`include "types.svh"

module ct_pt_add #(
  parameter int unsigned N  = N_SLOTS_L,
  parameter int unsigned W  = W_BITS_L,
  parameter int unsigned WW = 2*W_BITS_L,
  // explicit params so TB can override cleanly
  parameter logic [W-1:0] QP     = Q_MOD_L,
  parameter logic [W-1:0] DELTAP = DELTA_L
)(
  input  CT_t in_ct,     // (A, B)
  input  PT_t in_gamma,  // Γ
  output CT_t out_ct     // (A, B + Δ·Γ) mod q
);
  localparam logic [W-1:0] Q     = QP;
  localparam logic [W-1:0] DELTA = DELTAP;

  // Only used for the B path
  function automatic word_t mod_q(input logic signed [WW-1:0] x);
    logic signed [WW-1:0] r;
    begin
      r = x % $signed(Q);
      if (r < 0) r = r + $signed(Q);
      mod_q = word_t'(r[W-1:0]);
    end
  endfunction

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_ADDPT
      // --- A passes through unchanged ---
      assign out_ct.A[i] = in_ct.A[i];

      // --- B' = (B + Δ·Γ) mod q ---
      logic signed [WW-1:0] delta_gamma = $signed(DELTA) * $signed(in_gamma[i]);
      logic signed [WW-1:0] sumB        = $signed(in_ct.B[i]) + delta_gamma;
      assign out_ct.B[i] = mod_q(sumB);
    end
  endgenerate

  // Optional: sanity print so you can confirm q, Δ at sim time
  initial $display("ct_pt_add using q=%0d, Δ=%0d (W=%0d, N=%0d)", Q, DELTA, W, N);
endmodule
