// Simple testbench for SRAM_256_12 (256 words x 12 bits)
// Compile with +define+ARM_UD_MODEL (selects the 12-bit model)
`timescale 1ns/1ps

module tb_sram;
  localparam BITS  = 12;
  localparam WORDS = 256;

  reg              CLK = 0;
  reg              CEN = 1;      // active low chip enable
  reg              WEN = 1;      // active low write enable
  reg  [7:0]       A   = 0;
  reg  [BITS-1:0]  D   = 0;
  wire [BITS-1:0]  Q;
  wire             CENY, WENY;
  wire [7:0]       AY;
  wire [BITS-1:0]  DY;

  SRAM_256_12 u_sram (
    .CENY(CENY), .WENY(WENY), .AY(AY), .DY(DY), .Q(Q),
    .CLK(CLK), .CEN(CEN), .WEN(WEN), .A(A), .D(D),
    .EMA(3'b000), .EMAW(2'b00), .EMAS(1'b0),
    .TEN(1'b1), .BEN(1'b1), .TCEN(1'b1), .TWEN(1'b1),
    .TA(8'b0), .TD({BITS{1'b0}}), .TQ({BITS{1'b0}}),
    .RET1N(1'b1), .STOV(1'b0)
  );

  always #5 CLK = ~CLK;   // 100 MHz

  integer i, fd;
  integer errors = 0;
  reg [BITS-1:0] expected [0:WORDS-1];

  // ---------------- helper tasks ----------------
  task sram_write(input [7:0] addr, input [BITS-1:0] data);
    begin
      @(negedge CLK);
      CEN = 0; WEN = 0; A = addr; D = data;
      @(posedge CLK); #1;
      if (Q !== data) begin   // write-through check
        $display("ERROR write-thru addr=%0d exp=%h got=%h", addr, data, Q);
        errors = errors + 1;
      end
      @(negedge CLK);
      CEN = 1; WEN = 1;
    end
  endtask

  task sram_read_check(input [7:0] addr, input [BITS-1:0] exp);
    begin
      @(negedge CLK);
      CEN = 0; WEN = 1; A = addr;
      @(posedge CLK); #1;
      if (Q !== exp) begin
        $display("ERROR read addr=%0d exp=%h got=%h", addr, exp, Q);
        errors = errors + 1;
      end
      @(negedge CLK);
      CEN = 1;
    end
  endtask

  // ---------------- test sequence ----------------
  initial begin
    $dumpfile("tb_sram.vcd");
    $dumpvars(0, tb_sram);

    // ===== Test 1 : load memory from file, then read =====
    $display("Test 1: loadmem + read");
    fd = $fopen("sram_init.hex", "w");
    for (i = 0; i < WORDS; i = i + 1) begin
      expected[i] = (i * 13 + 7) % 3329;      // values < Q=3329
      $fdisplay(fd, "%h", expected[i]);
    end
    $fclose(fd);

    #12;                                    // CEN is high here (required by loadmem)
    u_sram.loadmem("sram_init.hex");

    for (i = 0; i < WORDS; i = i + 1)
      sram_read_check(i, expected[i]);
    $display("  done, errors so far = %0d", errors);

    // ===== Test 2 : write through ports, then read =====
    $display("Test 2: write + read");
    for (i = 0; i < WORDS; i = i + 1) begin
      expected[i] = (WORDS - i) * 11 % 3329;
      sram_write(i, expected[i]);
    end
    for (i = 0; i < WORDS; i = i + 1)
      sram_read_check(i, expected[i]);
    $display("  done, errors so far = %0d", errors);

    // ===== Test 3 : Q holds when CEN = 1 =====
    $display("Test 3: output hold when CEN=1");
    sram_read_check(8'd5, expected[5]);
    @(negedge CLK); A = 8'd9;               // change address, CEN still high
    @(posedge CLK); #1;
    if (Q !== expected[5]) begin
      $display("ERROR hold exp=%h got=%h", expected[5], Q);
      errors = errors + 1;
    end

    if (errors == 0) $display("*** ALL TESTS PASSED ***");
    else             $display("*** FAILED : %0d errors ***", errors);
    $finish;
  end
endmodule
