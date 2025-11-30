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
  logic register_file_ready;

  logic                    start_operation;
  logic [$clog2(NREG)-1:0] source0_register_index;
  logic [$clog2(NREG)-1:0] source1_register_index;
  logic [$clog2(NREG)-1:0] source2_register_index;
  logic [$clog2(NREG)-1:0] source3_register_index;
  logic [$clog2(NREG)-1:0] dest0_register_index;
  logic [$clog2(NREG)-1:0] dest1_register_index;

  logic   source0_valid, source1_valid, source2_valid, source3_valid;
  coeff_t source0_coefficient, source1_coefficient;
  coeff_t source2_coefficient, source3_coefficient;
  logic   source0_last, source1_last, source2_last, source3_last;

  logic   dest0_valid, dest1_valid;
  coeff_t dest0_coefficient, dest1_coefficient;
  logic   dest0_last, dest1_last;
  
  op_e operation_mode;

  // Parse Instruction
  always_comb begin
    operation_mode = op.mode;
    source0_register_index = op.idx1_a;
    source1_register_index = op.idx1_b;
    source2_register_index = op.idx2_a;
    source3_register_index = op.idx2_b;
    dest0_register_index = op.out_a;
    dest1_register_index = op.out_b;
  end

  // ============================
  //  Instantiate register file
  // ============================

  regfile u_rf (
    .clk                 (clk),
    .reset               (reset),
    .register_file_ready (register_file_ready),

    .start_operation     (start_operation),

    .source0_register_index (source0_register_index),
    .source1_register_index (source1_register_index),
    .source2_register_index (source2_register_index),
    .source3_register_index (source3_register_index),

    .dest0_register_index   (dest0_register_index),
    .dest1_register_index   (dest1_register_index),

    .source0_valid          (source0_valid),
    .source0_coefficient    (source0_coefficient),
    .source0_last           (source0_last),

    .source1_valid          (source1_valid),
    .source1_coefficient    (source1_coefficient),
    .source1_last           (source1_last),

    .source2_valid          (source2_valid),
    .source2_coefficient    (source2_coefficient),
    .source2_last           (source2_last),

    .source3_valid          (source3_valid),
    .source3_coefficient    (source3_coefficient),
    .source3_last           (source3_last),

    .dest0_valid            (dest0_valid),
    .dest0_coefficient      (dest0_coefficient),
    .dest0_last             (dest0_last),

    .dest1_valid            (dest1_valid),
    .dest1_coefficient      (dest1_coefficient),
    .dest1_last             (dest1_last)
  );

  // ============================
  //  STAGE 1: Register Access
  // ============================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      stage1_valid <= 1'b0;
      stage1_src0 <= '0;
      stage1_src1 <= '0;
      stage1_src2 <= '0;
      stage1_src3 <= '0;
      stage1_src0_last <= 1'b0;
      stage1_src1_last <= 1'b0;
      stage1_src2_last <= 1'b0;
      stage1_src3_last <= 1'b0;
      stage1_op_mode <= OP_CT_CT_ADD;
      stage1_dest0_idx <= '0;
      stage1_dest1_idx <= '0;
    end else begin
      // Capture data from register file when valid
      stage1_valid <= source0_valid & source1_valid;
      stage1_src0 <= source0_coefficient;
      stage1_src1 <= source1_coefficient;
      stage1_src2 <= source2_coefficient;
      stage1_src3 <= source3_coefficient;
      stage1_op_mode <= operation_mode;
      stage1_dest0_idx <= dest0_register_index;
      stage1_dest1_idx <= dest1_register_index;
    end
  end

  // ============================
  //  Functional Units
  // ============================

  wire fu_ready = source0_valid & source1_valid;
  wire ntt_ready = source0_valid;
  wire coeff_t op_a, op_b, op_c, op_d;

  wide_vec_t add_out_1, add_out_2;
  wide_vec_t mul_out_1, mul_out_2;
  wide_vec_t ntt_out_1, ntt_out_2;
  
  coeff_t mod_out_1, mod_out_2;
  wide_vec_t fu_out_1, fu_out_2;
  logic wb_0, wb_1, done;

  // ADDER 1
  adder u_add_1 (
    .a   (op_a),
    .b   (op_b),
    .out (add_out_1)
  );

  // ADDER 2
  adder u_add_2 (
    .a   (op_c),
    .b   (op_d),
    .out (add_out_2)
  );

  // MULT 1
  mult u_mult_1 (
    .a   (source0_coefficient),
    .b   (source1_coefficient),
    .out (mul_out_1)
  );

  // MULT 2
  mult u_mult_2 (
    .a   (source2_coefficient),
    .b   (source3_coefficient),
    .out (mul_out_2)
  );

  // NTT 1
  // ntt_block_radix2_pipelined ntt_1(
  //       .W(W), 
  //       .N(N), 
  //       .Modulus_Q(Modulus_Q), 
  //       .OMEGA(OMEGA)
  //   ) DUT (
  //       .clk(clk),
  //       .reset(reset),
  //       .data_valid_in(stag),
  //       .iNTT_mode(iNTT_mode),
  //       .Data_in(Data_in),
  //       .Data_out(Data_out),
  //       .data_valid_out(data_valid_out)
  //   );
  // NTT 2
  assign ntt_out_1 = '0;
  assign ntt_out_2 = '0;

  // ============================
  //  FU Selection
  // ============================
  always_comb begin

    op_a = '0;
    op_b = '0;
    op_c = '0;
    op_d = '0;
    fu_out_1 = '0;
    fu_out_2 = '0;
    wb_0 = 1'b0;
    wb_1 = 1'b0;
    done = 1'b0;

    if (stage1_valid) begin 
      unique case (stage1_op_mode)

        OP_CT_CT_ADD: begin
          op_a = stage1_src0;
          op_b = stage1_src1;
          op_c = stage1_src2;
          op_d = stage1_src3;
          fu_out_1 = add_out_1;
          fu_out_2 = add_out_2;
          wb_0 = 1;
          wb_1 = 1;
          done = 1;
        end

        OP_CT_PT_ADD: begin
          op_a = stage1_src0; //CT1.A
          op_b = '0; //0
          op_c = stage1_src2; //CT1.B
          op_d = delta_gamma; //DELTA_GAMMA
          fu_out_1 = add_out_1;
          fu_out_2 = add_out_2;
          wb_0 = 1;
          wb_1 = 1;
          done = 1;
        end

        OP_CT_PT_MUL: begin
          case (stage)
          // CT1.A * Plaintext
          //TWIST
          4'b0001: begin
            op_a = stage1_src0; //CT1.A
            op_b = twist_factor;
            op_c = stage1_src2; //PT
            op_d = twist_factor; 
            fu_out_1 = mul_out_1;
            fu_out_2 = mul_out_2;
          end
          //NTT
          4'b0010: begin
            inverse = 0;
            op_a = mod_out_1;
            op_c = mod_out_2;
            fu_out_1 = ntt_out_1;
            fu_out_2 = ntt_out_2;
          end
          //MUL
          4'b0011: begin
            op_a = mod_out_1;
            op_b = mod_out_2;
            fu_out_1 = mul_out_1;
          end
          //Inverse NTT
          4'b0100: begin
            inverse = 1;
            op_a = mod_out_1;
            fu_out_1 = ntt_out_1;
          end
          //Untwist
          4'b0101: begin
            op_a = mod_out_1;
            op_b = untwist_factor;
            fu_out_1 = mul_out_1;
            wb_0 = 1;
          end

          // CT1.B * Plaintext
          4'b0110: begin
            op_a = stage1_src1; //CT1.B
            op_b = twist_factor;
            op_c = stage1_src2; //PT
            op_d = twist_factor; 
            fu_out_1 = mul_out_1;
            fu_out_2 = mul_out_2;
          end
          //NTT
          4'b0111: begin
            inverse = 0;
            op_a = mod_out_1;
            op_c = mod_out_2;
            fu_out_1 = ntt_out_1;
            fu_out_2 = ntt_out_2;
          end
          //MUL
          4'b1000: begin
            op_a = mod_out_1;
            op_b = mod_out_2;
            fu_out_1 = mul_out_1;
          end
          //Inverse NTT
          4'b1001: begin
            inverse = 1;
            op_a = mod_out_1;
            fu_out_1 = ntt_out_1;
          end
          //Untwist
          4'b1010: begin
            op_a = mod_out_1;
            op_b = untwist_factor;
            fu_out_1 = mul_out_1;
            wb_1 = 1;
            done = 1;
          end
          endcase  
        end

      endcase
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      stage2_valid <= 1'b0;
      stage2_fu_out_1 <= '0;
      stage2_fu_out_2 <= '0;
      stage2_dest0_idx <= '0;
      stage2_dest1_idx <= '0;
    end else begin
      stage2_valid <= stage1_valid;
      stage2_fu_out_1 <= fu_out_1;
      stage2_fu_out_2 <= fu_out_2;
      stage2_dest0_idx <= stage1_dest0_idx;
      stage2_dest1_idx <= stage1_dest1_idx;
    end
  end

  // ============================
  //  STAGE 3: Modulo Operations
  // ============================

  mod_vector modA(
    .in_vec(stage2_fu_out_1),
    .out_vec(mod_out_1)
  );

  mod_vector modB(
    .in_vec(stage2_fu_out_2),
    .out_vec(mod_out_2)
  );

  // ============================
  //  Writeback to Register File
  // ============================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      start_operation <= 1'b0;
      dest0_valid <= 1'b0;
      dest1_valid <= 1'b0;
      dest0_coefficient <= '0;
      dest1_coefficient <= '0;
      wb_valid <= '0;
    end else begin
      dest0_valid <= stage2_valid & wb_0;
      dest0_coefficient <= mod_out_1;
      dest0_register_index <= stage2_dest0_idx;
      
      dest1_valid <= stage2_valid & wb_1;
      dest1_coefficient <= mod_out_2;
      dest1_register_index <= stage2_dest1_idx;

      wb_valid <= stage2_valid;
    end
  end

  assign done_out = done & wb_valid;

endmodule