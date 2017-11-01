`timescale 10ns / 1ns

module mips_cpu_test
();

	reg				mips_cpu_clk;
    reg				mips_cpu_reset;

    wire            mips_cpu_pc_sig;
    wire [7:0]      mips_cpu_perf_sig;

	initial begin
		mips_cpu_clk = 1'b0;
		mips_cpu_reset = 1'b1;
		# 3
		mips_cpu_reset = 1'b0;

		# 2000000
		$finish;
	end

	always begin
		# 1 mips_cpu_clk = ~mips_cpu_clk;
	end
    wire [31:0]  mips_cpu_ddr_AWADDR;
    wire [7:0]   mips_cpu_ddr_AWLEN;
    wire [2:0]   mips_cpu_ddr_AWSIZE;
    wire [1:0]   mips_cpu_ddr_AWBURST;
    wire [3:0]   mips_cpu_ddr_AWCACHE;     
    wire mips_cpu_ddr_AWVALID;
    wire mips_cpu_ddr_AWREADY;            
    wire [31:0]  mips_cpu_ddr_WDATA;
    wire [3:0]   mips_cpu_ddr_WSTRB;
    wire mips_cpu_ddr_WLAST;
    wire mips_cpu_ddr_WVALID;
    wire mips_cpu_ddr_WREADY;      
    wire [1:0]   mips_cpu_ddr_BRESP;
    wire mips_cpu_ddr_BVALID;
    wire mips_cpu_ddr_BREADY;
    wire [31:0]  mips_cpu_ddr_ARADDR;
    wire [7:0]   mips_cpu_ddr_ARLEN;
    wire [2:0]   mips_cpu_ddr_ARSIZE;
    wire [1:0]   mips_cpu_ddr_ARBURST;
    wire [3:0]   mips_cpu_ddr_ARCACHE;     
    wire mips_cpu_ddr_ARVALID;
    wire mips_cpu_ddr_ARREADY;    
    wire [31:0]  mips_cpu_ddr_RDATA;
    wire [1:0]   mips_cpu_ddr_RRESP;                              //error detect(no use)
    wire mips_cpu_ddr_RLAST;
    wire mips_cpu_ddr_RVALID;
    wire mips_cpu_ddr_RREADY;
            
    mips_cpu_top    u_mips_cpu (
        .mips_cpu_clk       (mips_cpu_clk),
        .mips_cpu_reset     (mips_cpu_reset),

        .mips_cpu_pc_sig    (mips_cpu_pc_sig),
        .mips_cpu_perf_sig  (mips_cpu_perf_sig),
        
        .mips_cpu_M_AXI_AWADDR(mips_cpu_ddr_AWADDR),
        .mips_cpu_M_AXI_AWLEN(mips_cpu_ddr_AWLEN),
        .mips_cpu_M_AXI_AWSIZE(mips_cpu_ddr_AWSIZE),
        .mips_cpu_M_AXI_AWBURST(mips_cpu_ddr_AWBURST),
        .mips_cpu_M_AXI_AWCACHE(mips_cpu_ddr_AWCACHE),     
        .mips_cpu_M_AXI_AWVALID(mips_cpu_ddr_AWVALID),
        .mips_cpu_M_AXI_AWREADY(mips_cpu_ddr_AWREADY),            
        .mips_cpu_M_AXI_WDATA(mips_cpu_ddr_WDATA),
        .mips_cpu_M_AXI_WSTRB(mips_cpu_ddr_WSTRB),
        .mips_cpu_M_AXI_WLAST(mips_cpu_ddr_WLAST),
        .mips_cpu_M_AXI_WVALID(mips_cpu_ddr_WVALID),
        .mips_cpu_M_AXI_WREADY(mips_cpu_ddr_WREADY),      
        .mips_cpu_M_AXI_BRESP(mips_cpu_ddr_BRESP),
        .mips_cpu_M_AXI_BVALID(mips_cpu_ddr_BVALID),
        .mips_cpu_M_AXI_BREADY(mips_cpu_ddr_BREADY),
        .mips_cpu_M_AXI_ARADDR(mips_cpu_ddr_ARADDR),
        .mips_cpu_M_AXI_ARLEN(mips_cpu_ddr_ARLEN),
        .mips_cpu_M_AXI_ARSIZE(mips_cpu_ddr_ARSIZE),
        .mips_cpu_M_AXI_ARBURST(mips_cpu_ddr_ARBURST),
        .mips_cpu_M_AXI_ARCACHE(mips_cpu_ddr_ARCACHE),     
        .mips_cpu_M_AXI_ARVALID(mips_cpu_ddr_ARVALID),
        .mips_cpu_M_AXI_ARREADY(mips_cpu_ddr_ARREADY),    
        .mips_cpu_M_AXI_RDATA(mips_cpu_ddr_RDATA),
        .mips_cpu_M_AXI_RRESP(mips_cpu_ddr_RRESP),                              //error detect(no use)
        .mips_cpu_M_AXI_RLAST(mips_cpu_ddr_RLAST),
        .mips_cpu_M_AXI_RVALID(mips_cpu_ddr_RVALID),
        .mips_cpu_M_AXI_RREADY(mips_cpu_ddr_RREADY)
    );
    
    ddr3   design_1_wrapper(
    .S_AXI_araddr(mips_cpu_ddr_ARADDR),
    .S_AXI_arburst(mips_cpu_ddr_ARBURST),
    .S_AXI_arcache(mips_cpu_ddr_ARCACHE),
    .S_AXI_arlen(mips_cpu_ddr_ARLEN),
    .S_AXI_arlock('d0),
    .S_AXI_arprot('d0),
    .S_AXI_arready(mips_cpu_ddr_ARREADY),
    .S_AXI_arsize(mips_cpu_ddr_ARSIZE),
    .S_AXI_arvalid(mips_cpu_ddr_ARVALID),
    .S_AXI_awaddr(mips_cpu_ddr_AWADDR),
    .S_AXI_awburst(mips_cpu_ddr_AWBURST),
    .S_AXI_awcache(mips_cpu_ddr_AWCACHE),
    .S_AXI_awlen(mips_cpu_ddr_AWLEN),
    .S_AXI_awlock('d0),
    .S_AXI_awprot('d0),
    .S_AXI_awready(mips_cpu_ddr_AWREADY),
    .S_AXI_awsize(mips_cpu_ddr_AWSIZE),
    .S_AXI_awvalid(mips_cpu_ddr_AWVALID),
    .S_AXI_bready(mips_cpu_ddr_BREADY),
    .S_AXI_bresp(mips_cpu_ddr_BRESP),
    .S_AXI_bvalid(mips_cpu_ddr_BVALID),
    .S_AXI_rdata(mips_cpu_ddr_RDATA),
    .S_AXI_rlast(mips_cpu_ddr_RLAST),
    .S_AXI_rready(mips_cpu_ddr_RREADY),
    .S_AXI_rresp(mips_cpu_ddr_RRESP),
    .S_AXI_rvalid(mips_cpu_ddr_RVALID),
    .S_AXI_wdata(mips_cpu_ddr_WDATA),
    .S_AXI_wlast(mips_cpu_ddr_WLAST),
    .S_AXI_wready(mips_cpu_ddr_WREADY),
    .S_AXI_wstrb(mips_cpu_ddr_WSTRB),
    .S_AXI_wvalid(mips_cpu_ddr_WVALID),
    .s_axi_aclk(mips_cpu_clk),
    .s_axi_aresetn(~mips_cpu_reset)
    );

endmodule
