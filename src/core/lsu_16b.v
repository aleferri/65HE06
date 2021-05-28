module lsu_16b(
    input   wire        clk,
    input   wire        a_rst,
    input   wire[15:0]  rq_addr,
    input   wire        rq_wr_addr,
    input   wire[15:0]  rq_data,
    input   wire        rq_width,
    input   wire        rq_cmd,
    input   wire        rq_t_id,
    input   wire        rq_start,
    input   wire        mem_rdy,
    output  wire[15:0]  mem_addr,
    output  wire[15:0]  mem_data,
    output  wire        mem_cmd,
    output  wire        be0,
    output  wire        be1,
    output  wire        mem_bus_assert,
    output  wire        t_id,
    output  wire        rq_ack
);

reg[15:0] address;
reg[15:0] data;
reg command;
reg width;
reg rs_t_id;

reg busy;

wire next_busy = busy & ~mem_rdy | rq_start;
assign rq_ack = (busy & mem_rdy | ~busy) & rq_start;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        busy <= 1'b0;
    end else begin
        busy <= next_busy;
    end
end

always @(posedge clk) begin
    address <= (rq_ack & rq_wr_addr) ? rq_addr : address;
    data <= rq_ack ? rq_data : data;
    width <= rq_ack ? rq_width : width;
    command <= rq_ack ? rq_cmd : command;
    rs_t_id <= rq_ack ? rq_t_id : rs_t_id;
end

assign mem_addr = address;
assign mem_data = data;
assign mem_cmd = command;
assign be0 = ~mem_addr[0];
assign be1 = mem_addr[0] | ~mem_addr[0] & ~width;
assign mem_bus_assert = busy;
assign t_id = rs_t_id;

endmodule