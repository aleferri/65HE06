
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
    
    //ALU rmw interface
    input   wire[15:0]  rmw_flags,
    input   wire        rmw_w_flags,
    
    //Control Interface
    input   wire        dest_r_wr,
    input   wire[1:0]   dest_r_addr,
    input   wire        dest_w_flags,
    
    //Both ALU & ID
    output  wire[15:0]  flags
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

always @(posedge clk) begin
    case ( { rmw_w_flags, dest_w_flags } )
    2'b00: sf <= sf;
    2'b01: sf <= alu_flags;
    2'b10: sf <= rmw_flags;
    2'b11: sf <= rmw_flags;
    endcase
end

always @(posedge clk) begin
    a <= is_a_pc ? r_pc : conflict_a ? alu_r : bank_a[r_a_addr];
    b <= is_b_pc ? r_pc : conflict_b ? alu_r : bank_b[r_b_addr];
    if ( dest_r_wr ) begin
        bank_a[ dest_r_addr ] <= alu_r;
        bank_b[ dest_r_addr ] <= alu_r;
    end
end

assign alu_a = a;
assign alu_b = b;
assign flags = sf;

endmodule