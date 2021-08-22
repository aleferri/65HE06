
module perf_indexed;

reg clk;
reg rst;
reg[15:0] clock_count;

wire evt_irq = 1'b0;
wire evt_irq_ack;
wire evt_nmi = 1'b0;
wire evt_nmi_ack;
wire evt_rst = 1'b0;

reg[15:0] i_bank[0:63];
reg[31:0] opc;
wire i_mem_rdy = 1'b1;

wire[15:0] pc;

reg[7:0] d_bank[0:65535];
reg[15:0] d_data_in;
wire[15:0] d_data_out;
wire[15:0] d_addr;
wire d_mem_rdy = 1'b1;
wire d_cmd;
wire d_be0;
wire d_be1;
wire d_assert;
reg[16:0] count;

always @(negedge clk) begin
    if ( d_assert ) begin
        if ( d_cmd ) begin
            if ( d_be0 & d_be1 ) begin
                d_bank[ { d_addr[15:1], 1'b0 } ] <= d_data_out[ 15:8 ];
                d_bank[ { d_addr[15:1], 1'b1 } ] <= d_data_out[ 7:0 ];
            end else begin
                d_bank[ d_addr[15:0] ] <= d_data_out[ 7:0 ];
                $display( "Wrote at %h: %h", d_addr, d_data_out );
            end
        end else begin
            if ( d_be0 & d_be1 ) begin
                d_data_in[15:8] <= d_bank[ { d_addr[15:1], 1'b0 } ];
                d_data_in[7:0] <= d_bank[ { d_addr[15:1], 1'b1 } ];
            end else begin
                d_data_in[15:8] <= 8'b0;
                d_data_in[7:0] <= d_bank[ d_addr ];
                $display( "Read at %h: %h", d_addr, d_bank[ d_addr ] );
            end
        end
    end
end

always @(negedge clk) begin
    if ( d_assert & d_cmd & ( d_addr == 16'hFFFE ) ) begin
        $display( "Completion at %d", clock_count );
        $finish;
    end
end

core dut(
    .clk ( clk ),
    .a_rst ( rst ),
    
    .evt_rst ( evt_rst ),
    .evt_nmi ( evt_nmi ),
    .evt_nmi_ack ( evt_nmi_ack ),
    .evt_irq ( evt_irq ),
    .evt_irq_ack ( evt_irq_ack ),
    
    .i_mem_opcode ( opc ),
    .i_mem_rdy ( i_mem_rdy ),
    .i_mem_pc ( pc ),
    
    .d_mem_rdy ( d_mem_rdy ),
    .d_mem_data_in ( d_data_in ),
    .d_mem_data_out ( d_data_out ),
    .d_mem_addr ( d_addr ),
    .d_mem_be0 ( d_be0 ),
    .d_mem_be1 ( d_be1 ),
    .d_mem_cmd ( d_cmd ),
    .d_mem_assert ( d_assert )
);

initial begin
    $dumpfile("testbench_indexed.vcd");
    $dumpvars(0, dut);
    for ( count = 0; count < 65532; count++ ) begin
        d_bank[count] = count[15:8];
    end
    d_bank[ 16'b1111_1111_1111_1000 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1001 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1010 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1011 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1100 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1101 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1110 ] = 8'b0;
    d_bank[ 16'b1111_1111_1111_1111 ] = 8'b0;
    
    clock_count = 0;
    
    i_bank[0] = 16'b00010_111_1001_0000;    // LDZ      #0
    i_bank[1] = 16'h0000;
    i_bank[2] = 16'b00010_100_0001_0000;    // LDS      #0
    i_bank[3] = 16'h0000;
    i_bank[4] = 16'b10011_111_1001_0000;    // STF      Z ?
    i_bank[5] = 16'h0000;
    i_bank[6] = 16'b00010_110_0001_0000;    // LDY      #$64
    i_bank[7] = 16'h0064;
    i_bank[8] = 16'b00001_110_1001_0000;   // SUB:Y    #1 ?
    i_bank[9] = 16'h0000;
    i_bank[10] = 16'b00010_000_0110_1000;   // LDA      byte $C000, Y
    i_bank[11] = 16'hC000;
    i_bank[12] = 16'b10000_000_0110_1000;   // STA      byte $B000, Y
    i_bank[13] = 16'hB000;
    i_bank[14] = 16'hF320;                  // BNE      -16
    i_bank[15] = 16'hFFF0;
    i_bank[16] = 16'b10000_111_0010_1100;   // STZ      $FFFE
    i_bank[17] = 16'hFFFE;
    i_bank[18] = 16'b10000_111_0010_1100;   // STZ      $FFFE
    i_bank[19] = 16'hFFFE;
    i_bank[20] = 16'b10000_111_0010_1100;   // STZ      $FFFE
    i_bank[21] = 16'hFFFE;
    
    for ( count = 22; count < 64; count++ ) begin
        i_bank[count] = 16'b0;
    end
    
    rst = 0;
    clk = 0;
    #1 rst = 1;
    #4600
    $display("Not completed in time");
    $finish;
end

always @(posedge clk) begin
    clock_count <= clock_count + 1;
end

always begin
    #2 clk <= ~clk;
end

always @(negedge clk) begin
    opc[31:16] = i_bank[ { pc[7:2], 1'b0 } ];
    opc[15:0] = i_bank[ { pc[7:2], 1'b1 } ];
end

endmodule