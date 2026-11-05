module mod_add
#(
    parameter WIDTH = 32,
    parameter [WIDTH-1:0] Q = 32'd7681   // Modulus Q (odd prime)
)
(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] result
);

    wire [WIDTH:0] sum_ext;
    
    assign sum_ext = a + b;
    assign result = (sum_ext >= Q) ? (sum_ext - Q) : sum_ext[WIDTH-1:0];

endmodule