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
  vec_t   source0_coefficient, source1_coefficient;
  vec_t   source2_coefficient, source3_coefficient;

  logic   dest0_valid, dest1_valid;
  vec_t   dest0_coefficient, dest1_coefficient;
  
  op_e operation_mode;

  // -----------------------------
  // Stage 1 pipeline registers
  // -----------------------------
  logic   stage1_valid;
  vec_t   stage1_src0, stage1_src1, stage1_src2, stage1_src3;
  op_e    stage1_op_mode;
  logic [$clog2(NREG)-1:0] stage1_dest0_idx, stage1_dest1_idx;

  // -----------------------------
  // Stage 2 pipeline registers
  // -----------------------------
  logic      stage2_valid;
  wide_vec_t stage2_fu_out_1, stage2_fu_out_2;
  logic [$clog2(NREG)-1:0] stage2_dest0_idx, stage2_dest1_idx;

  // -----------------------------
  // Misc control regs
  // -----------------------------
  logic wb_valid;
  logic [3:0] stage;   // your CT-PT-MUL micro-FSM state
  logic       inverse; // NTT direction flag

  // -----------------------------
  // Scalarized constants for CT-PT ops
  // -----------------------------
  coeff_t delta_gamma;
  coeff_t twist_factor_coeff;
  coeff_t untwist_factor_coeff;

  assign delta_gamma          = DELTA_L;          // from types.svh
  assign twist_factor_coeff   = twist_factor[0];  // vec_t -> single coeff
  assign untwist_factor_coeff = untwist_factor[0];

  // Parse Instruction
  always_comb begin
    operation_mode          = op.mode;
    source0_register_index  = op.idx1_a;
    source1_register_index  = op.idx1_b;
    source2_register_index  = op.idx2_a;
    source3_register_index  = op.idx2_b;
    dest0_register_index    = op.out_a;
    dest1_register_index    = op.out_b;
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

    .source1_valid          (source1_valid),
    .source1_coefficient    (source1_coefficient),

    .source2_valid          (source2_valid),
    .source2_coefficient    (source2_coefficient),

    .source3_valid          (source3_valid),
    .source3_coefficient    (source3_coefficient),

    .dest0_valid            (dest0_valid),
    .dest0_coefficient      (dest0_coefficient),

    .dest1_valid            (dest1_valid),
    .dest1_coefficient      (dest1_coefficient)
  );

  // ============================
  //  STAGE 1: Register Access
  // ============================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      stage1_valid      <= 1'b0;
      stage1_src0       <= '{default: '0};
      stage1_src1       <= '{default: '0};
      stage1_src2       <= '{default: '0};
      stage1_src3       <= '{default: '0};
      stage1_op_mode    <= OP_CT_CT_ADD;
      stage1_dest0_idx  <= '0;
      stage1_dest1_idx  <= '0;
    end else begin
      // Capture data from register file when valid
      stage1_valid      <= source0_valid & source1_valid;
      stage1_src0       <= source0_coefficient;
      stage1_src1       <= source1_coefficient;
      stage1_src2       <= source2_coefficient;
      stage1_src3       <= source3_coefficient;
      stage1_op_mode    <= operation_mode;
      stage1_dest0_idx  <= dest0_register_index;
      stage1_dest1_idx  <= dest1_register_index;
    end
  end

  // ============================
  //  Functional Units
  // ============================

  wire    fu_ready   = source0_valid & source1_valid;
  wire    ntt_ready  = source0_valid;
  vec_t   op_a, op_b, op_c, op_d;

  wide_vec_t add_out_1, add_out_2;
  wide_vec_t mul_out_1, mul_out_2;
  wide_vec_t ntt_out_1, ntt_out_2;
  
  vec_t     mod_out_1, mod_out_2;
  wide_vec_t fu_out_1, fu_out_2;
  logic     wb_0, wb_1, done;

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

  // NTT 1 & 2 (stubbed for now)
  assign ntt_out_1 = '{default: '0};
  assign ntt_out_2 = '{default: '0};

  // ============================
  //  FU Selection
  // ============================
  always_comb begin

    op_a     = '{default: '0};
    op_b     = '{default: '0};
    op_c     = '{default: '0};
    op_d     = '{default: '0};
    fu_out_1 = '{default: '0};
    fu_out_2 = '{default: '0};
    wb_0     = 1'b0;
    wb_1     = 1'b0;
    done     = 1'b0;

    if (stage1_valid) begin 
      unique case (stage1_op_mode)

      

        OP_CT_CT_ADD: begin
          // CT-CT ADD:
          // CT2.A = CT0.A + CT1.A
          // CT2.B = CT0.B + CT1.B
          //
          // stage1_src0 = CT0.A   (idx1_a)
          // stage1_src1 = CT0.B   (idx1_b)
          // stage1_src2 = CT1.A   (idx2_a)
          // stage1_src3 = CT1.B   (idx2_b)

          op_a     = stage1_src0;  // CT0.A
          op_b     = stage1_src2;  // CT1.A
          op_c     = stage1_src1;  // CT0.B
          op_d     = stage1_src3;  // CT1.B

          fu_out_1 = add_out_1;    // sum for A
          fu_out_2 = add_out_2;    // sum for B
          wb_0     = 1;
          wb_1     = 1;
          done     = 1;
        end


        OP_CT_PT_ADD: begin
          op_a     = stage1_src0;                    // CT1.A
          op_b     = '{default: '0};                 // 0
          op_c     = stage1_src2;                    // CT1.B
          op_d     = '{default: delta_gamma};        // broadcast DELTA*gamma
          fu_out_1 = add_out_1;
          fu_out_2 = add_out_2;
          wb_0     = 1;
          wb_1     = 1;
          done     = 1;
        end

        OP_CT_PT_MUL: begin
          case (stage)
          // CT1.A * Plaintext
          // TWIST
          4'b0001: begin
            op_a     = stage1_src0;                       // CT1.A (vec)
            op_b     = '{default: twist_factor_coeff};    // scalar twist broadcast
            op_c     = stage1_src2;                       // PT (vec)
            op_d     = '{default: twist_factor_coeff};    // scalar twist broadcast
            fu_out_1 = mul_out_1;
            fu_out_2 = mul_out_2;
          end
          // NTT
          4'b0010: begin
            inverse  = 1'b0;
            op_a     = mod_out_1;
            op_c     = mod_out_2;
            fu_out_1 = ntt_out_1;
            fu_out_2 = ntt_out_2;
          end
          // MUL
          4'b0011: begin
            op_a     = mod_out_1;
            op_b     = mod_out_2;
            fu_out_1 = mul_out_1;
          end
          // Inverse NTT
          4'b0100: begin
            inverse  = 1'b1;
            op_a     = mod_out_1;
            fu_out_1 = ntt_out_1;
          end
          // Untwist
          4'b0101: begin
            op_a     = mod_out_1;
            op_b     = '{default: untwist_factor_coeff};  // scalar untwist broadcast
            fu_out_1 = mul_out_1;
            wb_0     = 1;
          end

          // CT1.B * Plaintext
          4'b0110: begin
            op_a     = stage1_src1;                       // CT1.B
            op_b     = '{default: twist_factor_coeff};
            op_c     = stage1_src2;                       // PT
            op_d     = '{default: twist_factor_coeff};
            fu_out_1 = mul_out_1;
            fu_out_2 = mul_out_2;
          end
          // NTT
          4'b0111: begin
            inverse  = 1'b0;
            op_a     = mod_out_1;
            op_c     = mod_out_2;
            fu_out_1 = ntt_out_1;
            fu_out_2 = ntt_out_2;
          end
          // MUL
          4'b1000: begin
            op_a     = mod_out_1;
            op_b     = mod_out_2;
            fu_out_1 = mul_out_1;
          end
          // Inverse NTT
          4'b1001: begin
            inverse  = 1'b1;
            op_a     = mod_out_1;
            fu_out_1 = ntt_out_1;
          end
          // Untwist
          4'b1010: begin
            op_a     = mod_out_1;
            op_b     = '{default: untwist_factor_coeff};
            fu_out_1 = mul_out_1;
            wb_1     = 1;
            done     = 1;
          end
          endcase  
        end

      endcase
    end
  end

  // ============================
  //  Stage 2 pipe reg
  // ============================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      stage2_valid     <= 1'b0;
      stage2_fu_out_1  <= '{default: '0};
      stage2_fu_out_2  <= '{default: '0};
      stage2_dest0_idx <= '0;
      stage2_dest1_idx <= '0;
    end else begin
      stage2_valid     <= stage1_valid;
      stage2_fu_out_1  <= fu_out_1;
      stage2_fu_out_2  <= fu_out_2;
      stage2_dest0_idx <= stage1_dest0_idx;
      stage2_dest1_idx <= stage1_dest1_idx;
    end
  end

  // ============================
  //  STAGE 3: Modulo Operations
  // ============================

  mod_vector modA(
    .in_vec (stage2_fu_out_1),
    .out_vec(mod_out_1)
  );

  mod_vector modB(
    .in_vec (stage2_fu_out_2),
    .out_vec(mod_out_2)
  );

  // ============================
  //  Writeback to Register File
  // ============================
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      start_operation       <= 1'b0;
      dest0_valid           <= 1'b0;
      dest1_valid           <= 1'b0;
      dest0_coefficient     <= '{default: '0};
      dest1_coefficient     <= '{default: '0};
      wb_valid              <= 1'b0;
    end else begin
      dest0_valid           <= stage2_valid & wb_0;
      dest0_coefficient     <= mod_out_1;

      dest1_valid           <= stage2_valid & wb_1;
      dest1_coefficient     <= mod_out_2;

      wb_valid              <= stage2_valid;
    end
  end
  assign done_out = done & wb_valid;

endmodule
