// D Flip-Flop using non-blocking assignment (correct)
module dff_nonblocking (
    input  wire clk,
    input  wire d,
    output reg  q
);

    always @(posedge clk) begin
        q <= d;
    end

endmodule
