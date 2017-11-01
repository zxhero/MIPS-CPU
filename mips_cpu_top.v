/* =========================================
* Top module for MIPS cores in the FPGA
* evaluation platform
*
* Author1: Yisong Chang (changyisong@ict.ac.cn)
* Author2: Xu Zhang (zhangxu414@mails.ucas.ac.cn)
* Date: 15/07/2017
* Version: v0.0.2
*===========================================
*/

`timescale 10 ns / 1 ns
`define C_M_AXI_ADDR_WIDTH 32
`define C_M_AXI_DATA_WIDTH 32
module mips_cpu_top (

`ifndef MIPS_CPU_FULL_SIMU
	//AXI AR Channel
    input  [15:0]	mips_cpu_axi_if_araddr,
    output			mips_cpu_axi_if_arready,
    input			mips_cpu_axi_if_arvalid,

	//AXI AW Channel
    input  [15:0]	mips_cpu_axi_if_awaddr,
    output			mips_cpu_axi_if_awready,
    input			mips_cpu_axi_if_awvalid,

	//AXI B Channel
    input			mips_cpu_axi_if_bready,
    output [1:0]	mips_cpu_axi_if_bresp,
    output			mips_cpu_axi_if_bvalid,

	//AXI R Channel
    output [31:0]	mips_cpu_axi_if_rdata,
    input			mips_cpu_axi_if_rready,
    output [1:0]	mips_cpu_axi_if_rresp,
    output			mips_cpu_axi_if_rvalid,

	//AXI W Channel
    input  [31:0]	mips_cpu_axi_if_wdata,
    output			mips_cpu_axi_if_wready,
    input  [3:0]	mips_cpu_axi_if_wstrb,
    input			mips_cpu_axi_if_wvalid,
`endif

`ifdef MIPS_CPU_FULL_SIMU
	output			mips_cpu_pc_sig,
	output [7:0]	mips_cpu_perf_sig,
