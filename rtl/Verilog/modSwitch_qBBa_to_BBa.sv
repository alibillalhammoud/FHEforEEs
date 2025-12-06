`include "types.svh"

// depends on fastBConv
// multi-cycle mod switch for a vector of RNS Integers
// NOTE: q modulis MUST be in the first q_BASIS_LEN slots (of each RNS Integer), and the rest must be BBa basis
module modSwitch_qBBa_to_BBa (
    input wire clk,
    input wire reset,

    input wire in_valid, // triggers the calculations to start
    input wire rns_residue_t input_RNSpoly [`N_SLOTS][`qBBa_BASIS_LEN],

    output reg out_valid,
    output wire rns_residue_t output_RNSpoly [`N_SLOTS][`BBa_BASIS_LEN] // Value is valid when out_valid is asserted
);
    // seperate the drop RNS residues from each slot
    wire rns_residue_t to_be_dropped_RNSpoly [`N_SLOTS][`q_BASIS_LEN];
    wire signed [`RNS_PRIME_BITS:0] to_be_kept_RNSpoly [`N_SLOTS][`BBa_BASIS_LEN];
    genvar k;
    genvar j;
    generate
        for (k = 0; k < `N_SLOTS; k++) begin : SEPERATE_q_FROM_BBa
            // drop [0:`q_BASIS_LEN-1]
            for(j = 0; j < `q_BASIS_LEN; ++j) begin : GETDROPMODULIS_q
                assign to_be_dropped_RNSpoly[k][j] = input_RNSpoly[k][j];
            end
            // keep the rest (convert to signed by adding to the front 0)
            for(j = 0; j < `BBa_BASIS_LEN; ++j) begin : GETKEEPMODULIS_BBa
                assign to_be_kept_RNSpoly[k][j] = {1'b0, input_RNSpoly[k][j+`q_BASIS_LEN]};
            end
        end
    endgenerate
    
    // fast base conv q to BBa
    rns_residue_t xhatf_fastBconv_output_RNSpoly [`N_SLOTS][`BBa_BASIS_LEN];
    logic fastBConv_outvalid;
    fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`BBa_BASIS_LEN),
        .IN_BASIS(q_BASIS),
        .OUT_BASIS(BBa_BASIS),
        .ZiLUT(z_MOD_q),
        .YMODB(y_q_TO_BBa)
    ) conv_inst (
        .clk(clk),
        .reset(reset),
        .in_valid(in_valid),
        .input_RNSpoly(to_be_dropped_RNSpoly),
        .out_valid(fastBConv_outvalid),
        .output_RNSpoly(xhatf_fastBconv_output_RNSpoly)
    );
    // signed version of fastBConv output (convert to signed by adding 0 to the front)
    wire signed [`RNS_PRIME_BITS:0] signed_xhatf_fastBconv_RNSpoly [`N_SLOTS][`BBa_BASIS_LEN];
    generate
        for (k = 0; k < `N_SLOTS; k++) begin
            for(j = 0; j < `BBa_BASIS_LEN; ++j) begin
                assign signed_xhatf_fastBconv_RNSpoly[k][j] = {1'b0, xhatf_fastBconv_output_RNSpoly[k][j]};
            end
        end
    endgenerate

    // finish the mod switch in one step combinationally (output of fastBConv is a reg, so this takes another cycle)
    // TODO a better approach we would send the fastBConv output to the reg file and do this after a reg (to avoid glitches)
    wire signed [`RNS_PRIME_BITS:0] delta_signed [`N_SLOTS][`BBa_BASIS_LEN];
    wire rns_residue_t delta [`N_SLOTS][`BBa_BASIS_LEN];
    wire wide_rns_residue_t new_res_nomod [`N_SLOTS][`BBa_BASIS_LEN];
    generate
        for (k = 0; k < `N_SLOTS; ++k) begin : FINISH_MODSWITCH
            for(j = 0; j < `BBa_BASIS_LEN; ++j) begin
                assign delta_signed[k][j] = to_be_kept_RNSpoly[k][j]-signed_xhatf_fastBconv_RNSpoly[k][j];
                // make positive then truncate to unsigned width (signed width is one bit longer than unsigned)
                assign delta[k][j] = delta_signed[k][j][`RNS_PRIME_BITS] ? delta_signed[k][j] + BBa_BASIS[j] : delta_signed[k][j];
                // perform multiplication with precomputed values
                assign new_res_nomod[k][j] = delta[k][j]*qinv_MOD_BBa[j];
                assign output_RNSpoly[k][j] = new_res_nomod[k][j] % BBa_BASIS[j];
            end
        end
    endgenerate

    // limited control logic (just need to update the reset and delay out_valid by one cycle)
    logic out_valid_n;
    assign out_valid_n = fastBConv_outvalid;
    always_ff @( posedge clk ) begin : MODSWITCH_CONTROL
        out_valid <= reset ? 0 : out_valid_n;
    end

endmodule