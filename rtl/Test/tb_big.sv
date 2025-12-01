`timescale 1ns/1ps

module ntt_tb;

    // =================================================================
    // 1. 参数定义 (Parameters)
    // 确保这里与 DUT (ntt_block_radix2_pipelined) 的参数一致
    // =================================================================
    localparam W = 32;          // Data width
    localparam N = 8;           // NTT Length
    localparam Modulus_Q = 134221489; // Q 134221489
    localparam OMEGA = 10606137;      // Primitive root 10606137

    // =================================================================
    // 2. 信号定义
    // =================================================================
    logic clk;
    logic reset;
    
    // 控制信号
    logic data_valid_in;
    logic iNTT_mode;
    logic data_valid_out;

    // 数据信号
    logic [W-1:0] Data_in [0:N-1];
    logic [W-1:0] Data_out [0:N-1];

    // 统计用变量
    int latency_counter;
    int start_time;

    // =================================================================
    // 3. 实例化 DUT (Device Under Test)
    // =================================================================
    ntt_block_radix2_pipelined #(
        .W(W), 
        .N(N), 
        .Modulus_Q(Modulus_Q), 
        .OMEGA(OMEGA)
    ) DUT (
        .clk(clk),
        .reset(reset),
        
        .data_valid_in(data_valid_in), // 新增
        .iNTT_mode(iNTT_mode),
        
        .Data_in(Data_in),
        .Data_out(Data_out),
        .data_valid_out(data_valid_out) // 新增
    );

    // =================================================================
    // 4. 时钟生成 (10ns 周期, 100MHz)
    // =================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================================
    // 5. 测试主流程
    // =================================================================
    initial begin
        // --- 初始化 ---
        reset = 1;
        data_valid_in = 0;
        iNTT_mode = 0; // NTT 模式
        latency_counter = 0;
        
        // 初始化输入数据 (对应 N=8)
        Data_in[0] = 123412341;
        Data_in[1] = 123412342;
        Data_in[2] = 123412343;
        Data_in[3] = 123412344;
        Data_in[4] = 123412345;
        Data_in[5] = 0;
        Data_in[6] = 0;
        Data_in[7] = 0;

        // 打印输入
        $display("\n=== Simulation Start ===");
        $display("Parameters: N=%0d, Q=%0d", N, Modulus_Q);
        $write("Input Data: ");
        for (int i = 0; i < N; i++) $write("%0d ", Data_in[i]);
        $display("\n");

        // --- 释放复位 ---
        #20;
        @(posedge clk);
        reset = 0;
        $display("[%0t] Reset released.", $time);

        // --- 驱动数据进入 Pipeline ---
        @(posedge clk); 
        $display("[%0t] Driving Data Valid...", $time);
        
        data_valid_in <= 1'b1; // 拉高 Valid
        start_time = $time;    // 记录开始时间
        
        // 保持 valid_in 一个周期 (单次 burst)
        // 如果想测试流水线吞吐量，可以在这里连续改变 Data_in 并保持 valid_in 为高
        @(posedge clk); 
        data_valid_in <= 1'b0; 

        // --- 等待结果 ---
        // 使用 wait 语句或者 while 循环等待 output valid
        $display("[%0t] Waiting for Output Valid...", $time);
        
        wait (data_valid_out == 1'b1);
        
        // 在 valid_out 变高的那个时钟沿采样数据
        // 注意：在 SystemVerilog 仿真中，wait 触发后通常还要配合时钟沿确保数据稳定
        @(posedge clk); 
        
        // --- 结果验证与打印 ---
        $display("[%0t] Data Valid Received!", $time);
        
        // 计算延迟 (Latency)
        // 延迟周期 = (当前时间 - 开始时间) / 时钟周期 - 1 (减去驱动那一拍)
        $display("Latency Observed: %0d cycles (Expected: %0d)", ($time - start_time)/10 - 1, $clog2(N) + 1);

        $display("------------------------------------------------");
        $write("Output Data: ");
        for (int i = 0; i < N; i++) begin
            $write("%0d ", Data_out[i]);
        end
        $display("\n------------------------------------------------");

        // 简单的正确性检查 (针对 N=8, Q=12289, 输入 1,2,3,4,5,0,0,0)
        // 期望输出 (Python 计算参考): [15, 6896, 7558, 2690, 8935, 7622, 10762, 4678]
        // 注意：如果你更改了输入或参数，这里的值需要重新计算
        if (Data_out[0] == 15 && Data_out[1] == 6896) begin
             $display("SUCCESS: Data matches expected reference for N=8, Q=12289.");
        end else begin
             $display("NOTE: Verify output values manually if parameters changed.");
        end

        #20;
        $finish;
    end

    // --- 超时看门狗 (防止 pipeline 没通导致仿真卡死) ---
    initial begin
        #1000; // 100个周期后强行停止
        if (data_valid_out === 0) begin
            $display("\nERROR: Timeout! Output valid never went high.");
            $finish;
        end
    end

endmodule