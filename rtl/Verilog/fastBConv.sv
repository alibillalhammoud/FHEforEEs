// fastBConv : RNS basis-conversion datapath
//
//  Implements the “Hardware step” in the Python fastBconv()
//      ai  = (xi * zi)                  mod qi
//      cj  = Σi (ai * yib[j][i])        mod bj
//
//  All expensive constants (zi, bj, yib) are pre-computed in software
//  and supplied to the RTL through parameters.
//
//  Notes
//  - Combinational version below; add pipeline regs if timing closes
//  - Width W must be large enough to hold any modulus in either basis
//  - Mod-multiplication is done with a simple (A*B) % M function here;
//    swap in Barrett/Montgomery blocks if you have them.
//---------------------------------------------------------------------
module fastBConv #(
    //-----------------------------------------------------------------
    // GLOBAL SIZES
    //-----------------------------------------------------------------
    parameter int unsigned W      = 32,          // datapath width
    parameter int unsigned N_IN   = 4,           // |input  basis|
    parameter int unsigned N_OUT  = 4,           // |target basis|
    //-----------------------------------------------------------------
    // PER-BASIS CONSTANTS (all pre-computed offline)
    // qi  : input  basis moduli
    // bj  : target basis moduli
    // zi  : yi-1  = (q/qi) ^-1  mod qi
    // yib : (q/qi)            % bj
    //-----------------------------------------------------------------
    parameter logic [W-1:0] QI   [N_IN ] = '{default: 0},
    parameter logic [W-1:0] ZI   [N_IN ] = '{default: 0},
    parameter logic [W-1:0] BJ   [N_OUT] = '{default: 0},
    parameter logic [W-1:0] YMODB[N_OUT][N_IN] = '{default:'{default:0}}
) (
    //-----------------------------------------------------------------
    // INTERFACE
    //-----------------------------------------------------------------
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic                     in_valid,
    input  logic [W-1:0]             x   [N_IN],  // xi : residues in input basis

    output logic                     out_valid,
    output logic [W-1:0]             c   [N_OUT]  // cj : residues in target basis
);
    //-----------------------------------------------------------------
    //  LOCAL FUNCTIONS
    //  Simple (A*B)%M helper. Replace with Montgomery/Barrett as needed
    //-----------------------------------------------------------------
    function automatic logic [W-1:0] modmul
        (
         input logic [W-1:0] a,
         input logic [W-1:0] b,
         input logic [W-1:0] m
        );
        logic [2*W-1:0] product;
        product = a * b;
        modmul  = product % m;
    endfunction

    //-----------------------------------------------------------------
    //  COMBINATIONAL CORE
    //-----------------------------------------------------------------
    logic [W-1:0] a     [N_IN ];           // ai  = (xi*zi) mod qi
    logic [W-1:0] sum   [N_OUT];           // accumulator for each bj
    integer                       i, j;

    always_comb begin
        // Step-1 : ai
        for (i = 0; i < N_IN; i++) begin
            a[i] = modmul(x[i], ZI[i], QI[i]);
        end

        // Step-2 : cj
        for (j = 0; j < N_OUT; j++) begin
            logic [W-1:0] acc;
            acc = '0;
            for (i = 0; i < N_IN; i++) begin
                acc = (acc + modmul(a[i], YMODB[j][i], BJ[j])) % BJ[j];
            end
            sum[j] = acc;
        end
    end

    //-----------------------------------------------------------------
    //  SIMPLE HAND-SHAKE (1-cycle latency here, can be pipelined)
    //-----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
        end
        else begin
            out_valid <= in_valid;
        end
    end

    // Drive outputs
    for (genvar g = 0; g < N_OUT; g++) begin : OUT_ASSIGN
        always_ff @(posedge clk) begin
            if (in_valid) c[g] <= sum[g];
        end
    end
endmodule


`include "types.svh"

module fastBConv #(
    // GLOBAL SIZES
    parameter int unsigned W      = RNS_PRIME_BITS, // datapath width
    parameter int unsigned N_IN   = 4, // length(input basis)
    parameter int unsigned N_OUT  = 4, // length(target basis)
    // PER-BASIS CONSTANTS (all pre-computed offline)
    // qi  : input  basis moduli
    // bj  : target basis moduli
    // zi  : yi-1  = (q/qi) ^-1  mod qi
    // yib : (q/qi)            % bj
    parameter logic [W-1:0] QI   [N_IN ] = '{default: 0},
    parameter logic [W-1:0] ZI   [N_IN ] = '{default: 0},
    parameter logic [W-1:0] BJ   [N_OUT] = '{default: 0},
    parameter logic [W-1:0] YMODB[N_OUT][N_IN] = '{default:'{default:0}}
) (
    // IO
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic                     in_valid,
    input  logic [W-1:0]             x   [N_IN],  // xi : residues in input basis

    output logic                     out_valid,
    output logic [W-1:0]             c   [N_OUT]  // cj : residues in target basis
);
endmodule