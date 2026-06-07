bits 16

global _start
global _putInMemory
global _getChar
global _getFromMemory
extern _main

_start:
    cli
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFF
    sti
    call _main

.hang:
    jmp .hang

_putInMemory:
    push bp
    mov bp, sp
    push ds
    push bx
    mov ax, [bp+4]
    mov bx, [bp+6]
    mov cl, [bp+8]
    mov ds, ax
    mov [bx], cl
    pop bx
    pop ds
    pop bp
    ret

_getFromMemory:
    push bp
    mov bp, sp
    push ds
    push bx
    mov ax, [bp+4]
    mov bx, [bp+6]
    mov ds, ax
    mov al, [bx]
    xor ah, ah
    pop bx
    pop ds
    pop bp
    ret

_getChar:
    mov ah, 0x00
    int 0x16
    xor ah, ah
    ret
