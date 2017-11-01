//////////////////////////////////////////////////////////////////////////////////
//Author: Xu Zhang (zhangxu415@mails.ucas.ac.cn)
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module interrupt_control #(
  parameter integer  C_M_AXI_DATA_WIDTH       = 32
)
(
  input clk,
  input rst,
//port to requst select
  input                            interrupt_write,
  input  [C_M_AXI_DATA_WIDTH-1 : 0] mask,
//port to DMA
  input                             INTR_from_dma,
  output                            ENTR_to_dma,
//port to CPU
  output                            INTR,
  input                             ENTR
    );
  reg SR;
  //0x0000_8010
  reg   [C_M_AXI_DATA_WIDTH-1 : 0]  DMA_interrupt;
//set interrupt mask
  always @(posedge clk)
  begin
      if(rst)  DMA_interrupt <= 'd0;
      else if(interrupt_write) 
               DMA_interrupt <= mask;
      else     DMA_interrupt <= DMA_interrupt;
  end
//interrupt requst
  assign INTR = INTR_from_dma & DMA_interrupt[0] & ~SR;
//interrupt enable
  assign ENTR_to_dma = INTR_from_dma & ENTR;
  always @(posedge clk)
  begin
     if(rst)
     begin
         SR  <= 1'b0;
     end
     else if(ENTR )
     begin
         SR  <= 1'b1;
     end
     else
     begin
         SR  <= 1'b0;
     end
  end
endmodule
