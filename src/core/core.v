
module core(
    input   wire        clk,
    input   wire        a_rst,

    input   wire        evt_rst,
    input   wire        evt_nmi,
    output  wire        evt_nmi_ack,
    input   wire        evt_irq,
    output  wire        evt_irq_ack,

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
wire [15:0] ex_pc;

wire ex_feed_slot;

wire id_feed;
wire [31:0] id_iop;
wire [2:0] id_iop_init;
wire [15:0] id_arg;

wire [15:0] ex_rq_addr;
wire [15:0] ex_rq_data;
wire ex_rq_width;
wire ex_rq_cmd;
wire ex_rq_hold;
wire [1:0] ex_rq_tag;
wire ex_rq_start;

wire [15:0] sf;
wire ex_sf_wr;

front_end front(
    .clk ( clk ),
    .a_rst ( a_rst ),

    .evt_rst ( evt_rst ),
    .evt_nmi ( evt_nmi ),
    .evt_nmi_ack ( evt_nmi_ack ),
    .evt_irq ( evt_irq ),
    .evt_irq_ack ( evt_irq_ack ),

    .i_mem_opcode ( i_mem_opcode ),
    .i_mem_rdy ( i_mem_rdy ),

    .ex_pc_w ( ex_pc_w ),
    .ex_pc ( ex_pc ),
    .ex_feed_slot ( ex_feed_slot ),
    .id_feed_req ( id_feed ),
    .ex_sf ( sf[7:0] ),
    .ex_sf_wr ( ex_sf_wr ),

    .i_mem_pc ( i_mem_pc ),
    
    .id_iop ( id_iop ),
    .id_iop_init ( id_iop_init ),
    .id_arg ( id_arg )
);

// Comb because verilog is stupid

reg [2:0] flags_id_next;

always @(*) begin
    flags_id_next = flags_id + ( id_iop[21] & id_feed );
end

// Sync

reg [2:0] flags_id; // flags renaming

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        flags_id <= 3'b000;
    end else begin
        flags_id <= flags_id_next;
    end
end

wire [2:0] rf_a_adr;
wire [2:0] rf_b_adr;
wire [15:0] rf_pc;
wire [3:0] rf_d_adr;

wire [15:0] alu_t16;
wire [2:0] alu_tag;
wire alu_sf_wr;
wire alu_carry_mask;
wire [3:0] alu_fn;
wire alu_bypass_b;

wire rmw_offload;
wire conflict_sf;

wire [15:0] agu_offset;
wire agu_zero_index;

wire agu_mem_width;
wire agu_mem_cmd;
wire agu_src_tag;
wire agu_mem_req;
wire lsu_deny;
wire [1:0] lsu_result_tag;
wire lsu_wb;

wire [2:0] sf_rmw_tag;
wire [2:0] sf_alu_tag;

scheduling_queue q(
    .clk ( clk ),
    .a_rst ( a_rst ),

    // ID <=> Queue
    .id_feed      ( id_feed ),
    .id_iop       ( { id_iop[31:3], flags_id_next } ),
    .id_iop_init  ( id_iop_init ),
    .id_pc        ( i_mem_pc ),
    .id_k16       ( id_arg ),
    .id_req       ( ex_feed_slot ),
    
    //RF during scheduling
    .rf_a_adr ( rf_a_adr ),
    .rf_b_adr ( rf_b_adr ),
    .rf_pc    ( rf_pc ),
    
    //ALU during execution
    .alu_t16        ( alu_t16 ),
    .alu_sf_wr      ( alu_sf_wr ),
    .alu_sf_tag     ( sf_alu_tag ),
    .alu_carry_mask ( alu_carry_mask ),
    .alu_fn         ( alu_fn ),
    .alu_bypass_b   ( alu_bypass_b ),
    
    //RF during execution
    .sf_conflict ( conflict_sf ),
    .rf_d_adr    ( rf_d_adr ),
    
    //AGU interface
    .agu_zero_index ( agu_zero_index ),
    .agu_offset     ( agu_offset ),
    
    //LSU interface
    .rmw_offload  ( rmw_offload ),
    .lsu_rq_width ( agu_mem_width ),
    .lsu_rq_cmd   ( agu_mem_cmd ),
    .lsu_rq_tag   ( agu_src_tag ),
    .lsu_rq_start ( agu_mem_req ),
    .lsu_wait     ( lsu_deny ),
    
    //LSU interface after load
    .lsu_data_in  ( d_mem_data_in ),
    .lsu_data_tag ( lsu_result_tag ),
    .lsu_data_wb  ( lsu_wb )
);

wire sf_rmw_write;
wire [15:0] sf_rmw;
wire [15:0] sf_alu;

wire [15:0] rf_a;
wire [15:0] rf_b;
wire [15:0] alu_result;

regfile rf(
    .clk ( clk ),
    
    //R Station Interface
    .r_a_addr ( rf_a_adr ),
    .r_b_addr ( rf_b_adr ),
    .r_pc     ( rf_pc ),
    
    //ALU interface
    .alu_r  ( alu_result ),
    .alu_sf ( sf_alu     ),
    .alu_a  ( rf_a       ),
    .alu_b  ( rf_b       ),
    
    //ALU rmw interface
    .rmw_sf   ( sf_rmw ),
    .rmw_sf_w ( sf_rmw_write ),
    
    //Control Interface
    .alu_d_wr  ( rf_d_adr[3] ),
    .alu_d_adr ( rf_d_adr[2:0] ),
    .alu_sf_wr ( alu_sf_wr & ~rmw_offload ),
    .conflict_sf ( conflict_sf ),
    
    //Both ALU & ID
    .flags ( sf )
);

assign ex_pc_w = rf_d_adr == 4'b1011;
assign ex_pc = alu_result;

wire [1:0] rmw_fn = { alu_fn[3] & alu_fn[1], alu_fn[0] };
wire rmw_start = rmw_offload & ~ex_rq_hold;

assign ex_sf_wr = sf_rmw_write & ( sf_rmw_tag == flags_id ) | ~sf_rmw_write & alu_sf_wr & ~rmw_offload & ( sf_alu_tag == flags_id );

wire [15:0] agu_addr;
wire [15:0] rmw_addr;

wire [15:0] agu_data;
wire [15:0] rmw_data;
wire rmw_data_rdy;
wire rmw_deny_addr;

alu_rwm rmw(
    .clk ( clk ),
    .a_rst ( a_rst ),
    
    .agu_addr ( agu_addr ),                 // AGU generated address
    
    .mem_rdy ( d_mem_rdy ),                 // Memory ready
    .mem_data_in ( d_mem_data_in ),         // Memory Data in
    
    .sched_rmw_fn ( rmw_fn ),               // Function to perform with the data
    .sched_rmw ( rmw_start ),               // Start RMW operation, in parallel with the load ack of LSU
    .sched_flags_wr ( alu_sf_wr ),          // Write flags after operation
    .sched_flags_tag ( sf_alu_tag ),
    .sched_carry_mask ( alu_carry_mask ),   // Carry Mask
    
    .rf_flags_in ( sf ),                    // Current flags
    .rf_flags_wr ( sf_rmw_write ),          // Write flags
    .rf_flags_out ( sf_rmw ),               // Result flags from operation
    .rf_flags_tag ( sf_rmw_tag ),
    
    .lsu_hold ( ex_rq_hold ),               // LSU accepted write request
    .lsu_deny_op ( rmw_deny_addr ),         // Deny any operations at the same address
    .lsu_data ( rmw_data ),                 // Modified data for LSU
    .lsu_addr ( rmw_addr ),                 // Original address for LSU
    .lsu_data_rdy ( rmw_data_rdy )          // Modified data is ready
);

alu_16b alu(
    .carry_mask ( alu_carry_mask ),
    .alu_f      ( alu_fn ),
    
    //Reg File interface
    .rf_sf   ( sf ),
    .rf_a    ( rf_a ),
    .rf_b    ( rf_b ),
    .rf_d    ( alu_result ),
    .rf_sf_n ( sf_alu ),
    
    //Scheduler interface
    .sched_t16          ( alu_t16 ),
    .sched_agu_t16      ( agu_offset ),
    .sched_bypass_b     ( alu_bypass_b ),
    .sched_zero_index   ( agu_zero_index ),
    
    //Load Store Interface
    .lsu_adr     ( agu_addr ),
    .lsu_payload ( agu_data )
);

assign ex_rq_addr = rmw_data_rdy ? rmw_addr : agu_addr;
assign ex_rq_start = rmw_data_rdy | agu_mem_req & ~rmw_deny_addr;
assign ex_rq_data = rmw_data_rdy ? rmw_data : agu_data;
assign ex_rq_width = rmw_data_rdy ? 1'b0 : agu_mem_width;
assign ex_rq_cmd = rmw_data_rdy ? 1'b1 : agu_mem_cmd;
assign ex_rq_tag = rmw_data_rdy ? 2'b11 : { 1'b0, agu_src_tag }; 
assign lsu_deny = ex_rq_hold | rmw_deny_addr;

lsu_16b lsu(
    .clk        ( clk ),
    .a_rst      ( a_rst ),
    
    .rq_addr    ( ex_rq_addr ),
    .rq_data    ( ex_rq_data ),
    .rq_width   ( ex_rq_width ),
    .rq_cmd     ( ex_rq_cmd ),
    .rq_tag     ( ex_rq_tag ),
    .rq_start   ( ex_rq_start ),
    .rq_hold    ( ex_rq_hold ),
    
    .mem_rdy    ( d_mem_rdy ),
    .mem_addr   ( d_mem_addr ),
    .mem_data   ( d_mem_data_out ),
    .mem_cmd    ( d_mem_cmd ),
    .mem_assert ( d_mem_assert ),
    .be0        ( d_mem_be0 ),
    .be1        ( d_mem_be1 ),
    
    .rs_tag     ( lsu_result_tag ),
    .rs_wb      ( lsu_wb )
);

endmodule