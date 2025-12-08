module ntt_block_radix2_pipelined #(
    parameter W           = 32,
    parameter N           = 8,
    parameter logic [2*W-1:0] Modulus_Q   = 241,
    parameter OMEGA       = 30,
    parameter OMEGA_INV   = 233
) (
    input  logic clk,
    input  logic reset,
    
    // Control signals
    input  logic data_valid_in, // Input data-valid indicator
    input  logic iNTT_mode,     // 0: NTT, 1: inverse NTT (per-frame selectable)

    // Input data (natural order)
    input  logic [W-1:0] Data_in [0:N-1],

    // Output data (bit-reversed order)
    output logic [W-1:0] Data_out [0:N-1],
    output logic         data_valid_out, // Output valid indicator
    output logic         mode_out        // Output mode (debug)
);

    // Number of stages
    localparam LOG2_N = $clog2(N);

    // ============================================================
    // 1. Pipeline registers (Data, Valid, Mode)
    // ============================================================
    
    // Data pipeline
    logic [W-1:0] stage_regs [0:LOG2_N][0:N-1];
    logic [W-1:0] butterfly_out_wires [0:LOG2_N-1][0:N-1];

    // Control pipeline (Valid & Mode)
    // valid_pipe[s] and mode_pipe[s] correspond to stage_regs[s]
    logic [LOG2_N:0] valid_pipe;
    logic [LOG2_N:0] mode_pipe;

    // ============================================================
    // 2. Precompute twiddle-factor ROM tables
    // ============================================================
    typedef logic [W-1:0] twiddle_array_t [0:N/2-1];

    function automatic twiddle_array_t gen_twiddles (
        input logic [W-1:0] base, 
        input logic [W-1:0] mod
    );
        twiddle_array_t tw_table;
        longint twiddle_factor;
        int i;

        twiddle_factor = 1; 
        for (i = 0; i < N/2; i++) begin
            tw_table[i] = twiddle_factor;
            twiddle_factor = longint'(twiddle_factor) * longint'(base) % longint'(mod);
        end
        return tw_table;
    endfunction

    // Forward and inverse twiddle ROMs
    localparam twiddle_array_t TWIDDLE_ROM_FWD = gen_twiddles(OMEGA,     Modulus_Q);
    localparam twiddle_array_t TWIDDLE_ROM_INV = gen_twiddles(OMEGA_INV, Modulus_Q);

    // ============================================================
    // 3. Input stage: bit reversal + control pipelining
    // ============================================================
    // This stage consumes 1 cycle
    
    function automatic logic [LOG2_N-1:0] bit_reverse_func (
        input logic [LOG2_N-1:0] addr_in
    );
        for (int i = 0; i < LOG2_N; i = i + 1) begin
            bit_reverse_func[i] = addr_in[LOG2_N - 1 - i];
        end
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < N; i++) stage_regs[0][i] <= '0;
            valid_pipe[0] <= 1'b0;
            mode_pipe[0]  <= 1'b0;
        end else begin
            // Bit-reversed input write
            for (int i = 0; i < N; i++) begin
                stage_regs[0][i] <= Data_in[bit_reverse_func(i)];
            end
            // Capture control signals
            valid_pipe[0] <= data_valid_in;
            mode_pipe[0]  <= iNTT_mode;
        end
    end

    // ============================================================
    // 4. Butterfly network + pipeline generation
    // ============================================================
    genvar s, g, b; 

    generate
        // For each stage (0 to LOG2_N-1)
        for (s = 0; s < LOG2_N; s = s + 1) begin : STAGE_LOOP
            
            localparam stride     = 1 << s;
            localparam num_groups = N / (stride * 2);

            // --------------------------------------------------------
            // A. Instantiate 2-stage butterflies for this stage
            // --------------------------------------------------------
            for (g = 0; g < num_groups; g = g + 1) begin : GROUP_LOOP
                for (b = 0; b < stride; b = b + 1) begin : BFLY_LOOP
                    localparam top_idx     = (g * stride * 2) + b;
                    localparam bot_idx     = (g * stride * 2) + b + stride;
                    localparam twiddle_idx = b * num_groups;

                    ntt_butterfly_2stage #(
                        .W(W),
                        .Q(Modulus_Q)
                    ) ntt_bfly_inst (
                        .clk(clk),        
                        .reset(reset),
                        
                        // Mode for this stage
                        .iNTT_mode(mode_pipe[s]), 

                        // Inputs from current stage registers
                        .A_in(stage_regs[s][top_idx]),
                        .B_in(stage_regs[s][bot_idx]),
                        
                        // Twiddle factors (forward + inverse)
                        .Wk_fwd(TWIDDLE_ROM_FWD[twiddle_idx]),
                        .Wk_inv(TWIDDLE_ROM_INV[twiddle_idx]),

                        // Outputs to next-stage wires (butterfly latency = 1 cycle)
                        .A_out(butterfly_out_wires[s][top_idx]),
                        .B_out(butterfly_out_wires[s][bot_idx])
                    );
                end 
            end 

            // --------------------------------------------------------
            // B. Pipeline-register update (data + control)
            // --------------------------------------------------------
            // Butterfly consumes 2 cycles (internal + output reg)
            
            // Data pipeline registers
            always_ff @(posedge clk or posedge reset) begin
                if (reset) begin
                    for (int k = 0; k < N; k++) stage_regs[s+1][k] <= '0;
                end else begin
                    stage_regs[s+1] <= butterfly_out_wires[s];
                end
            end

            // Control-signal pipeline (valid + mode)
            // Must match the 2-cycle delay of the butterfly
            reg valid_mid_delay; 
            reg mode_mid_delay; 

            always_ff @(posedge clk or posedge reset) begin
                if (reset) begin
                    valid_mid_delay <= 1'b0;
                    valid_pipe[s+1] <= 1'b0;
                    
                    mode_mid_delay  <= 1'b0;
                    mode_pipe[s+1]  <= 1'b0;
                end else begin
                    // Cycle 1: control enters butterfly internal stage
                    valid_mid_delay <= valid_pipe[s];
                    mode_mid_delay  <= mode_pipe[s];
                    
                    // Cycle 2: control advances to next stage
                    valid_pipe[s+1] <= valid_mid_delay;
                    mode_pipe[s+1]  <= mode_mid_delay;
                end
            end

        end // STAGE_LOOP
    endgenerate

    // ============================================================
    // 5. Output assignment
    // ============================================================
    assign Data_out       = stage_regs[LOG2_N];
    assign data_valid_out = valid_pipe[LOG2_N];
    assign mode_out       = mode_pipe[LOG2_N]; // debug: shows which mode produced this output

endmodule
