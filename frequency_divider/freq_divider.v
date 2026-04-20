
`timescale 1ns/1ps

module freq_divider (
    input  wire clk,
    input  wire rst,
    input  wire [7:0] N,
    output wire clk_out
);
    reg [7:0] count;
    reg pos, neg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            pos   <= 0;
        end else begin
            count <= (count >= N - 1) ? 0 : count + 1;
            pos   <= (count < N / 2);
        end
    end

    always @(negedge clk or posedge rst) begin
        if (rst) neg <= 0;
        else     neg <= pos;
    end

    assign clk_out = (N == 1)?clk:  (N % 2 == 0)?pos : (pos | neg) ;
endmodule