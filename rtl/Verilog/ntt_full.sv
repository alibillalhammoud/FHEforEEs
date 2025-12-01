module ntt_block_radix2_pipelined #(
    parameter W           = 32,
    parameter N           = 8,
    parameter Modulus_Q   = 241,
    parameter OMEGA       = 30,
    parameter OMEGA_INV   = 233
) (
    input  logic clk,
    input  logic reset,
    
    // 控制信号
    input  logic data_valid_in, // 输入数据有效指示
    input  logic iNTT_mode,     // 0: NTT, 1: iNTT (每一帧数据可以独立切换)

    // 输入数据 (自然顺序)
    input  logic [W-1:0] Data_in [0:N-1],

    // 输出数据 (比特反转顺序)
    output logic [W-1:0] Data_out [0:N-1],
    output logic         data_valid_out, // 输出数据有效指示
    output logic         mode_out        // 指示当前输出数据的模式 (调试用)
);

    // 计算级数
    localparam LOG2_N = $clog2(N);

    // ============================================================
    // 1. 定义流水线寄存器 (Data, Valid, Mode)
    // ============================================================
    
    // Data Pipeline
    logic [W-1:0] stage_regs [0:LOG2_N][0:N-1];
    logic [W-1:0] butterfly_out_wires [0:LOG2_N-1][0:N-1];

    // Control Pipeline (Valid & Mode)
    // valid_pipe[s] 和 mode_pipe[s] 对应 stage_regs[s]
    logic [LOG2_N:0] valid_pipe;
    logic [LOG2_N:0] mode_pipe;

    // ============================================================
    // 2. 预计算旋转因子 (Dual Twiddle Factors)
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

    // 生成两张 ROM 表
    localparam twiddle_array_t TWIDDLE_ROM_FWD = gen_twiddles(OMEGA, Modulus_Q);
    localparam twiddle_array_t TWIDDLE_ROM_INV = gen_twiddles(OMEGA_INV, Modulus_Q);

    // ============================================================
    // 3. 输入级：比特反转 + Control 打拍
    // ============================================================
    // 这一级消耗 1 个 Cycle
    
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
            // 数据打拍（Bit Reversal）
            for (int i = 0; i < N; i++) begin
                stage_regs[0][i] <= Data_in[bit_reverse_func(i)];
            end
            // 控制信号同步打拍
            valid_pipe[0] <= data_valid_in;
            mode_pipe[0]  <= iNTT_mode; // 捕获当前的模式
        end
    end

    // ============================================================
    // 4. 生成蝶形网络与流水线
    // ============================================================
    genvar s, g, b; 

    generate
        // 遍历每一级 (Stage 0 到 LOG2_N-1)
        for (s = 0; s < LOG2_N; s = s + 1) begin : STAGE_LOOP
            
            localparam stride = 1 << s;
            localparam num_groups = N / (stride * 2);

            // --------------------------------------------------------
            // A. 实例化 2-Stage 蝴蝶单元
            // --------------------------------------------------------
            for (g = 0; g < num_groups; g = g + 1) begin : GROUP_LOOP
                for (b = 0; b < stride; b = b + 1) begin : BFLY_LOOP
                    localparam top_idx = (g * stride * 2) + b;
                    localparam bot_idx = (g * stride * 2) + b + stride;
                    localparam twiddle_idx = b * num_groups;

                    // 使用支持 Dual Mode 的 2-Stage 模块
                    ntt_butterfly_2stage #(
                        .W(W),
                        .Q(Modulus_Q)
                    ) ntt_bfly_inst (
                        .clk(clk),        
                        .reset(reset),
                        
                        // Control: 使用当前 Stage 的 mode 信号
                        .iNTT_mode(mode_pipe[s]), 

                        // Inputs: 来自当前级的寄存器
                        .A_in(stage_regs[s][top_idx]),
                        .B_in(stage_regs[s][bot_idx]),
                        
                        // Twiddles: 同时传入 FWD 和 INV 因子
                        .Wk_fwd(TWIDDLE_ROM_FWD[twiddle_idx]),
                        .Wk_inv(TWIDDLE_ROM_INV[twiddle_idx]),

                        // Outputs: 连接到临时 Wire (Stage Delay = 1 cycle internally)
                        .A_out(butterfly_out_wires[s][top_idx]),
                        .B_out(butterfly_out_wires[s][bot_idx])
                    );
                end 
            end 

            // --------------------------------------------------------
            // B. 流水线寄存器更新逻辑 (Data + Control)
            // --------------------------------------------------------
            // 每级 Butterfly 逻辑上消耗 2 Cycles (Internal Reg + Output Reg)
            
            // 1. 数据路径寄存器
            always_ff @(posedge clk or posedge reset) begin
                if (reset) begin
                    for (int k = 0; k < N; k++) stage_regs[s+1][k] <= '0;
                end else begin
                    stage_regs[s+1] <= butterfly_out_wires[s];
                end
            end

            // 2. Control 信号路径 (Valid & Mode)
            // 需要匹配 Butterfly 的 2 Cycle Latency
            reg valid_mid_delay; 
            reg mode_mid_delay; 

            always_ff @(posedge clk or posedge reset) begin
                if (reset) begin
                    valid_mid_delay <= 1'b0;
                    valid_pipe[s+1] <= 1'b0;
                    
                    mode_mid_delay  <= 1'b0;
                    mode_pipe[s+1]  <= 1'b0;
                end else begin
                    // Cycle 1: 信号进入 Butterfly 内部 (Internal Reg 阶段)
                    valid_mid_delay <= valid_pipe[s];
                    mode_mid_delay  <= mode_pipe[s];
                    
                    // Cycle 2: 信号随 Result 一起到达下一级 Stage Register
                    valid_pipe[s+1] <= valid_mid_delay;
                    mode_pipe[s+1]  <= mode_mid_delay;
                end
            end

        end // STAGE_LOOP
    endgenerate

    // ============================================================
    // 5. 输出连接
    // ============================================================
    assign Data_out       = stage_regs[LOG2_N];
    assign data_valid_out = valid_pipe[LOG2_N];
    assign mode_out       = mode_pipe[LOG2_N]; // 用于验证输出是属于哪种 Mode

endmodule