assume cs:code

code segment
start:
    mov ax,cs
    mov ds,ax
    mov si,offset iloop

    mov ax,0
    mov es,ax
    mov di,200h

    mov cx,offset iloop_end-offset iloop
    cld
    rep movsb

    mov word ptr es:[7ch*4+0],200h
    mov word ptr es:[7ch*4+2],0

    ;test
    mov ax,0b800h
    mov es,ax
    mov di,160*12
    mov bx,offset s-offset se
    mov cx,80
s:  mov byte ptr es:[di],'!'
    mov byte ptr es:[di].1,2
    add di,2
    int 7ch
se: nop
    mov ax,4c00H
    int 21H

iloop:
    push bp
    mov bp,sp
    dec cx
    jcxz iloop_ret
    add [bp+2],bx
iloop_ret:
    pop bp
    iret
iloop_end:nop

code ends

end start
