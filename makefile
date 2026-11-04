rtl :
	vcs -full64 -sverilog  package.sv polynomial_mul.v  -o simv  && ./simv

clean : 
	  rm -rf *.vcd *.log simv *.key csrc simv.daidir