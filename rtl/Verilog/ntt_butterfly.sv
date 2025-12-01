// =====================================================================
// MODULE: ntt_butterfly_2stage
// DESCRIPTION: 支持 NTT/iNTT 动态切换的 2-Stage Butterfly
// =====================================================================
module ntt_butterfly_2stage #(
    parameter W = 32,    // Data width
    parameter Q = 40961  // Modulus Q
) (
    input  logic clk,
    input  logic reset,
    
    // Control
    input  logic iNTT_mode,      // 0: Forward, 1: Inverse
    
    // Data Inputs
    input  logic [W-1:0] A_in,   
    input  logic [W-1:0] B_in,   
    
    // Dual Twiddle Inputs (From ROMs)
    input  logic [W-1:0] Wk_fwd, 
    input  logic [W-1:0] Wk_inv, 

    // Outputs
    output logic [W-1:0] A_out,  
    output logic [W-1:0] B_out   
);

    // ============================================================
    // Stage 1: Mux selection, Multiplication & Data Alignment
    // ============================================================
    
    logic [W-1:0]   Wk_selected;
    logic [2*W-1:0] pipe_mult_prod; 
    logic [W-1:0]   pipe_A_reg;     

    // 1. Mux Selection (Combinational)
    assign Wk_selected = iNTT_mode ? Wk_inv : Wk_fwd;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipe_mult_prod <= '0;
            pipe_A_reg     <= '0;
        end else begin
            // 2. 乘法运算 (使用选择后的 Wk)
            pipe_mult_prod <= B_in * Wk_selected;
            
            // 3. 对齐 A 路径
            pipe_A_reg     <= A_in;
        end
    end

    // ============================================================
    // Stage 2: Modular Reduction & Butterfly Arithmetic
    // ============================================================

    logic [W-1:0] P_mod; 
    logic [W-1:0] B_term;
    logic [W:0]   sum;   
    logic [W:0]   diff;  

    // 1. Modular Reduction
    always_comb begin
        P_mod = pipe_mult_prod % Q;
    end

    assign B_term = P_mod;

    // 2. A' Calculation
    always_comb begin
        sum = pipe_A_reg + B_term;
        if (sum >= Q) begin
            A_out = sum - Q;
        end else begin
            A_out = sum;
        end
    end

    // 3. B' Calculation
    always_comb begin
        if (pipe_A_reg < B_term) begin
            diff = pipe_A_reg - B_term + Q;
        end else begin
            diff = pipe_A_reg - B_term;
        end
        B_out = diff[W-1:0];
    end

endmodule

