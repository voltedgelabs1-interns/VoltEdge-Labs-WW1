`timescale 1ns/1ps

module uart_top #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst_n,

    input  wire rx_in,
    output reg  tx_out,

    input  wire [7:0] data_in,
    input  wire data_valid,
    output reg  tx_busy,

    output reg [7:0] data_out,
    output reg data_ready
);

    // -------------------------------
    // Baud Rate Generator
    // -------------------------------
    localparam BAUD_TICK_LIMIT = CLK_FREQ / BAUD_RATE;

    reg [$clog2(BAUD_TICK_LIMIT)-1:0] tx_baud_cnt, rx_baud_cnt;

    // -------------------------------
    // RX Synchronizer (Metastability fix)
    // -------------------------------
    reg rx_sync1, rx_sync2;

    always @(posedge clk) begin
        rx_sync1 <= rx_in;
        rx_sync2 <= rx_sync1;
    end

    // -------------------------------
    // TX Section
    // -------------------------------
    localparam TX_IDLE  = 0,
               TX_START = 1,
               TX_DATA  = 2,
               TX_STOP  = 3;

    reg [1:0] tx_state;
    reg [2:0] tx_bit_cnt;
    reg [7:0] tx_shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state     <= TX_IDLE;
            tx_out       <= 1'b1;
            tx_bit_cnt   <= 0;
            tx_shift_reg <= 0;
            tx_baud_cnt  <= 0;
            tx_busy      <= 0;
        end else begin

            case (tx_state)

                TX_IDLE: begin
                    tx_out <= 1'b1;
                    tx_bit_cnt <= 0;
                    tx_baud_cnt <= 0;

                    if (data_valid) begin
                        tx_shift_reg <= data_in;
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                    end
                end

                TX_START: begin
                    tx_out <= 1'b0;

                    if (tx_baud_cnt == BAUD_TICK_LIMIT-1) begin
                        tx_baud_cnt <= 0;
                        tx_state <= TX_DATA;
                    end else
                        tx_baud_cnt <= tx_baud_cnt + 1;
                end

                TX_DATA: begin
                    tx_out <= tx_shift_reg[tx_bit_cnt];

                    if (tx_baud_cnt == BAUD_TICK_LIMIT-1) begin
                        tx_baud_cnt <= 0;

                        if (tx_bit_cnt == 7)
                            tx_state <= TX_STOP;

                        tx_bit_cnt <= tx_bit_cnt + 1;
                    end else
                        tx_baud_cnt <= tx_baud_cnt + 1;
                end

                TX_STOP: begin
                    tx_out <= 1'b1;

                    if (tx_baud_cnt == BAUD_TICK_LIMIT-1) begin
                        tx_baud_cnt <= 0;
                        tx_state <= TX_IDLE;
                        tx_busy <= 1'b0;
                    end else
                        tx_baud_cnt <= tx_baud_cnt + 1;
                end

            endcase
        end
    end

    // -------------------------------
    // RX Section
    // -------------------------------
    localparam RX_IDLE  = 0,
               RX_START = 1,
               RX_DATA  = 2,
               RX_STOP  = 3;

    reg [1:0] rx_state;
    reg [2:0] rx_bit_cnt;
    reg [7:0] rx_shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state      <= RX_IDLE;
            rx_bit_cnt    <= 0;
            rx_shift_reg  <= 0;
            rx_baud_cnt   <= 0;
            data_out      <= 0;
            data_ready    <= 0;
        end else begin

            data_ready <= 0; // default

            case (rx_state)

                RX_IDLE: begin
                    rx_bit_cnt <= 0;

                    if (rx_sync2 == 0) begin // start bit detected
                        rx_state <= RX_START;
                        rx_baud_cnt <= 0;
                    end
                end

                RX_START: begin
                    if (rx_baud_cnt == (BAUD_TICK_LIMIT/2)) begin
                        // sample middle of start bit
                        if (rx_sync2 == 0) begin
                            rx_baud_cnt <= 0;
                            rx_state <= RX_DATA;
                        end else
                            rx_state <= RX_IDLE; // false start
                    end else
                        rx_baud_cnt <= rx_baud_cnt + 1;
                end

                RX_DATA: begin
                    if (rx_baud_cnt == BAUD_TICK_LIMIT-1) begin
                        rx_baud_cnt <= 0;

                        rx_shift_reg[rx_bit_cnt] <= rx_sync2;

                        if (rx_bit_cnt == 7)
                            rx_state <= RX_STOP;

                        rx_bit_cnt <= rx_bit_cnt + 1;
                    end else
                        rx_baud_cnt <= rx_baud_cnt + 1;
                end

                RX_STOP: begin
                    if (rx_baud_cnt == BAUD_TICK_LIMIT-1) begin
                        rx_baud_cnt <= 0;

                        if (rx_sync2 == 1) begin // valid stop bit
                            data_out   <= rx_shift_reg;
                            data_ready <= 1'b1;
                        end

                        rx_state <= RX_IDLE;
                    end else
                        rx_baud_cnt <= rx_baud_cnt + 1;
                end

            endcase
        end
    end

endmodule