
module regfile(
    input   wire        clk,
    
    //R Station Interface
    input   wire[2:0]   r_a_addr,
    input   wire[2:0]   r_b_addr,
    input   wire[15:0]  r_pc,
    
    //ALU interface
    input   wire[15:0]  alu_r,
    input   wire[15:0]  alu_sf,
    output  wire[15:0]  alu_a,
    output  wire[15:0]  alu_b,
    
    //ALU rmw interface
    input   wire[15:0]  rmw_sf,
    input   wire        rmw_sf_w,
    
    //Control Interface
    input   wire        alu_d_wr,
    input   wire[2:0]   alu_d_adr,
    input   wire        alu_sf_wr,
    output  wire        conflict_sf,
    
    //Both ALU & ID
    output  wire[15:0]  flags
);

assign conflict_sf = alu_sf_wr & rmw_sf_w; // if both try to write flags, ALU fail and operation must be repeated

wire conflict_a = (r_a_addr == alu_d_adr) & alu_d_wr & ~conflict_sf;
wire conflict_b = (r_b_addr == alu_d_adr) & alu_d_wr & ~conflict_sf;

wire is_a_pc = (r_a_addr == 3'b011);
wire is_b_pc = (r_b_addr == 3'b011);

reg[15:0] bank_a[0:7];
reg[15:0] bank_b[0:7];

reg[15:0] a;
reg[15:0] b;

reg[15:0] sf;

always @(posedge clk) begin
    case ( { rmw_sf_w, alu_sf_wr } )
    2'b00: sf <= sf;
    2'b01: sf <= alu_sf;
    2'b10: sf <= rmw_sf;
    2'b11: sf <= rmw_sf;
    endcase
end

always @(posedge clk) begin
    a <= is_a_pc ? r_pc : ( conflict_a ? alu_r : bank_a[r_a_addr] );
    b <= is_b_pc ? r_pc : ( conflict_b ? alu_r : bank_b[r_b_addr] );
    if ( alu_d_wr & ~conflict_sf ) begin
        bank_a[ alu_d_adr ] <= alu_r;
        bank_b[ alu_d_adr ] <= alu_r;
    end
end

assign alu_a = a;
assign alu_b = b;
assign flags = sf;

endmodule