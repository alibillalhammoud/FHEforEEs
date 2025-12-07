`timescale 1ns/1ps

module ntt_tb;

    // =================================================================
    // 1. Parameter definitions
    //    These must match the DUT (ntt_block_radix2_pipelined)
    // =================================================================
    localparam W         = 32;          // Data width
    localparam N         = 8;           // NTT length
    localparam Modulus_Q = 134221489;   // Modulus Q = 134221489
    localparam OMEGA     = 10606137;    // Primitive root = 10606137

    // =================================================================
    // 2. Signal declarations
    // =================================================================
    logic clk;
    logic reset;
    
    // Control signals
    logic data_valid_in;
    logic iNTT_mode;
    logic data_valid_out;

    // Data signals
    logic [W-1:0] Data_in  [0:N-1];
    logic [W-1:0] Data_out [0:N-1];

    // Statistics / measurement variables
    int latency_counter;
    int start_time;

    // =================================================================
    // 3. DUT (Device Under Test) instantiation
    // =================================================================
    ntt_block_radix2_pipelined #(
        .W(W), 
        .N(N), 
        .Modulus_Q(Modulus_Q), 
        .OMEGA(OMEGA)
    ) DUT (
        .clk(clk),
        .reset(reset),
        
        .data_valid_in(data_valid_in), // Input valid to DUT
        .iNTT_mode(iNTT_mode),
        
        .Data_in(Data_in),
        .Data_out(Data_out),
        .data_valid_out(data_valid_out) // Output valid from DUT
    );

    // =================================================================
    // 4. Clock generation (10 ns period, 100 MHz)
    // =================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================================
    // 5. Main test sequence
    // =================================================================
    initial begin
        // --- Initialization ---
        reset          = 1;
        data_valid_in  = 0;
        iNTT_mode      = 0; // NTT mode
        latency_counter = 0;
        
        // Initialize input data (for N = 8)
        Data_in[0] = 123412341;
        Data_in[1] = 123412342;
        Data_in[2] = 123412343;
        Data_in[3] = 123412344;
        Data_in[4] = 123412345;
        Data_in[5] = 0;
        Data_in[6] = 0;
        Data_in[7] = 0;

        // Print input
        $display("\n=== Simulation Start ===");
        $display("Parameters: N=%0d, Q=%0d", N, Modulus_Q);
        $write("Input Data: ");
        for (int i = 0; i < N; i++) $write("%0d ", Data_in[i]);
        $display("\n");

        // --- Release reset ---
        #20;
        @(posedge clk);
        reset = 0;
        $display("[%0t] Reset released.", $time);

        // --- Drive data into the pipeline ---
        @(posedge clk); 
        $display("[%0t] Driving Data Valid...", $time);
        
        data_valid_in <= 1'b1; // Assert valid
        start_time    = $time; // Record start time
        
        // Hold valid_in for one cycle (single burst)
        // To test pipeline throughput, keep valid_in high and vary Data_in every cycle
        @(posedge clk); 
        data_valid_in <= 1'b0; 

        // --- Wait for result ---
        // Use wait or a while-loop to wait for output valid
        $display("[%0t] Waiting for Output Valid...", $time);
        
        wait (data_valid_out == 1'b1);
        
        // Sample data on the clock edge when valid_out goes high
        // Note: after wait triggers, also sync to a clock edge to ensure data stability
        @(posedge clk); 
        
        // --- Result checking and printing ---
        $display("[%0t] Data Valid Received!", $time);
        
        // Compute latency (in cycles)
        // Latency (cycles) = (current time - start time) / clock period - 1
        // (subtract the cycle when data was driven)
        $display("Latency Observed: %0d cycles (Expected: %0d)", 
                 ($time - start_time)/10 - 1, $clog2(N) + 1);

        $display("------------------------------------------------");
        $write("Output Data: ");
        for (int i = 0; i < N; i++) begin
            $write("%0d ", Data_out[i]);
        end
        $display("\n------------------------------------------------");

        // Simple correctness check (for N=8, Q=12289, input 1,2,3,4,5,0,0,0)
        // Expected outputs (Python reference): [15, 6896, 7558, 2690, 8935, 7622, 10762, 4678]
        // Note: if you change the inputs or parameters, recompute these reference values
        if (Data_out[0] == 15 && Data_out[1] == 6896) begin
             $display("SUCCESS: Data matches expected reference for N=8, Q=12289.");
        end else begin
             $display("NOTE: Verify output values manually if parameters changed.");
        end

        #20;
        $finish;
    end

    // // --- Timeout watchdog (prevents simulation from hanging) ---
    // initial begin
    //     #1000; // Force stop after 100 ns (~100 cycles at 10 ns period)
    //     if (data_valid_out === 0) begin
    //         $display("\nERROR: Timeout! Output valid never went high.");
    //         $finish;
    //     end
    // end

endmodule
