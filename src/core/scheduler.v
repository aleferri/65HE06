module scheduler(
    input   wire[19:0]  uop_next_a,
    input   wire[19:0]  uop_next_b,
    input   wire        uop_is_last_a,
    input   wire        uop_is_last_b,
    input   wire[19:0]  uop_last_a,
    input   wire[19:0]  uop_last_b,
    input   wire        main_sched,
    input   wire        ex_doing_mem,
    output  wire        next_sched,
    output  wire        next_main,
    output  wire[19:0]  uop_next
);

wire is_b_store = uop_is_last_b[13];
wire is_a_store = uop_is_last_a[13];
wire is_next_a_store = uop_next_a[13];
wire is_next_b_store = uop_next_b[13];
wire dest_reg_a = uop_last_a[11:8];
wire dest_reb_b = uop_last_b[11:8];
wire source_reg_0_a = { 1'b0, uop_next_a[2:0] };
wire source_reg_1_a = { 1'b0, uop_next_a[5:3] };
wire source_reg_0_b = { 1'b0, uop_next_b[2:0] };
wire source_reg_1_b = { 1'b0, uop_next_b[5:3] };

wire is_a_rdy_if_next = ~is_b_store & ~is_next_a_store & ~uop_is_last_a & (source_reg_0_a != dest_reb_b) & (source_reg_1_a != dest_reb_b);
wire is_b_rdy_if_next = ~is_a_store & ~is_next_b_store & ~uop_is_last_b & (source_reg_0_b != dest_reb_a) & (source_reg_1_b != dest_reb_a);

wire is_a_main = ~main_sched;
wire is_b_main = main_sched;

assign next_sched = main ^ ( ex_doing_mem & is_a_rdy_if_next & is_b_main | ex_doing_mem & is_b_rdy_if_next & is_a_main );
assign next_main = main_sched ^ ( is_a_main & uop_is_last_a & ~next_sched | is_b_main & uop_is_last_b & next_sched );
assign uop_next = next_sched ? uop_next_b : uop_next_a;

endmodule