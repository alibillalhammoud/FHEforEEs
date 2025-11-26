`timescale 1ns/1ps
`include "types.svh"

module tb_regfile;

  // -----------------------------
  // Declarations
  // -----------------------------

  // Clock and reset
  logic clk;
  logic reset;

  // DUT I/O wires
  logic register_file_ready;

  logic                    start_operation;
  logic [$clog2(NREG)-1:0] source0_register_index;
  logic [$clog2(NREG)-1:0] source1_register_index;
  logic [$clog2(NREG)-1:0] destination_register_index;
  logic                    use_source1;

  logic   source0_valid;
  coeff_t source0_coefficient;
  logic   source0_last;

  logic   source1_valid;
  coeff_t source1_coefficient;
  logic   source1_last;

  logic   destination_valid;
  coeff_t destination_coefficient;
  logic   destination_last;

  // simple counters just so we see how many items flowed
  integer source0_count;
  integer source1_count;
  integer destination_count;
  integer source0_last_count;
  integer source1_last_count;

  // error counter for PASS/FAIL
  integer errors;

  // expected number of stream elements per poly (coeff * prime)
  localparam int TOTAL_ELEMS = NCOEFF * NPRIMES;

  // loop vars for init / dump
  integer c, p;

  // -----------------------------
  // Instantiate DUT
  // -----------------------------
  regfile dut (
    .clk                         (clk),
    .reset                       (reset),
    .register_file_ready         (register_file_ready),
    .start_operation             (start_operation),
    .source0_register_index      (source0_register_index),
    .source1_register_index      (source1_register_index),
    .destination_register_index  (destination_register_index),
    .use_source1                 (use_source1),
    .source0_valid               (source0_valid),
    .source0_coefficient         (source0_coefficient),
    .source0_last                (source0_last),
    .source1_valid               (source1_valid),
    .source1_coefficient         (source1_coefficient),
    .source1_last                (source1_last),
    .destination_valid           (destination_valid),
    .destination_coefficient     (destination_coefficient),
    .destination_last            (destination_last)
  );

  // -----------------------------
  // Clock: 10 ns period
  // -----------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // -----------------------------
  // Reset + regfile init
  // -----------------------------
  initial begin
    reset                      = 1;
    start_operation            = 0;
    use_source1                = 0;
    source0_register_index     = '0;
    source1_register_index     = '0;
    destination_register_index = '0;
    errors                     = 0;

    // hold reset for a few cycles
    repeat (5) @(posedge clk);
    reset = 0;

    // Give one cycle after reset deassert
    @(posedge clk);

    // ----------------------------
    // Initialize R0 and R1 in DUT
    // ----------------------------
    $display("[%0t] Initializing R0 and R1 in regfile memory", $time);
    for (c = 0; c < NCOEFF; c = c + 1) begin
      for (p = 0; p < NPRIMES; p = p + 1) begin
        // R0
        dut.mem[0][0][c][p] = coeff_t'(c + p);
        // R1
        dut.mem[0][1][c][p] = coeff_t'((c << 2) + p + 10);
      end
    end

    $display("[%0t] Done initializing regfile", $time);
  end

  // ---------------------------------------------------
  // "Fake FU" – combinational: add or forward
  // ---------------------------------------------------
  always @* begin
    destination_valid       = 1'b0;
    destination_coefficient = '0;
    destination_last        = 1'b0;

    if (!reset) begin
      if (use_source1) begin
        if (source0_valid && source1_valid) begin
          destination_valid       = 1'b1;
          destination_coefficient = source0_coefficient + source1_coefficient;
          destination_last        = source0_last && source1_last;
        end
      end else begin
        if (source0_valid) begin
          destination_valid       = 1'b1;
          destination_coefficient = source0_coefficient;
          destination_last        = source0_last;
        end
      end
    end
  end

  // ---------------------------------------------------
  // Counters – just for visibility
  // ---------------------------------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      source0_count      <= 0;
      source1_count      <= 0;
      destination_count  <= 0;
      source0_last_count <= 0;
      source1_last_count <= 0;
    end else begin
      if (source0_valid)
        source0_count <= source0_count + 1;
      if (source0_valid && source0_last)
        source0_last_count <= source0_last_count + 1;

      if (source1_valid)
        source1_count <= source1_count + 1;
      if (source1_valid && source1_last)
        source1_last_count <= source1_last_count + 1;

      if (destination_valid)
        destination_count <= destination_count + 1;
    end
  end

  // ---------------------------------------------------
  // Test procedure
  // ---------------------------------------------------
  initial begin
    // Wait until reset is deasserted and RF says it's ready
    @(negedge reset);
    @(posedge clk);
    wait (register_file_ready == 1'b1);
    $display("[%0t] Register file is ready", $time);

    // Use R0 and R1 as inputs, write result into R2
    use_source1                = 1'b1;   // binary op
    source0_register_index     = 'd0;    // reg 0  (cipher0.A)
    source1_register_index     = 'd1;    // reg 0, poly B
    destination_register_index = 'd2;    // reg 1, poly A

    @(posedge clk);
    start_operation = 1'b1;
    @(posedge clk);
    start_operation = 1'b0;
    $display("[%0t] Started operation: R0 + R1 -> R2", $time);

    // Wait until regfile says this stream is finished
    wait (destination_valid && destination_last);
    $display("[%0t] Destination stream finished (binary op)", $time);

    // one extra cycle to settle
    @(posedge clk);

    // Dump some stats
    $display("--------------------------------------------------");
    $display("NCOEFF    = %0d", NCOEFF);
    $display("NPRIMES   = %0d", NPRIMES);
    $display("TOTAL_ELEMS (per poly) = %0d", TOTAL_ELEMS);
    $display("source0_count      = %0d", source0_count);
    $display("source1_count      = %0d", source1_count);
    $display("destination_count  = %0d", destination_count);
    $display("source0_last_count = %0d", source0_last_count);
    $display("source1_last_count = %0d", source1_last_count);
    $display(" (Counts are sanity-only; may be off by 1 due to sampling.)");
    $display("--------------------------------------------------");

    // -----------------------------------------
    // Check a few residues in R2 for correctness
    // R2 -> cipher 1, poly 0 (since NPOLY=2)
    // expected pattern: R0(c,p) + R1(c,p)
    //   R0(c,p) = c + p
    //   R1(c,p) = (c << 2) + p + 10
    // => expected = 5*c + 2*p + 10
    // -----------------------------------------
    $display("First few coeff/prime residues of R2:");
    for (c = 0; c < (NCOEFF < 2 ? NCOEFF : 2); c = c + 1) begin
      for (p = 0; p < NPRIMES; p = p + 1) begin
        int expected;
        expected = 5*c + 2*p + 10;

        $display("  R2: coeff %0d, prime %0d -> %0d (expected %0d)",
                 c, p, dut.mem[1][0][c][p], expected);

        if (dut.mem[1][0][c][p] !== coeff_t'(expected)) begin
          $display("ERROR: R2 mismatch at coeff %0d prime %0d: got %0d, expected %0d",
                   c, p, dut.mem[1][0][c][p], expected);
          errors = errors + 1;
        end
      end
    end

    $display("==================================================");
    if (errors == 0) begin
      $display("************ ALL TESTS PASSED (functional) ************");
    end else begin
      $display("************ TEST FAILED: %0d functional errors ************", errors);
    end
    $display("==================================================");

    $finish;
  end

endmodule
