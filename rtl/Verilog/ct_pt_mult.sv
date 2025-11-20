`include "types.svh"
module ct_pt_mult (
  input  CT_t in_ct,     
  input  PT_t in_gamma,  
  output CT_t out_ct    
);

  wide_vec_t tempA, tempB;

  mult multA(
    .a(in_ct.A),
    .b(in_gamma),
    .out(tempA)
  );

  mult multB(
    .a(in_ct.B),
    .b(in_gamma),
    .out(tempB)
  );

  mod_vector modA(
    .in_vec(tempA),
    .out_vec(out_ct.A)
  );

  mod_vector modB(
    .in_vec(tempB),
    .out_vec(out_ct.B)
  );

endmodule