.globl start
.section .text:

  start:
         addiu $3,$0,0x00007000 
         addiu $2,$0,0x00008000
         addiu $23,$0,0
         sw $23,($3)
         addiu $23,$0,1
         sw $23,4($3)
         sw $0,($2)
         sw $3,4($2)
         addiu $23,$0,8
	 sw $23,8($2)
	 addiu $23,$0,1
	 sw $23,16($2)
	 addiu $23,$0,3
	 sw $23,12($2)
	 lw $23,12($2)
 
         j Inthandler
         addiu $3,$0,0x00007008
        sw $0,($2)
	sw $3,4($2)
	addu $23,$0,8
	sw $23,8($2)
	addiu $23,$0,1
	sw $23,16($2)
	addiu $23,$0,1
	sw $23,12($2)
         lw $23,12($2)
         j Inthandler
         addiu $2,$0,1
         addiu $3,$0,0x00007000
        lw $4,($3)
        lw $5,4($3)
        lw $6,8($3)
        lw $7,12($3)
         
  Inthandler:
         eret


.section .data:
  var1:
.int 0x00007000
  var2:
.int 0x00008000