`endif
	input			mips_cpu_clk,
    input			mips_cpu_reset,
    //ddr3 ports
        output wire [`C_M_AXI_ADDR_WIDTH-1:0]      mips_cpu_M_AXI_AWADDR,
        output wire [7:0]                          mips_cpu_M_AXI_AWLEN,
        output wire [2:0]                          mips_cpu_M_AXI_AWSIZE,
        output wire [1:0]                          mips_cpu_M_AXI_AWBURST,
        output wire [3:0]                          mips_cpu_M_AXI_AWCACHE,
      
        output wire                                mips_cpu_M_AXI_AWVALID,
        input  wire                                mips_cpu_M_AXI_AWREADY,
      
        output wire [31:0]                         mips_cpu_M_AXI_WDATA,
        output wire [3:0]                          mips_cpu_M_AXI_WSTRB,
        output wire                                mips_cpu_M_AXI_WLAST,
        output wire                                mips_cpu_M_AXI_WVALID,
        input  wire                                mips_cpu_M_AXI_WREADY,
      
        input  wire [1:0]                          mips_cpu_M_AXI_BRESP,
        input  wire                                mips_cpu_M_AXI_BVALID,
        output wire                                mips_cpu_M_AXI_BREADY,
      
        output wire [`C_M_AXI_ADDR_WIDTH-1:0]      mips_cpu_M_AXI_ARADDR,
        output wire [7:0]                          mips_cpu_M_AXI_ARLEN,
        output wire [2:0]                          mips_cpu_M_AXI_ARSIZE,
        output wire [1:0]                          mips_cpu_M_AXI_ARBURST,
        output wire [3:0]                          mips_cpu_M_AXI_ARCACHE,
      
        output wire                                mips_cpu_M_AXI_ARVALID,
        input  wire                                mips_cpu_M_AXI_ARREADY,
      
        input  wire [31:0]                         mips_cpu_M_AXI_RDATA,
        input  wire [1:0]                          mips_cpu_M_AXI_RRESP,                              //error detect(no use)
        input  wire                                mips_cpu_M_AXI_RLAST,
        input  wire                                mips_cpu_M_AXI_RVALID,
        output wire                                mips_cpu_M_AXI_RREADY
);

//at most 2KB+ ideal memory, so MEM_ADDR_WIDTH cannot exceed 16
localparam		MEM_ADDR_WIDTH = 11;

//AXI Lite IF ports to requst select
wire [MEM_ADDR_WIDTH - 3:0]		axi_lite_mem_addr;

wire			axi_lite_mem_wren;
wire [31:0]		axi_lite_mem_wdata;
wire			axi_lite_mem_rden;
wire [31:0]		axi_lite_mem_rdata;

//MIPS CPU ports to requst select
wire [31:0]		mips_mem_addr;
wire			MemWrite;
wire [31:0]		mips_mem_wdata;
wire			MemRead;

wire [31:0]		PC;

//CPU ports to interrupt control
wire           ENTR;

//requst select ports to CPU
wire [31:0]		Instruction;
wire [31:0]		mips_mem_rdata;
wire           ack_to_cpu;

//requst select ports to ideal mem
wire [MEM_ADDR_WIDTH - 3:0] select_mem_Waddr;
wire [MEM_ADDR_WIDTH - 3:0] select_mem_Raddr1;
wire [MEM_ADDR_WIDTH - 3:0] select_mem_Raddr2;

wire			select_mem_Wren;
wire [31:0]		select_mem_Wdata;
wire			select_mem_Rden1;
wire			select_mem_Rden2;
       
//requst select ports to dma
wire [MEM_ADDR_WIDTH -3:0]  reg_addr;
wire [31 :0]                reg_data;
wire                        reg_write;
wire                        mem_enable_ack;

//requst select ports to interrupt control
wire                        interrupt_write;
wire  [31 :0]               mask;

//dma ports to interrupt control
wire                        interrupt_intr;

//dma ports to ideal mem
wire  [31 :0]               dma_rdata_to_mem;
wire                        dma_MEMwrite_to_mem;
wire                        dma_MEMread_to_mem;
wire  [MEM_ADDR_WIDTH -3:0] dma_waddr_to_mem;
wire  [MEM_ADDR_WIDTH -3:0] dma_raddr_to_mem;
//dma ports to requst select
wire                        dma_mem_requst_ack;

//dma ports to axi master
wire [`C_M_AXI_ADDR_WIDTH-1:0]  raddr_to_ddr;
wire [`C_M_AXI_ADDR_WIDTH-1:0]  waddr_to_ddr;
wire [31 :0]                    wdata_to_ddr;
wire                            ack_to_axi;
wire                            response_to_axi;
wire                            dma_start;
wire                            dma_type;
wire [3:0]                      burst_len;

//axi master ports to dma
wire  [31 :0]               rdata_from_ddr;
wire                        ack_from_axi;
wire                        response_from_axi;
wire                        WCOMPLETE;
wire                        RCOMPLETE;
wire [3:0]                  read_index;

//interrupt control ports to CPU
wire                        INTR;

//interrupt control ports to dma
wire                        interrupt_entr;

//ideal mem ports to requst select
wire [31:0]		             select_mem_Rdata1; 

//ideal mem ports to dma
wire  [31 :0]               wdata_from_mem_to_dma;

//Ideal memory ports
wire [MEM_ADDR_WIDTH - 3:0]	Waddr;
wire [MEM_ADDR_WIDTH - 3:0]	Raddr;

wire			Wren;
wire [31:0]		Wdata;
wire			Rden;
wire [31:0]		mem_Rdata2;

//Synchronized reset signal generated from AXI Lite IF
wire			mips_rst;

`ifdef MIPS_CPU_FULL_SIMU
reg [1:0]		mips_cpu_rst_i = 2'b11;
wire			mips_cpu_rst;
`endif
//CPU performance counter
(*mark_debug = "true"*) wire [31:0]		cycle_cnt;
(*mark_debug = "true"*) wire [31:0]		inst_cnt;
(*mark_debug = "true"*) wire [31:0]		br_cnt;
(*mark_debug = "true"*) wire [31:0]		ld_cnt;
(*mark_debug = "true"*) wire [31:0]		st_cnt;
(*mark_debug = "true"*) wire [31:0]		user1_cnt;
(*mark_debug = "true"*) wire [31:0]		user2_cnt;
(*mark_debug = "true"*) wire [31:0]		user3_cnt;

//axi master module
axi_master   #(
        .C_M_AXI_DATA_WIDTH('d32)
)  axi_master (
  .WCOMPLETE(WCOMPLETE),
  .RCOMPLETE(RCOMPLETE),

  .M_AXI_ACLK(mips_cpu_clk),
  .M_AXI_ARESETN(~mips_cpu_reset),
  
  .M_AXI_AWADDR(mips_cpu_M_AXI_AWADDR),
  .M_AXI_AWLEN(mips_cpu_M_AXI_AWLEN),
  .M_AXI_AWSIZE(mips_cpu_M_AXI_AWSIZE),
  .M_AXI_AWBURST(mips_cpu_M_AXI_AWBURST),
  .M_AXI_AWCACHE(mips_cpu_M_AXI_AWCACHE),

  .M_AXI_AWVALID(mips_cpu_M_AXI_AWVALID),
  .M_AXI_AWREADY(mips_cpu_M_AXI_AWREADY),

  .M_AXI_WDATA(mips_cpu_M_AXI_WDATA),
  .M_AXI_WSTRB(mips_cpu_M_AXI_WSTRB),
  .M_AXI_WLAST(mips_cpu_M_AXI_WLAST),
  .M_AXI_WVALID(mips_cpu_M_AXI_WVALID),
  .M_AXI_WREADY(mips_cpu_M_AXI_WREADY),

  .M_AXI_BRESP(mips_cpu_M_AXI_BRESP),
  .M_AXI_BVALID(mips_cpu_M_AXI_BVALID),
  .M_AXI_BREADY(mips_cpu_M_AXI_BREADY),

  .M_AXI_ARADDR(mips_cpu_M_AXI_ARADDR),
  .M_AXI_ARLEN(mips_cpu_M_AXI_ARLEN),
  .M_AXI_ARSIZE(mips_cpu_M_AXI_ARSIZE),
  .M_AXI_ARBURST(mips_cpu_M_AXI_ARBURST),
  .M_AXI_ARCACHE(mips_cpu_M_AXI_ARCACHE),

  .M_AXI_ARVALID(mips_cpu_M_AXI_ARVALID),
  .M_AXI_ARREADY(mips_cpu_M_AXI_ARREADY),

  .M_AXI_RDATA(mips_cpu_M_AXI_RDATA),
  .M_AXI_RRESP(mips_cpu_M_AXI_RRESP),                              //error detect(no use)
  .M_AXI_RLAST(mips_cpu_M_AXI_RLAST),
  .M_AXI_RVALID(mips_cpu_M_AXI_RVALID),
  .M_AXI_RREADY(mips_cpu_M_AXI_RREADY),

  .M_AXI_DMA_raddr(raddr_to_ddr),
  . M_AXI_DMA_rdata(rdata_from_ddr),
  .ack_to_DMA(ack_from_axi),
  .response_from_DMA(response_to_axi),
  .M_AXI_DMA_START(dma_start),
  .M_AXI_DMA_TYPE(dma_type),
  .C_BURST_LEN(burst_len),
  .read_index(read_index),

  .M_AXI_DMA_waddr(waddr_to_ddr),
  .M_AXI_DMA_wdata(wdata_to_ddr),
  .ack_from_DMA(ack_to_axi),
  .response_to_DMA(response_from_axi)
);

//axi lite module
`ifndef MIPS_CPU_FULL_SIMU
  //AXI Lite Interface Module
  //Receving memory read/write requests from ARM CPU cores
  axi_lite_if 	#(
	  .ADDR_WIDTH		(MEM_ADDR_WIDTH)
  ) u_axi_lite_slave (
	  .S_AXI_ACLK		(mips_cpu_clk),
	  .S_AXI_ARESETN	(~mips_cpu_reset),
	  
	  .S_AXI_ARADDR		(mips_cpu_axi_if_araddr),
	  .S_AXI_ARREADY	(mips_cpu_axi_if_arready),
	  .S_AXI_ARVALID	(mips_cpu_axi_if_arvalid),
	  
	  .S_AXI_AWADDR		(mips_cpu_axi_if_awaddr),
	  .S_AXI_AWREADY	(mips_cpu_axi_if_awready),
	  .S_AXI_AWVALID	(mips_cpu_axi_if_awvalid),
	  
	  .S_AXI_BREADY		(mips_cpu_axi_if_bready),
	  .S_AXI_BRESP		(mips_cpu_axi_if_bresp),
	  .S_AXI_BVALID		(mips_cpu_axi_if_bvalid),
	  
	  .S_AXI_RDATA		(mips_cpu_axi_if_rdata),
	  .S_AXI_RREADY		(mips_cpu_axi_if_rready),
	  .S_AXI_RRESP		(mips_cpu_axi_if_rresp),
	  .S_AXI_RVALID		(mips_cpu_axi_if_rvalid),
	  
	  .S_AXI_WDATA		(mips_cpu_axi_if_wdata),
	  .S_AXI_WREADY		(mips_cpu_axi_if_wready),
	  .S_AXI_WSTRB		(mips_cpu_axi_if_wstrb),
	  .S_AXI_WVALID		(mips_cpu_axi_if_wvalid),
	  
	  .AXI_Address		(axi_lite_mem_addr),
	  .AXI_MemRead		(axi_lite_mem_rden),
	  .AXI_MemWrite		(axi_lite_mem_wren),
	  .AXI_Read_data	(axi_lite_mem_rdata),
	  .AXI_Write_data	(axi_lite_mem_wdata),

	  .cycle_cnt		(cycle_cnt),
	  .inst_cnt			(inst_cnt),
	  .br_cnt			(br_cnt),
	  .ld_cnt			(ld_cnt),
	  .st_cnt			(st_cnt),
	  .user1_cnt		(user1_cnt),
	  .user2_cnt		(user2_cnt),
	  .user3_cnt		(user3_cnt),
	  
	  .mips_rst			(mips_rst)
  );
