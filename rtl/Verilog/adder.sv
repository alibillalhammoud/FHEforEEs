`include "types.svh"

module adder(
  input vec_t a,
  input vec_t b,
  output wide_vec_t out
);

  genvar i;
  generate
    for (i = 0; i < `N_SLOTS; i++) begin : GEN_ADD
      assign out[i] = {1'b0, a[i]} + {1'b0, b[i]};
    end
  endgenerate

endmodule;