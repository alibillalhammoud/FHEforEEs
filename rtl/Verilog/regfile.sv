`include "types.svh"

module regfile (
  input  logic clk,
  input  logic reset,

  // Goes high once reset is done and the RF can be used
  output logic register_file_ready,

  // ---------- control from CPU ----------

  // One–cycle pulse to start a new op (new poly read/write)
  input  logic                    start_operation,

  // Which registers are used for this op
  input  logic [$clog2(NREG)-1:0] source0_register_index,       // first input reg
  input  logic [$clog2(NREG)-1:0] source1_register_index,       // second input reg (if used)
  input  logic [$clog2(NREG)-1:0] destination_register_index,   // result goes here
  input  logic                    use_source1,                  // 0 = only src0, 1 = src0+src1

  // ---------- streams out to FUs ----------

  // Source 0: one coeff per cycle while source0_valid is high
  output logic   source0_valid,
  output coeff_t source0_coefficient,
  output logic   source0_last,      // 1 on last coeff

  // Source 1: same idea, only if use_source1 = 1
  output logic   source1_valid,
  output coeff_t source1_coefficient,
  output logic   source1_last,

  // ---------- stream back from FUs ----------

  // Result coeffs come back here, one per cycle
  input  logic   destination_valid,
  input  coeff_t destination_coefficient,
  input  logic   destination_last    // 1 on last result coeff
);

  // Register file contents: mem[reg][coeff_index]
  coeff_t mem [NREG][NCOEFF];

  // Simple "ready" flag – low in reset, high otherwise
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      register_file_ready <= 1'b0;
    end else begin
      register_file_ready <= 1'b1;
    end
  end

  // ------------------------------
  //  Read side (source0 / source1)
  // ------------------------------
  logic [$clog2(NCOEFF)-1:0] source0_index_q, source1_index_q;
  logic                      source0_active,   source1_active;
  logic [$clog2(NREG)-1:0]   source0_register_index_q, source1_register_index_q;

  // Track which regs we’re reading from and which coeff we’re on
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      source0_active             <= 1'b0;
      source1_active             <= 1'b0;
      source0_index_q            <= '0;
      source1_index_q            <= '0;
      source0_register_index_q   <= '0;
      source1_register_index_q   <= '0;
    end else begin
      if (start_operation) begin
        // New op: start src0 at coeff 0, and src1 if needed
        source0_active           <= 1'b1;
        source0_index_q          <= '0;
        source0_register_index_q <= source0_register_index;

        if (use_source1) begin
          source1_active           <= 1'b1;
          source1_index_q          <= '0;
          source1_register_index_q <= source1_register_index;
        end else begin
          source1_active           <= 1'b0;
          source1_index_q          <= '0;
        end
      end else begin
        // Walk through src0 coefficients
        if (source0_active) begin
          if (source0_index_q == NCOEFF-1) begin
            source0_active <= 1'b0;
          end else begin
            source0_index_q <= source0_index_q + 1;
          end
        end

        // Same for src1
        if (source1_active) begin
          if (source1_index_q == NCOEFF-1) begin
            source1_active <= 1'b0;
          end else begin
            source1_index_q <= source1_index_q + 1;
          end
        end
      end
    end
  end

  // Wire out current coeffs for source0 / source1
  assign source0_valid       = source0_active;
  assign source0_last        = source0_active && (source0_index_q == NCOEFF-1);
  assign source0_coefficient = mem[source0_register_index_q][source0_index_q];

  assign source1_valid       = source1_active;
  assign source1_last        = source1_active && (source1_index_q == NCOEFF-1);
  assign source1_coefficient = mem[source1_register_index_q][source1_index_q];

  // ------------------------------
  //  Writeback side (destination)
  // ------------------------------
  logic [$clog2(NCOEFF)-1:0] destination_index_q;
  logic                      destination_active;
  logic [$clog2(NREG)-1:0]   destination_register_index_q;

  // Write result coeffs back into destination_register_index[*]
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      destination_active           <= 1'b0;
      destination_index_q          <= '0;
      destination_register_index_q <= '0;
    end else begin
      if (!destination_active && destination_valid) begin
        // First coeff of a new result poly
        destination_active           <= 1'b1;
        destination_index_q          <= '0;
        destination_register_index_q <= destination_register_index;

        mem[destination_register_index][0] <= destination_coefficient;

        // Single–coeff result: done right away
        if (destination_last) begin
          destination_active <= 1'b0;
        end
      end else if (destination_active && destination_valid) begin
        // Middle of the writeback
        destination_index_q <= destination_index_q + 1;
        mem[destination_register_index_q][destination_index_q + 1] <= destination_coefficient;

        if (destination_last) begin
          destination_active <= 1'b0;
        end
      end
    end
  end

endmodule