`else
  assign axi_lite_mem_addr = 'd0;
  assign axi_lite_mem_rden = 'd0;
  assign axi_lite_mem_wren = 'd0;
  assign axi_lite_mem_wdata = 'd0;
  assign mips_rst = mips_cpu_reset;

  assign mips_cpu_perf_sig[0] = |cycle_cnt[31:0];
  assign mips_cpu_perf_sig[1] = |inst_cnt[31:0];
  assign mips_cpu_perf_sig[2] = |br_cnt[31:0];
  assign mips_cpu_perf_sig[3] = |ld_cnt[31:0];
  assign mips_cpu_perf_sig[4] = |st_cnt[31:0];
  assign mips_cpu_perf_sig[5] = |user1_cnt[31:0];
  assign mips_cpu_perf_sig[6] = |user2_cnt[31:0];
  assign mips_cpu_perf_sig[7] = |user3_cnt[31:0];

`endif

`ifdef MIPS_CPU_FULL_SIMU
	always @ (posedge mips_cpu_clk)
	begin
		mips_cpu_rst_i <= {mips_cpu_rst_i[0], mips_cpu_reset};
	end
	assign mips_cpu_rst = mips_cpu_rst_i[1];
`endif

//MIPS CPU cores
  mips_cpu	u_mips_cpu (	
	  .clk			(mips_cpu_clk),
`ifdef MIPS_CPU_FULL_SIMU
	  .rst			(mips_cpu_rst),
`else
	  .rst			(mips_rst),
`endif

	  .PC			(PC),
	  .Instruction	(Instruction),

	  .Address		(mips_mem_addr),
	  .MemWrite		(MemWrite),
	  .Write_data	(mips_mem_wdata),
	  .MemRead		(MemRead),
	  .Read_data	(mips_mem_rdata),

	  .cycle_cnt	(cycle_cnt),
	  .inst_cnt		(inst_cnt),
	  .br_cnt		(br_cnt),
	  .ld_cnt		(ld_cnt),
	  .st_cnt		(st_cnt),
	  .user1_cnt	(user1_cnt),
	  .user2_cnt	(user2_cnt),
	  .user3_cnt	(user3_cnt),
	  
	  .ENTR         (ENTR),
	  .ack_from_mem (ack_to_cpu),
	  .INTR         (INTR)
  );

`ifdef MIPS_CPU_FULL_SIMU
  assign mips_cpu_pc_sig = PC[2];
`endif

// dma engine module
  dma_engine  #(
  .C_M_AXI_DATA_WIDTH(32),
  .ADDR_WIDTH(MEM_ADDR_WIDTH)
)dma(
  .clk(mips_cpu_clk),
`ifdef MIPS_CPU_FULL_SIMU
        .rst            (mips_cpu_rst),
  `else
        .rst            (mips_rst),
  `endif
//port to ideal_mem
  .wdata_from_mem(wdata_from_mem_to_dma),
  .rdata_to_mem(dma_rdata_to_mem),
  .MEMwrite(dma_MEMwrite_to_mem),
  .MEMread(dma_MEMread_to_mem),
  .waddr(dma_waddr_to_mem),
  .raddr(dma_raddr_to_mem),
//port to requst select
  .reg_addr(reg_addr),
  .reg_data(reg_data),
  .reg_write(reg_write),
  .mem_requst_ack(dma_mem_requst_ack),
  .mem_enable_ack(mem_enable_ack),
//port to interrupt control
  .interrupt_intr(interrupt_intr),
  .interrupt_entr(interrupt_entr),
//port to axi_master
  .raddr_to_ddr(raddr_to_ddr),
  .waddr_to_ddr(waddr_to_ddr),
  .rdata_from_ddr(rdata_from_ddr),
  .wdata_to_ddr(wdata_to_ddr),
  .ack_to_axi(ack_to_axi),
  .ack_from_axi(ack_from_axi),
  .response_from_axi(response_from_axi),
  .response_to_axi(response_to_axi),
  .dma_start(dma_start),
  .dma_type(dma_type),
  .burst_len(burst_len),
  .WCOMPLETE(WCOMPLETE),
  .RCOMPLETE(RCOMPLETE),
  .read_index(read_index)  
    );

