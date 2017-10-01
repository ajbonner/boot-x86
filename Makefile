all: clean boot.bin vga.bin

boot.bin:
	nasm -o boot.bin boot.s

vga.bin:
	nasm -o vga.bin vga.s

clean:
	rm -rf *.bin

run:
	qemu-system-i386 -hda boot.bin

run_vga: vga.bin
	qemu-system-i386 -hda vga.bin
