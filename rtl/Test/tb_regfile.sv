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

  // -----------------------------
  // Instantiate DUT
  // (change regfile -> regfile_big if that's your module name)
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
  // Clock generation: 10ns period
  // -----------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // -----------------------------
  // Reset sequence
  // -----------------------------
  initial begin
    reset                      = 1;
    start_operation            = 0;
    use_source1                = 0;
    source0_register_index     = '0;
    source1_register_index     = '0;
    destination_register_index = '0;

    // Hold reset for a few cycles
    repeat (5) @(posedge clk);
    reset = 0;
  end

  // ---------------------------------------------------
  // "Fake FU" – COMBINATIONAL
  // Drives destination_* directly from source*_*
  // ---------------------------------------------------
  always @* begin
    // defaults
    destination_valid       = 1'b0;
    destination_coefficient = '0;
    destination_last        = 1'b0;

    if (!reset) begin
      if (use_source1) begin
        // Binary op: only produce output when both inputs are valid
        if (source0_valid && source1_valid) begin
          destination_valid       = 1'b1;
          destination_coefficient = source0_coefficient + source1_coefficient;
          destination_last        = source0_last && source1_last;
        end
      end else begin
        // Unary op: just forward source0
        if (source0_valid) begin
          destination_valid       = 1'b1;
          destination_coefficient = source0_coefficient;
          destination_last        = source0_last;
        end
      end
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

    // -------------------------------------------------
    // Binary operation: source0 = R0, source1 = R1, dest = R2
    // -------------------------------------------------
    use_source1                = 1'b1;   // binary op
    source0_register_index     = 'd0;    // register 0
    source1_register_index     = 'd1;    // register 1
    destination_register_index = 'd2;    // register 2

    @(posedge clk);
    start_operation = 1'b1;
    @(posedge clk);
    start_operation = 1'b0;
    $display("[%0t] Started operation: R0 + R1 -> R2", $time);

    // Wait until destination_last is seen once
    wait (destination_valid && destination_last);
    $display("[%0t] Destination stream finished (binary op)", $time);

    // One extra cycle just because
    @(posedge clk);

    $display("==================================================");
    $display(" TB DONE: regfile streamed data and accepted result.");
    $display("==================================================");

    $finish;
  end

endmodule
