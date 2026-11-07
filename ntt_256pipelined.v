module ntt_256point #(
    parameter WIDTH = 12,
    parameter Q     = 32'd3329
)(
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 start,
    input  wire [256*WIDTH-1:0] in,
    output wire [256*WIDTH-1:0] out,
    output reg                  done
);

    localparam N           = 256;
    localparam NUM_STAGE   = $clog2(N) - 1; // 7 stages for N=256
    localparam BFU_LATENCY = 4; // BFU computation latency

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

    // Single original working memory
    reg [WIDTH-1:0] mem [0:N-1];

    // Counters & Status
    reg [$clog2($clog2(N)) - 1 : 0] stage;      
    reg [$clog2(N >> 1) - 1 : 0] pair_cnt;   // 0 to 127 (128 butterflies per stage)
    reg [2:0] drain_cnt;  // 0 to 4 (drains pipeline at end of each stage)
    reg       running;
    reg       draining;

    // Address Generator
    wire [$clog2(N) - 1 : 0] addr_u, addr_v;
    wire [$clog2(N >> 1) - 1 : 0] tw_idx;

    ntt_addr_gen #(.N(N)) addr_gen (
        .stage(stage),
        .pair_idx(pair_cnt),
        .addr_u(addr_u),
        .addr_v(addr_v),
        .twiddle_idx(tw_idx)
    );

    // 4-cycle address & write-enable delay line (scalar registers)
    reg [$clog2(N) - 1 : 0] addr_u_d1, addr_u_d2, addr_u_d3, addr_u_d4;
    reg [$clog2(N) - 1 : 0] addr_v_d1, addr_v_d2, addr_v_d3, addr_v_d4;
    reg       wr_en_d1,  wr_en_d2,  wr_en_d3,  wr_en_d4;

    // Directly read from memory and feed into BFU
    wire [WIDTH-1:0] u_in = mem[addr_u];
    wire [WIDTH-1:0] v_in = mem[addr_v];
    wire [WIDTH-1:0] w_in = twiddle_rom[tw_idx];

    wire [WIDTH-1:0] u_next, v_next;
    wire             bfu_done;

    BFU #(.WIDTH(WIDTH), .Q(Q), .OP(1)) u_bfu (
        .clk(clk),
        .reset(reset),
        .A(u_in),
        .B(v_in),
        .W(w_in),
        .W_inv({WIDTH{1'b0}}),
        .start(running),
        .U(u_next),
        .V(v_next),
        .done(bfu_done)
    );

    // -------------------------------------------------------------
    // Pipelined Sequencing Logic
    // -------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stage      <= 3'd0;
            pair_cnt   <= 7'd0;
            drain_cnt  <= 3'd0;
            running    <= 1'b0;
            draining   <= 1'b0;
            done       <= 1'b0;

            addr_u_d1  <= 8'd0; addr_u_d2 <= 8'd0; addr_u_d3 <= 8'd0; addr_u_d4 <= 8'd0;
            addr_v_d1  <= 8'd0; addr_v_d2 <= 8'd0; addr_v_d3 <= 8'd0; addr_v_d4 <= 8'd0;
            wr_en_d1   <= 1'b0; wr_en_d2  <= 1'b0; wr_en_d3  <= 1'b0; wr_en_d4  <= 1'b0;
        end else begin
            // 4-stage pipeline shift for write addresses and write enable
            addr_u_d1 <= addr_u;
            addr_u_d2 <= addr_u_d1;
            addr_u_d3 <= addr_u_d2;
            addr_u_d4 <= addr_u_d3;

            addr_v_d1 <= addr_v;
            addr_v_d2 <= addr_v_d1;
            addr_v_d3 <= addr_v_d2;
            addr_v_d4 <= addr_v_d3;

            wr_en_d1  <= running;
            wr_en_d2  <= wr_en_d1;
            wr_en_d3  <= wr_en_d2;
            wr_en_d4  <= wr_en_d3;

            if (start) begin
                stage     <= 3'd0;
                pair_cnt  <= 7'd0;
                running   <= 1'b1;
                draining  <= 1'b0;
                drain_cnt <= 3'd0;
                done      <= 1'b0;
            end else if (running) begin
                if (pair_cnt == 7'd127) begin
                    pair_cnt  <= 7'd0;
                    running   <= 1'b0; // Stop reading, let pipe drain
                    draining  <= 1'b1;
                    drain_cnt <= 3'd1;
                end else begin
                    pair_cnt <= pair_cnt + 1'b1;
                end
            end else if (draining) begin
                if (drain_cnt == BFU_LATENCY) begin
                    draining  <= 1'b0;
                    drain_cnt <= 3'd0;

                    if (stage == NUM_STAGE - 1) begin
                        done <= 1'b1;
                    end else begin
                        stage   <= stage + 1'b1;
                        running <= 1'b1; // Start next stage immediately
                    end
                end else begin
                    drain_cnt <= drain_cnt + 1'b1;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------
    // In-Place Memory Write
    // -------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (start) begin
            for (i = 0; i < N; i = i + 1) begin
                mem[i] <= in[i*WIDTH +: WIDTH];
            end
        end else if (wr_en_d4) begin
            // Exact same working memory written 4 cycles after read
            mem[addr_u_d4] <= u_next;
            mem[addr_v_d4] <= v_next;
        end
    end

    // Output assignments
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : g_out
            assign out[k*WIDTH +: WIDTH] = mem[k];
        end
    endgenerate

endmodule