; All function returns are according to cdecl convention,
; meaning AX, CX, DX are caller-saved and the rest are up to the callee to save.

bits 16
org 0x7C00

xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax

; Stack initialization
mov bp, 0x9C00
mov sp, bp

_start:
    mov si, msg_welcome ; Print welcome message
    call puts

    ; Print address of _start
    mov si, msg_my_start_address_is
    call puts
    mov ax, cs
    call print_ax
    mov si, char_colon
    call puts
    mov ax, _start
    call print_ax
    mov si, newline
    call puts

    ; Writing to floppy test
    mov ax, ds
    mov es, ax
    mov bx, 0
    call write_to_hd

    call print_ax
    mov si, newline
    call puts


    ; Going through the IVT on the resulting dump of the first segment,
    ; We'll dump the segments which contain cool BIOS interrupt code

    mov si, msg_done
    call puts

    jmp $                 ; wait


; Block Device Interaction
write_to_hd:
    ; Write data to Floppy disk 1
    ; https://en.wikipedia.org/wiki/INT_13H
    ; ARGS:
    ;   ES:BX: Buffer address pointer
    push es
    push bx
    push dx

    mov ah, 0x03        ; Select BIOS function - Write sectors to drive
    mov al, 0x80        ; Sectors to write count - seems the maximum ix 0x80
    mov ch, 0x00        ; Track
    mov cl, 0x01        ; Sector
    mov dh, 0x00        ; Head
    mov dl, 0x00        ; Drive - 1st floppy disk

    int 0x13            ; BIOS interrupt - Block device action

    pop dx
    pop bx
    pop es
    ret


; Print functions
print_ax:
    ; Prints the contents of AX in hex form
    push ax
    shr ax, 8
    call print_byte
    pop ax
    call print_byte
    ret


print_byte:
    ; Print 2 characters which are the hex representation of AL.
    ; ARGS:
    ;   AL: A byte to print the hex representation of.
    mov dl, al                      ; Copy AL to DL as we will overwrite AL and we will need to reaccess the given byte
    mov ah, 0x0E                    ; Choose BIOS interrupt function - Teletype output the char at AL

    ; Print 4 most significant bits character
    shr al, 4                       ; Set 4 LSB of AL to it's 4 MSB, to print those 4 MSB as a hex character
    call fourbit_int_to_ascii          ; Convert 4 LSB of AL to ASCII character of the corresponding hex digit
    int 0x10                        ; BIOS interrupt

    ; Print 4 least significant bits character
    mov al, dl                      ; Restore saved AL from function start
    call fourbit_int_to_ascii          ; Convert 4 LSB of AL to ASCII character of the corresponding hex digit
    int 0x10                        ; BIOS interrupt

    ret


fourbit_int_to_ascii:
    ; Set AL to be the ASCII char which is the hex representation of the 4 least significant bits of AL.
    ; ARGS:
    ;   AL: 4 least significant bits represent number from 0x0 to 0xF, 
    ;       to be converted to the ASCII character correspondant to the number: 0x1 -> 1, 0xA -> A and so on.
    and al, 0b00001111      ; Set 4 MSB of AL to zero
    cmp al, 9               ; There is a distance of 7 characters in the ASCII table
                            ; between the end of number characters and the beginning of upper-case letters.
    jbe .add_ascii_0        ; If AL < 9 don't add to it the requirement of A-F characters.
    add al, 7
    .add_ascii_0:
        add al, 0x30        ; Add the value of ASCII '0' to receive the final value of the ASCII hex representation of the 4 LS bits of AL
    ret



puts:
    ; Print a null-terminated string.
    ; ARGS:
    ;   SI: address of null-terminated string in DS segment
    push si
    mov ah, 0x0E            ; Select BIOS interrupt function - Teletype output the char at AL
    .print_loop:
        lodsb               ; mov al, [ds:si] ; si += 1
        or al, al           ; Set zero flag if current character is a null byte
        jz .j_ret           ; Return if current char is null
        int 0x10            ; BIOS interrupt
        jmp .print_loop     ; Re-call puts and print the next character
    .j_ret: 
        pop si
        ret


putsn:
    ; Print CX characters starting at address DS:SI.
    ; ARGS:
    ;   SI: Starting address of string in DS.
    ;   CX: Amount of characters to print.
    push si
    mov ah, 0x0E            ; Select BIOS interrupt function - Teletype output the char at AL
    .print_loop:
        lodsb               ; mov al, [ds:si] ; si += 1
        int 0x10            ; BIOS interrupt
        loop .print_loop    ; cx -= 1 ; if cx > 0: jmp .print_loop
    pop si
    ret

putsn_hex:
    ; Print the hex representation of CX characters, starting at address DS:SI, each byte seperated by a single space.
    ; ARGS:
    ;   SI: Starting address of string in DS.
    ;   CX: Amount of characters to print hex representation of.
    push si
    mov ah, 0x0E            ; Select BIOS interrupt function - Teletype output the char at AL
    .print_loop:
        lodsb               ; mov al, [ds:si] ; si += 1
        call print_byte     ; Print hex representation of AL
        cmp cx, 1           ; Print a space only if the current character is not the last in the string
        jbe .print_loop
        mov al, ' '
        int 0x10            ; BIOS Interrupt
        loop .print_loop
    pop si
    ret

hexdump_segment:
    ; Hex dump a memory segment at a given address.
    ; ARGS:
    ;   AX: address of real-mode segment.
    push ds
    mov ds, ax      ; Set DS to current segment to print
    mov cx, 0xFFFF  ; Set amount of bytes to dump - entire segment
    xor si, si      ; Set starting address in segment to print - 0
    call putsn_hex  ; Hex dump AX:0000 - AX:ffff
    pop ds
    ret


; Message Strings
msg_welcome: db "Welcome to the BootDumper!", 0x0D, 0x0A, 0
msg_dump_start: db "Starting dump...", 0x0D, 0x0A, 0
msg_done: db "Finished Dumping! Enjoy my product.", 0x0D, 0x0A, 0
newline: db 0x0D, 0x0A, 0
msg_my_start_address_is: db "My _start address is: ", 0
msg_current_segment: db "Dumping segment: 0x", 0
char_colon: db ":", 0


times 510-($-$$) db 0x69
dw 0xAA55               ; Magic bytes for the image to be considered a valid MBR