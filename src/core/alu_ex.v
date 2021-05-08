
module alu_ex(
    input   wire        clk,
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
    output  wire[15:0]  mem_data,
    output  wire        wr_pc
);

reg[15:0] reg_file[0:7];
reg[15:0] sf;

wire is_sub = ~alu_f[3] & ~alu_f[2] & alu_f[1];
wire has_v = ~alu_f[3] & ~alu_f[2];
wire is_cmp = is_sub & alu_f[0];
wire is_test = ~alu_f[3] & alu_f[2] & alu_f[1] & alu_f[0];

reg[15:0] result_val;
reg[15:0] result_flags;
reg[15:0] a_val;
reg[15:0] b_val;
reg[15:0] sel_val;
reg carry;
reg overflow;
reg zero;
reg negative;

always @(*) begin
    a_val = reg_file[a_idx];
    b_val = reg_file[b_idx];
    sel_val = sel_inp ? t16 : b_val;
    case(alu_f)
    4'b0000: { carry, result_val } = a_val + sel_val;
    4'b0001: { carry, result_val } = { 1'b0, sel_val };
    4'b0010: { carry, result_val } = a_val - sel_val;
    4'b0011: { carry, result_val } = a_val - sel_val;
    4'b0100: { carry, result_val } = { 1'b0, a_val & sel_val };
    4'b0101: { carry, result_val } = { 1'b0, a_val | sel_val };
    4'b0110: { carry, result_val } = { 1'b0, a_val ^ sel_val };
    4'b0111: { carry, result_val } = { 1'b0, a_val & sel_val };
    4'b1000: { carry, result_val } = { 1'b0, sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val[7], sel_val };
    4'b1001: { carry, result_val } = { 1'b0, sel_val[3:0], sel_val[7:4] };
    4'b1010: { result_val, carry } = { 1'b0, sel_val };
    4'b1011: { carry, result_val } = { sel_val, 1'b0 };
    4'b1100: { result_val, carry } = 17'b0;
    4'b1101: { result_val, carry } = 17'b0;
    4'b1110: { result_val, carry } = 17'b0;
    4'b1111: { result_val, carry } = 17'b0;
    end
    overflow = has_v & ( result_val[15] & ~a_val[15] & ((~sel_val[15]) ^ is_sub) | ~result_val[15] & a_val[15] & (sel_val[15] ^ is_sub) );
    zero = result_val == 0;
    negative = result_val[15];
    result_flags = { negative, zero, overflow, carry };
end

always @(posedge clk) begin
    if ( is_cmp | is_test | ~wr_reg ) begin
        reg_file[ d_idx ] = reg_file[ d_idx ];
    end else begin
        reg_file[ d_idx ] = result_val;
    end
end

always @(posedge clk) begin
    if ( wr_flags ) begin
        sf <= { 12'b0, result_flags };
    end else if ( (d_idx == 3'b010) & wr_reg & ~is_cmp & ~is_test ) begin
        sf <= result_val;
    end else begin
        sf <= sf;
    end
end
    
assign flags = sf;
assign d_val = result_val;
assign mem_data = b_val;
assign wr_pc = (d_idx == 3'b011) & wr_reg & ~is_cmp & ~is_test;

endmodule