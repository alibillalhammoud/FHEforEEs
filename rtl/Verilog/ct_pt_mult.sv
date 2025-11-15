`include "types.svh"
module ct_pt_mult #(
  parameter int unsigned N   = N_SLOTS_L,
  parameter int unsigned W   = W_BITS_L,
  parameter int unsigned WW  = 2*W_BITS_L,    
  parameter logic [W-1:0] QP = Q_MOD_L
)(
  input  CT_t in_ct,     
  input  PT_t in_gamma,  
  output CT_t out_ct    
);
  localparam logic [W-1:0] Q = QP;
  localparam int unsigned WWP = WW + 1;          
  localparam int unsigned MAX_SUB = 16;       
  function automatic word_t reduce_mod_q(input logic [WWP-1:0] t_in);
    logic [WWP-1:0] t, qext;
    begin
      t    = t_in;
      qext = { {(WWP-W){1'b0}}, Q };
      for (int k = 0; k < MAX_SUB; k++) begin
        if (t >= qext) t = t - qext;
      end
      reduce_mod_q = word_t'(t[W-1:0]);
    end
  endfunction

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_MUL
      logic [WW-1:0]  prodA_u;
      logic [WW-1:0]  prodB_u;
      logic [WWP-1:0] prodA_w;
      logic [WWP-1:0] prodB_w;
      assign prodA_u = $unsigned(in_ct.A[i]) * $unsigned(in_gamma[i]);
      assign prodB_u = $unsigned(in_ct.B[i]) * $unsigned(in_gamma[i]);
      assign prodA_w = { {(WWP-WW){1'b0}}, prodA_u };
      assign prodB_w = { {(WWP-WW){1'b0}}, prodB_u };
      assign out_ct.A[i] = reduce_mod_q(prodA_w);
      assign out_ct.B[i] = reduce_mod_q(prodB_w);
    end
  endgenerate
endmodule
