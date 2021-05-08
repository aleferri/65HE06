module r_station(
    input   wire        clk,
    input   wire        a_rst,
    
    output  wire        id_feed_req,
    
    input   wire[19:0]  id_uop_0,
    input   wire[19:0]  id_uop_1,
    input   wire[19:0]  id_uop_2,
    input   wire[1:0]   id_uop_count,
    
    output  wire[19:0]  ex_uop_last,
    output  wire[19:0]  ex_uop_next,
    
    input   wire[15:0]  id_k16,
    input   wire[15:0]  mem_data_in,
    input   wire        mem_data_wr,
    input   wire        ex_sched_ack,
    output  wire[15:0]  ex_data_out
);
parameter NOP = 20'b0000_0000_1111_00_000_000;

reg[19:0] uop_0;
reg[19:0] uop_1;
reg[19:0] uop_2;
reg[15:0] temp;
reg[1:0] uop_count;
reg valid;

always @(posedge clk, negedge a_rst) begin
    if ( ~a_rst ) begin
        uop_0 = 0;
        uop_1 = 1;
        uop_2 = 2;
        uop_count = 0;
        valid = 0;
    end else
        if uop_count == 2'b0 begin
            uop_0 <= id_uop_0;
            uop_1 <= id_uop_1;
            uop_2 <= id_uop_2;
            uop_count <= id_uop_count;
            valid <= ex_sched_ack;
        end else begin
            uop_0 <= uop_0;
            uop_1 <= uop_1;
            uop_2 <= uop_2;
            uop_count <= uop_count - ex_sched_ack;
            valid <= valid;
        end
    end
end

always @(posedge clk, negedge a_rst) begin
    if ( ~a_rst ) begin
        temp <= 0;
    end else
        if uop_count == 2'b0 begin
            temp <= id_k16;
        end else if mem_data_wr begin
            temp <= mem_data_in;
        end else begin
            temp <= temp;
        end
    end
end

assign id_feed_req = 2'b00 = uop_count;
assign ex_uop_last = uop_0;

reg[19:0] next;

always @(*) begin
    case({ uop_count[1] | ~valid, uop_count[0] | ~valid })
    2'b00: next = uop_0;
    2'b01: next = uop_1;
    2'b10: next = uop_2;
    2'b11: next = NOP;
    endcase
end

assign ex_uop_next = next;
assign ex_data_out = temp;

endmodule