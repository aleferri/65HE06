module uop_executing(
    input   wire        clk,
    input   wire        a_rst,
    input   wire        stop,
    input   wire[19:0]  uop_next,
    input   wire[15:0]  temp_a,
    input   wire[15:0]  temp_b,
    input   wire        next_sched,
    input   wire        next_main,
    output  wire[15:0]  t16,
    output  wire[2:0]   idx_a,
    output  wire[2:0]   idx_b,
    output  wire        sel_inp,
    output  wire[2:0]   idx_dest,
    output  wire[3:0]   alu_f,
    output  wire        carry_mask,
    output  wire        flags_w,
    output  wire        reg_wr,
    output  wire        adr_wr_back,
    output  wire        mar_wr,
    output  wire        mem_rq_width,
    output  wire        mem_rq_cmd,
    output  wire        mem_rq,
    output  wire        sched_now,
    output  wire        sched_main,
    output  wire        main_ex_mem
);

reg[19:0] uop;
reg[15:0] temp;
reg main;
reg sched;

always @(posedge clk or negedge a_rst) begin
    if ( ~a_rst ) begin
        main = 1'b0;
        sched = 1'b0;
        uop = 20'b0;
        temp = 16'b0;
    end else begin
        uop <= uop_next;
        temp <= next_sched ? temp_b : temp_a;
        sched <= stop ? sched : next_sched;
        main <= stop ? main : next_main;
    end
end

assign t16 = temp;
assign idx_a = uop[2:0];
assign idx_b = uop[5:3];
assign sel_inp = uop[6];
assign adr_wr_back = uop[7];
assign idx_dest = uop[10:8];
assign reg_wr = ~uop[11] & ~stop;
assign flags_w = uop[12] & ~stop;
assign mar_wr = uop[11] & ~uop[10] & ~uop[9] & ~stop;
assign mem_rq_width = mar_wr & uop[8];
assign mem_rq_cmd = uop[13];
assign mem_rq = (uop[13] | uop[14]) & ~stop;
assign sched_main = main;
assign alu_f = uop[19:16];
assign carry_mask = ~uop[15];
assign main_ex_mem = mem_rq & sched_main == sched;
assign sched_now = sched;

endmodule