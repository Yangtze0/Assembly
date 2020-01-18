assume cs:code

code segment
start:
    mov ax,cs
    mov ds,ax
    mov si,offset hacka

    mov ax,0
    mov es,ax
    mov di,200h

    mov cx,offset h_end-offset hacka
    cld
    rep movsb

    mov ax,es:[9*4]
    mov es:[202h],ax
    mov ax,es:[9*4+2]
    mov es:[204h],ax
    mov word ptr es:[9*4],200h
    mov word ptr es:[9*4+2],0

    mov ax,4c00H
    int 21H

hacka:
    jmp short h_start
    db "hack A b"
h_start:
    push ax
    push es
    push cx
    push si

    in al,60h
    pushf
    call dword ptr cs:[202h]

    cmp al,9eh
    jne ok
    mov si,1
    mov cx,7d0h
s:  mov ax,0b800h
    mov es,ax
    mov byte ptr es:[si],2
    add si,2
    loop s

ok: pop si
    pop cx
    pop es
    pop ax
    iret
h_end:nop

code ends

end start
