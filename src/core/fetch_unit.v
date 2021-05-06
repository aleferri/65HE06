module fetch_unit(
    input   wire        clk,
    // memory
    input   wire[15:0]  fetch_opc,
    input   wire[15:0]  fetch_arg,
    // memory & decoder
    input   wire        hold,
    // alu feedback
    input   wire        pc_w,
    input   wire[15:0]  pc_alu,
    // decoder
    input   wire        pc_inc,
    input   wire        pc_i2,
    input   wire        pc_inv,
    output  wire[15:0]  pc_out,
    output  wire[15:0]  ir_out,
    output  wire[15.0]  k16_out,
    output  wire        d_valid
);

//Internal states encoded in two flip flops
reg[1:0] status;

//Current PC
reg[14:0] pc;

//New PC fetched from result bus
reg next_write;
reg[15:0] npc;

//Fetched instruction
reg[15:0] k16;
reg[15:0] ir;


always @(posedge clk) begin
    npc <= pc_w ? pc_alu : npc;
    next_write <= pc_w | next_write & status[1];
end

wire[14:0] inc_pc_amount = { 13'b0, pc_i2, ~pc_i2 };
wire[14:0] pc_addition = pc_inc ? inc_pc_amount : k16[15:1];


wire next_status_high_0 = ~inc & ~status[0] | pc_w & status[1] & ~status[0];
wire next_status_high_1 = pc_inv & ~status[1] & ~status[0] | status[1] & ~status[0] & ~pc_w;
wire next_status_is_11 = next_status_high_1 & next_status_high_0;
wire ldpc = status[1] & ~status[0] & next_status_is_11 & ~hold;
wire do_fetch = ~next_status_high_0 & ~next_status_high_1 & ~hold;

always @(posedge clk) begin
    case (status[1]):
    1'b0: pc <= pc + pc_addition;
    1'b1: pc <= ldpc ? npc[15:1] : pc;
    endcase
end

always @(posedge clk) begin
    if (hold) begin
        status <= status;
    end else begin
        case(status):
        2'b00: status <= { ~pc_inv, ~pc_inc };
        2'b01: status <= 2'b00 ;
        2'b10: status <= { 1'b1, pc_w };
        2'b11: status <= 2'b00;
        endcase
    end
end

always @(posedge clk) begin
    ir <= do_fetch ? fetch_opc : ir;
    k16 <= do_fetch ? fetch_arg : k16;
end

assign pc_out = { pc, 1'b0 };
assign ir_out = ir;
assign k16_out = k16;
assign valid = ~status[0] & ~status[1];

endmodule
