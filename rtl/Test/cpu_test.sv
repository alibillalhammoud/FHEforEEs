`timescale 1ns/1ps
`include "types.svh"

module tb_cpu;

  logic clk, reset;
  operation op;
  logic done_out;

  // Instantiate DUT
  cpu u_cpu (
    .clk   (clk),
    .reset (reset),
    .op    (op),
    .done_out(done_out)
  );

  // Clock
  always #5 clk = ~clk;

  // Wait until done_out == 1
  task wait_done();
    while (!done_out) @(posedge clk);
    @(posedge clk); // allow writeback to settle
  endtask

  // ================================
  // Task: Compare two vectors
  // Returns 1 if equal, 0 if mismatch
  // ================================
  function automatic logic compare_vecs(string name, q_BASIS_poly act, q_BASIS_poly exp);
    compare_vecs = 1'b1;
    foreach(act[i]) begin
      if (act[i] !== exp[i]) begin
        $display("[FAIL] %s mismatch at index %0d. Act: %0d, Exp: %0d", 
                 name, i, act[i], exp[i]);
        compare_vecs = 1'b0;
        // Optional: break; // Stop at first error
      end
    end
  endfunction

  // =========================================================
  // Main Test Sequence
  // =========================================================
  initial begin

    q_BASIS_poly CT1_A = '{default: 5};
    q_BASIS_poly CT1_B = '{default: 10};
    q_BASIS_poly CT2_A = '{default: 7};
    q_BASIS_poly CT2_B = '{default: 3};

    q_BASIS_poly PT   = '{default: 4};   // plaintext
    q_BASIS_poly outA, outB;
    q_BASIS_poly gold_A, gold_B;
    logic match_A, match_B;

    clk = 0;
    reset = 1;
    op = '0;
    
    reset = 0;
    repeat(5) @(posedge clk);
    

    // =======================================================
    // Preload Register File
    // REG0 = CT1
    // REG1 = CT2
    // REG2 = PT
    // =======================================================

    u_cpu.u_rf_q.mem[0] = CT1_A;
    u_cpu.u_rf_q.mem[1] = CT1_B;
    u_cpu.u_rf_q.mem[2] = CT2_A;
    u_cpu.u_rf_q.mem[3] = CT2_B;
    u_cpu.u_rf_q.mem[4] = PT;

    $display("==== Starting CPU Testbench ====");

    // =======================================================
    // TEST 1: CT-CT ADD
    // out = CT1 + CT2
    // =======================================================

    op.mode  = OP_CT_CT_ADD;
    op.idx1_a = 0; // CT1.A
    op.idx1_b = 1; // CT1.B
    op.idx2_a = 2; // CT2.A
    op.idx2_b = 3; // CT2.B
    op.out_a  = 4; // result stored in reg3
    op.out_b  = 5; // both A and B of reg3

    @(posedge clk);
    wait_done();

    outA = u_cpu.u_rf_q.mem[4];
    outB = u_cpu.u_rf_q.mem[5];

    foreach(gold_A[i]) begin
        gold_A[i] = CT1_A[i] + CT2_A[i];
        gold_B[i] = CT1_B[i] + CT2_B[i];
    end

    match_A = compare_vecs("CT-CT ADD (A)", outA, gold_A);
    match_B = compare_vecs("CT-CT ADD (B)", outB, gold_B);

    if (match_A && match_B)
      $display("[PASS] CT-CT ADD correct.");
    else begin
      $display("[FAIL] CT-CT ADD mismatch!");
      $display(" expected A=%0d B=%0d", gold_A[0], gold_B[0]);
      $display(" actual   A=%0d B=%0d", outA[0], outB[0]);
    end

    // =======================================================
    // TEST 2: CT-PT ADD
    //
    // CT_out.A = CT.A
    // CT_out.B = CT.B + PT * DELTA
    // =======================================================

    // op.mode  = OP_CT_PT_ADD;
    // op.idx1_a = 0; // CT1.A
    // op.idx1_b = 0; // CT1.B
    // op.idx2_a = 2; // PT
    // op.idx2_b = 2; // PT
    // op.out_a  = 4; // result in reg4
    // op.out_b  = 4;

    // @(posedge clk);
    // wait_done();

    // read_reg(4, outA, outB);

    // gold_A = CT1_A;
    // gold_B = CT1_B + (PT * DELTA);

    // if (outA == gold_A && outB == gold_B)
    //   $display("[PASS] CT-PT ADD correct.");
    // else begin
    //   $display("[FAIL] CT-PT ADD mismatch!");
    //   $display(" expected A=%0d B=%0d", gold_A[0], gold_B[0]);
    //   $display(" actual   A=%0d B=%0d", outA[0], outB[0]);
    // end

    $display("==== TESTBENCH FINISHED ====");
    $finish;
  end

endmodule