// ============================================================
// Montgomery Reduction Unit
// ============================================================
module mod_red #(
    parameter WIDTH = 32                     // Bit-width (R = 2^WIDTH)
)(
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 start,   // Pulse to begin operation
    input  wire [2*WIDTH-1:0]       c,       // Input product C = A * B
    input  wire [WIDTH-1:0]         q,       // Modulus Q (odd prime)
    output reg  [WIDTH-1:0]         res,     // Reduced output: (C * R^-1) mod Q
    output reg                  done     // Pulsed high when res is valid
);

    localparam NUM_STEPS = $clog2(WIDTH);

    // Internal state encoding
    localparam IDLE      = 2'd0;
    localparam CALC_QPR  = 2'd1;
    localparam REDC_PIPE = 2'd2;

    reg [1:0] state;
    reg [$clog2(NUM_STEPS+1)-1:0] step_cnt;

    // Latched inputs & precomputed registers
    reg [2*WIDTH-1:0] c_reg;
    reg [WIDTH-1:0]   q_reg;
    reg [WIDTH-1:0]   q_prime;
    reg [WIDTH-1:0]   x_inv;
    reg [1:0]     pipe_cnt;

    // Newton-Raphson next-step wire for Q'
    wire [WIDTH-1:0] qx        = q_reg * x_inv;
    wire [WIDTH-1:0] two_minus = {{(WIDTH-2){1'b0}}, 2'b10} - qx;
    wire [WIDTH-1:0] x_next    = x_inv * two_minus;

    // REDC combinational datapath
    wire [WIDTH-1:0] m         = c_reg[WIDTH-1:0] * q_prime;
    wire [2*WIDTH:0] sum       = c_reg + (m * q_reg);
    wire [WIDTH:0]   t         = sum[2*WIDTH:WIDTH];          // X / 2^WIDTH wire slice

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            q_reg    <= {WIDTH{1'b0}};
            q_prime  <= {WIDTH{1'b0}};
            c_reg    <= {(2*WIDTH){1'b0}};
            x_inv    <= {WIDTH{1'b0}};
            step_cnt <= 0;
            pipe_cnt <= 0;
            res      <= {WIDTH{1'b0}};
            done     <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        c_reg <= c;
                        // Check if Q has changed; if unchanged, reuse existing Q'
                        if (q != q_reg || q_prime == {WIDTH{1'b0}}) begin
                            q_reg    <= q;
                            x_inv    <= {{(WIDTH-1){1'b0}}, 1'b1}; // Seed: 1
                            step_cnt <= 0;
                            state    <= CALC_QPR;
                        end else begin
                            pipe_cnt <= 0;
                            state    <= REDC_PIPE;
                        end
                    end
                end

                CALC_QPR: begin
                    x_inv    <= x_next;
                    step_cnt <= step_cnt + 1;

                    if (step_cnt == NUM_STEPS - 1) begin
                        q_prime  <= (~x_next) + 1'b1;  // Q' = -Q^-1 mod 2^WIDTH
                        pipe_cnt <= 0;
                        state    <= REDC_PIPE;
                    end
                end

                REDC_PIPE: begin
                    pipe_cnt <= pipe_cnt + 1;
                    if (pipe_cnt == 2'd1) begin
                        // Final reduction & range check
                        if (t >= {1'b0, q_reg})
                            res <= t[WIDTH-1:0] - q_reg;
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