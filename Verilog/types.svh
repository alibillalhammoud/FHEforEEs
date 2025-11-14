`ifndef TYPES_SVH
`define TYPES_SVH

`define N_SLOTS   128 // For true polynomial conv/NTT, you’ll replace elementwise ops with NTT-domain ops later.
`define W_BITS    32 // Bit width per slot (word width for each coefficient/entry)
`define Q_MOD     32'd12289   // For real systems, q is often RNS (multi-prime). Here we start simple: single-prime q.

// Plaintext modulus t
`define T_MOD     32'd256    

// Δ = floor(q / t)
`define DELTA     32'd48      // 12289 / 256 ≈ 48, floor -> 48

typedef logic signed [`W_BITS-1:0]      word_t;                       // one slot
typedef word_t                          vec_t   [`N_SLOTS];           // vector of slots
typedef vec_t                           PK_t;     // "PublicKey" slot-vector container
typedef PK_t                            PT_t;     // Plaintext type alias


// Ciphertext = pair of vectors (A, B)
// NOTE: struct is *unpacked* because A/B are unpacked arrays.
typedef struct {
  vec_t A;   // vector of slots
  vec_t B;   // vector of slots
} CT_t;

localparam int unsigned N_SLOTS_L   = `N_SLOTS;
localparam int unsigned W_BITS_L    = `W_BITS;
localparam word_t        Q_MOD_L    = `Q_MOD;
localparam word_t        T_MOD_L    = `T_MOD;
localparam word_t        DELTA_L    = `DELTA;

`endif // TYPES_SVH
