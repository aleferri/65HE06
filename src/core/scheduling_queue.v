
module scheduling_queue(
    input   wire        clk,
    input   wire        a_rst,
    
    input   wire        id_feed,
    input   wire[31:0]  id_iop,
    input   wire[2:0]   id_iop_init,
    input   wire[15:0]  id_pc,
    input   wire[15:0]  id_k16,
    output  wire        id_req,
    
    //RF during scheduling
    output  wire[2:0]   rf_a_adr,
    output  wire[2:0]   rf_b_adr,
    output  wire[15:0]  rf_pc,
    
    //ALU during execution
    output  wire[15:0]  alu_t16,
    output  wire        alu_sf_wr,
    output  wire[2:0]   alu_sf_tag,
    output  wire        alu_carry_mask,
    output  wire[3:0]   alu_fn,
    output  wire        alu_bypass_b,
    
    //RF during execution
    output  wire[3:0]   rf_d_adr,
    
    //AGU interface
    output  wire        agu_zero_index,
    output  wire[15:0]  agu_offset,
    
    //LSU interface
    output  wire        rmw_offload,
    output  wire        lsu_rq_width,
    output  wire        lsu_rq_cmd,
    output  wire        lsu_rq_tag,
    output  wire        lsu_rq_start,
    input   wire        lsu_wait,
    
    //LSU interface after load
    input   wire[15:0]  lsu_data_in,
    input   wire[1:0]   lsu_data_tag,
    input   wire        lsu_data_wb
);

reg rsa_order, rsb_order;
wire sched_rsa_order_next, sched_rsb_order_next;

always @(posedge clk or posedge a_rst) begin
    if ( a_rst ) begin
        rsa_order = 1'b0;
        rsb_order = 1'b0;
    end else begin
        rsa_order <= sched_rsa_order_next;
        rsb_order <= sched_rsb_order_next;
    end
end

wire rs_sched_adr;
wire is_rsa_done;
wire is_rsb_done;

wire rsa_ready;
wire rsb_ready;

wire rsa_will_complete;
wire rsb_will_complete;

wire[15:0] rsa_pc, rsb_pc;
wire[15:0] rsa_k16, rsb_k16;
wire[15:0] rsa_offset16, rsb_offset16;
wire[2:0] rsa_a_adr, rsb_a_adr;
wire[2:0] rsa_b_adr, rsb_b_adr;
wire[3:0] rsa_d_adr, rsb_d_adr;
wire[3:0] rsa_fn, rsb_fn;

wire rsa_mask_carry;
wire rsb_mask_carry;

wire rsa_mask_index;
wire rsa_save_flags;
wire rsa_start_rmw;
wire rsa_st_mem;
wire rsa_ld_mem;
wire rsa_mem_width;
wire rsa_bypass_b;
wire rsa_lock_loads;

wire rsb_mask_index;
wire rsb_save_flags;
wire rsb_start_rmw;
wire rsb_st_mem;
wire rsb_ld_mem;
wire rsb_mem_width;
wire rsb_bypass_b;
wire rsb_lock_loads;

wire[3:0] rsa_lock_reg_wr, rsb_lock_reg_wr;
wire[2:0] rsa_lock_reg_rd_0, rsb_lock_reg_rd_0;
wire[2:0] rsa_lock_reg_rd_1, rsb_lock_reg_rd_1;
wire[2:0] rsa_lock_reg_rd_2, rsb_lock_reg_rd_2;

wire[2:0] rsa_save_flags_tag, rsb_save_flags_tag;

assign id_req = is_rsa_done | is_rsb_done;

