assume cs:code,ds:data,ss:stack

stack segment
    dw 8 dup (0)
stack ends

data segment
    db '1. display      '
    db '2. brows        '
    db '3. replace      '
    db '4. modify       '
data ends

code segment
start:
    mov ax,stack
    mov ss,ax
    mov sp,16

    mov ax,data
    mov ds,ax

    mov bx,0
    mov cx,4

s0: push cx
    mov si,0
    mov cx,4

s:  mov al,3[bx][si]
    and al,11011111b
    mov 3[bx][si],al
    inc si
    loop s

    add bx,16
    pop cx
    loop s0

    mov ax,4c00H
    int 21H
code ends

end start
