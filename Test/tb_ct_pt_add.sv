`timescale 1ns/1ps

// Keep TB self-contained; widths big enough for q=7710
`define N_SLOTS 8
`define W_BITS  16
`define Q_MOD   16'd7710
`define T_MOD   16'd257
`define DELTA   16'd30

`include "verilog/types.svh"
// ct_pt_add compiled separately by the Makefile

module tb_ct_pt_add_fixed;
  localparam int N = N_SLOTS_L;

  // DUT ports
  CT_t in_ct, out_ct;
  PT_t gamma;

  // Instantiate DUT and PASS q, Δ explicitly
  ct_pt_add #(
    .N     (N_SLOTS_L),
    .W     (W_BITS_L),
    .WW    (2*W_BITS_L),
    .QP    (16'd7710),   // q
    .DELTAP(16'd30)      // Δ
  ) dut (
    .in_ct   (in_ct),
    .in_gamma(gamma),
    .out_ct  (out_ct)
  );

  // Expected container
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
    $display("== CT + (Δ·PT) fixed test (q=7710, Δ=30, n=8) ==");

    // ----- Cipher 1 (your A,B) -----
    in_ct.A[0]=1429; in_ct.A[1]=4717; in_ct.A[2]=6311; in_ct.A[3]=3279;
    in_ct.A[4]=7215; in_ct.A[5]=6215; in_ct.A[6]=6931; in_ct.A[7]=973;

    in_ct.B[0]=7531; in_ct.B[1]=4381; in_ct.B[2]=1094; in_ct.B[3]=7529;
    in_ct.B[4]=5909; in_ct.B[5]=964;  in_ct.B[6]=5576; in_ct.B[7]=4640;

    // ----- Plaintext Γ (choose any PT you like; this is simple) -----
    gamma[0]=1; gamma[1]=2; gamma[2]=3; gamma[3]=4;
    gamma[4]=5; gamma[5]=6; gamma[6]=7; gamma[7]=8;

    // ----- Expected -----
    // A' = A mod q (already < q -> unchanged)
    exp.A[0]=1429; exp.A[1]=4717; exp.A[2]=6311; exp.A[3]=3279;
    exp.A[4]=7215; exp.A[5]=6215; exp.A[6]=6931; exp.A[7]=973;

    // B' = (B + Δ·Γ) mod q  with Δ=30
    // Δ·Γ = [30,60,90,120,150,180,210,240]
    // B'  = [7561,4441,1184,7649,6059,1144,5786,4880]
    exp.B[0]=7561; exp.B[1]=4441; exp.B[2]=1184; exp.B[3]=7649;
    exp.B[4]=6059; exp.B[5]=1144; exp.B[6]=5786; exp.B[7]=4880;

    #1; // settle

    check_equal_vec("A", out_ct.A, exp.A);
    check_equal_vec("B", out_ct.B, exp.B);

    $display("PASS ✅  ct_pt_add produced expected output.");
    $finish;
  end
endmodule
