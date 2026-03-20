module design_seq (
    input  clk,
    input  a, b, c,
    output reg y
);
    wire n1, n2;
    assign n1 = a & b;
    assign n2 = n1 | c;
    always @(posedge clk)
        y <= n2;
endmodule
