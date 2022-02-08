# Bootdumper
Ever wondered what that sneaky BIOS smuggles into your memory when you aren't looking?
Here's a cool boot tool to sate your paranoia!
## Building:
```
make
```
## Running:
Create an output image whatever size you like
```
qemu-img create output/floppy.img your_size_here
```
Start the virtual machine
```
make run
```
