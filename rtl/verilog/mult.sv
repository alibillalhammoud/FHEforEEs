`include "types.svh"

module mult(
  // input a
  input q_BASIS_poly a_q,
  input B_BASIS_poly a_b,
  input Ba_BASIS_poly a_ba,
  // input b
  input q_BASIS_poly b_q,
  input B_BASIS_poly b_b,
  input Ba_BASIS_poly b_ba,
  // output = a*b % q / a*b % Ba / a*b % Ba
  output q_BASIS_poly out_q,
  output B_BASIS_poly out_b,
  output Ba_BASIS_poly out_ba
);

// temp wires
wide_q_BASIS_poly out_premod_q;
wide_B_BASIS_poly out_premod_B;
wide_Ba_BASIS_poly out_premod_Ba;

// generat the multipliers
genvar i, j;
generate 
  for (i = 0; i < `N_SLOTS; i++) begin : q_BASIS_MUL
    for (j=0; j < `q_BASIS_LEN; j++) begin
      assign out_premod_q[i][j] = a_q[i][j] * b_q[i][j];
      assign out_q[i][j] = out_premod_q[i][j] % q_BASIS[j];
    end
  end
endgenerate
//
generate 
  for (i = 0; i < `N_SLOTS; i++) begin : B_BASIS_MUL
    for (j=0; j < `B_BASIS_LEN; j++) begin
      assign out_premod_B[i][j] = a_b[i][j] * b_b[i][j];
      assign out_b[i][j] = out_premod_B[i][j] % B_BASIS[j];
    end
  end
endgenerate
//
generate
  for (i = 0; i < `N_SLOTS; i++) begin : Ba_BASIS_MUL
    for (j=0; j < `Ba_BASIS_LEN; j++) begin
      assign out_premod_Ba[i][j] = a_ba[i][j] * b_ba[i][j];
      assign out_ba[i][j] = out_premod_Ba[i][j] % Ba_BASIS[j];
    end
  end
endgenerate

endmodule