module decode_unit(
    input   wire        clk,
    input   wire        a_rst,
    
    // cpu status control
    input   wire        hold,  // hold instruction feeding
    input   wire        clr_idx,
    output  wire        sf_query,
    output  wire        op_rti,
    output  wire        op_stp,
    output  wire        op_wai,
    
    // instruction fetch
    input   wire[15:0]  ir,
    output  wire        br_taken,
    output  wire        pc_inv,
    output  wire        pc_inc,
    
    // alu
    input   wire[7:0]   sf,
    
    // scheduling queue
    output  wire        id_feed,
    output  wire[31:0]  id_iop,
    output  wire[2:0]   id_iop_init
);
parameter ADD_OP = 5'b00000;
parameter SUB_OP = 5'b00001;
parameter LDA_OP = 5'b00010;
parameter CMP_OP = 5'b00011;
parameter ORA_OP = 5'b00100;
parameter AND_OP = 5'b00101;
parameter EOR_OP = 5'b00110;
parameter TST_OP = 5'b00111;
parameter EXT_OP = 5'b01000;
parameter BSW_OP = 5'b01001;
parameter LSR_OP = 5'b01010;
parameter ASL_OP = 5'b01011;
parameter ADC_OP = 5'b01100;
parameter SBC_OP = 5'b01101;
parameter ROR_OP = 5'b01110;
parameter ROL_OP = 5'b01111;
parameter STA_OP = 5'b10000;
parameter RMW_OP = 5'b10001;
parameter LDF_OP = 5'b10010;
parameter STF_OP = 5'b10011;
parameter CAI_OP = 5'b11110;
parameter CAR_OP = 5'b11111;

parameter UNARY_INC = 3'b000;
parameter UNARY_DEP = 3'b001;

wire is_add = ir[15:11] == ADD_OP;
wire is_sub = ir[15:11] == SUB_OP;
wire is_lda = ir[15:11] == LDA_OP;
wire is_cmp = ir[15:11] == CMP_OP;
wire is_ora = ir[15:11] == ORA_OP;
wire is_and = ir[15:11] == AND_OP;
wire is_eor = ir[15:11] == EOR_OP;
wire is_tst = ir[15:11] == TST_OP;
wire is_ext = ir[15:11] == EXT_OP;
wire is_bsw = ir[15:11] == BSW_OP;
wire is_lsr = ir[15:11] == LSR_OP;
wire is_asl = ir[15:11] == ASL_OP;
wire is_adc = ir[15:11] == ADC_OP;
wire is_sbc = ir[15:11] == SBC_OP;
wire is_rol = ir[15:11] == ROL_OP;
wire is_ror = ir[15:11] == ROR_OP;
wire is_ldf = ir[15:11] == LDF_OP;
wire is_stf = ir[15:11] == STF_OP;

wire is_sta = ir[15:11] == STA_OP;
wire is_rmw = ir[15:11] == RMW_OP;
wire is_inc = ir[10:8] == UNARY_INC;
wire is_dep = ir[10:8] == UNARY_DEP;

wire is_bsr = ir[15:11] == 5'b10100;
wire is_jsr = ir[15:11] == 5'b10101;

wire is_brk = ir[15:11] == 5'b10110;
wire is_rti = ir[15:11] == 5'b11000;
wire is_wai = ir[15:11] == 5'b11001;
wire is_stp = ir[15:11] == 5'b11010;

wire is_addcc_imm = ir[15:11] == 5'b11110;
wire is_addcc_reg = ir[15:11] == 5'b11111;
wire[2:0] cc_flags = ir[6:4];

reg[3:0] alu_bits_last_step;

wire save_flags = ir[7];

