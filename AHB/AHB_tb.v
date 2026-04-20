

// 5. TESTBENCH
`timescale 1ns/1ps
module ahb_tb;
    reg HCLK;
    reg HRESETn;

    // User interface signals to/from ahb_top
    reg        start;
    reg        wr_rd;
    reg [31:0] addr_in;
    reg [31:0] wdata_in;

    wire [31:0] rdata_out;
    wire        done;

    // DUT — top-level AHB system
    ahb_top u_top (
        .HCLK(HCLK),.HRESETn(HRESETn),.start(start),.wr_rd(wr_rd),.addr_in(addr_in),
		.wdata_in(wdata_in),.rdata_out(rdata_out),.done(done)
    );

    // 100 MHz clock (10 ns period)
    initial HCLK = 0;
    always #5 HCLK = ~HCLK;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // Task: write transfer
    task do_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge HCLK); #1;
            addr_in  = addr;
            wdata_in = data;
            wr_rd    = 1'b1;   // Write
            start    = 1'b1;
            @(posedge HCLK); #1;
            start    = 1'b0;
            @(posedge done);   // Wait for master to signal completion
            @(posedge HCLK);
            $display("[TB] WR addr=0x%08h  data=0x%08h", addr, data);
        end
    endtask


    // Task: read transfer 
    task do_read;
        input [31:0] addr;
        input [31:0] expected;
        reg   [31:0] got;
        begin
            @(posedge HCLK); #1;
            addr_in = addr;
            wr_rd   = 1'b0;    // Read
            start   = 1'b1;
            @(posedge HCLK); #1;
            start   = 1'b0;
            @(posedge done);
            @(posedge HCLK);
            got = rdata_out;
            if (got === expected) begin
                $display("[TB] RD addr=0x%08h  got=0x%08h  exp=0x%08h  PASS",
                         addr, got, expected);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[TB] RD addr=0x%08h  got=0x%08h  exp=0x%08h  FAIL <<<",
                         addr, got, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // Main test sequence

    initial begin
        // Initialise
        HRESETn = 1'b0;
        start   = 1'b0;
        wr_rd   = 1'b0;
        addr_in = 32'h0;
        wdata_in= 32'h0;
        repeat(4) @(posedge HCLK);
        HRESETn = 1'b1;
        @(posedge HCLK);

        $display("\n                AHB Protocol Tests           \n");

        $display("\n T1: Single write/read — Slave 0 (no wait states)\n");
        do_write(32'h0000_0000, 32'hABCD_1234);
        do_read (32'h0000_0000, 32'hABCD_1234);

        $display("\n T2: Multi-word write/read — Slave 0");
        do_write(32'h0000_0004, 32'hCEDFA01);
        do_write(32'h0000_0008, 32'hF3A0CABE);
        do_write(32'h0000_000C, 32'h1234_5678);
        do_read (32'h0000_0004, 32'hCEDFA01);
        do_read (32'h0000_0008, 32'hF3A0CABE);
        do_read (32'h0000_000C, 32'h1234_5678);


        $display("\n--- T3: Write/read — Slave 1 (2 wait states) ---");
        do_write(32'h0001_0000, 32'h5A5A_5A5A);
        do_read (32'h0001_0000, 32'h5A5A_5A5A);
        do_write(32'h0001_0004, 32'hFFFF_0000);
        do_read (32'h0001_0004, 32'hFFFF_0000);

        $display("\n--- T4: Back-to-back across both slaves ---");
        do_write(32'h0000_0010, 32'h1111_1111);
        do_write(32'h0001_0008, 32'h2222_2222);
        do_read (32'h0000_0010, 32'h1111_1111);
        do_read (32'h0001_0008, 32'h2222_2222);

        $display("\n        TEST SUMMARY ");
        $display("  PASS : %0d", pass_cnt);
        $display("  FAIL : %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("  >> ALL TESTS PASSED <<");
        else
            $display("  >> %0d TEST(S) FAILED <<", fail_cnt);
        #20; $finish;
    end
endmodule