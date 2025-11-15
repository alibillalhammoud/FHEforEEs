`timescale 1ns/1ps
`define N_SLOTS 8
`define W_BITS  16
`define Q_MOD   16'd7710
`define T_MOD   16'd257
`define DELTA   16'd30
`include "verilog/types.svh"
module tb_mod_vector;
  localparam int    N  = N_SLOTS_L;
  localparam int    W  = W_BITS_L;
  localparam int    WW = 2*W_BITS_L;
  localparam word_t Q  = Q_MOD_L;
  logic signed [WW-1:0] in_vec [N];
  vec_t                 out_vec;
  mod_vector #(
    .N (N_SLOTS_L),
    .W (W_BITS_L),
    .WW(2*W_BITS_L)
  ) dut (
    .in_vec (in_vec),
    .out_vec(out_vec)
  );
  task automatic check_vec(string tag, input vec_t got, input vec_t exp);
    for (int i = 0; i < N; i++) begin
        if (got[i] !== exp[i]) begin
        $error("[%s] slot %0d mismatch: got=%0d exp=%0d", tag, i, got[i], exp[i]);
        $fatal;
        end
    end
  endtask
  vec_t exp;

  initial begin
    $display("== mod_vector test (q=%0d, N=%0d, W=%0d, WW=%0d) ==", Q, N, W, WW);
    // Case 1: mix of negatives, wrap, in-range
    in_vec[0] = -1;
    in_vec[1] = -20;
    in_vec[2] = 0;
    in_vec[3] = 5;
    in_vec[4] = 7710-1;
    in_vec[5] = 7710;
    in_vec[6] = 7710+1;
    in_vec[7] = 9041;     

    // Expected mod 7710: [7709, 7690, 0, 5, 7709, 0, 1, 1331]
    exp[0]=7709; exp[1]=7690; exp[2]=0; exp[3]=5;
    exp[4]=7709; exp[5]=0;    exp[6]=1; exp[7]=1331;

    #1;
    check_vec("case1", out_vec, exp);

    // Case 2: all zeros
    for (int i = 0; i < N; i++) in_vec[i] = '0;
    for (int i = 0; i < N; i++) exp[i]    = '0;

    #1;
    check_vec("case2", out_vec, exp);
    $display("PASS: mod_vector produced expected outputs for 2 cases.");
    $finish;
  end
endmodule
