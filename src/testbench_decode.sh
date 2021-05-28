iverilog -o testbench_decode.vvp tests/decode_tb.v core/*.v
vvp testbench_decode.vvp
gtkwave testbench_decode.vcd
