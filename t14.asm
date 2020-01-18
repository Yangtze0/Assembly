assume cs:code

code segment
start:
    ;year
    mov bl,9
    call cmos
    mov bx,0b800h
    mov es,bx
    mov byte ptr es:[160*12+40*2].0,ah
    mov byte ptr es:[160*12+40*2].1,2
    mov byte ptr es:[160*12+40*2].2,al
    mov byte ptr es:[160*12+40*2].3,2
    mov byte ptr es:[160*12+40*2].4,'/'
    mov byte ptr es:[160*12+40*2].5,2
    ;month
    mov bl,8
    call cmos
    mov bx,0b800h
    mov es,bx
    mov byte ptr es:[160*12+40*2].6,ah
    mov byte ptr es:[160*12+40*2].7,2
    mov byte ptr es:[160*12+40*2].8,al
    mov byte ptr es:[160*12+40*2].9,2
    mov byte ptr es:[160*12+40*2].10,'/'
    mov byte ptr es:[160*12+40*2].11,2
    ;day
    mov bl,7
    call cmos
    mov bx,0b800h
    mov es,bx
    mov byte ptr es:[160*12+40*2].12,ah
    mov byte ptr es:[160*12+40*2].13,2
    mov byte ptr es:[160*12+40*2].14,al
    mov byte ptr es:[160*12+40*2].15,2
    mov byte ptr es:[160*12+40*2].16,' '
    mov byte ptr es:[160*12+40*2].17,2
    ;hour
    mov bl,4
    call cmos
    mov bx,0b800h
    mov es,bx
    mov byte ptr es:[160*12+40*2].18,ah
    mov byte ptr es:[160*12+40*2].19,2
    mov byte ptr es:[160*12+40*2].20,al
    mov byte ptr es:[160*12+40*2].21,2
    mov byte ptr es:[160*12+40*2].22,':'
    mov byte ptr es:[160*12+40*2].23,2
    ;minute
    mov bl,2
    call cmos
    mov bx,0b800h
    mov es,bx
    mov byte ptr es:[160*12+40*2].24,ah
    mov byte ptr es:[160*12+40*2].25,2
    mov byte ptr es:[160*12+40*2].26,al
    mov byte ptr es:[160*12+40*2].27,2
    mov byte ptr es:[160*12+40*2].28,':'
    mov byte ptr es:[160*12+40*2].29,2
    ;second
    mov bl,0
    call cmos
    mov bx,0b800h
    mov es,bx
    mov byte ptr es:[160*12+40*2].30,ah
    mov byte ptr es:[160*12+40*2].31,2
    mov byte ptr es:[160*12+40*2].32,al
    mov byte ptr es:[160*12+40*2].33,2

    mov ax,4c00h
    int 21h

cmos:
    mov al,bl
    out 70h,al
    in al,71h

    mov ah,al
    mov cl,4
    shr ah,cl
    and al,00001111b

    add ah,30h
    add al,30h
    ret

code ends

end start
