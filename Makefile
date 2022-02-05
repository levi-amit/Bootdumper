default:
	mkdir -p bin
	mkdir -p img
	nasm -fbin src/x86/bootloader.asm -o bin/bootdump.bin
	sudo dd if=bin/bootdump.bin of=img/bootdump.img

run:
	sudo qemu-system-x86_64 -hda img/bootdump.img -monitor stdio
	@ To get the dump into a file:
	@ sudo qemu-system-x86_64 -hda img/bootdump.img -nographic > output.txt
	@ Didn't work on WSL for me, try on actual linux PC or VM