`timescale 1ns/1ps

module alu_32bit_tb;

    parameter DATA_WIDTH = 32;

    reg  [DATA_WIDTH-1:0] a;
    reg  [DATA_WIDTH-1:0] b;
    reg  [3:0]            opcode;
    wire [DATA_WIDTH-1:0] result;
    wire                  zero;

    // Instantiate DUT
    alu_32bit #(DATA_WIDTH) dut (
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result),
        .zero(zero)
    );

    // Task to apply stimulus
    task apply_test;
        input [DATA_WIDTH-1:0] ta, tb;
        input [3:0] op;
        begin
            a = ta;
            b = tb;
            opcode = op;
            #10;
            $display("TIME=%0t | OPCODE=%b | A=%h | B=%h | RESULT=%h | ZERO=%b",
                      $time, opcode, a, b, result, zero);
        end
    endtask

    initial begin
        $dumpfile("alu_32bit.vcd");
        $dumpvars(0, alu_32bit_tb);

        // Initialize
        a = 0;
        b = 0;
        opcode = 0;

        #10;

        // ---------------- BASIC OPERATIONS ----------------
        apply_test(32'd10, 32'd5, 4'b0000); // ADD
        apply_test(32'd10, 32'd5, 4'b0001); // SUB
        apply_test(32'hF0F0F0F0, 32'h0F0F0F0F, 4'b0010); // AND
        apply_test(32'hF0F0F0F0, 32'h0F0F0F0F, 4'b0011); // OR
        apply_test(32'hAAAA5555, 32'h5555AAAA, 4'b0100); // XOR

        // ---------------- SHIFT OPERATIONS ----------------
        apply_test(32'h00000001, 32'd4, 4'b0101); // SLL
        apply_test(32'h00000010, 32'd2, 4'b0110); // SRL

        // ---------------- PASS OPERATION ----------------
        apply_test(32'd0, 32'h12345678, 4'b0111); // PASS B

        // ---------------- EDGE CASES ----------------
        
        // Zero result check
        apply_test(32'd5, 32'd5, 4'b0001); // SUB → 0

        // Large numbers
        apply_test(32'hFFFFFFFF, 32'd1, 4'b0000); // Overflow case

        // Shift by 0
        apply_test(32'hA5A5A5A5, 32'd0, 4'b0101);

        // Invalid opcode
        apply_test(32'd10, 32'd20, 4'b1111);

        // All zeros
        apply_test(32'd0, 32'd0, 4'b0000);

        #20;
        $finish;
    end

endmodule