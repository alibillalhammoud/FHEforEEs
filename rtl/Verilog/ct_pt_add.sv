`include "types.svh"

module ct_pt_add (
  input logic clk,
  input logic reset,
  input  CT_t in_ct,
  input  PT_t in_gamma,
  output CT_t out_ct
);

  vec_t delta_gamma;
  wide_vec_t tempB;

  assign out_ct.A = in_ct.A;

  genvar i;
  generate
    for (i = 0; i < `N_SLOTS; i++) begin : GEN_MULT_DELTA
      assign delta_gamma[i] = in_gamma[i] * `DELTA;
    end
  endgenerate

  adder a(
    .a(in_ct.B),
    .b(delta_gamma),
    .out(tempB)
  );

  mod_vector mod(
    .in_vec(tempB),
    .out_vec(out_ct.B)
  );

endmodule