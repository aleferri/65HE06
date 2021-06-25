
module alu_rwm(
    input   wire        clk,                // Clock
    input   wire        a_rst,              // Async reset
    
    input   wire[15:0]  agu_addr,           // AGU generated address
    
    input   wire        mem_rdy,            // Memory ready
    input   wire[15:0]  mem_data_in,        // Memory Data in
    
    input   wire[1:0]   sched_rmw_fn,       // Function to perform with the data
    input   wire        sched_rmw,          // Start RMW operation, in parallel with the load ack of LSU
    input   wire        sched_wr_flags,     // Write flags after operation
    input   wire        sched_carry_mask,   // Carry Mask
    
    input   wire        rf_flags_in,        // Current flags
    output  wire        rf_flags_wr,        // Write flags
    output  wire[15:0]  rf_flags_out,       // Result flags from operation
    
    input   wire        lsu_ack,            // LSU accepted write request
    output  wire        lsu_deny_op,        // Deny any operations at the same address
    output  wire[15:0]  lsu_data,           // Modified data for LSU
    output  wire[15:0]  lsu_addr,           // Original address for LSU
    output  wire        lsu_data_rdy        // Modified data is ready
);

// Sync Logic

reg rmw;
reg phase;

always @(posedge clk or posedge a_rst) begin
    if ( a_rst ) begin
        rmw = 1'b0;
        phase = 1'b0;
    end else begin
        if ( rmw ) begin
            rmw <= ~phase | ~lsu_ack;
            phase <= mem_rdy;
        end else begin
            rmw <= sched_rmw;
            phase <= 1'b0;
        end
    end
end

reg[15:0] addr;
reg[15:0] data;
reg[1:0] rmw_fn;
reg carry_mask;
reg wr_flags;

always @(posedge clk) begin
    data <= mem_rdy ? mem_data_in : data;
    addr <= r_rmw ? agu_addr : addr;
    rmw_fn <= r_rmw ? sched_rmw_fn : rmw_fn;
    wr_flags <= r_rmw ? sched_wr_flags : wr_flags;
    carry_mask <= r_rmw ? sched_carry_mask : carry_mask;
end

// Combinatory Logic

reg[15:0] result;
reg zero;
reg carry;
reg acquired;

wire was_zero = data == 16'b0;
wire carry_in = rf_flags_in[0] & carry_mask;

always @(*) begin
    case ( rmw_fn )
    //  INC
    2'b00: begin 
        carry = rf_flags_in[0];
        result = data + 1'b1;
        acquired = 1'b0;
    end
    //  DEP
    2'b01: begin
        carry = rf_flags_in[0];
        result = data - was_zero;
        acquired = ~was_zero;
    end
    //  LSR/ROR
    2'b10: { acquired, result, carry } = { 1'b0, carry_in, alu_b };
    //  ASL/ROL
    2'b11: { acquired, carry, result } = { 1'b0, alu_b, carry_in };
    endcase
    zero = result == 16'b0;
end

assign rf_flags_out = { rf_flags_in[15:5], acquired, rf_flags_in[3], rf_flags_in[2], zero, carry };
assign rf_flags_wr = wr_flags;
assign lsu_data = result;
assign lsu_addr = addr;
assign lsu_data_rdy = phase;
assign lsu_deny_op = ( addr == agu_addr ) & rmw;

endmodule