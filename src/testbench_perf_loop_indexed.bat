iverilog -g2012 -o testbench_indexed.vvp tests/perf_indexed.v core/*.v
vvp testbench_indexed.vvp
gtkwave testbench_indexed.vcd