module mod_sub
#(
    parameter WIDTH = 12,
    parameter [WIDTH-1:0] Q = 32'd3329   // Modulus Q (odd prime)
)
(
    input  wire [WIDTH-1 : 0] a,
    input  wire [WIDTH-1 : 0] b,
    output wire [WIDTH-1 : 0] result
);

    wire [WIDTH-1 : 0] temp_diff;
    
    assign temp_diff = a + ~b + 1;
    assign result = (a < b) ? (temp_diff + Q) : temp_diff;

endmodule