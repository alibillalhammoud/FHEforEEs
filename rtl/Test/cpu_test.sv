`timescale 1ns/1ps
`include "types.svh"

module cpu_test;

  // -----------------------------
  // DUT interface
  // -----------------------------
  logic     clk;
  logic     reset;
  operation op;
  logic     done_out;

  // Instantiate CPU
  cpu dut (
    .clk      (clk),
    .reset    (reset),
    .op       (op),
    .done_out (done_out)
  );

  // -----------------------------
  // Params / vars
  // -----------------------------
  localparam integer TOTAL_ELEMS = NCOEFF * NPRIMES;

  integer c, p;
  integer errors;
  integer ct0_cipher, ct1_cipher, out_cipher;

  // -----------------------------
  // Clock
  // -----------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // -----------------------------
  // Main test
  // -----------------------------
  initial begin
    // init
    reset       = 1'b1;
    op          = '0;
    errors      = 0;
    ct0_cipher  = 0;
    ct1_cipher  = 1;
    out_cipher  = 2;

    // hold reset
    repeat (5) @(posedge clk);
    reset = 1'b0;
    @(posedge clk);

    // ------------------------------------
    // Initialize CT0, CT1 in regfile mem
    // ------------------------------------
    $display("[%0t] Initializing regfile memories", $time);
    for (c = 0; c < NCOEFF; c = c + 1) begin
      for (p = 0; p < NPRIMES; p = p + 1) begin
        // CT0 (cipher 0)
        dut.u_rf.init_mem_entry(ct0_cipher, 0, c, p, coeff_t'(10 + c + p));     // A
        dut.u_rf.init_mem_entry(ct0_cipher, 1, c, p, coeff_t'(20 + 2*c + p));   // B

        // CT1 (cipher 1)
        dut.u_rf.init_mem_entry(ct1_cipher, 0, c, p, coeff_t'(30 + c + 2*p));   // A
        dut.u_rf.init_mem_entry(ct1_cipher, 1, c, p, coeff_t'(40 + 3*c + 2*p)); // B

      end
    end

    // ==================================================
    // Test 1: CT–CT ADD  (CT0 + CT1 -> CT2)
    // ==================================================
    $display("[%0t] Starting CT-CT ADD test", $time);

    op.mode   = OP_CT_CT_ADD;
    op.idx1_a = ct0_cipher*NPOLY + 0; // CT0.A
    op.idx1_b = ct0_cipher*NPOLY + 1; // CT0.B
    op.idx2_a = ct1_cipher*NPOLY + 0; // CT1.A
    op.idx2_b = ct1_cipher*NPOLY + 1; // CT1.B

    out_cipher = 2;
    op.out_a   = out_cipher*NPOLY + 0; // CT2.A
    op.out_b   = out_cipher*NPOLY + 1; // CT2.B

    // No need to poke start_operation anymore; regfile is always "ready"
    @(posedge clk);

    // Wait for all residues (overkill now, but safe)
    repeat (TOTAL_ELEMS + 20) @(posedge clk);

    // Check a few residues in CT2
    $display("[%0t] Checking CT-CT ADD result (CT2)", $time);
    for (c = 0; c < (NCOEFF < 2 ? NCOEFF : 2); c = c + 1) begin
      for (p = 0; p < NPRIMES; p = p + 1) begin
        integer exp_a, exp_b;
        integer a0, b0, a1, b1;
        integer ra, rb;

        a0 = dut.u_rf.mem[ct0_cipher][0][c][p];
        b0 = dut.u_rf.mem[ct0_cipher][1][c][p];
        a1 = dut.u_rf.mem[ct1_cipher][0][c][p];
        b1 = dut.u_rf.mem[ct1_cipher][1][c][p];

        ra = dut.u_rf.mem[out_cipher][0][c][p];
        rb = dut.u_rf.mem[out_cipher][1][c][p];

        exp_a = a0 + a1;
        exp_b = b0 + b1;

        if (ra !== coeff_t'(exp_a)) begin
          $display("ERROR CT-CT A: coeff %0d prime %0d got %0d exp %0d",
                   c, p, ra, exp_a);
          errors = errors + 1;
        end
        if (rb !== coeff_t'(exp_b)) begin
          $display("ERROR CT-CT B: coeff %0d prime %0d got %0d exp %0d",
                   c, p, rb, exp_b);
          errors = errors + 1;
        end
      end
    end

    // ==================================================
    // Test 2: CT–PT ADD
    // ==================================================
    $display("[%0t] Starting CT-PT ADD test", $time);

    op.mode   = OP_CT_PT_ADD;

    // idx1_a -> A path (pass-through)
    op.idx1_a = ct0_cipher*NPOLY + 0; // CT0.A

    // idx2_a -> B path (+ DELTA_L)
    op.idx2_a = ct0_cipher*NPOLY + 1; // CT0.B

    // idx1_b / idx2_b unused in this mode
    op.idx1_b = '0;
    op.idx2_b = '0;

    out_cipher = 3;
    op.out_a   = out_cipher*NPOLY + 0; // CT3.A
    op.out_b   = out_cipher*NPOLY + 1; // CT3.B

    @(posedge clk);

    repeat (TOTAL_ELEMS + 20) @(posedge clk);

    // Check CT3
    $display("[%0t] Checking CT-PT ADD result (CT3)", $time);
    for (c = 0; c < (NCOEFF < 2 ? NCOEFF : 2); c = c + 1) begin
      for (p = 0; p < NPRIMES; p = p + 1) begin
        integer a_in, b_in;
        integer a_out, b_out;
        integer exp_a2, exp_b2;

        a_in  = dut.u_rf.mem[ct0_cipher][0][c][p]; // CT0.A
        b_in  = dut.u_rf.mem[ct0_cipher][1][c][p]; // CT0.B
        a_out = dut.u_rf.mem[out_cipher][0][c][p]; // CT3.A
        b_out = dut.u_rf.mem[out_cipher][1][c][p]; // CT3.B

        exp_a2 = a_in;
        exp_b2 = b_in + DELTA_L;

        if (a_out !== coeff_t'(exp_a2)) begin
          $display("ERROR CT-PT A: coeff %0d prime %0d got %0d exp %0d",
                   c, p, a_out, exp_a2);
          errors = errors + 1;
        end

        if (b_out !== coeff_t'(exp_b2)) begin
          $display("ERROR CT-PT B: coeff %0d prime %0d got %0d exp %0d",
                   c, p, b_out, exp_b2);
          errors = errors + 1;
        end
      end
    end

    // ==================================================
    // Summary
    // ==================================================
    $display("=======================================");
    if (errors == 0) begin
      $display("CPU TEST PASSED (CT-CT + CT-PT add)");
    end else begin
      $display("CPU TEST FAILED with %0d errors", errors);
    end
    $display("=======================================");

    $finish;
  end

endmodule
