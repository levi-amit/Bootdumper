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

    ; Hex dump entire memory
    xor ax, ax      ; Start from segment 0
    mov bx, 1       ; Dump 1 segment
    call print_segments

    mov si, msg_done
    call puts

    jmp $                 ; wait


print_byte:
    ; Print 2 characters which are the hex representation of a given byte
    ; Args:
    ;   AL: byte to print hex representation of    
    mov dl, al                      ; Copy AL to DL as we will overwrite AL and we will need to reaccess the given byte
    mov ah, 0x0E                    ; Choose BIOS interrupt function - Teletype output the char at AL

    ; Print 4 most significant bits character
    and al, 0b11110000
    shr al, 4
    call .set_al_to_al_4lsb_ascii_hex
    int 0x10

    ; Print 4 least significant bits character
    mov al, dl
    and al, 0b00001111
    call .set_al_to_al_4lsb_ascii_hex
    int 0x10

    ret

    .set_al_to_al_4lsb_ascii_hex:
        ; Set AL to be the ASCII char which is the hex representation of the 4 least significant bits of AL.
        ; Args:
        ;   AL: Needs to be between 0x00 and 0x0F
        cmp al, 9               ; There is a distance of 7 characters in the ASCII table between the end of number characters and the beginning of upper-case letters.
        jbe .add_ascii_0
        add al, 7
        .add_ascii_0:
            add al, 0x30        ; Add the value of ASCII '0' to receive the final value of the ASCII hex representation of the 4 LS bits of AL
            ret


puts:
    ; Print a null-terminated string.
    ; Args:
    ;   SI: address of null-terminated string in DS segment
    mov ah, 0x0E    ; BIOS interrupt function - Teletype output the char at AL
    lodsb           ; Load byte at address DS:SI into AL
    or al, al       ; Check if the current character is a null byte
    jz .j_ret       ; Return if current char is null
    int 0x10        ; BIOS interrupt
    jmp puts        ; Re-call puts and print the next character
    .j_ret: ret

puts_hex:
    mov ah, 0x0E
    lodsb
    or al, al
    jz .j_ret

    push ax
    call print_byte
    pop ax

    mov al, ' '
    int 0x10
    
    jmp puts_hex
    .j_ret:
        mov si, newline
        call puts
        ret

putsn:
    ; Print a string starting at SI and ending CX bytes afterwards.
    mov ah, 0x0E
    lodsb
    int 0x10
    loop putsn

putsn_hex:
    ; Print the hex representation of DS:00 - DS:CX, bytes seperated by spaces
    mov ah, 0x0E
    xor si, si              ; Reset SI to 0 to print from segment start
    .putsn_hex:
        lodsb               ; mov al, [ds:si] ; si += 1
        call print_byte     ; Print hex representation of AL
        cmp cx, 1           ; Print a space if the current character is not the last in the string
        jbe .loop
        mov al, ' '
        int 0x10
    .loop: loop .putsn_hex
    ret

print_segment:
    ; Hex dump a memory segment at address AX
    push ds         ; Save current DS
    mov ds, ax      ; Set DS to current segment to print
    mov cx, 0xFFFF  ; Set amount of bytes to dump - entire segment
    call putsn_hex  ; Call function to hex dump DS:00 - DS:CX
    pop ds          ; Return to saved DS
    ret

print_segments:
    ; Hex dump continuous memory starting at segment AX and going on forward BX segments.
    ; To print continuous memory, the correct gap between segments is 0x1000
    call print_segment
    mov si, newline
    call puts
    add ax, 0x1000
    dec bx
    jnz print_segments
    ret

msg_welcome:
    db "Welcome to the BootDumper!", 0x0D, 0x0A, 0
msg_dump_start:
    db "Starting dump...", 0x0D, 0x0A, 0
msg_done:
    db "Finished Dumping! Enjoy my product.", 0x0D, 0x0A, 0
newline: db 0x0D, 0x0A, 0


times 510-($-$$) db 0
dw 0xAA55               ; Magic bytes for the image to be considered a valid MBR