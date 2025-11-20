`include "types.svh"
module mod_single #(
  parameter int unsigned W  = W_BITS_L,     
  parameter int unsigned WW = 2*W_BITS_L
)(
  input  logic signed [WW-1:0] in_val,  
  output word_t                out_mod  
);
  localparam word_t Q             = Q_MOD_L;
  localparam int unsigned WWP     = WW + 1;   
  localparam int unsigned MAXSUB  = 64;        
  function automatic word_t reduce_pos(input logic [WWP-1:0] t_in);
    logic [WWP-1:0] t, qext;
    begin
      t    = t_in;
      qext = { {(WWP-W){1'b0}}, Q };
      for (int k = 0; k < MAXSUB; k++) begin
        if (t >= qext) t = t - qext;
      end
      reduce_pos = word_t'(t[W-1:0]);
    end
  endfunction
  wire is_neg = in_val[WW-1];
  logic [WW-1:0] abs_u;
  assign abs_u = is_neg ? $unsigned(-in_val) : $unsigned(in_val);
  logic [WWP-1:0] abs_ext;
  assign abs_ext = { {(WWP-WW){1'b0}}, abs_u };
  wire word_t r_pos = reduce_pos(abs_ext);
  wire word_t r_neg = (r_pos == '0) ? word_t'(0) : (Q - r_pos);
  assign out_mod = is_neg ? r_neg : r_pos;
endmodule