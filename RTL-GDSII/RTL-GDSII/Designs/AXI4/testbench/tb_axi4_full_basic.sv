`timescale 1ns/1ps

module tb_axi4_full_basic;

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 32;
parameter ID_WIDTH   = 4;

logic clk;
logic rstn;

/* WRITE ADDRESS CHANNEL */

logic awvalid;
logic [ADDR_WIDTH-1:0] awaddr;
logic [ID_WIDTH-1:0] awid;
logic [7:0] awlen;
logic [2:0] awsize;
logic awready;

/* WRITE DATA CHANNEL */

logic wvalid;
logic [DATA_WIDTH-1:0] wdata;
logic [(DATA_WIDTH/8)-1:0] wstrb;
logic wlast;
logic wready;

/* WRITE RESPONSE CHANNEL */

logic bready;
logic bvalid;
logic [1:0] bresp;
logic [ID_WIDTH-1:0] bid;

/* READ ADDRESS CHANNEL */

logic arvalid;
logic [ADDR_WIDTH-1:0] araddr;
logic [ID_WIDTH-1:0] arid;
logic arready;

/* READ DATA CHANNEL */

logic rready;
logic rvalid;
logic [DATA_WIDTH-1:0] rdata;
logic [1:0] rresp;
logic rlast;
logic [ID_WIDTH-1:0] rid;



/* DUT */

axi4_full_basic dut (

.clk(clk),
.rstn(rstn),

.awready(awready),
.awvalid(awvalid),
.awaddr(awaddr),
.awid(awid),
.awlen(awlen),
.awsize(awsize),

.wready(wready),
.wvalid(wvalid),
.wdata(wdata),
.wstrb(wstrb),
.wlast(wlast),

.bready(bready),
.bvalid(bvalid),
.bresp(bresp),
.bid(bid),

.arready(arready),
.arvalid(arvalid),
.araddr(araddr),
.arid(arid),

.rready(rready),
.rvalid(rvalid),
.rdata(rdata),
.rresp(rresp),
.rlast(rlast),
.rid(rid)

);



/* CLOCK */

initial begin
clk = 0;
forever #5 clk = ~clk;
end



/* RESET */

initial begin
rstn = 0;
#20;
rstn = 1;
end



/* WRITE TASK */

task automatic write_transaction;

begin

$display("WRITE TRANSACTION START");

awaddr = 32'h10;
awid   = 1;
awlen  = 0;
awsize = 3'b010;

wdata = $urandom;
wstrb = 4'hF;
wlast = 1;

awvalid = 1;
wvalid  = 1;

@(posedge clk);

awvalid = 0;
wvalid  = 0;

wait(bvalid);

bready = 1;

@(posedge clk);

bready = 0;

$display("WRITE COMPLETE");

end

endtask



/* READ TASK */

task automatic read_transaction;

begin

$display("READ TRANSACTION START");

araddr = 32'h10;
arid   = 2;

arvalid = 1;

@(posedge clk);

arvalid = 0;

wait(rvalid);

rready = 1;

@(posedge clk);

rready = 0;

$display("READ DATA = %h", rdata);

end

endtask



/* TEST SEQUENCE */

initial begin

awvalid = 0;
wvalid  = 0;
bready  = 0;

arvalid = 0;
rready  = 0;

@(posedge rstn);

repeat(5)
begin

write_transaction();

#20;

read_transaction();

#20;

end

#200;

$display("TEST FINISHED");

$finish;

end



/* COVERAGE */

covergroup axi_cov @(posedge clk);

coverpoint awvalid;
coverpoint wvalid;
coverpoint bvalid;

coverpoint arvalid;
coverpoint rvalid;

endgroup


axi_cov cov = new();

endmodule