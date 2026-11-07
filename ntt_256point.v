// 256-point forward NTT (Kyber / ML-KEM), q = 3329
//
// 7 Cooley-Tukey stages (Kyber NTT stops at 128 degree-1 pairs).
//   stage s = 1..7 :  len = 128 >> (s-1),  groups = 2^(s-1)
//   group g pairs a[j] with a[j+len] for j in [g*2*len, g*2*len+len)
//   and uses twiddle W[2^(s-1) + g]
//   BFU (OP=1):  U = A + W*B,  V = A - W*B   (mod q)
//
// Twiddles: W[i] = 17^bitrev7(i) * 2^12 mod q  (Montgomery form, R = 2^12,
// matching mod_mult which computes a*w*2^-12 mod q -> plain a*zeta).
// Input and output are in natural Kyber order (coefficient i at in[i*WIDTH +: WIDTH]).

module ntt_256point #(
    parameter WIDTH = 12,
    parameter Q = 32'd3329
)(
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 start,
    input  wire [256*WIDTH-1:0] in,
    output wire [256*WIDTH-1:0] out,
    output reg                  done
);

    localparam N         = 256;
    localparam NUM_STAGE = $clog2(N) - 1;   // 7 stages for Kyber

    localparam [WIDTH-1:0] twiddle_rom [0:127] = '{
         767, 1201, 1434, 2610, 2382,  505,  226, 1261,
        2278,  455, 1555, 2092, 2973,  341,  324,  924,
         660, 2622, 1681,  232, 2653, 3004,  316,  408,
        1830, 1520,  878,   38, 1152, 1066, 2692,  526,
        1949,  873, 1630, 1936, 2624, 2798, 2063, 1568,
        2529, 1664, 3309, 2039,  315, 2008,  424,  716,
         987, 2075, 3104,  468, 1047, 2616, 1441, 1397,
        2888, 3181,  738,  995,   28, 1806, 2331, 2209,
        3052,  443, 1075, 1093,  546, 1927,  513, 1463,
        2107, 1077, 3132, 2274,  606, 2468, 2179, 2392,
        1233, 1297, 1945,  615, 1824, 1133, 2043,  278,
        1149, 2537, 1610,  646, 2939, 1477, 2487, 2284,
        3172, 1525, 1078, 2951, 1331,  960, 1781,   24,
        3045, 1656, 2989, 1373, 2026,  846,  550, 2185,
         134, 1985, 2833, 1298, 1154, 1195, 1194,  446,
        2490,  813, 2559,  270,  476,  741, 3008,  934
    };

    localparam IDLE    = 2'd0;
    localparam READ    = 2'd1;
    localparam EXEC    = 2'd2;
    localparam FINISH  = 2'd3;

    reg [1:0] state;
    reg [$clog2($clog2(N)) - 1 : 0] stage;    // 0 to 6 (7 stages)
    reg [$clog2(N >> 1) - 1 : 0]    pair_cnt; // 0 to 127 (128 butterflies per stage)

    // Address Generator
    wire [$clog2(N) - 1 : 0]      addr_u;
    wire [$clog2(N) - 1 : 0]      addr_v;
    wire [$clog2(N >> 1) - 1 : 0] tw_idx;

    ntt_addr_gen #(.N(N)) addr_gen (
        .stage(stage),
        .pair_idx(pair_cnt),
        .addr_u(addr_u),
        .addr_v(addr_v),
        .twiddle_idx(tw_idx)
    );

    reg [WIDTH-1:0] mem [0:N-1]; // 256 x 12-bit working memory

    reg [$clog2(N) - 1 : 0] reg_addr_u, reg_addr_v;
    reg [WIDTH-1:0] u_reg, v_reg;
    reg [WIDTH-1:0] twiddle_reg;
    reg             bfu_start;   // 1-cycle pulse per butterfly

    wire [WIDTH-1:0] u_next, v_next;
    wire             bfu_done;

    BFU #(.WIDTH(WIDTH), .Q(Q), .OP(1)) u_bfu (
        .clk(clk), .reset(reset),
        .A(u_reg), .B(v_reg),
        .W(twiddle_reg), .W_inv({WIDTH{1'b0}}),
        .start(bfu_start),
        .U(u_next), .V(v_next),
        .done(bfu_done)
    );

    // Output bus driven from working memory (valid when done = 1)
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : g_out
            assign out[k*WIDTH +: WIDTH] = mem[k];
        end
    endgenerate

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            stage       <= 0;
            pair_cnt    <= 0;
            done        <= 0;
            bfu_start   <= 0;
            u_reg       <= 0;
            v_reg       <= 0;
            twiddle_reg <= 0;
            reg_addr_u  <= 0;
            reg_addr_v  <= 0;
        end else begin
            bfu_start <= 1'b0;
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        for (i = 0; i < N; i = i + 1)
                            mem[i] <= in[i*WIDTH +: WIDTH];
                        stage    <= 0;
                        pair_cnt <= 0;
                        state    <= READ;
                    end
                end

                READ: begin
                    // Fetch butterfly operands & twiddle, kick the BFU
                    u_reg       <= mem[addr_u];
                    v_reg       <= mem[addr_v];
                    twiddle_reg <= twiddle_rom[tw_idx];
                    reg_addr_u  <= addr_u;
                    reg_addr_v  <= addr_v;
                    bfu_start   <= 1'b1;
                    state       <= EXEC;
                end

                EXEC: begin
                    if (bfu_done) begin
                        mem[reg_addr_u] <= u_next;
                        mem[reg_addr_v] <= v_next;

                        if (pair_cnt == (N >> 1) - 1) begin
                            pair_cnt <= 0;
                            if (stage == NUM_STAGE - 1) begin
                                state <= FINISH;
                            end else begin
                                stage <= stage + 1'b1;
                                state <= READ;
                            end
                        end else begin
                            pair_cnt <= pair_cnt + 1'b1;
                            state    <= READ;
                        end
                    end
                end

                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
