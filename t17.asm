assume cs:code

code segment
start:
    mov ax,cs
    mov ds,ax
    mov si,offset floppy

    mov ax,0
    mov es,ax
    mov di,200h

    mov cx,offset f_end-offset floppy
    cld
    rep movsb

    mov ax,es:[13h*4+0]
    mov es:[202h],ax
    mov ax,es:[13h*4+2]
    mov es:[204h],ax
    mov word ptr es:[7ch*4+0],200h
    mov word ptr es:[7ch*4+2],0

    ;test
    mov ax,0b800h
    mov es,ax
    mov bx,0
    mov si,0
    mov cx,256
s1: or byte ptr es:[bx][si].1,01000000b
    add si,2
    loop s1
    mov ah,1
    mov dx,0
    int 7ch

    mov ax,0b8a0h
    mov es,ax
    mov bx,0
    mov ah,0
    mov dx,0
    int 7ch
    mov si,0
    mov cx,256
s2: or byte ptr es:[bx][si].1,00100000b
    add si,2
    loop s2
    mov ax,4c00h
    int 21h

floppy:
    jmp short f_start
    db "floppyrw"
f_start:
    push bx
    push ax

    mov ax,dx
    mov dx,0
    mov bx,1440
    div bx
    push ax

    mov ax,dx
    mov dx,0
    mov bx,18
    div bx
    push ax

    inc dx
    mov cl,dl
    pop ax
    mov ch,al
    pop ax
    mov dh,al
    mov dl,0

    pop ax
    add ah,2
    mov al,1
    pop bx

    pushf
    call dword ptr cs:[202h]
    iret
f_end:nop
code ends

end start
