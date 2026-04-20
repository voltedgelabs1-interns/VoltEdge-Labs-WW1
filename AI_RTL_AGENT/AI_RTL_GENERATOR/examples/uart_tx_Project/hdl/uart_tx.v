module uart_tx #(
    parameter CLK_FREQ = 1_000_000_000,
    parameter BAUD_RATE = 9600,
    parameter DATA_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    rstn,
    input  wire                    tx_start,
    input  wire [DATA_WIDTH-1:0]   tx_data,
    output reg                     tx_busy,
    output reg                     tx_pin
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam CNT_WIDTH  = $clog2(BIT_PERIOD);

    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    reg [1:0]               state, next_state;
    reg [CNT_WIDTH-1:0]     clk_cnt;
    reg [$clog2(DATA_WIDTH)-1:0] bit_cnt;
    reg [DATA_WIDTH-1:0]    shift_reg;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state     <= IDLE;
            clk_cnt   <= {CNT_WIDTH{1'b0}};
            bit_cnt   <= 0;
            shift_reg <= {DATA_WIDTH{1'b0}};
            tx_pin    <= 1'b1;
            tx_busy   <= 1'b0;
        end else begin
            state <= next_state;

            if (state == IDLE) begin
                tx_pin  <= 1'b1;
                tx_busy <= 1'b0;
                if (tx_start) begin
                    shift_reg <= tx_data;
                    tx_busy   <= 1'b1;
                end
                clk_cnt <= {CNT_WIDTH{1'b0}};
                bit_cnt <= 0;
            end else begin
                tx_busy <= 1'b1;
                if (clk_cnt < BIT_PERIOD - 1) begin
                    clk_cnt <= clk_cnt + 1'b1;
                end else begin
                    clk_cnt <= {CNT_WIDTH{1'b0}};
                    case (state)
                        START: begin
                            tx_pin <= 1'b0;
                        end
                        DATA: begin
                            tx_pin <= shift_reg[bit_cnt];
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                        STOP: begin
                            tx_pin <= 1'b1;
                        end
                        default: tx_pin <= 1'b1;
                    endcase
                end
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (tx_start) next_state = START;
            end
            START: begin
                if (clk_cnt == BIT_PERIOD - 1) next_state = DATA;
            end
            DATA: begin
                if (clk_cnt == BIT_PERIOD - 1 && bit_cnt == DATA_WIDTH - 1) next_state = STOP;
            end
            STOP: begin
                if (clk_cnt == BIT_PERIOD - 1) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule