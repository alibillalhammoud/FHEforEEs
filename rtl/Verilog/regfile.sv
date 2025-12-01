`include "types.svh"

module regfile #(
  localparam NPRIMES
) (
  input  logic clk,
  // ---------- control from CPU ----------
  // Which "registers" (ciphertext/poly pairs) to use
  // 0..REG_NPOLY-1
  input  logic [$clog2(`REG_NPOLY)-1:0] source0_register_index,
  input  logic [$clog2(`REG_NPOLY)-1:0] source1_register_index,
  input  logic [$clog2(`REG_NPOLY)-1:0] source2_register_index,
  input  logic [$clog2(`REG_NPOLY)-1:0] source3_register_index,
  // Where to store the two result polys
  input  logic [$clog2(`REG_NPOLY)-1:0] dest0_register_index,
  input  logic [$clog2(`REG_NPOLY)-1:0] dest1_register_index,
  // ---------- streams out to FUs ----------
  // Now full q_BASIS_poly’s, not streaming scalars
  // Source 0
  output logic source0_valid,
  output rns_residue_t [NPRIMES][`N_SLOTS] source0_poly,
  // Source 1
  output logic source1_valid,
  output rns_residue_t [NPRIMES][`N_SLOTS] source1_poly,
  // Source 2
  output logic source2_valid,
  output rns_residue_t [NPRIMES][`N_SLOTS] source2_poly,
  // Source 3
  output logic source3_valid,
  output rns_residue_t [NPRIMES][`N_SLOTS] source3_poly,
  // ---------- streams back from FUs ----------
  // Now full q_BASIS_poly’s
  input  logic dest0_valid,
  input  rns_residue_t [NPRIMES][`N_SLOTS] dest0_poly,
  input  logic dest1_valid,
  input  rns_residue_t [NPRIMES][`N_SLOTS] dest1_poly
);

  // 3D storage: mem[polynomial][coeff][prime]
  coeff_t mem [`REG_NPOLY][`N_SLOTS][NPRIMES];

  // Total number of residues in one polynomial (coeff x prime)
  localparam int TOTAL_ELEMS = `N_SLOTS * NPRIMES;

  // Flatten (coeff, prime) into q_BASIS_poly index
  // function automatic int flat_idx (input int c, input int p);
  //   flat_idx = c * NPRIMES + p;
  // endfunction

  // ================================================================
  //  Read side: combinational, returns full q_BASIS_poly for each source
  // ================================================================
  rns_residue_t [NPRIMES][`N_SLOTS]   s0_poly,   s1_poly,   s2_poly,   s3_poly;

  always_comb begin
    s0_poly=source0_register_index;
    s1_poly=source1_register_index;
    s2_poly=source2_register_index;
    s3_poly=source2_register_index;

    // default all zeros
    source0_poly = '{default: '0};
    source1_poly = '{default: '0};
    source2_poly = '{default: '0};
    source3_poly = '{default: '0};

    // assemble full q_BASIS_poly’s from mem
    for (int c = 0; c < `N_SLOTS; c = c + 1) begin
      for (int p = 0; p < NPRIMES; p = p + 1) begin
        int idx;
        idx = flat_idx(c, p);

        source0_poly[idx] = mem[s0_poly][c][p];
        source1_poly[idx] = mem[s1_poly][c][p];
        source2_poly[idx] = mem[s2_poly][c][p];
        source3_poly[idx] = mem[s3_poly][c][p];
      end
    end

    // in this simplified model, reads are always "valid"
    source0_valid = 1'b1;
    source1_valid = 1'b1;
    source2_valid = 1'b1;
    source3_valid = 1'b1;
  end

  // ================================================================
  //  Writeback side: write entire q_BASIS_poly into mem when dest*_valid
  // ================================================================
  logic [$clog2(NCIPHERS)-1:0] d0_cipher, d1_cipher;
  logic [$clog2(NPOLY)-1:0]    d0_poly,   d1_poly;

  always_comb begin
    decode_reg_index(dest0_register_index, d0_cipher, d0_poly);
    decode_reg_index(dest1_register_index, d1_cipher, d1_poly);
  end

  always @(posedge clk) begin
    if (dest0_valid) begin
      for (int c = 0; c < `N_SLOTS; c = c + 1) begin
        for (int p = 0; p < NPRIMES; p = p + 1) begin
          int idx;
          idx = flat_idx(c, p);
          mem[d0_cipher][d0_poly][c][p] <= dest0_poly[idx];
        end
      end
    end

    if (dest1_valid) begin
      for (int c = 0; c < `N_SLOTS; c = c + 1) begin
        for (int p = 0; p < NPRIMES; p = p + 1) begin
          int idx;
          idx = flat_idx(c, p);
          mem[d1_cipher][d1_poly][c][p] <= dest1_poly[idx];
        end
      end
    end
  end

endmodule
