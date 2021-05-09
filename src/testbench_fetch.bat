iverilog -o testbench_fetch.vvp tests/fe_tb.v core/fetch_unit.v
vvp testbench_fetch.vvp
gtkwave testbench_fetch.vcd