`ifndef TYPES_SVH
`define TYPES_SVH
`define N_SLOTS   128 
`define W_BITS    32 
`define Q_MOD     32'd12289 
`define T_MOD     32'd256    
`define DELTA     32'd48    
`define BIG_Q     `Q_MOD * `DELTA
`define BASE      32'd2
`define NUM_DIGITS $clog2(`BIG_Q) / $clog2(`BASE)
typedef logic signed [`W_BITS-1:0]      word_t; 
typedef logic signed [2*`W_BITS-1:0]    wide_word_t;
typedef word_t                          vec_t   [`N_SLOTS];    
typedef wide_word_t                     wide_vec_t [`N_SLOTS];    
typedef vec_t                           PK_t;     
typedef PK_t                            PT_t;  
typedef struct {
  vec_t A;   
  vec_t B;   
} CT_t;
localparam int unsigned N_SLOTS_L   = `N_SLOTS;
localparam int unsigned W_BITS_L    = `W_BITS;
localparam word_t        Q_MOD_L    = `Q_MOD;
localparam word_t        T_MOD_L    = `T_MOD;
localparam word_t        DELTA_L    = `DELTA;
`endif