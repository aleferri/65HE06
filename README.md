# 65HE06
Prototype implementation of a Pipelined 16 bit Accumulator CPU, inspired by 6502

## Design
### Goals
1. No addressing mode left behind (from the original 6502), but improving or collapsing multiple addressing modes into one is allowed
2. No new registers, only registers already implemented in the original 6502 or later in the 65816 are allowed. Enhancing or expanding them is allowed
3. No support of self modifying code or BCD arithmetic
4. Supporting both 16 bit word and 8 bit bytes
5. Opcode fit in 16 bit.
6.  Argument fit in 16 bit
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
| Indirect Re-Indexed Operand | fffffaaas | w10jjyy |
| Predicated Mov Register | 11100aaas | cccnrrr |
| Predicated Add Register | 11101aaas | cccnrrr |
| Predicated Mov Immediate| 11110aaas | cccnrrr |
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
1. Immediate 8 bit is extended to Immediate 16 bit
2. Absolute 16 bit is remapped as Z + k16
3. Absolute 16 bit indexed by X is remapped as X + k16
4. Indirect Absolute is remapped as (X + k16), Z
5. Zero Page is remapped as Z + k16
6. Zero Page Indexed by X is remapped as X + k16
7. Zero Page indirect indexed by Y is remapped as (Z + k16) + Y
8. Zero Page indirect is remapped as (Z + k16) + Z

## Implementation
### 5 stage variable length, multi cycle pipeline (Failure)
#### Stages
1. IF: instruction fetch, fetch 16 bit from the memory
2. ID: instruction decode, fetch optional arguments, issue operations and registers to the back-end, keep track of busy registers (registers that are being calculated). Prevent failed predicted operations to enter the backend. Re Issue registers to the back end for reindexed mode. Create the uOP opcode that flow through the pipeline. Stall instructions if PC need to be updated or flags are required, but are currently busy.
3. AGU/ALU0: early exit for simple instructions, address calculation for memory operands
4. Load/Store Unit: load/store values from/to memory
5. ALU1: ALU for operations with memory values
#### Problems
1. ID does too much. It need to keep an enormous amount of state, while the last three stages of the pipeline has almost no state. IF does almost nothing.
2. IF fetch 16 bit/clock, but 32 bit instructions are common. It is useless to pipeline to get at most 0.5 op/cycle. A simpler implementation with a big late stage that do everything with microcode is already capable of 0.5 ipc (See my other repository 6516). There is no point to waste ton of resources if there is nothing to gain.
3. With registers checked at ID stage there is a guaranteed full pipeline flush as 3/8 registers are required to be not busy. Considering C mem* functions, all implementations will be something like `LD A, (S, src), Y; ST A, (S, dest), Y; ADD Y, #1`. In the specified sequence everything stall for the entire pipeline  (1°: 1 IF + 3 ID + 2 AGU + 2 MEM + 1 ALU, 2°: 1 ID, 2 AGU + 1 MEM)

| OP | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14
|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|
| LD A, (S, src), Y | IF | ID | ID | ID ALU0 | ALU0 | ALU0 | MEM | MEM | ALU1 |
| ST A, (S, dest), Y | - | - | IF | IF | ID | ID | ID | ID | ID | ID |ID ALU0 | ALU0 | ALU0 | MEM

A single memory transfer in 14 clock cycles is something that even the original 6502 could do, and without the two channels required here. Re-Indexed mode cannot be so slow that is useless. Since there is a limited set of registers and memory accesses are frequents Load/Stores cannot stall the pipeline.  

#### Conclusion
The pipeline need to be redesigned from scratch. Either a register renaming scheme is required or the register file need to be put near the execution units and busy/not busy deferred or avoided. IF is required to implement his own ALU and require a single port to handle predicated instructions that store on PC. A prefetch is needed to push 2 16 bit words/clock on IF.
Model of next prototype (Prefetch considered extern for the moment)
1. IF: fetch 2 16 bit words, IF then send a complete instruction to ID
2. ID: transform a 16 bit opcode in a 32 bit one, expanding all fields and present it to the execution unit when needed. ID issue back the expanded opcode to IF as well to let it handle predication
3. ALU: fetch expanded opcode, select inputs and calculate output, destination is itself or memory. Keeps the list of busy registers. WB pseudo operation is when Memory Write to Register file, while ALU is not writing back to register file (e.g. writing to the address)
4. MEM: fetch address and data from ALU, push back to register file

#### Proposed Schedule for the new pipeline
| OP | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10
|--|--|--|--|--|--|--|--|--|--|--|--|
| LD A, (S, src), Y | IF | ID | ALU | MEM | ALU | MEM | ALU
| ST A, (S, dest), Y | - | IF | ID | ALU | MEM | WB | - | ALU | MEM

### 4/8 Stage Multi cycle interlieved Micro-Executed Pipeline
Given the aforementioned requirements and conclusions, a new pipeline is being developed.
The interlieved execution of Memory Operations simplify the state tracking and improve performance delaying the stall until the last possible moment.
The new pipeline is composed of
1. IF: fetch 2 16 bit words and feed them to ID
2. ID: use the opcode to generate at most 3 uOp/cycle and feed them to the Microcore Reservation Stations (A & B).
3. Microcore Select uOp: select next uOp and load them in the uOp register
4. Microcore ALU: execute the selected uOp and start a memory cycle if required
5. Microcore MEM: execute writes, execute loads and save the result in the temporary register of the relative Reservation Station (Register TA for RSA, Register TB for RSB). 
The Microcore Repeat stages 3-5 until execution complete. During Main memory cycles, use ALU to execute Spot ALU operations. Load a new operation when needed. During stalls, ID will feed a NOP.

| OP | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10
|--|--|--|--|--|--|--|--|--|--|--|--|
| LD A, (S, src), Y | IF | ID | RS | ALU | MEM | ALU | MEM | ALU
| ST A, (S, dest), Y | - | IF | ID | RS | ALU | MEM | NOP | - | ALU | MEM
