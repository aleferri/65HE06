module fetch_unit(
    input   wire        clk,
    input   wire        a_rst,
    // memory
    input   wire[31:0]  fetch_opc,
    // memory & decoder
    input   wire        hold,
    // alu feedback
    input   wire        pc_w,
    input   wire[15:0]  pc_alu,
    // decoder
    input   wire        pc_inc,
    input   wire        pc_inv,
    input   wire        pc_branch,
    output  wire[15:0]  pc_out,
    output  wire[15:0]  ir_out,
    output  wire[15:0]  k16_out,
    output  wire        ir_valid
);

//Internal states encoded in two flip flops
reg[1:0] status;

//Current PC
reg[13:0] pc;
reg[13:0] pc_backup;

//New PC fetched from result bus
reg next_write;
reg[13:0] npc;

//Fetched instruction
reg[15:0] k16;
reg[15:0] ir;

always @(posedge clk) begin
    npc <= pc_w ? pc_alu[15:2] : npc;
    next_write <= pc_w | next_write & status[1];
end

reg[1:0] next_status;

always @(*) begin
    case(status)
    2'b00: next_status = 2'b01;
    2'b01: next_status = { pc_inv, ~pc_inv & ~pc_branch };
    2'b10: next_status = { 1'b1, next_write };
    2'b11: next_status = 2'b00;
    endcase
end

wire[13:0] inc_pc_amount = { 13'b0, ~hold & ~(status[0] & status[1]) };
wire[13:0] pc_addition = (pc_inc | hold) ? inc_pc_amount : k16[15:2];

wire next_status_high_0 = next_status[0];
wire next_status_high_1 = next_status[1];
wire next_status_is_11 = next_status_high_1 & next_status_high_0;
wire do_fetch = ( next_status_high_0 & ~next_status_high_1 ) & ~hold;
wire ready_mem = ~hold;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        pc <= 14'b0;
        pc_backup <= 14'b0;
    end else begin
        pc_backup <= pc;
        case (status)
        2'b00: pc <= pc + ready_mem;
        2'b01: pc <= pc + pc_addition;
        2'b10: pc <= npc;
        2'b11: pc <= pc + pc_addition;
        endcase
    end
end

always @(posedge clk or negedge a_rst) begin
    if (~a_rst) begin
        status <= 2'b00;
    end else begin
        status <= next_status;
    end
end

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        ir <= 16'b0;
        k16 <= 16'b0;
    end else begin
        ir <= do_fetch ? fetch_opc[31:16] : ir;
        k16 <= do_fetch ? fetch_opc[15:0] : k16;
    end
end

assign pc_out = { do_fetch ? pc : pc_backup, 2'b0 };
assign ir_out = ir;
assign k16_out = k16;
assign ir_valid = status[0] & ~status[1];

endmodule
