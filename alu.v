`ifdef PRJ1_FPGA_IMPL
	// the board does not have enough GPIO, so we implement a 4-bit ALU
    `define DATA_WIDTH 4
`else
    `define DATA_WIDTH 32
`endif

module alu(A, B,	ALUop,sa,Overflow,CarryOut,Zero,Result);
  input [`DATA_WIDTH - 1:0] A;
	input [`DATA_WIDTH - 1:0] B;
	input [2:0] ALUop;
	input [4:0] sa;
	output Overflow;
	output CarryOut;
	output Zero;
	output  reg [`DATA_WIDTH - 1:0] Result;
  wire [`DATA_WIDTH - 1:0] C;
  wire [`DATA_WIDTH - 1:0] D;
  wire [`DATA_WIDTH - 1:0] E;
  wire [`DATA_WIDTH :0] F;
  wire [`DATA_WIDTH :0] H;
  wire cin;
  assign cin = (ALUop[2]&ALUop[1]&~ALUop[0])|(ALUop[2]&~ALUop[1]&~ALUop[0])|(ALUop[2]&~ALUop[1]&ALUop[0]);
  assign Zero = ~(|Result);
  assign Overflow = F[`DATA_WIDTH]^F[`DATA_WIDTH-1];
  assign CarryOut = cin^H[`DATA_WIDTH];
  assign D = (A&B);
  assign  C = (~B);
  assign  E = A|B;
  assign H = (cin) ? ({1'b0,A}+{1'b0,C}+cin) : ({1'b0,A}+{1'b0,B});           //??????carryout??
  assign F = (cin) ? ({A[`DATA_WIDTH - 1],A}+{C[`DATA_WIDTH - 1],C}+cin) : ({A[`DATA_WIDTH - 1],A}+{B[`DATA_WIDTH - 1],B});   //??????overflow??  
  always @(*)
  begin
    if(ALUop == 3'b000)
      Result = D;
    else if(ALUop == 3'b001)
      Result = E;
    else if(ALUop == 3'b010)
      Result = A+B;
    else if(ALUop == 3'b110)
      Result = A+C+cin;
    else if(ALUop == 3'b011)
      Result = B<<16;
    else if(ALUop == 3'b100)
      Result = {{31{1'b0}},CarryOut};
    else if(ALUop == 3'b111)
      Result = B<<sa;
    else 
      Result = {{31{1'b0}},F[`DATA_WIDTH]};
  end
  	// TODO: insert your code
endmodule
