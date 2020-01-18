assume cs:code,ds:data,ss:stack

stack segment
    dw 8 dup (0)
stack ends

data segment
    db "Beginner's All-purpose Symbolic Instruction Code.",0
data ends

code segment
start:
    mov ax,stack
    mov ss,ax
    mov sp,16

    mov ax,data
    mov ds,ax

    mov si,0
    call letterc

    mov ax,4c00H
    int 21H

letterc:
    push cx
    push si

s0: mov cl,[si]
    jcxz ok

    cmp cl,'a'
    jb s1
    cmp cl,'z'
    ja s1
    and cl,11011111b
    mov [si],cl

s1: inc si
    jmp s0

ok: pop si
    pop cx
    ret

code ends

end start
