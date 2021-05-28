module decode_tb();

reg clk;

reg hold;
reg[7:0] sf;
reg sf_written;
wire pc_inc;
wire pc_inv;
reg[15:0] ir;
reg feed_req;
wire feed_ack;
wire sel_pc;
wire br_taken;
wire restore_int;
reg ir_valid;
wire[19:0] uop_0;
wire[19:0] uop_1;
wire[19:0] uop_2;
wire[1:0] count;
reg rst;
reg[15:0] code[0:15];
reg[3:0] next;

decode_unit id(
    .clk ( clk ),
    .a_rst ( rst ),
    .hold ( hold ),
    .ir_valid ( ir_valid ),
    .feed_req ( feed_req ),
    .feed_ack ( feed_ack ),
    .ir ( ir ),
    .sf ( sf ),
    .sf_written ( sf_written ),
    .sel_pc ( sel_pc ),
    .br_taken ( br_taken ),
    .pc_inv ( pc_inv ),
    .pc_inc ( pc_inc ),
    .restore_int ( restore_int ),
    .uop_0 ( uop_0 ),
    .uop_1 ( uop_1 ),
    .uop_2 ( uop_2 ),
    .uop_count ( count )
);

initial begin
    $dumpfile("testbench_decode.vcd");
    $dumpvars(0,decode_tb);
    code[0] = 16'b00010_111_1001_0000;
    code[1] = 16'b00010_100_0001_0000;
    code[2] = 16'b00010_110_0001_0000;
    code[3] = 16'b00010_000_0001_0000;
    code[4] = 16'b10000_000_0010_1100;
    code[5] = 16'b00010_000_0001_0000;
    code[6] = 16'b10000_000_0010_1100;
    code[7] = 16'b00001_110_0001_0000;
    code[8] = 16'b00010_000_0111_1110;
    code[9] = 16'b10000_000_0111_1110;
    code[10] = 16'hF320;
    code[11] = 16'h1010;
    code[12] = 16'h6020;
    next = 0;
    ir_valid = 1;
    sf = 8'b0;
    feed_req = 0;
    sf_written = 1;
    ir = code[0];
    clk = 0;
    hold = 1;
    rst = 0;
    #1
    rst = 1;
    #54
    $finish;
end

always begin
    #2 clk <= ~clk;
end

always @(posedge clk) begin
    ir <= code [ next ];
    next <= next + 1;
end

always @(negedge clk) begin
    $display( "Start frame %d %b", next, ir );
    $display( "ALU: %d, MASK: %d, LD: %d, WR: %d, FLAGS: %d, DEST: %d, ALU_MUX: %d, B: %d, A: %d", uop_0[19:16], uop_0[15], uop_0[14], uop_0[13], uop_0[12], uop_0[11:8], uop_0[7:6], uop_0[5:3], uop_0[2:0]);
    $display( "ALU: %d, MASK: %d, LD: %d, WR: %d, FLAGS: %d, DEST: %d, ALU_MUX: %d, B: %d, A: %d", uop_1[19:16], uop_1[15], uop_1[14], uop_1[13], uop_1[12], uop_1[11:8], uop_1[7:6], uop_1[5:3], uop_1[2:0]); 
    $display( "ALU: %d, MASK: %d, LD: %d, WR: %d, FLAGS: %d, DEST: %d, ALU_MUX: %d, B: %d, A: %d", uop_2[19:16], uop_2[15], uop_2[14], uop_2[13], uop_2[12], uop_2[11:8], uop_2[7:6], uop_2[5:3], uop_2[2:0]);
    $display( "End frame\n" );
end

endmodule
