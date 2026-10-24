module mod_sub
#(
    parameter WIDTH = 32
)
(
    input  wire [WIDTH-1 : 0] a,
    input  wire [WIDTH-1 : 0] b,
    input  wire [WIDTH-1 : 0] q,
    output wire [WIDTH-1 : 0] result
);

    wire [WIDTH-1 : 0] temp_diff;

    assign temp_diff = a - b;
    assign result    = (a < b) ? (temp_diff + q) : temp_diff;

endmodule
