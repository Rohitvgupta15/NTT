module mod_add
#(
    parameter WIDTH = 32
)
(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] q, // modulus
    output wire [WIDTH-1:0] result
);

    wire [WIDTH:0] sum_ext;
    
    assign sum_ext = a + b;
    assign result = (sum_ext >= q) ? (sum_ext - q) : sum_ext[WIDTH-1:0];

endmodule