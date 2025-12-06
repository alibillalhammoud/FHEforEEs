// =====================================================================
// MODULE: ntt_butterfly_2stage
// DESCRIPTION: 2-stage butterfly supporting dynamic NTT/iNTT switching
// =====================================================================
module ntt_butterfly_2stage #(
    parameter W = 32,    // Data width
    parameter Q = 40961  // Modulus Q
) (
    input  logic clk,
    input  logic reset,
    
    // Control
    input  logic iNTT_mode,      // 0 = forward NTT, 1 = inverse NTT
    
    // Data inputs
    input  logic [W-1:0] A_in,   
    input  logic [W-1:0] B_in,   
    
    // Twiddle inputs (forward & inverse)
    input  logic [W-1:0] Wk_fwd, 
    input  logic [W-1:0] Wk_inv, 

    // Outputs
    output logic [W-1:0] A_out,  
    output logic [W-1:0] B_out   
);

    // ============================================================
    // Stage 1: Twiddle selection, multiplication, and alignment
    // ============================================================
    
    logic [W-1:0]   Wk_selected;
    logic [2*W-1:0] pipe_mult_prod;   // Multiplier result (before reduction)
    logic [W-1:0]   pipe_A_reg;       // Delayed A for alignment

    // 1. Select twiddle based on mode (combinational)
    assign Wk_selected = iNTT_mode ? Wk_inv : Wk_fwd;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipe_mult_prod <= '0;
            pipe_A_reg     <= '0;
        end else begin
            // 2. Multiply B by the selected twiddle
            pipe_mult_prod <= B_in * Wk_selected;
            
            // 3. Align A path with multiplier latency
            pipe_A_reg     <= A_in;
        end
    end

    // ============================================================
    // Stage 2: Modular reduction and butterfly arithmetic
    // ============================================================

    logic [W-1:0] P_mod;  // Reduced product
    logic [W-1:0] B_term; // Twiddled B
    logic [W:0]   sum;    // For A'
    logic [W:0]   diff;   // For B'

    // 1. Modular reduction of multiplication result
    always_comb begin
        P_mod = pipe_mult_prod % Q;
    end

    assign B_term = P_mod;

    // 2. Compute A' = (A + B') mod Q
    always_comb begin
        sum = pipe_A_reg + B_term;
        if (sum >= Q)
            A_out = sum - Q;
        else
            A_out = sum;
    end

    // 3. Compute B' = (A - B') mod Q
    always_comb begin
        if (pipe_A_reg < B_term)
            diff = pipe_A_reg - B_term + Q;
        else
            diff = pipe_A_reg - B_term;

        B_out = diff[W-1:0];
    end

endmodule
