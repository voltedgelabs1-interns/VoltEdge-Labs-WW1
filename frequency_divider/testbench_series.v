// testbench_series.v
// One clear example per series
// Base clock = 50 MHz (period = 20ns)
//
// How to run:
//   iverilog -o sim testbench_series.v freq_divider.v
//   vvp sim
//   gtkwave waveform.vcd

`timescale 1ns/1ps

module testbench_series;

    // ─────────────────────────────────────────
    // CLOCK AND RESET
    // period = 20ns = 50 MHz
    // ─────────────────────────────────────────
    reg clk, rst;

    initial clk = 0;
    always #10 clk = ~clk;   // flip every 10ns → 20ns period

    initial begin
        rst = 1;                      // hold reset ON
        repeat(5) @(posedge clk);    // wait 5 clock ticks
        rst = 0;                      // release reset
    end


    // ─────────────────────────────────────────
    // SERIES 1 — 2n  (n=4 → divide by 8)
    //
    //   2n where n=4 → N = 2×4 = 8
    //   Output = 50MHz ÷ 8 = 6.25 MHz
    //   N=8 is even → duty cycle already 50%, no FF trick needed
    // ─────────────────────────────────────────
    wire out_2n;
    freq_divider u_2n (
        .clk     (clk),
        .rst     (rst),
        .N       (8'd8),    // 2×4 = 8
        .clk_out (out_2n)
    );


    // ─────────────────────────────────────────
    // SERIES 2 — 3n  (n=3 → divide by 9)
    //
    //   3n where n=3 → N = 3×3 = 9
    //   Output = 50MHz ÷ 9 = 5.55 MHz
    //   N=9 is ODD → needs −ve edge FF + OR to fix duty cycle
    // ─────────────────────────────────────────
    wire out_3n;
    freq_divider u_3n (
        .clk     (clk),
        .rst     (rst),
        .N       (8'd9),    // 3×3 = 9
        .clk_out (out_3n)
    );


    // ─────────────────────────────────────────
    // SERIES 3 — n²  (n=5 → divide by 25)
    //
    //   n² where n=5 → N = 5×5 = 25
    //   Output = 50MHz ÷ 25 = 2 MHz
    //   N=25 is ODD → needs −ve edge FF + OR to fix duty cycle
    // ─────────────────────────────────────────
    wire out_n2;
    freq_divider u_n2 (
        .clk     (clk),
        .rst     (rst),
        .N       (8'd25),   // 5² = 25
        .clk_out (out_n2)
    );


    // ─────────────────────────────────────────
    // SERIES 4 — 2^n  (n=4 → divide by 16)
    //
    //   2^n where n=4 → N = 2⁴ = 16
    //   Output = 50MHz ÷ 16 = 3.125 MHz
    //   N=16 is even AND a power of 2 → easiest case, free 50% DC
    // ─────────────────────────────────────────
    wire out_2pn;
    freq_divider u_2pn (
        .clk     (clk),
        .rst     (rst),
        .N       (8'd16),   // 2⁴ = 16
        .clk_out (out_2pn)
    );


    // ─────────────────────────────────────────
    // RECORD AND RUN
    // ─────────────────────────────────────────
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench_series);

        // run long enough to see several cycles of the
        // slowest signal (÷25 → period = 500ns)
        // so run for at least 10 × 500ns = 5000ns
        #5000;

        $display("Done. Signals to look at in GTKWave:");
        $display("  clk     = 50 MHz base clock");
        $display("  out_2n  = 6.25 MHz  (50MHz / 8,  series 2n, n=4)");
        $display("  out_3n  = 5.55 MHz  (50MHz / 9,  series 3n, n=3)");
        $display("  out_n2  = 2.00 MHz  (50MHz / 25, series n2, n=5)");
        $display("  out_2pn = 3.125 MHz (50MHz / 16, series 2^n, n=4)");

        $finish;
    end

endmodule
