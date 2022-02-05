default:
	mkdir -p bin
	mkdir -p img
	nasm -fbin src/x86/bootloader.asm -o bin/bootdump.bin

run:
	sudo qemu-system-x86_64 -hda bin/bootdump.bin -monitor stdio
	# To get the dump into a file:
	# sudo qemu-system-x86_64 -hda img/bootdump.img -nographic > output.txt
	# Didn't work on WSL for me, try on actual linux PC or VM