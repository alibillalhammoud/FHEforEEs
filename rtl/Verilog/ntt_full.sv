/**
 * @brief 参数化的 NTT/FFT (Cooley-Tukey DIT) 模块
 *
 * * 使用 'generate' 语句为任意 N (2的幂) 自动生成级联蝶形结构。
 * * 架构: Decimation-in-Time (DIT)
 * * 输入: 自然顺序 (Natural order)
 * * 输出: 比特反转顺序 (Bit-reversed order)
 *
 * @param W          数据位宽
 * @param N          NTT/FFT 点数 (必须是 2 的幂)
 * @param Modulus_Q  NTT 运算的模数
 */


module ntt_block_radix2 #(
    parameter W         = 32,
    parameter N         = 8,
    parameter Modulus_Q = 12289999,
    parameter OMEGA     = 77777
) (
    input clk,
    input reset,
    input iNTT_mode,

    // 输入数据 (自然顺序)
    input  [W-1:0] Data_in [0:N-1],

    // 旋转因子 (Twiddle factors) W_N^0 到 W_N^(N/2 - 1)
    // input  [W-1:0] Twiddle_Wk [0:N/2-1],

    // 输出数据 (比特反转顺序)
    output [W-1:0] Data_out [0:N-1]
);

    // 自动计算所需的级数 (stages)
    localparam LOG2_N = $clog2(N);

    // --- 内部数据线网 ---
    // 用于连接各个 stage 之间的数据
    // stage_data[0] 是 NTT 的输入
    // stage_data[LOG2_N] 是 NTT 的最终输出
    logic [W-1:0] stage_data [0:LOG2_N][0:N-1];

    // 将模块输入连接到第 0 级
    // assign stage_data[0] = Data_in;

	function automatic logic [LOG2_N-1:0] bit_reverse_func (
    						input logic [LOG2_N-1:0] addr_in);
    // 循环变量 i 必须在函数内部声明
		for (int i = 0; i < LOG2_N; i = i + 1) begin
			// 函数名本身作为返回值寄存器
			bit_reverse_func[i] = addr_in[LOG2_N - 1 - i];
		end
	endfunction
	genvar i;
	generate
		for (i = 0; i < N; i = i + 1) begin : INPUT_CONNECT
			assign stage_data[0][i] = Data_in[bit_reverse_func(i)];
		end
	endgenerate

    // 将最后 H 级输出连接到模块输出
    assign Data_out = stage_data[LOG2_N];

    typedef logic [W-1:0] twiddle_array_t [0:N/2-1];

    // 2. 函数定义：返回值类型必须是上面定义的 twiddle_array_t
    function automatic twiddle_array_t gen_twiddles (
        input logic [W-1:0] base, 
        input logic [W-1:0] mod
    );
        // 内部变量也使用该类型
        twiddle_array_t tw_table;
        longint twiddle_factor;
        int i;


        twiddle_factor = 1; // Start with Wk^0 = 1
        
        for (i = 0; i < N/2; i++) begin
            tw_table[i] = twiddle_factor;
            twiddle_factor = longint'(twiddle_factor) * longint'(base) % longint'(mod);
        end
        


        return tw_table;
    endfunction

    // 3. Localparam 定义
    localparam twiddle_array_t TWIDDLE_ROM = gen_twiddles(OMEGA, Modulus_Q);



    initial begin
        $display("=== NTT Block Parameters ===");
        $display("N = %0d, Q = %0d", N, Modulus_Q);
        $display("Primitive N-th Root (Omega) = %0d", OMEGA);
        $display("Twiddle Factors:");
        for (int i = 0; i < N/2; i++) begin
            $display("TWIDDLE_ROM[%0d] = %0d", i, TWIDDLE_ROM[i]);
        end
        $display("============================");
    end

    // --- 自动生成蝶形网络 ---
    genvar s, g, b; // 'generate' 循环变量

    generate
        // 循环遍历每一级 (stage): s = 0 to LOG2_N - 1
        for (s = 0; s < LOG2_N; s = s + 1) begin : STAGE_LOOP
            
            // 当前 stage 的蝶形跨度 (stride) (s=0 -> 1, s=1 -> 2, s=2 -> 4, ...)
            localparam stride = 1 << s;
            
            // 当前 stage 的蝶形组数 (num_groups) (N=8: s=0 -> 4, s=1 -> 2, s=2 -> 1)
            localparam num_groups = N / (stride * 2);

            // 循环遍历每个蝶形组 (group)
            for (g = 0; g < num_groups; g = g + 1) begin : GROUP_LOOP

                // 循环遍历一个组内的每个蝶形单元 (butterfly)
                for (b = 0; b < stride; b = b + 1) begin : BFLY_LOOP

                    // --- 计算索引 ---
                    // 蝶形单元的两个输入/输出索引
                    localparam top_idx = (g * stride * 2) + b;
                    localparam bot_idx = (g * stride * 2) + b + stride;

                    // 蝶形单元所需的旋转因子 (twiddle factor) 索引
                    // 公式: k = b * (N / (2 * stride)) -> 恰好等于 b * num_groups
                    localparam twiddle_idx = b * num_groups;

                    // --- 实例化蝶形单元 ---
                    ntt_butterfly #(
                        .W(W),
                        .Q(Modulus_Q)
                    ) ntt_bfly_inst (
                        .clk(clk),
                        .reset(reset),
                        .iNTT_mode(iNTT_mode),

                        // 输入来自上一级 (stage 's')
                        .A_in(stage_data[s][top_idx]),
                        .B_in(stage_data[s][bot_idx]),
                        .Wk_in(TWIDDLE_ROM[twiddle_idx]),

                        // 输出连接到下一级 (stage 's+1')
                        .A_out(stage_data[s+1][top_idx]),
                        .B_out(stage_data[s+1][bot_idx])
                    );

                end // BFLY_LOOP (butterfly)
            end // GROUP_LOOP (group)
        end // STAGE_LOOP (stage)
    endgenerate

endmodule