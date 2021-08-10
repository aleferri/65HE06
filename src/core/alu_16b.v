module alu_16b(
    input   wire        carry_mask,
    input   wire[3:0]   alu_f,
    
    //Reg File interface
    input   wire[15:0]  rf_sf,
    input   wire[15:0]  rf_a,
    input   wire[15:0]  rf_b,
    output  wire[15:0]  rf_d,
    output  wire[15:0]  rf_sf_n,
    
    //Scheduler interface
    input   wire[15:0]  sched_t16,
    input   wire[15:0]  sched_agu_t16,
    input   wire        sched_bypass_b,
    input   wire        sched_zero_index,
    
    //Load Store Interface
    output  wire[15:0]  lsu_adr,
    output  wire[15:0]  lsu_payload
);
/**
 * This reworked ALU is stateless
 * - it generates address from rf_a and agu_t16
 * - it generates result from rf_a and (t16 or rf_b)
 * - rf_b is also the payload for LSU if a memory transfer is requested
 * 
 **/

wire has_v = ~alu_f[3] & ~alu_f[2];

reg [15:0] result_val;
reg [15:0] address_val;

reg [11:0] flags_high;
reg carry;
reg overflow;
reg zero;
reg negative;
reg acquired;

wire carry_in = rf_sf[0] & carry_mask;
wire not_carry_in = ~carry_in;

wire[15:0] alu_a = rf_a;
wire[15:0] alu_b = sched_bypass_b ? sched_t16 : rf_b;
wire[15:0] not_b = ~alu_b;
wire[15:0] agu_a = sched_zero_index ? 16'b0 : rf_a;
wire[15:0] agu_b = sched_agu_t16;

wire was_zero = ~(alu_b == 16'b0);

always @(*) begin
    case(alu_f)
    //  ADD/ADC
    4'b0000: begin 
        { carry, result_val } = alu_a + alu_b + carry_in;
        overflow = has_v & ( result_val[15] & ~alu_a[15] & ~alu_b[15] | ~result_val[15] & alu_a[15] & alu_b[15] );
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  INC
    4'b0001: begin 
        result_val = alu_b + 1'b1;
        carry = rf_sf[0];
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  SUB/SBC
    4'b0010: begin 
        { carry, result_val } = alu_a + not_b + not_carry_in;
        overflow = has_v & ( result_val[15] & ~alu_a[15] & alu_b[15] | ~result_val[15] & alu_a[15] & ~alu_b[15] );
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  DEP
    4'b0011: begin 
        result_val = alu_b - was_zero;
        carry = rf_sf[0];
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = ~was_zero;
        flags_high = 11'b0;
    end
    //  AND
    4'b0100: begin 
        { carry, result_val } = { rf_sf[0], alu_a & alu_b };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  ORA
    4'b0101: begin 
        { carry, result_val } = { rf_sf[0], alu_a | alu_b };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  EOR
    4'b0110: begin 
        { carry, result_val } = { rf_sf[0], alu_a ^ alu_b };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  LDA
    4'b0111: begin 
        { carry, result_val } = { rf_sf[0], alu_b };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  EXT (Sign Ext 8 -> 16)
    4'b1000: begin 
        { carry, result_val } = { rf_sf[0], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b[7], alu_b };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  BSW (Bytes SWap)
    4'b1001: begin 
        { carry, result_val } = { 1'b0, alu_b[3:0], alu_b[7:4] };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = result_val[15];
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  LSR/ROR
    4'b1010: begin 
        { result_val, carry } = { carry_in, alu_b };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = 1'b0;
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  ASL/ROL
    4'b1011: begin 
        { result_val, carry } = { alu_b, carry_in };
        overflow = rf_sf[1];
        zero = ( result_val == 0 );
        negative = 1'b0;
        acquired = 1'b0;
        flags_high = 11'b0;
    end
    //  LDZ
    4'b1100: { result_val, flags_high, acquired, negative, zero, overflow, carry } = 32'b0;
    //  LDZ
    4'b1101: { result_val, flags_high, acquired, negative, zero, overflow, carry } = 32'b0;
    //  LDF
    4'b1110: { result_val, flags_high, acquired, negative, zero, overflow, carry } = { rf_sf, rf_sf };
    //  STF
    4'b1111: { result_val, flags_high, acquired, negative, zero, overflow, carry } = { alu_a, alu_a };
    endcase
    
    address_val = agu_a + agu_b;
end
    
assign rf_sf_n = { flags_high, acquired, negative, zero, overflow, carry };
assign rf_d = result_val;
assign lsu_payload = rf_b;
assign lsu_adr = address_val;

endmodule
