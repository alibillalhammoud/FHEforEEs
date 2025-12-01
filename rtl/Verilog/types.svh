`ifndef TYPES_SVH
`define TYPES_SVH

// ---------------------------
// Basic data types
// ---------------------------

// Width of each RNS residue (one small prime)
`define RNS_PRIME_BITS 32
// Vector / slot params
`define N_SLOTS   64
// moduli and RNS bases
`define t_MODULUS = 257
parameter logic [`RNS_PRIME_BITS-1:0] q_BASIS '{257, 2147483777, 2147484161, 2147484929, 2147485057, 2147486849, 2147488001, 2147489537, 2147490689, 2147491201, 2147492353};
`define q_BASIS_LEN 11
//`define q_MODULUS = 536092687689737712660299305370020840707037344303743567681198293980556215074372863278673727266177
parameter logic [`RNS_PRIME_BITS-1:0] B_BASIS {2147492609, 2147493889, 2147494273, 2147494529, 2147494913, 2147495681, 2147496193, 2147496961, 2147499521, 2147502337};
`define B_BASIS_LEN 10
//`define B_MODULUS = 2086045702160390514072457421164142647843268814746900546792219301529141418454085790414389880321
parameter logic [`RNS_PRIME_BITS-1:0] Ba_BASIS {2147503489, 2147504257, 2147505281, 2147506433, 2147510401, 2147512193, 2147513089, 2147513857, 2147514497, 2147515649};
`define Ba_BASIS_LEN 10
//`define Ba_MODULUS = 2086179990300185692566282340241293917615228850341888667901630103052349372235204354347116052993

// NTT
`define BASE      32'd2

// RNS residues
typedef logic unsigned [`RNS_PRIME_BITS-1:0]   rns_residue_t; 
typedef logic unsigned [2*`RNS_PRIME_BITS-1:0] wide_rns_residue_t;
// RNS integers
typedef rns_residue_t rns_int_q_BASIS_t [`q_BASIS_LEN];
typedef rns_residue_t rns_int_B_BASIS_t [`B_BASIS_LEN];
typedef rns_residue_t rns_int_Ba_BASIS_t [`Ba_BASIS_LEN];
/*typedef rns_residue_t rns_coef_qBBa_BASIS_t [`q_BASIS_LEN + `B_BASIS_LEN + `Ba_BASIS_LEN];*/
// Polynomials
typedef rns_int_q_BASIS_t q_BASIS_poly [`N_SLOTS];
typedef rns_int_B_BASIS_t B_BASIS_poly [`N_SLOTS];
typedef rns_int_Ba_BASIS_t Ba_BASIS_poly [`N_SLOTS];
/*typedef rns_coef_qBBA_BASIS_t qBBa_BASIS_poly [`N_SLOTS];*/
// wide RNS integers (each residue is double the length for mult)
typedef wide_rns_residue_t wide_rns_int_q_BASIS_t [`q_BASIS_LEN];
typedef wide_rns_residue_t wide_rns_int_B_BASIS_t [`B_BASIS_LEN];
typedef wide_rns_residue_t wide_rns_int_Ba_BASIS_t [`Ba_BASIS_LEN];
// wide Polynomials
typedef wide_rns_int_q_BASIS_t wide_q_BASIS_poly [`N_SLOTS];
typedef wide_rns_int_B_BASIS_t wide_B_BASIS_poly [`N_SLOTS];
typedef wide_rns_int_Ba_BASIS_t wide_Ba_BASIS_poly [`N_SLOTS];


`define REG_NPOLY = 12;// how many polynomials can the register file store

// One residue value (one prime for one coefficient)
typedef rns_residue_t coeff_t;

// If you ever want to explicitly tag A vs B in code:
typedef enum logic [0:0] {
  POLY_A = 1'b0,
  POLY_B = 1'b1
} poly_sel_e;

// ---------------------------
// Operation description
// ---------------------------

typedef enum logic [1:0] {
    OP_CT_CT_ADD,
    OP_CT_PT_ADD,
    OP_CT_PT_MUL
} op_e;

typedef struct packed {
  op_e                          mode;
  logic [$clog2(REG_NPOLY)-1:0]      idx1_a;
  logic [$clog2(REG_NPOLY)-1:0]      idx1_b;
  logic [$clog2(REG_NPOLY)-1:0]      idx2_a;
  logic [$clog2(REG_NPOLY)-1:0]      idx2_b;
  logic [$clog2(REG_NPOLY)-1:0]      out_a;
  logic [$clog2(REG_NPOLY)-1:0]      out_b;
} operation;

// ---------------------------
// precalculated values
// ---------------------------
// Example constant “twist” factors (all 1s for now)
parameter rns_residue_t twist_factor   [`N_SLOTS] = '{default: '1};
parameter rns_residue_t untwist_factor [`N_SLOTS] = '{default: '1};

// NOTE:
// Any runtime-computed things like delta_gamma[i] = in_gamma[i] * `DELTA
// should live inside a module, not in this types header. Put that logic
// in the module that actually has in_gamma as a signal.

`endif
