`include "types.svh"

module cpu (
  input  logic clk,
  input  logic reset,
  input  operation op,
  output logic done_out
);

  // ============================
  //  Register file interface
  // ============================

  logic [$clog2(`REG_NPOLY)-1:0] source0_register_index_q;
  logic [$clog2(`REG_NPOLY)-1:0] source1_register_index_q;
  logic [$clog2(`REG_NPOLY)-1:0] source2_register_index_q;
  logic [$clog2(`REG_NPOLY)-1:0] source3_register_index_q;
  logic [$clog2(`REG_NPOLY)-1:0] dest0_register_index_q;
  logic [$clog2(`REG_NPOLY)-1:0] dest1_register_index_q;

  logic   source0_valid_q, source1_valid_q, source2_valid_q, source3_valid_q;
  q_BASIS_poly   source0_poly_q, source1_poly_q;
  q_BASIS_poly   source2_poly_q, source3_poly_q;

  logic   dest0_valid_q, dest1_valid_q;
  q_BASIS_poly   dest0_poly_q, dest1_poly_q;
  
  op_e operation_mode;

  // -----------------------------
  // Misc control regs
  // -----------------------------
  logic wb_valid;
  logic [3:0] stage;   // your CT-PT-MUL micro-FSM state
  logic       inverse; // NTT direction flag
  logic     wb_0_q, wb_1_q, done;

  q_BASIS_poly   op_a_q, op_b_q, op_c_q, op_d_q;
  B_BASIS_poly   op_a_b, op_b_b, op_c_b, op_d_b;
  Ba_BASIS_poly  op_a_ba, op_b_ba, op_c_ba, op_d_ba;

  q_BASIS_poly  add_out_1, add_out_2, mul_out_1_q, mul_out_2_q, fu_out_1_q, fu_out_2_q, ntt_out_1_q, ntt_out_2_q;
  B_BASIS_poly  mul_out_1_b, mul_out_2_b,fu_out_1_b, fu_out_2_b;
  Ba_BASIS_poly mul_out_1_ba, mul_out_2_ba, fu_out_1_ba, fu_out_2_ba;

  logic stage1_valid;
  q_BASIS_poly stage1_src0_q;
  q_BASIS_poly stage1_src1_q;
  q_BASIS_poly stage1_src2_q;
  q_BASIS_poly stage1_src3_q;
  op_e stage1_op_mode;
  logic [$clog2(`REG_NPOLY)-1:0] stage1_dest0_idx;
  logic [$clog2(`REG_NPOLY)-1:0] stage1_dest1_idx;

  // Parse Instruction
  always_comb begin
    operation_mode            = op.mode;
    source0_register_index_q  = op.idx1_a;
    source1_register_index_q  = op.idx1_b;
    source2_register_index_q  = op.idx2_a;
    source3_register_index_q  = op.idx2_b;
    dest0_register_index_q    = op.out_a;
    dest1_register_index_q    = op.out_b;
  end

  // ============================
  //  Instantiate register file
  // ============================

  regfile #(
    .NPRIMES(`q_BASIS_LEN)
  ) u_rf_q (
  
    .clk                 (clk),
    
    .source0_register_index (source0_register_index_q),
    .source1_register_index (source1_register_index_q),
    .source2_register_index (source2_register_index_q),
    .source3_register_index (source3_register_index_q),

    .dest0_register_index   (dest0_register_index_q),
    .dest1_register_index   (dest1_register_index_q),

    .source0_valid          (source0_valid_q),
    .source0_poly           (source0_poly_q),

    .source1_valid          (source1_valid_q),
    .source1_poly           (source1_poly_q),

    .source2_valid          (source2_valid_q),
    .source2_poly           (source2_poly_q),

    .source3_valid          (source3_valid_q),
    .source3_poly           (source3_poly_q),

    .dest0_valid            (dest0_valid_q),
    .dest0_poly             (dest0_poly_q),

    .dest1_valid            (dest1_valid_q),
    .dest1_poly             (dest1_poly_q)
  );

  // ============================
  //  STAGE 1: Register Access
  // ============================
  always_ff @(posedge clk) begin
    if (reset) begin
      dest0_valid_q     <= 1'b0;
      dest1_valid_q     <= 1'b0;
      stage1_valid      <= 1'b0;
      stage1_src0_q     <= '{default: '0};
      stage1_src1_q     <= '{default: '0};
      stage1_src2_q     <= '{default: '0};
      stage1_src3_q     <= '{default: '0};
      stage1_op_mode    <= NO_OP;
      stage1_dest0_idx  <= '0;
      stage1_dest1_idx  <= '0;
      dest0_poly_q      <= '{default: '0};
      dest1_poly_q      <= '{default: '0};
      done_out          <= '0;
      stage             <= '0;
    end else begin
      // Capture data from register file when valid
      stage1_valid      <= source0_valid_q & source1_valid_q;
      stage1_src0_q     <= source0_poly_q;
      stage1_src1_q     <= source1_poly_q;
      stage1_src2_q     <= source2_poly_q;
      stage1_src3_q     <= source3_poly_q;
      stage1_op_mode    <= operation_mode;
      stage1_dest0_idx  <= dest0_register_index_q;
      stage1_dest1_idx  <= dest1_register_index_q;
      dest0_valid_q     <= wb_0_q;
      dest1_valid_q     <= wb_1_q;
      dest0_poly_q      <= fu_out_1_q;
      dest1_poly_q      <= fu_out_2_q;
      done_out          <= done; 
      stage             <= (done) ? 4'b0 : stage + 1;
    end
  end

  // ============================
  //  Functional Units
  // ============================

  // ADDER 1
  adder u_add_1 (
    .a   (op_a_q),
    .b   (op_b_q),
    .out (add_out_1)
  );

  // ADDER 2
  adder u_add_2 (
    .a   (op_c_q),
    .b   (op_d_q),
    .out (add_out_2)
  );

  // MULT 1
  mult u_mult_1 (
    .a_q   (op_a_q), 
    .a_b  (op_a_b),
    .a_ba (op_a_ba),
    .b_q   (op_b_q), 
    .b_b  (op_b_b),
    .b_ba (op_b_ba),
    .out_q (mul_out_1_q),
    .out_b (mul_out_1_b),
    .out_ba (mul_out_1_ba)
  );

  // MULT 2
  mult u_mult_2 (
    .a_q   (op_c_q), 
    .a_b  (op_c_b),
    .a_ba (op_c_ba),
    .b_q   (op_d_q), 
    .b_b  (op_d_b),
    .b_ba (op_d_ba),
    .out_q (mul_out_2_q),
    .out_b (mul_out_2_b),
    .out_ba (mul_out_2_ba)
  );

  // NTT 1 & 2 (stubbed for now)
  assign ntt_out_1_q = '{default: '0};
  assign ntt_out_2_q = '{default: '0};

  // ============================
  //  Controller
  // ============================
  always_comb begin
    op_a_q     = '{default: '0};
    op_b_q     = '{default: '0};
    op_c_q     = '{default: '0};
    op_d_q     = '{default: '0};
    fu_out_1_q = '{default: '0};
    fu_out_2_q = '{default: '0};
    wb_0_q     = 1'b0;
    wb_1_q     = 1'b0;
    done       = 1'b0;

    if (stage1_valid) begin 
      unique case (stage1_op_mode)
        OP_CT_CT_ADD: begin
          op_a_q     = stage1_src0_q;  // CT0.A
          op_b_q     = stage1_src2_q;  // CT1.A
          op_c_q     = stage1_src1_q;  // CT0.B
          op_d_q     = stage1_src3_q;  // CT1.B

          fu_out_1_q = add_out_1;    // sum for A
          fu_out_2_q = add_out_2;    // sum for B
          wb_0_q     = 1;
          wb_1_q     = 1;
          done       = 1;
        end

        OP_CT_PT_ADD: begin
          op_a_q       = stage1_src0_q;  // CT1.A           
          op_b_q       = '{default: '0};  // 0
          op_c_q       = stage1_src1_q; // CT1.B     
          op_d_q       = stage1_src3_q; // Scaled PT            
          fu_out_1_q = op_a_q;
          fu_out_2_q = add_out_2;    
          wb_0_q     = 1;                
          wb_1_q     = 1;
          done       = 1;
        end

        // OP_CT_PT_MUL: begin
        //   case (stage)
        //   // CT1.A * Plaintext
        //   // TWIST
        //   4'b0001: begin
        //     op_a     = stage1_src0_q;                       // CT1.A (vec)
        //     op_b     = twist_factor;
        //     op_c     = stage1_src2_q;                       // PT (vec)
        //     op_d     = twist_factor;
        //     fu_out_1 = mul_out_1;
        //     fu_out_2 = mul_out_2;
        //   end
        //   // NTT
        //   4'b0010: begin
        //     inverse  = 1'b0;
        //     op_a     = dest0_coefficient;
        //     op_c     = dest1_coefficient;
        //     fu_out_1 = ntt_out_1;
        //     fu_out_2 = ntt_out_2;
        //   end
        //   // MUL
        //   4'b0011: begin
        //     op_a     = dest0_coefficient;
        //     op_b     = dest1_coefficient;
        //     fu_out_1 = mul_out_1;
        //   end
        //   // Inverse NTT
        //   4'b0100: begin
        //     inverse  = 1'b1;
        //     op_a     = dest0_coefficient;
        //     fu_out_1 = ntt_out_1;
        //   end
        //   // Untwist
        //   4'b0101: begin
        //     op_a     = dest0_coefficient;
        //     op_b     = untwist_factor;
        //     fu_out_1 = mul_out_1;
        //     wb_0_q     = 1;
        //   end

        //   // CT1.B * Plaintext
        //   4'b0110: begin
        //     op_a     = stage1_src1_q;                       // CT1.B
        //     op_b     = twist_factor;
        //     op_c     = stage1_src2_q;                       // PT
        //     op_d     = twist_factor;
        //     fu_out_1 = mul_out_1;
        //     fu_out_2 = mul_out_2;
        //   end
        //   // NTT
        //   4'b0111: begin
        //     inverse  = 1'b0;
        //     op_a     = dest0_coefficient;
        //     op_c     = dest1_coefficient;
        //     fu_out_1 = ntt_out_1;
        //     fu_out_2 = ntt_out_2;
        //   end
        //   // MUL
        //   4'b1000: begin
        //     op_a     = dest0_coefficient;
        //     op_b     = dest1_coefficient;
        //     fu_out_1 = mul_out_1;
        //   end
        //   // Inverse NTT
        //   4'b1001: begin
        //     inverse  = 1'b1;
        //     op_a     = dest0_coefficient;
        //     fu_out_1 = ntt_out_1;
        //   end
        //   // Untwist
        //   4'b1010: begin
        //     op_a     = dest0_coefficient;
        //     op_b     = untwist_factor;
        //     fu_out_1 = mul_out_1;
        //     wb_1_q     = 1;
        //     done     = 1;
        //   end
        //   endcase  
        // end

      endcase
    end
  end

endmodule