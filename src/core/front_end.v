
module front_end(
    input   wire        clk,
    input   wire        a_rst,

    input   wire        evt_rst,
    input   wire        evt_nmi,
    output  wire        evt_nmi_ack,
    input   wire        evt_irq,
    output  wire        evt_irq_ack,

    input   wire[31:0]  i_mem_opcode,
    input   wire        i_mem_rdy,

    input   wire        ex_pc_w,
    input   wire[15:0]  ex_pc,
    input   wire        ex_feed_slot,
    output  wire        id_feed_req,
    input   wire[7:0]   ex_sf,
    input   wire        ex_sf_wr,

    output  wire[15:0]  i_mem_pc,
    
    output  wire[31:0]  id_iop,
    output  wire[2:0]   id_iop_init,
    output  wire[15:0]  id_arg
);

wire id_is_brk;
wire id_is_wai;
wire id_is_stp;
wire id_is_rti;
wire id_sf_query;
wire [15:0] cs_opcode;
wire [15:0] cs_arg;
wire id_swap_ir;
wire id_swap_arg;
wire cs_hold_fetch;
wire cs_hold_decode;

cpu_status status(
    .clk ( clk ),
    .a_rst ( a_rst ),
    
    .nmi ( evt_nmi ),
    .irq ( evt_irq ),
    .rst ( evt_rst ),
    .brk ( id_is_brk ),
    .nmi_ack ( evt_nmi_ack ),
    .irq_ack ( evt_irq_ack ),
    
    .op_wai (id_is_wai),
    .op_stp (id_is_stp),
    .op_rti (id_is_rti),
    
    .feed_ack( id_feed_req & ex_feed_slot ),
    
    .sf_rdy ( ex_sf_wr ),
    .sf_busy ( id_iop[21] ),
    .sf_query ( id_sf_query ),
    
    .int_ir (cs_opcode),
    .int_k (cs_arg),
    
    .replace_ir ( id_swap_ir ),
    .replace_k ( id_swap_arg ),
    .hold_fetch ( cs_hold_fetch ),
    .hold_decode ( cs_hold_decode )
);

wire br_taken;
wire de_pc_inc;
wire de_pc_inv;

wire[15:0] pc;
wire[15:0] fu_arg;
wire[15:0] fu_ir;
wire fu_ready_ir;

assign hold_fetch = cs_hold_fetch | ~i_mem_rdy | ( fu_ready_ir & ~ex_feed_slot );           // flags hazards are handled by cpu_status
assign hold_decode = cs_hold_decode | ( ~fu_ready_ir & ~id_swap_ir ) | ~ex_feed_slot;       // flags hazards are handled by cpu_status

assign i_mem_pc = pc;

fetch_unit fu(
    .clk ( clk ),
    .a_rst ( a_rst ),
    // memory
    .fetch_opc ( i_mem_opcode ),
    // memory & decoder
    .hold ( hold_fetch ),
    // alu feedback
    .pc_w ( ex_pc_w ),
    .pc_alu ( ex_pc ),
    // decoder
    .pc_inc ( de_pc_inc ),
    .pc_inv ( de_pc_inv ),
    .pc_out ( pc ),
    .ir_out ( fu_ir ),
    .k16_out ( fu_arg ),
    .ir_valid ( fu_ready_ir )
);

wire is_bsr;
wire is_jsr;
wire is_stp;
wire is_wai;

wire [15:0] ir = id_swap_ir ? cs_opcode : fu_ir;
assign id_arg = id_swap_arg ? cs_arg : fu_arg;

decode_unit decode(
    .clk ( clk ),
    .a_rst ( a_rst ),
    
    // cpu status control
    .hold ( hold_fetch ),
    .clr_idx ( id_swap_ir ),
    .sf_query ( id_sf_query ),
    .op_rti ( id_is_rti ),
    .op_stp ( id_is_stp ),
    .op_wai ( id_is_wai ),
    
    // instruction fetch
    .ir ( ir ),
    .br_taken ( br_taken ),
    .pc_inv ( de_pc_inv ),
    .pc_inc ( de_pc_inc ),
    
    // rf
    .sf ( ex_sf ),
    
    // scheduling queue
    .id_feed ( id_feed_req ),
    .id_iop ( id_iop ),
    .id_iop_init ( id_iop_init )
);

endmodule