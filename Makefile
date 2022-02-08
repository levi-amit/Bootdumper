default:
	mkdir -p bin
	mkdir -p img
	nasm -fbin src/x86/bootloader.asm -o bin/bootdump.bin

run:
	sudo qemu-system-x86_64 -hda bin/bootdump.bin -fda output/floppy.img -monitor stdio