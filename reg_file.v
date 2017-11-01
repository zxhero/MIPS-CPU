`ifdef PRJ1_FPGA_IMPL
	// the board does not have enough GPIO, so we implement 4 4-bit registers
    `define DATA_WIDTH 4
	`define ADDR_WIDTH 2
`else
    `define DATA_WIDTH 32
	`define ADDR_WIDTH 5
`endif

module reg_file(
	input clk,
	input rst,
	input [`ADDR_WIDTH - 1:0] waddr,
	input [`ADDR_WIDTH - 1:0] raddr1,
	input [`ADDR_WIDTH - 1:0] raddr2,
	input wen,
	input [`DATA_WIDTH - 1:0] wdata,
	output [`DATA_WIDTH - 1:0] rdata1,
	output [`DATA_WIDTH - 1:0] rdata2
);
  reg [`DATA_WIDTH - 1:0] mem [(1<<`ADDR_WIDTH)-1:0];
  integer i;
  assign rdata1 =  mem[raddr1];
  assign rdata2 =  mem[raddr2];
  always @(posedge clk )
  begin
    if(rst)
       for(i=0;i<`DATA_WIDTH;i=i+1)
           mem[i] <= `DATA_WIDTH'd0;
    else if(wen)
      mem[waddr] <= (waddr == `ADDR_WIDTH'd0) ? `DATA_WIDTH'd0 : wdata;  
  end    
	// TODO: insert your code
endmodule
