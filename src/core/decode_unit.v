module decode_unit(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        hold,
    input   wire        ir_valid,
    input   wire        feed_req,
    output  wire        feed_ack,
    input   wire[15:0]  ir,
    input   wire[7:0]   sf,
    input   wire        sf_written,
    output  wire        sel_pc,
    output  wire        br_taken,
    output  wire        pc_inv,
    output  wire        pc_inc,
    output  wire        restore_int,
    output  wire        is_stp,
    output  wire        is_wai,
    output  wire        is_bsr,
    output  wire        is_jsr,
    output  wire[19:0]  uop_0,
    output  wire[19:0]  uop_1,
    output  wire[19:0]  uop_2,
    output  wire[1:0]   uop_count
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
parameter ROL_OP = 5'b01110;
parameter ROR_OP = 5'b01111;
parameter STA_OP = 5'b10000;
parameter RMW_OP = 5'b10001;
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

wire is_ld  = ~ir[15];
wire is_sta = ir[15:11] == STA_OP;
wire is_rmw = ir[15:11] == RMW_OP;
wire is_inc = ir[10:8] == UNARY_INC;
wire is_dep = ir[10:8] == UNARY_DEP;

wire is_bsr = ir[15:11] == 5'b10100;

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
wire not_taken_pred = ~is_taken_pred & is_predicated_op;

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
    default: alu_bits_last_step = 4'b0000;
    endcase
end

wire[2:0] field_reg_0 = ir[10:8];
wire[2:0] field_reg_1 = ir[2:0];
wire[1:0] field_reg_2 = ir[3:2];
wire[1:0] field_reg_3 = ir[1:0];

reg busy_sf;
reg[1:0] status;

wire width_bit = ir[6];

wire is_pc_dest = (field_reg_0 == 3'b011) & ~is_sta;
wire is_pc_update = (is_pc_dest | is_predicated_op & busy_sf) & (status == 2'b00);


wire bit_0_active = (status == 2'b00) & is_predicated_op & busy_sf | ~is_taken_pred & (status == 2'b11);
wire bit_1_active = is_pc_update | (~ir_valid & status == 2'b10 ) | ( status == 2'b11 & busy_sf );

wire issued = ~bit_0_active & ~bit_1_active & feed_req & ir_valid;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        status = 2'b0;
    end else begin
        status <= hold ? status : { bit_1_active, bit_0_active };
    end
end

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        busy_sf = 1'b0;
    end else begin
        if ( busy_sf ) begin
            busy_sf <= hold | ~(~hold & sf_written);
        end else begin
            busy_sf <= (status == 2'b0) & (field_reg_0 == 3'b010 | save_flags) & ~is_sta & ~hold & ir_valid;
        end
    end
end

assign uop_2 = {
    4'b0,
    1'b0, //mask flags
    1'b1, // ld
    1'b0, // wr
    1'b0, //write flags,
    4'b1000, // destination bits
    1'b0,  // write back address
    1'b0,  // select input for ALU, always select K
    { 1'b1, field_reg_3 }, // B register select, don't care for uop_2
    { 1'b1, field_reg_3 } // A register select, top bit is always 1
};

assign uop_1 = {
    is_push ? 4'b0010 : 4'b0111, // sub if push
    1'b0,                        // always mask
    is_sta & is_ixy | is_ld,     // load if is sta indirect or is load
    1'b0,                        // never store
    1'b0,                        // never write flags 
    is_push ? { 2'b01, field_reg_2 } : { 3'b100, is_ld & width_bit }, // width is 1 only if is load 8 bit
    is_pop,                      // write back address if is pop
    1'b0,                        // always select K                      
    field_reg_1,                 // don't care, as we always select K
    (is_sta & is_ixy) ? { 1'b1, field_reg_3 } : { 1'b1, field_reg_2 } // source is re-index if sta indirect, index otherwise
};

assign uop_0 = {
    alu_bits_last_step,         // selected ALU function
    is_adc | is_sbc | is_rol | is_ror, //do not mask if the op use carry
    1'b0,                              //last operation cannot load
    is_rmw | is_sta,                   //write if is sta or read-modify-write
    save_flags,                        //save flags if the op requires it
    ( is_sta | is_rmw | not_taken_pred ) ? { 1'b1, not_taken_pred, 1'b0, width_bit } : field_reg_0, // dest: 4 bit
    1'b0,                              //never write back
    is_reg,                            //select p if K
    is_sta ? field_reg_0 : field_reg_1,  //if op is store then B register is @A
    is_sta ? { 1'b1, field_reg_2 } : field_reg_0 // if op is store then A register is index
};

assign uop_count = (is_reg | is_imm | is_sta & is_idx & ~is_push) ? 2'b0 : ( is_lda & is_idx | is_sta & is_ixy | is_push ) ? 2'b01 : 2'b10;
assign restore_int = is_rti & issued;

assign feed_ack = issued;
assign br_taken = is_predicated_op & is_taken_pred | is_bsr;
assign pc_inc = ~is_pc_dest | is_pc_dest & not_taken_pred;
assign pc_inv = is_pc_dest & ~is_addcc_imm;
assign sel_pc = is_reg & (field_reg_1 == 3'b011) | is_sta & (field_reg_0 == 3'b011);

endmodule
