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


// =====================================================================
// MODULE: ntt_butterfly_2stage
// DESCRIPTION: 2-Stage Pipelined Radix-2 NTT butterfly.
//
// Stage 1: Multiplication (B * Wk) and Input Alignment (A_reg)
//          --> [Pipeline Register]
// Stage 2: Modular Reduction (%), Addition, Subtraction
//          --> [Combinational Output]
// =====================================================================
// module ntt_butterfly_2stage #(
//     parameter W = 32,    // Data width (max Q size)
//     parameter Q = 40961  // Modulus Q
// ) (
//     input logic clk,
//     input logic reset,
    
//     input logic [W-1:0] A_in,    // Input A
//     input logic [W-1:0] B_in,    // Input B
//     input logic [W-1:0] Wk_in,   // Twiddle factor omega^k
//     input logic iNTT_mode,       // (Pass-through or logic control)

//     output logic [W-1:0] A_out,   // Output A'
//     output logic [W-1:0] B_out    // Output B'
// );

//     // ============================================================
//     // Stage 1: Multiplication & Data Alignment
//     // ============================================================
    
//     // 定义流水线寄存器
//     // 乘法结果最大为 (Q-1)^2，需要 2*W 位宽
//     logic [2*W-1:0] pipe_mult_prod; 
//     // A 需要打一拍以配合乘法的延迟，确保在 Stage 2 数据对齐
//     logic [W-1:0]   pipe_A_reg;     

//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             pipe_mult_prod <= '0;
//             pipe_A_reg     <= '0;
//         end else begin
//             // 1. 执行乘法，但不做模运算
//             pipe_mult_prod <= B_in * Wk_in;
            
//             // 2. 同步 A 路径
//             pipe_A_reg     <= A_in;
//         end
//     end

//     // ============================================================
//     // Stage 2: Modular Reduction & Butterfly Arithmetic
//     // (Pure Combinational Logic from Pipeline Registers)
//     // ============================================================

//     logic [W-1:0] P_mod; // Reduced modular product
//     logic [W-1:0] B_term;
//     logic [W:0]   sum;   // Extra bit for carry
//     logic [W:0]   diff;  // Extra bit for borrow handling

//     // 1. Modular Reduction: (B * Wk) % Q
//     // 注意：这里的输入源变成了寄存器 pipe_mult_prod
//     always_comb begin
//         P_mod = pipe_mult_prod % Q;
//     end

//     assign B_term = P_mod;

//     // 2. A' Calculation: (A + B_term) % Q
//     // 注意：这里的输入源变成了寄存器 pipe_A_reg
//     always_comb begin
//         sum = pipe_A_reg + B_term;
//         if (sum >= Q) begin
//             A_out = sum - Q;
//         end else begin
//             A_out = sum;
//         end
//     end

//     // 3. B' Calculation: (A - B_term) % Q
//     // 注意：这里的输入源变成了寄存器 pipe_A_reg
//     always_comb begin
//         if (pipe_A_reg < B_term) begin
//             // 借位减法：Result = A - B + Q
//             diff = pipe_A_reg - B_term + Q;
//         end else begin
//             diff = pipe_A_reg - B_term;
//         end
//         B_out = diff[W-1:0];
//     end

// endmodule




// // =====================================================================
// // MODULE: ntt_butterfly
// // DESCRIPTION: Core Radix-2 NTT/Inverse-NTT butterfly operation.
// // Inputs and outputs are assumed to be less than the modulus Q.
// // Note: This module performs 64-bit multiplication internally to handle Q*Q products.
// // =====================================================================
// module ntt_butterfly #(
//     parameter W = 32,    // Data width (max Q size)
//     parameter Q = 40961  // Modulus Q (e.g., 40961 = 160 * 256 + 1 for N=256)
// ) (
//     input logic clk,
//     input logic reset,
//     input logic [W-1:0] A_in,    // Input A
//     input logic [W-1:0] B_in,    // Input B
//     input logic [W-1:0] Wk_in,   // Twiddle factor omega^k
//     input logic iNTT_mode, // 0 for NTT (A + B*Wk), 1 for iNTT (A + B*Wk*N_inv)

//     output logic [W-1:0] A_out,   // Output A'
//     output logic [W-1:0] B_out    // Output B'
// );

// // Internal wire for B * Wk (pre-mod Q)
// logic [2*W-1:0] P_mult;
// // Internal wire for B * Wk (mod Q)
// logic [W-1:0] P_mod;

// // 1. Modular Multiplication: P = (B_in * Wk_in) mod Q
// // The multiplication result P_mult can be up to (Q-1)*(Q-1) < Q^2,
// // which requires up to 2*W bits.
// always_comb begin
//     P_mult = B_in * Wk_in;
//     // Simple reduction: P_mod = P_mult % Q
//     // For synthesis, this would be a custom fast reduction unit (e.g., Montgomery)
//     // but for behavioral Verilog, we use the modulo operator.
//     P_mod = P_mult % Q;
// 	// $display("DEBUG: B_in=%0d, Wk_in=%0d, P_mult=%0d, P_mod=%0d", B_in, Wk_in, P_mult, P_mod);
// end

// // Determine the value to be added/subtracted: B_term = P_mod or (P_mod * N_inv) mod Q
// // Since N_inv is usually handled by pre-scaling the twiddle factors,
// // we just assume Wk_in contains the correct pre-calculated factor.
// logic [W-1:0] B_term;
// assign B_term = P_mod;

// // 2. Modular Addition and Subtraction
// // A' = (A_in + B_term) mod Q
// // B' = (A_in - B_term) mod Q (if NTT) OR (A_in - B_term) mod Q (if iNTT)
// // The iNTT_mode logic (which often involves multiplying the result by N_inv)
// // is simplified here by assuming the inputs Wk already handle the N_inv factor if iNTT_mode is active.

// // Calculate intermediate sums
// logic [W:0] sum;
// logic [W:0] diff;

// // A' Calculation: A_out = (A_in + B_term) mod Q
// always_comb begin
//     sum = A_in + B_term;
//     if (sum >= Q) begin
//         A_out = sum - Q;
//     end else begin
//         A_out = sum;
//     end
// end

// // B' Calculation: B_out = (A_in - B_term) mod Q
// // The difference (A_in - B_term) can be negative.
// always_comb begin
//     // Standard modular subtraction: (A - B) mod Q = A - B + (Q if A < B)
//     if (A_in < B_term) begin
//         // Result is A_in - B_term + Q
//         diff = A_in - B_term + Q;
//     end else begin
//         // Result is A_in - B_term
//         diff = A_in - B_term;
//     end
//     B_out = diff[W-1:0]; // B_out is always positive and < Q
// end

// endmodule