module design3 (
    input  clk,
    input  [7:0] a, b,
    output reg [7:0] y
);
    reg [7:0] ra, rb;
    wire [7:0] sum, andv, orv;

    assign sum  = ra + rb;
    assign andv = ra & rb;
    assign orv  = ra | rb;

    always @(posedge clk) begin
        ra <= a;
        rb <= b;
        y  <= sum & andv & orv;
    end

endmodule
