assume cs:code

data segment
    db 2048 dup (0)
data ends

code segment
start:
    ;write boot to data0
    mov ax,cs
    mov ds,ax
    mov si,offset boot

    mov ax,data
    mov es,ax

    mov di,0
    mov cx,offset b_end - offset boot
    cld
    rep movsb

    ;write task to data1-3
    mov si,offset task
    mov di,512
    mov cx,offset t_end - offset task
    cld
    rep movsb

    ;write data to floppy1-4
    mov ax,data
    mov es,ax
    mov bx,0

    mov dl,0
    mov dh,0
    mov ch,0
    mov cl,1
    mov al,4
    mov ah,3
    int 13h

    mov ax,4c00h
    int 21h

;floppy 0 0 1
boot:
    jmp short b_start
    db 10 dup (0)
    b_start:
        mov ax,cs
        mov ss,ax
        mov sp,10

        mov ax,0
        mov es,ax
        mov bx,7e00h

        mov al,3
        mov ch,0
        mov cl,2
        mov dl,0
        mov dh,0
        mov ah,2
        int 13h

        mov bx,0
        push bx
        mov bx,7e00h
        push bx
        retf
    b_end:nop

;floppy 0 0 2-4
task:
    jmp short t_start
    menu_1 db '1) reset pc',0
    menu_2 db '2) start system',0
    menu_3 db '3) clock',0
    menu_4 db '4) set clock',0

    menu_addr   dw offset menu_1 - offset task + 7e00h
                dw offset menu_2 - offset task + 7e00h
                dw offset menu_3 - offset task + 7e00h
                dw offset menu_4 - offset task + 7e00h
    
    time db 9,8,7,4,2,0
    time_blank db '// :: '

    int9 dw 0,0
    Esc_F1 db 0
    t_start:
        call clear_screen
        call top_screen

        top_input:
        mov ah,0
        int 16h
        cmp al,31h
        je key1
        cmp al,32h
        je key2
        cmp al,33h
        je key3
        cmp al,34h
        je key4
        jmp top_input

        ;reset pc
        key1:
        mov ax,0ffffh
        push ax
        mov ax,0
        push ax
        retf

        ;boot c
        key2:
        call clear_screen
        mov ax,0
        mov es,ax
        mov bx,7c00h

        mov al,1
        mov ch,0
        mov cl,1
        mov dl,80h  ;hard disk start from 80h(C:),81h(D:)...
        mov dh,0
        mov ah,2
        int 13h

        mov ax,0
        push ax
        mov ax,7c00h
        push ax
        retf

        key3:
        call clear_screen
        call clock
        jmp short t_start

        key4:
        call clear_screen
        call set_clock
        jmp short t_start

    set_clock:
        jmp sc_start
        ;              '0123456789ab'
        sc_blank    db ' / /   : :  '
        sc_format   db 'yymmddhhmmss'
        sc_start:
        mov bx,offset cs_top - offset task + 7e00h
        mov word ptr [bx],0

        mov di,160*10+20*2
        mov byte ptr es:[di].0,'_'
        mov byte ptr es:[di].1,11110000b

        mov bx,offset sc_blank - offset task + 7e00h
        mov bp,offset sc_format - offset task + 7e00h
        mov cx,12
        sc_s0:
            mov al,[bx]
            mov es:[di].2,al
            mov byte ptr es:[di].3,3
            mov al,ds:[bp]
            mov es:[di-160].0,al
            mov byte ptr es:[di-160].1,4
            inc bx
            inc bp
            add di,4
            loop sc_s0
        
        call get_str
        call change_clock
        ret

    change_clock:
        jmp short cc_start
        cc_unit db 9,8,7,4,2,0
        cc_time db 13 dup (0)
        cc_start:
            push si
            push bx
            push cx
            push ax

            mov si,offset cc_time - offset task + 7e00h
            mov bx,offset cc_unit - offset task + 7e00h
            mov cx,6
            cc_s:
                push cx
                mov al,[si].0
                sub al,30h
                mov cl,4
                shl al,cl
                mov ah,[si].1
                sub ah,30h
                add ah,al

                mov al,[bx]
                out 70h,al
                mov al,ah
                out 71h,al

                inc bx
                add si,2
                pop cx
                loop cc_s

            pop ax
            pop cx
            pop bx
            pop si
            ret

    get_str:
        push ax
        gs_s:
            mov ah,0
            int 16h
            cmp al,30h
            jb notnum
            cmp al,39h
            ja gs_continue
            mov ah,0
            call char_stack
            jmp gs_continue
            notnum:
                cmp ah,0eh  ;delete
                jne gs_enter
                mov ah,1
                call char_stack
                jmp gs_continue
            gs_enter:
                cmp ah,1ch  ;Enter
                jne gs_continue
                mov al,0
                mov ah,0
                call char_stack
                mov ah,2
                call char_stack
                jmp gs_ret
            gs_continue:
            mov ah,2
            call char_stack
            jmp gs_s

        gs_ret:
        pop ax
        ret

    ;ah=0(push),1(pop),2(show)
    ;0:al=char
    ;1:al=char
    ;2:dh=row,dl=column
    char_stack:
        jmp short cs_start
        cs_table    dw offset cs_push - offset task + 7e00h
                    dw offset cs_pop - offset task + 7e00h
                    dw offset cs_show - offset task + 7e00h
        cs_top dw 0
        cs_time db 13 dup (0)
        cs_start:
            push bx
            push dx
            push di
            push es
            push bx

            cmp ah,2
            ja cs_ret
            mov bl,ah
            mov bh,0
            add bx,bx
            mov di,offset cs_table - offset task + 7e00h
            jmp word ptr [di][bx]
        cs_push:
            mov di,offset cs_top - offset task + 7e00h
            mov bx,[di]
            mov si,offset cs_time - offset task + 7e00h
            mov [si][bx],al
            inc bx
            mov [di],bx
            jmp cs_ret
        cs_pop:
            mov di,offset cs_top - offset task + 7e00h
            mov bx,[di]
            cmp bx,0
            je cs_ret
            dec bx
            mov [di],bx
            mov si,offset cs_time - offset task + 7e00h
            mov al,[si][bx]
            jmp cs_ret
        cs_show:
            mov di,160*10+20*2
            mov bx,0
            cs_s_s:
                mov bp,offset cs_top - offset task + 7e00h
                cmp bx,[bp]
                jne noempty
                mov byte ptr es:[di],' '
                jmp cs_ret
                noempty:
                mov si,offset cs_time - offset task + 7e00h
                mov al,[si][bx]
                mov es:[di].0,al
                mov byte ptr es:[di].1,2
                mov byte ptr es:[di].4,'_'
                mov byte ptr es:[di].5,11110000b
                inc bx
                add di,4
                jmp cs_s_s

        cs_ret:
            pop bx
            pop es
            pop di
            pop dx
            pop bx
            ret

    clock:
        push bx
        push ax
        push cx
        push si

        mov bx,offset int9 - offset task + 7e00h
        push ds:[9*4+0]
        pop [bx].0
        push ds:[9*4+2]
        pop [bx].2

        cli
        mov word ptr ds:[9*4+0],offset int9_hack - offset task + 7e00h
        mov word ptr ds:[9*4+2],cs
        sti

        mov bx,offset Esc_F1 - offset task + 7e00h
        mov byte ptr [bx],0
        date_loop:
            call date_screen
            mov al,[bx]
            cmp al,01h  ;Esc
            je c_end
            cmp al,3bh  ;F1
            jne continue

            mov si,1
            mov cx,2000
            color:
                inc byte ptr es:[si]
                add si,2
                loop color

            continue:
            mov si,3
            mov cx,0
            d_s:    ;delay 30000h
                sub cx,1
                sbb si,0
                cmp cx,0
                jne d_s
                cmp si,0
                jne d_s
            jmp date_loop

        c_end:
        mov bx,offset int9 - offset task + 7e00h
        cli
        push [bx].0
        pop ds:[9*4+0]
        push [bx].2
        pop ds:[9*4+2]
        sti

        pop si
        pop cx
        pop ax
        pop bx
        ret

    int9_hack:
        push bx
        in al,60h
        mov bx,offset int9 - offset task + 7e00h
        pushf
        call dword ptr [bx]
        mov bx,offset Esc_F1 - offset task + 7e00h
        mov [bx],al
        pop bx
        iret

    date_screen:
        push di
        push si
        push cx
        push ax
        push bx

        mov di,160*10+20*2
        mov si,offset time - offset task + 7e00h
        mov bx,offset time_blank - offset task + 7e00h
        mov cx,6
        d_s_s0:
            push cx
            mov al,[si]
            out 70h,al
            in al,71h

            mov ah,al
            mov cl,4
            shr ah,cl
            and al,00001111b

            add ah,30h
            add al,30h
            mov byte ptr es:[di].0,ah
            mov byte ptr es:[di].2,al
            mov al,[bx]
            mov byte ptr es:[di].4,al

            add di,6
            inc si
            inc bx
            pop cx
            loop d_s_s0

        pop bx
        pop ax
        pop cx
        pop si
        pop di
        ret

    top_screen:
        mov ax,0
        mov ds,ax
        mov bx,offset menu_addr - offset task + 7e00h

        mov ax,0b800h
        mov es,ax
        mov di,160*8+25*2

        mov cx,4
        t_s_s0:
            mov si,[bx]
            push cx
            push di
            t_s_s1:
                mov cl,[si]
                mov ch,0
                jcxz t_s_ok
                mov byte ptr es:[di].0,cl
                mov byte ptr es:[di].1,2
                inc si
                add di,2
                jmp short t_s_s1
            t_s_ok:
            add bx,2
            pop di
            add di,160
            pop cx
            loop t_s_s0

        ret

    clear_screen:
        push bx
        push cx
        push es
        push ax

        mov ax,0b800h
        mov es,ax
        mov bx,0
        mov ah,' '
        mov al,00000111b
        mov cx,2000
        c_s_s:
            mov byte ptr es:[bx].0,ah
            mov byte ptr es:[bx].1,al
            add bx,2
            loop c_s_s

        pop ax
        pop es
        pop cx
        pop bx
        ret

    t_end:nop
code ends

end start
