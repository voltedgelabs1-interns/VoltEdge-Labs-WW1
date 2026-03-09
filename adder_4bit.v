// 4-bit Combinational Adder
module adder_4bit (
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [4:0] sum
);

    // 4-bit addition with carry out
    assign sum = a + b;

endmodule
