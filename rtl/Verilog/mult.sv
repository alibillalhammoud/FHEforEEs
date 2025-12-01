`include "types.svh"

module mult(
  input vec_t a,
  input vec_t b,
  output wide_vec_t out
);

parameter int unsigned WWP = 2*`RNS_PRIME_BITS + 1;

genvar i;
  generate
    for (i = 0; i < `N_SLOTS; i++) begin : GEN_MUL
      wide_rns_residue_t  prod_u;
      logic [WWP-1:0] prod_w;
      assign prod_u = $unsigned(a[i]) * $unsigned(b[i]);
      assign prod_w = { {1'b0}, prod_u };
      assign out[i] = prod_w;
    end
  endgenerate

endmodule