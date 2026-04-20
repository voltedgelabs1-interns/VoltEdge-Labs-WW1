module alu #(
    parameter DATA_WIDTH = 16
)(
    input  wire                     clk,
    input  wire                     rstn,
    input  wire [DATA_WIDTH-1:0]    a,
    input  wire [DATA_WIDTH-1:0]    b,
    input  wire [1:0]               opcode,
    output reg  [DATA_WIDTH-1:0]    result,
    output reg                      carry_out
);

    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;
    localparam OP_AND = 2'b10;
    localparam OP_OR  = 2'b11;

    reg [DATA_WIDTH:0] alu_out;

    always @(*) begin
        // Default assignments to prevent latches
        alu_out = {(DATA_WIDTH+1){1'b0}};
        
        case (opcode)
            OP_ADD: alu_out = {1'b0, a} + {1'b0, b};
            OP_SUB: alu_out = {1'b0, a} - {1'b0, b};
            OP_AND: alu_out = {1'b0, a & b};
            OP_OR:  alu_out = {1'b0, a | b};
            default: alu_out = {(DATA_WIDTH+1){1'b0}};
        endcase
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            result    <= {DATA_WIDTH{1'b0}};
            carry_out <= 1'b0;
        end else begin
            result    <= alu_out[DATA_WIDTH-1:0];
            carry_out <= alu_out[DATA_WIDTH];
        end
    end

endmodule