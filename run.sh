mipsel-buildroot-linux-gnu-gcc -c $1.c -o $1.o
mipsel-buildroot-linux-gnu-gcc -c start.S -o start.o
mipsel-buildroot-linux-gnu-ld -Tlinked.lds -EL start.o $1.o -o $1
mipsel-buildroot-linux-gnu-objcopy -O binary -S $1 $1.bin
mipsel-buildroot-linux-gnu-objdump -D $1 > $1.txt
./handlebin $1.bin $1.vh

