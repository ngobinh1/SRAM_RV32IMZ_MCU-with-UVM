vlog *.v *.sv
vsim -voptargs="+acc" -c -do "run -all" tb_top +UVM_TESTNAME=riscv_full_test