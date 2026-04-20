`timescale 1ns/1ps

module uart_tx_tb;

    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 10_000_000; // Increased to speed up simulation
    parameter DATA_WIDTH = 8;

    reg clk;
    reg rstn;
    reg tx_start;
    reg [DATA_WIDTH-1:0] tx_data;
    wire tx_busy;
    wire tx_pin;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_pin(tx_pin)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);

        clk = 0;
        rstn = 0;
        tx_start = 0;
        tx_data = 8'h00;

        #20 rstn = 1;

        // Test Case 1: Send 8'hA5 (10100101)
        @(posedge clk);
        tx_data = 8'hA5;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        // Wait for transmission to complete
        wait(tx_busy == 0);
        #100;

        // Test Case 2: Send 8'h5A (01011010)
        @(posedge clk);
        tx_data = 8'h5A;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        wait(tx_busy == 0);
        #100;

        $finish;
    end

endmodule