station rsa(
    .clk    ( clk ),
    .a_rst  ( a_rst ),
    
    //Instruction Decode Interface
    .id_feed ( id_feed & is_rsa_done ), 
    .id_iop ( id_iop ),
    .id_iop_init ( id_iop_init ),
    .id_pc ( id_pc ),
    .id_k16 ( id_k16 ),
    .id_complete ( is_rsa_done ),
    
    //LSU Interface
    .lsu_data ( lsu_data_in ),
    .lsu_wb ( lsu_data_wb & ~lsu_data_tag[1] & ~lsu_data_tag[0] ),
    
    //Scheduler Interface
    .r_ready ( rsa_ready ),
    .r_will_complete ( rsa_will_complete ),
    .r_pc ( rsa_pc ),
    .r_k16 ( rsa_k16 ),
    .r_agu_k16 ( rsa_offset16 ),
    .r_a_adr ( rsa_a_adr ),
    .r_b_adr ( rsa_b_adr ),
    .r_d_adr ( rsa_d_adr ),
    .r_fn ( rsa_fn ),
    .r_mask_carry ( rsa_mask_carry ),
    .r_mask_index ( rsa_mask_index ),
    .r_save_flags ( rsa_save_flags ),
    .r_save_flags_tag ( rsa_save_flags_tag ),
    .r_forward_to_rmw ( rsa_start_rmw ),
    .r_st_mem ( rsa_st_mem ),
    .r_ld_mem ( rsa_ld_mem ),
    .r_mem_width ( rsa_mem_width ),
    .r_bypass_b ( rsa_bypass_b ),
    .r_lock_loads ( rsa_lock_loads ),
    .r_lock_reg_wr ( rsa_lock_reg_wr ),
    .r_lock_reg_rd_0 ( rsa_lock_reg_rd_0 ),
    .r_lock_reg_rd_1 ( rsa_lock_reg_rd_1 ),
    .r_lock_reg_rd_2 ( rsa_lock_reg_rd_2 ),
    .sched_ack ( ~rs_sched_adr )
);

station rsb(
    .clk    ( clk ),
    .a_rst  ( a_rst ),
    
    //Instruction Decode Interface
    .id_feed ( id_feed & is_rsb_done & ~is_rsa_done ), 
    .id_iop ( id_iop ),
    .id_iop_init ( id_iop_init ),
    .id_pc ( id_pc ),
    .id_k16 ( id_k16 ),
    .id_complete ( is_rsb_done ),
    
    //LSU Interface
    .lsu_data ( lsu_data_in ),
    .lsu_wb ( lsu_data_wb & ~lsu_data_tag[1] & lsu_data_tag[0] ),
    
    //Scheduler Interface
    .r_ready ( rsb_ready ),
    .r_will_complete ( rsb_will_complete ),
    .r_pc ( rsb_pc ),
    .r_k16 ( rsb_k16 ),
    .r_agu_k16 ( rsb_offset16 ),
    .r_a_adr ( rsb_a_adr ),
    .r_b_adr ( rsb_b_adr ),
    .r_d_adr ( rsb_d_adr ),
    .r_fn ( rsb_fn ),
    .r_mask_carry ( rsb_mask_carry ),
    .r_mask_index ( rsb_mask_index ),
    .r_save_flags ( rsb_save_flags ),
    .r_save_flags_tag ( rsb_save_flags_tag ),
    .r_forward_to_rmw ( rsb_start_rmw ),
    .r_st_mem ( rsb_st_mem ),
    .r_ld_mem ( rsb_ld_mem ),
    .r_mem_width ( rsb_mem_width ),
    .r_bypass_b ( rsb_bypass_b ),
    .r_lock_loads ( rsb_lock_loads ),
    .r_lock_reg_wr ( rsb_lock_reg_wr ),
    .r_lock_reg_rd_0 ( rsb_lock_reg_rd_0 ),
    .r_lock_reg_rd_1 ( rsb_lock_reg_rd_1 ),
    .r_lock_reg_rd_2 ( rsb_lock_reg_rd_2 ),
    .sched_ack ( rs_sched_adr )
);

// Scheduler
wire rsa_no_conflict_mem = ~rsa_ld_mem | rsa_ld_mem & ~rsb_lock_loads & ~rsa_st_mem;
wire rsa_no_conflict_d = ~rsa_d_adr[3] | rsa_d_adr[3] & ( rsa_d_adr[2:0] != rsb_lock_reg_rd_0 ) & ( rsa_d_adr[2:0] != rsb_lock_reg_rd_1 ) & ( rsa_d_adr[2:0] != rsb_lock_reg_rd_2 );
wire rsa_no_conflict_a = (rsa_a_adr != rsb_lock_reg_wr);
wire rsa_no_conflict_b = (rsa_b_adr != rsb_lock_reg_wr);
wire rsa_no_conflict_sf = ~rsa_save_flags | rsa_save_flags & ~rsb_save_flags;
wire rsa_sched = ~rsa_order | rsa_order & rsa_ready & ~rsb_ready & rsa_no_conflict_mem & rsa_no_conflict_d & rsa_no_conflict_a & rsa_no_conflict_b & rsa_no_conflict_sf;

