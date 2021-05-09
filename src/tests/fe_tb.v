module fe_tb();

reg clk;
reg [15:0] cache_bank_a[0:63];
reg [15:0] cache_bank_b[0:63];
reg [6:0] count;

reg[15:0] bank_a;
reg[15:0] bank_b;
reg[15:0] prefetch_a;

reg hold;
reg pc_w;
reg[15:0] pc_alu;
reg pc_inc;
reg pc_i2;
reg pc_inv;
wire[15:0] pc_out;
wire[15:0] ir_out;
wire[15:0] k16_out;
wire[15:0] prefetch_out;
wire ir_valid;
reg rst;

fetch_unit f(
    .clk(clk),
    .a_rst(rst),
    .fetch_opc(bank_a),
    .fetch_arg(bank_b),
    .prefetch_opc(prefetch_a),
    .hold(hold),
    .prefetch_out(prefetch_out),
    .pc_w(pc_w),
    .pc_alu(pc_alu),
    .pc_inc(pc_inc),
    .pc_i2(pc_i2),
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
        cache_bank_a[count] = count * 2;
        cache_bank_b[count] = count * 2 + 1;
    end
    clk = 0;
    pc_inv = 1;
    pc_inc = 0;
    pc_i2 = 0;
    pc_alu = 16'b0;
    bank_a = 16'b0;
    bank_b = 16'b0;
    prefetch_a = 16'b0;
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
    pc_inv = 0;
    #5
    pc_i2 = 1;
    #9
    pc_i2 = 0;
    #54
    $finish;
    
end

always begin
    #2 clk <= ~clk;
    bank_a <= cache_bank_a[ pc_out[6:2] ];
    bank_b <= cache_bank_b[ pc_out[6:2] ];
    prefetch_a <= cache_bank_a[ prefetch_out[6:2] ];
end

endmodule