`timescale 1ns/1ps
`include "types.svh"

module tb_cpu;

  logic clk, reset;
  operation op;
  logic done_out;

  // Instantiate DUT
  cpu u_cpu (
    .clk      (clk),
    .reset    (reset),
    .op       (op),
    .done_out (done_out)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;

    // Wait until done_out == 1
  task wait_done_add(input string label);
    @(posedge clk);
    op.mode = NO_OP;
    while (!done_out) @(posedge clk);
    @(posedge clk); // allow writeback to settle
  endtask

  task wait_done_mul(input string label);
    int cycle;
    cycle = 0;

    while (!done_out && cycle < 500) begin
      

      // $display("[%0t] [%s] cyc=%0d  stage=%0d  stage1_valid=%0b  stage1_op_mode=%0d",
      //           $time, label, cycle,
      //           u_cpu.stage,
      //           u_cpu.stage1_valid,
      //           u_cpu.stage1_op_mode);

      // $display("ntt_1_start=%0b ntt_2_start=%0b  ntt_1_valid_in=%0b ntt_2_valid_in=%0b",
      //           u_cpu.ntt_1_start,
      //           u_cpu.ntt_2_start,
      //           u_cpu.ntt_1_valid_in,
      //           u_cpu.ntt_2_valid_in);

      // $display("         ntt_1_valid_out=%0b ntt_2_valid_out=%0b  doing_ntt=%0b",
      //           u_cpu.ntt_1_valid_out,
      //           u_cpu.ntt_2_valid_out,
      //           u_cpu.doing_ntt);

      // $display("         dest0_valid_q=%0b dest1_valid_q=%0b  done_internal=%0b done_out=%0b\n",
      //           u_cpu.dest0_valid_q,
      //           u_cpu.dest1_valid_q,
      //           u_cpu.done,
      //           done_out);

      @(posedge clk);
      op.mode = NO_OP;
      cycle++;

    end

    if (!done_out) begin
      $display("[TIMEOUT] %s: done_out never went high after %0d cycles", label, cycle);
      $display("          Final: stage=%0d stage1_op_mode=%0d doing_ntt=%0b ntt_1_valid_out=%0b ntt_2_valid_out=%0b\n",
               u_cpu.stage,
               u_cpu.stage1_op_mode,
               u_cpu.doing_ntt,
               u_cpu.ntt_1_valid_out,
               u_cpu.ntt_2_valid_out);
    end else begin
      $display("[DONE] %s completed at %0t  (stage=%0d)\n",
               label, $time, u_cpu.stage);
    end

    @(posedge clk); // allow WB to settle
  endtask


  // ================================
  // Task: Compare two polynomials
  // Returns 1 if equal, 0 if mismatch
  // ================================
  function automatic logic compare_polys(string name, q_BASIS_poly act, q_BASIS_poly exp);
    logic match;
    int mismatches;
    match = 1'b1;
    mismatches = 0;
    
    foreach(act[slot]) begin
      foreach(act[slot][prime]) begin
        if (act[slot][prime] !== exp[slot][prime]) begin
          if (mismatches < 5) begin // Only show first 5 mismatches
            $display("[FAIL] %s mismatch at slot=%0d, prime=%0d. Act: %0d, Exp: %0d", 
                     name, slot, prime, act[slot][prime], exp[slot][prime]);
          end
          match = 1'b0;
          mismatches++;
        end
      end
    end
    
    if (mismatches > 5) begin
      $display("[FAIL] %s had %0d total mismatches (only first 5 shown)", name, mismatches);
    end
    
    compare_polys = match;
  endfunction

  // ================================
  // Helper: Modular addition
  // ================================
  function automatic rns_residue_t mod_add(rns_residue_t a, rns_residue_t b, rns_residue_t modulus);
    wide_rns_residue_t sum;
    sum = a + b;
    if (sum >= modulus) sum = sum - modulus;
    mod_add = sum[`RNS_PRIME_BITS-1:0];
  endfunction

  // ================================
  // Helper: Modular multiplication
  // ================================
  function automatic rns_residue_t mod_mul(rns_residue_t a, rns_residue_t b, rns_residue_t modulus);
    wide_rns_residue_t prod;
    prod = a * b;
    mod_mul = prod % modulus;
  endfunction

  // =========================================================
  // Main Test Sequence
  // =========================================================
  initial begin
    int i, j;
    
    // Test vectors - using simple values for easy verification
    q_BASIS_poly CT1_A, CT1_B, CT2_A, CT2_B, PT;
    q_BASIS_poly outA, outB;
    q_BASIS_poly gold_A, gold_B;
    logic match_A, match_B;
    
    // Initialize test vectors with simple patterns
    foreach(CT1_A[slot]) begin
      foreach(CT1_A[slot][prime]) begin
        CT1_A[slot][prime] = 5;
        CT1_B[slot][prime] = 10;
        CT2_A[slot][prime] = 7;
        CT2_B[slot][prime] = 3;
        PT[slot][prime]    = 4;
      end
    end

    // Initialize signals
    op = '0;
    reset = 1;
    
    @(posedge clk);
    @(posedge clk);
    reset = 0;
    @(posedge clk);
    @(posedge clk);

    $display("==== Starting CPU Testbench ====\n");

    // =======================================================
    // Preload Register File
    // REG[0] = CT1.A
    // REG[1] = CT1.B
    // REG[2] = CT2.A
    // REG[3] = CT2.B
    // REG[4] = PT
    // =======================================================
    u_cpu.u_rf_q.mem[0] = CT1_A;
    u_cpu.u_rf_q.mem[1] = CT1_B;
    u_cpu.u_rf_q.mem[2] = CT2_A;
    u_cpu.u_rf_q.mem[3] = CT2_B;
    u_cpu.u_rf_q.mem[4] = PT;
    
    $display("Register file preloaded:");
    $display("  REG[0] (CT1.A): sample value = %0d", u_cpu.u_rf_q.mem[0][0][0]);
    $display("  REG[1] (CT1.B): sample value = %0d", u_cpu.u_rf_q.mem[1][0][0]);
    $display("  REG[2] (CT2.A): sample value = %0d", u_cpu.u_rf_q.mem[2][0][0]);
    $display("  REG[3] (CT2.B): sample value = %0d", u_cpu.u_rf_q.mem[3][0][0]);
    $display("  REG[4] (PT):    sample value = %0d\n", u_cpu.u_rf_q.mem[4][0][0]);

    // =======================================================
    // TEST 1: CT-CT ADD
    // out = CT1 + CT2
    // Expected: outA = CT1.A + CT2.A, outB = CT1.B + CT2.B
    // =======================================================
    $display("==== TEST 1: CT-CT ADD ====");
    
    op.mode   = OP_CT_CT_ADD;
    op.idx1_a = 0; // CT1.A
    op.idx1_b = 1; // CT1.B
    op.idx2_a = 2; // CT2.A
    op.idx2_b = 3; // CT2.B
    op.out_a  = 5; // result.A stored in reg[5]
    op.out_b  = 6; // result.B stored in reg[6]

    wait_done_add("CT-CT ADD");

    // Read results
    outA = u_cpu.u_rf_q.mem[5];
    outB = u_cpu.u_rf_q.mem[6];

    // Compute expected results with proper modular arithmetic
    foreach(gold_A[slot]) begin
      foreach(gold_A[slot][prime]) begin
        gold_A[slot][prime] = mod_add(CT1_A[slot][prime], CT2_A[slot][prime], q_BASIS[prime]);
        gold_B[slot][prime] = mod_add(CT1_B[slot][prime], CT2_B[slot][prime], q_BASIS[prime]);
      end
    end

    // Compare results
    match_A = compare_polys("CT-CT ADD (A)", outA, gold_A);
    match_B = compare_polys("CT-CT ADD (B)", outB, gold_B);

    if (match_A && match_B) begin
      $display("[PASS] CT-CT ADD test passed!\n");
      $display("  Result A[0][0] = %0d (expected %0d)", outA[0][0], gold_A[0][0]);
      $display("  Result B[0][0] = %0d (expected %0d)\n", outB[0][0], gold_B[0][0]);
    end else begin
      $display("[FAIL] CT-CT ADD test failed!\n");
    end

    // =======================================================
    // TEST 2: CT-PT ADD
    // CT_out.A = CT1.A (unchanged)
    // CT_out.B = CT1.B + PT
    // =======================================================
    $display("==== TEST 2: CT-PT ADD ====");
    
    op.mode   = OP_CT_PT_ADD;
    op.idx1_a = 0; // CT1.A (passes through)
    op.idx1_b = 1; // CT1.B (gets PT added)
    op.idx2_a = 0; // unused for PT add (A passthrough)
    op.idx2_b = 4; // PT (to be added to B)
    op.out_a  = 7; // result.A stored in reg[7]
    op.out_b  = 8; // result.B stored in reg[8]

    wait_done_add("CT-PT ADD");
    // @(posedge clk);
    // @(posedge clk);
    // $display("op_a: %0d, op_b: %0d", u_cpu.op_a_q[0][0], u_cpu.op_b_q[0][0]); 
    // $display("op_c: %0d, op_d: %0d", u_cpu.op_c_q[0][0], u_cpu.op_d_q[0][0]); 
    // $display("Add_out_1: %0d, Add_out_2: \n", u_cpu.add_out_1[0][0], u_cpu.add_out_2[0][0]); 
    // @(posedge clk);
    // @(posedge clk);
    // @(posedge clk);
    // $display(" Done: %0b\n", done_out);

    // Read results
    outA = u_cpu.u_rf_q.mem[7];
    outB = u_cpu.u_rf_q.mem[8];

    // Compute expected results
    // A should pass through unchanged
    gold_A = CT1_A;
    
    // B should be CT1.B + (PT * DELTA)
    // DELTA_i = q_i / t for each prime q_i
    foreach(gold_B[slot]) begin
      foreach(gold_B[slot][prime]) begin        

        gold_B[slot][prime] = mod_add(CT1_B[slot][prime], PT[slot][prime], q_BASIS[prime]);

      end
    end

    // Compare results
    match_A = compare_polys("CT-PT ADD (A)", outA, gold_A);
    match_B = compare_polys("CT-PT ADD (B)", outB, gold_B);

    if (match_A && match_B) begin
      $display("[PASS] CT-PT ADD test passed!\n");
      $display("  Result A[0][0] = %0d (expected %0d - passthrough)", outA[0][0], gold_A[0][0]);
      $display("  Result B[0][0] = %0d (expected %0d)\n", outB[0][0], gold_B[0][0]);
    end else begin
      $display("[FAIL] CT-PT ADD test failed!\n");
    end

    // =======================================================
    // TEST 3: CT-PT MUL
    // CT_out.A = CT1.A * PT
    // CT_out.B = CT1.B * PT
    // (per-slot, per-prime multiplication mod q_BASIS[prime])
    // =======================================================
    $display("==== TEST 3: CT-PT MUL ====");
    
    op.mode   = OP_CT_PT_MUL;
    op.idx1_a = 0;  // CT1.A
    op.idx1_b = 1;  // CT1.B
    op.idx2_a = 0;  // unused in your controller for MUL path
    op.idx2_b = 4;  // PT
    op.out_a  = 9;  // result.A -> REG[9]
    op.out_b  = 10; // result.B -> REG[10]

    $display("[T3] Issued CT-PT MUL: idx1_a=%0d idx1_b=%0d idx2_b(PT)=%0d out_a=%0d out_b=%0d",
             op.idx1_a, op.idx1_b, op.idx2_b, op.out_a, op.out_b);

    wait_done_mul("CT-PT MUL");

    // Read back results from regfile
    outA = u_cpu.u_rf_q.mem[9];
    outB = u_cpu.u_rf_q.mem[10];

    // Compute expected results: CT1.* * PT (mod q_BASIS)
    foreach (gold_A[slot]) begin
      foreach (gold_A[slot][prime]) begin
        gold_A[slot][prime] = mod_mul(CT1_A[slot][prime],  PT[slot][prime],  q_BASIS[prime]);
        gold_B[slot][prime] = mod_mul(CT1_B[slot][prime],  PT[slot][prime],  q_BASIS[prime]);
      end
    end

    // Compare results
    match_A = compare_polys("CT-PT MUL (A)", outA, gold_A);
    match_B = compare_polys("CT-PT MUL (B)", outB, gold_B);

    if (match_A && match_B) begin
      $display("[PASS] CT-PT MUL test passed!\n");
      $display("  Result A[0][0] = %0d (expected %0d)", outA[0][0], gold_A[0][0]);
      $display("  Result B[0][0] = %0d (expected %0d)\n", outB[0][0], gold_B[0][0]);
    end else begin
      $display("[FAIL] CT-PT MUL test failed!\n");
    end

    // =======================================================
    // Summary
    // =======================================================
    $display("==== TESTBENCH FINISHED ====");
    $display("All tests completed.\n");
    
    #100;
    $finish;
  end

endmodule