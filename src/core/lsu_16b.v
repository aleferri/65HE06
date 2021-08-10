module lsu_16b(
    input   wire        clk,
    input   wire        a_rst,
    
    // Request interface
    input   wire[15:0]  rq_addr,    // Request memory address
    input   wire[15:0]  rq_data,    // Data to write
    input   wire        rq_width,   // Bus Width: 0: 16 bit, 1: 8 bit
    input   wire        rq_cmd,     // Command, 0: read, 1: write
    input   wire[1:0]   rq_tag,     // Tag of the request
    input   wire        rq_start,   // Start request with parameters
    output  wire        rq_hold,    // Hold any incoming request
    
    // Memory
    input   wire        mem_rdy,
    output  wire[15:0]  mem_addr,
    output  wire[15:0]  mem_data,
    output  wire        mem_cmd,
    output  wire        be0,
    output  wire        be1,
    output  wire        mem_assert,
    
    // Reservations Stations
    output  wire        rs_wb,
    output  wire[1:0]   rs_tag
);

reg[15:0] address;
reg[15:0] data;
reg command;
reg width;
reg[1:0] tag;

reg busy;

wire accept_rq = ( ~busy | mem_rdy ) & rq_start;
wire next_busy = busy & ~mem_rdy | rq_start;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        busy <= 1'b0;
    end else begin
        busy <= next_busy;
    end
end

always @(posedge clk) begin
    address <= accept_rq ? rq_addr : address;
    data <= accept_rq ? rq_data : data;
    width <= accept_rq ? rq_width : width;
    command <= accept_rq ? rq_cmd : command;
    tag <= accept_rq ? rq_tag : tag;
end

assign rq_hold = busy & ~mem_rdy;

assign mem_addr = address;
assign mem_data = data;
assign mem_cmd = command;
assign be0 = ~mem_addr[0];
assign be1 = mem_addr[0] | ~mem_addr[0] & ~width;
assign mem_assert = busy;
assign rs_tag = tag;
assign rs_wb = mem_rdy & mem_cmd;

endmodule