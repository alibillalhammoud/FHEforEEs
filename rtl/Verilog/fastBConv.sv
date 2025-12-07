`include "types.svh"

// multi-cycle fast base conversion for a single RNS Integer
module fastBConvSingle #(
    parameter int IN_BASIS_LEN, // num primes in input basis
    parameter int OUT_BASIS_LEN, // num primes in target basis
    // PER-BASIS CONSTANTS (all pre-computed)
    // qi  : input  basis moduli
    // bj  : target basis moduli
    // zi  : yi-1  = (q/qi) ^-1  mod qi
    // yib : (q/qi)            % bj
    parameter rns_residue_t IN_BASIS [IN_BASIS_LEN],
    parameter rns_residue_t OUT_BASIS [OUT_BASIS_LEN],
    parameter rns_residue_t ZiLUT [IN_BASIS_LEN],
    parameter rns_residue_t YMODB [OUT_BASIS_LEN][IN_BASIS_LEN]
) (
    input wire clk,
    input wire reset,

    input wire in_valid, // triggers the calculations to start
    input wire rns_residue_t input_RNSint [IN_BASIS_LEN],

    output wire out_valid,
    output rns_residue_t output_RNSint [OUT_BASIS_LEN], // this is a register. Value is valid when out_valid is asserted
    output wire doing_fastBconv
);
    // verilog compilation error checking
    if ((IN_BASIS_LEN==1 && IN_BASIS[0]==0) || (OUT_BASIS_LEN==1 && OUT_BASIS[0]==0) || ZiLUT[0]==0) begin
        $fatal(1,"fastBConv: parameters must be overridden (or you cant pick len=1 and basis[0]=0)");
    end

    // control state registers
    reg [$clog2(IN_BASIS_LEN)-1:0] current_state;
    reg compute_is_active;

    // compute "a" for every residue in the input
    wire wide_rns_residue_t a_re_nomod [IN_BASIS_LEN];
    wire wide_rns_residue_t wideINBASIS_forfastmod [IN_BASIS_LEN];
    wire rns_residue_t n_a_res [IN_BASIS_LEN];
    rns_residue_t a_res [IN_BASIS_LEN]; // register

    genvar i;
    generate
        // all steps are indpendent/parallel
        for (i = 0; i < IN_BASIS_LEN; ++i) begin : GEN_A_COEFFS
            //assign wideINBASIS_forfastmod[i] = IN_BASIS[i];
            assign a_re_nomod[i] = input_RNSint[i] * ZiLUT[i];
            assign n_a_res[i] = a_re_nomod[i] % IN_BASIS[i];
        end
    endgenerate
    
    // accumulate the new RNS prime from partial sums calculated over multiple (IN_BASIS_LEN) cycles
    wire rns_residue_t psum [OUT_BASIS_LEN];
    wire wide_rns_residue_t psum_nomod [OUT_BASIS_LEN];
    wire wide_rns_residue_t wideOUTBASIS_forfastmod [OUT_BASIS_LEN];
    wire rns_residue_t n_total_sum [OUT_BASIS_LEN];
    wire [`RNS_PRIME_BITS:0] wide_n_total_sum [OUT_BASIS_LEN];
    genvar j;
    generate
        // all steps are indpendent/parallel
        for (j = 0; j < OUT_BASIS_LEN; j++) begin : PSUM_GEN
            //assign wideOUTBASIS_forfastmod[j] = OUT_BASIS[j];
            // multiplication needs a real mod // % IN_BASIS_LEN
            assign psum_nomod[j] = a_res[current_state] * YMODB[j][current_state];
            assign psum[j] = psum_nomod[j] % OUT_BASIS[j];
            assign wide_n_total_sum[j] = output_RNSint[j] + psum[j];
            // addition can use a "fake" mod
            assign n_total_sum[j] = (wide_n_total_sum[j] >= OUT_BASIS[j]) ? (wide_n_total_sum[j] - OUT_BASIS[j]) : wide_n_total_sum[j];
        end
    endgenerate

    assign out_valid = (current_state==IN_BASIS_LEN);
    assign n_out_valid = ((current_state+1)==IN_BASIS_LEN);
    // sequential logic / state machine controller
    assign doing_fastBconv = compute_is_active;
    always_ff @( posedge clk ) begin : MULTICYCLE_REGS
        // if in_valid, start the state counter and latch the computed "a" coefficients
        current_state <= (reset || in_valid) ? '0 : (compute_is_active ? (current_state + 1) : current_state);
        compute_is_active <= reset ? 0 : (in_valid ? 1 : (n_out_valid ? 0 : compute_is_active));
        //
        // first pipeline stage computes "a" coefs
        a_res <= in_valid ? n_a_res : a_res;
        // second stage writes to the output register, and takes "OUT_BASIS_LEN" cycles
        output_RNSint <= in_valid ? '{default:'0} : (compute_is_active ? n_total_sum : output_RNSint);
    end
endmodule



// TODO in the future, we should move the control logic here because we don't need control for each single block
// for now, fastBConvSingle is tested and working
module fastBConv #(
    parameter int IN_BASIS_LEN,
    parameter int OUT_BASIS_LEN,
    parameter rns_residue_t IN_BASIS [IN_BASIS_LEN],
    parameter rns_residue_t OUT_BASIS [OUT_BASIS_LEN],
    parameter rns_residue_t ZiLUT [IN_BASIS_LEN],
    parameter rns_residue_t YMODB [OUT_BASIS_LEN][IN_BASIS_LEN]
) (
    input wire clk,
    input wire reset,

    input wire in_valid,
    input wire rns_residue_t input_RNSpoly [`N_SLOTS][IN_BASIS_LEN],

    output wire out_valid,
    output rns_residue_t output_RNSpoly [`N_SLOTS][OUT_BASIS_LEN], // this is a register. Value is valid when out_valid is asserted
    output wire doing_fastBconv
);
    // verilog compilation error checking
    if ((IN_BASIS_LEN==1 && IN_BASIS[0]==0) || (OUT_BASIS_LEN==1 && OUT_BASIS[0]==0) || ZiLUT[0]==0) begin
        initial $fatal(1,"fastBConv: parameters must be overridden (or you cant pick len=1 and basis[0]=0)");
    end
    
    wire [`N_SLOTS-1:0] slot_out_valid;
    wire [`N_SLOTS-1:0] slot_running_compute;
    
    genvar k;
    generate
        for (k = 0; k < `N_SLOTS; k++) begin : FASTBCONV_INSTS
            fastBConvSingle #(
                .IN_BASIS_LEN(IN_BASIS_LEN),
                .OUT_BASIS_LEN(OUT_BASIS_LEN),
                .IN_BASIS(IN_BASIS),
                .OUT_BASIS(OUT_BASIS),
                .ZiLUT(ZiLUT),
                .YMODB(YMODB)
            ) conv_inst (
                .clk(clk),
                .reset(reset),
                .in_valid(in_valid), // could be indexed if you're triggering each slot separately
                .input_RNSint(input_RNSpoly[k]), // [IN_BASIS_LEN] slice for this slot
                .out_valid(slot_out_valid[k]),
                .output_RNSint(output_RNSpoly[k]),
                .doing_fastBconv(slot_running_compute[k])
            );
        end
    endgenerate

    assign out_valid = slot_out_valid[0]; // logic is identical for all (it is redundant)
    assign doing_fastBconv = slot_running_compute[0];
endmodule

