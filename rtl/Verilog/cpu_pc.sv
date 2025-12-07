`include "types.svh"

module cpu (
  input  logic clk,
  input  logic reset,
  input  operation op,
  //input op_e op_in, //TODO
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
  // think of each operation like a mini program that is hardcoded into the CPU (like a finite state machine)
  pc_state_type programCounter, programCounter_next;
  pc_state_type jumpandlink_PC, jumpandlink_PC_next;// where to go back to after an internal OP (e.g. convolution)
  logic       inverse; // NTT direction flag
  logic     wb_0_q, wb_1_q, done;

  logic ntt_1_valid_in, ntt_1_valid_out, ntt_2_valid_in, ntt_2_valid_out;
  logic doing_ntt, doing_fastBconv;
  logic ntt_1_start, ntt_2_start;


  q_BASIS_poly   op_a_q, op_b_q, op_c_q, op_d_q;
  B_BASIS_poly   op_a_b, op_b_b, op_c_b, op_d_b;
  Ba_BASIS_poly  op_a_ba, op_b_ba, op_c_ba, op_d_ba;

  q_BASIS_poly  add_out_1, add_out_2, mul_out_1_q, mul_out_2_q, fu_out_1_q, fu_out_2_q, ntt_out_1_q, ntt_out_2_q;
  B_BASIS_poly  mul_out_1_b, mul_out_2_b,fu_out_1_b, fu_out_2_b, ntt_out_1_b, ntt_out_2_b;
  Ba_BASIS_poly mul_out_1_ba, mul_out_2_ba, fu_out_1_ba, fu_out_2_ba, ntt_out_1_ba, ntt_out_2_ba;

  // ============================================================
  //  CT-CT MUL intermediates
  // ============================================================

  // Step 1 outputs: mod raise q -> qBBa for each ct component
  qBBa_BASIS_poly fastBconv_out_1, fastBconv_out_2;
  qBBa_BASIS_poly fastBconv_out_3, fastBconv_out_4;

  // Step 2/3/4/5: D0,D1,D2 through qBBa -> BBa -> q
  // qBBa_BASIS_poly D0_qBBa, D1_qBBa, D2_qBBa;
  // BBa_BASIS_poly  D0_BBa,  D1_BBa,  D2_BBa;
  // q_BASIS_poly    D0_q,    D1_q,    D2_q;

  // ---------- fastBConv (mod raise) handshakes ----------
  logic modraise_ct1A_in_valid, modraise_ct1A_out_valid;
  logic modraise_ct1B_in_valid, modraise_ct1B_out_valid;
  logic modraise_ct2A_in_valid, modraise_ct2A_out_valid;
  logic modraise_ct2B_in_valid, modraise_ct2B_out_valid;

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
  op_e operationMode, operationMode_next;
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
    $display("Stage: %d, Operation: %d, Done: %b",programCounter, operation_mode, done_out);
    $display("Op_a: %d, Op_b: %d, Op_c: %d, Op_d: %d", op_a_q[0][0], op_b_q[0][0], op_c_q[0][0], op_d_q[0][0]);
    $display("Fu_1: %d, Fu_2: %d", fu_out_1_q[0][0], fu_out_2_q[0][0]);
    $display("NTT_1_Valid: %b, NTT_2_Valid: %b", ntt_1_valid_out, ntt_2_valid_out);
    if (reset) begin
      dest0_valid_q     <= 1'b0;
      dest1_valid_q     <= 1'b0;
      stage1_valid      <= 1'b0;
      stage1_src0_q     <= '{default: '0};
      stage1_src1_q     <= '{default: '0};
      stage1_src2_q     <= '{default: '0};
      stage1_src3_q     <= '{default: '0};
      operationMode    <= NO_OP;
      stage1_dest0_idx  <= '0;
      stage1_dest1_idx  <= '0;
      dest0_poly_q      <= '{default: '0};
      dest1_poly_q      <= '{default: '0};
      done_out          <= '0;
      programCounter             <= '0;
    end else begin
      // Capture data from register file when valid
      stage1_valid      <= source0_valid_q & source1_valid_q;
      stage1_src0_q     <= source0_poly_q;
      stage1_src1_q     <= source1_poly_q;
      stage1_src2_q     <= source2_poly_q;
      stage1_src3_q     <= source3_poly_q;
      operationMode    <= operationMode_next;
      stage1_dest0_idx  <= dest0_register_index_q;
      stage1_dest1_idx  <= dest1_register_index_q;
      dest0_valid_q     <= wb_0_q;
      dest1_valid_q     <= wb_1_q;
      dest0_poly_q      <= fu_out_1_q;
      dest1_poly_q      <= fu_out_2_q;
      done_out          <= done; 
      doing_ntt <= (operationMode == OP_CT_PT_MUL) &&  (programCounter == 4'b0010 || programCounter == 4'b0111 || programCounter == 4'b0100 || programCounter == 4'b1001);
      programCounter  <= programCounter_next;
      // when operation_mode != No_OP, programCounter = 0
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
      localparam int BASIS_TYPE = (i < `q_BASIS_LEN) ? 0 :   (i < (`q_BASIS_LEN + `B_BASIS_LEN)) ? 1 : 2;
      localparam int LOCAL_IDX = (i < `q_BASIS_LEN) ? i :  (i < (`q_BASIS_LEN + `B_BASIS_LEN)) ? (i - `q_BASIS_LEN) :  (i - `q_BASIS_LEN - `B_BASIS_LEN);
      
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

    // ============================================================
  //  Step 1: mod raise from q -> qBBa for ct1.A, ct1.B, ct2.A, ct2.B
  // ============================================================

  // ct1.A (stage1_src0_q)
  fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS    (q_BASIS),
        .OUT_BASIS   (qBBa_BASIS),
        .ZiLUT       (z_MOD_q),
        .YMODB       (y_q_TO_qBBa)
  ) conv_inst_MODRAISE_ct1A (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (modraise_ct1A_in_valid),   // driven by controller
        .input_RNSpoly(op_a_q),           // ct1.A in q basis
        .out_valid    (modraise_ct1A_out_valid),
        .output_RNSpoly(fastBconv_out_1)              // ct1.A in qBBa basis
  );

  // ct1.B (stage1_src1_q)
  fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS    (q_BASIS),
        .OUT_BASIS   (qBBa_BASIS),
        .ZiLUT       (z_MOD_q),
        .YMODB       (y_q_TO_qBBa)
  ) conv_inst_MODRAISE_ct1B (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (modraise_ct1B_in_valid),
        .input_RNSpoly(op_b_q),           // ct1.B in q basis
        .out_valid    (modraise_ct1B_out_valid),
        .output_RNSpoly(fastBconv_out_2)
  );

  // ct2.A (stage1_src2_q)
  fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS    (q_BASIS),
        .OUT_BASIS   (qBBa_BASIS),
        .ZiLUT       (z_MOD_q),
        .YMODB       (y_q_TO_qBBa)
  ) conv_inst_MODRAISE_ct2A (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (modraise_ct2A_in_valid),
        .input_RNSpoly(op_c_q),           // ct2.A
        .out_valid    (modraise_ct2A_out_valid),
        .output_RNSpoly(fastBconv_out_3)
  );

  // ct2.B (stage1_src3_q)
  fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS    (q_BASIS),
        .OUT_BASIS   (qBBa_BASIS),
        .ZiLUT       (z_MOD_q),
        .YMODB       (y_q_TO_qBBa)
  ) conv_inst_MODRAISE_ct2B (
        .clk          (clk),
        .reset        (reset),
        .in_valid     (modraise_ct2B_in_valid),
        .input_RNSpoly(op_d_q),           // ct2.B
        .out_valid    (modraise_ct2B_out_valid),
        .output_RNSpoly(fastBconv_out_4)
  );

  // // D0
  // modSwitch_qBBa_to_BBa qBBatoBBaMODSWITCH_D0 (
  //     .clk            (clk),
  //     .reset          (reset),
  //     .in_valid       (ms_D0_in_valid),   // driven by controller
  //     .input_RNSpoly  (D0_qBBa),          // D0 in qBBa basis
  //     .out_valid      (ms_D0_out_valid),
  //     .output_RNSpoly (D0_BBa)            // D0 in BBa basis
  // );

  // // D1
  // modSwitch_qBBa_to_BBa qBBatoBBaMODSWITCH_D1 (
  //     .clk            (clk),
  //     .reset          (reset),
  //     .in_valid       (ms_D1_in_valid),
  //     .input_RNSpoly  (D1_qBBa),
  //     .out_valid      (ms_D1_out_valid),
  //     .output_RNSpoly (D1_BBa)
  // );

  // // D2
  // modSwitch_qBBa_to_BBa qBBatoBBaMODSWITCH_D2 (
  //     .clk            (clk),
  //     .reset          (reset),
  //     .in_valid       (ms_D2_in_valid),
  //     .input_RNSpoly  (D2_qBBa),
  //     .out_valid      (ms_D2_out_valid),
  //     .output_RNSpoly (D2_BBa)
  // );

  // // D0
  // fastBConvEx_BBa_to_q BBatoqFASTBCONVEX_D0 (
  //     .clk            (clk),
  //     .reset          (reset),
  //     .in_valid       (fbex_D0_in_valid), // driven by controller
  //     .input_RNSpoly  (D0_BBa),           // D0 in BBa basis
  //     .out_valid      (fbex_D0_out_valid),
  //     .output_RNSpoly (D0_q)              // D0 back in q basis
  // );

  // // D1
  // fastBConvEx_BBa_to_q BBatoqFASTBCONVEX_D1 (
  //     .clk            (clk),
  //     .reset          (reset),
  //     .in_valid       (fbex_D1_in_valid),
  //     .input_RNSpoly  (D1_BBa),
  //     .out_valid      (fbex_D1_out_valid),
  //     .output_RNSpoly (D1_q)
  // );

  // // D2
  // fastBConvEx_BBa_to_q BBatoqFASTBCONVEX_D2 (
  //     .clk            (clk),
  //     .reset          (reset),
  //     .in_valid       (fbex_D2_in_valid),
  //     .input_RNSpoly  (D2_BBa),
  //     .out_valid      (fbex_D2_out_valid),
  //     .output_RNSpoly (D2_q)
  // );

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
    doing_fastBconv = 1'b0;


    ntt_1_valid_in = 1'b0;
    ntt_2_valid_in = 1'b0;

    // new blocks: default no pulses
    modraise_ct1A_in_valid = 1'b0;
    modraise_ct1B_in_valid = 1'b0;
    modraise_ct2A_in_valid = 1'b0;
    modraise_ct2B_in_valid = 1'b0;

    ms_D0_in_valid = 1'b0;
    ms_D1_in_valid = 1'b0;
    ms_D2_in_valid = 1'b0;

    fbex_D0_in_valid = 1'b0;
    fbex_D1_in_valid = 1'b0;
    fbex_D2_in_valid = 1'b0;

    programCounter_next = (done || operationMode == NO_OP) ? '0 : ((ntt_1_valid_in & ~ntt_1_valid_out) || (modraise_ct1A_in_valid & ~modraise_ct1A_out_valid)) ? programCounter : programCounter + 1;
    operationMode_next = (done || operationMode == NO_OP) ? operation_mode : operationMode;

    // we consider ourselves "in an NTT step" at these stages

    if (stage1_valid) begin 
      unique case (operationMode)
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
          done       = 1;
        end

        OP_CT_PT_MUL: begin
          case (programCounter)
            // CT1.A * Plaintext
            // TWIST
            4'b0001: begin
              op_a_q     = stage1_src0_q;       // CT1.A (vec)
              op_b_q     = twist_factor_q;
              op_c_q     = stage1_src3_q;       // PT (vec)
              op_d_q     = twist_factor_q;
              fu_out_1_q = mul_out_1_q;
              fu_out_2_q = mul_out_2_q;
            end

            // NTT of CT1.A and PT
            4'b0010: begin
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
            4'b0011: begin
              op_a_q     = dest0_poly_q;        // NTT(CT1.A * twist)
              op_b_q     = dest1_poly_q;        // NTT(PT * twist)
              fu_out_1_q = mul_out_1_q;         // CT1.A * PT
            end

            // Inverse NTT (A)
            4'b0100: begin
              inverse    = 1'b1;
              op_a_q     = dest0_poly_q;
              fu_out_1_q = ntt_out_1_q;
              ntt_1_valid_in = 1'b1;
            end

            // Untwist (A)
            4'b0101: begin
              op_a_q     = dest0_poly_q;
              op_b_q     = untwist_factor_q;
              fu_out_1_q = mul_out_1_q;
              wb_0_q     = 1;
            end

            // CT1.B * Plaintext — twist
            4'b0110: begin
              op_a_q     = stage1_src1_q;       // CT1.B
              op_b_q     = twist_factor_q;
              op_c_q     = stage1_src3_q;       // PT
              op_d_q     = twist_factor_q;
              fu_out_1_q = mul_out_1_q;
              fu_out_2_q = mul_out_2_q;
            end

            // NTT (B path)
            4'b0111: begin
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
            4'b1000: begin
              op_a_q     = dest0_poly_q;
              op_b_q     = dest1_poly_q;
              fu_out_1_q = mul_out_1_q;
            end

            // Inverse NTT (B)
            4'b1001: begin
              inverse    = 1'b1;
              op_a_q     = dest0_poly_q;
              fu_out_1_q = ntt_out_1_q;
              ntt_1_valid_in = 1'b1;
              // ntt_1_valid_in from ntt_1_start FF
            end

            // Untwist (B)
            4'b1010: begin
              op_a_q     = dest0_poly_q;
              op_b_q     = untwist_factor_q;
              fu_out_2_q = mul_out_1_q;
              wb_1_q     = 1;
              done       = 1;
            end
          endcase
        end

        OP_CT_CT_MUL: begin
          unique case (programCounter)

            // ======================================================
            // Step 1: q -> qBBa on A1,B1,A2,B2
            // ======================================================

            // Kick all four mod-raises in parallel once
            4'd1: begin
              modraise_ct1A_in_valid = 1'b1;  // A1 -> qBBa
              modraise_ct1B_in_valid = 1'b1;  // B1 -> qBBa
              modraise_ct2A_in_valid = 1'b1;  // A2 -> qBBa
              modraise_ct2B_in_valid = 1'b1;  // B2 -> qBBa
              doing_fastBconv = 1'b1;
              // If you want to stall here until all out_valid are high,
              // gate your programCounter increment using ct_ct_modraise_done.
            end

            // ======================================================
            // Step 2: D0,D1,D2 polynomial mul in qBBa
            //   D0 = B1 * B2
            //   D1 = B2*A1 + B1*A2
            //   D2 = A1 * A2
            // ======================================================

            // 4'd5: begin
            //   // Assume mod-raise outputs are now valid in ct1_*_qBBa/ct2_*_qBBa.
            //   // These are pure combinational function calls; the real work
            //   // is in poly_mul_qBBa().
            //   D0_qBBa = poly_mul_qBBa(ct1_B_qBBa, ct2_B_qBBa); // B1 * B2
            // end

            // 4'd6: begin
            //   D2_qBBa = poly_mul_qBBa(ct1_A_qBBa, ct2_A_qBBa); // A1 * A2
            // end

            // 4'd7: begin
            //   qBBa_BASIS_poly tmp1, tmp2;

            //   tmp1     = poly_mul_qBBa(ct2_B_qBBa, ct1_A_qBBa); // B2 * A1
            //   tmp2     = poly_mul_qBBa(ct1_B_qBBa, ct2_A_qBBa); // B1 * A2

            //   // D1 = tmp1 + tmp2 (coefficient-wise in qBBa)
            //   for (int s = 0; s < `N_SLOTS; s++) begin
            //     for (int i = 0; i < `qBBa_BASIS_LEN; i++) begin
            //       D1_qBBa[s][i] = tmp1[s][i] + tmp2[s][i]; // TODO: mod qBBa_BASIS[i] if needed
            //     end
            //   end
            // end

            // // ======================================================
            // // Step 3: multiply D0,D1,D2 by t_MODULUS (scalar)
            // // ======================================================

            // 4'd8: begin
            //   for (int s = 0; s < `N_SLOTS; s++) begin
            //     for (int i = 0; i < `qBBa_BASIS_LEN; i++) begin
            //       D0_qBBa[s][i] = D0_qBBa[s][i] * `t_MODULUS; // TODO: mod qBBa_BASIS[i]
            //       D1_qBBa[s][i] = D1_qBBa[s][i] * `t_MODULUS;
            //       D2_qBBa[s][i] = D2_qBBa[s][i] * `t_MODULUS;
            //     end
            //   end
            // end

            // // ======================================================
            // // Step 4: mod-switch qBBa -> BBa (D0,D1,D2)
            // // ======================================================

            // 4'd9: begin
            //   ms_D0_in_valid = 1'b1;  // D0_qBBa -> D0_BBa
            // end

            // 4'd10: begin
            //   ms_D1_in_valid = 1'b1;  // D1_qBBa -> D1_BBa
            // end

            // 4'd11: begin
            //   ms_D2_in_valid = 1'b1;  // D2_qBBa -> D2_BBa
            // end

            // // ======================================================
            // // Step 5: fastBConvEx BBa -> q (D0,D1,D2)
            // // ======================================================

            // 4'd12: begin
            //   fbex_D0_in_valid = 1'b1; // D0_BBa -> D0_q
            // end

            // 4'd13: begin
            //   fbex_D1_in_valid = 1'b1; // D1_BBa -> D1_q
            // end

            // 4'd14: begin
            //   fbex_D2_in_valid = 1'b1; // D2_BBa -> D2_q
            // end

            // // ======================================================
            // // Step 6: write back ciphertext (no relinearization yet)
            // // For now:
            // //   new A = D1_q
            // //   new B = D0_q
            // // ======================================================

            // 4'd15: begin
            //   fu_out_1_q = D1_q;  // ct_out.A
            //   fu_out_2_q = D0_q;  // ct_out.B

            //   wb_0_q     = 1'b1;
            //   wb_1_q     = 1'b1;
            //   done       = 1'b1;
            // end

            // default: ;
          endcase
        end
     endcase
    end
  end
