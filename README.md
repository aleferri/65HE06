# 65HE06
Prototype implementation of a Pipelined 16 bit Accumulator CPU, inspired by 6502. HE mean Half-word Extended, with a 32 bit word.

## Design
### Goals
1. No addressing mode left behind (from the original 6502), but improving or collapsing multiple addressing modes into one is allowed
2. No new registers, only registers already implemented in the original 6502 or later in the 65816 are allowed. Enhancing or expanding them is allowed
3. No support of self modifying code or BCD arithmetic
4. Supporting both 16 bit word and 8 bit bytes
5. Opcode fit in 16 bit.
6. Argument fit in 16 bit
7. Final core is synthetizable and is written in verilog
8. Try to perform less than 2 clock per instruction

### Instruction Encoding

1. 5 bit opcode
2. 3 bit accumulator
3. 1 bit save flags
4. 7 bit left for different families

| Instruction Family | Fixed Encoding | Specific encoding |
|--|--| -- |
| Immediate Operand | fffffaaas | 0010000 |
| Register Operand | fffffaaas | 0000rrr |
| Indexed Operand | fffffaaas | w10jj00 |
| Indirect Indexed Operand | fffffaaas | w11jjyy |
| Predicated Add Register | 11101aaas | cccnrrr |
| Predicated Add Immediate| 11111aaas | cccnrrr |

1. R(3) is source register, flow is: OP(A, R) -> A
2. W(1) is width, if 0 the size is word, if 1 the size is byte
3. C(3) is the index of the first 8 bit of Status Flags
4. N(1) is the predicated value of the selected bit
5. J(2) is the index register for indexed and reindexed modes
6. Y(2) is the post-index register for the reindexed mode

### Register Set
1. 4 Accumulators: A, B, SF, PC
2. 4 Indexes: S, X, Y, Z
3. Z is conventionally 0

### Remapping original addressing modes
1. #imm is extended to 16 bit
2. Abs is remapped as Z + k16
3. Abs, X is remapped as X + k16
4. Abs, Y is remapped as Y + k16
5. (Abs) is remapped as (Z + k16), Z
6. ZP is remapped as Z + k16
7. ZP, X is remapped as X + k16
8. ZP, Y is remapped as Y + k16
9. (ZP, X) is remapped as (X + k16), Z
10. (ZP), Y is remapped as (Z + k16), Y
11. (ZP) is remapped as (Z + k16), Z

## Implementation 1
### 5 stage variable length, multi cycle pipeline (Failure)
#### Stages
1. IF: instruction fetch, fetch 16 bit from the memory
2. ID: instruction decode, fetch the optional argument, issue operations and registers to the back-end, keep track of busy registers (registers that are being calculated). Prevent failed predicted operations to enter the backend. Re Issue registers to the back end for reindexed mode. Create the uOP opcode that flow through the pipeline. Stall instructions if PC need to be updated or flags are required, but are currently busy.
3. AGU/ALU0: early exit for simple instructions, address calculation for memory operands. Multi stage
4. Load/Store Unit: load/store values from/to memory.
5. ALU1: ALU for operations with memory values.
#### Problems
1. ID does too much. It needs to keep an enormous amount of state, while the last three stages of the pipeline have almost no state. IF does almost nothing.
2. IF fetch 16 bit/clock, but 32 bit instructions are common. It is useless to pipeline the core to get at most 0.5 op/cycle on frequent operations. A simpler implementation with a single microcoded late stage that do everything is already capable of 0.5 ipc for the common opcodes (See my other repository 6516). There is no point to waste ton of resources to gain nothing.
3. With registers checked at ID stage there is a guaranteed full pipeline flush everytime someone write a register since 3/8 registers are required to be not busy . Considering C mem* functions, all implementations will be something like `LD A, (S, src), Y; ST A, (S, dest), Y; ADD Y, #1`. In the specified sequence everything stall for multiple stages (1°: 1 IF + 3 ID + 2 AGU + 2 MEM, 2°: 1 ID, 2 AGU + 1 MEM)
4. No writeback to memory as writeback is impossible with this configuration. While most of rmw operands opcodes are not needed because their performance is bad: e.g. "LSR B, mem; ADD A, B; ST B, mem;" is faster than "LSR mem; ADD A, mem;", atomic operations are popular and registers spills come with great cost.

