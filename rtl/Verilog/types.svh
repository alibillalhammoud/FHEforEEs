`ifndef TYPES_SVH
`define TYPES_SVH

// ---------------------------
// Basic numeric / RNS params
// ---------------------------

// Width of each RNS residue (one small prime)
`define RNS_PRIME_BITS 32

// Vector / slot params
`define N_SLOTS   64

`define Q_MOD     32'd12289 
`define DELTA     32'd48    
`define BIG_Q     (`Q_MOD * `DELTA)

`define t_MODULUS = 257
`define q_BASIS {257, 2147483777, 2147484161, 2147484929, 2147485057, 2147486849, 2147488001, 2147489537, 2147490689, 2147491201, 2147492353}
`define q_BASIS_LEN 11
//`define q_MODULUS = 536092687689737712660299305370020840707037344303743567681198293980556215074372863278673727266177
`define B_BASIS {2147492609, 2147493889, 2147494273, 2147494529, 2147494913, 2147495681, 2147496193, 2147496961, 2147499521, 2147502337}
`define B_BASIS_LEN 10
//`define B_MODULUS = 2086045702160390514072457421164142647843268814746900546792219301529141418454085790414389880321
`define Ba_BASIS {2147503489, 2147504257, 2147505281, 2147506433, 2147510401, 2147512193, 2147513089, 2147513857, 2147514497, 2147515649}
`define Ba_BASIS_LEN 10
//`define Ba_MODULUS = 2086179990300185692566282340241293917615228850341888667901630103052349372235204354347116052993

// NTT
`define BASE      32'd2

// Base word / vector types
typedef logic signed [`RNS_PRIME_BITS-1:0]      rns_residue_t; 
typedef logic signed [2*`RNS_PRIME_BITS-1:0]    wide_rns_residue_t;
// “Vector of slots” types (still useful for NTT, etc.)
//typedef rns_residue_t       vec_t      [`N_SLOTS];    
//typedef wide_rns_residue_t  wide_vec_t [`N_SLOTS];    
// TODO update everything away from vec_t
//
typedef rns_residue_t rns_coef_q_BASIS_t [`q_BASIS_LEN];
typedef rns_residue_t rns_coef_B_BASIS_t [`B_BASIS_LEN];
typedef rns_residue_t rns_coef_Ba_BASIS_t [`Ba_BASIS_LEN];
// polynomial
typedef rns_coef_q_BASIS_t [`N_SLOTS];
typedef rns_coef_B_BASIS_t [`N_SLOTS];
typedef rns_coef_Ba_BASIS_t [`N_SLOTS];
// 
typedef wide_rns_residue_t wide_rns_coef_q_BASIS_t [`q_BASIS_LEN];
typedef wide_rns_residue_t wide_rns_coef_B_BASIS_t [`B_BASIS_LEN];
typedef wide_rns_residue_t wide_rns_coef_Ba_BASIS_t [`Ba_BASIS_LEN];
// wide polynomial


typedef vec_t        PK_t;
typedef PK_t         PT_t;
//
typedef struct {
  vec_t A;   
  vec_t B;   
} CT_t;


// Register file shape
// num ciphertexts in the reg file
localparam int unsigned NCIPHERS = 8;
// 2 polys per ciphertext: A and B
localparam int unsigned NPOLY    = 2;
// RNS coefficients per poly
localparam int unsigned NCOEFF   = `N_SLOTS;
// number of RNS primes per coefficient (must be able to hold q*B*Ba)
localparam int unsigned NPRIMES  = `q_BASIS_LEN + `B_BASIS_LEN + `Ba_BASIS_LEN;
// “Registers” from the CPU point of view = (ciphertext, poly) pair
localparam int unsigned NREG = NCIPHERS * NPOLY;

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
  logic [$clog2(NREG)-1:0]      idx1_a;
  logic [$clog2(NREG)-1:0]      idx1_b;
  logic [$clog2(NREG)-1:0]      idx2_a;
  logic [$clog2(NREG)-1:0]      idx2_b;
  logic [$clog2(NREG)-1:0]      out_a;
  logic [$clog2(NREG)-1:0]      out_b;
} operation;

// ---------------------------
// Handy localparams
// ---------------------------
localparam rns_residue_t        Q_MOD_L    = `Q_MOD;
localparam rns_residue_t        DELTA_L    = `DELTA;

// Example constant “twist” factors (all 1s for now)
localparam vec_t twist_factor   = '{default: '1};
localparam vec_t untwist_factor = '{default: '1};

// NOTE:
// Any runtime-computed things like delta_gamma[i] = in_gamma[i] * `DELTA
// should live inside a module, not in this types header. Put that logic
// in the module that actually has in_gamma as a signal.

`endif
