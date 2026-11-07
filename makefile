rtl_4 :
	vcs -full64 -sverilog  package.sv ntt_4point.v  -o simv  && ./simv

clean : 
	  rm -rf *.vcd *.log simv *.key csrc *.daidir

rtl_2 :
	vcs -full64 -sverilog  package.sv ntt_2point.v  -o simv  && ./simv
sram :
	vcs -full64 -sverilog +define+ARM_UD_MODEL SRAM_256_12.v tb_sram.v -o simv_sram && ./simv_sram

ntt256 :
	vcs -full64 -sverilog package.sv ntt_256point.v tb_ntt_256point.v -o simv_ntt256 && ./simv_ntt256

ntt256_pipeline :
	vcs -full64 -sverilog package.sv ntt_256pipelined.v tb_ntt_256point.v -o simv_ntt256 && ./simv_ntt256
