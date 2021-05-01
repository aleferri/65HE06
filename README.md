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

1. R(3) is source register, flow is A, R -> A
2. W(1) is width 0 is word, 1 is byte
3. C(3) is the condition bit to test in the Status Flags register
4. N(1) is the predicated value of the bit
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
