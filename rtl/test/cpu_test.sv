`timescale 1ns/1ps
`include "types.svh"
`include "ct_test_inputs.svh"


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
      @(posedge clk);
      op.mode = NO_OP;
      cycle++;

    end
    @(posedge clk); // allow WB to settle
  endtask

  // Compare two polynomials: Returns 1 if equal, 0 if mismatch
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


  // Main Test Sequence
  initial begin
    int i, j;
    
    // Test vectors - using simple values for easy verification
    q_BASIS_poly CT1_A, CT1_B, CT2_A, CT2_B, PT, SCALED_PT;
    q_BASIS_poly outA, outB;
    q_BASIS_poly gold_A, gold_B;
    logic match_A, match_B;
    q_BASIS_poly CTCT_OUT_A_GOLD, CTCT_OUT_B_GOLD;
    
    CT1_A = A1__INPUT;
    CT1_B = B1__INPUT;
    CT2_A = A2__INPUT;
    CT2_B = B2__INPUT;
    PT = PLAIN__TEXT;

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
    u_cpu.u_rf_q.mem[4] = PLAIN__TEXTSCALED_FORADD;

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

    // Compare results
    gold_A = CTCT_ADDA__GOLDRES;
    gold_B = CTCT_ADDB__GOLDRES;
    match_A = compare_polys("CT-CT ADD (A)", outA, CTCT_ADDA__GOLDRES);
    match_B = compare_polys("CT-CT ADD (B)", outB, CTCT_ADDB__GOLDRES);

    if (match_A && match_B) begin
      $display("[PASS] CT-CT ADD test passed!\n");
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

    // Read results
    outA = u_cpu.u_rf_q.mem[7];
    outB = u_cpu.u_rf_q.mem[8];
    // A should pass through unchanged
    gold_A = CT1_A;
    gold_B = PTCT_ADDB__GOLDRES;
    // Compare results
    match_A = compare_polys("CT-PT ADD (A)", outA, gold_A);
    match_B = compare_polys("CT-PT ADD (B)", outB, gold_B);

    if (match_A && match_B) begin
      $display("[PASS] CT-PT ADD test passed!\n");
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
    u_cpu.u_rf_q.mem[4] = PLAIN__TEXT;
    
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

    // Compare results
    match_A = compare_polys("CT-PT MUL (A)", outA, PTCT_MULA__GOLDRES);
    match_B = compare_polys("CT-PT MUL (B)", outB, PTCT_MULB__GOLDRES);

    if (match_A && match_B) begin
      $display("[PASS] CT-PT MUL test passed!\n");
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