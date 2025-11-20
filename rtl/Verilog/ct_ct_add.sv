`include "types.svh"

module ct_ct_add (
  input  CT_t in_ct1,
  input  CT_t in_ct2,
  output CT_t out_ct
);

  wide_vec_t tempA, tempB;

  adder addA(
    .a(in_ct1.A),
    .b(in_ct2.A),
    .out(tempA)
  );

  adder addB(
    .a(in_ct1.B),
    .b(in_ct2.B),
    .out(tempB)
  );

  mod_vector modA(
    .in_vec(tempA),
    .out_vec(out_ct.A)
  );

  mod_vector modB(
    .in_vec(tempB),
    .out_vec(out_ct.B)
  );

endmodule