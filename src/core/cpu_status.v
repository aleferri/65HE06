
module cpu_status(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        nmi,
    input   wire        irq,
    input   wire        brk,
    input   wire        rst,
    input   wire        wai,
    input   wire        stp,
    input   wire        restore,
    input   wire        jsr,
    input   wire        bsr,
    input   wire        feed_ack,
    input   wire[7:0]   ir_low,
    output  wire[15:0]  int_ir,
    output  wire[15:0]  int_k,
    output  wire        int_ack,
    output  wire        replace_ir,
    output  wire        replace_k,
    output  wire        hold_fetch,
    output  wire        hold_decode
);
parameter INT_VEC_BASE = 14'b1111_1111_1111_11;

// FFFE-FFFF : IRQ 11
// FFFC-FFFD : RST 10
// FFFA-FFFB : NMI 01
// FFF8-FFF9 : BRK 00

reg mask_irq;
reg is_powerup;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        mask_irq = 1'b0;
    end else begin
        mask_irq <= ~mask_irq & irq | mask_irq & ~restore;
    end
end

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        is_powerup = 1'b0;
    end else begin
        is_powerup <= ( next_proc_status == 3'b000 );
    end
end

wire irq_masked = irq & ~mask_irq;

//JSR/INT SEQUENCE:
// 0) stable
// 1) IR = push pc; hold fetch
// 2) IR = jmp dest; assert inv_pc, goto stable
// OTHER STATES
// 3) wai: hold fetch/decode until irq/nmi/rst
// 4) stp: hold fetch/decode until rst

reg[2:0] proc_status;
reg[2:0] next_proc_status;

wire is_interrupt = nmi | rst | irq_masked | brk | ~is_powerup;

always @(*) begin
    case (proc_status)
    3'b000: next_proc_status = ( is_interrupt | jsr | bsr ) ? { wai | stp, stp, 1'b1 } : 3'b000;
    3'b001: next_proc_status = feed_ack ? 3'b010 : 3'b001;
    3'b010: next_proc_status = feed_ack ? 3'b000 : 3'b010;
    3'b011: next_proc_status = 3'b000;
    3'b100: next_proc_status = 3'b000;
    3'b101: next_proc_status = 3'b001;
    3'b110: next_proc_status = 3'b000;
    3'b111: next_proc_status = rst ? 3'b001 : 3'b111;
    endcase
end

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        proc_status = 3'b000;
    end else begin
        proc_status <= next_proc_status;
    end
end

reg was_irq;
reg was_rst;
reg was_nmi;
reg was_brk;

always @(posedge clk) begin
    was_irq <= ( proc_status === 3'b000 ) ? irq : was_irq;
    was_rst <= ( proc_status === 3'b000 ) ? (rst | ~is_powerup) : was_rst;
    was_nmi <= ( proc_status === 3'b000 ) ? nmi : was_nmi;
    was_brk <= ( proc_status === 3'b000 ) ? brk : was_brk;
end

assign int_ir = (next_proc_status === 3'b001) ? 16'b10000_011_0010_00_10 : { 8'b00010_011, ir_low };
assign int_k = (next_proc_status === 3'b001) ? 16'h0001 : { INT_VEC_BASE, was_rst | was_irq, was_nmi | was_irq };
assign int_ack = ( next_proc_status === 3'b001 );
assign replace_ir = ( proc_status === 3'b001 ) | ( proc_status === 3'b010 );
assign replace_k = ( proc_status === 3'b001 ) | ( proc_status === 3'b010 ) & ( was_rst | was_irq | was_nmi | was_brk );
assign hold_fetch = ( next_proc_status === 3'b001 ) | (next_proc_status === 3'b010);
assign hold_decode = ( next_proc_status === 3'b001 ) | (next_proc_status === 3'b010);

endmodule