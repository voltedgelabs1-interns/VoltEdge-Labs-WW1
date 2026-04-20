module alu_tb;

    parameter DATA_WIDTH = 16;

    reg clk;
    reg rstn;
    reg [DATA_WIDTH-1:0] a;
    reg [DATA_WIDTH-1:0] b;
    reg [1:0] opcode;
    wire [DATA_WIDTH-1:0] result;
    wire carry_out;

    alu #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk),
        .rstn(rstn),
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result),
        .carry_out(carry_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        clk = 0;
        rstn = 0;
        a = 0;
        b = 0;
        opcode = 0;

        #20 rstn = 1;

        // Test ADD
        a = 16'h000F; b = 16'h0001; opcode = 2'b00;
        #10;
        
        // Test SUB
        a = 16'h0010; b = 16'h0001; opcode = 2'b01;
        #10;

        // Test AND
        a = 16'hAAAA; b = 16'h5555; opcode = 2'b10;
        #10;

        // Test OR
        a = 16'hAAAA; b = 16'h5555; opcode = 2'b11;
        #10;

        #20 $finish;
    end

endmodule