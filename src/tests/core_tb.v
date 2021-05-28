
module core_tb;

reg clk;
reg[15:0] clock_count;
reg rst;
wire evt_int = 1'b0;
wire evt_int_ack;

reg[15:0] i_bank[0:63];
reg[31:0] opc;
wire i_mem_rdy = 1'b1;

wire[15:0] pc;

always @(negedge clk) begin
    opc[31:16] <= i_bank[ { pc[6:2], 1'b0 } ];
    opc[15:0] <= i_bank[ { pc[6:2], 1'b1 } ];
end

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
            if ( d_be0 ) begin
                d_bank[ d_addr ] <= d_data_out[7:0];
            end
            if ( d_be1 ) begin
                d_bank[ { d_addr[15:1], d_be0 } ] <= d_be0 ? d_data_out[15:8] : d_data_out[7:0];
            end
        end else begin
            d_data_in[7:0] <= d_bank[ {d_addr[15:1], ~d_be0} ];
            d_data_in[15:0] <= (d_be0 & d_be1) ? d_bank[ { d_addr[15:1], 1'b1 } ] : 8'b0;
        end
    end
end

core dut(
    .clk ( clk ),
    .a_rst ( rst ),
    .evt_int ( evt_int ),
    .evt_int_ack ( evt_int_ack ),
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
    $dumpfile("testbench_core.vcd");
    $dumpvars(0, dut);
    for ( count = 0; count < 65536; count++ ) begin
        d_bank[count] = count[15:8];
    end
    
    clock_count = 0;
    
    i_bank[0] = 16'b00010_111_1001_0000;
    i_bank[1] = 16'h0000;
    i_bank[2] = 16'b00010_100_0001_0000;
    i_bank[3] = 16'h0000;
    i_bank[4] = 16'b00010_110_0001_0000;
    i_bank[5] = 16'h0064;
    i_bank[6] = 16'b00010_000_0001_0000;
    i_bank[7] = 16'hC000;
    i_bank[8] = 16'b10000_000_0010_1100;
    i_bank[9] = 16'h00A0;
    i_bank[10] = 16'b00010_000_0001_0000;
    i_bank[11] = 16'hB000;
    i_bank[12] = 16'b10000_000_0010_1100;
    i_bank[13] = 16'h00A2;
    i_bank[14] = 16'b00001_110_0001_0000;
    i_bank[15] = 16'h0001;
    i_bank[16] = 16'b00010_000_0111_1110;
    i_bank[17] = 16'h00A0;
    i_bank[18] = 16'b10000_000_0111_1110;
    i_bank[19] = 16'h00A2;
    i_bank[20] = 16'hF320;
    i_bank[21] = 16'hFFF0;
    i_bank[22] = 16'h1010;
    i_bank[23] = 16'h0000;
    i_bank[24] = 16'h6020;
    i_bank[25] = 16'hFFFF;
    for ( count = 26; count < 64; count++ ) begin
        i_bank[count] = 16'b0;
    end
    rst = 1;
    clk = 1;
    #1 rst = 0;
    #5
    rst = 1;
    #200
    $display(clock_count);
    $finish;
    
end

always @(posedge clk) begin
    clock_count <= clock_count + 1;
end

always begin
    #2 clk <= ~clk;
end

endmodule