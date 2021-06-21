
module regfile(
    input   wire        clk,
    
    //R Station Interface
    input   wire[2:0]   r_a_addr,
    input   wire[2:0]   r_b_addr,
    input   wire[15:0]  r_pc,
    
    //ALU interface
    input   wire[15:0]  alu_r,
    input   wire[15:0]  alu_flags,
    output  wire[15:0]  alu_a,
    output  wire[15:0]  alu_b,
    
    //Control Interface
    input   wire        dest_r_wr,
    input   wire[1:0]   dest_r_addr,
    input   wire        dest_w_flags,
    output  wire        abort
);

wire conflict_a = (r_a_addr == dest_r_addr) & dest_r_wr;
wire conflict_b = (r_b_addr == dest_r_addr) & dest_r_wr;

wire is_a_pc = (r_a_addr == 3'b011);
wire is_b_pc = (r_b_addr == 3'b011);

reg[15:0] bank_a[0:7];
reg[15:0] bank_b[0:7];

reg[15:0] a;
reg[15:0] b;

reg[15:0] sf;
reg locked_flags;

always @(posedge clk) begin
    if ( dest_w_flags ) begin
        sf <= alu_flags;
        locked_flags <= 1'b1;
    end else begin
        locked_flags <= ~dest_r_wr;
        sf <= sf;
    end
end

always @(posedge clk) begin
    a <= is_a_pc ? pc : conflict_a ? alu_r : bank_a[r_a_addr];
    b <= is_b_pc ? pc : conflict_b ? alu_r : bank_b[r_b_addr];
    if ( dest_r_wr ) begin
        bank_a[ dest_r_addr ] <= alu_r;
        bank_b[ dest_r_addr ] <= alu_r;
    end else begin
        bank_a[ 3'b010 ] <= sf;
        bank_b[ 3'b010 ] <= sf;
    end
end

assign abort = locked_flags & ( (r_a_addr == 3'b010) | ( r_b_addr == 3'b010 ) );
assign alu_a = a;
assign alu_b = b;

endmodule