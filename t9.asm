assume cs:code,ds:data,ss:stack

stack segment
    dw 8 dup (0)
stack ends

data segment
    db 'welcome to masm!'
    db 10000010b,00101100b,01110001b
data ends

code segment
start:
    mov ax,stack
    mov ss,ax
    mov sp,16

    mov ax,data
    mov ds,ax

    mov ax,0b872h
    mov es,ax

    mov bx,0
    mov si,0
    mov bp,0
    mov di,0
    mov cx,3

s0: push cx
    mov bx,0
    mov di,0
    mov cx,16

s:  mov al,[bx]
    mov es:[bp][di],al
    mov al,10h[si]
    mov es:[bp].1[di],al

    inc bx
    add di,2
    loop s

    inc si
    add bp,0a0h
    pop cx
    loop s0

    mov ax,4c00H
    int 21H
code ends

end start
