module scheduler(

    // R Station A interface
    input   wire        ra_lock_loads,       //lock loads
    input   wire[3:0]   ra_lock_reg_wr,      //lock register from being read
    input   wire[2:0]   ra_lock_reg_rd_0,    //lock register from being written
    input   wire[2:0]   ra_lock_reg_rd_1,    //lock register from being written
    input   wire[2:0]   ra_lock_reg_rd_2,    //lock register from being written
    
    input   wire[2:0]   ra_a_adr,
    input   wire[2:0]   ra_b_adr,
    input   wire[3:0]   ra_d_adr,
    input   wire        ra_ld_mem,
    input   wire        ra_st_mem,
    
    input   wire        ra_ready,
    input   wire        ra_order,
    input   wire        ra_will_complete,
    
    // R Station B interface
    input   wire        rb_lock_loads,       //lock loads
    input   wire[3:0]   rb_lock_reg_wr,      //lock register from being read
    input   wire[2:0]   rb_lock_reg_rd_0,    //lock register from being written
    input   wire[2:0]   rb_lock_reg_rd_1,    //lock register from being written
    input   wire[2:0]   rb_lock_reg_rd_2,    //lock register from being written
    
    input   wire[2:0]   rb_a_adr,
    input   wire[2:0]   rb_b_adr,
    input   wire[3:0]   rb_d_adr,
    input   wire        rb_ld_mem,
    input   wire        rb_st_mem,
    
    input   wire        rb_ready,
    input   wire        rb_order,
    input   wire        rb_will_complete,
    
    // Scheduler Interface
    output  wire        sched_next,
    output  wire        sched_order_ra,
    output  wire        sched_order_rb
);

wire ra_no_conflict_mem = ~ra_ld_mem | ra_ld_mem & ~rb_lock_loads & ~ra_st_mem;
wire ra_no_conflict_d = ~ra_d_adr[3] | ra_d_adr[3] & ( ra_d_adr[2:0] != rb_lock_reg_rd_0 ) & ( ra_d_adr[2:0] != rb_lock_reg_rd_1 ) & ( ra_d_adr[2:0] != rb_lock_reg_rd_2 );
wire ra_no_conflict_a = (ra_a_adr != rb_lock_wr);
wire ra_no_conflict_b = (ra_b_adr != rb_lock_wr);
wire ra_sched = ~ra_order | ra_order & ra_ready & ~rb_ready & ra_no_conflict_mem & ra_no_conflict_d & ra_no_conflict_a & ra_no_conflict_b;

wire rb_no_conflict_mem = ~rb_ld_mem | rb_ld_mem & ~ra_lock_loads & ~rb_st_mem;
wire rb_no_conflict_d = ~rb_d_adr[3] | rb_d_adr[3] & ( rb_d_adr[2:0] != ra_lock_reg_rd_0 ) & ( rb_d_adr[2:0] != ra_lock_reg_rd_1 ) & ( rb_d_adr[2:0] != ra_lock_reg_rd_2 );
wire rb_no_conflict_a = (rb_a_adr != ra_lock_wr);
wire rb_no_conflict_b = (rb_b_adr != ra_lock_wr);
wire rb_sched = ~rb_order | rb_order & rb_ready & ~ra_ready & rb_no_conflict_mem & rb_no_conflict_d & rb_no_conflict_a & rb_no_conflict_b;

assign sched_next = ~ra_sched | rb_sched;
assign sched_order_ra = ra_order ^ ( ra_will_complete & ra_sched | rb_will_complete & rb_sched );
assign sched_order_rb = rb_order ^ ( ra_will_complete & ra_sched | rb_will_complete & rb_sched );

endmodule