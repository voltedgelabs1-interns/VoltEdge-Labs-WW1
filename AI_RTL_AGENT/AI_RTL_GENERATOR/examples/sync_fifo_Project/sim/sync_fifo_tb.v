`timescale 1ns / 1ps

module sync_fifo_tb;

    parameter DATA_WIDTH = 64;
    parameter DEPTH      = 128;
    parameter ADDR_WIDTH = 7;

    reg clk;
    reg rst_n;
    reg wr_en;
    reg [DATA_WIDTH-1:0] wr_data;
    reg rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire full;
    wire empty;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .full(full),
        .empty(empty)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);

        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;

        #20 rst_n = 1;

        // Test Case 1: Fill FIFO
        repeat (10) begin
            @(posedge clk);
            wr_en = 1;
            wr_data = $random;
        end

        // Test Case 2: Read from FIFO
        @(posedge clk);
        wr_en = 0;
        rd_en = 1;
        repeat (5) @(posedge clk);

        // Test Case 3: Simultaneous Write/Read
        @(posedge clk);
        wr_en = 1;
        wr_data = 64'hDEADBEEF;
        rd_en = 1;
        
        @(posedge clk);
        wr_en = 0;
        rd_en = 0;

        #100 $finish;
    end

endmodule