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
    input                   op, // 0 = NTT , 1 = INTT

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


//  mod_mult returns B * W * 2^-WIDTH mod q, so passing W in Montgomery
//  form makes wb = B * W mod q.
    wire [WIDTH - 1 : 0] wb;
    // reg  [WIDTH - 1 : 0] u_ntt;
    // reg  [WIDTH - 1 : 0] v_ntt;
    // reg  [WIDTH - 1 : 0] u_intt;
    // reg  [WIDTH - 1 : 0] v_intt;

    // Hold A until the multiplier result is ready
    reg  [WIDTH - 1 : 0] a_reg;
    always @(posedge clk or posedge reset) begin
        if (reset)
            a_reg <= {WIDTH{1'b0}};
        else if (start)
            a_reg <= A;
    end
    // for NTT
    mod_mult #(
        .WIDTH (WIDTH)
    ) m_mul (
        .clk    (clk),
        .reset  (reset),
        .start  (start),
        .a      (B),
        .w      (W),
        .q      (q),
        .result (wb),
        .done   (done)
    );

    mod_add #(
        .WIDTH (WIDTH)
    ) m_add (
        .a      (a_reg),
        .b      (wb),
        .q      (q),
        .result (u)
    );

    mod_sub #(
        .WIDTH (WIDTH)
    ) m_sub (
        .a      (a_reg),
        .b      (wb),
        .q      (q),
        .result (v)
    );

    // // for INTT
    // reg [WIDTH - 1 : 0] U_RES
    // mod_red #(
    //     .WIDTH (WIDTH)
    // ) m2 (
    //     .clk   (clk),
    //     .reset (reset),
    //     .start (start),   
    //     .c     (B),
    //     .q     (q),
    //     .res   (result),
    //     .done  (done)
    // );

endmodule



// ============================================================
// Testbench
// ============================================================
module tb_bfu;

    parameter WIDTH = 32;

    reg              clk;
    reg              reset;
    reg              start;
    reg  [WIDTH-1:0] A;
    reg  [WIDTH-1:0] B;
    reg  [WIDTH-1:0] W;
    reg  [WIDTH-1:0] q;

    wire [WIDTH-1:0] u;
    wire [WIDTH-1:0] v;
    wire             done;

    integer errors;

    BFU #(
        .WIDTH (WIDTH)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .A     (A),
        .B     (B),
        .W     (W),
        .q     (q),
        .start (start),
        .u     (u),
        .v     (v),
        .done  (done)
    );

    // Clock generator (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Waveform dump
    initial begin
        $dumpfile("bfu.vcd");
        $dumpvars(0, tb_bfu);
    end

    // Run one butterfly and compare against a reference model.
    // in_w is the plain twiddle; it is converted to Montgomery form here.
    task check_bfu(input [WIDTH-1:0] in_a, input [WIDTH-1:0] in_b,
                   input [WIDTH-1:0] in_w, input [WIDTH-1:0] in_q);
        reg [2*WIDTH-1:0] w_mont;
        reg [2*WIDTH-1:0] wb;
        reg [WIDTH-1:0]   exp_u, exp_v;
        begin
            w_mont = ({{WIDTH{1'b0}}, in_w} << WIDTH) % in_q;
            wb     = ({{WIDTH{1'b0}}, in_b} * in_w) % in_q;
            exp_u  = (in_a + wb) % in_q;
            exp_v  = (in_a + in_q - wb) % in_q;

            @(posedge clk);
            A     <= in_a;
            B     <= in_b;
            W     <= w_mont[WIDTH-1:0];
            q     <= in_q;
            start <= 1'b1;

            @(posedge clk);
            start <= 1'b0;

            @(posedge done);
            #1;
            if (u !== exp_u || v !== exp_v) begin
                errors = errors + 1;
                $display("[%0t] FAIL A=%0d B=%0d W=%0d Q=%0d | U=%0d (exp %0d) V=%0d (exp %0d)",
                         $time, in_a, in_b, in_w, in_q, u, exp_u, v, exp_v);
            end else
                $display("[%0t] PASS A=%0d B=%0d W=%0d Q=%0d | U=%0d V=%0d",
                         $time, in_a, in_b, in_w, in_q, u, v);
        end
    endtask

    // Stimulus
    initial begin
        errors = 0;
        reset  = 1;
        start  = 0;
        A      = 0;
        B      = 0;
        W      = 0;
        q      = 0;

        #20;
        reset = 0;
        #10;

        check_bfu(32'd3,     32'd5,    32'd7,     32'd17);
        check_bfu(32'd100,   32'd123,  32'd456,   32'd12289);
        check_bfu(32'd0,     32'd12288, 32'd12288, 32'd12289);   // V wraps
        check_bfu(32'd12288, 32'd1,    32'd1,     32'd12289);    // U wraps
        check_bfu(32'd1000,  32'd2000, 32'd3000,  32'd40961);

        repeat (20) begin
            check_bfu($urandom % 12289, $urandom % 12289, $urandom % 12289, 32'd12289);
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);

        #50;
        $finish;
    end

endmodule
