module alu_mux_16bit #(
    parameter DATA_WIDTH = 16
)(
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    input  wire [2:0]            op,
    output wire [DATA_WIDTH-1:0] result
);

    // Operation localparams
    localparam OP_ADD  = 3'b000;
    localparam OP_SUB  = 3'b001;
    localparam OP_AND  = 3'b010;
    localparam OP_OR   = 3'b011;
    localparam OP_XOR  = 3'b100;
    localparam OP_NOT_A = 3'b101;
    localparam OP_PASS_B = 3'b110;
    localparam OP_ZERO  = 3'b111;

    wire [DATA_WIDTH-1:0] add_res, sub_res, and_res, or_res, xor_res, not_a_res;

    assign add_res   = a + b;
    assign sub_res   = a - b;
    assign and_res   = a & b;
    assign or_res    = a | b;
    assign xor_res   = a ^ b;
    assign not_a_res = ~a;

    // Multiplexer-based ALU implementation
    assign result = (op == OP_ADD)   ? add_res   :
                    (op == OP_SUB)   ? sub_res   :
                    (op == OP_AND)   ? and_res   :
                    (op == OP_OR)    ? or_res    :
                    (op == OP_XOR)   ? xor_res   :
                    (op == OP_NOT_A) ? not_a_res :
                    (op == OP_PASS_B)? b         :
                    {DATA_WIDTH{1'b0}};

endmodule