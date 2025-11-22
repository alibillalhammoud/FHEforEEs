`include "types.svh"

module cpu (
  input  logic clk,
  input  logic reset
);

  // ============================
  //  Register file interface
  // ============================
  logic register_file_ready;

  // Control to RF (for each operation)
  logic                    start_operation;
  logic                    use_source1;  // 1 = binary op (add/mul), 0 = unary (NTT)
  logic [$clog2(NREG)-1:0] source0_register_index;
  logic [$clog2(NREG)-1:0] source1_register_index;
  logic [$clog2(NREG)-1:0] destination_register_index;

  // Streams from RF (into functional units)
  logic   source0_valid;
  coeff_t source0_coefficient;
  logic   source0_last;

  logic   source1_valid;
  coeff_t source1_coefficient;
  logic   source1_last;

  // Stream back to RF (from functional units)
  logic   destination_valid;
  coeff_t destination_coefficient;
  logic   destination_last;

  // ============================
  //  Instantiate big register file
  // ============================
  regfile u_rf (
    .clk                        (clk),
    .reset                      (reset),

    .register_file_ready        (register_file_ready),

    .start_operation            (start_operation),
    .source0_register_index     (source0_register_index),
    .source1_register_index     (source1_register_index),
    .destination_register_index (destination_register_index),
    .use_source1                (use_source1),

    .source0_valid              (source0_valid),
    .source0_coefficient        (source0_coefficient),
    .source0_last               (source0_last),

    .source1_valid              (source1_valid),
    .source1_coefficient        (source1_coefficient),
    .source1_last               (source1_last),

    .destination_valid          (destination_valid),
    .destination_coefficient    (destination_coefficient),
    .destination_last           (destination_last)
  );

  // ============================
  //  Functional units
  //  (per-coefficient add/mul/NTT)
  // ============================

  // "Ready" means: this cycle has valid inputs
  wire add_ready = source0_valid & source1_valid;
  wire mul_ready = source0_valid & source1_valid;
  wire ntt_ready = source0_valid;

  // One coefficient at a time
  coeff_t add_out;
  coeff_t mul_out;
  coeff_t ntt_out;  // stub for now

  // Example FUs using streamed coeffs
  adder u_add (
    .a   (source0_coefficient),
    .b   (source1_coefficient),
    .out (add_out)
  );

  mult u_mult (
    .a   (source0_coefficient),
    .b   (source1_coefficient),
    .out (mul_out)
  );


  // ============================
  //  FU selection + writeback to RF
  // ============================

  typedef enum logic [1:0] { FU_ADD, FU_MUL, FU_NTT } fu_e;
  fu_e fu_sel;

  // Take FU outputs and drive RF destination stream
  always_comb begin
    // defaults
    destination_valid       = 1'b0;
    destination_coefficient = '0;
    destination_last        = 1'b0;

    unique case (fu_sel)
      FU_ADD: begin
        if (add_ready) begin
          destination_valid       = 1'b1;
          destination_coefficient = add_out;
          destination_last        = source0_last & source1_last;
        end
      end

      FU_MUL: begin
        if (mul_ready) begin
          destination_valid       = 1'b1;
          destination_coefficient = mul_out;
          destination_last        = source0_last & source1_last;
        end
      end

      FU_NTT: begin
        if (ntt_ready) begin
          destination_valid       = 1'b1;
          destination_coefficient = ntt_out;
          destination_last        = source0_last; // unary op
        end
      end

      default: ;
    endcase
  end

  // ============================
  //  Tiny "controller" inside CPU
  //  - Hard-coded: R0 + R1 -> R2
  // ============================

  typedef enum logic [1:0] {
    ST_RESET,
    ST_WAIT_RF_READY,
    ST_KICK_OP,
    ST_WAIT_DONE
  } state_e;

  state_e state;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      // Simple hard-coded job: R0 + R1 -> R2
      fu_sel                  <= FU_ADD;
      use_source1             <= 1'b1;     // binary op (add)
      source0_register_index  <= 'd0;      // R0
      source1_register_index  <= 'd1;      // R1
      destination_register_index <= 'd2;   // R2

      start_operation         <= 1'b0;
      state                   <= ST_WAIT_RF_READY;
    end else begin
      // default each cycle
      start_operation <= 1'b0;

      unique case (state)
        ST_WAIT_RF_READY: begin
          if (register_file_ready) begin
            // kick off first operation
            start_operation <= 1'b1;  // one-cycle pulse
            state           <= ST_WAIT_DONE;
          end
        end

        ST_WAIT_DONE: begin
          // Wait for the regfile to finish streaming result
          if (destination_valid && destination_last) begin
            // For now, just stop here; you can chain more ops later
            state <= ST_WAIT_RF_READY;
            // (optionally change fu_sel / indices for next op)
          end
        end

        default: state <= ST_WAIT_RF_READY;
      endcase
    end
  end

endmodule
