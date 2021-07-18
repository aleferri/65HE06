
module core(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        evt_int,
    output  wire        evt_int_ack,
    input   wire[31:0]  i_mem_opcode,
    input   wire        i_mem_rdy,
    output  wire[15:0]  i_mem_pc,
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
    .i_mem_rdy ( i_mem_rdy ),
    .ex_pc_w ( ex_pc_w ),
    .ex_pc ( ex_pc ),
    .ex_feed_req ( ex_feed_req ),
    .ex_feed_ack ( ex_feed_ack ),
    .ex_sf ( ex_sf ),
    .ex_sf_wr ( ex_sf_wr ),
    .i_mem_pc ( i_mem_pc ),
    .ex_uop_0 ( ex_uop_0 ),
    .ex_uop_1 ( ex_uop_1 ),
    .ex_uop_2 ( ex_uop_2 ),
    .ex_uop_count ( ex_uop_count ),
    .ex_k ( ex_k )
);

scheduling_queue q(
    input   wire        clk,
    input   wire        a_rst,
    
    input   wire        id_feed,
    input   wire[31:0]  id_iop,
    input   wire[2:0]   id_iop_init,
    input   wire[15:0]  id_pc,
    input   wire[15:0]  id_k16,
    output  wire        id_ack,
    
    //RF during scheduling
    output  wire[2:0]   rf_a_adr,
    output  wire[2:0]   rf_b_adr,
    
    //ALU during execution
    output  wire[15:0]  alu_t16,
    output  wire        alu_wr_sf,
    output  wire        alu_carry_mask,
    output  wire[3:0]   alu_fn,
    output  wire        alu_bypass_b,
    
    //RF during execution
    output  wire[3:0]   rf_d_addr,
    
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
    input   wire        lsu_data_tag,
    input   wire        lsu_data_wb
);

regfile rf(
    input   wire        clk,
    
    //R Station Interface
    input   wire[2:0]   r_a_addr,
    input   wire[2:0]   r_b_addr,
    input   wire[15:0]  r_pc,
    
    //ALU interface
    input   wire[15:0]  alu_r,
    input   wire[15:0]  alu_flags,
    output  wire[15:0]  alu_a,
    output  wire[15:0]  alu_b,
    
    //ALU rmw interface
    input   wire[15:0]  rmw_flags,
    input   wire        rmw_w_flags,
    
    //Control Interface
    input   wire        dest_r_wr,
    input   wire[1:0]   dest_r_addr,
    input   wire        dest_w_flags,
    
    //Both ALU & ID
    output  wire[15:0]  flags
);

alu_rwm rmw(
    input   wire        clk,                // Clock
    input   wire        a_rst,              // Async reset
    
    input   wire[15:0]  agu_addr,           // AGU generated address
    
    input   wire        mem_rdy,            // Memory ready
    input   wire[15:0]  mem_data_in,        // Memory Data in
    
    input   wire[1:0]   sched_rmw_fn,       // Function to perform with the data
    input   wire        sched_rmw,          // Start RMW operation, in parallel with the load ack of LSU
    input   wire        sched_wr_flags,     // Write flags after operation
    input   wire        sched_carry_mask,   // Carry Mask
    
    input   wire[15:0]  rf_flags_in,        // Current flags
    output  wire        rf_flags_wr,        // Write flags
    output  wire[15:0]  rf_flags_out,       // Result flags from operation
    
    input   wire        lsu_ack,            // LSU accepted write request
    output  wire        lsu_deny_op,        // Deny any operations at the same address
    output  wire[15:0]  lsu_data,           // Modified data for LSU
    output  wire[15:0]  lsu_addr,           // Original address for LSU
    output  wire        lsu_data_rdy        // Modified data is ready
);

alu_16b alu(
    input   wire        carry_mask,
    input   wire[3:0]   alu_f,
    
    //Reg File interface
    input   wire[15:0]  rf_a,
    input   wire[15:0]  rf_b,
    output  wire[15:0]  rf_d,
    output  wire[15:0]  rf_sf,
    
    //Scheduler interface
    input   wire[15:0]  sched_t16,
    input   wire[15:0]  sched_agu_t16,
    input   wire        sched_bypass_b,
    input   wire        sched_zero_index,
    
    //Load Store Interface
    output  wire[15:0]  lsu_adr,
    output  wire[15:0]  lsu_payload
);

lsu_16b lsu(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .rq_addr ( ex_rq_addr ),
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
    .rq_ack ( ex_rq_ack )
);

endmodule