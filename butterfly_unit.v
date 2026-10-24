module BFU #(
    parameter WIDTH = 32
) (
    input                  clk,
    input                  reset,
    input  [WIDTH - 1 : 0] A,
    input  [WIDTH - 1 : 0] B,
    input  [WIDTH - 1 : 0] W,     // twiddle in Montgomery form: W * 2^WIDTH mod q
    input  [WIDTH - 1 : 0] q,
    input                  start,
    input                  op,    // 0 = NTT , 1 = INTT

    output [WIDTH - 1 : 0] u,
    output [WIDTH - 1 : 0] v,
    output                 done
);
//   for NTT
//  using Cooley-Tukey (CT)
//   U = A + W * B mod q
//   V = A - W * B mod q

//   for INTT
//  using Gentleman-Sande (GS)
//   U = A + B mod q
//   V = (A - B) * W mod q

//  mod_mult returns x * W * 2^-WIDTH mod q, so passing W in Montgomery
//  form makes the product x * W mod q.
//  Both modes share one multiplier: NTT multiplies B, INTT multiplies (A - B).
    wire [WIDTH - 1 : 0] a_minus_b;    // (A - B) mod q
    wire [WIDTH - 1 : 0] mult_in;      // NTT: B ,     INTT: A - B
    wire [WIDTH - 1 : 0] mult_out;     // NTT: W*B ,   INTT: (A - B)*W
    wire [WIDTH - 1 : 0] add_in;       // NTT: W*B ,   INTT: B
    wire [WIDTH - 1 : 0] a_plus;       // NTT: A + W*B , INTT: A + B
    wire [WIDTH - 1 : 0] a_minus_wb;   // A - W*B (NTT only)

    // Hold A, B and op until the multiplier result is ready
    reg  [WIDTH - 1 : 0] a_reg;
    reg  [WIDTH - 1 : 0] b_reg;
    reg                  op_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            a_reg  <= {WIDTH{1'b0}};
            b_reg  <= {WIDTH{1'b0}};
            op_reg <= 1'b0;
        end
        else if (start) begin
            a_reg  <= A;
            b_reg  <= B;
            op_reg <= op;
        end
    end

    // INTT: A - B before the multiplier
    mod_sub #(
        .WIDTH (WIDTH)
    ) u_sub_ab (
        .a      (A),
        .b      (B),
        .q      (q),
        .result (a_minus_b)
    );

    assign mult_in = op ? a_minus_b : B;

    mod_mult #(
        .WIDTH (WIDTH)
    ) u_mult (
        .clk    (clk),
        .reset  (reset),
        .start  (start),
        .a      (mult_in),
        .w      (W),
        .q      (q),
        .result (mult_out),
        .done   (done)
    );

    assign add_in = op_reg ? b_reg : mult_out;

    mod_add #(
        .WIDTH (WIDTH)
    ) u_add (
        .a      (a_reg),
        .b      (add_in),
        .q      (q),
        .result (a_plus)
    );

    // NTT: A - W*B after the multiplier
    mod_sub #(
        .WIDTH (WIDTH)
    ) u_sub_wb (
        .a      (a_reg),
        .b      (mult_out),
        .q      (q),
        .result (a_minus_wb)
    );

    assign u = a_plus;
    assign v = op_reg ? mult_out : a_minus_wb;

endmodule



// ============================================================
// Testbench
// ============================================================
module tb_bfu;

    localparam NTT  = 1'b0;
    localparam INTT = 1'b1;

    reg         clk = 0;
    reg         reset = 1;
    reg         start = 0;
    reg         op = NTT;
    reg  [31:0] A = 0, B = 0, W = 0, Q = 0;

    wire [31:0] u, v;
    wire        done;

    integer errors = 0;
    integer tests  = 0;

    BFU dut (
        .clk   (clk),
        .reset (reset),
        .A     (A),
        .B     (B),
        .W     (W),
        .q     (Q),
        .start (start),
        .op    (op),
        .u     (u),
        .v     (v),
        .done  (done)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("bfu.vcd");
        $dumpvars(0, tb_bfu);
    end

    // Apply one butterfly and compare with the expected result.
    // a, b, w must be < q; q must be odd; w is a plain twiddle.
    task check(input mode, input [63:0] a, input [63:0] b, input [63:0] w, input [63:0] q);
        reg [63:0] r, wb, exp_u, exp_v;
        begin
            r = (64'd1 << 32) % q;                   // 2^32 mod q, for Montgomery form
            if (mode == NTT) begin                   // CT
                wb    = b * w % q;
                exp_u = (a + wb) % q;
                exp_v = (a + q - wb) % q;
            end else begin                           // GS
                exp_u = (a + b) % q;
                exp_v = (a + q - b) % q * w % q;
            end

            @(posedge clk);
            A     <= a;
            B     <= b;
            W     <= w * r % q;
            Q     <= q;
            op    <= mode;
            start <= 1;
            @(posedge clk);
            start <= 0;
            @(posedge done);
            #1;

            tests = tests + 1;
            if (u !== exp_u[31:0] || v !== exp_v[31:0])
                errors = errors + 1;

            $display("%4d | %s | %6d | %6d %6d %6d | %6d %6d | %6d %6d | %s",
                     tests, mode ? "INTT" : "NTT ", q, a, b, w, u, v, exp_u, exp_v,
                     (u === exp_u[31:0] && v === exp_v[31:0]) ? "PASS" : "FAIL");
        end
    endtask

    initial begin
        #20 reset = 0;

        $display("");
        $display("   # | MODE |      q |      a      b      w |      u      v |  exp_u  exp_v | RESULT");
        $display("-----+------+--------+----------------------+---------------+---------------+-------");

        //     mode  a      b      w      q
        check(NTT,  3,     5,     7,     17);
        check(NTT,  100,   123,   456,   12289);
        check(NTT,  0,     12288, 12288, 12289);   // v wraps
        check(NTT,  12288, 1,     1,     12289);   // u wraps
        check(NTT,  1000,  2000,  3000,  40961);

        check(INTT, 3,     5,     7,     17);
        check(INTT, 100,   123,   456,   12289);   // a < b
        check(INTT, 12288, 12288, 5,     12289);   // u wraps, a - b = 0
        check(INTT, 1000,  2000,  3000,  40961);

        // random values for a few moduli
        repeat (10) check($urandom % 2, $urandom % 12289, $urandom % 12289, $urandom % 12289, 12289);
        repeat (10) check($urandom % 2, $urandom % 3329,  $urandom % 3329,  $urandom % 3329,  3329);
        repeat (10) check($urandom % 2, $urandom % 40961, $urandom % 40961, $urandom % 40961, 40961);

        $display("-----+------+--------+----------------------+---------------+---------------+-------");
        $display("Total: %0d   Passed: %0d   Failed: %0d", tests, tests - errors, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("SOME TESTS FAILED");
        $display("");
        $finish;
    end

endmodule
