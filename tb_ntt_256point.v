module tb_ntt_256point;

    parameter WIDTH = 12;
    parameter Q     = 32'd3329;
    parameter N     = 256;

    reg                    clk;
    reg                    reset;
    reg                    start;
    reg  [N*WIDTH-1:0]     in;
    wire [N*WIDTH-1:0]     out;
    wire                   done;

    ntt_256point #(.WIDTH(WIDTH), .Q(Q)) uut (
        .clk(clk), .reset(reset), .start(start),
        .in(in), .out(out), .done(done)
    );

    // Clock: period 10
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test vectors (hex, coefficient 0 first)
    reg [WIDTH-1:0] in_vec [0:N-1];   // ntt256_input.hex
    reg [WIDTH-1:0] golden [0:N-1];   // ntt256_golden.hex

    integer i;
    integer errors = 0;

    // coefficient i of a packed 256 x WIDTH bus
    function [WIDTH-1:0] coef(input [N*WIDTH-1:0] bus, input integer idx);
        coef = bus[idx*WIDTH +: WIDTH];
    endfunction

    // give a 1-clock start pulse, wait for done
    task run_ntt;
        begin
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            @(posedge done);
            #1;
        end
    endtask

    task print_vec(input [8*8-1:0] name, input [N*WIDTH-1:0] bus);
        begin
            $display("%0s :", name);
            for (i = 0; i < N; i = i + 1) begin
                $write("%h ", coef(bus, i));
                if (i % 16 == 15) $write("\n");
            end
        end
    endtask
    // Measure BFU latency (start -> done) and total NTT time
time t_bfu_start, t_ntt_start;
integer bfu_count = 0;

always @(posedge clk) begin
    if (uut.bfu_start)
        t_bfu_start = $time;
    if (uut.bfu_done) begin
        if (bfu_count == 0)
            $display("BFU latency = %0t ns = %0d cycles",
                     $time - t_bfu_start, ($time - t_bfu_start) / 10);
        bfu_count = bfu_count + 1;
    end
end

always @(posedge start) t_ntt_start = $time;
always @(posedge done)
    $display("NTT total = %0t ns = %0d cycles, %0d butterflies",
             $time - t_ntt_start, ($time - t_ntt_start) / 10, bfu_count);

    initial begin
        $readmemh("ntt256_input.hex",  in_vec);
        $readmemh("ntt256_golden.hex", golden);

        reset = 1;
        start = 0;
        in    = 0;
        repeat (2) @(posedge clk);
        reset = 0;

        // apply input vector
        for (i = 0; i < N; i = i + 1)
            in[i*WIDTH +: WIDTH] = in_vec[i];

        run_ntt;

        // compare with golden reference
        for (i = 0; i < N; i = i + 1)
            if (coef(out, i) !== golden[i]) begin
                if (errors < 20)
                    $display("MISMATCH out[%0d] = %h  golden = %h", i, coef(out, i), golden[i]);
                errors = errors + 1;
            end

        $display("==================================================");
        $display("NTT completed at t=%0t", $time);
        print_vec("Input ", in);
        $display("--------------------------------------------------");
        print_vec("Output", out);
        $display("==================================================");

        if (errors == 0) $display("*** PASS : output matches golden reference ***");
        else             $display("*** FAIL : %0d / %0d coefficients mismatch ***", errors, N);
        #20 $finish;
    end

    // Timeout so the sim never hangs if done never comes
    initial begin
        #200000;
        $display("TIMEOUT: done never asserted");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("ntt_256point.vcd");
        $dumpvars(0, tb_ntt_256point);
    end

endmodule
