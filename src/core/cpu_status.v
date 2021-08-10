
module cpu_status(
    input   wire        clk,
    input   wire        a_rst,
    
    // interrupts
    input   wire        nmi,
    input   wire        irq,
    input   wire        brk,
    input   wire        rst,
    output  wire        nmi_ack,
    output  wire        irq_ack,
    
    // opcodes that specifically affect cpu status
    input   wire        op_wai,     // wait for interrupt
    input   wire        op_stp,     // wait for reset
    input   wire        op_rti,     // unmask irq
    
    // opcode fed
    input   wire        feed_ack,
    
    // sf handling
    input   wire        sf_query,   // sf is requested, stall decode if sf is not stable
    input   wire        sf_busy,    // sf is busy
    input   wire        sf_rdy,     // sf busy flag is cleared
    
    // issue alternative ir + arg
    output  wire[15:0]  int_ir,
    output  wire[15:0]  int_k,
    
    output  wire        replace_ir,
    output  wire        replace_k,
    
    // control front end units
    output  wire        hold_fetch,
    output  wire        hold_decode
);
parameter INT_VEC_BASE = 14'b1111_1111_1111_11;

// Reset Vector
// FFFE-FFFF : IRQ 11
// FFFC-FFFD : RST 10
// FFFA-FFFB : NMI 01
// FFF8-FFF9 : BRK 00

reg sf_status; // 1'b0: ready, 1'b1: busy

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        sf_status = 1'b0;
    end else begin
        sf_status <= sf_status ? ( ~sf_rdy | sf_busy ) : sf_busy;
    end
end

/**
 * States:
 *  0) Reset                                         ; GOTO 1
 *  1) JUMP VECTOR                                   ; GOTO 2 when issued
 *  2) Skip Next                                     ; GOTO 3 when done
 *  3) Normal Operation                              ; GOTO 1 when IRQ | NMI | BRK | RST; GOTO 4 when opcode read busy flags; GOTO 7 when STP; GOTO 6 when WAI
 *  4) Wait flags busy                               ; GOTO 3 when resolved
 *  5) Wait Reset
 *  6) Wait Interrupt                                ; GOTO 1 when IRQ | RST | NMI
 *  7) Wait Reset                                    ; GOTO 1 when RST
 *
 * Invariants:
 * In 3 and 6 any interrupt mask IRQ
 * In 3 RTI unmask IRQ
 * On IRQ_ACK the irq status is asserted, on NMI_ACK the nmi status is asserted, only one of them can be high in the same cycle
 *
 * Fetch is put on hold during state 3 if the future state is not 3
 * Decode is put on hold during state 3 if the future state is not 3
 * Fetch is put on hold during states: 0, 1, 2, 4, 5, 6, 7
 * Decode is put on hold during states: 0, 2, 4, 5, 6, 7 
 **/
 
reg irq_mask;

reg[2:0] proc_status;
reg[2:0] next_proc_status;

wire is_interrupt = nmi | rst | irq_masked | brk;

always @(*) begin
    case (proc_status)
    3'b000: next_proc_status = 3'b001;
    3'b001: next_proc_status = feed_ack ? 3'b010 : proc_status;
    3'b010: next_proc_status = feed_ack ? 3'b011 : proc_status;
    3'b011: next_proc_status = ( sf_status & sf_query ) ? 3'b100 : ( is_interrupt & feed_ack | op_wai | op_stp ) ? { op_wai | op_stp, op_stp, 1'b1 } : proc_status;
    3'b100: next_proc_status = { ~sf_rdy, sf_rdy, sf_rdy };
    3'b101: next_proc_status = rst ? 3'b001 : proc_status;
    3'b110: next_proc_status = is_interrupt ? 3'b000 : proc_status;
    3'b111: next_proc_status = rst ? 3'b001 : proc_status;
    endcase
end

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        proc_status = 3'b000;
    end else begin
        proc_status <= next_proc_status;
    end
end

reg mask_irq;
always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        mask_irq = 1'b0;
    end else begin
        mask_irq <= ~mask_irq & irq | mask_irq & ~op_rti;
    end
end

wire irq_masked = irq & ~mask_irq;

reg was_irq;
reg was_rst;
reg was_nmi;
reg was_brk;

always @(posedge clk) begin
    was_irq <= ( proc_status == 3'b011 ) ? irq : was_irq;
    was_rst <= ( proc_status == 3'b011 ) ? rst : was_rst | (proc_status == 3'b000);
    was_nmi <= ( proc_status == 3'b011 ) ? nmi : was_nmi;
    was_brk <= ( proc_status == 3'b011 ) ? brk : was_brk;
end

assign int_ir = was_rst ? { 8'b00010_011, 8'b0010_1100 } : 16'b10000_011_0010_00_10;
assign int_k = { INT_VEC_BASE, was_rst | was_irq, was_nmi | was_irq };
assign irq_ack = ( next_proc_status == 3'b001 ) & was_irq;
assign nmi_ack = ( next_proc_status == 3'b001 ) & was_nmi;
assign replace_ir = ( proc_status == 3'b001 );
assign replace_k = ( proc_status == 3'b001 );
assign hold_fetch = ( next_proc_status != 3'b011 );
assign hold_decode = ( next_proc_status != 3'b001 ) & (next_proc_status != 3'b011);

endmodule