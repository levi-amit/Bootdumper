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
    ; Segments are written to 0x12000 chunks of the floppy disk,
    ; So if one segment starts at 0x0000 and ends at 0xffff,
    ; the second will start at 0x12000 and end at 0x21fff, and so on.
    mov si, msg_welcome ; Print welcome message
    call puts

    xor cx, cx                      ; Start from first element of segments_to_dump
    .dump_segments_loop:
        ; Write message about current segment being dumped
        push cx                         ; BP-2
        mov si, msg_current_segment     ; "Current segment: 0x"
        call puts
        mov bx, [bp-2]
        add bx, bx
        mov ax, [segments_to_dump + bx]
        call print_ax                   ; "0000"
        mov si, newline
        call puts

        ; Write the current segment and progress to 
        mov cx, [bp-2]                  ; Restore CX to be current loop index

        mov bx, cx
        add bx, bx
        mov es, [segments_to_dump + bx] ; Select current segment to write to floppy
        add cx, cx
        mov ch, cl                      ; Start from floppy track CX * 2
        mov cl, 1                       ; Start from floppy track first sector
        call write_segment_floppyA

        pop cx
        inc cx                          ; increment index of current segment location in the segments_to_dump array
        cmp cx, [segments_to_dump_len]  ; Check if current array index is the last
        jb .dump_segments_loop          ; loop to dump each segment in the array


    mov si, newline
    call puts

    ; Going through the IVT on the resulting dump of the first segment,
    ; We'll dump the segments which contain cool BIOS interrupt code

    mov si, msg_done
    call puts

    jmp $                 ; wait

; Array of segment addresses to be dumped.
; Make sure to update the length data as you add elements!
segments_to_dump: dw 0x0000
segments_to_dump_len: dw 1

; Block Device Interaction
write_segment_floppyA:
    ; Write the contents of a full segment of memory to floppy A,
    ; starting at given track and sector.
    ; ARGS:
    ;   ES: Segment to write to disk
    ;   CH: Floppy track to start writing from
    ;   CL: Sector in the track to start writing from
    ; RETURN:
    ;   AH: Last track written to
    push bp             ; BP-0
    mov bp, sp
    push es             ; BP-2
    push bx             ; BP-4
    push dx             ; BP-6
    
    xor bx, bx          ; Start reading from beginning of segment

    ; Calculate initial amount of sectors to write to fill up first track
    mov al, 0x49        ; Max amount of sectors in a track + 1
    sub al, cl          ; subtract first sector of first track (first sector of a track is 1 not 0)

    dec sp
    mov BYTE [bp-7], 0x80 ; BP-7: Stack_Var_1
                        ; Counter for remaining sectors to write from the memory segment.
                        ; Starts at 0xFFFF bytes / 512 bytes per sector = 0x7F sectors.
    .write_loop:
        ; Write current ES:BX to starting segment, until the end of the track
        mov dl, 0x00    ; Drive - 1st floppy disk
        mov dh, 0x00    ; Head - 0
        mov ah, 0x03    ; Select BIOS function - Write sectors to drive
        int 0x13        ; BIOS Interrupt - write AL sectors starting from memory ES:BX
        ; AL now contains the amount of sectors written.
        ; Set Stack_Var_1 to be new counter for remaining sectors
        sub BYTE [bp-7], al                 ; Stack_Var_1 -= AL
        ; Set BX to be next starting address in memory to read from
        ; when writing to the next track
        xor ah, ah                          ; AX = (int) AL
        mul WORD [floppy_sector_size]       ; DX:AX = AX * 0x200 (Size of one sector)
        add bx, ax                          ; BX += AL * 0x200 (amount of bytes written)
        ; Set CL to write from next track start
        mov cl, 1                           ; CL = 1
        ; Set AL to the correct amount of sectors to write until the end of the segment
        mov al, [bp-7]                      ; AL = Stack_Var_1
        ; Increment track number
        inc ch
        ; Test if there are more sectors to write and stop loop if not
        or al, al                           ; ZF = (AL==0)
        jnz .write_loop
    
    mov ah, ch          ; Return last track written to

    inc sp              ; pop Stack_Var_1
    pop dx              ; BP-6
    pop bx              ; BP-4
    pop es              ; BP-2
    pop bp              ; BP-0
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
; Constants
floppy_sector_size: dw 0x200

times 510-($-$$) db 0
dw 0xAA55               ; Magic bytes for the image to be considered a valid MBR