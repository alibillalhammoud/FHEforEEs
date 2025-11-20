`include "types.svh"

module ct_ct_mult (
  input  CT_t in_ct1,
  input  CT_t in_ct2,
  output CT_t out_ct
);

    vec_t D0, D1, D2, tempA, tempB;
    wide_vec_t D0_temp, D1_temp, D2_tempA, D2_tempB, D2_temp;
    vec_t [`NUM_DIGITS-1:0] D2_Decomp;

    // Calculate D0, D1, and D2
    mult multD0(
        .a(in_ct1.B),
        .b(in_ct2.B),
        .out(D0_temp)
    );

    mult multD1(
        .a(in_ct1.A),
        .b(in_ct2.A),
        .out(D1_temp)
    );

    mult multD2A(
        .a(in_ct1.A),
        .b(in_ct2.B),
        .out(D2_tempA)
    );

    mult multD2B(
        .a(in_ct1.B),
        .b(in_ct2.A),
        .out(D2_tempB)
    );

    mod_vector modD2A(
        .in_vec(D2_tempA),
        .out_vec(tempA)
    );

    mod_vector modD2B(
        .in_vec(D2_tempB),
        .out_vec(tempB)
    );

    adder addD2(
        .a(tempA),
        .b(tempB),
        .out(D2_temp)
    );

    mod_vector modD0(
        .in_vec(D0_temp),
        .out_vec(D0)
    );

    mod_vector modD1(
        .in_vec(D1_temp),
        .out_vec(D1)
    );

    mod_vector modD2(
        .in_vec(D2_temp),
        .out_vec(D2)
    );

    //Gadget Decomposition

endmodule


module decomp()(
    input word_t value
    output vec_t out
);

    vec_t temp;
    assign temp = reduce_mod_q(value);

    genvar i;
    generate
        for (i = 0; i < `NUM_DIGITS; i++) begin : GEN_DECOMP
            assign out = reduce_mod_q(temp / (`BASE ** i));
        end
    endgenerate

endmodule