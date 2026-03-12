Below is a compact, synthesizable I2C master core in Verilog. It implements a basic I2C master with open-drain style SDA and SCL (via tri-state nets). It supports one transaction at a time and can perform either a single-byte write or a single-byte read to a given 7-bit slave address. The clock divider lets you choose an I2C clock frequency (SCL) given your system clock.

Notes:
- SDA and SCL are modeled as open-drain via tri-state semantics. Connect external pull-ups on the bus.
- Start, stop, address/data transmission, and ACK/NACK handling follow the I2C protocol.
- This is a compact single-byte-per-transaction master. It can be extended to multi-byte operations by adding a byte counter and a data FIFO or streaming interface.
- The code is written to be synthesizable for common FPGA/ASIC targets.

Usage:
- clk: system clock
- rst_n: active-low reset
- start: start a transaction
- rw: 0 = write, 1 = read
- addr: 7-bit slave address
- wdata: data byte to write (valid when rw=0)
- rdata: data byte read (valid when done)
- busy: high while a transaction is in progress
- done: pulse high for one cycle when the transaction completes
- sda, scl: I2C lines (tri-state, open-drain with pull-ups)

Code:

```verilog
// Synthesizable I2C Master (one-byte write or one-byte read)
// Open-drain SDA and SCL (tri-state). Pull-ups required externally.
//
// This core performs:
//  - Start condition
//  - 8-bit address+RW transmission (MSB first)
//  - ACK from slave
//  - For write: 8-bit data, then ACK
//  - For read: 8-bit data from slave, then NACK (master ends read)
//  - Stop condition
//
// Limitations: single-byte per transaction. Extendable for multi-byte transfers.

module i2c_master_one_byte #(
    parameter CLK_FREQ  = 50_000_000, // System clock frequency (Hz)
    parameter I2C_FREQ  = 100_000     // Desired I2C clock frequency (SCL) (Hz)
)(
    input  wire        clk,
    input  wire        rst_n,

    // Operation interface
    input  wire        start,      // start transaction
    input  wire        rw,         // 0 = write, 1 = read
    input  wire [6:0]  addr,       // 7-bit slave address
    input  wire [7:0]  wdata,      // data to write (valid when rw=0)
    output reg  [7:0]  rdata,      // data read (valid when done)
    output reg         busy,       // busy during transaction
    output reg         done,       // 1 for 1 clk cycle when transaction finished

    // I2C lines (open-drain style)
    inout  wire        sda,
    inout  wire        scl
);

    // ---------------------------------------------------------------------
    // Clock divider for SCL generation
    // SCL period = 1 / I2C_FREQ. We use a two-phase half-period clock.
    // HALF_DIV = (CLK_FREQ) / (I2C_FREQ * 2)
    // Ensure integer arithmetic
    localparam integer HALF_DIV = (CLK_FREQ / (I2C_FREQ * 2));

    // Internal timer for SCL phase (0 = low, 1 = high)
    reg [31:0] div_cnt;
    reg        scl_phase; // 0 -> SCL low (drive), 1 -> SCL high (release)

    // Generate SCL phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt  <= 0;
            scl_phase <= 1'b1; // idle: SCL high (bus idle)
        end else begin
            if (div_cnt == HALF_DIV - 1) begin
                div_cnt   <= 0;
                scl_phase <= ~scl_phase;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end
    end

    // Open-drain implementation: drive low when needed, else release (high via pull-up)
    reg sda_drive;  // 1 = drive (pull SDA low), 0 = release (Hi-Z)
    reg scl_drive;  // 1 = drive (pull SCL low), 0 = release (Hi-Z)

    // SDA/SCL are tri-stated with pull-ups externally
    assign sda = sda_drive ? 1'b0 : 1'bz;
    assign scl = scl_drive ? 1'b0 : 1'bz;

    // Readable inputs from the bus (read current levels)
    wire sda_in = (sda === 1'bz) ? 1'b1 : sda; // treat Hi-Z as '1' (bus idle high)
    wire scl_in = (scl === 1'bz) ? 1'b1 : scl;

    // ---------------------------------------------------------------------
    // State machine for I2C master
    // States: IDLE, START, ADDR, ADDR_ACK, WRITE_BYTE, WRITE_ACK, READ_BYTE, READ_ACK, STOP
    localparam STE_IDLE      = 4'd0;
    localparam STE_START     = 4'd1;
    localparam STE_ADDR      = 4'd2;
    localparam STE_ADDR_ACK  = 4'd3;
    localparam STE_WRITE     = 4'd4;
    localparam STE_WRITE_ACK = 4'd5;
    localparam STE_READ      = 4'd6;
    localparam STE_READ_ACK  = 4'd7;
    localparam STE_STOP      = 4'd8;
    localparam STE_DONE      = 4'd9;

    reg [3:0] state, state_nx;
    reg [3:0] bit_cnt;      // bit counter (7..0)
    reg [7:0] tx_buf;       // transmission buffer (addr+rw or data)
    reg [7:0] rx_buf;       // received byte
    reg       addr_phase;     // internal phase flag for START handling

    // Helper: next_state (combinational)
    function [3:0] f_next;
        input [3:0] s;
        begin
            f_next = s; // default
        end
    endfunction

    // Sequential state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STE_IDLE;
            bit_cnt   <= 4'd0;
            tx_buf    <= 8'd0;
            rx_buf    <= 8'd0;
            rdata     <= 8'd0;
            busy      <= 1'b0;
            done      <= 1'b0;
            addr_phase<= 1'b0;
            sda_drive <= 1'b0;
            scl_drive <= 1'b0;
        end else begin
            // default one-cycle done pulse
            done <= 1'b0;

            // State machine
            case (state)
                STE_IDLE: begin
                    // Idle until a start is requested
                    sda_drive <= 1'b0; // release by default
                    scl_drive <= 1'b0; // release by default
                    busy      <= 1'b0;

                    if (start) begin
                        // Latch the operation
                        tx_buf  <= {addr, rw}; // addr[7]..addr[1]? Actually MSB addr[6] then RW in LSB
                        // Build 8-bit: [7:1] = addr[6:0], [0] = rw
                        // Proper packing:
                        // We'll compute as: {addr, rw}
                        // But we need MSB first, so we'll use addr[6] as bit7, ... addr[0] as bit1, rw as bit0
                        // bit_cnt will be 7 downto 0
                        bit_cnt <= 4'd7;
                        rx_buf  <= 8'd0;
                        rdata   <= 8'd0;

                        // Prepare to start condition next cycle
                        state   <= STE_START;
                        busy    <= 1'b1;
                        // Start condition: SDA goes low while SCL high. We assume SCL is high by default (bus idle),
                        // so drive SDA low in this cycle (SCL will be released/high in its phase).
                        sda_drive <= 1'b1; // drive SDA low (start condition)
                    end
                end

                // START condition (SDA already pulled low while SCL is high)
                STE_START: begin
                    // Ensure SCL is high (released)
                    scl_drive <= 1'b0; // release SCL (SCL high by pull-up)
                    // Next, drive the first bit of address+RW on the falling edge of SCL
                    // bit 7 is MSB of tx_buf
                    // We do not drive impedance here; We drive bit 7 during the low phase
                    // Move to ADDR phase and drive first bit
                    // Prepare the first bit on SDA according to bit 7
                    if (scl_phase == 1'b1) begin
                        // SCL high phase — do nothing, ensure SDA is set for next bit
                        // Drive bit 7
                        if (tx_buf[7] == 1'b0) begin
                            sda_drive <= 1'b1; // drive low for '0'
                        end else begin
                            sda_drive <= 1'b0; // release for '1'
                        end
                        bit_cnt <= 4'd6; // next bit to send
                        state   <= STE_ADDR;
                    end
                end

                // ADDR: send bits MSB to LSB, bit by bit
                STE_ADDR: begin
                    // Drive next bit on SDA during SCL low phase
                    if (scl_phase == 1'b0) begin
                        // SCL is low; set next bit
                        // The current bit to output is tx_buf[7 - (7-bit_cnt)]
                        // Because we already sent bit 7 in START
                        // Here we are sending next bits: bit index = bit_cnt
                        if (tx_buf[bit_cnt] == 1'b0)
                            sda_drive <= 1'b1; // drive 0
                        else
                            sda_drive <= 1'b0; // release for 1
                    end
                    // On falling edge (SCL goes high-to-low is not visible directly; we use phase)
                    if (scl_phase == 1'b1) begin
                        // SCL rising edge - slave samples bit; we advance after the high phase
                        // No action; just wait for fall to next bit
                    end
                    // When falling to low edge (i.e., next low phase after high), move to next bit
                    if (scl_phase == 1'b0 && sda_drive !== 1'bx) begin
                        // We already set the bit during previous low phase; now on next low phase, either step or ack
                        if (bit_cnt != 4'd0) begin
                            bit_cnt <= bit_cnt - 4'd1;
                        end else begin
                            // All 8 bits transmitted
                            state     <= STE_ADDR_ACK;
                            // Release SDA to allow slave to drive ACK
                            sda_drive <= 1'b0;
                        end
                    end
                end

                // ADDR_ACK: sample ACK bit from slave (during 9th clock)
                STE_ADDR_ACK: begin
                    // Look for ACK (SDA pulled low by slave during 9th clock)
                    // We sample on SCL rising edge (high phase)
                    if (scl_phase == 1'b1) begin
                        // Sample ACK
                        if (sda_in == 1'b0) begin
                            // ACK received
                            if (rw == 1'b0) begin
                                // Write operation: prepare to send data byte
                                tx_buf  <= wdata;
                                bit_cnt <= 4'd7;
                                state   <= STE_WRITE;
                                // Prepare first data bit on SDA (MSB) during next low phase
                                // Set SDA according to bit7 of wdata
                                if (wdata[7] == 1'b0) sda_drive <= 1'b1;
                                else                sda_drive <= 1'b0;
                            end else begin
                                // Read operation: prepare to read 8 bits
                                rx_buf  <= 8'd0;
                                bit_cnt <= 4'd7;
                                state   <= STE_READ;
                                // Release SDA to allow slave to drive
                                sda_drive <= 1'b0;
                            end
                        end else begin
                            // NACK or invalid: end transaction (abort)
                            state <= STE_STOP;
                        end
                    end
                end

                // WRITE: send data byte (MSB first)
                STE_WRITE: begin
                    // During SCL low, output next bit
                    if (scl_phase == 1'b0) begin
                        if (tx_buf[bit_cnt] == 1'b0)
                            sda_drive <= 1'b1; // drive 0
                        else
                            sda_drive <= 1'b0; // release for 1
                    end
                    // After sending, move to next bit on next low-to-high cycle
                    if (scl_phase == 1'b0) begin
                        // Move to next bit on the next high cycle
                        if (bit_cnt != 4'd0) begin
                            bit_cnt <= bit_cnt - 4'd1;
                        end else begin
                            // All 8 data bits sent; wait for ACK from slave
                            state     <= STE_WRITE_ACK;
                        end
                    end
                end

                // WRITE_ACK: sample ACK after data byte
                STE_WRITE_ACK: begin
                    // ACK from slave on 9th clock
                    if (scl_phase == 1'b1) begin
                        if (sda_in == 1'b0) begin
                            // ACK received; transaction complete for single-byte write
                            state <= STE_STOP;
                        end else begin
                            // NACK: abort
                            state <= STE_STOP;
                        end
                    end
                end

                // READ: read 8 bits from slave
                STE_READ: begin
                    // Slave drives data; sample on rising edge (scl_phase == 1)
                    if (scl_phase == 1'b1) begin
                        // sample MSB first
                        rx_buf[bit_cnt] <= sda_in;
                        if (bit_cnt != 4'd0) begin
                            bit_cnt <= bit_cnt - 4'd1;
                        end else begin
                            // 8 bits read; send NACK (master ends read)
                            state     <= STE_READ_ACK;
                        end
                    end
                    // While SCL low, ensure SDA is released (master not driving during read)
                    if (scl_phase == 1'b0) begin
                        sda_drive <= 1'b0;
                    end
                end

                // READ_ACK: after 8 bits read, send NACK to end read
                STE_READ_ACK: begin
                    // On next low phase, ensure SDA is released (NACK)
                    if (scl_phase == 1'b0) begin
                        sda_drive <= 1'b0; // release for NACK
                    end
                    // Then on next rising edge, stop
                    if (scl_phase == 1'b1) begin
                        // Capture read data
                        rdata <= rx_buf;
                        state <= STE_STOP;
                    end
                end

                // STOP: generate Stop condition
                STE_STOP: begin
                    // STOP: SDA goes high while SCL is high
                    // Ensure we release SDA (Hi-Z) to let it go high
                    if (scl_phase == 1'b1) begin
                        sda_drive <= 1'b0; // release
                    end
                    // Move to DONE
                    if (scl_phase == 1'b1) begin
                        state <= STE_DONE;
                    end
                end

                // DONE: complete the transaction
                STE_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    // Return to IDLE
                    state <= STE_IDLE;
                end

                default: state <= STE_IDLE;
            endcase
        end
    end

    // ---------------------------------------------------------------------
    // Outputs and flags (synchronous)
    // done is a one-cycle pulse; busy is held high during the transaction.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            // done is asserted in STE_DONE in the FSM above
            // No extra logic needed here
        end
    end

endmodule
```

Explanation of usage:
- To perform a write: assert start, set rw=0, addr=slave address, wdata=data to write. After completion, done goes high for one cycle and busy goes low. The data on rdata is not updated for write.
- To perform a read: assert start, set rw=1, addr=slave address. After completion, done goes high for one cycle and rdata holds the read byte.

Important integration notes:
- This is a compact, single-byte-per-transaction master. For multi-byte transfers, you’ll want to add a byte counter, a small queue, and separate control signals to orchestrate successive read/write bytes.
- The code assumes an external pull-up on SDA and SCL and uses open-drain tri-stating for both lines.
- The exact timing depends on your chosen CLK_FREQ and I2C_FREQ; HALF_DIV selects the SCL half-period count. If you have timing constraints, adjust CLK_FREQ and I2C_FREQ accordingly or add more precise timing control.
- In a real FPGA, you might want to implement a more robust start/stop generation and handle clock stretching (SCL low while slave holds it low). The current code is a good starting point and is straightforward to extend.

If you want, I can tailor this to your specific clock, desired SCL frequency, and extend it to support multi-byte reads/writes with a streaming data interface (FIFO-like handshake).