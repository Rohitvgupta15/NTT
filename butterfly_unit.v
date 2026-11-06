module BFU #(
    parameter WIDTH = 12,
    parameter [WIDTH-1:0] Q = 32'd3329,  // Modulus Q (odd prime)
    // Butterfly type (fixed at elaboration, only that datapath is built):
    //   1 = NTT  (Cooley-Tukey):     U = A + W*B,      V = A - W*B
    //   0 = INTT (Gentleman-Sande):  U = (A + B)/2,    V = (A - B)*W_inv

    parameter OP = 1
) (
    input                      clk,
    input                      reset,
    input      [WIDTH - 1 : 0] A,
    input      [WIDTH - 1 : 0] B,
    input      [WIDTH - 1 : 0] W,       // NTT twiddle  (used when OP == 1)
    input      [WIDTH - 1 : 0] W_inv,   // INTT twiddle (used when OP == 0)
    input                      start,

    output reg [WIDTH - 1 : 0] U,
    output reg [WIDTH - 1 : 0] V,
    output reg                 done
);

    wire [WIDTH - 1 : 0] u_next;
    wire [WIDTH - 1 : 0] v_next;
    wire                 mul_done;

    localparam [2*WIDTH-1:0] R2_64 = {1'b1, {(2*WIDTH){1'b0}}} % Q;   // R^2 mod Q
    localparam [WIDTH-1:0]   KU    = (((Q + 1) >> 1) * R2_64) % Q;    // (Q+1)/2 = 2^-1 mod Q

    generate
        if (OP == 1) begin : g_ct
            // ---------------- Cooley-Tukey (NTT) ----------------
            //   U = A + W*B mod q
            //   V = A - W*B mod q
            wire [WIDTH - 1 : 0] wb;

            mod_mult #(.WIDTH(WIDTH), .Q(Q)) mul (
                .clk   (clk),
                .reset (reset),
                .start (start),
                .a     (B),
                .w     (W),
                .result(wb),
                .done  (mul_done)
            );

            mod_add #(.WIDTH(WIDTH), .Q(Q)) add (.a(A), .b(wb), .result(u_next));
            mod_sub #(.WIDTH(WIDTH), .Q(Q)) sub (.a(A), .b(wb), .result(v_next));

        end else begin : g_gs
            // -------------- Gentleman-Sande (INTT) --------------
            //   U = (A + B)/2 mod q
            //   V = (A - B) * W_inv mod q   (W_inv has the 1/2 folded in)
            
            wire [WIDTH - 1 : 0] gs_add;
            wire [WIDTH - 1 : 0] gs_sub;
            wire [WIDTH     : 0] gs_add_q;

            mod_add #(.WIDTH(WIDTH), .Q(Q)) add (.a(A), .b(B), .result(gs_add));
            mod_sub #(.WIDTH(WIDTH), .Q(Q)) sub (.a(A), .b(B), .result(gs_sub));

            mod_mult #(.WIDTH(WIDTH), .Q(Q)) mul (
                .clk   (clk),
                .reset (reset),
                .start (start),
                .a     (gs_sub),
                .w     (W_inv),
                .result(v_next),
                .done  (mul_done)
            );
            
            if (OP == 0) begin : g_gs 
                    // x/2 mod q: if x is odd, add q (odd) first, then shift
                assign gs_add_q = gs_add + Q;
                assign u_next   = gs_add[0] ? gs_add_q[WIDTH:1] : (gs_add >> 1);
            end
            else if (OP == 2) begin : g_ct
                    mod_mult #(.WIDTH(WIDTH), .Q(Q)) mul2 (
                        .clk   (clk),
                        .reset (reset),
                        .start (start),
                        .a     (gs_add),
                        .w     (KU),
                        .result(u_next),
                        .done  ()
                    );
                end
            
        end
    endgenerate

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            U    <= {WIDTH{1'b0}};
            V    <= {WIDTH{1'b0}};
            done <= 1'b0;
        end else begin
            done <= mul_done;
            if (mul_done) begin
                U <= u_next;
                V <= v_next;
            end
        end
    end

endmodule


// module tb_BFU;
//     parameter WIDTH = 32;
//     reg clk, reset, start, op;
//     reg [WIDTH - 1 : 0] A, B, W, W_inv, q;
//     wire [WIDTH - 1 : 0] U, V;
//     wire done;

//     BFU #(
//         .WIDTH(WIDTH)
//     ) dut (
//         .clk(clk),
//         .reset(reset),
//         .op(op),
//         .A(A),
//         .B(B),
//         .W(W),
//         .W_inv(W_inv),
//         .q(q),
//         .start(start),
//         .U(U),
//         .V(V),
//         .done(done)
//     );

//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk; // Clock generation
//     end

//     initial begin
//         reset = 1;
//         start = 0;
//         op    = 1'b1; // Set operation mode (1 for NTT, 0 for INTT)
//         A     = 32'd125; // Example input values
//         B     = 32'd75;
//         W     = 32'd6115;   // Montgomery form of 3383
//         W_inv = 32'd783;   // Montgomery form of 4298 × 2^-1

//         q     = 32'd7681; // Example modulus
//         #10 reset = 0; // Release reset after some time
//         #10 start = 1; // Start the operation
//         #10 start = 0; // Stop the start signal
//         @(posedge done); #1;
//             $display("U: %d, V: %d", U, V);
// #10;
//         op    = 1'b0; // Set operation mode (1 for NTT, 0 for INTT)
//         A     = 32'd377; // Example input values
//         B     = 32'd7554;
//         W     = 32'd6115;   // Montgomery form of 3383
//         W_inv = 32'd783;   // Montgomery form of 4298 × 2^-1

//         q     = 32'd7681; // Example modulus
//         #10 reset = 0; // Release reset after some time
//         #10 start = 1; // Start the operation
//         #10 start = 0; // Stop the start signal
//         @(posedge done); #1;
//             $display("U: %d, V: %d", U, V);
//         #100 $finish; // Finish the simulation after some time

//     end

//     endmodule