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

// =========================================================
  // Task: write regfile entry (Backdoor access to 4D Memory)
  // =========================================================
  task write_reg(input int cipher_idx, input vec_t A, input vec_t B);
    // We refer to the DUT parameters to ensure loop bounds match the HW definition
    // Accessing u_cpu.u_rf allows us to use the specific NCOEFF/NPRIMES of that instance
    int flat_idx;

    for (int c = 0; c < NCOEFF; c++) begin
      for (int p = 0; p < NPRIMES; p++) begin
        
        // Calculate the flat index for vec_t
        // Must match the logic in regfile: flat_idx = c * NPRIMES + p
        flat_idx = c * NPRIMES + p;

        // Write Poly 0 (A)
        // mem[cipher][poly][coeff][prime]
        u_cpu.u_rf.mem[cipher_idx][0][c][p] = A[flat_idx];

        // Write Poly 1 (B)
        u_cpu.u_rf.mem[cipher_idx][1][c][p] = B[flat_idx];
      end
    end
  endtask

  // =========================================================
  // Task: read regfile entry (Backdoor access to 4D Memory)
  // =========================================================
  task read_reg(input int cipher_idx, output vec_t A, output vec_t B);
    int flat_idx;

    // Initialize defaults to avoid X propagation if partial reads occur
    A = '{default: '0};
    B = '{default: '0};

    for (int c = 0; c < NCOEFF; c++) begin
      for (int p = 0; p < NPRIMES; p++) begin
        
        // Calculate the flat index
        flat_idx = c * NPRIMES + p;

        // Read Poly 0 (A)
        A[flat_idx] = u_cpu.u_rf.mem[cipher_idx][0][c][p];

        // Read Poly 1 (B)
        B[flat_idx] = u_cpu.u_rf.mem[cipher_idx][1][c][p];
      end
    end
  endtask

  // Wait until done_out == 1
  task wait_done();
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    // while (!done_out) @(posedge clk);
    @(posedge clk); // allow writeback to settle
  endtask

  // ================================
  // Task: Compare two vectors
  // Returns 1 if equal, 0 if mismatch
  // ================================
  function automatic logic compare_vecs(string name, vec_t act, vec_t exp);
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

    vec_t CT1_A = '{default: 5};
    vec_t CT1_B = '{default: 10};
    vec_t CT2_A = '{default: 7};
    vec_t CT2_B = '{default: 3};

    vec_t PT   = '{default: 4};   // plaintext
    vec_t DELTA = '{default: `DELTA};
    vec_t outA, outB;
    vec_t gold_A, gold_B;
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

    write_reg(0, CT1_A, CT1_B);
    write_reg(1, CT2_A, CT2_B);
    write_reg(2, PT, '{default:0});

    $display("==== Starting CPU Testbench ====");

    // =======================================================
    // TEST 1: CT-CT ADD
    // out = CT1 + CT2
    // =======================================================

    op.mode  = OP_CT_CT_ADD;
    op.idx1_a = 0; // CT1.A
    op.idx1_b = 0; // CT1.B
    op.idx2_a = 1; // CT2.A
    op.idx2_b = 1; // CT2.B
    op.out_a  = 3; // result stored in reg3
    op.out_b  = 3; // both A and B of reg3

    @(posedge clk);
    wait_done();

    
    read_reg(3, outA, outB);

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