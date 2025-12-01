`timescale 1ns/1ps

module tb_full_mult;

    // =================================================================
    // 1. PARAMETERS & CONFIGURATION
    // =================================================================
    localparam W = 32;
    localparam N = 8;
    localparam Modulus_Q = 241;
    
    // NTT Parameters
    localparam OMEGA     = 30;  // 241 is prime, Omega=30 is 8-th root of unity
    localparam OMEGA_INV = 233; // Inverse of 30 mod 241
    
    // Negacyclic Convolution Parameters (psi^2 = omega)
    localparam PSI       = 111; // 16-th root of unity
    localparam PSI_INV   = 76; 
    localparam N_INV     = 211; // 8^-1 mod 241

    // Signals
    logic clk;
    logic reset;
    logic data_valid_in;
    logic iNTT_mode;
    logic [W-1:0] Data_in_dut [0:N-1]; // 连接到 DUT 的输入
    
    logic [W-1:0] Data_out_dut [0:N-1]; // 来自 DUT 的输出
    logic data_valid_out;
    logic mode_out_monitor; // 我们可以把 mode_out 也拉出来观察

    // =================================================================
    // 2. DATA STORAGE FOR STAGES
    // =================================================================
    // 原始多项式
    logic [W-1:0] poly_a [0:N-1];
    logic [W-1:0] poly_b [0:N-1];
    
    // Stage 1: Twisted Data (Software)
    logic [W-1:0] poly_a_twisted [0:N-1];
    logic [W-1:0] poly_b_twisted [0:N-1];

    // Stage 2: NTT Result (Hardware Output)
    logic [W-1:0] poly_A_NTT [0:N-1];
    logic [W-1:0] poly_B_NTT [0:N-1];

    // Stage 3: Pointwise Multiplication (Software)
    logic [W-1:0] poly_C_mult [0:N-1];

    // Stage 4: iNTT Result (Hardware Output)
    logic [W-1:0] poly_C_iNTT [0:N-1];

    // Stage 5: Final Result (Untwisted & Scaled) (Software)
    logic [W-1:0] poly_c_final [0:N-1];
    
    // Golden Reference
    logic [W-1:0] poly_golden [0:N-1];

    // =================================================================
    // 3. DUT INSTANTIATION
    // =================================================================
    ntt_block_radix2_pipelined #(
        .W(W), 
        .N(N), 
        .Modulus_Q(Modulus_Q), 
        .OMEGA(OMEGA),
        .OMEGA_INV(OMEGA_INV)
    ) DUT (
        .clk(clk),
        .reset(reset),
        .data_valid_in(data_valid_in), 
        .iNTT_mode(iNTT_mode),
        .Data_in(Data_in_dut), 
        .Data_out(Data_out_dut),
        .data_valid_out(data_valid_out),
        .mode_out(mode_out_monitor)
    );

    // Clock Gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================================
    // 4. HELPER TASKS (MATH OPERATIONS)
    // =================================================================
    
    // Task: 打印数组
    task print_array(input string name, input logic [W-1:0] arr [0:N-1]);
        $write("%s: [ ", name);
        for(int i=0; i<N; i++) $write("%0d ", arr[i]);
        $display("]");
    endtask

    // Task: Twist / Untwist ( mult by factor^i )
    task calc_twist_untwist(
        input logic [W-1:0] in_arr [0:N-1],
        output logic [W-1:0] out_arr [0:N-1],
        input int factor
    );
        longint p_pow = 1;
        for(int i=0; i<N; i++) begin
            out_arr[i] = (longint'(in_arr[i]) * p_pow) % Modulus_Q;
            p_pow = (p_pow * factor) % Modulus_Q;
        end
    endtask
        task calc_twist_untwista(
        input logic [W-1:0] in_arr [0:N-1],
        output logic [W-1:0] out_arr [0:N-1],
        input int factor
    );
        longint p_pow = 1;
        for(int i=0; i<N; i++) begin
            out_arr[i] = (longint'(in_arr[i]) * p_pow) % Modulus_Q;
            p_pow = (p_pow * factor) % Modulus_Q;
        end
    endtask
        task calc_twist_untwistb(
        input logic [W-1:0] in_arr [0:N-1],
        output logic [W-1:0] out_arr [0:N-1],
        input int factor
    );
        longint p_pow = 1;
        for(int i=0; i<N; i++) begin
            out_arr[i] = (longint'(in_arr[i]) * p_pow) % Modulus_Q;
            p_pow = (p_pow * factor) % Modulus_Q;
        end
    endtask

    // Task: Element-wise Multiplication Mod Q
    task calc_pointwise_mult(
        input logic [W-1:0] in_a [0:N-1],
        input logic [W-1:0] in_b [0:N-1],
        output logic [W-1:0] out_c [0:N-1]
    );
        for(int i=0; i<N; i++) begin
            out_c[i] = (longint'(in_a[i]) * longint'(in_b[i])) % Modulus_Q;
        end
    endtask

    // Task: Scalar Multiplication (Multiply by N_INV)
    task calc_scalar_mult(
        input logic [W-1:0] in_arr [0:N-1],
        output logic [W-1:0] out_arr [0:N-1],
        input int scalar
    );
        for(int i=0; i<N; i++) begin
            out_arr[i] = (longint'(in_arr[i]) * scalar) % Modulus_Q;
        end
    endtask

    // Task: Naive Negacyclic Convolution (Golden Reference)
    // C[k] = sum(a[i]*b[j]) where i+j = k  MINUS sum(a[i]*b[j]) where i+j = k+N
    task calc_golden_ref(
        input logic [W-1:0] in_a [0:N-1],
        input logic [W-1:0] in_b [0:N-1],
        output logic [W-1:0] out_gold [0:N-1]
    );
        longint sum;
        int k, i, j;
        for (k=0; k<N; k++) begin
            sum = 0;
            for (i=0; i<N; i++) begin
                for (j=0; j<N; j++) begin
                    if (i + j == k) 
                        sum = (sum + longint'(in_a[i]) * longint'(in_b[j])) % Modulus_Q;
                    else if (i + j == k + N)
                        // Negative wraparound: (A - B) mod Q = (A + Q - B) mod Q
                        sum = (sum + Modulus_Q - (longint'(in_a[i]) * longint'(in_b[j]) % Modulus_Q)) % Modulus_Q;
                end
            end
            out_gold[k] = sum;
        end
    endtask

    // Task: Send Data to DUT
    task send_packet(input logic [W-1:0] payload [0:N-1], input logic mode);
        @(posedge clk);
        Data_in_dut <= payload;
        iNTT_mode <= mode;
        data_valid_in <= 1'b1;
        @(posedge clk);
        data_valid_in <= 1'b0; // Pulse valid for 1 cycle
        // Data_in_dut can become 'x or stay same, doesn't matter
    endtask

    // =================================================================
    // 5. MAIN TEST PROCESS
    // =================================================================
    initial begin
        // --- 0. Initialize ---
        reset = 1;
        data_valid_in = 0;
        iNTT_mode = 0;
        
        // Setup Input Polynomials
        poly_a = '{1, 2, 3, 4, 5, 6, 3, 8};
        poly_b = '{1, 2, 3, 4, 5, 6, 7, 8};

        $display("\n=========================================================");
        $display("  POLYNOMIAL MULTIPLICATION TEST (Negacyclic)");
        $display("  Parameters: N=%0d, Q=%0d, PSI=%0d, N_INV=%0d", N, Modulus_Q, PSI, N_INV);
        $display("=========================================================");

        print_array("Input Poly A", poly_a);
        print_array("Input Poly B", poly_b);

        // --- 1. Software Twist (Pre-processing) ---
        $display("\n--- [Step 1] Software Twist (x PSI^i) ---");
        calc_twist_untwista(poly_a, poly_a_twisted, PSI);
        calc_twist_untwistb(poly_b, poly_b_twisted, PSI);
        print_array("A Twisted", poly_a_twisted);
        print_array("B Twisted", poly_b_twisted);

        // --- 2. Hardware NTT (Pipeline Feed) ---
        // Release Reset
        #20;
        @(posedge clk); reset = 0;
        #20;

        $display("\n--- [Step 2] Sending A & B to DUT (NTT Mode) ---");
        
        // Pipelined Send: Send A, then immediately Send B
        fork
            begin
                send_packet(poly_a_twisted, 1'b0); // Mode 0 = NTT
                send_packet(poly_b_twisted, 1'b0); // Mode 0 = NTT
            end
            begin
                // Receive A
                wait(data_valid_out == 1);
                @(negedge clk); // Sample on negedge to be safe or use registered output
                poly_A_NTT = Data_out_dut;
                $display("  -> Received NTT(A) from DUT");
                
                @(posedge clk); // Wait for valid to (potentially) go low or stay high
                @(posedge clk);
                // Receive B (Since pipeline depth is constant, it comes 1 cycle later if inputs were back-to-back)
                // Wait for the next valid cycle
                while(data_valid_out !== 1) @(posedge clk);
                
                @(negedge clk);
                poly_B_NTT = Data_out_dut;
                $display("  -> Received NTT(B) from DUT");
            end
        join

        print_array("NTT(A)", poly_A_NTT);
        print_array("NTT(B)", poly_B_NTT);

        // --- 3. Software Pointwise Multiplication ---
        $display("\n--- [Step 3] Software Pointwise Mult (C = A * B) ---");
        calc_pointwise_mult(poly_A_NTT, poly_B_NTT, poly_C_mult);
        print_array("C (Pointwise)", poly_C_mult);

        // --- 4. Hardware iNTT ---
        $display("\n--- [Step 4] Sending C to DUT (iNTT Mode) ---");
        // Ensure some gap (optional, but good for waveform clarity)
        #20; 
        
        fork 
            begin
                send_packet(poly_C_mult, 1'b1); // Mode 1 = iNTT
            end
            begin
                wait(data_valid_out == 1 && mode_out_monitor == 1); // Ensure we catch the iNTT packet
                @(negedge clk);
                poly_C_iNTT = Data_out_dut;
                $display("  -> Received iNTT(C) from DUT");
            end
        join

        print_array("iNTT(C) Raw", poly_C_iNTT);

        // --- 5. Software Post-Processing (Scale & Untwist) ---
        $display("\n--- [Step 5] Software Post-Processing ---");
        
        // Multiply by N_INV
        calc_scalar_mult(poly_C_iNTT, poly_c_final, N_INV); 
        print_array("C * N_inv", poly_c_final);

        // Untwist (Multiply by PSI_INV^i)
        // 注意：因为 SystemVerilog 数组传递是引用还是复制有时候比较绕，
        // 这里直接用 c_final 作为输入和输出（假设 calc_twist_untwist 支持原地操作，
        // 或者我们用一个临时变量）。我的 task 实现支持原地操作吗？
        // out_arr[i] = in_arr[i] * ... ; 如果 in 和 out 指向同一个内存，是可以的。
        // 但为了安全，我们用一个 temp 或者分步。这里直接覆盖 poly_c_final。
        
        begin
            logic [W-1:0] temp [0:N-1];
            calc_twist_untwist(poly_c_final, temp, PSI_INV);
            poly_c_final = temp;
        end
        print_array("Final Result (Untwisted)", poly_c_final);

        // --- 6. Golden Check ---
        $display("\n--- [Step 6] Verification ---");
        calc_golden_ref(poly_a, poly_b, poly_golden);
        print_array("Golden Ref", poly_golden);

        // Compare
        begin
            int err_cnt = 0;
            for(int i=0; i<N; i++) begin
                if(poly_c_final[i] !== poly_golden[i]) begin
                    $display("ERROR at index %0d: Expected %0d, Got %0d", i, poly_golden[i], poly_c_final[i]);
                    err_cnt++;
                end
            end

            if(err_cnt == 0) 
                $display("\nSUCCESS: Hardware Pipeline Matches Golden Model!");
            else
                $display("\nFAILURE: Found %0d mismatches.", err_cnt);
        end

        #50;
        $finish;
    end

    // Watchdog
    initial begin
        #5000;
        $display("ERROR: Watchdog Timeout");
        $finish;
    end

endmodule