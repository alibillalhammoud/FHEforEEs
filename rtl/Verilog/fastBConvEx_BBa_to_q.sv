`include "types.svh"

// depends on fastBConv
// multi-cycle fastBConvEx for a vector of RNS Integers
// NOTE: B modulis MUST be in the first B_BASIS_LEN slots (of each RNS Integer), and the rest must be Ba basis
// NOTE: Ba basis must be EXACTLY 1 prime long
module fastBConvEx_BBa_to_q (
    input wire clk,
    input wire reset,

    input wire in_valid, // triggers the calculations to start
    input wire rns_residue_t input_RNSpoly [`N_SLOTS][`BBa_BASIS_LEN],

    output reg out_valid,
    output wire rns_residue_t output_RNSpoly [`N_SLOTS][`q_BASIS_LEN] // Value is valid when out_valid is asserted
);
    // seperate B residues from Ba residues
    wire rns_residue_t xB_RNSpoly [`N_SLOTS][`B_BASIS_LEN];
    wire signed [`RNS_PRIME_BITS:0] signed_xBa_RNSpoly [`N_SLOTS][`Ba_BASIS_LEN];
    genvar k;
    genvar j;
    generate
        for (k = 0; k < `N_SLOTS; k++) begin : SEPERATE_B_FROM_Ba
            for(j = 0; j < `B_BASIS_LEN; ++j) begin : GETBMODULIS
                assign xB_RNSpoly[k][j] = input_RNSpoly[k][j];
            end
            for(j = 0; j < `Ba_BASIS_LEN; ++j) begin : GETBaMODULIS
                assign signed_xBa_RNSpoly[k][j] = {1'b0, input_RNSpoly[k][j+`B_BASIS_LEN]};
            end
        end
    endgenerate
    //
    // fast base conversion "xB" from B to Ba
    rns_residue_t xB_in_Ba [`N_SLOTS][`Ba_BASIS_LEN];
    logic fastBConv_BtoBa_outvalid;
    fastBConv #(
        .IN_BASIS_LEN(`B_BASIS_LEN),
        .OUT_BASIS_LEN(`Ba_BASIS_LEN),
        .IN_BASIS(B_BASIS),
        .OUT_BASIS(Ba_BASIS),
        .ZiLUT(z_MOD_B),
        .YMODB(y_B_TO_Ba)
    ) conv_inst_BtoBa (
        .clk(clk),
        .reset(reset),
        .in_valid(in_valid),
        .input_RNSpoly(xB_RNSpoly),
        .out_valid(fastBConv_BtoBa_outvalid),
        .output_RNSpoly(xB_in_Ba)
    );
    // create signed version of xB_in_Ba
    // TODO assert that Ba_BASIS_LEN=1
    logic signed [`RNS_PRIME_BITS:0] signed_xB_in_Ba[`N_SLOTS];
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            assign signed_xB_in_Ba[k] = {1'b0, xB_in_Ba[k][0]};
        end
    endgenerate
    //
    // fast base conv "xB" from B to q
    // in parralel with B->Ba conv
    rns_residue_t xB_in_q [`N_SLOTS][`q_BASIS_LEN];
    logic fastBConv_Btoq_outvalid;
    fastBConv #(
        .IN_BASIS_LEN(`B_BASIS_LEN),
        .OUT_BASIS_LEN(`q_BASIS_LEN),
        .IN_BASIS(B_BASIS),
        .OUT_BASIS(q_BASIS),
        .ZiLUT(z_MOD_B),
        .YMODB(y_B_TO_q)
    ) conv_inst_Btoq (
        .clk(clk),
        .reset(reset),
        .in_valid(in_valid),
        .input_RNSpoly(xB_RNSpoly),
        .out_valid(fastBConv_Btoq_outvalid),
        .output_RNSpoly(xB_in_q)
    );
    // create signed version of xB_in_q
    logic signed [`RNS_PRIME_BITS:0] signed_xB_in_q[`N_SLOTS][`q_BASIS_LEN];
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            for(j=0; j<`q_BASIS_LEN; ++j) begin
                assign signed_xB_in_q[k][j] = {1'b0, xB_in_q[k][j]};
            end
        end
    endgenerate
    //
    // create temp = (signed_xB_in_Ba - xBa) fakemod Ba
    logic signed [`RNS_PRIME_BITS:0] signed_temp_nomod [`N_SLOTS];
    rns_residue_t temp[`N_SLOTS];
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            assign signed_temp_nomod[k] = signed_xB_in_Ba[k]-signed_xBa_RNSpoly[k][0];
            assign temp[k] = signed_temp_nomod[k][`RNS_PRIME_BITS] ? signed_temp_nomod[k]+Ba_BASIS[0] : signed_temp_nomod[k];
        end
    endgenerate
    // compute correction term "gamma"
    wire wide_rns_residue_t gamma_nomod [`N_SLOTS];
    wire rns_residue_t gamma_nocenter [`N_SLOTS];
    wire signed [`RNS_PRIME_BITS:0] gamma_centered[`N_SLOTS];
    localparam logic signed [`RNS_PRIME_BITS:0] Ba_BASIS0_signed = {1'b0,Ba_BASIS[0]};
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            assign gamma_nomod[k] = temp[k]*binv_Ba_MOD_Ba[0];
            assign gamma_nocenter[k]=gamma_nomod[k]%Ba_BASIS[0];
            assign gamma_centered[k] = (gamma_nocenter[k]>(Ba_BASIS[0]/2)) ? gamma_nocenter[k]-Ba_BASIS0_signed : gamma_nocenter[k];
        end
    endgenerate
    //
    // to avoid very long critical path, I add a register for gamma_centered
    // signed_xB_in_q is already in a register (from fast b conv)
    logic signed [`RNS_PRIME_BITS:0] pl_gamma_centered[`N_SLOTS];
    // result_residues = (xB_to_q - gamma * b_mod_q) % target_basis (q)
    wire signed [(2*`RNS_PRIME_BITS):0] rr_tmpvar1[`N_SLOTS][`q_BASIS_LEN];
    wire signed [(2*`RNS_PRIME_BITS):0] rr_tmpvar2[`N_SLOTS][`q_BASIS_LEN];
    wire signed [(2*`RNS_PRIME_BITS):0] rr_tmpvar3_mod[`N_SLOTS][`q_BASIS_LEN];
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            for(j = 0; j<`q_BASIS_LEN; ++j) begin
                assign rr_tmpvar1[k][j] = pl_gamma_centered[k] * signed_intb_MOD_q[j];
                assign rr_tmpvar2[k][j] = signed_xB_in_q[k][j] - rr_tmpvar1[k][j];
                assign rr_tmpvar3_mod[k][j] = rr_tmpvar2[k][j]%q_BASIS[j];
                // convert cpp/verilog style mod to an actual math mod, also truncate to residue bits
                assign output_RNSpoly[k][j] = rr_tmpvar3_mod[k][j][(2*`RNS_PRIME_BITS)-1] ? rr_tmpvar2[k][j]+q_BASIS[j] : rr_tmpvar2[k][j];
            end
        end
    endgenerate

    // TODO only update gamma when values are updated to avoid glitches
    // for now this works
    logic n_n_out_valid, n_out_valid;
    assign n_n_out_valid = fastBConv_Btoq_outvalid && fastBConv_BtoBa_outvalid;
    always_ff @( posedge clk ) begin : CTRLANDREGS
        pl_gamma_centered <= gamma_centered;
        n_out_valid <= reset ? 0 : n_n_out_valid;
        out_valid <= reset ? 0 : n_out_valid;
    end

endmodule