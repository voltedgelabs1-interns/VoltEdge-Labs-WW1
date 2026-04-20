`timescale 1ns/1ps

module tb_apb_master_slave_interface;

  // Parameters
  parameter ADDR_WIDTH = 32;
  parameter DATA_WIDTH = 32;

  // Clock and reset
  reg clk;
  reg rstn;

  // Master interface signals
  wire m_ready;
  wire [DATA_WIDTH-1:0] m_rdata;
  reg m_req;
  reg m_write;
  reg [ADDR_WIDTH-1:0] m_addr;
  reg [DATA_WIDTH-1:0] m_wdata;

  // APB bus signals (connected to DUT)
  wire pclk;
  wire presetn;
  wire [ADDR_WIDTH-1:0] paddr;
  wire psel;
  wire penable;
  wire pwrite;
  wire [DATA_WIDTH-1:0] pwdata;
  reg pready;
  reg [DATA_WIDTH-1:0] prdata;

  // Slave memory model
  reg [DATA_WIDTH-1:0] mem [0:255];

  // Instantiate DUT
  apb_master_slave_interface #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk(clk),
      .rstn(rstn),
      .m_req(m_req),
      .m_write(m_write),
      .m_addr(m_addr),
      .m_wdata(m_wdata),
      .m_ready(m_ready),
      .m_rdata(m_rdata),
      .pclk(pclk),
      .presetn(presetn),
      .paddr(paddr),
      .psel(psel),
      .penable(penable),
      .pwrite(pwrite),
      .pwdata(pwdata),
      .pready(pready),
      .prdata(prdata)
  );

  // Clock generation: 10ns period
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rstn = 0;
    #20 rstn = 1;
  end

  // APB Slave behavior: assert pready one cycle after ACCESS starts
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      pready <= 1'b0;
      prdata <= {DATA_WIDTH{1'b0}};
    end else if (psel && penable) begin
      // Slave ready in this cycle
      pready <= 1'b1;
      if (pwrite) begin
        mem[paddr] <= pwdata;
        prdata <= {DATA_WIDTH{1'b0}}; // write data not needed on read bus
      end else begin
        prdata <= mem[paddr];
      end
    end else begin
      pready <= 1'b0;
      prdata <= {DATA_WIDTH{1'b0}};
    end
  end

  // Task definitions
  task cpu_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
    begin
      m_req   = 1'b1;
      m_write = 1'b1;
      m_addr  = addr;
      m_wdata = data;
      @(posedge clk); // drive for one cycle
      wait(m_ready);
      $display("[%0t] WRITE: addr=%h data=%h", $time, addr, data);
      // Deassert request after transfer completes
      m_req   = 1'b0;
      m_write = 1'b0;
    end
  endtask

  task cpu_read(input [ADDR_WIDTH-1:0] addr);
    begin
      m_req   = 1'b1;
      m_write = 1'b0;
      m_addr  = addr;
      @(posedge clk);
      wait(m_ready);
      $display("[%0t] READ:  addr=%h data=%h", $time, addr, m_rdata);
      m_req   = 1'b0;
      m_write = 1'b0;
    end
  endtask

  // Test sequence
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(1, tb_apb_master_slave_interface);

    // Wait for reset deassertion
    wait(rstn == 1);
    @(posedge clk);

    // Write to three addresses
    cpu_write(32'h0000_0000, 32'hDEAD_BEEF);
    cpu_write(32'h0000_0004, 32'hCAFE_BABE);
    cpu_write(32'h0000_0008, 32'h1234_5678);

    // Read back and verify
    cpu_read(32'h0000_0000);
    if (m_rdata !== 32'hDEAD_BEEF) $display("[%0t] ERROR: read back mismatch at 0", $time);
    cpu_read(32'h0000_0004);
    if (m_rdata !== 32'hCAFE_BABE) $display("[%0t] ERROR: read back mismatch at 4", $time);
    cpu_read(32'h0000_0008);
    if (m_rdata !== 32'h1234_5678) $display("[%0t] ERROR: read back mismatch at 8", $time);

    $display("[%0t] Test finished", $time);
    $finish;
  end

endmodule
