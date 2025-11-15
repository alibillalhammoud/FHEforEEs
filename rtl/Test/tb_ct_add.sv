`timescale 1ns/1ps
`define N_SLOTS 8
`define W_BITS  16
`define Q_MOD   16'd7710
`define T_MOD   16'd257
`define DELTA   16'd30
`include "verilog/types.svh"
module tb_ct_add;
  localparam int N = N_SLOTS_L;
  CT_t in1, in2, out;
  ct_ct_add #(.N(N_SLOTS_L), .W(W_BITS_L), .QP(16'd7710)) dut (
    .in_ct1 (in1),
    .in_ct2 (in2),
    .out_ct (out)
  );
  CT_t exp;

  task automatic check_equal_vec(string tag, vec_t a, vec_t b);
    for (int i = 0; i < N; i++) begin
      if (a[i] !== b[i]) begin
        $error("[%s] slot %0d mismatch: got=%0d exp=%0d", tag, i, a[i], b[i]);
        $fatal;
      end
    end
  endtask

  initial begin
    // Cipher 1
    $display("== CT + CT fixed-vector test (q=7710, n=8) ==");
    in1.A[0]=1429; in1.A[1]=4717; in1.A[2]=6311; in1.A[3]=3279;
    in1.A[4]=7215; in1.A[5]=6215; in1.A[6]=6931; in1.A[7]=973;
    in1.B[0]=7531; in1.B[1]=4381; in1.B[2]=1094; in1.B[3]=7529;
    in1.B[4]=5909; in1.B[5]=964;  in1.B[6]=5576; in1.B[7]=4640;

    // Cipher 2
    in2.A[0]=1081; in2.A[1]=592;  in2.A[2]=951;  in2.A[3]=5762;
    in2.A[4]=2873; in2.A[5]=4;    in2.A[6]=152;  in2.A[7]=3013;
    in2.B[0]=1577; in2.B[1]=3917; in2.B[2]=6039; in2.B[3]=6187;
    in2.B[4]=2056; in2.B[5]=6280; in2.B[6]=1531; in2.B[7]=7656;

    // Expected
    exp.A[0]=2510; exp.A[1]=5309; exp.A[2]=7262; exp.A[3]=1331;
    exp.A[4]=2378; exp.A[5]=6219; exp.A[6]=7083; exp.A[7]=3986;
    exp.B[0]=1398; exp.B[1]=588;  exp.B[2]=7133; exp.B[3]=6006;
    exp.B[4]=255;  exp.B[5]=7244; exp.B[6]=7107; exp.B[7]=4586;
    #1;
    check_equal_vec("A", out.A, exp.A);
    check_equal_vec("B", out.B, exp.B);
    $display("PASS: ct_ct_add produced expected output.");
    $finish;
  end
endmodule
