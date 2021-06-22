module alu_16b(
    input   wire        clk,
    input   wire        carry_mask,
    input   wire[3:0]   alu_f,
    
    //Reg File interface
    input   wire[15:0]  rf_a,
    input   wire[15:0]  rf_b,
    output  wire[15:0]  rf_d,
    output  wire[15:0]  rf_sf,
    
    //Scheduler interface
    input   wire[15:0]  sched_t16,
    input   wire        sched_bypass_b,
    
    //Load Store Interface
    output  wire[15:0]  lsu_adr,
    output  wire[15:0]  lsu_payload
);
/**
 * This reworked ALU is stateless
 * - it generates address from rf_a and t16
 * - it generates result from rf_a and (t16 or rf_b), the result is also the payload for LSU if a memory transfer is requested
 * 
 **/


wire is_sub = ~alu_f[3] & ~alu_f[2] & alu_f[1] & ~alu_f[0];
wire is_dep = ~alu_f[3] & ~alu_f[2] & alu_f[1] & alu_f[0];
wire has_v = ~alu_f[3] & ~alu_f[2];

reg[15:0] result_val;
reg[15:0] address_val;
reg carry;
reg overflow;
reg zero;
reg negative;
reg acquired;

wire carry_in = sf[0] & carry_mask;
wire not_carry_in = ~carry_in;

wire[15:0] alu_a = rf_a;
wire[15:0] alu_b = sched_bypass_b ? sched_t16 : rf_b;
wire[15:0] not_b = ~alu_b;
wire[15:0] agu_a = rf_a;
wire[15:0] agu_b = sched_t16;

wire was_zero = ~(alu_b == 16'b0);

always @(*) begin
    case(alu_f)
    //  ADD/ADC
    4'b0000: { carry, result_val } = alu_a + alu_b + carry_in;
    //  INC
    4'b0001: { carry, result_val } = alu_b + 1'b1;
    //  SUB/SBC
    4'b0010: { carry, result_val } = alu_a + not_b + not_carry_in;
    //  DEP
    4'b0011: { carry, result_val } = alu_b - was_zero;
    //  AND
    4'b0100: { carry, result_val } = { 1'b0, alu_a & alu_b };
    //  ORA
    4'b0101: { carry, result_val } = { 1'b0, alu_a | alu_b };
    //  EOR
    4'b0110: { carry, result_val } = { 1'b0, alu_a ^ alu_b };
    //  LDA
    4'b0111: { carry, result_val } = { 1'b0, alu_b };
    //  EXT (Sign Ext 8 -> 16)
    4'b1000: { carry, result_val } = { 1'b0, alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b };
    //  BSW (Bytes SWap)
    4'b1001: { carry, result_val } = { 1'b0, alu_b[3:0], alu_b[7:4] };
    //  LSR/ROR
    4'b1010: { result_val, carry } = { carry_in, alu_b };
    //  ASL/ROL
    4'b1011: { carry, result_val } = { alu_b, carry_in };
    //  LDZ
    4'b1100: { result_val, carry } = 17'b0;
    //  LDZ
    4'b1101: { result_val, carry } = 17'b0;
    //  LDZ
    4'b1110: { result_val, carry } = 17'b0;
    //  LDZ
    4'b1111: { result_val, carry } = 17'b0;
    endcase
    overflow = has_v & ( result_val[15] & ~alu_a[15] & ( ~alu_b[15] ^ is_sub) | ~result_val[15] & alu_a[15] & (alu_b[15] ^ is_sub) );
    zero = ( result_val == 0 );
    negative = result_val[15];
    acquired = ~zero_before & is_dep;
    address_val = agu_a + agu_b;
end
    
assign rf_sf = { 11'b0, acquired, negative, zero, overflow, carry };
assign rf_d = result_val;
assign lsu_payload = result_val;
assign lsu_adr = address_val;

endmodule
