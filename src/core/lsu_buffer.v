
module lsu_buffer(
    input   wire        clk,
    
    //ALU Interface
    input   wire[15:0]  alu_adr,
    
    //Scheduler Interface
    input   wire[1:0]   sched_rd,
    input   wire        sched_slot,
    input   wire        sched_wr,
    
    //LSU Interface
    output  wire[15:0]  lsu_adr
);

/**
 * Statically Known Reservations
 * B[00]: original t16     (absolute address for interrupt vector)
 * B[01]: original address (RMW usage)
 * B[10]: reserved
 * B[11]: reserved
 */

reg[15:0] buffer[0:1];

reg[15:0] a;

always @(posedge clk) begin
    a <= sched_rd[1] ? alu_adr : buffer[ sched_rd[0] ];
    
    if ( sched_wr ) begin
        buffer[ sched_slot ] <= alu_adr;
    end
end

assign lsu_adr = a;

endmodule