//interrupt control module
  interrupt_control #(
  .C_M_AXI_DATA_WIDTH(32)
)interrupt_con(
  .clk(mips_cpu_clk),
`ifdef MIPS_CPU_FULL_SIMU
        .rst            (mips_cpu_rst),
  `else
        .rst            (mips_rst),
  `endif 
//port to requst select
  .interrupt_write(interrupt_write),
  .mask(mask),
//port to DMA
  .INTR_from_dma(interrupt_intr),
  .ENTR_to_dma(interrupt_entr),
//port to CPU
  .INTR(INTR),
  .ENTR(ENTR)
    );
	
// mem requst select module
  requst_select #(
         .C_M_AXI_DATA_WIDTH(32),
         .ADDR_WIDTH(MEM_ADDR_WIDTH)
  )mem_requst_select (
//port to axi_lite
  .AXI_Address(axi_lite_mem_addr),
  .AXI_Write_data(axi_lite_mem_wdata),
  .AXI_MemWrite(axi_lite_mem_wren),
  .AXI_MemRead(axi_lite_mem_rden),
  .AXI_Read_data(axi_lite_mem_rdata),
`ifdef MIPS_CPU_FULL_SIMU
        .mips_rst            (mips_cpu_rst),
  `else
        .mips_rst            (mips_rst),
  `endif
//port to cpu
    .PC(PC),
	.Instruction(Instruction),

	.Address(mips_mem_addr),
	.MemWrite(MemWrite),
	.Write_data(mips_mem_wdata),

	.Read_data(mips_mem_rdata),
	.MemRead(MemRead),
	.ack_to_cpu(ack_to_cpu),
//port to dma
    .reg_addr(reg_addr),
    .reg_data(reg_data),
    .reg_write(reg_write),
    .mem_requst_ack(dma_mem_requst_ack),
    .mem_enable_ack(mem_enable_ack),
//port to interrupt control
    .interrupt_write(interrupt_write),
    .mask(mask),
//port to ideal_mem
	 .Waddr(select_mem_Waddr),			//Memory write port address
	 .Raddr1(select_mem_Raddr1),			//Read port 1 address
	 .Raddr2(select_mem_Raddr2),			//Read port 2 address

	 .Wren(select_mem_Wren),			//write enable
	 .Rden1(select_mem_Rden1),			//port 1 read enable
	 .Rden2(select_mem_Rden2),			//port 2 read enable

	 .Wdata(select_mem_Wdata),			//Memory write data
	 .Rdata1(select_mem_Rdata1),			//Memory read data 1
	 .Rdata2(mem_Rdata2)			//Memory read data 2
    );

//Distributed memory module used as main memory of MIPS CPU
          assign Waddr = select_mem_Waddr | dma_waddr_to_mem;
          assign Raddr = select_mem_Raddr2| dma_raddr_to_mem;
          assign Wren = select_mem_Wren | dma_MEMwrite_to_mem;
          assign Rden = select_mem_Rden2 | dma_MEMread_to_mem;
          assign Wdata = select_mem_Wdata | dma_rdata_to_mem;

  assign wdata_from_mem_to_dma = (mem_Rdata2 & {32{dma_MEMread_to_mem}}) | ({32{~dma_MEMread_to_mem}});
  ideal_mem		# (
	  .ADDR_WIDTH	(MEM_ADDR_WIDTH)
  ) u_ideal_mem (
	  .clk			(mips_cpu_clk),
	  
	  .Waddr		(Waddr),
	  .Raddr1		(select_mem_Raddr1),
	  .Raddr2		(Raddr),

	  .Wren			(Wren),
	  .Rden1		(select_mem_Rden1),
	  .Rden2		(Rden),

	  .Wdata		(Wdata),
	  .Rdata1		(select_mem_Rdata1),
	  .Rdata2		(mem_Rdata2)
  );

endmodule
