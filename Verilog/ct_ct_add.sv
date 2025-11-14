`include "types.svh"

module ct_ct_add #(
  parameter int unsigned N  = N_SLOTS_L,
  parameter int unsigned W  = W_BITS_L,
  // >>> add this: let the caller pass q explicitly
  parameter logic [W-1:0]   QP = Q_MOD_L
)(
  input  CT_t in_ct1,
  input  CT_t in_ct2,
  output CT_t out_ct
);
  // use the parameterized q everywhere
  localparam logic [W-1:0] Q = QP;

  function automatic word_t add_mod_q(input logic [W-1:0] a, input logic [W-1:0] b);
    logic [W:0] sum, qext, diff;
    begin
      sum  = {1'b0, a} + {1'b0, b};
      qext = {1'b0, Q};
      if (sum >= qext) begin
        diff = sum - qext;
        add_mod_q = word_t'(diff[W-1:0]);
      end else begin
        add_mod_q = word_t'(sum[W-1:0]);
      end
    end
  endfunction

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_ADD
      assign out_ct.A[i] = add_mod_q(in_ct1.A[i], in_ct2.A[i]);
      assign out_ct.B[i] = add_mod_q(in_ct1.B[i], in_ct2.B[i]);
    end
  endgenerate
endmodule
