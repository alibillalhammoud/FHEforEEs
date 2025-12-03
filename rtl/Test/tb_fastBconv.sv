`timescale 1ns/1ps
`include "types.svh"


module tb_fastBConvSingle;

localparam int unsigned IN_BASIS_LEN = `q_BASIS_LEN;
localparam int unsigned OUT_BASIS_LEN = `qBBa_BASIS_LEN;

localparam rns_residue_t IN_BASIS [IN_BASIS_LEN] = q_BASIS;
localparam rns_residue_t OUT_BASIS [OUT_BASIS_LEN] = qBBa_BASIS;

localparam rns_residue_t ZiLUT [IN_BASIS_LEN] = z_MOD_q;

localparam rns_residue_t YMODB [OUT_BASIS_LEN][IN_BASIS_LEN] = y_q_TO_qBBa;

//------------------------------------------------------------
// DUT I/O
//------------------------------------------------------------
logic clk = 0;
logic in_valid;
logic reset = 0;
rns_residue_t input_RNSint [IN_BASIS_LEN];

logic out_valid;
rns_residue_t output_RNSint [OUT_BASIS_LEN];

//------------------------------------------------------------
// Clock
//------------------------------------------------------------
always #5 clk = ~clk;

//------------------------------------------------------------
// DUT instance
//------------------------------------------------------------
fastBConvSingle #(
    .IN_BASIS_LEN (IN_BASIS_LEN),
    .OUT_BASIS_LEN(OUT_BASIS_LEN),
    .IN_BASIS (IN_BASIS),
    .OUT_BASIS (OUT_BASIS),
    .ZiLUT (ZiLUT),
    .YMODB (YMODB)
) dut (
    .clk (clk),
    .reset (reset),
    .in_valid (in_valid),
    .input_RNSint (input_RNSint),
    .out_valid (out_valid),
    .output_RNSint (output_RNSint)
);

//------------------------------------------------------------
// Golden model – identical arithmetic to Fast-BConv
//------------------------------------------------------------
function automatic void fastBConv_gold
    (input rns_residue_t xi [IN_BASIS_LEN],
    output rns_residue_t cj [OUT_BASIS_LEN]);
    rns_residue_t ai [IN_BASIS_LEN];
    rns_residue_t acc [OUT_BASIS_LEN];

    // ai  =  (xi * zi) mod qi
    for (int i = 0; i < IN_BASIS_LEN; i++) begin
        wide_rns_residue_t xzi_1 = xi[i] * ZiLUT[i];
        ai[i] = xzi_1 % IN_BASIS[i];
    end

    // cj accumulation
    for (int j = 0; j < OUT_BASIS_LEN; j++) begin
        acc[j] = '0;
        for (int i = 0; i < IN_BASIS_LEN; i++) begin
            wide_rns_residue_t psumnomod = ai[i] * YMODB[j][i];
            rns_residue_t psum = psumnomod % OUT_BASIS[j];
            acc[j]             = (acc[j] + psum) % OUT_BASIS[j];
        end
        cj[j] = acc[j];
    end

endfunction

//------------------------------------------------------------
// Test stimulus
//------------------------------------------------------------
localparam int NUM_TRIALS = 1000;
int unsigned pass_cnt = 0;
int unsigned fail_cnt = 0;

// hardcoded example expected output residues
rns_residue_t residues_before [11] = '{171, 248439331, 286163143, 1967172438, 241628409, 1837085570 ,1718631786 ,1862869392 ,458203860 ,765047659 ,1517904771};
rns_residue_t residues_after [31] = '{171, 248439331, 286163143, 1967172438, 241628409, 1837085570 ,1718631786 ,1862869392 ,458203860 ,765047659 ,1517904771, 499684161, 1971384895 ,1200237882, 396650664 ,1311262823, 231663970, 1167503752, 165387813, 847607089, 1312825462, 1945043885, 1969036839, 1379338755, 1021240996, 442208247, 431043462, 668688103, 808474874, 656330695, 1833556700};
rns_residue_t verilog_gold [OUT_BASIS_LEN];

logic DEBUG_MODE = 0;
logic COMPARE_PYTHON = 1;
rns_residue_t goldans [OUT_BASIS_LEN];
bit mismatch;
initial begin
    $display("input basis is:");
    for(int i=0; i<IN_BASIS_LEN;++i) begin
        $display("\t%d",IN_BASIS[i]);
    end
    $display("\noutput basis is:");
    for(int j=0; j<OUT_BASIS_LEN;++j) begin
        $display("\t%d",OUT_BASIS[j]);
    end
    @(posedge clk);
    @(negedge clk)
    in_valid = 0;
    reset = 1;
    input_RNSint = '{default:'0};
    @(negedge clk); // give DUT one cycle of reset
    reset = 0;

    // first trial is hardcoded (vs python) and must use qBBA (only happens in COMPARE_PYTHON mode). After that it is random testing
    for (int t = 0; t < NUM_TRIALS; t++) begin
        // generate a random big integer (256 bits)
        logic [255:0] x_rand = { $urandom, $urandom, $urandom, $urandom, $urandom, $urandom, $urandom, $urandom };
        // convert to residues w.r.t each qi
        for (int i = 0; i < IN_BASIS_LEN; i++) begin
            if(COMPARE_PYTHON && t==0) begin
                assert (OUT_BASIS_LEN == 31) else $error("Error: cannot run debug mode unless input basis is q and output is qBBa");
                input_RNSint[i] = residues_before[i];
            end else begin
                input_RNSint[i] = x_rand % IN_BASIS[i];
            end
        end

        // compute golden answer
        if(COMPARE_PYTHON && t==0) begin
            for(int j=0; j<OUT_BASIS_LEN; ++j) begin
                goldans[j] = residues_after[j];
            end
            fastBConv_gold(input_RNSint, verilog_gold);
        end else begin
            fastBConv_gold(input_RNSint, goldans);
        end

        //  Drive DUT  (in_valid asserted for 1 clk)
        @(negedge clk);
        in_valid = 1'b1;
        @(negedge clk);
        in_valid = 1'b0;

        // Wait for out_valid from DUT (and print outputs)
        while (!out_valid) begin
            @(posedge clk);
            if(DEBUG_MODE) begin
                $display("Time=%0t | STATE=%0d | active=%b | a_res=%p | output_RNSint=%p",
                    $time, dut.current_state, dut.compute_is_active, dut.a_res, dut.output_RNSint);
            end
        end

        // Compare
        mismatch = 0;
        for(int j = 0; j < OUT_BASIS_LEN; j++) begin
            if(output_RNSint[j] !== goldans[j]) begin
                $display("[%0t]  Trial %0d  MISMATCH  bj[%0d]: DUT=%0d  GOLD=%0d",
                        $time, t, j, output_RNSint[j], goldans[j]);
                mismatch = 1;
            end
        end

        if (mismatch) begin 
            fail_cnt++; 
        end else begin
            pass_cnt++;
        end
    
    end // end for

    //-----------------------------------------------------
    //  Summary
    //-----------------------------------------------------
    $display("\n\n==============================================");
    $display("FastBConvSingle TB finished  --  %0d / %0d passed",
            pass_cnt, NUM_TRIALS);
    $display("==============================================\n\n");

    $finish;

end  // end initial begin

endmodule
