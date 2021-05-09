module fetch_unit(
    input   wire        clk,
    input   wire        a_rst,
    // memory
    input   wire[15:0]  fetch_opc,
    input   wire[15:0]  fetch_arg,
    input   wire[15:0]  prefetch_opc,
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
    output  wire[15:0]  prefetch_out,
    output  wire[15:0]  ir_out,
    output  wire[15:0]  k16_out,
    output  wire        ir_valid
);

//Internal states encoded in two flip flops
reg[1:0] status;

//Current PC
reg[14:0] pc;
reg[14:0] prefetch; 

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

wire[14:0] inc_pc_amount = { 13'b0, pc_i2 & ~hold, ~pc_i2 & ~hold };
wire[14:0] pc_addition = pc_inc | hold ? inc_pc_amount : k16[15:1];


wire next_status_high_0 = ~pc_inc & ~status[0] | pc_w & status[1] & ~status[0];
wire next_status_high_1 = pc_inv & ~status[1] & ~status[0] | status[1] & ~status[0] & ~pc_w;
wire next_status_is_11 = next_status_high_1 & next_status_high_0;
wire ldpc = status[1] & ~status[0] & next_status_is_11 & ~hold;
wire do_fetch = ~next_status_high_0 & ~next_status_high_1 & ~hold;

always @(posedge clk) begin
    case (status)
    2'b00: pc <= pc + pc_addition;
    2'b01: pc <= pc;
    2'b10: pc <= npc;
    2'b11: pc <= pc;
    endcase
end

always @(posedge clk) begin
    case (status)
    2'b00: prefetch <= pc + pc_addition + 1'b1;
    2'b01: prefetch <= prefetch;
    2'b10: prefetch <= npc + 1'b1;
    2'b11: prefetch <= prefetch;
    endcase
end

always @(posedge clk or negedge a_rst) begin
    if (~a_rst) begin
        status <= 2'b00;
    end else begin
        if (hold) begin
            status <= status;
        end else begin
            case(status)
            2'b00: status <= { pc_inv, ~pc_inc & ~pc_inv };
            2'b01: status <= 2'b00 ;
            2'b10: status <= { 1'b1, next_write };
            2'b11: status <= 2'b00;
            endcase
        end
    end
end

always @(posedge clk) begin
    case({do_fetch, pc[0]})
    2'b00: ir <= ir;
    2'b01: ir <= ir;
    2'b10: ir <= fetch_opc;
    2'b11: ir <= k16;
    endcase
    case({do_fetch, pc[0]})
    2'b00: k16 <= k16;
    2'b01: k16 <= k16;
    2'b10: k16 <= fetch_arg;
    2'b11: k16 <= prefetch_opc;
    endcase
end

assign pc_out = { pc, 1'b0 };
assign prefetch_out = { prefetch, 1'b0 };
assign ir_out = ir;
assign k16_out = k16;
assign ir_valid = ~status[0] & ~status[1];

endmodule
