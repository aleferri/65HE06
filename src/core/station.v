
module station(
    input   wire        clk,
    input   wire        a_rst,
    
    //Instruction Decode Interface
    input   wire        id_feed,
    input   wire[31:0]  id_iop,
    input   wire[2:0]   id_iop_init,
    input   wire[15:0]  id_pc,
    input   wire[15:0]  id_k16,
    output  wire        id_complete,
    
    //LSU Interface
    input   wire[15:0]  lsu_data,
    input   wire        lsu_wb,
    
    //Scheduler Interface
    output  wire        r_ready,            //invariant of inputs, status only
    output  wire        r_will_complete,    //invariant of inputs, status only
    output  wire[15:0]  r_pc,
    output  wire[15:0]  r_k16,
    output  wire[15:0]  r_agu_k16,
    output  wire[2:0]   r_a_adr,
    output  wire[2:0]   r_b_adr,
    output  wire[3:0]   r_d_adr,
    output  wire[3:0]   r_fn,
    output  wire        r_mask_carry,
    output  wire        r_mask_index,
    output  wire        r_save_flags,
    output  wire        r_forward_to_rmw,
    output  wire        r_st_mem,
    output  wire        r_ld_mem,
    output  wire        r_mem_width,
    output  wire        r_bypass_b,
    output  wire        r_lock_loads,       //lock loads,                       invariant
    output  wire[3:0]   r_lock_reg_wr,      //lock register from being read,    invariant
    output  wire[2:0]   r_lock_reg_rd_0,    //lock register from being written  invariant
    output  wire[2:0]   r_lock_reg_rd_1,    //lock register from being written  invariant
    output  wire[2:0]   r_lock_reg_rd_2,    //lock register from being written  invariant
    input   wire        sched_ack
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
 * 02: reserved
 * 01: reserved
 * 00: reserved
 * -----------------------------------
 */

//Flip Flops

reg[31:0] iop;
reg[15:0] iop_pc;

always @(posedge clk) begin
    iop <= id_feed ? id_iop : iop;
    iop_pc <= id_feed ? id_pc : iop_pc;
end

reg[15:0] iop_k16;

always @(posedge clk) begin
    case({lsu_wb, id_feed})
    2'b00: iop_k16 <= iop_k16;
    2'b01: iop_k16 <= id_k16;
    2'b10: iop_k16 <= lsu_data;
    2'b11: iop_k16 <= id_k16;
    endcase
end

/**
 * LOAD_0:      ALU_A = index; ALU_B = x    ; ALU_FN = xxxx; WR_ADDR = 0; ALU_MASK = 0; ALU_SF = 0; ST_MEM = 0        ; LD_MEM = 1 ; ALU_DEST = x
 * LOAD_1:      ALU_A = index; ALU_B = x    ; ALU_FN = ADD ; WR_ADDR = 0; ALU_MASK = 0; ALU_SF = 0; ST_MEM = 0        ; LD_MEM = 1 ; ALU_DEST = index | none
 * ALU_0:       ALU_A = A    ; ALU_B = k | B; ALU_FN = FN  ; WR_ADDR = 1; ALU_MASK = m; ALU_SF = s; ST_MEM = 0        ; LD_MEM = 0 ; ALU_DEST = D | none
 * ALU_1:       ALU_A = index; ALU_B = k    ; ALU_FN = ADD ; WR_ADDR = 0; ALU_MASK = 0; ALU_SF = 0; ST_MEM = 1        ; LD_MEM = 0 ; ALU_DEST = index
 *
 * Steps
 * ALU_IMM : ALU_0
 * ALU_REG : ALU_0
 * ALU_IDX : LOAD_1 -> WAIT_1 -> ALU_0
 * ALU_IDX+: LOAD_1 -> WAIT_1 -> ALU_0                      ; LOAD_1 writeback A + k
 * STR_IDX-: ALU_1                                          ; ALU_1 writeback A + k
 * ALU_IND : LOAD_0 -> WAIT_0 -> LOAD_1 -> WAIT_1 -> ALU_0
 * RMW_IDX : LOAD_1 + RMW_START
 * RMW_IND : LOAD_0 -> WAIT_0 -> LOAD_1 + RMW_START
 * BSR_IMM : ALU_0 -> ALU_1
 * JSR_REG : ALU_0 -> ALU_1
 * JSR_IDX : LOAD_1 -> WAIT_1 -> ALU_0  -> ALU_1
 * JSR_IND : LOAD_0 -> WAIT_0 -> LOAD_1 -> WAIT_1 -> ALU_0 -> ALU_1
 */
 
// Combinatorial
wire offload_rmw = is_status_load_1 & iop[4];
wire write_back_alu = is_status_load_1 & iop[28] | is_status_store & iop[28];

assign id_complete = is_status_complete;

//These signals are expected to be gated outside the station

//These signals are repeatable
assign r_pc = iop_pc;
assign r_k16 = iop_k16;
assign r_agu_k16 = ( is_status_store | iop[29] ) ? iop_k16 : 16'b0;

assign r_mask_index = is_status_load_1 & iop[ 30 ];

assign r_a_adr = is_status_load_0 ? { 1'b1, iop[25:24] } : ( is_status_load_1 | is_status_store ) ? { 1'b1, iop[27:26] } : iop[15:13];
assign r_b_adr = iop[12:10];

//Quite complicated. D top bit (means "do the write") is 1 if doing pre-inc or post-dec during load or if ALU write to register. 
//Lower part is either the address of the index or the register specified by the instruction.
assign r_d_adr = { is_status_alu & iop[9] | write_back_alu, write_back_alu | iop[8], write_back_alu ? iop[27:26] : iop[7:6] };

assign r_fn = ( is_status_load_0 | is_status_load_1 | is_status_store & ~iop[4]) ? 4'b0000 : iop[19:16];

assign r_mask_carry = ~(~is_status_alu | iop[20]);

assign r_save_flags = ( is_status_alu | offload_rmw ) & iop[21];
assign r_forward_to_rmw = offload_rmw;

assign r_st_mem = is_status_store;
assign r_ld_mem = is_status_load_0 | is_status_load_1;
assign r_mem_width = iop[3] & ~is_status_load_0 & ~( iop[23] & is_status_store );

assign r_bypass_b = iop[5];

//Conflicts are implicitly handled for scheduled uOps operands (a, b & d), additional locks are required to specify the terminals reads and writes of the instruction
assign r_lock_loads = iop[22];
assign r_lock_reg_wr = iop[9:6];
assign r_lock_reg_rd_0 = iop[15:13];
assign r_lock_reg_rd_1 = iop[12:10];
assign r_lock_reg_rd_2 = { 1'b1, iop[27:26] };

assign r_ready = iop_status[2];

// State machine implementation
reg[2:0] next_status;

always @(*) begin
    case (iop_status)
        3'b000: next_status = id_iop_init;
        3'b001: next_status = { lsu_wb, 2'b01 };
        3'b010: next_status = { lsu_wb, 2'b10 };
        3'b011: next_status = 3'b111;
        3'b100: next_status = 3'b001;
        3'b101: next_status = { 1'b0, ~iop[28], 1'b0 };
        3'b110: next_status = { iop[23], iop[23], iop[23] };
        3'b111: next_status = 3'b000;
    endcase
end

assign r_will_complete = ( iop_status[0] | iop_status[1] | iop_status[2] ) & ~( next_status[0] | next_status[1] | next_status[2] ); 

always @(posedge clk or posedge a_rst) begin
    if ( a_rst ) begin
        iop_status = 3'b000;
    end else begin
        case (iop_status)
        3'b000: iop_status <= id_feed ? next_status : iop_status;
        3'b001: iop_status <= next_status;
        3'b010: iop_status <= next_status;
        3'b011: iop_status <= next_status;
        3'b100: iop_status <= sched_ack ? next_status : iop_status;
        3'b101: iop_status <= sched_ack ? next_status : iop_status;
        3'b110: iop_status <= sched_ack ? next_status : iop_status;
        3'b111: iop_status <= sched_ack ? next_status : iop_status;
        endcase
    end
end

/*
always @(*) begin
    assert( iop_status[0] == 1'b0 || iop_status[0] == 1'b1 );
    assert( iop_status[1] == 1'b0 || iop_status[1] == 1'b1 );
    assert( iop_status[2] == 1'b0 || iop_status[2] == 1'b1 );
    assert( r_ready == 1'b0 || r_ready == 1'b1 );
end*/

endmodule