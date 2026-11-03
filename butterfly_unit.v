module BFU #(
    parameter WIDTH = 32
) (
    input               clk,
    input             reset,
    input                op, // 1 = NTT, 0 = INTT
    input [WIDTH - 1 : 0] A,
    input [WIDTH - 1 : 0] B,
    input [WIDTH - 1 : 0] W,
    input [WIDTH - 1 : 0] W_inv,
    input [WIDTH - 1 : 0] q,
    input             start,

    output reg [WIDTH - 1 : 0] U,
    output reg [WIDTH - 1 : 0] V,
    output reg            done
);


    wire  [WIDTH - 1 : 0] modulo_ct;
    wire  [WIDTH - 1 : 0] reg_u_ct;
    wire  [WIDTH - 1 : 0] reg_v_ct;
    wire  [WIDTH - 1 : 0] reg_u_gs;
    wire  [WIDTH - 1 : 0] reg_v_gs;
    wire  [WIDTH - 1 : 0] gs_add;
    wire  [WIDTH - 1 : 0] gs_sub;
    wire  mul_done;

//  using Cooley-Tukey (CT)
//   U = A + W * B mod q
//   V = A - W * B mod q


    mod_mult #(
        .WIDTH       (WIDTH)
    ) mul1 (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .a     (B),
        .w     (W),
        .q     (q),
        .result(modulo_ct),
        .done  (mul_done)
    );

    mod_add #(
        .WIDTH       (WIDTH)
    ) add1 (
        .a     (A),
        .b     (modulo_ct),
        .q     (q),
        .result(reg_u_ct)
    );

    mod_sub #(
        .WIDTH       (WIDTH)
    ) sub1 (
        .a     (A),
        .b     (modulo_ct),
        .q     (q),
        .result(reg_v_ct)
    );

//  using Gentleman-Sande (GS)
//   U = (A + B) mod q
//   V = (A - B) * W_inv mod q

    mod_add #(
        .WIDTH       (WIDTH)
    ) add2 (
        .a     (A),
        .b     (B),
        .q     (q),
        .result(gs_add)
    );

    mod_sub #(
        .WIDTH       (WIDTH)
    ) sub2 (
        .a     (A),
        .b     (B),
        .q     (q),
        .result(gs_sub)
    );

    // mod_mult #(
    //     .WIDTH       (WIDTH)
    // ) mul2 (
    //     .clk   (clk),
    //     .reset (reset),
    //     .start (start),
    //     .a     (gs_add),
    //     .w     (W_inv),
    //     .q     (q),
    //     .result(reg_u_gs),
    //     .done  ()
    // );
    mod_mult #(
        .WIDTH       (WIDTH)
    ) mul3 (
        .clk   (clk),
        .reset (reset),
        .start (start),
        .a     (gs_sub),
        .w     (W_inv),
        .q     (q),
        .result(reg_v_gs),
        .done  ()
    );
    
    wire [WIDTH:0] gs_add_q = gs_add + q;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            U    <= {WIDTH{1'b0}};
            V    <= {WIDTH{1'b0}};
            done <= 1'b0;
        end
        else begin
            done <= mul_done;         
            if (mul_done) begin
                if (op == 1'b0) begin  // INTT
                    U <= gs_add[0] ? gs_add_q[WIDTH:1] : (gs_add >> 1);
                    V <= reg_v_gs;
                end
                else begin             // NTT
                    U <= reg_u_ct;
                    V <= reg_v_ct;
                end
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