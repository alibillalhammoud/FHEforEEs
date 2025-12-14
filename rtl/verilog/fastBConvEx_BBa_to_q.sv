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
    // verilog compilation error check that 
    if ((`Ba_BASIS_LEN)!=1) begin
        $fatal(1,"fastBConvEx_BBa_to_q: Ba_BASIS_LEN must be 1");
    end
    // seperate B residues from Ba residues
    wire rns_residue_t xB_RNSpoly [`N_SLOTS][`B_BASIS_LEN];
    reg signed [`RNS_PRIME_BITS:0] signed_xBa_RNSpoly [`N_SLOTS][`Ba_BASIS_LEN]; // logic is below
    genvar k;
    genvar j;
    generate
        for (k = 0; k < `N_SLOTS; k++) begin : SEPERATE_B_FROM_Ba
            for(j = 0; j < `B_BASIS_LEN; ++j) begin : GETBMODULIS
                assign xB_RNSpoly[k][j] = input_RNSpoly[k][j];
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
        .output_RNSpoly(xB_in_Ba),
        .doing_fastBconv()//unused
    );
    // create signed version of xB_in_Ba
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
        .output_RNSpoly(xB_in_q),
        .doing_fastBconv()//unused
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
    localparam wide_rns_residue_t Ba_BASIS0_widthextfastmod = Ba_BASIS[0];
    localparam logic signed [`RNS_PRIME_BITS:0] Ba_BASIS0_signed = {1'b0,Ba_BASIS[0]};
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            assign gamma_nomod[k] = temp[k]*binv_Ba_MOD_Ba[0];
            assign gamma_nocenter[k]=gamma_nomod[k]%Ba_BASIS0_widthextfastmod;
            assign gamma_centered[k] = (gamma_nocenter[k]>(Ba_BASIS[0]/2)) ? gamma_nocenter[k]-Ba_BASIS0_signed : gamma_nocenter[k];
        end
    endgenerate
    //
    // to avoid very long critical path, I add a register for gamma_centered
    // signed_xB_in_q is already in a register (from fast b conv)
    logic signed [`RNS_PRIME_BITS:0] pl_gamma_centered[`N_SLOTS];
    // will also require the signed version of the q basis
    logic signed [`RNS_PRIME_BITS:0] local_qBASIS_signed[`q_BASIS_LEN];
    wire signed [(2*`RNS_PRIME_BITS)+1:0] local_qBASIS_signed_wextfastmod[`q_BASIS_LEN];
    generate
        for(j = 0; j<`q_BASIS_LEN; ++j) begin
            assign local_qBASIS_signed[j] = {1'b0, q_BASIS[j]};
            assign local_qBASIS_signed_wextfastmod[j] = q_BASIS[j];
        end
    endgenerate
    // result_residues = (xB_to_q - gamma * b_mod_q) % target_basis (q)
    wire signed [(2*`RNS_PRIME_BITS)+1:0] rr_tmpvar1[`N_SLOTS][`q_BASIS_LEN];
    wire signed [(2*`RNS_PRIME_BITS)+1:0] rr_tmpvar2[`N_SLOTS][`q_BASIS_LEN];
    wire signed [`RNS_PRIME_BITS:0] rr_tmpvar3_mod[`N_SLOTS][`q_BASIS_LEN];
    generate
        for(k = 0; k<`N_SLOTS; ++k) begin
            for(j = 0; j<`q_BASIS_LEN; ++j) begin
                assign rr_tmpvar1[k][j] = pl_gamma_centered[k] * signed_intb_MOD_q[j];
                assign rr_tmpvar2[k][j] = signed_xB_in_q[k][j] - rr_tmpvar1[k][j];
                // perform modulus operation (truncates to RNS_PRIME_BITS+1 bits)
                assign rr_tmpvar3_mod[k][j] = rr_tmpvar2[k][j]%local_qBASIS_signed_wextfastmod[j];
                // convert cpp/verilog style mod to an actual math mod, also truncate to residue bits
                assign output_RNSpoly[k][j] = rr_tmpvar3_mod[k][j][`RNS_PRIME_BITS] ? rr_tmpvar3_mod[k][j]+local_qBASIS_signed[j] : rr_tmpvar3_mod[k][j];
            end
        end
    endgenerate

    // TODO only update gamma when values are updated to avoid glitches
    // for now this works
    logic n_n_out_valid, n_out_valid;
    assign n_n_out_valid = fastBConv_Btoq_outvalid && fastBConv_BtoBa_outvalid;
    int kn;
    always_ff @( posedge clk ) begin : CTRLANDREGS
        pl_gamma_centered <= gamma_centered;
        n_out_valid <= reset ? 0 : n_n_out_valid;
        out_valid <= reset ? 0 : n_out_valid;
        // 
        for(kn=0; kn<`N_SLOTS; ++kn) begin
            signed_xBa_RNSpoly[kn][0] <= in_valid ? input_RNSpoly[kn][`B_BASIS_LEN] : signed_xBa_RNSpoly[kn][0];
        end
    end

endmodule