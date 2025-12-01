`ifndef TYPES_SVH
`define TYPES_SVH

// ---------------------------
// Basic numeric / RNS params
// ---------------------------

// Width of each RNS residue (one small prime)
`define RNS_PRIME_BITS 32

// Vector / slot params (for NTT etc.)
`define N_SLOTS   128

// For now just tie W_BITS to RNS_PRIME_BITS
`define W_BITS    `RNS_PRIME_BITS

`define Q_MOD     32'd12289 
`define T_MOD     32'd256    
`define DELTA     32'd48    
`define BIG_Q     (`Q_MOD * `DELTA)
`define BASE      32'd2
`define NUM_DIGITS ($clog2(`BIG_Q) / $clog2(`BASE))

// ---------------------------
// Base word / vector types
// ---------------------------

typedef logic signed [`W_BITS-1:0]      word_t; 
typedef logic signed [2*`W_BITS-1:0]    wide_word_t;

// “Vector of slots” types (still useful for NTT, etc.)
typedef word_t       vec_t      [`N_SLOTS];    
typedef wide_word_t  wide_vec_t [`N_SLOTS];    

typedef vec_t        PK_t;     
typedef PK_t         PT_t;  

typedef struct {
  vec_t A;   
  vec_t B;   
} CT_t;

// ---------------------------
// Register file shape
// ---------------------------

// 16 ciphertexts
localparam int unsigned NCIPHERS = 16;
// 2 polys per ciphertext: A and B
localparam int unsigned NPOLY    = 2;
// coefficients per poly (keep 1024 for now; can drop to 600 later)
localparam int unsigned NCOEFF   = 1024;
// number of RNS primes (just 4 for now so we don’t explode RAM)
localparam int unsigned NPRIMES  = 4;

// “Registers” from the CPU point of view = (ciphertext, poly) pair
localparam int unsigned NREG     = NCIPHERS * NPOLY;

// One residue value (one prime for one coefficient)
typedef word_t coeff_t;

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

localparam int unsigned N_SLOTS_L   = `N_SLOTS;
localparam int unsigned W_BITS_L    = `W_BITS;
localparam word_t        Q_MOD_L    = `Q_MOD;
localparam word_t        T_MOD_L    = `T_MOD;
localparam word_t        DELTA_L    = `DELTA;

// Example constant “twist” factors (all 1s for now)
localparam vec_t twist_factor   = '{default: '1};
localparam vec_t untwist_factor = '{default: '1};

// NOTE:
// Any runtime-computed things like delta_gamma[i] = in_gamma[i] * `DELTA
// should live inside a module, not in this types header. Put that logic
// in the module that actually has in_gamma as a signal.

`endif