Example pipeline run with this configuration of a memory transfer between two array with pointer on stack, index in Y.

| OP | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14
|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|
| LD A, (S, src), Y | IF | ID | ID | ID ALU0 | ALU0 | ALU0 | MEM | MEM | ALU1 |
| ST A, (S, dest), Y | - | - | IF | IF | ID | ID | ID | ID | ID | ID |ID ALU0 | ALU0 | ALU0 | MEM

A single memory transfer in 14 clock cycles is something that even the original 6502 could do, and without the two channels required here. Indirect Indexed mode cannot be so slow that is useless. Since there is a limited set of registers and memory accesses are frequents, Load/Stores must not stall the pipeline.  

#### Conclusion
The pipeline need to be redesigned from scratch. Either a register renaming scheme is required or the register file need to be put near the execution units and busy/not busy deferred or avoided. IF is required to implement his own ALU and require a single port to handle predicated instructions that store on PC. A prefetch is needed to push 2 16 bit words/clock on IF.
Model of next prototype (Prefetch considered extern for the moment)
1. IF: fetch 2 16 bit words, IF then send a complete instruction to ID
2. ID: transform a 16 bit opcode in a 32 bit one, expanding all fields and present it to the execution unit when needed. ID issue back the expanded opcode to IF as well to let it handle predication
3. ALU: fetch expanded opcode, select inputs and calculate output, destination is itself or memory. Keeps the list of busy registers. WB pseudo operation is when Memory Write to Register file, while ALU is not writing back to register file (e.g. writing to the address)
4. MEM: fetch address and data from ALU, push back to register file

#### Proposed Schedule for the new pipeline
| OP | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
|--|--|--|--|--|--|--|--|--|--|
| LD A, (S, src), Y | IF | ID | ALU | MEM | ALU | MEM | ALU
| ST A, (S, dest), Y | - | IF | ID | ALU | MEM | WB | - | ALU | MEM

## Implementation 2
### 4/8 Stage Multi cycle interlieved Micro-Executed Pipeline
Given the aforementioned requirements and conclusions, a new pipeline is being developed.
The interlieved execution of Memory Operations simplify the state tracking and improve performance by delaying the stall until the last possible moment.
The new pipeline is composed of
1. IF: fetch 2 16 bit words and feed them to ID
2. ID: use the opcode to generate at most 3 uOp/cycle and feed them to the Microcore Reservation Stations (A & B).
3. Microcore SCHED: select next uOp and load it in the uOp register. Wait uOps that require busy registers. Note that Main RS doesn't check for busy registers.
4. Microcore ALU: execute the selected uOp and start a memory cycle if required
5. Microcore MEM: execute writes, execute loads and save the result in the temporary register of the relative Reservation Station (Register TA for RSA, Register TB for RSB). 
The Microcore Repeat stages 3-5 until the execution is complete. During Main memory cycles, the wasted cycle is instead used to perform useful ALU operations. Load a new operation when needed. During stalls, ID will feed a NOP.

| OP | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11
|--|--|--|--|--|--|--|--|--|--|--|--|
| SUB? Y, #1 | IF | ID | SCHED | ALU
| LD A, (S, src), Y | - | IF | ID | SCHED | ALU | MEM | ALU | MEM | ALU
| ST A, (S, dest), Y | - | - | IF | ID | SCHED | ALU | MEM | SCHED | SCHED | ALU | MEM
| BNE SUB | - | - | - | IF | ID | ID | ID | ID | ID | SCHED | ALU | 

### Performances so far
100 byte transfer using indirect indexed complete in 800 clocks, using direct indexed it requires only 600 clocks. Current performance is two/three fold of the original 6502, so the large implementation did improve performance in a meaningful way.

### TODO
Evaluate further code speedup. 
