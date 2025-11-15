`timescale 1ns/1ps
`define W_BITS  16
`define N_SLOTS 8
`define Q_MOD   16'd7710
`define T_MOD   16'd257
`define DELTA   16'd30
`include "verilog/types.svh"
module tb_mod_single;
  localparam int    W  = W_BITS_L;
  localparam int    WW = 2*W_BITS_L;
  localparam word_t Q  = Q_MOD_L;
  logic  signed [WW-1:0] in_val;
  word_t                 out_mod;

  mod_single #(
    .W (W_BITS_L),
    .WW(2*W_BITS_L)
  ) dut (
    .in_val (in_val),
    .out_mod(out_mod)
  );

  task automatic check(string tag, logic signed [WW-1:0] x, word_t got, word_t exp);
    if (got !== exp) begin
      $error("[%s] in=%0d (0x%0h) got=%0d exp=%0d", tag, x, x, got, exp);
      $fatal;
    end
  endtask

  initial begin
    $display("== mod_single test (q=%0d, W=%0d, WW=%0d) ==", Q, W, WW);

    // In-range
    in_val = 0;          #1; check("zero",    in_val, out_mod, 16'd0);
    in_val = 5;          #1; check("small+",  in_val, out_mod, 16'd5);
    in_val = 7710-1;     #1; check("max-1",   in_val, out_mod, 16'd7709);

    // Single wrap
    in_val = 7710;       #1; check("q",       in_val, out_mod, 16'd0);
    in_val = 7710+1;     #1; check("q+1",     in_val, out_mod, 16'd1);
    in_val = 3279+5762;  #1; check("9041→1331", in_val, out_mod, 16'd1331);

    // Multiple-q positive
    in_val = 5*7710 + 42; #1; check("5q+42",  in_val, out_mod, 16'd42);
    in_val = -1;          #1; check("-1",         in_val, out_mod, 16'd7709);
    in_val = -20;         #1; check("-20",        in_val, out_mod, 16'd7690);
    in_val = -(7710+7);   #1; check("-(q+7)",     in_val, out_mod, 16'd7703);
    in_val = -3*7710 + 15;#1; check("-3q+15",     in_val, out_mod, 16'd15);
    $display("PASS: mod_single produced expected outputs.");
    $finish;
  end
endmodule
