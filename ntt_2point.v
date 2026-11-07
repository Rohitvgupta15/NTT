// ============================================================
// 2-point negacyclic NTT-based polynomial multiplier
//   c(x) = a(x) * b(x)  mod (x^2 + 1, Q)
//
//   NTT  : 1 Cooley-Tukey stage   (W  = psi,           Montgomery form)
//   PW   : 2 pointwise mults      (result carries R^-1)
//   INTT : 1 Gentleman-Sande stage, OP=2 (multiplies both outputs by R,
//          cancelling the R^-1 left by the pointwise Montgomery mult)
//   psi = 1600 is a primitive 4th root of unity mod 3329 (psi^2 = -1)
// ============================================================
module ntt_2point #(
    parameter WIDTH = 12,
    parameter [WIDTH-1:0] Q = 32'd3329   // Modulus Q (odd prime)
) (
    input  wire               clk,
    input  wire               reset,
    input  wire               start,
    input  wire [WIDTH-1:0]   a0, a1,
    input  wire [WIDTH-1:0]   b0, b1,      // plain (normal) form, 0 <= b < Q
    output wire [WIDTH-1:0]   c0, c1,
    output wire               done
);

    // for Q == 3329, R = 2^12
    localparam [WIDTH-1:0] W  = 12'd2128;  // psi * R            (psi = 1600)
    localparam [WIDTH-1:0] WI = 12'd2846;  // psi^-1 * 1/2 * R^2 (scaled, OP=2 stage)

    // NTT outputs (A_hat, B_hat)
    wire [WIDTH-1:0] a1_0, a1_1;
    wire [WIDTH-1:0] b1_0, b1_1;
    // pointwise outputs
    wire [WIDTH-1:0] p_0, p_1;

    wire n_done, pw_done, i_done;

    // ================= NTT =================
    BFU #(.WIDTH(WIDTH), .Q(Q), .OP(1)) n_a (.clk(clk), .reset(reset), .A(a0), .B(a1), .W(W), .W_inv(32'd0), .start(start), .U(a1_0), .V(a1_1), .done(n_done));
    BFU #(.WIDTH(WIDTH), .Q(Q), .OP(1)) n_b (.clk(clk), .reset(reset), .A(b0), .B(b1), .W(W), .W_inv(32'd0), .start(start), .U(b1_0), .V(b1_1), .done());

    // ================= Pointwise multiply =================
    // mont(A_hat, B_hat) = A_hat*B_hat*R^-1 ; the R^-1 is removed by the OP=2 INTT stage
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw_0 (.clk(clk), .reset(reset), .start(n_done), .a(a1_0), .w(b1_0), .result(p_0), .done(pw_done));
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw_1 (.clk(clk), .reset(reset), .start(n_done), .a(a1_1), .w(b1_1), .result(p_1), .done());

    // ================= INTT =================
    BFU #(.WIDTH(WIDTH), .Q(Q), .OP(2)) i_a (.clk(clk), .reset(reset), .A(p_0), .B(p_1), .W(32'd0), .W_inv(WI), .start(pw_done), .U(c0), .V(c1), .done(i_done));

    assign done = i_done;

endmodule

module tb_ntt_2point;

    parameter WIDTH = 12;
    parameter [WIDTH-1:0] Q = 32'd3329;

    reg               clk;
    reg               reset;
    reg               start;
    reg  [WIDTH-1:0]  a0, a1;
    reg  [WIDTH-1:0]  b0, b1;
    wire [WIDTH-1:0]  c0, c1;
    wire              done;

    // Expected: (a0 + a1 x)(b0 + b1 x) mod (x^2 + 1)
    //   c0 = a0*b0 - a1*b1,  c1 = a0*b1 + a1*b0   (mod Q)
    reg  [WIDTH-1:0]  e0, e1;

    ntt_2point #(.WIDTH(WIDTH), .Q(Q)) uut (
        .clk(clk), .reset(reset), .start(start),
        .a0(a0), .a1(a1),
        .b0(b0), .b1(b1),
        .c0(c0), .c1(c1),
        .done(done)
    );

    // Clock: period 10
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        start = 0;
        a0 = 32'd1;  a1 = 32'd2;
        b0 = 32'd3; b1 = 32'd4;

        // 32-bit math so the products don't overflow WIDTH bits
        e0 = ((32'd0 + a0 * b0) % Q + Q - (32'd0 + a1 * b1) % Q) % Q;
        e1 = ((32'd0 + a0 * b1) % Q + (32'd0 + a1 * b0) % Q) % Q;

        // Release reset, then give a one-clock start pulse aligned to the clock
        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for done (pulse), then sample
        @(posedge done);
        #1;

        $display("==================================================");
        $display("Polynomial multiplication completed at t=%0t", $time);
        $display("Input A  = [%6d, %6d]", a0, a1);
        $display("Input B  = [%6d, %6d]", b0, b1);
        $display("--------------------------------------------------");
        $display("Result   = [%6d, %6d]", c0, c1);
        $display("Expected = [%6d, %6d]  %s", e0, e1,
                 (c0 == e0 && c1 == e1) ? "PASS" : "FAIL");
        $display("==================================================");

        #20 $finish;
    end

    // Timeout so the sim never hangs if done never comes
    initial begin
        #100000;
        $display("TIMEOUT: done never asserted");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("ntt_2point.vcd");
        $dumpvars(0, tb_ntt_2point);
    end

endmodule