endmodule



/* For references:

- 1: perform mod raise from q-> qBBa (use the fastBconv block "conv_inst_MODRAISE")
    - do this for each polynomial in ct1.a ct1.b ct2.a ct2.b
- 2: do this: 
      D0 = self.polynomial_mul(B1,B2)
      D1 = self.polynomial_mul(B2,A1) + self.polynomial_mul(B1,A2)
      D2 = self.polynomial_mul(A1,A2)
-3: multiply everything by `t_MODULUS (a single integer scalar that multiplies D0, D1, and D2)
-4: use "qBBatoBBaMODSWITCH" to perform mod switch on D0, D1, and D2
-5: perform "fastBconvEx" from B*Ba to q using "BBatoqFASTBCONVEX". apply individually on D0 D1 and D2
-6: ...to be continued...

// use this for step 1 mod raise (apply individually to ct1.a ct1.b ct2.a ct2.b)
fastBConv #(
        .IN_BASIS_LEN(`q_BASIS_LEN),
        .OUT_BASIS_LEN(`qBBa_BASIS_LEN),
        .IN_BASIS(q_BASIS),
        .OUT_BASIS(qBBa_BASIS),
        .ZiLUT(z_MOD_q),
        .YMODB(y_q_TO_qBBa)
    ) conv_inst_MODRAISE (
        .clk(clk),
        .reset(reset),
        .in_valid(#TODO#),// this is a single bit
        .input_RNSpoly(#TODO#),// this is a polynomial with each coefficient in q basis
        .out_valid(#TODO#),// this is a single bit
        .output_RNSpoly(#TODO#)// this is a polynomial with each coefficient in qBBa basis
    );


// mod switch from qBBa to BBa
// apply individually to D0 D1 and D2
modSwitch_qBBa_to_BBa qBBatoBBaMODSWITCH (
    .clk            (clk),
    .reset          (reset),
    .in_valid       (#TODO#),
    .input_RNSpoly  (#TODO#),// this is a polynomial with each coefficient in qBBa basis
    .out_valid      (#TODO#),
    .output_RNSpoly (#TODO#)// this is a polynomial with each coefficient in BBa basis
);


// fast b conv exact from BBa to q
// apply individually to D0 D1 and D2
fastBConvEx_BBa_to_q BBatoqFASTBCONVEX (
    .clk            (clk),
    .reset          (reset),
    .in_valid       (#TODO#),
    .input_RNSpoly  (#TODO#),// this is a polynomial with each coefficient in BBa basis
    .out_valid      (#TODO#),
    .output_RNSpoly (#TODO#)// this is a polynomial with each coefficient in q basis
);



*/