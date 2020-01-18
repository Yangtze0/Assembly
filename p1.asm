assume cs:code,ds:data,ss:stack,es:table

data segment
    db '1975','1976','1977','1978','1979','1980','1981','1982'
    db '1983','1984','1985','1986','1987','1988','1989','1990'
    db '1991','1992','1993','1994','1995'
    ;year
    dd 16,22,382,1356,2390,8000,16000,24486,50065,97479,140417,197514
    dd 345980,590827,803530,1183000,1843000,2759000,3753000,4649000,5937000
    ;summ
    dw 3,7,9,13,28,38,130,220,476,778,1001,1442,2258,2793,4037,5635,8226
    dw 11542,14430,15257,17800
    ;ne
data ends

table segment
    db 21 dup ('year summ ne ?? ')
    db 16 dup (0)
table ends

stack segment
    dw 24 dup (0)
stack ends

code segment
start:
    mov ax,stack
    mov ss,ax
    mov sp,16

    mov ax,data
    mov ds,ax

    mov ax,table
    mov es,ax

    mov bx,0
    mov bp,0
    mov cx,21

s0: push cx
    mov di,0
    mov cx,2

s1: mov ax,[bx]
    mov es:[bp].0[di],ax
    mov ax,54h[bx]
    mov es:[bp].5[di],ax
    add bx,2
    add di,2
    loop s1

    mov ax,0a8h[si]
    mov es:[bp].10,ax
    mov ax,es:[bp].5
    mov dx,es:[bp].7
    div word ptr es:[bp].10
    mov es:[bp].13,ax

    add si,2
    add bp,16
    pop cx
    loop s0

;show table
    mov ax,es
    mov ds,ax
    mov si,0
    mov dh,1
    mov cx,21
d0: push cx
    mov dl,20h
    mov cl,2
    call show_str

    add dl,8
    add si,5
    mov ax,[si]
    mov bx,dx
    mov dx,2[si]
    push si
    mov si,150h
    call dtoc
    mov dx,bx
    call show_str
    pop si

    add dl,10
    add si,5
    mov ax,[si]
    mov bx,dx
    mov dx,0
    push si
    mov si,150h
    call dtoc
    mov dx,bx
    call show_str
    pop si

    add dl,10
    add si,3
    mov ax,[si]
    mov bx,dx
    mov dx,0
    push si
    mov si,150h
    call dtoc
    mov dx,bx
    call show_str
    pop si

    inc dh
    add si,3
    pop cx
    loop d0

    mov ax,4c00H
    int 21H

dtoc:
    push cx
    push si

d1: mov cx,10
    call divdw
    add cx,30h
    push cx
    mov cx,ax
    inc si
    inc cx
    loop d1

    mov cx,si
    sub cx,150h
    mov si,150h
d2: pop [si]
    inc si
    loop d2

    pop si
    pop cx
    ret

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

show_str:
    push si
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
    pop si
    ret

code ends

end start
