`include "types.svh"

// depends on fastBConv
// multi-cycle mod switch for a vector of RNS Integers
// NOTE: q modulis MUST be in the first q_BASIS_LEN slots (of each RNS Integer), and the rest must be BBa basis
module modSwitch_qBBa_to_BBa (
    input wire clk,
    input wire reset,

    input wire in_valid, // triggers the calculations to start
    input wire rns_residue_t input_RNSpoly [`N_SLOTS][`qBBa_BASIS_LEN],

    output reg out_valid,
    output wire rns_residue_t output_RNSpoly [`N_SLOTS][`BBa_BASIS_LEN] // Value is valid when out_valid is asserted
);

endmodule