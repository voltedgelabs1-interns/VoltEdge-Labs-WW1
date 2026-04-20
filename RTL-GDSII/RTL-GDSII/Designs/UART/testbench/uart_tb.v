`timescale 1ns/1ps

module uart_top_tb;

    // Parameters
    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 115200;

    // DUT Signals
    reg clk;
    reg rst_n;

    reg rx_in;
    wire tx_out;

    reg [7:0] data_in;
    reg data_valid;
    wire tx_busy;

    wire [7:0] data_out;
    wire data_ready;

    // Instantiate DUT
    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_in(rx_in),
        .tx_out(tx_out),
        .data_in(data_in),
        .data_valid(data_valid),
        .tx_busy(tx_busy),
        .data_out(data_out),
        .data_ready(data_ready)
    );

    // -------------------------------
    // Clock Generation (50 MHz)
    // -------------------------------
    always #10 clk = ~clk; // 20ns period

    // -------------------------------
    // Loopback Connection
    // -------------------------------
    always @(*) begin
        rx_in = tx_out; // TX connected to RX
    end

    // -------------------------------
    // Task: Send Data
    // -------------------------------
    task send_byte(input [7:0] data);
    begin
        @(posedge clk);
        data_in    <= data;
        data_valid <= 1;

        @(posedge clk);
        data_valid <= 0;

        // Wait until TX is done
        wait(tx_busy == 1);
        wait(tx_busy == 0);
    end
    endtask

    // -------------------------------
    // Monitor Received Data
    // -------------------------------
    always @(posedge clk) begin
        if (data_ready) begin
            $display("Time=%0t | Received Data = 0x%h", $time, data_out);
        end
    end

    // -------------------------------
    // Test Sequence
    // -------------------------------
    initial begin
        $dumpfile("dump.vcd");   // file name
        $dumpvars(0, uart_top_tb); // dump all signals
        // Init
        clk = 0;
        rst_n = 0;
        data_in = 0;
        data_valid = 0;

        #100;
        rst_n = 1;

        // ---------------- TEST CASES ----------------

        // 1. Single byte
        send_byte(8'hA5);

        // 2. Multiple bytes
        send_byte(8'h3C);
        send_byte(8'hF0);
        send_byte(8'h55);

        // 3. Back-to-back transmission
        send_byte(8'hAA);
        send_byte(8'hBB);

        // 4. Edge case: all 0s
        send_byte(8'h00);

        // 5. Edge case: all 1s
        send_byte(8'hFF);

        // 6. Random values
        send_byte($random);
        send_byte($random);

        // Wait for last reception
        #100000;

        $display("Simulation Finished");
        $finish;
    end

endmodule