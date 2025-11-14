// ============================================================================
// mod_single.sv — Reduce a single (possibly wide/signed) value modulo q
// ============================================================================
`include "types.svh"

module mod_single #(
  parameter int unsigned W  = W_BITS_L,   // input word width
  parameter int unsigned WW = 2*W_BITS_L  // temp width for safety (mults)
)(
  input  logic signed [WW-1:0] in_val,  // can be wider than W
  output word_t                out_mod  // reduced into [W-1:0],  in [0, q)
);
  // Treat q as signed for comparison; keep it constant
  localparam word_t Q = Q_MOD_L;

  function automatic word_t mod_q(input logic signed [WW-1:0] x);
    logic signed [WW-1:0] r;
    begin
      // SystemVerilog % keeps sign; normalize to [0,q)
      r = x % Q;
      if (r < 0) r = r + Q;
      mod_q = word_t'(r[W-1:0]); // truncate to W bits (q should fit W bits)
    end
  endfunction

  assign out_mod = mod_q(in_val);
endmodule
