module design1 (
    input  clk,
    input  a, b, c, d,
    output reg y
);
    wire n1, n2, n3, n4;

    assign n1 = a & b;
    assign n2 = n1 | c;
    assign n3 = n2 ^ d;
    assign n4 = n3 & n2;

    always @(posedge clk)
        y <= n4;

endmodule
