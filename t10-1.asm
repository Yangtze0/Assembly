assume cs:code,ds:data,ss:stack

stack segment
    dw 8 dup (0)
stack ends

data segment
    db 'Welcome to masm!',0
data ends

code segment
start:
    mov ax,stack
    mov ss,ax
    mov sp,16

    mov ax,data
    mov ds,ax

    mov dh,8
    mov dl,3
    mov cl,2
    mov si,0
    call show_str

    mov ax,4c00H
    int 21H

show_str:
    push es
    push bx
    push bp
    push di

    mov ax,0b800h
    mov es,ax

    mov al,dh
    mov bl,0a0h
    mul bl
    mov bp,ax
    mov al,dl
    mov bl,2
    mul bl
    mov di,ax

s:  push cx
    mov cl,[si]
    mov ch,0
    jcxz ok
    mov es:[bp][di],cl
    pop cx
    mov es:[bp].1[di],cl
    inc si
    add di,2
    jmp short s

ok: pop cx
    pop di
    pop bp
    pop bx
    pop es
    ret

code ends

end start
