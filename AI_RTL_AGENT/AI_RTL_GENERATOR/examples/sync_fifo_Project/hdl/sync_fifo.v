module sync_fifo #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH      = 128,
    parameter ADDR_WIDTH = 7  // $clog2(128)
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  rd_data,
    output wire                   full,
    output wire                   empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Sequential Logic: Pointers and Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            rd_ptr <= {ADDR_WIDTH{1'b0}};
            count  <= {(ADDR_WIDTH + 1){1'b0}};
        end else begin
            // Write Pointer
            if (wr_en && !full) begin
                wr_ptr <= wr_ptr + 1'b1;
            end

            // Read Pointer
            if (rd_en && !empty) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // Count logic
            if ((wr_en && !full) && !(rd_en && !empty)) begin
                count <= count + 1'b1;
            end else if (!(wr_en && !full) && (rd_en && !empty)) begin
                count <= count - 1'b1;
            end
        end
    end

    // Memory Write
    integer i;
    always @(posedge clk) begin
        if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
        end
    end

    // Memory Read (Combinational read-out)
    always @(*) begin
        rd_data = mem[rd_ptr];
    end

    // Initialization for simulation/synthesis cleanliness
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end

endmodule