wire rsb_no_conflict_mem = ~rsb_ld_mem | rsb_ld_mem & ~rsa_lock_loads & ~rsb_st_mem;
wire rsb_no_conflict_d = ~rsb_d_adr[3] | rsb_d_adr[3] & ( rsb_d_adr[2:0] != rsa_lock_reg_rd_0 ) & ( rsb_d_adr[2:0] != rsa_lock_reg_rd_1 ) & ( rsb_d_adr[2:0] != rsa_lock_reg_rd_2 );
wire rsb_no_conflict_a = (rsb_a_adr != rsa_lock_reg_wr);
wire rsb_no_conflict_b = (rsb_b_adr != rsa_lock_reg_wr);
wire rsb_no_conflict_sf = ~rsb_save_flags | rsb_save_flags & ~rsa_save_flags;
wire rsb_sched = ~rsb_order | rsb_order & rsb_ready & ~rsa_ready & rsb_no_conflict_mem & rsb_no_conflict_d & rsb_no_conflict_a & rsb_no_conflict_b & rsb_no_conflict_sf;

assign rs_sched_adr = ~rsa_sched | rsb_sched;
assign sched_rsa_order_next = rsa_order ^ ( rsa_will_complete & rsa_sched | rsb_will_complete & rsb_sched );
assign sched_rsb_order_next = ~sched_rsa_order_next;

assign rf_a_adr = rs_sched_adr ? rsb_a_adr : rsa_a_adr;
assign rf_b_adr = rs_sched_adr ? rsb_b_adr : rsa_b_adr;
assign rf_pc = rs_sched_adr ? rsb_pc : rsa_pc;

// Muxes
wire r_ready = rs_sched_adr ? rsb_ready : rsa_ready;
wire[15:0] r_alu_t16 = rs_sched_adr ? rsb_k16 : rsa_k16;
wire r_alu_sf_wr = rs_sched_adr ? rsb_save_flags : rsa_save_flags;
wire[2:0] r_sf_tag = rs_sched_adr ? rsb_save_flags_tag : rsa_save_flags_tag;
wire r_alu_carry_mask = rs_sched_adr ? rsb_mask_carry : rsa_mask_carry;
wire[3:0] r_alu_fn = rs_sched_adr ? rsb_fn : rsa_fn;
wire r_alu_bypass_b = rs_sched_adr ? rsb_bypass_b : rsa_bypass_b;
    
wire[3:0] r_d_adr = rs_sched_adr ? rsb_d_adr : rsa_d_adr;
    
wire r_agu_zero_index = rs_sched_adr ? rsb_mask_index : rsa_mask_index;
wire[15:0] r_agu_offset = rs_sched_adr ? rsb_offset16 : rsa_offset16;
    
wire r_rmw_offload = rs_sched_adr ? rsb_start_rmw : rsa_start_rmw;
    
wire r_lsu_width = rs_sched_adr ? rsb_mem_width : rsa_mem_width;
wire r_lsu_st_mem = rs_sched_adr ? rsb_st_mem : rsa_st_mem;
wire r_lsu_ld_mem = rs_sched_adr ? rsb_ld_mem : rsa_ld_mem;
wire r_lsu_tag = rs_sched_adr;

// Scheduled part
reg[20:0] front;
reg[15:0] front_k16;
reg[15:0] front_offset16;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        front = 18'b0;
    end else begin
        front = lsu_wait ? front : { r_sf_tag, r_ready, r_alu_sf_wr, r_alu_carry_mask, r_alu_fn, r_alu_bypass_b, r_d_adr, r_agu_zero_index, r_rmw_offload, r_lsu_width, r_lsu_st_mem, r_lsu_ld_mem, r_lsu_tag };
    end
end

always @(posedge clk) begin
    front_k16 <= lsu_wait ? front_k16 : r_alu_t16;
    front_offset16 <= lsu_wait ? front_offset16 : r_agu_offset;
end

assign alu_t16 = front_k16;
assign alu_sf_wr = front[ 16 ] & front[ 17 ] & ~lsu_wait & ~front[ 4 ];
assign alu_sf_tag = front[20:18];
assign alu_carry_mask = front[ 15 ];
assign alu_fn = front[14:11];
assign alu_bypass_b = front[10];

assign rf_d_adr = { ~front[17] | front[9], ~front[ 17 ] | front[8], front[ 7:6 ] };

assign agu_zero_index = front[ 5 ];
assign agu_offset = front_offset16;

assign rmw_offload = front[ 4 ];
assign lsu_rq_width = front[ 3 ];
assign lsu_rq_cmd = front[ 2 ];
assign lsu_rq_tag = front[ 0 ];
assign lsu_rq_start = front[ 2 ] | front[ 1 ];

endmodule