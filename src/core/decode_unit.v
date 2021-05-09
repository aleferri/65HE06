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
    output  wire        pc_i2,
    output  wire        pc_inc,
    output  wire        restore_int,
    output  wire[15:0]  uop_0,
    output  wire[15:0]  uop_1,
    output  wire[15:0]  uop_2,
    output  wire[1:0]   uop_count
);

wire is_add = ir[15:11] == 5'b00000;
wire is_sub = ir[15:11] == 5'b00001;
wire is_lda = ir[15:11] == 5'b00010;
wire is_cmp = ir[15:11] == 5'b00011;
wire is_ora = ir[15:11] == 5'b00100;
wire is_and = ir[15:11] == 5'b00101;
wire is_eor = ir[15:11] == 5'b00110;
wire is_tst = ir[15:11] == 5'b00111;
wire is_ext = ir[15:11] == 5'b01000;
wire is_bsw = ir[15:11] == 5'b01001;
wire is_lsr = ir[15:11] == 5'b01010;
wire is_asl = ir[15:11] == 5'b01011;
wire is_adc = ir[15:11] == 5'b01100;
wire is_sbc = ir[15:11] == 5'b01101;
wire is_rol = ir[15:11] == 5'b01110;
wire is_ror = ir[15:11] == 5'b01111;

wire is_sta = ir[15:11] == 5'b10000;
wire is_rmw = ir[15:11] == 5'b10001;
wire is_inc = ir[10:8] == 3'b000;
wire is_dep = ir[10:8] == 3'b001;

wire is_bsr = ir[15:11] == 5'b10100;

wire is_brk = ir[15:11] == 5'b10110;
wire is_rti = ir[15:11] == 5'b11000;
wire is_wai = ir[15:11] == 5'b11001;
wire is_stp = ir[15:11] == 5'b11010;

wire is_addcc_imm = ir[15:11] == 5'b11110;
wire is_addcc_reg = ir[15:11] == 5'b11111;

wire field_reg_0 = ir[10:8];
wire field_reg_1 = ir[3:2];
wire field_reg_2 = ir[1:0];
wire is_post_inc = ir[1] & ~ir[0];
wire is_pre_dec = ir[1] & ir[0];

reg busy_sf;
reg[1:0] status;

wire width_bit = ir[6];

wire is_pc_update = (is_pc_inv | is_predicated_op_op & busy_sf) & (status == 2'b00);

wire high_bit_0 = (status == 2'b00) & is_predicated_op & busy_sf | ~taken_pred & (status == 2'b11);
wire high_bit_1 =  is_pc_update | (~valid_pc & status == 2'b10 ) | ( status == 2'b11 & busy );

wire issued = ~high_bit_0 & ~high_bit_1 & feed_req & ir_valid;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        status <= 2'b0;
    end else begin
        status <= { high_bit_1, high_bit_0 };
    end
end

assign uop_2 = {
    4'b0,
    1'b0, //mask flags
    1'b1, // ld
    1'b0, // wr
    1'b0, //write flags,
    3'b100, // dest top 3 bits
    1'b0,
    2'b01,  // select input for ALU
    3'b000, // B register select, don't care for uop_2
    1'b1, // A register select top bit. It is always index, so 1
    field_reg_2
};

assign uop_1 = {
    4'b0111,
    1'b0,
    is_sta & is_reindex | is_ld
    is_push,
    1'b0,
    3'b100,
    is_sta & is_reindex ? width_bit : 1'b0
    2'b01,
    field_reg_1,
    is_sta & is_reindex ? field_reg_2 : field_reg_1
};

assign uop_0 = {
};

assign uop_count = 2'b0;
assign restore_int = is_rti & issued;

endmodule