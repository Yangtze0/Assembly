assume cs:code,ds:data

data segment
    db 'welcome to masm! ',0
data ends

code segment
start:
    mov ax,cs
    mov ds,ax
    mov si,offset show_str

    mov ax,0
    mov es,ax
    mov di,200h

    mov cx,offset s_end-offset show_str
    cld
    rep movsb

    mov word ptr es:[7ch*4+0],200h
    mov word ptr es:[7ch*4+2],0

    ;test
    mov dh,10
    mov dl,10
    mov cl,2
    mov ax,data
    mov ds,ax
    mov si,0
    int 7ch

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
    iret
s_end:nop

code ends

end start
