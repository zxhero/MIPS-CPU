#include<stdio.h>

int main(){
	unsigned char ins[4];
	FILE* fp;
	FILE *fp2;
	int i = 0;
	char *filename = "inthandler.bin";
	char *filename2 = "inthandler.vh";
	fp = fopen(filename,"rb");
	fp2 = fopen(filename2,"w");
	fseek(fp,0,SEEK_SET);
	while(fread(ins,4,1,fp) != 0){
		fprintf(fp2,"mem[%d] = 32'h%02x%02x%02x%02x;\n",i,ins[3],ins[2],ins[1],ins[0]);
		i++;
	}
	return 0;
} 
