`include "types.svh"

// multi-cycle fast base conversion for a single RNS Integer
module fastBConvSingle #(
    localparam int IN_BASIS_LEN, // num primes in input basis
    localparam int OUT_BASIS_LEN, // num primes in target basis
    // PER-BASIS CONSTANTS (all pre-computed)
    // qi  : input  basis moduli
    // bj  : target basis moduli
    // zi  : yi-1  = (q/qi) ^-1  mod qi
    // yib : (q/qi)            % bj
    localparam rns_residue_t IN_BASIS [IN_BASIS_LEN],
    localparam rns_residue_t OUT_BASIS [OUT_BASIS_LEN],
    localparam rns_residue_t ZiLUT [IN_BASIS_LEN],
    localparam rns_residue_t YMODB [OUT_BASIS_LEN][IN_BASIS_LEN]
) (
    input logic clk,

    input logic in_valid, // acts like a reset signal and triggers the calculations to start
    input rns_residue_t input_RNSint [IN_BASIS_LEN],

    output logic out_valid,
    output rns_residue_t output_RNSint [OUT_BASIS_LEN] // this is a register. Value is valid when out_valid is asserted
);
    // control state
    logic [$clog2(IN_BASIS_LEN)-1:0] current_state;
    logic compute_is_active;

    // compute "a" for every residue in the input
    rns_residue_t n_a_res [IN_BASIS_LEN];
    rns_residue_t a_res [IN_BASIS_LEN]; // register
    always_comb begin : CALC_A
        // all steps are indpendent/parallel
        for (int i = 0; i < `IN_BASIS_LEN; i++) begin
            n_a_res[i] = (input_RNSint[i]*ZiLUT[i]) % IN_BASIS[i];
        end
    end
    
    // accumulate the new RNS prime from partial sums calculated over multiple (IN_BASIS_LEN) cycles
    rns_residue_t psum [`OUT_BASIS_LEN];
    rns_residue_t n_total_sum [`OUT_BASIS_LEN];
    logic [`RNS_PRIME_BITS:0] wide_n_total_sum [`OUT_BASIS_LEN];
    always_comb begin : ACCUMULATE_PSUM
        // all steps are indpendent/parallel
        for (int j = 0; j < `OUT_BASIS_LEN; j++) begin
            // multiplication needs a real mod
            psum[j] = (a_res[current_state]*YMODB[j][current_state]) % OUT_BASIS[j];
            wide_n_total_sum[j] = output_RNSint[j] + psum[j];
            // addition can use a "fake" mod
            n_total_sum[j] = wide_n_total_sum[j] > OUT_BASIS[j] ? wide_n_total_sum[j]-OUT_BASIS[j] : wide_n_total_sum[j];
        end
    end
    
    // sequential logic / state machine controller
    always_ff @( posedge clk ) begin : MULTICYCLE_REGS
        // if in_valid, start the state counter and latch the computed "a" coefficients
        current_state <= in_valid ? '0 : (compute_is_active ? (current_state + 1) : current_state);
        compute_is_active <= in_valid ? 1 : (out_valid ? 0 : compute_is_active);
        out_valid <= current_state==IN_BASIS_LEN;
        //
        // first pipeline stage computes "a" coefs
        a_res <= in_valid ? n_a_res : a_res;
        // second stage writes to the output register, and takes "OUT_BASIS_LEN" cycles
        output_RNSint <= in_valid ? '0 : (compute_is_active ? n_total_sum : output_RNSint);
    end
endmodule

module fastBConv #(
    localparam unsigned IN_BASIS_LEN, // num primes in input basis
    localparam unsigned OUT_BASIS_LEN, // num primes in target basis
    // PER-BASIS CONSTANTS (all pre-computed)
    // qi  : input  basis moduli
    // bj  : target basis moduli
    // zi  : yi-1  = (q/qi) ^-1  mod qi
    // yib : (q/qi)            % bj
    localparam rns_residue_t IN_BASIS [IN_BASIS_LEN],
    localparam rns_residue_t OUT_BASIS [OUT_BASIS_LEN],
    localparam rns_residue_t ZiLUT [IN_BASIS_LEN],
    localparam rns_residue_t YMODB[OUT_BASIS_LEN][IN_BASIS_LEN]
) (
    input logic clk,
    input logic reset,

    input logic in_valid,
    input rns_residue_t input_poly [`N_SLOTS][IN_BASIS_LEN],

    output logic out_valid,
    output rns_residue_t output_poly [`N_SLOTS][OUT_BASIS_LEN]
);

    genvar i;
    generate
    for (i = 0; i < `N_SLOTS; i++) begin
        // follow the same procedure for every coefficient in the polynomial
        // TODO instantiate fastBConvSingle
    end
    endgenerate


endmodule