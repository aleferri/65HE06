
module core(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        evt_int,
    output  wire        evt_int_ack,
    input   wire[15:0]  i_mem_opcode,
    input   wire[15:0]  i_mem_prefetch_opcode,
    input   wire        i_mem_rdy,
    output  wire[15:0]  i_mem_pc,
    output  wire[15:0]  i_mem_prefetch,
    input   wire        d_mem_rdy,
    input   wire[15:0]  d_mem_data_in,
    output  wire[15:0]  d_mem_addr,
    output  wire[15:0]  d_mem_data_out,
    output  wire        d_mem_be0,
    output  wire        d_mem_be1,
    output  wire        d_mem_cmd,
    output  wire        d_mem_assert
);

wire ex_pc_w;
wire[15:0] ex_pc;
wire ex_feed_req;
wire ex_feed_ack;
wire ex_sf_wr;

wire[19:0] ex_uop_0;
wire[19:0] ex_uop_1;
wire[19:0] ex_uop_2;
wire[1:0] ex_uop_count;
wire[15:0] ex_k;

wire[15:0] ex_rq_addr;
wire ex_rq_wr_addr;
wire[15:0] ex_rq_data;
wire ex_rq_width;
wire ex_rq_cmd;
wire ex_rq_t_id;
wire ex_rq_start;
wire ex_t_id_wr;
wire ex_rq_ack;
wire mem_writeback = ~d_mem_cmd & d_mem_rdy & d_mem_assert;

wire[15:0] sf_shared;
wire[7:0] ex_sf = sf_shared[7:0];
wire ex_hold = (~d_mem_rdy & d_mem_assert);

front_end front(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .evt_int ( evt_int ),
    .evt_int_ack ( evt_int_ack ),
    .i_mem_opcode ( i_mem_opcode ),
    .i_mem_prefetch_opcode ( i_mem_prefetch_opcode ),
    .i_mem_rdy ( i_mem_rdy ),
    .ex_pc_w ( ex_pc_w ),
    .ex_pc ( ex_pc ),
    .ex_feed_req ( ex_feed_req ),
    .ex_feed_ack ( ex_feed_ack ),
    .ex_sf ( ex_sf ),
    .ex_sf_wr ( ex_sf_wr ),
    .i_mem_pc ( i_mem_pc ),
    .i_mem_prefetch ( i_mem_prefetch ),
    .i_mem_rdy ( i_mem_rdy ),
    .i_mem_opcode ( i_mem_opcode ),
    .i_mem_prefetch_opcode ( i_mem_prefetch_opcode ),
    .ex_uop_0 ( ex_uop_0 ),
    .ex_uop_1 ( ex_uop_1 ),
    .ex_uop_2 ( ex_uop_2 ),
    .ex_uop_count ( ex_uop_count ),
    .ex_k ( ex_k )
);

ucore back(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .hold ( ex_hold ),
    .uop_0 ( ex_uop_0 ),
    .uop_1 ( ex_uop_1 ),
    .uop_2 ( ex_uop_2 ),
    .uop_cnt ( ex_uop_count ),
    .k16 ( ex_k ),
    .mem_data_in ( d_mem_data_in ),
    .mem_rq_data ( ex_rq_data ),
    .mem_rq_addr ( ex_rq_addr ),
    .mem_rq_cmd ( ex_rq_cmd ),
    .mem_rq_width ( ex_rq_width ),
    .mem_rq_start ( ex_rq_start ),
    .mem_rq_prepare_addr ( ex_rq_wr_addr ),
    .mem_t_id ( ex_rq_t_id ),
    .mem_data_t_wr ( ex_t_id_wr ),
    .mem_data_wr ( mem_writeback ),
    .id_sf_data ( sf_shared ),
    .id_sf_wr ( ex_sf_wr ),
    .fe_pc ( ex_pc ),
    .fe_pc_wr ( ex_pc_w ),
    .de_feed_req ( ex_feed_req )
);

lsu_16b lsu(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .rq_addr ( ex_rq_addr ),
    .rq_wr_addr ( ex_rq_wr_addr ),
    .rq_data ( ex_rq_data ),
    .rq_width ( ex_rq_width ),
    .rq_cmd ( ex_rq_cmd ),
    .rq_t_id ( ex_rq_t_id ),
    .rq_start ( ex_rq_start ),
    .mem_rdy ( d_mem_rdy ),
    .mem_addr ( d_mem_addr ),
    .mem_data ( d_mem_data_out ),
    .mem_cmd ( d_mem_cmd ),
    .be0 ( d_mem_be0 ),
    .be1 ( d_mem_be1 ),
    .mem_bus_assert ( d_mem_assert ),
    .t_id ( ex_t_id_wr ),
    .rq_ack ( ex_rq_ack )
);

endmodule