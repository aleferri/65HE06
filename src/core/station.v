
module station(
    input   wire        clk,
    input   wire        a_rst,
    
    //Instruction Decode Interface
    input   wire        id_ack,
    input   wire[31:0]  id_iop,
    input   wire[2:0]   id_iop_init,
    input   wire[15:0]  id_pc,
    input   wire[15:0]  id_k16,
    output  wire        id_feed,
    
    //Address Buffer Interface
    output  wire[15:0]  ab_data,
    output  wire        ab_wr,
    
    //LSU Interface
    input   wire[15:0]  lsu_data,
    input   wire        lsu_wb,
    
    //ALU Interface
    input   wire[15:0]  alu_addr,
    
    //Sched Interface
    output  wire[15:0]  r_pc,
    output  wire[15:0]  r_k16,
    output  wire[2:0]   r_a_adr,
    output  wire[2:0]   r_b_adr,
    output  wire[3:0]   r_d_adr,
    output  wire[3:0]   r_fn,
    output  wire        r_mask_carry,
    output  wire        r_save_flags,
    output  wire        r_st_mem,
    output  wire        r_ld_mem,
    output  wire        r_mem_width,
    output  wire        r_bypass_b,
    output  wire        r_lock_loads,       //lock loads
    output  wire[3:0]   r_lock_reg_wr,      //lock register from being read
    output  wire[2:0]   r_lock_reg_rd_0,    //lock register from being written
    output  wire[2:0]   r_lock_reg_rd_1,    //lock register from being written
    input   wire        sched_ack,
    input   wire        sched_ld_addr
);
parameter ST_COMPLETE = 3'b000;
parameter ST_WAIT_1   = 3'b001;
parameter ST_WAIT_2   = 3'b010;
parameter ST_WAIT_3   = 3'b011;
parameter ST_LOAD_0   = 3'b100;
parameter ST_LOAD_1   = 3'b101;
parameter ST_ALU      = 3'b110;
parameter ST_STORE    = 3'b111;

reg[2:0] iop_status;

wire is_status_complete = iop_status == ST_COMPLETE;
wire is_status_wait_1 = iop_status == ST_WAIT_1;
wire is_status_wait_2 = iop_status == ST_WAIT_2;
wire is_status_load_0 = iop_status == ST_LOAD_0;
wire is_status_load_1 = iop_status == ST_LOAD_1;
wire is_status_alu = iop_status == ST_ALU;
wire is_status_store = iop_status == ST_STORE;

/**
 * Internal OPeration fields:
 *
 * 30: agu_mask_index       (AGU step)
 * 29: agu_send_index       (AGU step)
 * 28: agu_write_back       (AGU step)
 * 27: agu_index_1_1        (AGU step)
 * 26: agu_index_1_0        (AGU step)
 * 25: agu_index_0_1        (AGU step)
 * 24: agu_index_0_0        (AGU step)
 * -----------------------------------
 * 23: alu_is_jsr           (ALU step)
 * 22: alu_st_mem           (ALU step)
 * 21: alu_save_flags       (ALU step)
 * 20: alu_mask_carry       (ALU step)
 * 19: alu_fn_3             (ALU step)
 * 18: alu_fn_2             (ALU step)
 * 17: alu_fn_1             (ALU step)
 * 16: alu_fn_0             (ALU step)
 * 15: alu_a_2              (ALU step)
 * 14: alu_a_1              (ALU step)
 * 13: alu_a_0              (ALU step)
 * 12: alu_b_2              (ALU step)
 * 11: alu_b_1              (ALU step)
 * 10: alu_b_0              (ALU step)
 * 09: alu_d_3              (ALU step)
 * 08: alu_d_2              (ALU step)
 * 07: alu_d_1              (ALU step)
 * 06: alu_d_0              (ALU step)
 * 05: alu_k                (ALU step)
 * -----------------------------------
 * 04: mem_is_rmw           (STORE step)
 * 03: mem_width            (LOAD/STORE step)
 * 02: mar_write            (LOAD/STORE step)
 * 01: reserved
 * 00: reserved
 * -----------------------------------
 */
 
// State machine implementation

reg[31:0] iop;
reg[15:0] iop_pc;

always @(posedge clk) begin
    iop <= (id_feed & id_ack) ? id_iop : iop;
    iop_pc <= (id_feed & id_ack) ? id_pc : iop_pc;
end

reg[15:0] iop_k16;

always @(posedge clk) begin
    case({lsu_wb, id_feed & id_ack})
    2'b00: iop_k16 <= iop_k16;
    2'b01: iop_k16 <= id_k16;
    2'b10: iop_k16 <= lsu_data;
    2'b11: iop_k16 <= id_k16;
    endcase
end

reg[15:0] iop_last_addr;

always @(posedge clk) begin
    iop_last_addr = sched_ld_addr ? alu_addr : sched_ld_addr;
end

wire is_alu_store = is_status_alu & iop[22];
wire is_rmw_index = is_status_load_1 & iop[28];

//This signal is already gated by sched_ack
assign id_feed = is_status_complete | is_status_alu & sched_ack;

//These signals are expected to be gated outside the station
assign ab_data = iop[4] ? iop_last_addr : iop_k16;
assign ab_wr = is_status_load_1 & iop[4] | is_status_load_1 & iop[30];

//These signals are repeatable
assign r_pc = iop_pc;
assign r_k16 = iop[29] ? 16'b0 : iop_k16;

assign r_a_adr = is_status_load_0 ? { 1'b1, iop[25:24] } : is_status_load_1 ? { 1'b1, iop[27:26] } : iop[15:13];
assign r_b_adr = iop[12:10];

//Quite complicated. D top bit (means "do the write") is 1 if doing pre-inc or post-dec during load or if ALU write to register. 
//Lower part is either the address of the index or the register specified by the instruction.
assign r_d_adr = { is_status_alu & iop[9] | is_rmw_index, is_rmw_index | iop[8], is_rmw_index ? iop[27:26] : iop[7:6] };

assign r_fn = ( is_status_load_0 | is_status_load_1 ) ? 4'b0111 : iop[19:16];

assign r_mask_carry = ~(~is_status_alu | iop[20]);

assign r_save_flags = is_status_alu & iop[21];

assign r_st_mem = is_alu_store;
assign r_ld_mem = is_status_load_0 | is_status_load_1;
assign r_mem_width = iop[3] & ~is_status_load_0;

assign r_bypass_b = iop[5];

//Conflicts are implicitly handled for scheduled uOps operands (a, b & d), additional locks are required to specify the terminals reads and writes of the instruction
assign r_lock_loads = iop[22];
assign r_lock_reg_wr = iop[9:6];
assign r_lock_reg_rd_0 = iop[15:13];
assign r_lock_reg_rd_1 = iop[12:10];

always @(posedge clk or posedge a_rst) begin
    if ( a_rst ) begin
        iop_status = 3'b000;
    end else begin
        case (iop_status)
        3'b000: iop_status <= id_ack ? id_iop_init : iop_status;
        3'b001: iop_status <= { lsu_wb, 2'b01 };
        3'b010: iop_status <= { lsu_wb, 2'b10 };
        3'b011: iop_status <= { lsu_wb, 2'b11 };
        3'b100: iop_status <= sched_ack ? 3'b001 : 3'b100;
        3'b101: iop_status <= sched_ack ? 3'b010 : 3'b101;
        3'b110: iop_status <= sched_ack ? { iop[22], iop[22], iop[22] } : 3'b110;
        3'b111: iop_status <= sched_ack ? 3'b000 : 3'b111;
        endcase
    end
end

endmodule