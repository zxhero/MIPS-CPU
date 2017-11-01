//////////////////////////////////////////////////////////////////////////////////
//* Author: Xu Zhang (zhangxu415@mails.ucas.ac.cn)

// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define C_M_AXI_ADDR_WIDTH 32

module dma_engine  #(
  parameter integer  C_M_AXI_DATA_WIDTH       = 32,
  parameter ADDR_WIDTH = 16
)
(
  input clk,
  input rst,
//port to ideal_mem
  input  [C_M_AXI_DATA_WIDTH-1 :0]  wdata_from_mem,
  output  [C_M_AXI_DATA_WIDTH-1 :0]  rdata_to_mem,
  output  reg                       MEMwrite,
  output  reg                       MEMread,
  output  reg [ADDR_WIDTH -3:0]     waddr,
  output  reg [ADDR_WIDTH -3:0]     raddr,
//port to requst select
  input   [ADDR_WIDTH -3:0]          reg_addr,
  input   [C_M_AXI_DATA_WIDTH-1 :0]  reg_data,
  input                              reg_write,
  output                             mem_requst_ack,
  input                              mem_enable_ack,
//port to interrupt control
  output                            interrupt_intr,
  input                             interrupt_entr,
//port to axi_master
  output [`C_M_AXI_ADDR_WIDTH-1:0]  raddr_to_ddr,
  output [`C_M_AXI_ADDR_WIDTH-1:0]  waddr_to_ddr,
  input  [C_M_AXI_DATA_WIDTH-1 :0]  rdata_from_ddr,
  output [C_M_AXI_DATA_WIDTH-1 :0]  wdata_to_ddr,
  output  reg                      ack_to_axi,
  input                             ack_from_axi,
  input                             response_from_axi,
  output reg                       response_to_axi,
  output reg                       dma_start,
  output                            dma_type,
  output  reg [3:0]                burst_len,
  input                             WCOMPLETE,
  input                             RCOMPLETE,
  input   [3:0]                    read_index  
    );
//the register keeps the addr to DDR3 0x0000_8000
  reg   [C_M_AXI_DATA_WIDTH-1:0]     DMA_SRC_ADDR;
//the register keeps the addr to ideal_mem  0x0000_8004
  reg   [C_M_AXI_DATA_WIDTH-1: 0]    DMA_DEST_ADDR;
//the register keeps the byte size of transaction,at most 60 byte,0x0000_8008
  reg   [C_M_AXI_DATA_WIDTH-1 : 0]  DMA_SIZE;
//0x0000_800C
  reg   [C_M_AXI_DATA_WIDTH-1 : 0]  DMA_CTRL_STAT;