wire is_reg = (ir[5:4] == 2'b00 & ~is_addcc_imm & ~is_addcc_reg) | is_addcc_reg;
wire is_imm = (ir[5:4] == 2'b01 & ~is_addcc_imm & ~is_addcc_reg) | is_addcc_imm;
wire is_idx = ir[5:4] == 2'b10 & ~is_addcc_imm & ~is_addcc_reg;
wire is_ixy = ir[5:4] == 2'b11 & ~is_addcc_imm & ~is_addcc_reg;
wire is_push = (ir[1:0] == 2'b10) & is_idx; // @A - k16 -> A ; B -> [@A + k16] ; [post decrement, k16 = num]
wire is_pop = (ir[1:0] == 2'b11) & is_idx; // [@A + k16] -> T, @A + k16 -> @A; T -> @D; [pre increment, k16 = num]

wire is_flag_bit_set = ir[3];
wire is_predicated_op = is_addcc_imm | is_addcc_reg;
wire is_taken_pred = ( sf[cc_flags] == is_flag_bit_set );
wire skip_op = is_predicated_op & ~is_taken_pred;

always @(*) begin
    case(ir[15:11])
    ADD_OP,
    ADC_OP,
    CAI_OP,
    CAR_OP: alu_bits_last_step = 4'b0000;
    SUB_OP,
    CMP_OP,
    SBC_OP: alu_bits_last_step = 4'b0010;
    ROL_OP,
    ASL_OP: alu_bits_last_step = 4'b1011;
    ROR_OP,
    LSR_OP: alu_bits_last_step = 4'b1010;
    LDA_OP: alu_bits_last_step = 4'b0111;
    ORA_OP: alu_bits_last_step = 4'b0101;
    AND_OP,
    TST_OP: alu_bits_last_step = 4'b0100;
    EOR_OP: alu_bits_last_step = 4'b0110;
    EXT_OP: alu_bits_last_step = 4'b1000;
    BSW_OP: alu_bits_last_step = 4'b1001;
    RMW_OP: alu_bits_last_step = is_dep ? 4'b0011 : 4'b0001;
    LDF_OP: alu_bits_last_step = 4'b1110;
    STF_OP: alu_bits_last_step = 4'b1111;
    default: alu_bits_last_step = 4'b0000;
    endcase
end

wire[2:0] field_reg_0 = ir[10:8];
wire[2:0] field_reg_1 = ir[2:0];
wire[1:0] field_reg_2 = ir[3:2];
wire[1:0] field_reg_3 = ir[1:0];

wire width_bit = ir[6];

assign op_rti = is_rti;
assign op_stp = is_stp;
assign op_wai = is_wai;

wire is_pc_dest = ( field_reg_0 == 3'b011 ) & ~is_sta;

assign br_taken = ( is_predicated_op & is_taken_pred | is_bsr ) & ~hold;
assign pc_inc = ~is_pc_dest | is_pc_dest & skip_op;
assign pc_inv = is_pc_dest & ( ~is_predicated_op | is_predicated_op & ~is_addcc_imm ) & ~hold;

assign sf_query = is_predicated_op;

/**
 * Internal OPeration fields:
 *
 * 30: agu_mask_index       (AGU step)
 * 29: agu_send_index       (AGU step)
 * 28: agu_write_back       (AGU step)
 * 27: agu_index_1_1        (AGU step)
 * 26: agu_index_1_0        (AGU step)
 * 25: agu_index_0_1        (AGU step)
 * 24: agu_index_0_0        (AGU step)
 * -----------------------------------
 * 23: alu_is_jsr           (ALU step)
 * 22: alu_st_mem           (ALU step)
 * 21: alu_save_flags       (ALU step)
 * 20: alu_carry_mask       (ALU step)
 * 19: alu_fn_3             (ALU step)
 * 18: alu_fn_2             (ALU step)
 * 17: alu_fn_1             (ALU step)
 * 16: alu_fn_0             (ALU step)
 * 15: alu_a_2              (ALU step)
 * 14: alu_a_1              (ALU step)
 * 13: alu_a_0              (ALU step)
 * 12: alu_b_2              (ALU step)
 * 11: alu_b_1              (ALU step)
 * 10: alu_b_0              (ALU step)
 * 09: alu_d_3              (ALU step)
 * 08: alu_d_2              (ALU step)
 * 07: alu_d_1              (ALU step)
 * 06: alu_d_0              (ALU step)
 * 05: alu_k                (ALU step)
 * -----------------------------------
 * 04: mem_is_rmw           (STORE step)
 * 03: mem_width            (LOAD/STORE step)
 * 02: reserved
 * 01: reserved
 * 00: reserved
 * -----------------------------------
 */
 
assign id_iop = {
    1'b0,
    // agu
    clr_idx,
    is_push,
    is_push | is_pop,
    field_reg_3,
    field_reg_2,
    // alu
    is_jsr | is_bsr,
    is_sta | is_rmw,
    save_flags,
    is_adc | is_sbc | is_rol | is_ror,
    alu_bits_last_step,
    field_reg_0,
    field_reg_1,
    ~is_sta & ~is_rmw & ~is_cmp & ~is_tst & ~is_stf,
    field_reg_0,
    ~is_reg,
    // mem
    is_rmw,
    width_bit,
    3'b0
};

assign id_iop_init = {
    1'b1,
    is_reg | is_imm | (is_sta & is_idx),
    is_idx
};

assign id_feed = ~hold & ~skip_op;

endmodule
