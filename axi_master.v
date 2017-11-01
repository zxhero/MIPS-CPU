////////////////////////////////////////////////////////////////////////////
* Author: Xu Zhang (zhangxu415@mails.ucas.ac.cn)
* Date: 31/08/2017
* Version: v0.0.1
////////////////////////////////////////////////////////////////////////////

`define C_M_AXI_ADDR_WIDTH 32

module axi_master #(

  ////////////////////////////////////////////////////////////////////////////
  // Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
  parameter integer  C_M_AXI_DATA_WIDTH       = 32
) (
  ////////////////////////////////////////////////////////////////////////////
  // Asserts when write transactions are complete
  output wire WCOMPLETE,
  ////////////////////////////////////////////////////////////////////////////
  // Asserts when read transactions are complete
  output wire RCOMPLETE,
  ////////////////////////////////////////////////////////////////////////////
  // System Signals
  input wire M_AXI_ACLK,
  input wire M_AXI_ARESETN,

  ////////////////////////////////////////////////////////////////////////////
  // Master Interface Write Address
  output wire [`C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_AWADDR,
  output wire [7:0] M_AXI_AWLEN,
  output wire [2:0] M_AXI_AWSIZE,
  output wire [1:0] M_AXI_AWBURST,
  output wire [3:0] M_AXI_AWCACHE,

  output wire M_AXI_AWVALID,
  input  wire M_AXI_AWREADY,

  ////////////////////////////////////////////////////////////////////////////
  // Master Interface Write Data
  output wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_WDATA,
  output wire [C_M_AXI_DATA_WIDTH/8-1:0]    M_AXI_WSTRB,
  output wire M_AXI_WLAST,
  output wire M_AXI_WVALID,
  input  wire M_AXI_WREADY,

  ////////////////////////////////////////////////////////////////////////////
  // Master Interface Write Response
  input  wire [1:0] M_AXI_BRESP,
  input  wire M_AXI_BVALID,
  output wire M_AXI_BREADY,

  ////////////////////////////////////////////////////////////////////////////
  // Master Interface Read Address
  output wire [`C_M_AXI_ADDR_WIDTH-1:0]      M_AXI_ARADDR,
  output wire [7:0] M_AXI_ARLEN,
  output wire [2:0] M_AXI_ARSIZE,
  output wire [1:0] M_AXI_ARBURST,
  output wire [3:0] M_AXI_ARCACHE,

  output wire M_AXI_ARVALID,
  input  wire M_AXI_ARREADY,

  ////////////////////////////////////////////////////////////////////////////
  // Master Interface Read Data
  input  wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_RDATA,
  input  wire [1:0] M_AXI_RRESP,                              //error detect(no use)
  input  wire M_AXI_RLAST,
  input  wire M_AXI_RVALID,
  output wire M_AXI_RREADY,
  
  ///////////////////////
  //read port from DMA engine
  input  wire [`C_M_AXI_ADDR_WIDTH-1:0]     M_AXI_DMA_raddr,
  output wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_DMA_rdata,
  output                                    ack_to_DMA,
  input                                     response_from_DMA,
  output reg  [3:0]                         read_index,
  ///////////////////////
  //write port from DMA engine
  input  wire [`C_M_AXI_ADDR_WIDTH-1:0]     M_AXI_DMA_waddr,
  input  wire [C_M_AXI_DATA_WIDTH-1:0]      M_AXI_DMA_wdata,
  input  wire                               ack_from_DMA,
  output reg                                response_to_DMA,
  input wire                                M_AXI_DMA_START,
  input wire                                M_AXI_DMA_TYPE,
  input wire  [3:0]                         C_BURST_LEN
);

////////////////////////////////////////////////////////////////////////////
// Base address of targeted slave
localparam  LP_TARGET_SLAVE_BASE_ADDR = `C_M_AXI_ADDR_WIDTH'h20000000;

////////////////////////////////////////////////////////////////////////////
// AXI4 internal temp signals
reg [`C_M_AXI_ADDR_WIDTH-1:0] axi_awaddr;
reg axi_awvalid;
reg [C_M_AXI_DATA_WIDTH-1:0] axi_wdata;
reg axi_wlast;
reg axi_wvalid;
reg axi_bready;
reg [`C_M_AXI_ADDR_WIDTH-1:0] axi_araddr;
reg axi_arvalid;
reg axi_rready;

////////////////////////////////////////////////////////////////////////////
// write beat count in a burst
reg [3:0] write_index;
////////////////////////////////////////////////////////////////////////////
// read beat count in a burst

reg start_single_burst_write;
reg start_single_burst_read;
(* mark_debug = "true" *)   reg writes_done;
(* mark_debug = "true" *)   reg reads_done;
reg burst_write_active;
reg burst_read_active;

wire wnext;
wire rnext;

////////////////////////////////////////////////////////////////////////////
// Example State machine to initialize counter, initialize write transactions,
// initialize read transactions and comparison of read data with the
// written data words.
localparam  [1:0] INIT_WAIT = 2'b00, // This state initializes the counter, ones
                                        // the counter reaches LP_START_COUNT count,
                                        // the state machine changes state to INIT_WRITE
                  INIT_WRITE  = 2'b01,  // This state initializes write transaction,
                                        // once writes are done, the state machine
                                        // changes state to INIT_READ
                  INIT_READ  = 2'b10;   // This state initializes read transaction
                                        // once reads are done, the state machine
                                        // changes state to INIT_COMPARE
reg [1:0] mst_exec_state;

////////////////////////////////////////////////////////////////////////////
//I/O Connections
////////////////////////////////////////////////////////////////////////////
//Write Address (AW)

////////////////////////////////////////////////////////////////////////////
// The AXI address is a concatenation of the target base address + active offset range
assign M_AXI_AWADDR = LP_TARGET_SLAVE_BASE_ADDR | axi_awaddr;

////////////////////////////////////////////////////////////////////////////
//Burst LENgth is number of transaction beats, minus 1
assign M_AXI_AWLEN = C_BURST_LEN - 1;

////////////////////////////////////////////////////////////////////////////
// Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
assign M_AXI_AWSIZE = 'd2;

////////////////////////////////////////////////////////////////////////////
// INCR burst type is usually used, except for keyhole bursts
assign M_AXI_AWBURST = 2'b01;
assign M_AXI_AWCACHE = 4'b0000;
assign M_AXI_AWVALID = axi_awvalid;

////////////////////////////////////////////////////////////////////////////
//Write Data(W)
assign M_AXI_WDATA = axi_wdata;

////////////////////////////////////////////////////////////////////////////
//All bursts are complete and aligned in this example
assign M_AXI_WSTRB = {(C_M_AXI_DATA_WIDTH/8){1'b1}};
assign M_AXI_WLAST = axi_wlast;
assign M_AXI_WVALID = axi_wvalid;

////////////////////////////////////////////////////////////////////////////
//Write Response (B)
assign M_AXI_BREADY = axi_bready;

////////////////////////////////////////////////////////////////////////////
//Read Address (AR)
assign M_AXI_ARADDR = LP_TARGET_SLAVE_BASE_ADDR | axi_araddr;

////////////////////////////////////////////////////////////////////////////
//Burst LENgth is number of transaction beats, minus 1
assign M_AXI_ARLEN = C_BURST_LEN - 1;

////////////////////////////////////////////////////////////////////////////
// Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
assign M_AXI_ARSIZE = 'd2;

////////////////////////////////////////////////////////////////////////////
// INCR burst type is usually used, except for keyhole bursts
assign M_AXI_ARBURST = 2'b01;
assign M_AXI_ARCACHE = 4'b0000;
assign M_AXI_ARVALID = axi_arvalid;

////////////////////////////////////////////////////////////////////////////
//Read and Read Response (R)
assign M_AXI_RREADY = axi_rready;

////////////////////////////////////////////////////////////////////////////
//Write Address Channel
//
// The purpose of the write address channel is to request the address and
// command information for the entire transaction.  It is a single beat
// of data for each burst.
//
// The AXI4 Write address channel in this example will continue to initiate
// write commands as fast as it is allowed by the slave/interconnect.
  always @(posedge M_AXI_ACLK)
  begin

    if (M_AXI_ARESETN == 0 )
      begin
        axi_awvalid <= 1'b0;
      end
	else if(~axi_awvalid && start_single_burst_write)
	    axi_awvalid <= 1'b1;	
    // If previously not valid , start next transaction
    /*else if (~axi_awvalid && burst_write_active)
      begin
        axi_awvalid <= 1'b1;
      end*/
    /* Once asserted, VALIDs cannot be deasserted, so axi_awvalid
    must wait until transaction is accepted */
    else if (M_AXI_AWREADY && axi_awvalid)
      begin
        axi_awvalid <= 1'b0;
      end
    else
      axi_awvalid <= axi_awvalid;
    end

////////////////////////////////////////////////////////////////////////////
// Next address after AWREADY indicates previous address acceptance
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      begin
        axi_awaddr <= {`C_M_AXI_ADDR_WIDTH{1'b0}};
      end
	else if(~axi_awvalid && start_single_burst_write)
	    axi_awaddr <= M_AXI_DMA_waddr;
    else if (~axi_awvalid && burst_write_active)
      begin
        axi_awaddr <= axi_awaddr + 4;
      end
    else
      axi_awaddr <= axi_awaddr;
    end

////////////////////////////////////////////////////////////////////////////
//Write Data Channel
//
// The write data will continually try to push write data across the interface.
//
// The amount of data accepted will depend on the AXI slave and the AXI
// Interconnect settings, such as if there are FIFOs enabled in interconnect.
//
// Note that there is no explicit timing relationship to the write address channel.
// The write channel has its own throttling flag, separate from the AW channel.
//
// Synchronization between the channels must be determined by the user.
//
// The simpliest but lowest performance would be to only issue one address write
// and write data burst at a time.
//
// In this example they are kept in sync by using the same address increment
// and burst sizes. Then the AW and W channels have their transactions measured
// with threshold counters as part of the user logic, to make sure neither
// channel gets too far ahead of each other.

////////////////////////////////////////////////////////////////////////////
// Forward movement occurs when the write channel is valid and ready
assign wnext = M_AXI_WREADY & axi_wvalid;

////////////////////////////////////////////////////////////////////////////
// WVALID logic, similar to the axi_awvalid always block above
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0 )
      begin
        axi_wvalid <= 1'b0;
		response_to_DMA <= 1'b0;
      end
    // If previously not valid, start next transaction
    else if (~axi_wvalid && ack_from_DMA && ~axi_wlast)
      begin
        axi_wvalid <= 1'b1;
		response_to_DMA <= 1'b1;
      end
	else if (~axi_wvalid && ack_from_DMA && axi_wlast)
	  begin
	    axi_wvalid <= 1'b1;
		response_to_DMA <= 1'b0;
	  end
	else if (axi_wvalid && M_AXI_WREADY)
	  begin  
	    axi_wvalid <= 1'b0;
		response_to_DMA <= 1'b0;
	  end
    ////////////////////////////////////////////////////////////////////////////
    // If WREADY and too many writes, throttle WVALID
    // Once asserted, VALIDs cannot be deasserted, so WVALID
    // must wait until burst is complete with WLAST
    else if (wnext && axi_wlast)
    begin
      axi_wvalid <= 1'b0;
	  response_to_DMA <= 1'b0;
	end
    else
    begin
      axi_wvalid <= axi_wvalid;
	  response_to_DMA <= response_to_DMA;
	end
  end


////////////////////////////////////////////////////////////////////////////
//WLAST generation on the MSB of a counter underflow
// WVALID logic, similar to the axi_awvalid always block above
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0 )
      begin
        axi_wlast <= 1'b0;
      end
    ////////////////////////////////////////////////////////////////////////////
    // axi_wlast is asserted when the write index
    // count reaches the penultimate count to synchronize
    // with the last write data when write_index is b1111
    // else if (&(write_index[LP_BEAT_NUM-1:1])&& ~write_index[0] && wnext)
    else if (((write_index == C_BURST_LEN-2 && C_BURST_LEN >= 2) && wnext) || (C_BURST_LEN == 1 ))
      begin
        axi_wlast <= 1'b1;
      end
    // Deassrt axi_wlast when the last write data has been
    // accepted by the slave with a valid response
    else if (wnext)
      axi_wlast <= 1'b0;
    else if (axi_wlast && C_BURST_LEN == 1)
      axi_wlast <= 1'b0;
    else
      axi_wlast <= axi_wlast;
  end

////////////////////////////////////////////////////////////////////////////
// Burst length counter. Uses extra counter register bit to indicate terminal
// count to reduce decode logic
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0 || M_AXI_DMA_START)
      begin
        write_index <= 0;
      end
    else if (wnext && (write_index != C_BURST_LEN-1))
      begin
        write_index <= write_index + 1;
      end
    else
      write_index <= write_index;
  end

////////////////////////////////////////////////////////////////////////////
// Write Data Generator
// Data pattern is only a simple incrementing count from 0 for each burst
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      axi_wdata <= 'd0;
    else if (~axi_wvalid && ack_from_DMA)
      axi_wdata <= M_AXI_DMA_wdata;
    else
      axi_wdata <= axi_wdata;
    end

////////////////////////////////////////////////////////////////////////////
//Write Response (B) Channel
//
// The write response channel provides feedback that the write has committed
// to memory. BREADY will occur when all of the data and the write address
// has arrived and been accepted by the slave.
//
// The write issuance (number of outstanding write addresses) is started by
// the Address Write transfer, and is completed by a BREADY/BRESP.
//
// While negating BREADY will eventually throttle the AWREADY signal,
// it is best not to throttle the whole data channel this way.
//
// The BRESP bit [1] is used indicate any errors from the interconnect or
// slave for the entire write burst. This example will capture the error
// into the ERROR output.

  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0 )
      begin
        axi_bready <= 1'b0;
      end
    // accept/acknowledge bresp with axi_bready by the master
    // when M_AXI_BVALID is asserted by slave
    else if (M_AXI_BVALID && ~axi_bready)
      begin
        axi_bready <= 1'b1;
      end
    // deassert after one clock cycle
    else if (axi_bready)
      begin
        axi_bready <= 1'b0;
      end
    // retain the previous value
    else
      axi_bready <= axi_bready;
  end

////////////////////////////////////////////////////////////////////////////
//Read Address Channel
//
// The Read Address Channel (AW) provides a similar function to the
// Write Address channel- to provide the tranfer qualifiers for the
// burst.
//
// In this example, the read address increments in the same
// manner as the write address channel.

  always @(posedge M_AXI_ACLK)
  begin

    if (M_AXI_ARESETN == 0 )
      begin
        axi_arvalid <= 1'b0;
      end
    // If previously not valid , start next transaction
    else if (~axi_arvalid && start_single_burst_read)
      begin
        axi_arvalid <= 1'b1;
      end
    else if (M_AXI_ARREADY && axi_arvalid)
      begin
        axi_arvalid <= 1'b0;
      end
	else if(~axi_arvalid &&burst_read_active)
	    axi_arvalid <= 1'b0;
    else
      axi_arvalid <= axi_arvalid;
  end


////////////////////////////////////////////////////////////////////////////
// Next address after ARREADY indicates previous address acceptance
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      begin
        axi_araddr <= {`C_M_AXI_ADDR_WIDTH{1'b0}};
      end
	else if(~axi_arvalid && start_single_burst_read)
	    axi_araddr <= M_AXI_DMA_raddr;
    else if (~axi_arvalid &&burst_read_active)
      begin
        axi_araddr <= axi_araddr + 4;
      end
    else
      axi_araddr <= axi_araddr;
  end


////////////////////////////////////////////////////////////////////////////
//Read Data (and Response) Channel

// Forward movement occurs when the channel is valid and ready
assign rnext = M_AXI_RVALID & axi_rready;
assign M_AXI_DMA_rdata = M_AXI_RDATA;

////////////////////////////////////////////////////////////////////////////
// Burst length counter. Uses extra counter register bit to indicate terminal
// count to reduce decode logic
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0 || M_AXI_DMA_START)
      begin
        read_index <= 0;
      end
    else if (rnext && (read_index != C_BURST_LEN-1))
      begin
        read_index <= read_index + 1;
      end
    else
      read_index <= read_index;
  end


////////////////////////////////////////////////////////////////////////////
// The Read Data channel returns the results of the read request
//
// In this example the data checker is always able to accept
// more data, so no need to throttle the RREADY signal

  assign ack_to_DMA = M_AXI_RVALID ;
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0 )
      begin
        axi_rready <= 1'b0;
      end
    // accept/acknowledge rdata/rresp with axi_rready by the master
    // when M_AXI_RVALID is asserted by slave
    else if (M_AXI_RVALID && ~axi_rready)
      begin
        axi_rready <= 1'b1;
      end
    // deassert after one clock cycle
    else if (axi_rready)
      begin
        axi_rready <= 1'b0;
      end
	else axi_rready <= axi_rready;
    // retain the previous value
  end

////////////////////////////////////////////////////////////////////////////
//Example design throttling

// For maximum port throughput, this user example code will try to allow
// each channel to run as independently and as quickly as possible.
//
// However, there are times when the flow of data needs to be throtted by
// the user application. This example application requires that data is
// not read before it is written and that the write channels do not
// advance beyond an arbitrary threshold (say to prevent an
// overrun of the current read address by the write address).
//
// From AXI4 Specification, 13.13.1: "If a master requires ordering between
// read and write transactions, it must ensure that a response is received
// for the previous transaction before issuing the next transaction."
//
// This example accomplishes this user application throttling through:
// -Reads wait for writes to fully complete
// -Address writes wait when not read + issued transaction counts pass
// a parameterized threshold
// -Writes wait when a not read + active data burst count pass
// a parameterized threshold

////////////////////////////////////////////////////////////////////////////
//implement master command interface state machine

  always @ ( posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 1'b0 )
      begin
        // reset condition
        // All the signals are assigned default values under reset condition
        mst_exec_state      <= INIT_WAIT;
        start_single_burst_write <= 1'b0;
        start_single_burst_read  <= 1'b0;
      end
    else
      begin

        // state transition
        case (mst_exec_state)

          INIT_WAIT:
            // This state is responsible to wait for user defined LP_START_COUNT
            // number of clock cycles.
            if (M_AXI_DMA_START &&  M_AXI_DMA_TYPE)
              begin
                mst_exec_state  <= INIT_WRITE;
              end
			else if(M_AXI_DMA_START &&  ~M_AXI_DMA_TYPE)
			  begin
			    mst_exec_state  <= INIT_READ;
			  end
            else
              begin
                mst_exec_state  <= INIT_WAIT;
              end

          INIT_WRITE:
            // This state is responsible to issue start_single_write pulse to
            // initiate a write transaction. Write transactions will be
            // issued until burst_write_active signal is asserted.
            // write controller
            if (writes_done)
              begin
                mst_exec_state <= INIT_WAIT;//
              end
            else
              begin
                mst_exec_state  <= INIT_WRITE;

                if (~axi_awvalid && ~start_single_burst_write && ~burst_write_active && M_AXI_DMA_START)
                  begin
                    start_single_burst_write <= 1'b1;
                  end
                else
                  begin
                    start_single_burst_write <= 1'b0; //Negate to generate a pulse
                  end
              end

          INIT_READ:
            // This state is responsible to issue start_single_read pulse to
            // initiate a read transaction. Read transactions will be
            // issued until burst_read_active signal is asserted.
            // read controller
            if (reads_done)
              begin
                mst_exec_state <= INIT_WAIT;
              end
            else
              begin
                mst_exec_state  <= INIT_READ;

                if (~axi_arvalid && ~burst_read_active && ~start_single_burst_read && M_AXI_DMA_START)
                  begin
                    start_single_burst_read <= 1'b1;
                  end
               else
                 begin
                   start_single_burst_read <= 1'b0; //Negate to generate a pulse
                 end
              end
        endcase
      end
  end //MASTER_EXECUTION_PROC


////////////////////////////////////////////////////////////////////////////
// burst_write_active signal is asserted when there is a burst write transaction
// is initiated by the assertion of start_single_burst_write. burst_write_active
// signal remains asserted until the burst write is accepted by the slave
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      burst_write_active <= 1'b0;

    //The burst_write_active is asserted when a write burst transaction is initiated
    else if (start_single_burst_write)
      burst_write_active <= 1'b1;
    else if (M_AXI_BVALID && axi_bready)
      burst_write_active <= 0;
	else burst_write_active <= burst_write_active;
  end

////////////////////////////////////////////////////////////////////////////
// Check for last write completion.
//
// This logic is to qualify the last write count with the final write
// response. This demonstrates how to confirm that a write has been
// committed.

  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      writes_done <= 1'b0;

    //The writes_done should be associated with a bready response
    else if (M_AXI_BVALID&& axi_bready && (write_index == C_BURST_LEN-1))
      writes_done <= 1'b1;
    else if(writes_done)
      writes_done <= 1'b0;
    else
      writes_done <= writes_done;
    end

////////////////////////////////////////////////////////////////////////////
// burst_read_active signal is asserted when there is a burst write transaction
// is initiated by the assertion of start_single_burst_write. start_single_burst_read
// signal remains asserted until the burst read is accepted by the master
  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      burst_read_active <= 1'b0;

    //The burst_write_active is asserted when a write burst transaction is initiated
    else if (start_single_burst_read)
      burst_read_active <= 1'b1;
    else if (M_AXI_RVALID && axi_rready && M_AXI_RLAST)
      burst_read_active <= 0;
	else burst_read_active <= burst_read_active;
    end

////////////////////////////////////////////////////////////////////////////
// Check for last read completion.
//
// This logic is to qualify the last read count with the final read
// response. This demonstrates how to confirm that a read has been
// committed.

  always @(posedge M_AXI_ACLK)
  begin
    if (M_AXI_ARESETN == 0)
      reads_done <= 1'b0;

    //The reads_done should be associated with a rready response
    else if (M_AXI_RVALID && axi_rready && (read_index == C_BURST_LEN-1))
      reads_done <= 1'b1;
    else if(reads_done)
      reads_done <= 1'b0;
    else
      reads_done <= reads_done;
    end


////////////////////////////////////////////////////////////////////////////
//Example design I/O
assign WCOMPLETE  = writes_done;
assign RCOMPLETE  = reads_done;

endmodule
