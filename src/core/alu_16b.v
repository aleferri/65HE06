
module alu_16b(
    input   wire        clk,
    input   wire        carry_mask,
    input   wire[3:0]   alu_f,
    input   wire[2:0]   a_idx,
    input   wire[2:0]   b_idx,
    input   wire[2:0]   d_idx,
    input   wire        wr_reg,
    input   wire        wr_flags,
    input   wire[15:0]  t16,
    input   wire        sel_inp,
    output  wire[15:0]  flags,
    output  wire[15:0]  d_val,
    output  wire[15:0]  mar_val,
    output  wire[15:0]  mem_data,
    output  wire        wr_pc
);

reg[15:0] bank_a[0:7];
reg[15:0] bank_b[0:7];

reg[15:0] sf;

wire is_sub = ~alu_f[3] & ~alu_f[2] & alu_f[1] & ~alu_f[0];
wire is_dep = ~alu_f[3] & ~alu_f[2] & alu_f[1] & alu_f[0];
wire has_v = ~alu_f[3] & ~alu_f[2];

reg[15:0] result_val;
reg[15:0] result_flags;
reg[15:0] address_val;
reg[15:0] a_val;
reg[15:0] b_val;
reg[15:0] sel_val;
reg carry;
reg overflow;
reg zero;
reg negative;
reg zero_before;
reg carry_in;
reg acquired;

always @(*) begin
    a_val = bank_a[a_idx];
    b_val = bank_b[b_idx];
    sel_val = sel_inp ? b_val : t16;
    zero_before = b_val == 16'b0;
    carry_in = ( sf[0] ^ is_sub ) & ~carry_mask;
    case(alu_f)
    //  ADD/ADC
    4'b0000: { carry, result_val } = a_val + sel_val + carry_in;
    //  INC
    4'b0001: { carry, result_val } = b_val + 1'b1;
    //  SUB/SBC
    4'b0010: { carry, result_val } = a_val + ~sel_val + carry_in;
    //  DEP
    4'b0011: { carry, result_val } = b_val - ~zero_before;
    //  AND
    4'b0100: { carry, result_val } = { 1'b0, a_val & sel_val };
    //  ORA
    4'b0101: { carry, result_val } = { 1'b0, a_val | sel_val };
    //  EOR
    4'b0110: { carry, result_val } = { 1'b0, a_val ^ sel_val };
    //  LDA
    4'b0111: { carry, result_val } = { 1'b0, b_val };
    //  EXT (Sign Ext 8 -> 16)
    4'b1000: { carry, result_val } = { 1'b0, sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val };
    //  BSW (Bytes SWap)
    4'b1001: { carry, result_val } = { 1'b0, sel_val[3:0], sel_val[7:4] };
    //  LSR/ROR
    4'b1010: { result_val, carry } = { carry_in, sel_val };
    //  ASL/ROL
    4'b1011: { carry, result_val } = { sel_val, carry_in };
    //  LDZ
    4'b1100: { result_val, carry } = 17'b0;
    //  LDZ
    4'b1101: { result_val, carry } = 17'b0;
    //  LDZ
    4'b1110: { result_val, carry } = 17'b0;
    //  LDZ
    4'b1111: { result_val, carry } = 17'b0;
    endcase
    overflow = has_v & ( result_val[15] & ~a_val[15] & ((~sel_val[15]) ^ is_sub) | ~result_val[15] & a_val[15] & (sel_val[15] ^ is_sub) );
    zero = result_val == 0;
    negative = result_val[15];
    acquired = ~zero_before & is_dep;
    result_flags = { acquired, negative, zero, overflow, carry };
    address_val = a_val + t16;
end

always @(posedge clk) begin
    if ( wr_reg ) begin
        bank_b[ d_idx ] = result_val;
        bank_a[ d_idx ] = result_val;
    end
end

always @(posedge clk) begin
    if ( wr_flags ) begin
        sf <= { 12'b0, result_flags };
    end else if ( (d_idx == 3'b010) & wr_reg ) begin
        sf <= result_val;
    end else begin
        sf <= sf;
    end
end
    
assign flags = sf;
assign d_val = result_val;
assign mem_data = b_val;
assign wr_pc = (d_idx == 3'b011) & wr_reg;
assign mar_val = address_val;

endmodule