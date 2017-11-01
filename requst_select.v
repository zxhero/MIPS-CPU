//////////////////////////////////////////////////////////////////////////////////
//* Author2: Xu Zhang (zhangxu414@mails.ucas.ac.cn)
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module requst_select #(
  parameter integer  C_M_AXI_DATA_WIDTH       = 32,
  parameter ADDR_WIDTH = 16
)
(
//port to axi_lite
  input wire [ADDR_WIDTH - 3:0]	       AXI_Address,
  input wire [31:0]                   AXI_Write_data,
  input wire                          AXI_MemWrite,
  input wire                          AXI_MemRead,
  output  wire [31:0]                 AXI_Read_data,
  input                                mips_rst,
//port to cpu
  input [31:0]                         PC,
  output  [31:0]                       Instruction,

  input [31:0]                         Address,
  input                                MemWrite,
  input [31:0]                         Write_data,

  output  [31:0]                       Read_data,
  input                                MemRead,
  output                               ack_to_cpu,
//port to dma
  output   [ADDR_WIDTH -3:0]          reg_addr,
  output   [C_M_AXI_DATA_WIDTH-1 :0]  reg_data,
  output                              reg_write,
  input                               mem_requst_ack,
  output                              mem_enable_ack,
//port to interrupt control
  output                              interrupt_write,
  output   [C_M_AXI_DATA_WIDTH-1 :0]  mask,
//port to ideal_mem
  output [ADDR_WIDTH - 3:0]	          Waddr,			//Memory write port address
  output [ADDR_WIDTH - 3:0]	          Raddr1,			//Read port 1 address,PC
  output [ADDR_WIDTH - 3:0]	          Raddr2,			//Read port 2 address

  output			                  Wren,			//write enable
  output			                  Rden1,			//port 1 read enable
  output			                  Rden2,			//port 2 read enable

  output [31:0]             	      Wdata,			//Memory write data
  input [31:0]	                      Rdata1,			//Memory read data 1, instruction
  input [31:0]	                      Rdata2			//Memory read data 2
    );
  
  wire cpu_mem_rd;
  wire axi_lite_mem_rd;
  wire cpu_mem_wr;
  wire axi_lite_mem_wren;
  wire mem_Wren;
  
  assign Raddr1 = PC[ADDR_WIDTH -1 : 2];
  assign Rden1 = 1'b1;
  assign Instruction = Rdata1;
  assign ack_to_cpu = (~mem_requst_ack) &  (MemRead|MemWrite) & (~mips_rst);
  assign mem_enable_ack = mem_requst_ack & (~ack_to_cpu);
/*
 * ============================================================== 
 * Memory read arbitration between AXI Lite IF and MIPS CPU and DMA
 * ==============================================================
 */

  //AXI Lite IF can read distributed memory only when MIPS CPU has no memory operations
  //if contention occurs, return 0xFFFFFFFF to Read_data port of AXI Lite IF
  
  assign cpu_mem_rd = ack_to_cpu & (~mips_rst) & MemRead;
  assign axi_lite_mem_rd =  AXI_MemRead & (mips_rst | (~cpu_mem_rd) & (~mem_enable_ack));
  
  assign Rden2 = (cpu_mem_rd | axi_lite_mem_rd) & (~mem_enable_ack) ;

  assign AXI_Read_data = ({32{axi_lite_mem_rd}} & Rdata2) | ({32{~axi_lite_mem_rd}});

  assign Read_data = ({32{cpu_mem_rd}} & Rdata2) | ({32{~cpu_mem_rd}});

  assign Raddr2 = ({ADDR_WIDTH-2{cpu_mem_rd}} & Address[ADDR_WIDTH - 1:2]) | 
				({ADDR_WIDTH-2{axi_lite_mem_rd}} & AXI_Address);

/*
 * ==============================================================
 * Memory write arbitration between AXI Lite IF and MIPS CPU and DMA
 * ==============================================================
 */
  //AXI Lite IF only generates memory write requests before MIPS CPU is running
  assign cpu_mem_wr = ack_to_cpu & (~mips_rst) & MemWrite;
  assign axi_lite_mem_wren = AXI_MemWrite & (mips_rst | (~cpu_mem_wr) & (~mem_enable_ack));
  assign mem_Wren = cpu_mem_wr | axi_lite_mem_wren;

  assign Wdata = ({32{cpu_mem_wr}} & Write_data) | 
				({32{axi_lite_mem_wren}} & AXI_Write_data);

  assign Waddr = ({(ADDR_WIDTH-2){cpu_mem_wr}} & Address[ADDR_WIDTH - 1:2]) | 
				({ADDR_WIDTH-2{axi_lite_mem_wren}} & AXI_Address);
/*
 * ==============================================================
 * DMA write from MIPS CPU
 * ==============================================================
 */
  assign reg_write = mem_Wren & Waddr[13] & ~Waddr[2];
  assign reg_addr = Waddr & ({ADDR_WIDTH-2{reg_write}});
  assign reg_data = Wdata & ({32{reg_write}});
   /*
   * ==============================================================
   * interrupt control write from MIPS CPU or axi_lite
   * ==============================================================
   */
   assign interrupt_write = mem_Wren & Waddr[13] & Waddr[2];
   assign mask = Wdata & ({32{interrupt_write}});
 /*
  * ==============================================================
  * ideal_mem write from MIPS CPU or axi_lite
  * ==============================================================
  */
  assign Wren = mem_Wren & ~reg_write & ~interrupt_write;
 
endmodule
