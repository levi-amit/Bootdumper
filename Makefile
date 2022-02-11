default:
	mkdir -p bin
	mkdir -p img
	nasm -fbin src/x86/bootloader.asm -o bin/bootdump.bin

run:
	qemu-img create output/floppy.img 16M
	sudo qemu-system-x86_64 -hda bin/bootdump.bin -fda output/floppy.img -monitor stdio