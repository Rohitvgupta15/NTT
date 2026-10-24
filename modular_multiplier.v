// ============================================================
// Top-Level Modular Multiplier
// ============================================================
module mod_mult #(
    parameter WIDTH = 32
)(
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 start,
    input  wire [WIDTH-1:0]     a,
    input  wire [WIDTH-1:0]     w,
    input  wire [WIDTH-1:0]     q,
    output wire [WIDTH-1:0]     result,
    output wire                 done
);

    wire [2*WIDTH-1:0] mult_out;

    // Shift register to align `start` with the 2-cycle latency of `mult_int`
    reg [1:0] start_delay;
    always @(posedge clk or posedge reset) begin
        if (reset)
            start_delay <= 2'b00;
        else
            start_delay <= {start_delay[0], start};
    end

    mult_int #(
        .WIDTH       (WIDTH),
        .CHUNK_WIDTH (16)
    ) m1 (
        .clk   (clk),
        .reset (reset),
        .A     (a),
        .B     (w),
        .C     (mult_out)
    );

    mod_red #(
        .WIDTH (WIDTH)
    ) m2 (
        .clk   (clk),
        .reset (reset),
        .start (start_delay[1]),   // Pulses high when mult_out is valid
        .c     (mult_out),
        .q     (q),
        .res   (result),
        .done  (done)
    );

endmodule



// // ============================================================
// // Testbench
// // ============================================================
// module tb_mod_mult;

//     parameter WIDTH = 32;

//     reg              clk;
//     reg              reset;
//     reg              start;
//     reg  [WIDTH-1:0] a;
//     reg  [WIDTH-1:0] w;
//     reg  [WIDTH-1:0] q;

//     wire [WIDTH-1:0] result;
//     wire             done;

//     mod_mult #(
//         .WIDTH (WIDTH)
//     ) dut (
//         .clk    (clk),
//         .reset  (reset),
//         .start  (start),
//         .a      (a),
//         .w      (w),
//         .q      (q),
//         .result (result),
//         .done   (done)
//     );

//     // Clock generator (100MHz)
//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk;
//     end

//     // Waveform dump
//     initial begin
//         $dumpfile("mod_mult.vcd");
//         $dumpvars(0, tb_mod_mult);
//     end

//     // Test execution task
//     task check_mod_mult(input [WIDTH-1:0] in_a, input [WIDTH-1:0] in_w, input [WIDTH-1:0] in_q);
//         begin
//             @(posedge clk);
//             a     <= in_a;
//             w     <= in_w;
//             q     <= in_q;
//             start <= 1'b1;

//             @(posedge clk);
//             start <= 1'b0;

//             // Wait for reduction to complete
//             @(posedge done);
//             #1;
//             $display("[%0t] A=%0d W=%0d Q=%0d | RES=%0d (done)", $time, in_a, in_w, in_q, result);
//         end
//     endtask

//     // Stimulus
//     initial begin
//         reset = 1;
//         start = 0;
//         a     = 0;
//         w     = 0;
//         q     = 0;

//         #20;
//         reset = 0;
//         #10;

//         // Test 1
//         check_mod_mult(32'd5, 32'd7, 32'd17);

//         // Test 2
//         check_mod_mult(32'd123, 32'd456, 32'd12289);

//         // Test 3
//         check_mod_mult(32'd1000, 32'd2000, 32'd40961);

//         // Random Tests with same Q (reuses computed Q')
//         repeat (10) begin
//             check_mod_mult($urandom % 12289, $urandom % 12289, 32'd12289);
//         end

//         #50;
//         $finish;
//     end

// endmodule