//initial DMA
  reg   burst_transaction;
  always@(posedge clk)
  begin
     if(rst)
     begin
        DMA_SRC_ADDR <= {C_M_AXI_DATA_WIDTH{1'b0}};
        DMA_DEST_ADDR <= {C_M_AXI_DATA_WIDTH{1'b0}};
        DMA_SIZE <= {C_M_AXI_DATA_WIDTH{1'b0}};
        DMA_CTRL_STAT <= {C_M_AXI_DATA_WIDTH{1'b0}};
        burst_len <= 4'd0;
     end
     else if(reg_write)
     begin
        case(reg_addr[2:0])
        3'b000: begin
                DMA_SRC_ADDR <= reg_data;
                DMA_DEST_ADDR <= DMA_DEST_ADDR;
                DMA_SIZE <= DMA_SIZE;
                DMA_CTRL_STAT <= DMA_CTRL_STAT;
                burst_len <= burst_len;
                end
        3'b001: begin
                DMA_SRC_ADDR <= DMA_SRC_ADDR;
                DMA_DEST_ADDR <= reg_data;
                DMA_SIZE <= DMA_SIZE;
                DMA_CTRL_STAT <= DMA_CTRL_STAT;
                burst_len <= burst_len;
                end
        3'b010:begin
                DMA_SRC_ADDR <= DMA_SRC_ADDR;
                DMA_DEST_ADDR <= DMA_DEST_ADDR;
                DMA_SIZE <= reg_data;
                DMA_CTRL_STAT <= DMA_CTRL_STAT;
                burst_len <= reg_data[5:2];
                end
        3'b011: begin
                DMA_SRC_ADDR <= DMA_SRC_ADDR;
                DMA_DEST_ADDR <= DMA_DEST_ADDR;
                DMA_SIZE <= DMA_SIZE;
                DMA_CTRL_STAT <= reg_data;
                burst_len <= burst_len;
                end
        default: begin
                 DMA_SRC_ADDR <= DMA_SRC_ADDR;
                 DMA_DEST_ADDR <= DMA_DEST_ADDR;
                 DMA_SIZE <= DMA_SIZE;
                 DMA_CTRL_STAT <= DMA_CTRL_STAT;
                 burst_len <= burst_len;
                 end
        endcase
     end
     else if(WCOMPLETE|RCOMPLETE)
     begin
        DMA_SRC_ADDR <= DMA_SRC_ADDR;
        DMA_DEST_ADDR <= DMA_DEST_ADDR;
        DMA_SIZE <= DMA_SIZE;
        DMA_CTRL_STAT <= {1'b1,DMA_CTRL_STAT[30:1],1'b0};
        burst_len <= burst_len;
     end
     else if(interrupt_entr)
     begin
        DMA_SRC_ADDR <= DMA_SRC_ADDR;
        DMA_DEST_ADDR <= DMA_DEST_ADDR;
        DMA_SIZE <= DMA_SIZE;
        DMA_CTRL_STAT <= {1'b0,DMA_CTRL_STAT[30:0]};
        burst_len <= burst_len;
     end
     else
     begin
        DMA_SRC_ADDR <= DMA_SRC_ADDR;
        DMA_DEST_ADDR <= DMA_DEST_ADDR;
        DMA_SIZE <= DMA_SIZE;
        DMA_CTRL_STAT <= DMA_CTRL_STAT;
        burst_len <= burst_len;
     end
  end
//requst for ideal_mem
        assign mem_requst_ack = DMA_CTRL_STAT[0];
 
//allowed to read/write ideal_mem
  assign dma_type = DMA_CTRL_STAT[1];
  assign wdata_to_ddr = wdata_from_mem;
  assign raddr_to_ddr = DMA_SRC_ADDR[`C_M_AXI_ADDR_WIDTH -1:0];
  assign waddr_to_ddr = DMA_SRC_ADDR[`C_M_AXI_ADDR_WIDTH -1:0];
  
  always @(posedge clk)
  begin
     if(rst) dma_start <= 1'b0;
     else if(~dma_start&&mem_enable_ack&&mem_requst_ack&&~burst_transaction)
             dma_start <= 1'b1;
     else if(burst_transaction)
             dma_start <= 1'b0;
     else    dma_start <= dma_start;
  end
  always @(posedge clk)
  begin
      if(rst) burst_transaction <= 1'b0;
      else if(~burst_transaction && dma_start)
              burst_transaction <= 1'b1;
      else if(WCOMPLETE | RCOMPLETE)
              burst_transaction <= 1'b0;
      else    burst_transaction <= burst_transaction;
  end
 //ideal_mem -> ddr
  always @(posedge clk)
  begin
     if(rst | ~mem_enable_ack) 
	 begin
	         MEMread <= 1'b0;
		     raddr   <= 'd0;
     end
     else if(dma_start && DMA_CTRL_STAT[1] &&~MEMread) 
	 begin
             MEMread <= 1'b1;
			 raddr   <= DMA_DEST_ADDR[ADDR_WIDTH-1:2];
	 end
     else if(~ack_to_axi && response_from_axi && DMA_CTRL_STAT[1])
	 begin
             MEMread <= 1'b1;
			 raddr   <= raddr + 14'd1;                                             //changed
     end
     else if(~response_from_axi && DMA_CTRL_STAT[1])
	 begin
             MEMread <= 1'b0;
			 raddr    <= raddr;
     end
     else    
	 begin
	         MEMread <= MEMread; 
			 raddr   <= raddr;
     end          		
  end
  always @(posedge clk)
  begin
     if(rst) ack_to_axi <= 1'b0;
     else if(dma_start && DMA_CTRL_STAT[1] && ~ack_to_axi)
             ack_to_axi <= 1'b1;
     else if(~ack_to_axi && response_from_axi && DMA_CTRL_STAT[1])
             ack_to_axi <= 1'b1;
     else if(~response_from_axi && DMA_CTRL_STAT[1])
             ack_to_axi <= 1'b0;
     else    ack_to_axi <= ack_to_axi;
  end
//ddr -> ideal_mem  
  assign rdata_to_mem = rdata_from_ddr & {32{MEMwrite}};
  always @(posedge clk)
  begin
     if(rst) response_to_axi <= 1'b0;
     else if(~DMA_CTRL_STAT[1] && ack_from_axi &&response_to_axi)
             response_to_axi <= 1'b0;
     else if(~DMA_CTRL_STAT[1] && ack_from_axi &&~response_to_axi)
             response_to_axi <= 1'b1;
     else    response_to_axi <= response_to_axi;
  end
  always @(posedge clk)
  begin
     if(rst | ~mem_enable_ack) MEMwrite <= 1'b0;
	 else if(ack_from_axi && ~response_to_axi)
	         MEMwrite <= 1'b1;
	 else if(MEMwrite)
	         MEMwrite <= 1'b0;
	 else    MEMwrite <= MEMwrite;
  end
  always @(posedge clk)
  begin
     if(rst | ~mem_enable_ack) waddr <= 'd0;
	 else if(read_index == 0 && ack_from_axi)
	         waddr <= DMA_DEST_ADDR[ADDR_WIDTH-1:2];
	 else if(ack_from_axi && ~response_to_axi)
	         waddr <= waddr + 'd1;
	 else    waddr <= waddr;
  end
//transcation finished
  assign interrupt_intr = DMA_CTRL_STAT[31];
endmodule
