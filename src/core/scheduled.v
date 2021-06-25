module scheduled(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        lsu_wait,
    
    input   wire        r_ready,
    input   wire[15:0]  r_alu_t16,
    input   wire        r_alu_wr_sf,
    input   wire        r_alu_carry_mask,
    input   wire[3:0]   r_alu_fn,
    input   wire        r_alu_bypass_b,
    
    input   wire[3:0]   r_rf_d_addr,
    
    input   wire        r_agu_zero_index,
    input   wire[15:0]  r_agu_offset,
    
    input   wire        r_rmw_offload,
    
    input   wire        r_lsu_width,
    input   wire        r_lsu_st_mem,
    input   wire        r_lsu_ld_mem,
    input   wire        r_lsu_tag,
    
    output  wire[15:0]  alu_t16,
    output  wire        alu_wr_sf,
    output  wire        alu_carry_mask,
    output  wire[3:0]   alu_fn,
    output  wire        alu_bypass_b,
    
    output  wire[3:0]   rf_d_addr,
    
    output  wire        agu_zero_index,
    output  wire[15:0]  agu_offset,
    
    output  wire        rmw_offload,
    output  wire        lsu_rq_width,
    output  wire        lsu_rq_cmd,
    output  wire        lsu_rq_tag,
    output  wire        lsu_rq_start
);

reg[17:0] scheduled_op;
reg[15:0] k16;
reg[15:0] offset16;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        scheduled_op = 18'b0;
    end else begin
        scheduled_op = lsu_wait ? scheduled_op : { r_ready, r_alu_wr_sf, r_alu_carry_mask, r_alu_fn, r_alu_bypass_b, r_rf_d_addr, r_agu_zero_index, r_rmw_offload, r_lsu_width, r_lsu_st_mem, r_lsu_ld_mem, r_lsu_tag };
    end
end

always @(posedge clk) begin
    k16 <= lsu_wait ? k16 : r_alu_t16;
    offset16 <= lsu_wait ? offset16 : r_agu_offset;
end

assign alu_t16 = k16;
assign alu_wr_sf = scheduled_op[ 16 ] & scheduled_op[ 17 ] & ~lsu_wait & ~scheduled_op[ 4 ];
assign alu_carry_mask = scheduled_op[ 15 ];
assign alu_fn = scheduled_op[14:11];
assign alu_bypass_b = scheduled_op[10];

assign rf_d_addr = { ~scheduled_op[17] | scheduled_op[9], ~scheduled_op[ 17 ] | scheduled_op[8], scheduled_op[ 7:6 ] };

assign agu_zero_index = scheduled_op[ 5 ];
assign agu_offset = offset16;

assign rmw_offload = scheduled_op[ 4 ];
assign lsu_rq_width = scheduled_op[ 3 ];
assign lsu_rq_cmd = scheduled_op[ 2 ];
assign lsu_rq_tag = scheduled_op[ 0 ];
assign lsu_rq_start = scheduled_op[ 2 ] | scheduled_op[ 1 ];

endmodule