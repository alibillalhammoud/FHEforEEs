`include "types.svh"

module adder(
  input q_BASIS_poly a,
  input q_BASIS_poly b,
  output q_BASIS_poly out
);

  genvar i, j;
  generate
    for (i = 0; i < `N_SLOTS; i++) begin : GEN_ADD
      for (j=0; j < `q_BASIS_LEN; j++) begin
          assign out[i][j] = (a[i][j] + b[i][j]) > q_BASIS[j] ? (a[i][j] + b[i][j]) - q_BASIS[j] : (a[i][j] + b[i][j]);
        end
      end
  endgenerate

endmodule;