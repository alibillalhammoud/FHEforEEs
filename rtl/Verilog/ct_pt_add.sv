`include "types.svh"

module ct_pt_add #(
  parameter int unsigned N   = N_SLOTS_L,
  parameter int unsigned W   = W_BITS_L,
  parameter int unsigned WW  = 2*W_BITS_L,        
  parameter logic [W-1:0] QP     = Q_MOD_L,
  parameter logic [W-1:0] DELTAP = DELTA_L
)(
  input  CT_t in_ct,
  input  PT_t in_gamma,
  output CT_t out_ct
);
  localparam logic [W-1:0] Q     = QP;
  localparam logic [W-1:0] DELTA = DELTAP;
  localparam int unsigned WWP = (WW + 1);
  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_ADDPT
      assign out_ct.A[i] = in_ct.A[i];
      logic [WW-1:0]  delta_gamma_u;                 
      logic [WWP-1:0] sum_u, qext_u, diff_u; 

      always @* begin
        delta_gamma_u = $unsigned(DELTA) * $unsigned(in_gamma[i]);
        sum_u  = { {(WWP-W){1'b0}},  $unsigned(in_ct.B[i]) }
               + { {(WWP-WW){1'b0}}, delta_gamma_u };
        qext_u = { {(WWP-W){1'b0}},  Q };
        if (sum_u >= qext_u)
          diff_u = sum_u - qext_u;
        else
          diff_u = sum_u;
        out_ct.B[i] = word_t'(diff_u[W-1:0]);
      end
    end
  endgenerate
  initial $display("ct_pt_add using q=%0d, Δ=%0d (W=%0d, N=%0d)", Q, DELTA, W, N);
endmodule
