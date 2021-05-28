module fe_tb();

reg clk;
reg [15:0] cache_bank[0:63];
reg [6:0] count;

reg[31:0] opc;

reg hold;
reg pc_w;
reg[15:0] pc_alu;
reg pc_inc;
reg pc_inv;
wire[15:0] pc_out;
wire[15:0] ir_out;
wire[15:0] k16_out;
wire ir_valid;
reg rst;

wire[14:0] effective_pc = pc_out[15:1];

fetch_unit f(
    .clk(clk),
    .a_rst(rst),
    .fetch_opc(opc),
    .hold(hold),
    .pc_w(pc_w),
    .pc_alu(pc_alu),
    .pc_inc(pc_inc),
    .pc_inv(pc_inv),
    .pc_out(pc_out),
    .ir_out(ir_out),
    .k16_out(k16_out),
    .ir_valid(ir_valid)
);

initial begin
    $dumpfile("testbench_fetch.vcd");
    $dumpvars(0,fe_tb);
    for ( count = 0; count < 64; count++ ) begin
        cache_bank[count] = count;
    end
    clk = 0;
    pc_inv = 1;
    pc_inc = 0;
    pc_alu = 16'b0;
    opc = 32'b0;
    pc_w = 0;
    hold = 1;
    rst = 1;
    #3
    rst = 0;
    #3
    pc_inv = 1;
    hold = 0;
    rst = 1;
    #3
    pc_w = 1;
    #3
    pc_w = 0;
    pc_inc = 1;
    #2
    pc_inv = 0;
    #54
    $finish;
    
end

always begin
    #2 clk <= ~clk;
end

always @(negedge clk) begin
    opc[31:16] <= cache_bank[ { effective_pc[5:1], 1'b0 } ];
    opc[15:0] <= cache_bank[ { effective_pc[5:1], 1'b1 } ];
end

endmodule