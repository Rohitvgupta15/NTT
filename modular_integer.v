// ============================================================
// Multiplier Module (2-Cycle Pipeline Latency)
// ============================================================
module mult_int #(
    parameter WIDTH       = 32,
    parameter CHUNK_WIDTH = 16,
    parameter NUM_CHUNKS  = WIDTH / CHUNK_WIDTH,
    parameter PROD_WIDTH  = 2 * WIDTH
)(
    input  wire                   clk,
    input  wire                   reset,
    input  wire [WIDTH-1:0]       A,
    input  wire [WIDTH-1:0]       B,
    output reg  [PROD_WIDTH-1:0]  C
);

    integer i, j;

    // Split operands into chunks
    reg [CHUNK_WIDTH-1:0] a_chunk [0:NUM_CHUNKS-1];
    reg [CHUNK_WIDTH-1:0] b_chunk [0:NUM_CHUNKS-1];

    always @(*) begin
        for (i = 0; i < NUM_CHUNKS; i = i + 1) begin
            a_chunk[i] = A[i*CHUNK_WIDTH +: CHUNK_WIDTH];
            b_chunk[i] = B[i*CHUNK_WIDTH +: CHUNK_WIDTH];
        end
    end

    // Stage 1: Registered Partial Products
    (* use_dsp = "yes" *)
    reg [PROD_WIDTH-1:0] partial_product [0:NUM_CHUNKS*NUM_CHUNKS-1];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < NUM_CHUNKS*NUM_CHUNKS; i = i + 1)
                partial_product[i] <= {PROD_WIDTH{1'b0}};
        end else begin
            for (i = 0; i < NUM_CHUNKS; i = i + 1) begin
                for (j = 0; j < NUM_CHUNKS; j = j + 1) begin
                    partial_product[i*NUM_CHUNKS+j] <= 
                        ({ {(PROD_WIDTH - CHUNK_WIDTH){1'b0}}, a_chunk[i] } * 
                         { {(PROD_WIDTH - CHUNK_WIDTH){1'b0}}, b_chunk[j] }) 
                        << ((i + j) * CHUNK_WIDTH);
                end
            end
        end
    end

    // Reduction Tree (Combinational)
    reg [PROD_WIDTH-1:0] result;

    always @(*) begin
        result = {PROD_WIDTH{1'b0}};
        for (i = 0; i < NUM_CHUNKS*NUM_CHUNKS; i = i + 1)
            result = result + partial_product[i];
    end

    // Stage 2: Output Register
    always @(posedge clk or posedge reset) begin
        if (reset)
            C <= {PROD_WIDTH{1'b0}};
        else
            C <= result;
    end

endmodule