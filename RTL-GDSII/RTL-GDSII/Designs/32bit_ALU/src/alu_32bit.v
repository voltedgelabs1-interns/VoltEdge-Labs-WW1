module alu_32bit #(
    parameter DATA_WIDTH = 32
) (
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    input  wire [3:0]            opcode,
    output reg  [DATA_WIDTH-1:0] result,
    output reg                   zero
);

    // Opcode localparams
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_PASS = 4'b0111;

    always @(*) begin
        // Default assignments to prevent latches
        result = {DATA_WIDTH{1'b0}};
        zero   = 1'b0;

        case (opcode)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_PASS: result = b;
            default:  result = {DATA_WIDTH{1'b0}};
        endcase

        if (result == {DATA_WIDTH{1'b0}}) begin
            zero = 1'b1;
        end
        else 
        zero=1'b0;
    end

endmodule