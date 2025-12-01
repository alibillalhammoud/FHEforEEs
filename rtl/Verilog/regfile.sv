`include "types.svh"

module regfile #(
  parameter NPRIMES
)(
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
  output rns_residue_t source0_poly [`N_SLOTS][NPRIMES],
  // Source 1
  output logic source1_valid,
  output rns_residue_t source1_poly [`N_SLOTS][NPRIMES],
  // Source 2
  output logic source2_valid,
  output rns_residue_t source2_poly [`N_SLOTS][NPRIMES],
  // Source 3
  output logic source3_valid,
  output rns_residue_t source3_poly [`N_SLOTS][NPRIMES],
  // ---------- streams back from FUs ----------
  // Now full q_BASIS_poly’s
  input  logic dest0_valid,
  input  rns_residue_t dest0_poly [`N_SLOTS][NPRIMES],
  input  logic dest1_valid,
  input  rns_residue_t dest1_poly [`N_SLOTS][NPRIMES]
);

  // 3D storage: mem[polynomial][coeff][prime]
  rns_residue_t mem [`REG_NPOLY][`N_SLOTS][NPRIMES];

  // Total number of residues in one polynomial (coeff x prime)
  localparam int TOTAL_ELEMS = `N_SLOTS * NPRIMES;

  // Flatten (coeff, prime) into q_BASIS_poly index
  // function automatic int flat_idx (input int c, input int p);
  //   flat_idx = c * NPRIMES + p;
  // endfunction

  // ================================================================
  //  Read side: combinational, returns full q_BASIS_poly for each source
  // ================================================================

  always_comb begin
    source0_poly = mem[source0_register_index];
    source1_poly = mem[source1_register_index];
    source2_poly = mem[source2_register_index];
    source3_poly = mem[source3_register_index];

    // in this simplified model, reads are always "valid"
    source0_valid = 1'b1;
    source1_valid = 1'b1;
    source2_valid = 1'b1;
    source3_valid = 1'b1;
  end

  // ================================================================
  //  Writeback side: write entire q_BASIS_poly into mem when dest*_valid
  // ================================================================

  always @(posedge clk) begin
    if (dest0_valid) begin
      mem[dest0_register_index] = dest0_poly;
    end

    if (dest1_valid) begin
      mem[dest1_register_index] = dest1_poly;
    end
  end

endmodule
