module polynomial_mul #(
    parameter WIDTH = 32,
    parameter [WIDTH-1:0] Q = 32'd7681   // Modulus Q (odd prime)
) (
    input  wire               clk,
    input  wire               reset,
    input  wire               start,
    input  wire [WIDTH-1:0]   a0, a1, a2, a3,
    input  wire [WIDTH-1:0]   b0, b1, b2, b3,
    output wire [WIDTH-1:0]   c0, c1, c2, c3,
    output wire               done
);

    // Montgomery-form constants (value * 2^32 mod Q) -- valid for Q = 7681
    localparam [WIDTH-1:0] W1  = 32'd6115;  // NTT stage 1
    localparam [WIDTH-1:0] W2  = 32'd5330;  // NTT stage 2, pair (0,1)
    localparam [WIDTH-1:0] W3  = 32'd4083;  // NTT stage 2, pair (2,3)
    localparam [WIDTH-1:0] WI2 = 32'd1799;  // INTT stage 1, pair (0,1)
    localparam [WIDTH-1:0] WI3 = 32'd5016;  // INTT stage 1, pair (2,3)
    localparam [WIDTH-1:0] WI1 = 32'd783;   // INTT stage 2
    localparam [WIDTH-1:0] R2  = 32'd5564;  // R^2 mod q

    // NTT stage 1 outputs
    wire [WIDTH-1:0] a1_0, a1_1, a1_2, a1_3;
    wire [WIDTH-1:0] b1_0, b1_1, b1_2, b1_3;
    // NTT stage 2 outputs (A_hat, B_hat)
    wire [WIDTH-1:0] a2_0, a2_1, a2_2, a2_3;
    wire [WIDTH-1:0] b2_0, b2_1, b2_2, b2_3;
    // pointwise outputs
    wire [WIDTH-1:0] p1_0, p1_1, p1_2, p1_3;   // A_hat*B_hat*R^-1
    wire [WIDTH-1:0] p2_0, p2_1, p2_2, p2_3;   // corrected
    // INTT stage 1 outputs
    wire [WIDTH-1:0] i1_0, i1_1, i1_2, i1_3;

    wire n1_done, n2_done, pw1_done, pw2_done, i1_done, i2_done;

    // ================= NTT stage 1 (stride 2) =================
    BFU #(.WIDTH(WIDTH), .Q(Q)) n1_a0 (.clk(clk), .reset(reset), .op(1'b1), .A(a0), .B(a2), .W(W1), .W_inv(32'd0), .start(start), .U(a1_0), .V(a1_2), .done(n1_done));
    BFU #(.WIDTH(WIDTH), .Q(Q)) n1_a1 (.clk(clk), .reset(reset), .op(1'b1), .A(a1), .B(a3), .W(W1), .W_inv(32'd0), .start(start), .U(a1_1), .V(a1_3), .done());
    BFU #(.WIDTH(WIDTH), .Q(Q)) n1_b0 (.clk(clk), .reset(reset), .op(1'b1), .A(b0), .B(b2), .W(W1), .W_inv(32'd0), .start(start), .U(b1_0), .V(b1_2), .done());
    BFU #(.WIDTH(WIDTH), .Q(Q)) n1_b1 (.clk(clk), .reset(reset), .op(1'b1), .A(b1), .B(b3), .W(W1), .W_inv(32'd0), .start(start), .U(b1_1), .V(b1_3), .done());

    // ================= NTT stage 2 (stride 1) =================
    BFU #(.WIDTH(WIDTH), .Q(Q)) n2_a0 (.clk(clk), .reset(reset), .op(1'b1), .A(a1_0), .B(a1_1), .W(W2), .W_inv(32'd0), .start(n1_done), .U(a2_0), .V(a2_1), .done(n2_done));
    BFU #(.WIDTH(WIDTH), .Q(Q)) n2_a1 (.clk(clk), .reset(reset), .op(1'b1), .A(a1_2), .B(a1_3), .W(W3), .W_inv(32'd0), .start(n1_done), .U(a2_2), .V(a2_3), .done());
    BFU #(.WIDTH(WIDTH), .Q(Q)) n2_b0 (.clk(clk), .reset(reset), .op(1'b1), .A(b1_0), .B(b1_1), .W(W2), .W_inv(32'd0), .start(n1_done), .U(b2_0), .V(b2_1), .done());
    BFU #(.WIDTH(WIDTH), .Q(Q)) n2_b1 (.clk(clk), .reset(reset), .op(1'b1), .A(b1_2), .B(b1_3), .W(W3), .W_inv(32'd0), .start(n1_done), .U(b2_2), .V(b2_3), .done());

    // ================= Pointwise multiply =================
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw1_0 (.clk(clk), .reset(reset), .start(n2_done), .a(a2_0), .w(b2_0), .result(p1_0), .done(pw1_done));
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw1_1 (.clk(clk), .reset(reset), .start(n2_done), .a(a2_1), .w(b2_1), .result(p1_1), .done());
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw1_2 (.clk(clk), .reset(reset), .start(n2_done), .a(a2_2), .w(b2_2), .result(p1_2), .done());
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw1_3 (.clk(clk), .reset(reset), .start(n2_done), .a(a2_3), .w(b2_3), .result(p1_3), .done());

    // Montgomery correction: x * R^2 * R^-1 = x * R  -> cancels the earlier R^-1
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw2_0 (.clk(clk), .reset(reset), .start(pw1_done), .a(p1_0), .w(R2), .result(p2_0), .done(pw2_done));
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw2_1 (.clk(clk), .reset(reset), .start(pw1_done), .a(p1_1), .w(R2), .result(p2_1), .done());
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw2_2 (.clk(clk), .reset(reset), .start(pw1_done), .a(p1_2), .w(R2), .result(p2_2), .done());
    mod_mult #(.WIDTH(WIDTH), .Q(Q)) pw2_3 (.clk(clk), .reset(reset), .start(pw1_done), .a(p1_3), .w(R2), .result(p2_3), .done());

    // ================= INTT stage 1 (stride 1) =================
    BFU #(.WIDTH(WIDTH), .Q(Q)) i1_a (.clk(clk), .reset(reset), .op(1'b0), .A(p2_0), .B(p2_1), .W(32'd0), .W_inv(WI2), .start(pw2_done), .U(i1_0), .V(i1_1), .done(i1_done));
    BFU #(.WIDTH(WIDTH), .Q(Q)) i1_b (.clk(clk), .reset(reset), .op(1'b0), .A(p2_2), .B(p2_3), .W(32'd0), .W_inv(WI3), .start(pw2_done), .U(i1_2), .V(i1_3), .done());

    // ================= INTT stage 2 (stride 2) =================
    BFU #(.WIDTH(WIDTH), .Q(Q)) i2_a (.clk(clk), .reset(reset), .op(1'b0), .A(i1_0), .B(i1_2), .W(32'd0), .W_inv(WI1), .start(i1_done), .U(c0), .V(c2), .done(i2_done));
    BFU #(.WIDTH(WIDTH), .Q(Q)) i2_b (.clk(clk), .reset(reset), .op(1'b0), .A(i1_1), .B(i1_3), .W(32'd0), .W_inv(WI1), .start(i1_done), .U(c1), .V(c3), .done());

    assign done = i2_done;

