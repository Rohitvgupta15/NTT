// ============================================================
// Montgomery Reduction Unit
//   res = (C * R^-1) mod Q,  R = 2^WIDTH
//   Q is a compile-time parameter, so Q' = -Q^-1 mod R is
//   computed at elaboration (no runtime Newton-Raphson).
// ============================================================
module mod_red #(
    parameter WIDTH = 32,                    // Bit-width (R = 2^WIDTH)
    parameter [WIDTH-1:0] Q = 32'd7681       // Modulus Q (odd prime)
)(
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 start,       // Pulse to begin operation
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

    // Internal state encoding
    localparam IDLE      = 1'b0;
    localparam REDC_PIPE = 1'b1;

    reg               state;
    reg [1:0]         pipe_cnt;
    reg [2*WIDTH-1:0] c_reg;

    // REDC combinational datapath
    wire [WIDTH-1:0] m   = c_reg[WIDTH-1:0] * Q_PRIME;
    wire [2*WIDTH:0] sum = c_reg + (m * Q);
    wire [WIDTH:0]   t   = sum[2*WIDTH:WIDTH];           // X / 2^WIDTH

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            c_reg    <= {(2*WIDTH){1'b0}};
            pipe_cnt <= 2'd0;
            res      <= {WIDTH{1'b0}};
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        c_reg    <= c;
                        pipe_cnt <= 2'd0;
                        state    <= REDC_PIPE;
                    end
                end

                REDC_PIPE: begin
                    pipe_cnt <= pipe_cnt + 1'b1;
                    if (pipe_cnt == 2'd1) begin
                        // Final reduction & range check
                        if (t >= {1'b0, Q})
                            res <= t[WIDTH-1:0] - Q;
                        else
                            res <= t[WIDTH-1:0];

                        done  <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
