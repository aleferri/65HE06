
module front_end(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        evt_int,
    output  wire        evt_int_ack,
    input   wire[15:0]  i_mem_opcode,
    input   wire[15:0]  i_mem_prefetch_opcode,
    input   wire        i_mem_rdy,
    input   wire        ex_pc_w,
    input   wire[15:0]  ex_pc,
    input   wire        ex_feed_req,
    output  wire        ex_feed_ack,
    input   wire[7:0]   ex_sf,
    input   wire        ex_sf_wr,
    output  wire[15:0]  i_mem_pc,
    output  wire[15:0]  i_mem_prefetch,
    output  wire[19:0]  ex_uop_0,
    output  wire[19:0]  ex_uop_1,
    output  wire[19:0]  ex_uop_2,
    output  wire[1:0]   ex_uop_count,
    output  wire[15:0]  ex_k
);

wire hold_fetch;
wire hold_decode;
wire br_taken;
wire de_pc_inc;
wire de_pc_i2;
wire de_pc_inv;

reg int_mask;
reg int_mask_next;
wire int_restore;

always @(*) begin
    case ( { evt_int, int_restore } )
    2'b00: int_mask_next = int_mask;
    2'b01: int_mask_next = 1'b0;
    2'b10: int_mask_next = 1'b1;
    2'b11: int_mask_next = 1'b0;
    endcase
end

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        int_mask = 1'b0;
    end else begin
        int_mask <= int_mask_next;
    end
end

assign evt_int_ack = ~int_mask & int_mask_next;

wire[15:0] pc;
wire[15:0] prefetch;
wire[15:0] fu_arg;
wire[15:0] fu_ir;
wire fu_ready_ir;
wire mux_forward_pc;

wire de_pc_i2;
wire de_pc_inc;
wire de_pc_inv;

assign hold_fetch = ~i_mem_rdy | ( fu_ready_ir & ~ex_feed_ack );
assign hold_decode = ~fu_ready_ir | ~ex_feed_req;
assign ex_k = mux_forward_pc ? pc : fu_arg;

assign i_mem_pc = pc;

fetch_unit fu(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .fetch_opc ( i_mem_opcode ),
    .prefetch_opc ( i_mem_prefetch_opcode ),
    .hold ( hold_fetch ),
    .pc_w ( ex_pc_w ),
    .pc_alu ( ex_pc ),
    .pc_inc ( de_pc_inc ),
    .pc_i2 ( de_pc_i2 ),
    .pc_inv ( de_pc_inv ),
    .pc_out ( pc ),
    .prefetch_out ( i_mem_prefetch ),
    .ir_out ( fu_ir ),
    .k16_out ( fu_arg ),
    .ir_valid ( fu_ready_ir )
);

decode_unit decode(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .hold ( hold_decode ),
    .ir_valid ( fu_ready_ir ),
    .feed_req ( ex_feed_req ),
    .feed_ack ( ex_feed_ack ),
    .ir ( fu_ir ),
    .sf ( ex_sf ),
    .sf_written ( ex_sf_wr ),
    .sel_pc ( mux_forward_pc ),
    .br_taken ( br_taken ),
    .pc_inv ( de_pc_inv ),
    .pc_i2 ( de_pc_i2 ),
    .pc_inc ( de_pc_inc ),
    .restore_int ( int_restore ),
    .uop_0 ( ex_uop_0 ),
    .uop_1 ( ex_uop_1 ),
    .uop_2 ( ex_uop_2 ),
    .uop_count ( ex_uop_count )
);

endmodule