module alu_mux_16bit_tb;

    parameter DATA_WIDTH = 16;

    reg clk;
    reg rst;
    reg [DATA_WIDTH-1:0] a;
    reg [DATA_WIDTH-1:0] b;
    reg [2:0] op;
    wire [DATA_WIDTH-1:0] result;

    alu_mux_16bit #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("alu_mux_16bit.vcd");
        $dumpvars(0, alu_mux_16bit_tb);

        clk = 0;
        rst = 1;
        a = 0;
        b = 0;
        op = 0;

        #10 rst = 0;
        
        // Test cases
        a = 16'hAAAA;
        b = 16'h5555;

        // ADD
        op = 3'b000; #10;
        // SUB
        op = 3'b001; #10;
        // AND
        op = 3'b010; #10;
        // OR
        op = 3'b011; #10;
        // XOR
        op = 3'b100; #10;
        // NOT_A
        op = 3'b101; #10;
        // PASS_B
        op = 3'b110; #10;
        // ZERO
        op = 3'b111; #10;

        $display("Testbench finished.");
        $finish;
    end

endmodule