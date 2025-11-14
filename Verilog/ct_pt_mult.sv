// ============================================================================
// ct_pt_mult.sv — Ciphertext × Plaintext (slot-wise), modulo q
//   Out = (A ⊙ Γ, B ⊙ Γ) mod q
//   (⊙ = element-wise product across N slots)
// ============================================================================
`include "types.svh"

module ct_pt_mult #(
  parameter int unsigned N  = N_SLOTS_L,
  parameter int unsigned W  = W_BITS_L,
  parameter int unsigned WW = 2*W_BITS_L // mult needs double width
)(
  input  CT_t in_ct,     // (A, B)
  input  PT_t in_gamma,  // Γ (plaintext vector)
  output CT_t out_ct     // (A*Γ, B*Γ) mod q
);
  localparam word_t Q = Q_MOD_L;

  function automatic word_t mod_q(input logic signed [WW-1:0] x);
    logic signed [WW-1:0] r;
    begin
      r = x % Q;
      if (r < 0) r = r + Q;
      mod_q = word_t'(r[W-1:0]);
    end
  endfunction

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_MUL
      logic signed [WW-1:0] prodA = $signed(in_ct.A[i]) * $signed(in_gamma[i]);
      logic signed [WW-1:0] prodB = $signed(in_ct.B[i]) * $signed(in_gamma[i]);

      assign out_ct.A[i] = mod_q(prodA);
      assign out_ct.B[i] = mod_q(prodB);
    end
  endgenerate
endmodule
