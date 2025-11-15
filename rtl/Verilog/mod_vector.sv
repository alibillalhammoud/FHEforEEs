`include "types.svh"

module mod_vector #(
  parameter int unsigned N   = N_SLOTS_L,
  parameter int unsigned W   = W_BITS_L,
  parameter int unsigned WW  = 2*W_BITS_L        
)(
  input  logic signed [WW-1:0] in_vec [N],
  output vec_t                 out_vec
);
  localparam logic [W-1:0] Q = Q_MOD_L;
  localparam int unsigned WWP = ((WW > W) ? WW : W) + 1;
  function automatic logic [W-1:0] urem_mod_q(input logic [WWP-1:0] u_in);
    logic [WWP-1:0] t, qext;
    begin
      t    = u_in;
      qext = { {(WWP-W){1'b0}}, Q };
      for (int k = WWP-1; k >= 0; k--) begin
        if (t >= (qext << k)) t = t - (qext << k);
      end
      urem_mod_q = t[W-1:0];
    end
  endfunction

  function automatic word_t srem_mod_q(input logic signed [WW-1:0] x_in);
    logic signed [WWP-1:0] xse;
    logic        [WWP-1:0] abs_u;
    logic        [W-1:0]   a_mod;
    begin
      xse   = { {(WWP-WW){x_in[WW-1]}}, x_in };
      abs_u = xse[WWP-1] ? $unsigned(-xse) : $unsigned(xse);  
      a_mod = urem_mod_q(abs_u);                           
      if (!xse[WWP-1]) begin
        srem_mod_q = a_mod;                             
      end else begin
        srem_mod_q = (a_mod == '0) ? word_t'(0) : word_t'(Q - a_mod); 
      end
    end
  endfunction

  genvar i;
  generate
    for (i = 0; i < N; i++) begin : GEN_MOD
      assign out_vec[i] = srem_mod_q(in_vec[i]);
    end
  endgenerate
endmodule
