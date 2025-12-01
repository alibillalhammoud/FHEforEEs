`include "types.svh"

module regfile (
  input  logic clk,
  input  logic reset,

  // Goes high once reset is done and the RF can be used
  output logic register_file_ready,

  // ---------- control from CPU ----------
  // (start_operation is kept for interface compatibility, but ignored here)
  input  logic                    start_operation,

  // Which "registers" (ciphertext/poly pairs) to use
  // 0..NREG-1, where reg = cipher*NPOLY + poly
  input  logic [$clog2(NREG)-1:0] source0_register_index,
  input  logic [$clog2(NREG)-1:0] source1_register_index,
  input  logic [$clog2(NREG)-1:0] source2_register_index,
  input  logic [$clog2(NREG)-1:0] source3_register_index,

  // Where to store the two result polys
  input  logic [$clog2(NREG)-1:0] dest0_register_index,
  input  logic [$clog2(NREG)-1:0] dest1_register_index,

  // ---------- streams out to FUs ----------
  // Now full vec_t’s, not streaming scalars

  // Source 0
  output logic source0_valid,
  output vec_t source0_coefficient,

  // Source 1
  output logic source1_valid,
  output vec_t source1_coefficient,

  // Source 2
  output logic source2_valid,
  output vec_t source2_coefficient,

  // Source 3
  output logic source3_valid,
  output vec_t source3_coefficient,

  // ---------- streams back from FUs ----------
  // Now full vec_t’s

  input  logic dest0_valid,
  input  vec_t dest0_coefficient,

  input  logic dest1_valid,
  input  vec_t dest1_coefficient
);

  // ------------------------------------------------------------------
  // 4D storage:
  //   mem[cipher][poly][coeff][prime]
  // ------------------------------------------------------------------
  coeff_t mem [NCIPHERS][NPOLY][NCOEFF][NPRIMES];

  // helper task for testbench initialization
  task automatic init_mem_entry(
    input int     cipher,
    input int     poly,
    input int     coeff,
    input int     prime,
    input coeff_t value
  );
    mem[cipher][poly][coeff][prime] = value;
  endtask

  // Total number of residues in one polynomial (coeff x prime)
  localparam int TOTAL_ELEMS = NCOEFF * NPRIMES;

  // Simple ready flag: low in reset, high otherwise
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
    input  logic [$clog2(NREG)-1:0]     reg_idx,
    output logic [$clog2(NCIPHERS)-1:0] cipher_idx,
    output logic [$clog2(NPOLY)-1:0]    poly_idx
  );
    begin
      cipher_idx = reg_idx / NPOLY;
      poly_idx   = reg_idx % NPOLY;
    end
  endfunction

  // Flatten (coeff, prime) into vec_t index
  function automatic int flat_idx (input int c, input int p);
    flat_idx = c * NPRIMES + p;
  endfunction

  // ================================================================
  //  Read side: combinational, returns full vec_t for each source
  // ================================================================
  logic [$clog2(NCIPHERS)-1:0] s0_cipher, s1_cipher, s2_cipher, s3_cipher;
  logic [$clog2(NPOLY)-1:0]    s0_poly,   s1_poly,   s2_poly,   s3_poly;

  always_comb begin
    // decode which ciphertext/poly each source index refers to
    decode_reg_index(source0_register_index, s0_cipher, s0_poly);
    decode_reg_index(source1_register_index, s1_cipher, s1_poly);
    decode_reg_index(source2_register_index, s2_cipher, s2_poly);
    decode_reg_index(source3_register_index, s3_cipher, s3_poly);

    // default all zeros
    source0_coefficient = '{default: '0};
    source1_coefficient = '{default: '0};
    source2_coefficient = '{default: '0};
    source3_coefficient = '{default: '0};

    // assemble full vec_t’s from mem
    for (int c = 0; c < NCOEFF; c = c + 1) begin
      for (int p = 0; p < NPRIMES; p = p + 1) begin
        int idx;
        idx = flat_idx(c, p);

        source0_coefficient[idx] = mem[s0_cipher][s0_poly][c][p];
        source1_coefficient[idx] = mem[s1_cipher][s1_poly][c][p];
        source2_coefficient[idx] = mem[s2_cipher][s2_poly][c][p];
        source3_coefficient[idx] = mem[s3_cipher][s3_poly][c][p];
      end
    end

    // in this simplified model, reads are always "valid"
    source0_valid = 1'b1;
    source1_valid = 1'b1;
    source2_valid = 1'b1;
    source3_valid = 1'b1;
  end

  // ================================================================
  //  Writeback side: write entire vec_t into mem when dest*_valid
  // ================================================================
  logic [$clog2(NCIPHERS)-1:0] d0_cipher, d1_cipher;
  logic [$clog2(NPOLY)-1:0]    d0_poly,   d1_poly;

  always_comb begin
    decode_reg_index(dest0_register_index, d0_cipher, d0_poly);
    decode_reg_index(dest1_register_index, d1_cipher, d1_poly);
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      // optional: clear mem if you want deterministic reset contents
      // for (cipher/poly/coeff/prime) mem = '0;
    end else begin
      if (dest0_valid) begin
        for (int c = 0; c < NCOEFF; c = c + 1) begin
          for (int p = 0; p < NPRIMES; p = p + 1) begin
            int idx;
            idx = flat_idx(c, p);
            mem[d0_cipher][d0_poly][c][p] <= dest0_coefficient[idx];
          end
        end
      end

      if (dest1_valid) begin
        for (int c = 0; c < NCOEFF; c = c + 1) begin
          for (int p = 0; p < NPRIMES; p = p + 1) begin
            int idx;
            idx = flat_idx(c, p);
            mem[d1_cipher][d1_poly][c][p] <= dest1_coefficient[idx];
          end
        end
      end
    end
  end

endmodule