endmodule

module tb_polynomial_mul;

    parameter WIDTH = 32;
    parameter [WIDTH-1:0] Q = 32'd7681;

    reg               clk;
    reg               reset;
    reg               start;
    reg  [WIDTH-1:0]  a0, a1, a2, a3;
    reg  [WIDTH-1:0]  b0, b1, b2, b3;
    wire [WIDTH-1:0]  c0, c1, c2, c3;
    wire              done;

    polynomial_mul #(.WIDTH(WIDTH), .Q(Q)) uut (
        .clk(clk), .reset(reset), .start(start),
        .a0(a0), .a1(a1), .a2(a2), .a3(a3),
        .b0(b0), .b1(b1), .b2(b2), .b3(b3),
        .c0(c0), .c1(c1), .c2(c2), .c3(c3),
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
        a0 = 32'd560;  a1 = 32'd2624; a2 = 32'd6099; a3 = 32'd5678;
        b0 = 32'd5257; b1 = 32'd4836; b2 = 32'd1995; b3 = 32'd1574;

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
        $display("Input A  = [%6d, %6d, %6d, %6d]", a0, a1, a2, a3);
        $display("Input B  = [%6d, %6d, %6d, %6d]", b0, b1, b2, b3);
        $display("--------------------------------------------------");
        $display("Result   = [%6d, %6d, %6d, %6d]", c0, c1, c2, c3);
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
        $dumpfile("polynomial_mul.vcd");
        $dumpvars(0, tb_polynomial_mul);
    end

endmodule




