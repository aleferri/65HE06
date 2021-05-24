iverilog -o testbench_core.vvp tests/core_tb.v core/*.v
vvp testbench_core.vvp
gtkwave testbench_core.vcd