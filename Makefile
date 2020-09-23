all: clean boot.bin vga.bin

boot.bin:
	nasm -f bin -o boot.bin boot.s

vga.bin:
	nasm -f bin -o vga.bin vga.s

clean:
	rm -rf *.bin

run: boot.bin
	qemu-system-i386 -drive format=raw,file=boot.bin,index=0 -machine pc

run_vga: clean vga.bin
	qemu-system-i386 -drive format=raw,file=vga.bin,index=0 -machine pc

run_bochs: clean vga.bin
	bochs -q

dis_boot: boot.bin
	objdump -m i8086 -M intel -b binary -D boot.bin

dis_vga: vga.bin
	objdump -m i8086 -M intel -b binary -D vga.bin
