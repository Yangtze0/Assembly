assume cs:code,ss:stack

stack segment
    dw 8 dup (0)
stack ends

code segment
start:
    mov ax,stack
    mov ss,ax
    mov sp,16

    mov ax,4240h
    mov dx,000fh
    mov cx,0ah
    call divdw

    mov ax,4c00H
    int 21H

divdw:
    push bx
    push ax
    mov ax,dx
    mov dx,0
    div cx
    mov bx,ax
    pop ax
    div cx
    mov cx,dx
    mov dx,bx
    pop bx
    ret

code ends

end start
