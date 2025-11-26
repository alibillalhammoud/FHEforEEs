`include "types.svh"

module regfile (
  input  logic clk,
  input  logic reset,

  // Goes high once reset is done and the RF can be used
  output logic register_file_ready,

  // ---------- control from CPU ----------

  // One–cycle pulse to start a new op (new poly read/write)
  input  logic                    start_operation,

  // Which "registers" (ciphertext/poly pairs) to use
  // 0..NREG-1, where reg = cipher*NPOLY + poly
  input  logic [$clog2(NREG)-1:0] source0_register_index,       // first input
  input  logic [$clog2(NREG)-1:0] source1_register_index,       // second input (if used)
  input  logic [$clog2(NREG)-1:0] destination_register_index,   // result goes here
  input  logic                    use_source1,                  // 0 = only src0, 1 = src0+src1

  // ---------- streams out to FUs ----------

  // Source 0: one residue per cycle while source0_valid is high
  output logic   source0_valid,
  output coeff_t source0_coefficient,
  output logic   source0_last,      // 1 on last residue of the poly

  // Source 1: same idea, only if use_source1 = 1
  output logic   source1_valid,
  output coeff_t source1_coefficient,
  output logic   source1_last,

  // ---------- stream back from FUs ----------

  // Result residues come back here, one per cycle
  input  logic   destination_valid,
  input  coeff_t destination_coefficient,
  input  logic   destination_last    // 1 on last result residue (for this op)
);

  // ------------------------------------------------------------------
  // 4D storage:
  //   mem[cipher][poly][coeff][prime]
  //
  // cipher : which ciphertext       (0..NCIPHERS-1)
  // poly   : A/B                    (0..NPOLY-1)
  // coeff  : coefficient index      (0..NCOEFF-1)
  // prime  : which RNS prime        (0..NPRIMES-1)
  // ------------------------------------------------------------------
  coeff_t mem [NCIPHERS][NPOLY][NCOEFF][NPRIMES];

  // Total number of residues in one polynomial (coeff x prime)
  localparam int TOTAL_ELEMS = NCOEFF * NPRIMES;

  // Ready flag – just "out of reset"
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      register_file_ready <= 1'b0;
    end else begin
      register_file_ready <= 1'b1;
    end
  end

  // ================================================================
  //  Helper: decode flat reg index into (cipher, poly)
  // ================================================================
  function automatic void decode_reg_index(
    input  logic [$clog2(NREG)-1:0] reg_idx,
    output logic [$clog2(NCIPHERS)-1:0] cipher_idx,
    output logic [$clog2(NPOLY)-1:0]    poly_idx
  );
    begin
      cipher_idx = reg_idx / NPOLY;
      poly_idx   = reg_idx % NPOLY;
      // With NPOLY = 2 this is basically:
      //   cipher_idx = reg_idx[$clog2(NREG)-1:1];
      //   poly_idx   = reg_idx[0];
    end
  endfunction

  // ================================================================
  //  Read side: source0 / source1
  //  We walk a flat index 0..TOTAL_ELEMS-1 and derive (coeff, prime)
  // ================================================================
  // latched register selection (decoded into cipher / poly)
  logic [$clog2(NCIPHERS)-1:0] src0_cipher_q, src1_cipher_q;
  logic [$clog2(NPOLY)-1:0]    src0_poly_q,   src1_poly_q;

  // flat indices inside the selected poly
  logic [$clog2(TOTAL_ELEMS)-1:0] src0_flat_idx_q, src1_flat_idx_q;
  logic                           src0_active,      src1_active;

  // indices derived from flat index
  logic [$clog2(NCOEFF)-1:0]  src0_coeff_idx;
  logic [$clog2(NPRIMES)-1:0] src0_prime_idx;
  logic [$clog2(NCOEFF)-1:0]  src1_coeff_idx;
  logic [$clog2(NPRIMES)-1:0] src1_prime_idx;

  assign src0_coeff_idx = src0_flat_idx_q / NPRIMES;
  assign src0_prime_idx = src0_flat_idx_q % NPRIMES;

  assign src1_coeff_idx = src1_flat_idx_q / NPRIMES;
  assign src1_prime_idx = src1_flat_idx_q % NPRIMES;

  // Walk the flat indices for source0/source1
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      src0_active      <= 1'b0;
      src1_active      <= 1'b0;
      src0_flat_idx_q  <= '0;
      src1_flat_idx_q  <= '0;
      src0_cipher_q    <= '0;
      src0_poly_q      <= '0;
      src1_cipher_q    <= '0;
      src1_poly_q      <= '0;
    end else begin
      if (start_operation) begin
        // New op: latch which regs we’re using and reset indices
        decode_reg_index(source0_register_index, src0_cipher_q, src0_poly_q);
        src0_active     <= 1'b1;
        src0_flat_idx_q <= '0;

        if (use_source1) begin
          decode_reg_index(source1_register_index, src1_cipher_q, src1_poly_q);
          src1_active     <= 1'b1;
          src1_flat_idx_q <= '0;
        end else begin
          src1_active     <= 1'b0;
          src1_flat_idx_q <= '0;
        end
      end else begin
        // Advance source0 if active
        if (src0_active) begin
          if (src0_flat_idx_q == TOTAL_ELEMS-1) begin
            src0_active <= 1'b0;
          end else begin
            src0_flat_idx_q <= src0_flat_idx_q + 1;
          end
        end

        // Advance source1 if active
        if (src1_active) begin
          if (src1_flat_idx_q == TOTAL_ELEMS-1) begin
            src1_active <= 1'b0;
          end else begin
            src1_flat_idx_q <= src1_flat_idx_q + 1;
          end
        end
      end
    end
  end

  // Wire out current residues for source0 / source1
  assign source0_valid       = src0_active;
  assign source0_last        = src0_active && (src0_flat_idx_q == TOTAL_ELEMS-1);
  assign source0_coefficient = mem[src0_cipher_q][src0_poly_q]
                                  [src0_coeff_idx][src0_prime_idx];

  assign source1_valid       = src1_active;
  assign source1_last        = src1_active && (src1_flat_idx_q == TOTAL_ELEMS-1);
  assign source1_coefficient = mem[src1_cipher_q][src1_poly_q]
                                  [src1_coeff_idx][src1_prime_idx];

  // ================================================================
  //  Writeback side: destination
  //  Same walk through 0..TOTAL_ELEMS-1, derived (coeff, prime)
  //
  //  NOTE: this is `always`, not `always_ff`, so the testbench is
  //        allowed to initialize mem[...] directly.
  // ================================================================
  logic [$clog2(NCIPHERS)-1:0]    dest_cipher_q;
  logic [$clog2(NPOLY)-1:0]       dest_poly_q;
  logic [$clog2(TOTAL_ELEMS)-1:0] dest_flat_idx_q;
  logic                           dest_active;

  // derived indices for destination
  logic [$clog2(NCOEFF)-1:0]  dest_coeff_idx;
  logic [$clog2(NPRIMES)-1:0] dest_prime_idx;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      dest_active     <= 1'b0;
      dest_flat_idx_q <= '0;
      dest_cipher_q   <= '0;
      dest_poly_q     <= '0;
    end else begin
      if (destination_valid) begin
        // On the first valid of a new stream, latch destination reg and reset index
        if (!dest_active) begin
          dest_active     <= 1'b1;
          dest_flat_idx_q <= '0;
          decode_reg_index(destination_register_index, dest_cipher_q, dest_poly_q);
        end

        // Compute current (coeff, prime) from flat index
        dest_coeff_idx = dest_flat_idx_q / NPRIMES;
        dest_prime_idx = dest_flat_idx_q % NPRIMES;

        // Write current residue
        mem[dest_cipher_q][dest_poly_q][dest_coeff_idx][dest_prime_idx]
          <= destination_coefficient;

        // Decide whether we’re done or need to move to the next element
        if (destination_last || (dest_flat_idx_q == TOTAL_ELEMS-1)) begin
          dest_active <= 1'b0;
        end else begin
          dest_flat_idx_q <= dest_flat_idx_q + 1;
        end
      end
      // if !destination_valid, hold state
    end
  end

endmodule
