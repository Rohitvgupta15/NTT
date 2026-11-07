
module ntt_addr_gen #(
    parameter WIDTH = 12,
    parameter Q = 32'd3329,
    parameter N = 256
)
(
    input  wire [$clog2($clog2(N)) - 1 : 0] stage,       // 0..6
    input  wire [$clog2(N >> 1) - 1 : 0]    pair_idx,    // 0..127
    output wire [$clog2(N) - 1 : 0]         addr_u,      // RAM address for u
    output wire [$clog2(N) - 1 : 0]         addr_v,      // RAM address for v
    output wire [$clog2(N >> 1) - 1 : 0]    twiddle_idx  // index into Kyber zeta ROM
);
    localparam LOGH = $clog2(N >> 1);                    // 7

    wire [LOGH : 0]     len = (N >> 1) >> stage;         // 128, 64, ..., 2
    wire [LOGH - 1 : 0] j   = pair_idx & (len - 1'b1);   // offset inside group
    wire [LOGH - 1 : 0] k   = pair_idx >> (LOGH - stage); // group number

    assign addr_u      = ({1'b0, k} << (LOGH + 1 - stage)) + j;  // k*2*len + j
    assign addr_v      = addr_u + len;
    assign twiddle_idx = (1 << stage) + k;
endmodule
