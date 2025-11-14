// ============================================================================
// mod_vector.sv — Reduce a vector of values modulo q (element-wise)
// ============================================================================
`include "types.svh"

module mod_vector #(
  parameter int unsigned N  = N_SLOTS_L,
  parameter int unsigned W  = W_BITS_L,
  parameter int unsigned WW = 2*W_BITS_L
)(
  input  logic signed [WW-1:0] in_vec [N],
  output vec_t                 out_vec
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
    for (i = 0; i < N; i++) begin : GEN_MOD
      assign out_vec[i] = mod_q(in_vec[i]);
    end
  endgenerate
endmodule
