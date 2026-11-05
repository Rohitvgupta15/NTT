// ============================================================
// Montgomery Reduction Unit (FSM-free, 1-cycle latency)
//   res = (C * R^-1) mod Q,  R = 2^WIDTH
//   Q is a compile-time parameter; Q' is computed at elaboration.
// ============================================================
module mod_red #(
    parameter WIDTH = 32,                    // Bit-width (R = 2^WIDTH)
    parameter [WIDTH-1:0] Q = 32'd7681       // Modulus Q (odd prime)
)(
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 start,       // Input valid pulse
    input  wire [2*WIDTH-1:0]   c,           // Input product C = A * B
    output reg  [WIDTH-1:0]     res,         // Reduced output: (C * R^-1) mod Q
    output reg                  done         // Pulsed high when res is valid
);

    // --------------------------------------------------------
    // Q' = -Q^-1 mod 2^WIDTH  (constant function, Newton-Raphson)
    //   x_{k+1} = x_k * (2 - Q * x_k)  mod 2^WIDTH
    // --------------------------------------------------------
    function [WIDTH-1:0] calc_qprime;
        input [WIDTH-1:0] qv;
        reg   [WIDTH-1:0] x;
        integer k;
        begin
            x = {{(WIDTH-1){1'b0}}, 1'b1};               // Seed: 1 (valid mod 2 for odd Q)
            for (k = 0; k < $clog2(WIDTH) + 1; k = k + 1)
                x = x * ({{(WIDTH-2){1'b0}}, 2'b10} - qv * x);
            calc_qprime = (~x) + 1'b1;                   // negate
        end
    endfunction

    localparam [WIDTH-1:0] Q_PRIME = calc_qprime(Q);

    // REDC combinational datapath
    wire [WIDTH-1:0] m   = c[WIDTH-1:0] * Q_PRIME;
    wire [2*WIDTH:0] sum = c + (m * Q);
    wire [WIDTH:0]   t   = sum[2*WIDTH:WIDTH];           // X / 2^WIDTH

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            res  <= {WIDTH{1'b0}};
            done <= 1'b0;
        end else begin
            done <= start;
            if (start) begin
                if (t >= {1'b0, Q})
                    res <= t[WIDTH-1:0] - Q;
                else
                    res <= t[WIDTH-1:0];
            end
        end
    end

endmodule
