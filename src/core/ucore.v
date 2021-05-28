
module ucore(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        hold,
    input   wire[19:0]  uop_0,
    input   wire[19:0]  uop_1,
    input   wire[19:0]  uop_2,
    input   wire[1:0]   uop_cnt,
    input   wire[15:0]  k16,
    input   wire[15:0]  mem_data_in,
    input   wire        mem_data_t_wr,
    input   wire        mem_data_wr,
    output  wire[15:0]  mem_rq_data,
    output  wire[15:0]  mem_rq_addr,
    output  wire        mem_rq_start,
    output  wire        mem_rq_width,
    output  wire        mem_rq_cmd,
    output  wire        mem_rq_prepare_addr,
    output  wire        mem_t_id,
    output  wire[15:0]  id_sf_data,
    output  wire        id_sf_wr,
    output  wire[15:0]  fe_pc,
    output  wire        fe_pc_wr,
    output  wire        de_feed_req,
    input   wire        de_feed_ack
);

wire rsa_feed_req;
wire rsb_feed_req;

wire rsa_feed_ack;
wire rsb_feed_ack;

wire[19:0] rsa_last;
wire[19:0] rsa_next;

wire[19:0] rsb_last;
wire[19:0] rsb_next;

wire[15:0] rsa_t16;
wire[15:0] rsb_t16;

wire sched_ack_rsa;
wire sched_ack_rsb;
wire sched_next;

wire wr_data_rsa = ~mem_data_t_wr & mem_data_wr;
wire wr_data_rsb = mem_data_t_wr & mem_data_wr;

wire main_sched;
wire main_next;
wire main_ex_mem;

wire is_a_valid;
wire is_b_valid;

wire[19:0] sched_uop;

assign sched_ack_rsa = ~sched_next;
assign sched_ack_rsb = sched_next;

assign de_feed_req = rsa_feed_req | rsb_feed_req;

assign rsa_feed_ack = rsa_feed_req & de_feed_ack & ( sched_ack_rsa | ~sched_ack_rsa & ~rsb_last );
assign rsb_feed_ack = rsb_feed_req & de_feed_ack & ~rsa_feed_ack;

r_station rsa(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .id_feed_req ( rsa_feed_req ),
    .id_feed_ack ( rsa_feed_ack ),
    .id_uop_0 ( uop_0 ),
    .id_uop_1 ( uop_1 ),
    .id_uop_2 ( uop_2 ),
    .id_uop_count ( uop_cnt ),
    .ex_uop_last ( rsa_last ),
    .ex_uop_next ( rsa_next ),
    .id_k16 ( k16 ),
    .mem_data_in ( mem_data_in ),
    .mem_data_wr ( wr_data_rsa ),
    .ex_sched_ack ( sched_ack_rsa ),
    .ex_data_out ( rsa_t16 ),
    .ex_is_valid ( is_a_valid )
);

r_station rsb(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .id_feed_req ( rsb_feed_req ),
    .id_feed_ack ( rsb_feed_ack ),
    .id_uop_0 ( uop_0 ),
    .id_uop_1 ( uop_1 ),
    .id_uop_2 ( uop_2 ),
    .id_uop_count ( uop_cnt ),
    .ex_uop_last ( rsb_last ),
    .ex_uop_next ( rsb_next ),
    .id_k16 ( k16 ),
    .mem_data_in ( mem_data_in ),
    .mem_data_wr ( wr_data_rsb ),
    .ex_sched_ack ( sched_ack_rsb ),
    .ex_data_out ( rsb_t16 ),
    .ex_is_valid ( is_b_valid )
);

scheduler sched(
    .uop_next_a ( rsa_next ),
    .uop_next_b ( rsb_next ),
    .uop_is_last_a ( rsa_feed_req ),
    .uop_is_last_b ( rsb_feed_req ),
    .is_a_valid ( is_a_valid ),
    .is_b_valid ( is_b_valid ),
    .uop_last_a ( rsa_last ),
    .uop_last_b ( rsb_last ),
    .main_sched ( main_sched ),
    .ex_doing_mem ( main_ex_mem ),
    .next_sched ( sched_next ),
    .next_main ( main_next ),
    .uop_next ( sched_uop )
);

wire[15:0] alu_t16;
wire[2:0] alu_a;
wire[2:0] alu_b;
wire[2:0] alu_d;
wire[3:0] alu_fn;
wire alu_mux_sel;

wire reg_wr;
wire wr_sf_flags;
wire wr_sf_result;
wire alu_allow_carry;
wire alu_write_back_addr;

uop_executing scheduled(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .stop ( hold ),
    .uop_next ( sched_uop ),
    .temp_a ( rsa_t16 ),
    .temp_b ( rsb_t16 ),
    .next_sched ( sched_next ),
    .next_main ( main_next ),
    .t16 ( alu_t16 ),
    .idx_a ( alu_a ),
    .idx_b ( alu_b ),
    .sel_inp ( alu_mux_sel ),
    .adr_wr_back ( alu_write_back_addr ),
    .idx_dest ( alu_d ),
    .alu_f ( alu_fn ),
    .carry_mask ( alu_allow_carry ),
    .flags_w ( wr_sf_flags ),
    .reg_wr ( reg_wr ),
    .mar_wr ( mem_rq_prepare_addr ),
    .mem_rq_width ( mem_rq_width ),
    .mem_rq_cmd ( mem_rq_cmd ),
    .mem_rq ( mem_rq_start ),
    .sched_main ( main_sched ),
    .main_ex_mem ( main_ex_mem ),
    .sched_now ( mem_t_id )
);

alu_16b main_alu(
    .clk ( clk ),
    .carry_mask ( alu_allow_carry ),
    .alu_f ( alu_fn ),
    .a_idx ( alu_a ),
    .b_idx ( alu_b ),
    .d_idx ( alu_d ),
    .wr_reg ( reg_wr ),
    .wr_flags ( wr_sf_flags ),
    .t16 ( alu_t16 ),
    .sel_inp ( alu_mux_sel ),
    .wr_back_addr ( alu_write_back_addr ),
    .flags ( id_sf_data ),
    .d_val ( fe_pc ),
    .mar_val ( mem_rq_addr ),
    .mem_data ( mem_rq_data ),
    .wr_pc ( fe_pc_wr )
);

assign id_sf_wr = wr_sf_flags | (alu_d == 4'b0010);

endmodule