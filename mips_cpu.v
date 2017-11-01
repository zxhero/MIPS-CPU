module mips_cpu(
	input  rst,
	input  clk,

	output [31:0] PC,
	input  [31:0] Instruction,

	output [31:0] Address,
	output MemWrite,
	output [31:0] Write_data,

	input  [31:0] Read_data,
	output MemRead,
	
	output reg [31:0] cycle_cnt,		//counter of total cycles
    output reg [31:0] inst_cnt,            //counter of total instructions
    output reg [31:0] br_cnt,            //counter of branch/jump instructions
    output reg [31:0] ld_cnt,            //counter of load instructions
    output reg [31:0] st_cnt,            //counter of store instructions
    output reg [31:0] user1_cnt,        //user defined counter (reserved)
    output reg [31:0] user2_cnt,
    output reg [31:0] user3_cnt,
    output reg        ENTR,
    input             ack_from_mem,
    input             INTR,
);
  wire br;
  wire interrupt_enable;
  wire interrupt_cancle;
  reg [31:0] EPC;
  reg [31:0] instruction_reg;
  reg [31:0] mem_to_data;
  reg [31:0] ALUout;
  wire [17:0] option;
  wire [4:0] reg_waddr;
  wire [31:0] reg_wdata;
  wire [31:0] reg_rdataA;
  wire [31:0] reg_rdataB;
  reg [31:0] A;
  reg [31:0] B;
  wire [31:0] alu_A;
  wire [31:0] alu_B;
  wire [31:0] alu_result;
  wire [31:0] jump_Pc;
  wire [31:0] ad_IR;
  wire [2:0] ALUop;
  wire Zero;
  reg [31:0] PC_reg;
  wire PCw;
  wire btype;
  reg [4:0] reg_waddr_reg;
  assign reg_waddr = reg_waddr_reg;
  assign ad_IR = {{16{instruction_reg[15]}},instruction_reg[15:0]};
  assign reg_wdata = (option[5]) ? mem_to_data : ALUout;
  assign jump_Pc = {PC_reg[31:28],instruction_reg[25:0],2'b00};
  assign PCw = ((Zero^btype)&option[0])|option[1];
  assign Address = ALUout;
  assign MemWrite = option[4];
  assign MemRead = option[3];
  assign Write_data = B;
  assign alu_A = (option[14]) ? A:PC_reg;
  assign alu_B = (option[12])?((option[13])?(ad_IR<<2):(32'd4)):((option[13])?ad_IR:B);
  assign PC = PC_reg;
  alu_con alu_control(.G(instruction_reg[5:0]),.H(option[11:9]),.ALUop(ALUop));
  cpu_control op_control(.F(instruction_reg[31:26]),.G(instruction_reg[5:0]),.op(option),.btype(btype),.clk(clk),.rst(rst),.br(br),.ack_from_mem(ack_from_mem),.interrupt_enable(interrupt_enable),.interrupt_cancle(interrupt_cancle),.INTR(INTR),.ENTR(ENTR));
  reg_file reg1(.clk(clk),.rst(rst),.waddr(reg_waddr),.raddr1(instruction_reg[25:21]),.raddr2(instruction_reg[20:16]),.wdata(reg_wdata),.rdata1(reg_rdataA),.rdata2(reg_rdataB),.wen(option[15]));
  alu alu1(.A(alu_A),.B(alu_B),.ALUop(ALUop),.sa(instruction_reg[10:6]),.Result(alu_result),.Zero(Zero));
  always @*
  begin
    case(option[17:16])
    2'b00: reg_waddr_reg = instruction_reg[20:16];
    2'b01: reg_waddr_reg = instruction_reg[15:11];
    default: reg_waddr_reg = 5'd31;
    endcase
   end
   
  always @(posedge clk)
  begin
    if(rst) begin
    A <= 32'd0;
    B <= 32'd0;
    mem_to_data <= 32'd0;
    ALUout <= 32'd0;
    end
    else if(MemWrite|MemRead)
    begin
       ALUout <= ALUout;
       B <= B;
       A <= A;
       mem_to_data <= Read_data;
    end
    else begin
    A <= reg_rdataA;
    B <= reg_rdataB;
    mem_to_data <= mem_to_data;
    ALUout <= alu_result;
    end
  end
  
  always @(posedge clk)//or posedge rst
  begin
     if(rst)
   PC_reg <= 32'd0;
   else if(PCw)
    case(option[8:7])
    2'b00:  PC_reg <= alu_result;
    2'b01:  PC_reg <= ALUout;
    2'b11:  PC_reg <= EPC;
    default: PC_reg <= jump_Pc; 
    endcase
  end
  
  always @(posedge clk) begin
    if(rst) begin
    inst_cnt <= 32'd0;
    instruction_reg <= 32'd0;
    end
    else if(option[6]) begin
    instruction_reg <= Instruction;
    inst_cnt <= inst_cnt + 32'd1;
    end
    else
    begin
       instruction_reg <= instruction_reg;
       inst_cnt <= inst_cnt;
    end
  end
  
  always @(posedge clk) begin
   if(rst) begin
   cycle_cnt <= 32'd0;
   user1_cnt <= 32'd0;
   user2_cnt <= 32'd0;
   user3_cnt <= 32'd0;
   end
   else begin
   cycle_cnt <= cycle_cnt + 32'd1;
   user1_cnt <= user1_cnt + 32'd1;
   user2_cnt <= user2_cnt + 32'd1;
   user3_cnt <= user3_cnt + 32'd1;
   end
  end
  
  always @(posedge clk) begin
   if(rst) br_cnt <= 32'd0;
   else if(br) br_cnt <= br_cnt + 32'd1;
  end
  
  always @(posedge clk) begin
     if(rst) ld_cnt <= 32'd0;
     else if(MemRead) ld_cnt <= ld_cnt + 32'd1;
   end
   
   always @(posedge clk) begin
      if(rst) st_cnt <= 32'd0;
      else if(MemWrite) st_cnt <= st_cnt + 32'd1;
   end
   
   always @(posedge clk)
      if(rst) 
      begin
          EPC <= 'd0;
          ENTR <= 1'b0;
      end
      else if(interrupt_enable)
      begin
          EPC <= PC_reg + 32'd4;
          ENTR <= 1'b1;
      end
      else if(interrupt_cancle)
      begin
          EPC <= EPC;
          ENTR <= 1'b0;
      end
      else 
      begin
          EPC <= EPC;
          ENTR <= ENTR;
      end
	//TODO: Insert your design of single cycle MIPS CPU here
endmodule

module cpu_control(
  input [5:0] F,
  input [5:0] G,
  input clk,
  input rst,
  output btype,
  output reg br,
  output [17:0] op,
  input ack_from_mem,
  output            interrupt_enable,
  output            interrupt_cancle,
  input             INTR,
  input             ENTR,
);
    reg [4:0] CMAR;
    reg [23:0] micro_reg [31:0];
    wire sw;
    wire lw;
    wire [23:0] read;
    wire [4:0] generate_addr;
    wire addiu;
    wire bne;
    wire beq;
    wire jmp;
    wire jal;
    wire jr;
    wire lui;
    wire slti;
    wire sltiu;
    wire eret;
    wire bal;
    assign btype = bne;
    assign eret =  ~F[5]&F[4]&~F[3]&~F[2]&~F[1]&~F[0];
    assign slti = ~F[5]&~F[4]&F[3]&~F[2]&F[1]&~F[0];
    assign sltiu = ~F[5]&~F[4]&F[3]&~F[2]&F[1]&F[0];
    assign lui = ~F[5]&~F[4]&F[3]&F[2]&F[1]&F[0];
    assign jr =  rtype&~G[5]&~G[4]&G[3]&~G[2]&~G[1]&~G[0];
    assign jal = ~F[5]&~F[4]&~F[3]&~F[2]&F[1]&F[0];
    assign jmp = ~F[5]&~F[4]&~F[3]&~F[2]&F[1]&~F[0];
    assign beq = ~F[5]&~F[4]&~F[3]&F[2]&~F[1]&~F[0];
    assign rtype = ~F[5]&~F[4]&~F[3]&~F[2]&~F[1]&~F[0];
    assign addiu = ~F[5]&~F[4]&F[3]&~F[2]&~F[1]&F[0];
    assign lw = F[5]&~F[4]&~F[3]&~F[2]&F[1]&F[0];
    assign sw = F[5]&~F[4]&F[3]&~F[2]&F[1]&F[0];
    assign bne = ~F[5]&~F[4]&~F[3]&F[2]&~F[1]&F[0];
    assign bal = ~F[5]&~F[4]&~F[3]&~F[2]&~F[1]&F[0];
    assign generate_addr[4] = (rtype^jr)|bne|beq|eret|bal;
    assign generate_addr[3] = jr|jmp|jal|sltiu|slti|lui;
    assign generate_addr[2] = jr|jmp|jal|addiu|sw|bal;
    assign generate_addr[1] = jr|jmp|sltiu|slti|addiu|lw|bne|beq|eret;
    assign generate_addr[0] = jmp|sltiu|lui|addiu|sw|eret;
  assign read =  micro_reg[CMAR];
  assign op = {read[23:8],read[7],read[6]};
  assign interrupt_enable = ~ENTR & ~read[5] & read[4] & ~(|read[3:0]) & INTR;
  assign interrupt_cancle = eret & ENTR;
  initial  begin
  micro_reg[0] <= 24'b000001010001000010000000;
  micro_reg[1] <= 24'b000011010000000000100000;
  micro_reg[2] <= 24'b000110010000000000000000;
  micro_reg[3] <= 24'b000000000000001000000000;
  micro_reg[4] <= 24'b001000000000100000010000;
  micro_reg[5] <= 24'b000110010000000000000000;
  micro_reg[6] <= 24'b000000000000010000010000;
  micro_reg[7] <= 24'b000110010000000000000000;
  micro_reg[8] <= 24'b001000000000000000010000;
  micro_reg[9] <= 24'b000010011000000000011000;
  micro_reg[10] <= 24'b000110101000000000011000;
  micro_reg[11] <= 24'b000110100000000000011000;
  micro_reg[12] <= 24'b000001010100000010000000;
  micro_reg[13] <= 24'b101000000000000000010000;
  micro_reg[14] <= 24'b000100000000000000000000;
  micro_reg[15] <= 24'b000001010100000010010000;
  micro_reg[16] <= 24'b000100000000000000000000;
  micro_reg[17] <= 24'b011000000000000000010000;
  micro_reg[18] <= 24'b000100110010000001010000;
  micro_reg[19] <= 24'b000000000110000010010000;
  micro_reg[20] <= 24'b000001010000000000000000;
  micro_reg[21] <= 24'b101011010000000010010000;
  end
  always @(posedge clk) begin
  if(rst)   CMAR <= 5'd0;
  else if(((read[9]| read[10]) && ~ack_from_mem )
  begin
      CMAR <= CMAR;
  end
  else begin
  case(read[5:4])
  2'b00 : CMAR <= CMAR + 5'd1;
  2'b01 : CMAR <= {1'b0,read[3:0]};
  default: CMAR <= generate_addr;
  endcase
  end 
  end
  always @(posedge clk) begin
  if(rst) br <= 1'b0;
  else begin case(CMAR)
  5'd18,5'd12,5'd15: br <= 1'b1;
  default : br <= 1'b0;
  endcase
  end
  end
endmodule

module alu_con(input [5:0] G,
       input [2:0] H,
       output reg [2:0] ALUop);
       wire slt;
       wire jr;
       wire all_nop;
       wire addu;
       wire or_move;
       assign slt = G[5]&~G[4]&G[3]&~G[2]&G[1]&~G[0]&~H[2]&~H[1]&~H[0];
       assign jr = ~G[5]&~G[4]&G[3]&~G[2]&~G[1]&~G[0]&~H[2]&~H[1]&~H[0];
       assign all_nop = ~G[5]&~G[4]&~G[3]&~G[2]&~G[1]&~G[0]&~H[2]&~H[1]&~H[0];
       assign addu = G[5]&~G[4]&~G[3]&~G[2]&~G[1]&G[0]&~H[2]&~H[1]&~H[0];
       assign or_move = G[5]&~G[4]&~G[3]&G[2]&~G[1]&G[0]&~H[2]&~H[1]&~H[0];
       always @*
       begin
       case({slt,jr,all_nop,addu,or_move})
       5'b10000: ALUop <= 3'b101;
       5'b01000: ALUop <= 3'b010;
       5'b00100: ALUop <= 3'b111;
       5'b00010: ALUop <= 3'b010;
       5'b00001: ALUop <= 3'b001;
       default: ALUop <= H;
       endcase
       end
endmodule 
