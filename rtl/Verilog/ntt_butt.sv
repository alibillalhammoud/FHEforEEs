// =====================================================================
// MODULE: ntt_butterfly
// DESCRIPTION: Core Radix-2 NTT/Inverse-NTT butterfly operation.
// Inputs and outputs are assumed to be less than the modulus Q.
// Note: This module performs 64-bit multiplication internally to handle Q*Q products.
// =====================================================================
module ntt_butterfly #(
    parameter W = 32,    // Data width (max Q size)
    parameter Q = 40961  // Modulus Q (e.g., 40961 = 160 * 256 + 1 for N=256)
) (
    input logic clk,
    input logic reset,
    input logic [W-1:0] A_in,    // Input A
    input logic [W-1:0] B_in,    // Input B
    input logic [W-1:0] Wk_in,   // Twiddle factor omega^k
    input logic iNTT_mode, // 0 for NTT (A + B*Wk), 1 for iNTT (A + B*Wk*N_inv)

    output logic [W-1:0] A_out,   // Output A'
    output logic [W-1:0] B_out    // Output B'
);

// Internal wire for B * Wk (pre-mod Q)
logic [2*W-1:0] P_mult;
// Internal wire for B * Wk (mod Q)
logic [W-1:0] P_mod;

// 1. Modular Multiplication: P = (B_in * Wk_in) mod Q
// The multiplication result P_mult can be up to (Q-1)*(Q-1) < Q^2,
// which requires up to 2*W bits.
always_comb begin
    P_mult = B_in * Wk_in;
    // Simple reduction: P_mod = P_mult % Q
    // For synthesis, this would be a custom fast reduction unit (e.g., Montgomery)
    // but for behavioral Verilog, we use the modulo operator.
    P_mod = P_mult % Q;
	// $display("DEBUG: B_in=%0d, Wk_in=%0d, P_mult=%0d, P_mod=%0d", B_in, Wk_in, P_mult, P_mod);
end

// Determine the value to be added/subtracted: B_term = P_mod or (P_mod * N_inv) mod Q
// Since N_inv is usually handled by pre-scaling the twiddle factors,
// we just assume Wk_in contains the correct pre-calculated factor.
logic [W-1:0] B_term;
assign B_term = P_mod;

// 2. Modular Addition and Subtraction
// A' = (A_in + B_term) mod Q
// B' = (A_in - B_term) mod Q (if NTT) OR (A_in - B_term) mod Q (if iNTT)
// The iNTT_mode logic (which often involves multiplying the result by N_inv)
// is simplified here by assuming the inputs Wk already handle the N_inv factor if iNTT_mode is active.

// Calculate intermediate sums
logic [W:0] sum;
logic [W:0] diff;

// A' Calculation: A_out = (A_in + B_term) mod Q
always_comb begin
    sum = A_in + B_term;
    if (sum >= Q) begin
        A_out = sum - Q;
    end else begin
        A_out = sum;
    end
end

// B' Calculation: B_out = (A_in - B_term) mod Q
// The difference (A_in - B_term) can be negative.
always_comb begin
    // Standard modular subtraction: (A - B) mod Q = A - B + (Q if A < B)
    if (A_in < B_term) begin
        // Result is A_in - B_term + Q
        diff = A_in - B_term + Q;
    end else begin
        // Result is A_in - B_term
        diff = A_in - B_term;
    end
    B_out = diff[W-1:0]; // B_out is always positive and < Q
end

endmodule