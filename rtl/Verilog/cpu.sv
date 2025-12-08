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
  logic [$clog2(`REG_NPOLY)-1:0] wb_0_idx_q, wb_1_idx_q;
  logic [$clog2(`REG_NPOLY)-1:0] controller_wb_0_idx_q, controller_wb_1_idx_q;
  logic [$clog2(`REG_NPOLY)-1:0] read_idx_0_q, read_idx_1_q, read_idx_2_q, read_idx_3_q;

  logic   source0_valid_q, source1_valid_q, source2_valid_q, source3_valid_q;
  q_BASIS_poly   source0_poly_q, source1_poly_q;
  q_BASIS_poly   source2_poly_q, source3_poly_q;

  logic   dest0_valid_q, dest1_valid_q;
  q_BASIS_poly   dest0_poly_q, dest1_poly_q;

  // B-basis regfile interface
  B_BASIS_poly   source0_poly_b, source1_poly_b;
  B_BASIS_poly   source2_poly_b, source3_poly_b;
  B_BASIS_poly   dest0_poly_b,  dest1_poly_b;

  // Ba-basis regfile interface
  Ba_BASIS_poly  source0_poly_ba, source1_poly_ba;
  Ba_BASIS_poly  source2_poly_ba, source3_poly_ba;
  Ba_BASIS_poly  dest0_poly_ba,   dest1_poly_ba;

  qBBa_BASIS_poly modSwitch1_in, modSwitch2_in;
  BBa_BASIS_poly fastBConvEx_in_1, fastBConvEx_in_2;

  logic fastBConvEx_in_valid_1, fastBConvEx_in_valid_2;
  logic modSwitch_in_valid_1, modSwitch_in_valid_2;
  
  op_e operation_mode, stage1_op_mode;

  // -----------------------------
  // Misc control regs
  // -----------------------------
  logic wb_valid;
  logic [4:0] stage;   // your CT-PT-MUL micro-FSM state
  logic       inverse; // NTT direction flag
  logic     wb_0_q, wb_1_q, done;

  logic ntt_1_valid_in, ntt_1_valid_out, ntt_2_valid_in, ntt_2_valid_out;
  logic doing_ntt, doing_fastBconv;
  logic ntt_1_start, ntt_2_start;
  logic modSwitch_out_valid_2;
  logic fast_BConvex_out_valid_1, fast_BConvex_out_valid_2;
  
  q_BASIS_poly   op_a_q, op_b_q, op_c_q, op_d_q;
  B_BASIS_poly   op_a_b, op_b_b, op_c_b, op_d_b;
  Ba_BASIS_poly  op_a_ba, op_b_ba, op_c_ba, op_d_ba;

  q_BASIS_poly  add_out_1, add_out_2, mul_out_1_q, mul_out_2_q, fu_out_1_q, fu_out_2_q, ntt_out_1_q, ntt_out_2_q;
  q_BASIS_poly  fast_BConvex_out_1, fast_BConvex_out_2;
  B_BASIS_poly  mul_out_1_b, mul_out_2_b,fu_out_1_b, fu_out_2_b, ntt_out_1_b, ntt_out_2_b;
  Ba_BASIS_poly mul_out_1_ba, mul_out_2_ba, fu_out_1_ba, fu_out_2_ba, ntt_out_1_ba, ntt_out_2_ba;

  // ============================================================
  //  CT-CT MUL intermediates
  // ============================================================

  // Step 1 outputs: mod raise q -> qBBa for each ct component
  qBBa_BASIS_poly fastBconv_out_1, fastBconv_out_2;

  BBa_BASIS_poly modswitch_out_1, modswitch_out_2;

  // Step 2/3/4/5: D0,D1,D2 through qBBa -> BBa -> q
  // qBBa_BASIS_poly D0_qBBa, D1_qBBa, D2_qBBa;
  // BBa_BASIS_poly  D0_BBa,  D1_BBa,  D2_BBa;
  // q_BASIS_poly    D0_q,    D1_q,    D2_q;

  // ---------- fastBConv (mod raise) handshakes ----------
  logic fastBconv_in_valid, fastbconv_out_1_valid, modraise_out_2_valid;

  // ---------- modSwitch_qBBa_to_BBa handshakes ----------
  logic ms_D0_in_valid, ms_D0_out_valid;
  logic ms_D1_in_valid, ms_D1_out_valid;
  logic ms_D2_in_valid, ms_D2_out_valid;

  // ---------- fastBConvEx_BBa_to_q handshakes ----------
  logic fbex_D0_in_valid, fbex_D0_out_valid;
  logic fbex_D1_in_valid, fbex_D1_out_valid;
  logic fbex_D2_in_valid, fbex_D2_out_valid;


  logic stage1_valid;
  q_BASIS_poly stage1_src0_q;
  q_BASIS_poly stage1_src1_q;
  q_BASIS_poly stage1_src2_q;
  q_BASIS_poly stage1_src3_q;

  B_BASIS_poly stage1_src0_b;
  B_BASIS_poly stage1_src1_b;
  B_BASIS_poly stage1_src2_b;
  B_BASIS_poly stage1_src3_b;

  Ba_BASIS_poly stage1_src0_ba;
  Ba_BASIS_poly stage1_src1_ba;
  Ba_BASIS_poly stage1_src2_ba;
  Ba_BASIS_poly stage1_src3_ba;

  op_e operationMode, operationMode_next;
  logic [$clog2(`REG_NPOLY)-1:0] stage1_dest0_idx;
  logic [$clog2(`REG_NPOLY)-1:0] stage1_dest1_idx;


  // Parse Instruction
  always_comb begin
    operation_mode            = op.mode;
    if (operation_mode != NO_OP) begin
      source0_register_index_q  = op.idx1_a;
      source1_register_index_q  = op.idx1_b;
      source2_register_index_q  = op.idx2_a;
      source3_register_index_q  = op.idx2_b;
      dest0_register_index_q    = op.out_a;
      dest1_register_index_q    = op.out_b;
    end else begin
      // source0_register_index_q = read_idx_0_q;
      // source1_register_index_q = read_idx_1_q;
      // source2_register_index_q = read_idx_2_q;
      // source3_register_index_q = read_idx_3_q;
      dest0_register_index_q    = controller_wb_0_idx_q;
      dest1_register_index_q    = controller_wb_1_idx_q;
    end
  end

  // ============================
  //  Instantiate register file
  // ============================

  // Q-basis bank
  regfile #(
    .NPRIMES(`q_BASIS_LEN)
  ) u_rf_q (
  
    .clk                 (clk),
    
    .source0_register_index (source0_register_index_q),
    .source1_register_index (source1_register_index_q),
    .source2_register_index (source2_register_index_q),
    .source3_register_index (source3_register_index_q),

    .dest0_register_index   (wb_0_idx_q),
    .dest1_register_index   (wb_1_idx_q),

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

  // B-basis bank
  regfile #(
    .NPRIMES(`B_BASIS_LEN)
  ) u_rf_b (
    .clk                 (clk),

    .source0_register_index (source0_register_index_q),
    .source1_register_index (source1_register_index_q),
    .source2_register_index (source2_register_index_q),
    .source3_register_index (source3_register_index_q),

    .dest0_register_index   (wb_0_idx_q),
    .dest1_register_index   (wb_1_idx_q),

    .source0_valid          (source0_valid_b),
    .source0_poly           (source0_poly_b),
    .source1_valid          (source1_valid_b),
    .source1_poly           (source1_poly_b),
    .source2_valid          (source2_valid_b),
    .source2_poly           (source2_poly_b),
    .source3_valid          (source3_valid_b),
    .source3_poly           (source3_poly_b),

    .dest0_valid            (dest0_valid_q),   // shared WE
    .dest0_poly             (dest0_poly_b),
    .dest1_valid            (dest1_valid_q),
    .dest1_poly             (dest1_poly_b)
  );

  // Ba-basis bank
  regfile #(
    .NPRIMES(`Ba_BASIS_LEN)
  ) u_rf_ba (
    .clk                 (clk),

    .source0_register_index (source0_register_index_q),
    .source1_register_index (source1_register_index_q),
    .source2_register_index (source2_register_index_q),
    .source3_register_index (source3_register_index_q),

    .dest0_register_index   (wb_0_idx_q),
    .dest1_register_index   (wb_1_idx_q),

    .source0_valid          (source0_valid_ba),
    .source0_poly           (source0_poly_ba),
    .source1_valid          (source1_valid_ba),
    .source1_poly           (source1_poly_ba),
    .source2_valid          (source2_valid_ba),
    .source2_poly           (source2_poly_ba),
    .source3_valid          (source3_valid_ba),
    .source3_poly           (source3_poly_ba),

    .dest0_valid            (dest0_valid_q),
    .dest0_poly             (dest0_poly_ba),
    .dest1_valid            (dest1_valid_q),
    .dest1_poly             (dest1_poly_ba)
  );

  // ============================
  //  STAGE 1: Register Access
  // ============================
  always_ff @(posedge clk) begin
    if(`DEBUG_EN) begin
      $display("Stage: %d, Operation: %d, Done: %b",stage, operation_mode, done_out);
      // $display("%b, %b, %b, %b, %b, %b", done, stage1_op_mode, ntt_1_valid_in, ntt_1_valid_out, fastBconv_in_valid, fastbconv_out_1_valid);
      $display("Op_a: %d, Op_b: %d, Op_c: %d, Op_d: %d", op_a_q[0][0], op_b_q[0][0], op_c_q[0][0], op_d_q[0][0]);
      $display("Fu_1: %d, Fu_2: %d", fu_out_1_q[0][0], fu_out_2_q[0][0]);
      $display("Dest0_poly: %d, Dest1_poly: %d", dest0_poly_q[0][0], dest1_poly_q[0][0]);
      $display("Wb_0_idx: %d, Wb_1_idx: %d", wb_0_idx_q, wb_1_idx_q);
      // $display("Mem11: %d, Mem12: %d", u_rf_q.mem[11][0][0], u_rf_q.mem[12][0][0]);
      // $display("Mem0: %d, Mem1: %d", u_rf_q.mem[0][0][0], u_rf_q.mem[1][0][0]);
      // $display("Read0_poly: %d, Read1_poly: %d", source0_poly_q[0][0], source1_poly_q[0][0]);
      // $display("Read_0_idx: %d, Read_1_idx: %d", read_idx_0_q, read_idx_1_q);
      // $display("NTT_1_Valid: %b, NTT_2_Valid: %b", ntt_1_valid_out, ntt_2_valid_out);
      // $display("NTT_1_Valid_in: %b, NTT_2_Valid_in: %b", ntt_1_valid_in, ntt_2_valid_in);
      // $display("fastbconv valid in: %b, doing_fastBconv: %b", fastBconv_in_valid, doing_fastBconv);
      // $display("fastbconv1 valid out: %b, fastbconv2 valid out: %b ", fastbconv_out_1_valid, modraise_out_2_valid);
    end

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
      dest0_poly_b      <= '{default: '0};   
      dest1_poly_b      <= '{default: '0};   
      dest0_poly_ba     <= '{default: '0};   
      dest1_poly_ba     <= '{default: '0};   
      done_out          <= '0;
      stage             <= '0;
    end else begin
      // Capture data from register file when valid
      stage1_valid      <= source0_valid_q & source1_valid_q;
      stage1_src0_q     <= source0_poly_q;
      stage1_src1_q     <= source1_poly_q;
      stage1_src1_b     <= source1_poly_b;
      stage1_src1_ba     <= source1_poly_ba;
      stage1_src2_q     <= source2_poly_q;
      stage1_src2_b     <= source2_poly_b;
      stage1_src2_ba    <= source2_poly_ba;
      stage1_src3_q     <= source3_poly_q;
      stage1_src3_b     <= source3_poly_b;
      stage1_src3_ba     <= source3_poly_ba;
      stage1_op_mode    <= (done || stage1_op_mode == NO_OP) ? operation_mode : stage1_op_mode;
      stage1_dest0_idx  <= (done || stage1_op_mode == NO_OP) ? dest0_register_index_q : stage1_dest0_idx;
      stage1_dest1_idx  <= (done || stage1_op_mode == NO_OP) ? dest1_register_index_q : stage1_dest1_idx;
      dest0_valid_q     <= wb_0_q;
      dest1_valid_q     <= wb_1_q;
      dest0_poly_q      <= fu_out_1_q;
      dest1_poly_q      <= fu_out_2_q;
      dest0_poly_b      <= fu_out_1_b;
      dest1_poly_b      <= fu_out_2_b;
      dest0_poly_ba     <= fu_out_1_ba;
      dest1_poly_ba     <= fu_out_2_ba;
      done_out          <= done; 
      doing_ntt <= (stage1_op_mode == OP_CT_PT_MUL) && (stage == 5'b00010 || stage == 5'b00111 || stage == 5'b00100 || stage == 5'b01001);
      // doing_fastBconv <= (stage1_op_mode == OP_CT_CT_MUL) && (stage == 5'b00001 || stage == 5'b00010);
      stage             <= (done || stage1_op_mode == NO_OP) ? 5'b00001 : ((ntt_1_valid_in & ~ntt_1_valid_out) || (fastBconv_in_valid & ~fastbconv_out_1_valid)) ? stage : stage + 1;
      wb_0_idx_q <= (controller_wb_0_idx_q);
      wb_1_idx_q <= (controller_wb_1_idx_q);
      // when operation_mode != No_OP, stage = 0
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

  // NTT 1 & 2
  logic [`qBBa_BASIS_LEN-1:0] ntt_1_valid_out_array;
  logic [`qBBa_BASIS_LEN-1:0] ntt_2_valid_out_array;

  genvar i;
  generate 
    for (i = 0; i < `qBBa_BASIS_LEN; i++) begin : gen_ntt_blocks

      // Calculate basis type and local index once
      localparam int BASIS_TYPE = (i < `q_BASIS_LEN) ? 0 : 
                                  (i < (`q_BASIS_LEN + `B_BASIS_LEN)) ? 1 : 2;
      localparam int LOCAL_IDX = (i < `q_BASIS_LEN) ? i :
                                (i < (`q_BASIS_LEN + `B_BASIS_LEN)) ? (i - `q_BASIS_LEN) :
                                (i - `q_BASIS_LEN - `B_BASIS_LEN);
      
      // Use generate if for compile-time conditional elaboration
      rns_residue_t data_in_a [0:`N_SLOTS-1];
      rns_residue_t data_in_c [0:`N_SLOTS-1];
      rns_residue_t data_out_1 [0:`N_SLOTS-1];
      rns_residue_t data_out_2 [0:`N_SLOTS-1];

      if (BASIS_TYPE == 0) begin : q_basis_assignment
        always_comb begin
          for (int s = 0; s < `N_SLOTS; s++) begin
            data_in_a[s] = op_a_q[s][LOCAL_IDX];
            data_in_c[s] = op_c_q[s][LOCAL_IDX];
            ntt_out_1_q[s][LOCAL_IDX] = data_out_1[s];
            ntt_out_2_q[s][LOCAL_IDX] = data_out_2[s];
          end
        end
      end else if (BASIS_TYPE == 1) begin : b_basis_assignment
        always_comb begin
          for (int s = 0; s < `N_SLOTS; s++) begin
            data_in_a[s] = op_a_b[s][LOCAL_IDX];
            data_in_c[s] = op_c_b[s][LOCAL_IDX];
            ntt_out_1_b[s][LOCAL_IDX] = data_out_1[s];
            ntt_out_2_b[s][LOCAL_IDX] = data_out_2[s];
          end
        end
      end else begin : ba_basis_assignment  // BASIS_TYPE == 2
        always_comb begin
          for (int s = 0; s < `N_SLOTS; s++) begin
            data_in_a[s] = op_a_ba[s][LOCAL_IDX];
            data_in_c[s] = op_c_ba[s][LOCAL_IDX];
            ntt_out_1_ba[s][LOCAL_IDX] = data_out_1[s];
            ntt_out_2_ba[s][LOCAL_IDX] = data_out_2[s];
          end
        end
      end
      
      // {q_BASIS_poly[0][i], q_BASIS_poly[1][i], ... , q_BASIS_poly[`N_SLOTS - 1][i] }

      ntt_block_radix2_pipelined #(
        .W(`RNS_PRIME_BITS),
        .N(`N_SLOTS),
        .Modulus_Q(qBBa_BASIS[i]),
        .OMEGA(w_BASIS[i]), // parameter need to be instantiate in the type def. 
        .OMEGA_INV(w_INV_BASIS[i])
      ) u_ntt_1(
        .clk(clk),
        .reset(reset),
        
        .data_valid_in(ntt_1_valid_in & ~doing_ntt), 
        .iNTT_mode(inverse),    

        .Data_in(data_in_a),

        .Data_out(data_out_1),
        .data_valid_out(ntt_1_valid_out_array[i]), 
        .mode_out()       
      );

      ntt_block_radix2_pipelined #(
        .W(`RNS_PRIME_BITS),
        .N(`N_SLOTS),
        .Modulus_Q(qBBa_BASIS[i]),
        .OMEGA(w_BASIS[i]), // parameter need to be instantiate in the type def. 
        .OMEGA_INV(w_INV_BASIS[i])
      ) u_ntt_2(
        .clk(clk),
        .reset(reset),
        
        .data_valid_in(ntt_2_valid_in & ~doing_ntt), 
        .iNTT_mode(inverse),    

        .Data_in(data_in_c),

        .Data_out(data_out_2),
        .data_valid_out(ntt_2_valid_out_array[i]), 
        .mode_out()       
      );
    end
  endgenerate

  assign ntt_1_valid_out = &ntt_1_valid_out_array;
  assign ntt_2_valid_out = &ntt_2_valid_out_array; 

  fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS    (q_BASIS),
        .OUT_BASIS   (qBBa_BASIS),
        .ZiLUT       (z_MOD_q),
        .YMODB       (y_q_TO_qBBa)
  ) fastBConv_1 (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (fastBconv_in_valid & ~doing_fastBconv),
        .input_RNSpoly(op_a_q),           // ct1.B in q basis
        .doing_fastBconv    (doing_fastBconv),
        .out_valid (fastbconv_out_1_valid),
        .output_RNSpoly(fastBconv_out_1)
  );

  fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS    (q_BASIS),
        .OUT_BASIS   (qBBa_BASIS),
        .ZiLUT       (z_MOD_q),
        .YMODB       (y_q_TO_qBBa)
  ) fastBConv_2 (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (fastBconv_in_valid & ~doing_fastBconv),
        .input_RNSpoly(op_c_q),           // ct1.B in q basis
        .out_valid    (modraise_out_2_valid),
        .output_RNSpoly(fastBconv_out_2)
  );

    // D0

    always_comb begin
      for (int i = 0; i < `N_SLOTS; i++) begin

        for (int j = 0; j < `q_BASIS_LEN; j++) begin
          modSwitch1_in[i][j] = op_a_q[i][j];
          modSwitch2_in[i][j] = op_c_q[i][j];
        end

        for (int j = 0; j < `B_BASIS_LEN; j++) begin
          modSwitch1_in[i][j + `q_BASIS_LEN] = op_a_b[i][j];
          modSwitch2_in[i][j + `q_BASIS_LEN] = op_c_b[i][j];
        end

        for (int j = 0; j < `Ba_BASIS_LEN; j++) begin
          modSwitch1_in[i][j + `q_BASIS_LEN + `B_BASIS_LEN] = op_a_ba[i][j];
          modSwitch2_in[i][j + `q_BASIS_LEN + `B_BASIS_LEN] = op_c_ba[i][j];
        end
      end
    end

  modSwitch_qBBa_to_BBa modSwitch1 (
      .clk            (clk),
      .reset          (reset),
      .in_valid       (modSwitch_in_valid_1),   // driven by controller
      .input_RNSpoly  (modSwitch1_in),          // D0 in qBBa basis
      .out_valid      (modSwitch_out_valid_1),
      .output_RNSpoly (modswitch_out_1)            // D0 in BBa basis
  );

  modSwitch_qBBa_to_BBa modSwitch2 (
      .clk            (clk),
      .reset          (reset),
      .in_valid       (modSwitch_in_valid_2),   // driven by controller
      .input_RNSpoly  (modSwitch2_in),          // D0 in qBBa basis
      .out_valid      (modSwitch_out_valid_2),
      .output_RNSpoly (modswitch_out_2)            // D0 in BBa basis
  );

  always_comb begin
      for (int i = 0; i < `N_SLOTS; i++) begin

        for (int j = 0; j < `B_BASIS_LEN; j++) begin
          fastBConvEx_in_1[i][j] = op_a_b[i][j];
          fastBConvEx_in_2[i][j + `q_BASIS_LEN] = op_c_b[i][j];
        end

        for (int j = 0; j < `Ba_BASIS_LEN; j++) begin
          fastBConvEx_in_1[i][j + `B_BASIS_LEN] = op_a_ba[i][j];
          fastBConvEx_in_2[i][j + `B_BASIS_LEN] = op_c_ba[i][j];
        end
      end
    end

  // D0
  fastBConvEx_BBa_to_q fastBConvEX_1 (
      .clk            (clk),
      .reset          (reset),
      .in_valid       (fastBConvEx_in_valid_1), // driven by controller
      .input_RNSpoly  (fastBConvEx_in_1),           // D0 in BBa basis
      .out_valid      (fast_BConvex_out_valid_1),
      // .doing_fastBConvEx (doing_fastBConvEx),
      .output_RNSpoly (fast_BConvex_out_1)              // D0 back in q basis
  );

  fastBConvEx_BBa_to_q fastBConvEX_2 (
      .clk            (clk),
      .reset          (reset),
      .in_valid       (fastBConvEx_in_valid_2), // driven by controller
      .input_RNSpoly  (fastBConvEx_in_1),           // D0 in BBa basis
      .out_valid      (fast_BConvex_out_valid_2),
      // .doing_fastBConvEx (doing_fastBConvEx),
      .output_RNSpoly (fast_BConvex_out_2)              // D0 back in q basis
  );

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
    inverse    = 1'b0;
    controller_wb_0_idx_q = stage1_dest0_idx;
    controller_wb_1_idx_q = stage1_dest1_idx;
    fastBConvEx_in_valid_2 = 1'b0;
    fastBConvEx_in_valid_1 = 1'b0;
    modSwitch_in_valid_1 = 1'b0;
    modSwitch_in_valid_2 = 1'b0;
    read_idx_0_q = '0;
    read_idx_1_q = '0;
    read_idx_2_q = '0;
    read_idx_3_q = '0;
    fastBconv_in_valid = 1'b0;
    

    // valid_in = one-cycle pulse from the FF above
    ntt_1_valid_in = 1'b0;
    ntt_2_valid_in = 1'b0;

    // we consider ourselves "in an NTT step" at these stages

    if (stage1_valid) begin 
      unique case (stage1_op_mode)
        NO_OP: ;

        OP_CT_CT_ADD: begin
          op_a_q     = stage1_src0_q;  // CT0.A
          op_b_q     = stage1_src2_q;  // CT1.A
          op_c_q     = stage1_src1_q;  // CT0.B
          op_d_q     = stage1_src3_q;  // CT1.B

          fu_out_1_q = add_out_1;      // sum for A
          fu_out_2_q = add_out_2;      // sum for B
          wb_0_q     = 1;
          wb_1_q     = 1;
          controller_wb_0_idx_q = stage1_dest0_idx;
          controller_wb_1_idx_q = stage1_dest1_idx;
          done       = 1;
        end

        OP_CT_PT_ADD: begin
          op_a_q     = stage1_src0_q;      // CT1.A
          op_b_q     = '{default: '0};     // 0
          op_c_q     = stage1_src1_q;      // CT1.B
          op_d_q     = stage1_src3_q;      // scaled PT
          fu_out_1_q = add_out_1;
          fu_out_2_q = add_out_2;
          wb_0_q     = 1;
          wb_1_q     = 1;
          controller_wb_0_idx_q = stage1_dest0_idx;
          controller_wb_1_idx_q = stage1_dest1_idx;
          done       = 1;
        end

        OP_CT_PT_MUL: begin
          case (stage)
            // CT1.A * Plaintext
            // TWIST
            5'b00001: begin
              op_a_q     = stage1_src0_q;       // CT1.A (vec)
              op_b_q     = twist_factor_q;
              op_c_q     = stage1_src3_q;       // PT (vec)
              op_d_q     = twist_factor_q;
              fu_out_1_q = mul_out_1_q;
              fu_out_2_q = mul_out_2_q;
            end

            // NTT of CT1.A and PT
            5'b00010: begin
              inverse    = 1'b0;
              op_a_q     = dest0_poly_q;        // CT1.A * twist
              op_c_q     = dest1_poly_q;        // PT * twist
              fu_out_1_q = ntt_out_1_q;
              fu_out_2_q = ntt_out_2_q;
              // $display("inside first NTT");
              ntt_1_valid_in = 1'b1;
              ntt_2_valid_in = 1'b1;
            end

            // MUL in NTT domain (A part)
            5'b00011: begin
              op_a_q     = dest0_poly_q;        // NTT(CT1.A * twist)
              op_b_q     = dest1_poly_q;        // NTT(PT * twist)
              fu_out_1_q = mul_out_1_q;         // CT1.A * PT
            end

            // Inverse NTT (A)
            5'b00100: begin
              inverse    = 1'b1;
              op_a_q     = dest0_poly_q;
              fu_out_1_q = ntt_out_1_q;
              ntt_1_valid_in = 1'b1;
            end

            // Untwist (A)
            5'b00101: begin
              op_a_q     = dest0_poly_q;
              op_b_q     = untwist_factor_q;
              fu_out_1_q = mul_out_1_q;
              wb_0_q     = 1;
              controller_wb_0_idx_q = stage1_dest0_idx;
            end

            // CT1.B * Plaintext — twist
            5'b00110: begin
              op_a_q     = stage1_src1_q;       // CT1.B
              op_b_q     = twist_factor_q;
              op_c_q     = stage1_src3_q;       // PT
              op_d_q     = twist_factor_q;
              fu_out_1_q = mul_out_1_q;
              fu_out_2_q = mul_out_2_q;
            end

            // NTT (B path)
            5'b00111: begin
              inverse    = 1'b0;
              op_a_q     = dest0_poly_q;
              op_c_q     = dest1_poly_q;
              fu_out_1_q = ntt_out_1_q;
              fu_out_2_q = ntt_out_2_q;
              ntt_1_valid_in = 1'b1;
              ntt_2_valid_in = 1'b1;
              // no direct ntt_*_valid_in or doing_ntt here
            end

            // MUL in NTT domain (B part)
            5'b01000: begin
              op_a_q     = dest0_poly_q;
              op_b_q     = dest1_poly_q;
              fu_out_1_q = mul_out_1_q;
            end

            // Inverse NTT (B)
            5'b01001: begin
              inverse    = 1'b1;
              op_a_q     = dest0_poly_q;
              fu_out_1_q = ntt_out_1_q;
              ntt_1_valid_in = 1'b1;
              // ntt_1_valid_in from ntt_1_start FF
            end

            // Untwist (B)
            5'b01010: begin
              op_a_q     = dest0_poly_q;
              op_b_q     = untwist_factor_q;
              fu_out_2_q = mul_out_1_q;
              wb_1_q     = 1;
              controller_wb_1_idx_q = stage1_dest1_idx;
              done       = 1;
            end
          endcase
        end

        OP_CT_CT_MUL: begin
          case (stage)
            5'b00001: begin
            fastBconv_in_valid = 1'b1;  // A1 -> qBBa
              op_a_q = stage1_src0_q; //CT1.A
              op_c_q = stage1_src1_q; //CT1.B

              // Store values in reg 11 and 12
              wb_0_q = 1'b1;
              wb_1_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              controller_wb_1_idx_q = `REG_NPOLY'd12;

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `q_BASIS_LEN; j++) begin
                  fu_out_1_q[i][j] = fastBconv_out_1[i][j];
                  fu_out_2_q[i][j] = fastBconv_out_2[i][j];
                end
              end

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `B_BASIS_LEN; j++) begin
                  fu_out_1_b[i][j] = fastBconv_out_1[i][`q_BASIS_LEN + j];
                  fu_out_2_b[i][j] = fastBconv_out_2[i][`q_BASIS_LEN + j];
                end
              end

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `Ba_BASIS_LEN; j++) begin
                  fu_out_1_ba[i][j] = fastBconv_out_1[i][`q_BASIS_LEN + `B_BASIS_LEN + j];
                  fu_out_2_ba[i][j] = fastBconv_out_2[i][`q_BASIS_LEN + `B_BASIS_LEN + j];
                end
              end
            end
            
            5'b00010: begin
              fastBconv_in_valid = 1'b1;
              op_a_q = stage1_src2_q; //CT2.A
              op_c_q = stage1_src3_q; //CT2.B

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `q_BASIS_LEN; j++) begin
                  fu_out_1_q[i][j] = fastBconv_out_1[i][j];
                  fu_out_2_q[i][j] = fastBconv_out_2[i][j];
                end
              end

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `B_BASIS_LEN; j++) begin
                  fu_out_1_b[i][j] = fastBconv_out_1[i][`q_BASIS_LEN + j];
                  fu_out_2_b[i][j] = fastBconv_out_2[i][`q_BASIS_LEN + j];
                end
              end

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `Ba_BASIS_LEN; j++) begin
                  fu_out_1_ba[i][j] = fastBconv_out_1[i][`q_BASIS_LEN + `B_BASIS_LEN + j];
                  fu_out_2_ba[i][j] = fastBconv_out_2[i][`q_BASIS_LEN + `B_BASIS_LEN + j];
                end
              end
            end

            5'b00011: begin
              // Twist CT2
              op_a_q     = dest0_poly_q;      // CT2.A
              op_a_b     = dest0_poly_b;      // CT2.A
              op_a_ba     = dest0_poly_ba;      // CT2.A
              op_b_q     = twist_factor_q;
              op_b_b     = twist_factor_b;
              op_b_ba     = twist_factor_ba;
              op_c_q     = dest1_poly_q;      // CT2.B
              op_c_b     = dest1_poly_b;      // CT2.B
              op_c_ba     = dest1_poly_ba;      // CT2.B
              op_d_q     = twist_factor_q;
              op_d_b     = twist_factor_b;
              op_d_ba     = twist_factor_ba;
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_ba = mul_out_2_ba;

              // For next cycle, read registers 11 and 12
              read_idx_0_q = `REG_NPOLY'd11;
              read_idx_1_q = `REG_NPOLY'd12;
            end

            5'b00100: begin
              // Twist CT1
              op_a_q     = stage1_src0_q;      // CT1.A
              op_a_b     = stage1_src0_b;      // CT1.A
              op_a_ba     = stage1_src0_ba;      // CT1.A
              op_b_q     = twist_factor_q;
              op_b_b     = twist_factor_b;
              op_b_ba     = twist_factor_ba;
              op_c_q     = stage1_src1_q;      // CT1.B
              op_c_b     = stage1_src1_b;      // CT1.B
              op_c_ba     = stage1_src1_ba;      // CT1.B
              op_d_q     = twist_factor_q;
              op_d_b     = twist_factor_b;
              op_d_ba     = twist_factor_ba;
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_ba = mul_out_2_ba;
            end

            5'b00101: begin
              // NTT CT1
              inverse    = 1'b0;
              op_a_q     = dest0_poly_q;        // CT1.A * twist
              op_a_b     = dest0_poly_b;        // CT1.A * twist
              op_a_ba     = dest0_poly_ba;        // CT1.A * twist
              op_c_q     = dest1_poly_q;        // CT1.B * twist
              op_c_b     = dest1_poly_b;        // CT1.B * twist
              op_c_ba     = dest1_poly_ba;        // CT1.B * twist
              fu_out_1_q = ntt_out_1_q;
              fu_out_1_b = ntt_out_1_b;
              fu_out_1_ba = ntt_out_1_ba;
              fu_out_2_q = ntt_out_2_q;
              fu_out_2_b = ntt_out_2_b;
              fu_out_2_ba = ntt_out_2_ba;
              ntt_1_valid_in = 1'b1;
              ntt_2_valid_in = 1'b1;

              // Store values in reg 11 and 12
              wb_0_q = 1'b1;
              wb_1_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              controller_wb_1_idx_q = `REG_NPOLY'd12;

              // For next cycle, read registers dest0 and dest1
              read_idx_0_q = `REG_NPOLY'd11;
              read_idx_1_q = `REG_NPOLY'd11;
            end

            5'b00110: begin
              // NTT CT2
              inverse    = 1'b0;
              op_a_q     = stage1_src2_q;        // CT2.A * twist
              op_a_b     = stage1_src2_b;        // CT2.A * twist
              op_a_ba     = stage1_src2_ba;        // CT2.A * twist
              op_c_q     = stage1_src3_q;        // CT2.B * twist
              op_c_b     = stage1_src3_b;        // CT2.B * twist
              op_c_ba     = stage1_src3_ba;        // CT2.B * twist
              fu_out_1_q = ntt_out_1_q;
              fu_out_1_b = ntt_out_1_b;
              fu_out_1_ba = ntt_out_1_ba;
              fu_out_2_q = ntt_out_2_q;
              fu_out_2_b = ntt_out_2_b;
              fu_out_2_ba = ntt_out_2_ba;
              ntt_1_valid_in = 1'b1;
              ntt_2_valid_in = 1'b1;
            end

            5'b00111: begin
              // MUL B2 * A1 & B1 * A2
              op_a_q     = stage1_src0_q;     // CT1.A
              op_a_b     = stage1_src0_b;     // CT1.A
              op_a_ba     = stage1_src0_ba;     // CT1.A
              op_b_q     = stage1_src3_q;     // CT2.B
              op_b_b     = stage1_src3_b;     // CT2.B
              op_b_ba     = stage1_src3_ba;     // CT2.B
              op_c_q     = stage1_src1_q;     // CT1.B
              op_c_b     = stage1_src1_b;     // CT1.B
              op_c_ba     = stage1_src1_ba;     // CT1.B
              op_d_q     = stage1_src2_q;     // CT2.A
              op_d_b     = stage1_src2_b;     // CT2.A
              op_d_ba     = stage1_src2_ba;     // CT2.A
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_ba = mul_out_2_ba;

              // Store values in reg 11 and 12
              wb_0_q = 1'b1;
              wb_1_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              controller_wb_1_idx_q = `REG_NPOLY'd12;
            end

            5'b01000: begin
              // MUL B1 * B2 & A1 * A2
              op_a_q     = stage1_src1_q;     // CT1.B
              op_a_b     = stage1_src1_b;     // CT1.B
              op_a_ba     = stage1_src1_ba;     // CT1.B
              op_b_q     = stage1_src3_q;     // CT2.B
              op_b_b     = stage1_src3_b;     // CT2.B
              op_b_ba     = stage1_src3_ba;     // CT2.B
              op_c_q     = stage1_src1_q;     // CT1.A
              op_c_b     = stage1_src1_b;     // CT1.B
              op_c_ba     = stage1_src1_ba;     // CT1.B
              op_d_q     = stage1_src2_q;     // CT2.A
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_b = mul_out_2_b;
              fu_out_2_ba = mul_out_2_ba;
            end

            5'b01001: begin
              // Inverse NTT: B1 * B2 & A1 * A2
              inverse    = 1'b1;
              op_a_q     = dest0_poly_q;
              op_a_b     = dest0_poly_b;
              op_a_ba     = dest0_poly_ba;
              op_c_q     = dest1_poly_q;
              op_c_b     = dest1_poly_b;
              op_c_ba     = dest1_poly_ba;
              fu_out_1_q = ntt_out_1_q;
              fu_out_1_b = ntt_out_1_b;
              fu_out_1_ba = ntt_out_1_ba;
              fu_out_2_q = ntt_out_2_q;
              fu_out_2_b = ntt_out_2_b;
              fu_out_2_ba = ntt_out_2_ba;
              ntt_1_valid_in = 1'b1;
              ntt_2_valid_in = 1'b1;

              // Store values in reg 11 and 12
              wb_0_q = 1'b1;
              wb_1_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              controller_wb_1_idx_q = `REG_NPOLY'd12;
            end

            5'b01010: begin
              // Inverse NTT: B2 * A1 & B1 * A2
              inverse    = 1'b1;
              op_a_q     = stage1_src0_q;    
              op_a_b     = stage1_src0_b;   
              op_a_ba    = stage1_src0_ba;    
              op_c_q     = stage1_src1_q;
              op_c_b     = stage1_src1_b;
              op_c_ba     = stage1_src1_ba;
              fu_out_1_q = ntt_out_1_q;
              fu_out_1_b = ntt_out_1_b;
              fu_out_1_ba = ntt_out_1_ba;
              fu_out_2_q = ntt_out_2_q;
              fu_out_2_b = ntt_out_2_b;
              fu_out_2_ba = ntt_out_2_ba;
              ntt_1_valid_in = 1'b1;
              ntt_2_valid_in = 1'b1;
            end

            5'b01011: begin
              // Untwist: D0 = B2 * A1 & D2 = B1 * A2
              op_a_b     = dest0_poly_b;      
              op_a_ba     = dest0_poly_ba;    
              op_b_q     = untwist_factor_q;
              op_b_b     = untwist_factor_b;
              op_b_ba     = untwist_factor_ba;
              op_c_q     = dest1_poly_q;     
              op_c_b     = dest1_poly_b;   
              op_c_ba     = dest1_poly_ba;   
              op_d_q     = untwist_factor_q;
              op_d_b     = untwist_factor_b;
              op_d_ba     = untwist_factor_ba;
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_b = mul_out_2_b;
              fu_out_2_ba = mul_out_2_ba;

              // Store values in reg 11 and 12
              wb_0_q = 1'b1;
              wb_1_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              controller_wb_1_idx_q = `REG_NPOLY'd12;
            end

            5'b01100: begin
              // Untwist B1 * B2 & A1 * A2
              op_a_q     = stage1_src0_q;    
              op_a_b     = stage1_src0_b;    
              op_a_ba     = stage1_src0_ba;     
              op_b_q     = untwist_factor_q;   
              op_b_b     = untwist_factor_b;   
              op_b_ba     = untwist_factor_ba;    
              op_c_q     = stage1_src2_q;  
              op_c_b     = stage1_src2_b;  
              op_c_ba     = stage1_src2_ba;     
              op_d_q     = untwist_factor_q;   
              op_d_b     = untwist_factor_b;   
              op_d_ba     = untwist_factor_ba;   
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_b = mul_out_2_b;
              fu_out_2_ba = mul_out_2_ba;
            end

            5'b01101: begin
              // Add D1 = B1 * B2 & A1 * A2
              op_a_q     = dest0_poly_q;     
              op_b_q     = dest1_poly_q;    
              fu_out_1_q = add_out_1;
            end

            5'b01110: begin
              // Add B1 * B2 & A1 * A2
              op_a_q     = dest0_poly_q;     
              op_b_q     = dest1_poly_q;    
              fu_out_1_q = add_out_1;

              // Store values in reg 10
              wb_0_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;

              /*
              Reg 10 - D1
              Reg 11 - D0
              Reg 12 - D2
              */
            end

            5'b01111: begin
              // Multiply D0 and D1 with t
              op_a_q     = stage1_src0_q;   //D0 
              op_a_b     = stage1_src0_b;   //D0 
              op_a_ba     = stage1_src0_ba;   //D0 
              // op_b_q     = `t_MODULUS;    
              // op_b_b     = `t_MODULUS;    
              // op_b_ba     = `t_MODULUS;    
              op_c_q     = stage1_src1_q;   //D1  
              op_c_b     = stage1_src1_b;   //D1  
              op_c_ba     = stage1_src1_ba;   //D1  
              // op_d_q     = `t_MODULUS;  
              // op_d_b     = `t_MODULUS;  
              // op_d_ba     = `t_MODULUS;    
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;
              fu_out_2_q = mul_out_2_q;
              fu_out_2_b = mul_out_2_b;
              fu_out_2_ba = mul_out_2_ba;

              // Store values in reg 10 and 11
              wb_0_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              wb_1_q = 1'b1;
              controller_wb_1_idx_q = `REG_NPOLY'd10;
            end

            5'b10000: begin
              // Multiply D2 with t
              op_a_q     = stage1_src0_q;   //D2
              op_a_b     = stage1_src0_b;   //D2
              op_a_ba     = stage1_src0_ba;   //D2 

              // op_b_q     = `t_MODULUS;    
              // op_b_b     = `t_MODULUS;    
              // op_b_ba     = `t_MODULUS;  
               
              fu_out_1_q = mul_out_1_q;
              fu_out_1_b = mul_out_1_b;
              fu_out_1_ba = mul_out_1_ba;

              // Mod Switch D0 
              op_c_q     = stage1_src1_q;   //D0
              op_c_b     = stage1_src1_b;   //D0
              op_c_ba    = stage1_src1_ba;   //D0
              
              modSwitch_in_valid_2 = 1'b1;

              // op_d_q     = `t_MODULUS;   
              // op_d_b     = `t_MODULUS;   
              // op_d_ba    = `t_MODULUS;  

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `B_BASIS_LEN; j++) begin
                  fu_out_2_b[i][j] = modswitch_out_2[i][j];
                end
              end

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `Ba_BASIS_LEN; j++) begin
                  fu_out_2_ba[i][j] = modswitch_out_2[i][`B_BASIS_LEN + j];
                end
              end
              
              // Store values in reg 12 and 11
              wb_0_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd12;
              wb_1_q = 1'b1;
              controller_wb_1_idx_q = `REG_NPOLY'd11;
            end

            5'b10001: begin
              // Mod Switch D1
              op_a_q     = stage1_src0_q;   //D1  
              op_a_b     = stage1_src0_b;   //D1  
              op_a_ba     = stage1_src0_ba;   //D1 
              modSwitch_in_valid_1 = 1'b1;

              // Mod Switch D2
              op_c_q     = stage1_src1_q;   //D2
              op_c_b     = stage1_src1_b;   //D2
              op_c_ba     = stage1_src1_ba;   //D2
              modSwitch_in_valid_2 = 1'b1;

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `B_BASIS_LEN; j++) begin
                  fu_out_1_b[i][j] = modswitch_out_1[i][j];
                  fu_out_2_b[i][j] = modswitch_out_2[i][j];
                end
              end

              for (int i = 0; i < `N_SLOTS; i++) begin
                for (int j = 0; j < `Ba_BASIS_LEN; j++) begin
                  fu_out_1_ba[i][j] = modswitch_out_1[i][`B_BASIS_LEN + j];
                  fu_out_2_ba[i][j] = modswitch_out_2[i][`B_BASIS_LEN + j];
                end
              end
              
              // Store values in reg 12 and 11
              wb_0_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd10;
              wb_1_q = 1'b1;
              controller_wb_1_idx_q = `REG_NPOLY'd12;
            end

            5'b10010: begin
              // FastBConvEx D0
              op_a_b     = stage1_src0_b;   //D0  
              op_a_ba     = stage1_src0_ba;   //D0  
              fu_out_1_q = fast_BConvex_out_1;
              fastBConvEx_in_valid_1 = 1'b1;
              // FastBConvEx
              op_c_b      = stage1_src1_b;   //D1
              op_c_ba     = stage1_src1_ba;   //D1
              fu_out_1_q = fast_BConvex_out_2; 
              fastBConvEx_in_valid_2 = 1'b1;
              
              wb_0_q = 1'b1;
              controller_wb_0_idx_q = `REG_NPOLY'd11;
              wb_1_q = 1'b1;
              controller_wb_1_idx_q = `REG_NPOLY'd10;
              done = 1;
            end

          endcase
        end
      endcase
    end
  end


endmodule