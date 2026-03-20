module design2 (
    input  clk,
    input  [3:0] d,
    output reg [3:0] q1,
    output reg [3:0] q2
);
    always @(posedge clk) begin
        q1 <= d;
        q2 <= q1;
    end

endmodule
