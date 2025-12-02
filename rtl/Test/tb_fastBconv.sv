module tb_fastBConvSingle;

//------------------------------------------------------------
// Small demo bases (3 qi’s --> 2 bj’s)
//------------------------------------------------------------
localparam int unsigned IN_BASIS_LEN = 3;
localparam int unsigned OUT_BASIS_LEN = 2;

// qi = {5,7,11}
localparam rns_residue_t IN_BASIS [IN_BASIS_LEN] = '{ 5, 7, 11 };
// bj = {13,17}
localparam rns_residue_t OUT_BASIS [OUT_BASIS_LEN] = '{ 13, 17 };

// zi = (q/qi)^{-1} mod qi
localparam rns_residue_t ZiLUT [IN_BASIS_LEN] = '{ 3, 6, 6 };

// yib = (q/qi) mod bj (rows -> bj, columns -> qi)
localparam rns_residue_t YMODB [OUT_BASIS_LEN][IN_BASIS_LEN] = '{ '{ 12, 3, 9 }, // for bj = 13 
        '{ 9, 4, 1 } // for bj = 17
    };

//------------------------------------------------------------
// DUT I/O
//------------------------------------------------------------
logic clk = 0;
logic in_valid;
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
    for (int i = 0; i < IN_BASIS_LEN; i++)
        ai[i] = (xi[i] * ZiLUT[i]) % IN_BASIS[i];

    // cj accumulation
    for (int j = 0; j < OUT_BASIS_LEN; j++) begin
        acc[j] = '0;
        for (int i = 0; i < IN_BASIS_LEN; i++) begin
            rns_residue_t psum = (ai[i] * YMODB[j][i]) % OUT_BASIS[j];
            acc[j]             = (acc[j] + psum) % OUT_BASIS[j];
        end
        cj[j] = acc[j];
    end

endfunction

//------------------------------------------------------------
// Test stimulus
//------------------------------------------------------------
localparam int NUM_TRIALS = 100;
int unsigned pass_cnt = 0;
int unsigned fail_cnt = 0;

initial begin
    in_valid = 0;
    input_RNSint = '{default:'0};
    @(posedge clk); // give DUT one cycle of reset-ish zeros

    for (int t = 0; t < NUM_TRIALS; t++) begin : TRIAL
        //--------------------------------------------------
        // generate a random big integer    0 ...(2^31-1)
        //--------------------------------------------------
        int unsigned x_rand = $urandom;

        // convert to residues w.r.t each qi
        for (int i = 0; i < IN_BASIS_LEN; i++)
            input_RNSint[i] = x_rand % IN_BASIS[i];

        // compute golden answer
        rns_residue_t gold [OUT_BASIS_LEN];
        fastBConv_gold(input_RNSint, gold);

        //--------------------------------------------------
        //  Drive DUT  (in_valid asserted for 1 clk)
        //--------------------------------------------------
        @(negedge clk);
        in_valid = 1'b1;
        @(negedge clk);
        in_valid = 1'b0;

        //--------------------------------------------------
        // Wait for out_valid from DUT
        //--------------------------------------------------
        @(posedge out_valid);

        //--------------------------------------------------
        // Compare
        //--------------------------------------------------
        bit mismatch = 0;
        for (int j = 0; j < OUT_BASIS_LEN; j++) begin
        if (output_RNSint[j] !== gold[j]) begin
            $display("[%0t]  Trial %0d  MISMATCH  bj[%0d]: DUT=%0d  GOLD=%0d",
                    $time, t, j, output_RNSint[j], gold[j]);
            mismatch = 1;
        end
        end

        if (mismatch) fail_cnt++; else pass_cnt++;
    end  // for t
end

 //-----------------------------------------------------
 //  Summary
 //-----------------------------------------------------
 $display("==============================================");
 $display("FastBConvSingle TB finished  --  %0d / %0d passed",
           pass_cnt, NUM_TRIALS);
 $display("==============================================");

 $finish;

endmodule