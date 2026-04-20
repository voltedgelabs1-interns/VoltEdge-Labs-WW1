//  																			AHB Protocol 
//  Modules included:
//    1. ahb_master  2. ahb_slave    3. ahb_decoder  4. ahb_top    5. ahb_tb      
`timescale 1ns/1ps
//																				1. MASTER
module ahb_master (
    // Clock & Reset
    input  wire        HCLK,
    input  wire        HRESETn,

    // AHB Bus Outputs (to interconnect)
    output reg  [31:0] HADDR,    // Address bus
    output reg  [1:0]  HTRANS,   // Transfer type (IDLE/NONSEQ/SEQ/BUSY)
    output reg         HWRITE,   // 1 = Write, 0 = Read
    output reg  [2:0]  HSIZE,HBURST,  // Transfer size & Burst type   
    output reg  [31:0] HWDATA,   // Write data

    // AHB Bus Inputs (from interconnect)
    input  wire [31:0] HRDATA,   // Read data from slave
    input  wire        HREADY,   // 1 = transfer complete / bus free
    input  wire [1:0]  HRESP,    // Response: OKAY=00, ERROR=01

    // User / Testbench Interface
    input  wire        start,    // Pulse high to begin
    input  wire        wr_rd,    // 1 = Write, 0 = Read
    input  wire [31:0] addr_in,  // Target address
    input  wire [31:0] wdata_in, // write data
    output reg  [31:0] rdata_out,// read data
    output reg         done      // Pulses high when complete
);

    // HTRANS encodings
    localparam IDLE   = 2'b00;  // No transfer requested
    localparam NONSEQ = 2'b10;  // Single or first burst transfer

	// FSM state encoding
    localparam S_IDLE = 2'd0;   // Waiting for start
    localparam S_ADDR = 2'd1;   // Address phase: drive HADDR/HTRANS
    localparam S_DATA = 2'd2;   // Data phase: drive HWDATA, wait HREADY
    localparam S_DONE = 2'd3;   // Latch result, assert done

    reg [1:0] state, next_state;

    // Latched command 
    reg        cmd_wr;
    reg [31:0] cmd_addr;
    reg [31:0] cmd_wdata;

    // State register
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) state <= S_IDLE;
        else          state <= next_state;
    end

    // Next-state + combinational output logic
    always @(*) begin
        // Safe defaults
        next_state = state;
        HTRANS     = IDLE;
        HWRITE     = 1'b0;
        HADDR      = 32'h0;
        HWDATA     = 32'h0;
        HSIZE      = 3'b010;   // 32-bit word
        HBURST     = 3'b000;   // SINGLE burst
        done       = 1'b0;

        case (state)
            // IDLE: Bus inactive, wait for start command
            S_IDLE: begin
                if (start) next_state = S_ADDR;
            end

            // ADDR:
            S_ADDR: begin
                HTRANS     = NONSEQ;
                HADDR      = cmd_addr;
                HWRITE     = cmd_wr;
                HSIZE      = 3'b010;
                HBURST     = 3'b000;
                next_state = S_DATA;
            end

            // DATA:
            S_DATA: begin
                HTRANS = IDLE;       // No back-to-back (single transfer)
                HWRITE = cmd_wr;
                HWDATA = cmd_wdata;  // Must be stable the whole data phase

                if (HREADY)          // Slave finished 
                    next_state = S_DONE;
            end

            // DONE:
            S_DONE: begin
                done       = 1'b1;
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Latch user command on rising start (only when idle)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            cmd_wr    <= 1'b0;
            cmd_addr  <= 32'h0;
            cmd_wdata <= 32'h0;
        end else if (start && state == S_IDLE) begin
            cmd_wr    <= wr_rd;
            cmd_addr  <= addr_in;
            cmd_wdata <= wdata_in;
        end
    end

    // Capture HRDATA at end of read data phase
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            rdata_out <= 32'h0;
        else if ((state == S_DATA) && HREADY && !cmd_wr)
            rdata_out <= HRDATA;   // Slave drives valid data on HREADY
    end

endmodule




// 																						2. SLAVE 
module ahb_slave #(
    parameter MEM_DEPTH   = 16,             // Number of 32-bit words
    parameter ADDR_BASE   = 32'h0000_0000,  // Base address mapped to this slave
    parameter WAIT_STATES = 0               // Extra wait cycles per transfer
)(
    // Clock & Reset
    input  wire        HCLK,
    input  wire        HRESETn,

    // AHB Bus Inputs
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [2:0]  HBURST,
    input  wire [31:0] HWDATA,
    input  wire        HSEL,     // Decoder asserts this when HADDR hits our range

    // AHB Bus Outputs
    output reg  [31:0] HRDATA,
    output reg         HREADY,
    output reg  [1:0]  HRESP
);

    // HTRANS / HRESP encodings
    localparam T_IDLE   = 2'b00;
    localparam T_NONSEQ = 2'b10;
    localparam T_SEQ    = 2'b11;

    localparam OKAY  = 2'b00;
    localparam ERROR = 2'b01;

    // Internal memory
    reg [31:0] mem [0:MEM_DEPTH-1];

    reg        wr_reg;      // Registered HWRITE
    reg [31:0] addr_reg;    // Registered HADDR
    reg        sel_reg;     // Registered HSEL
    reg        valid_reg;   // High when a real transfer is in progress

    // Wait-state down-counter
    reg [$clog2(WAIT_STATES+2):0] wait_cnt;

    // Pipeline capture: latch address phase on every HREADY edge
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wr_reg    <= 1'b0;
            addr_reg  <= 32'h0;
            sel_reg   <= 1'b0;
            valid_reg <= 1'b0;
        end else if (HREADY) begin
            wr_reg    <= HWRITE;
            addr_reg  <= HADDR;
            sel_reg   <= HSEL;
            // Transfer is valid only for NONSEQ or SEQ types
            valid_reg <= HSEL && ((HTRANS == T_NONSEQ) || (HTRANS == T_SEQ));
        end
    end
    // HREADY / wait-state generation
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wait_cnt <= 0;
            HREADY   <= 1'b1;   // Bus free after reset
        end else begin
            if (valid_reg && !HREADY) begin
                // Currently counting down wait states
                if (wait_cnt == 0)
                    HREADY <= 1'b1;          // Done — release bus
                else
                    wait_cnt <= wait_cnt - 1; // Keep waiting
            end else if (valid_reg && HREADY) begin
                // New valid transfer just sampled; start wait counter
                if (WAIT_STATES > 0) begin
                    wait_cnt <= WAIT_STATES - 1;
                    HREADY   <= 1'b0;        // Stall master
                end
                // else: WAIT_STATES==0, HREADY stays 1
            end else begin
                HREADY   <= 1'b1;            // Idle — keep bus free
                wait_cnt <= 0;
            end
        end
    end

    // Data phase: execute the read or write
    wire [31:0] word_idx = (addr_reg - ADDR_BASE) >> 2; // Word-aligned index

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HRDATA <= 32'h0;
            HRESP  <= OKAY;
        end else if (valid_reg && HREADY) begin
            if (word_idx < MEM_DEPTH) begin
                HRESP <= OKAY;
                if (wr_reg) begin
                    // ---- WRITE operation ----
                    mem[word_idx] <= HWDATA;
                    $display("[S%0d] WR addr=0x%08h data=0x%08h  @%0t",
                             (ADDR_BASE != 0), addr_reg, HWDATA, $time);
                end else begin
                    // ---- READ operation ----
                    HRDATA <= mem[word_idx];
                    $display("[S%0d] RD addr=0x%08h data=0x%08h  @%0t",
                             (ADDR_BASE != 0), addr_reg, mem[word_idx], $time);
                end
            end else begin
                // Out-of-range address — signal ERROR to master
                HRESP  <= ERROR;
                HRDATA <= 32'hDEAD_BEEF;
                $display("[S%0d] ERROR out-of-range addr=0x%08h  @%0t",
                         (ADDR_BASE != 0), addr_reg, $time);
            end
        end else begin
            HRESP <= OKAY;   // Hold OKAY during idle cycles
        end
    end

endmodule




// 																					3. DECODER 
module ahb_decoder (
    input  wire [31:0] HADDR,
    // Slave select outputs
    output reg         HSEL_S0,
    output reg         HSEL_S1,
    // Per-slave response inputs
    input  wire [31:0] HRDATA_S0, HRDATA_S1,
    input  wire        HREADY_S0, HREADY_S1,
    input  wire [1:0]  HRESP_S0,  HRESP_S1,
    // Muxed response to master
    output reg  [31:0] HRDATA,
    output reg         HREADY,
    output reg  [1:0]  HRESP
);

	// Address decode
    always @(*) begin
        HSEL_S0 = 1'b0;
        HSEL_S1 = 1'b0;

        if      (HADDR[31:6] == 26'h000000) HSEL_S0 = 1'b1; // 0x0000_0000
        else if (HADDR[31:6] == 26'h000400) HSEL_S1 = 1'b1; // 0x0001_0000
    end

    // Response mux
    always @(*) begin
        if (HSEL_S0) begin
            HRDATA = HRDATA_S0;
            HREADY = HREADY_S0;
            HRESP  = HRESP_S0;
        end else if (HSEL_S1) begin
            HRDATA = HRDATA_S1;
            HREADY = HREADY_S1;
            HRESP  = HRESP_S1;
        end else begin
            // No slave selected — keep bus free
            HRDATA = 32'h0;
            HREADY = 1'b1;
            HRESP  = 2'b00;
        end
    end

endmodule


// 																						4.TOP 
module ahb_top (
    input  wire        HCLK,
    input  wire        HRESETn,

    // User interface (exposed for testbench)
    input  wire        start,
    input  wire        wr_rd,
    input  wire [31:0] addr_in,
    input  wire [31:0] wdata_in,
    output wire [31:0] rdata_out,
    output wire        done
);


    // AHB bus wires 
    wire [31:0] HADDR;
    wire [1:0]  HTRANS;
    wire        HWRITE;
    wire [2:0]  HSIZE;
    wire [2:0]  HBURST;
    wire [31:0] HWDATA;
    // AHB bus wires (bus → master)
    wire [31:0] HRDATA;
    wire        HREADY;
    wire [1:0]  HRESP;
    // Slave select
    wire        HSEL_S0, HSEL_S1;
    // Per-slave responses
    wire [31:0] HRDATA_S0, HRDATA_S1;
    wire        HREADY_S0, HREADY_S1;
    wire [1:0]  HRESP_S0,  HRESP_S1;

    // Master instance
    ahb_master u_master (
        .HCLK(HCLK),.HRESETn(HRESETn),.HADDR(HADDR),.HTRANS(HTRANS),.HWRITE(HWRITE),.HSIZE(HSIZE),.HBURST(HBURST),.HWDATA(HWDATA),
		.HRDATA(HRDATA),.HREADY(HREADY),.HRESP(HRESP),.start(start),.wr_rd(wr_rd),.addr_in(addr_in),.wdata_in(wdata_in),.rdata_out(rdata_out), 
		.done(done));
    // Decoder 
		ahb_decoder u_decoder (
        .HADDR(HADDR),.HSEL_S0(HSEL_S0),.HSEL_S1(HSEL_S1),.HRDATA_S0(HRDATA_S0),.HRDATA_S1(HRDATA_S1),
        .HREADY_S0(HREADY_S0),.HREADY_S1(HREADY_S1),.HRESP_S0(HRESP_S0),.HRESP_S1 (HRESP_S1),.HRDATA(HRDATA),
		.HREADY(HREADY),.HRESP(HRESP)
    );
    // Slave 0: base=0x0000_0000, 16 words, no wait states
    ahb_slave #(
        .MEM_DEPTH  (16),
        .ADDR_BASE  (32'h0000_0000),
        .WAIT_STATES(0)
    ) u_slave0 (
        .HCLK(HCLK),.HRESETn(HRESETn),.HADDR(HADDR),.HTRANS(HTRANS),.HWRITE(HWRITE),.HSIZE(HSIZE),
        .HBURST(HBURST),.HWDATA (HWDATA),.HSEL(HSEL_S0),.HRDATA(HRDATA_S0),.HREADY(HREADY_S0),.HRESP(HRESP_S0)
    );

    // Slave 1: base=0x0001_0000, 16 words, 2 wait states
    ahb_slave #(
        .MEM_DEPTH  (16),
        .ADDR_BASE  (32'h0001_0000),
        .WAIT_STATES(2)
    ) u_slave1 (
        .HCLK(HCLK),.HRESETn (HRESETn),.HADDR(HADDR),  .HTRANS  (HTRANS),
        .HWRITE(HWRITE),.HSIZE(HSIZE),.HBURST(HBURST),.HWDATA(HWDATA),.HSEL(HSEL_S1),
        .HRDATA(HRDATA_S1),.HREADY(HREADY_S1),.HRESP(HRESP_S1)
    );
endmodule


