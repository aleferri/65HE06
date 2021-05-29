module int_tb;

reg clk;
reg a_rst;
reg nmi;
reg irq;
reg rst;
reg wai;
reg stp;
reg restore;
reg jsr;
reg bsr;
reg feed_ack;
reg[7:0] ir_low;

wire[15:0] int_ir;
wire[15:0] int_k;
wire replace_ir;
wire replace_k;
wire hold_fetch;
wire hold_decode;

cpu_status status(
    .clk ( clk ),
    .a_rst ( a_rst ),
    .nmi ( nmi ),
    .irq ( irq ),
    .brk ( brk ),
    .rst ( rst ),
    .wai ( wai ),
    .stp ( stp ),
    .restore ( restore ),
    .jsr ( jsr ),
    .bsr ( bsr ),
    .feed_ack ( feed_ack ),
    .ir_low ( ir_low ),
    .int_ir ( int_ir ),
    .int_k ( int_k ),
    .int_ack ( int_ack ),
    .replace_ir ( replace_ir ),
    .replace_k ( replace_k ),
    .hold_fetch ( hold_fetch ),
    .hold_decode ( hold_decode )
);

endmodule