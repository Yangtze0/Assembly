assume cs:code

code segment
start:
    mov ax,cs
    mov ds,ax
    mov si,offset setscreen

    mov ax,0
    mov es,ax
    mov di,200h

    mov cx,offset s_end-offset setscreen
    cld
    rep movsb

    mov word ptr es:[7ch*4+0],200h
    mov word ptr es:[7ch*4+2],0

    ;test
    mov ah,1
    mov al,2
    int 7ch
    mov ah,2
    mov al,4
    int 7ch

    mov ax,4c00h
    int 21h

setscreen:
    jmp short s_start
    table   dw offset sub0-offset setscreen+200h
            dw offset sub1-offset setscreen+200h
            dw offset sub2-offset setscreen+200h
            dw offset sub3-offset setscreen+200h
s_start:
    push bx
    cmp ah,3
    ja s_ret
    mov bl,ah
    mov bh,0
    add bx,bx
    call word ptr cs:202h[bx]
s_ret:
    pop bx
    iret

sub0:
    push bx
    push cx
    push es
    mov bx,0b800h
    mov es,bx
    mov bx,0
    mov cx,2000
sub0s:
    mov byte ptr es:[bx],' '
    add bx,2
    loop sub0s
    pop es
    pop cx
    pop bx
    ret

sub1:
    push bx
    push cx
    push es
    mov bx,0b800h
    mov es,bx
    mov bx,1
    mov cx,2000
sub1s:
    and byte ptr es:[bx],11111000b
    or es:[bx],al
    add bx,2
    loop sub1s
    pop es
    pop cx
    pop bx
    ret

sub2:
    push bx
    push cx
    push es
    mov cl,4
    shl al,cl
    mov bx,0b800h
    mov es,bx
    mov bx,1
    mov cx,2000
sub2s:
    and byte ptr es:[bx],10001111b
    or es:[bx],al
    add bx,2
    loop sub2s
    pop es
    pop cx
    pop bx
    ret

sub3:
    push cx
    push si
    push di
    push es
    push ds
    mov si,0b800h
    mov es,si
    mov ds,si
    mov si,160
    mov di,0
    cld
    mov cx,24
sub3s:
    push cx
    mov cx,160
    rep movsb
    pop cx
    loop sub3s
    mov cx,80
    mov si,0
sub3s1:
    mov byte ptr [160*24+si],' '
    add si,2
    loop sub3s1
    pop ds
    pop es
    pop di
    pop si
    pop cx
    ret
    
s_end:nop

code ends

end start
