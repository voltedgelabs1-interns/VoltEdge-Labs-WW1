module apb_master_slave_interface #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire                          clk,
    input wire                          rstn,
    
    // Master Interface (To local CPU/Processor)
    input wire                          m_req,
    input wire                          m_write,
    input wire [ADDR_WIDTH-1:0]         m_addr,
    input wire [DATA_WIDTH-1:0]         m_wdata,
    output reg                          m_ready,
    output reg [DATA_WIDTH-1:0]         m_rdata,

    // APB Bus Interface
    output wire                         pclk,
    output wire                         presetn,
    output reg [ADDR_WIDTH-1:0]         paddr,
    output reg                          psel,
    output reg                          penable,
    output reg                          pwrite,
    output reg [DATA_WIDTH-1:0]         pwdata,
    input wire                          pready,
    input wire [DATA_WIDTH-1:0]         prdata
);

    // State Encoding
    localparam IDLE    = 2'b00;
    localparam SETUP   = 2'b01;
    localparam ACCESS  = 2'b10;

    reg [1:0] state, next_state;

    // Internal Registers to ensure Address/Data stability
    reg [ADDR_WIDTH-1:0] paddr_reg;
    reg [DATA_WIDTH-1:0] pwdata_reg;
    reg                  pwrite_reg;

    // Continuous assignments for clock and reset mirroring
    assign pclk    = clk;
    assign presetn = rstn;

    // Sequential State and Data Latching Logic
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state      <= IDLE;
            paddr_reg  <= {ADDR_WIDTH{1'b0}};
            pwdata_reg <= {DATA_WIDTH{1'b0}};
            pwrite_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            // Latch master inputs only when a new request starts (IDLE -> SETUP)
            // This fixes the glitch where paddr/pwdata dropped mid-transfer
            if (state == IDLE && m_req) begin
                paddr_reg  <= m_addr;
                pwdata_reg <= m_wdata;
                pwrite_reg <= m_write;
            end
        end
    end

    // Next State and Combinational Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        m_ready    = 1'b0;
        m_rdata    = {DATA_WIDTH{1'b0}};
        psel       = 1'b0;
        penable    = 1'b0;
        
        // Drive APB bus from the stable internal registers
        paddr      = paddr_reg;
        pwrite     = pwrite_reg;
        pwdata     = pwdata_reg;

        case (state)
            IDLE: begin
                if (m_req) begin
                    next_state = SETUP;
                end
            end

            SETUP: begin
                psel       = 1'b1;
                next_state = ACCESS;
            end

            ACCESS: begin
                psel    = 1'b1;
                penable = 1'b1;
                
                if (pready) begin
                    m_ready = 1'b1;
                    m_rdata = prdata;
                    next_state = IDLE;
                end else begin
                    next_state = ACCESS;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule