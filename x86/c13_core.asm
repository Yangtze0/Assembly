; x86 Assembly
; TAB=4

	org 0x100
section install
    mov ax,cs
    mov es,ax

    mov ebx,section.head.start
    sub [cs:bx+0x00],ebx
    sub [cs:bx+0x04],ebx
    sub [cs:bx+0x08],ebx
    sub [cs:bx+0x0c],ebx

    mov ax,[cs:bx+0x00]
    mov dx,[cs:bx+0x02]
    add ax,511
    mov bx,512
    div bx

    mov cx,ax
    mov ax,1
    mov bx,section.head.start
    write_loop:
        call write_floppy_disk
        inc ax
        mov dx,es
		add dx,0x20
		mov es,dx
        loop write_loop

    mov ax,4c00h
    int 21h

write_floppy_disk:	;向软盘写入一个逻辑扇区
					;输入：ax(逻辑扇区号)，es:bx(目标位置)
	push ax
    push cx
    push dx

    push bx
	mov dl,0	;0:FD

	mov bl,36
	div bl
	mov dh,al	;C

	mov al,ah
	mov ah,0
	mov bl,18
	div bl
	mov ch,al	;H
	mov cl,ah
	add cl,1	;S

	mov al,1	;n
	mov ah,3	;write
	pop bx
	int 13h

    pop dx
    pop cx
    pop ax
	ret

    sel_mem_4gb     equ 0x08
    sel_core_stack  equ 0x18
    sel_mem_screen  equ 0x20
    sel_sys_routine equ 0x28
    sel_core_data   equ 0x30
    sel_core_code   equ 0x38

section head align=0x200 vstart=0
    core_lenth      dd section.tail.start
    seg_sys_routine dd section.sys_routine.start
    seg_core_data   dd section.core_data.start
    seg_core_code   dd section.core_code.start
    core_entry      dd entry
                    dw sel_core_code

    [bits 32]
section sys_routine align=16 vstart=0
show_string:            ;显示以0终止的字符串并移动光标
                    ;输入：ds:ebx(串地址)
    push ecx
    getc:
        mov cl,[ebx]
        or cl,cl
        jz exit
        mov ch,0x12
        call show_char
        inc ebx
        jmp getc
    
    exit:
    pop ecx
    retf

 show_char:         ;显示一个字符并推进光标，仅段内调用
                    ;输入：cl(字符ASCII码)，ch(颜色属性)
    pushad
    push ds
    push es

    mov eax,sel_mem_screen
    mov ds,eax
    mov es,eax

    mov dx,0x3d4
    mov al,0x0e
    out dx,al
    mov dx,0x3d5
    in al,dx        ;光标位置高8位
    mov ah,al

    mov dx,0x3d4
    mov al,0x0f
    out dx,al
    mov dx,0x3d5
    in al,dx        ;光标位置低8位  
    mov bx,ax       ;bx=16位光标位置

    cmp cl,0x0d     ;回车符？
    jnz get_0a
    mov ax,bx
    mov bl,80
    div bl
    mul bl
    mov bx,ax
    jmp set_cursor

    get_0a:
    cmp cl,0x0a     ;换行符？
    jnz get_other
    add bx,80
    jmp roll_screen

    get_other:      ;可打印字符
    shl bx,1
    mov [es:bx],cx
    shr bx,1
    inc bx

    roll_screen:
    cmp bx,2000     ;光标超出屏幕？滚屏
    jl set_cursor

    mov esi,0xa0
    mov edi,0x00
    cld
    mov ecx,1920
    rep movsw

    push bx
    mov bx,3840     ;清除屏幕最底一行
    mov ecx,80
    cls:
        mov word [es:bx],0x0720
        add bx,2
        loop cls
    
    pop bx
    sub bx,80

    set_cursor:
    mov dx,0x3d4
    mov al,0x0e
    out dx,al
    mov dx,0x3d5
    mov al,bh
    out dx,al
    mov dx,0x3d4
    mov al,0x0f
    out dx,al
    mov dx,0x3d5
    mov al,bl
    out dx,al

    pop es
    pop ds
    popad
    ret

show_hex_dword:         ;以十六进制显示双字并推进光标，调试用
                        ;输入：edx(待显示双字)
    pushad
    push ds
      
    mov eax,sel_core_data
    mov ds,eax
      
    mov ebx,bin_hex     ;指向核心数据段内的转换表
    mov ecx,8
    xlt:    
        rol edx,4
        mov eax,edx
        and eax,0x0000000f
        xlat            ;Translate
      
        push ecx
        mov cl,al
        mov ch,0x42
        call show_char
        pop ecx
        loop xlt
    
    pop ds
    popad
    retf

allocate_memory:        ;分配内存
                        ;输入：ecx(希望分配字节数)
                        ;输出：ecx(起始线性地址)
    push eax
    push ebx
    push ds
    
    mov eax,sel_core_data
    mov ds,eax
      
    mov eax,[ram_alloc]
    add eax,ecx
      
    ;这里应当有检测可用内存数量的指令
          
    mov ecx,[ram_alloc]

    mov ebx,eax
    and ebx,0xfffffffc
    add ebx,4               ;align=4
    test eax,0x00000003
    cmovnz eax,ebx
    mov [ram_alloc],eax

    pop ds
    pop ebx
    pop eax
    retf

GDT_make:		        ;构造描述符
				        ;输入：eax(线性基址)，ebx(段界限)，ecx(属性)
				        ;返回：edx:eax(完整描述符)
	mov edx,eax
	shl eax,16
	or ax,bx

	and edx,0xffff0000
	rol edx,8
	bswap edx
	and ebx,0x000f0000
	or edx,ebx
	or edx,ecx

	retf

GDT_add:                ;在GDT内安装一个新的描述符
                        ;输入：edx:eax=描述符 
                        ;输出：cx=描述符选择子
    push eax
    push ebx
    push edx
    push ds
    push es
      
    mov ebx,sel_core_data
    mov ds,ebx
    mov ebx,sel_mem_4gb
    mov es,ebx

    sgdt [GDTR]
    movzx ebx,word [GDTR]
    inc bx                     
    add ebx,[GDTR+0x02]        
      
    mov [es:ebx+0x00],eax
    mov [es:ebx+0x04],edx
      
    add word [GDTR],8               
    lgdt [GDTR]                   
       
    mov ax,[GDTR]            
    xor dx,dx
    mov bx,8
    div bx                   
    mov cx,ax                          
    shl cx,3     

    pop es
    pop ds
    pop edx
    pop ebx
    pop eax
    retf 

section core_data align=16 vstart=0
    GDTR            dw 0
                    dd 0
    ram_alloc       dd 0x00100000           ;下次内存分配起始地址

    SALT:
        salt_1      db '@PrintString'
                    times 256-($-salt_1) db 0
                    dd show_string
                    dw sel_sys_routine

        salt_2      db '@ReadDiskData'
                    times 256-($-salt_2) db 0
                    dd 0
                    dw sel_sys_routine

        salt_3      db '@PrintDwordAsHexString'
                    times 256-($-salt_3) db 0
                    dd show_hex_dword
                    dw sel_sys_routine

        salt_4      db '@TerminateProgram'
                    times 256-($-salt_4) db 0
                    dd return_point
                    dw sel_core_code

        salt_item_len   equ $-salt_4
        salt_items      equ ($-SALT)/salt_item_len

    msg_1           db '  If you seen this message,that means we '
                    db 'are now in protect mode, and the system '
                    db 'core is loaded, and the video display '
                    db 'routine works perfectly.',0x0d,0x0a,0
    msg_5           db '  Loading user program...',0
    do_status       db '  Done.',0x0d,0x0a,0
    msg_6           db 0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                    db '  User program terminated, control returned.',0

    bin_hex         db '0123456789abcdef'   ;show_hex_dword查找表

    esp_pointer     dd 0

    cpu_brnd0       db 0x0d,0x0a,'  ',0
    cpu_brand       times 52 db 0
    cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

    align 16
user_program:
    user_len        dd user_end - user_program

    user_head_len   dd user_data - user_program     ;0x04   sel_head

    user_stack_seg  dd 0    ;接收堆栈段选择子          #0x08   sel_stack
    user_stack_len  dd 1    ;建议堆栈大小，以4KB为单位  #0x0c

    user_entry      dd 0    ;程序入口                 #0x10
    user_code_seg   dd user_code - user_program     ;0x14   sel_code
    user_code_len   dd user_end - user_code         ;0x18

    user_data_seg   dd user_data - user_program     ;0x1c   sel_data
    user_data_len   dd user_code - user_data        ;0x20

    user_salt_items dd (user_data - user_salt)/256  ;0x24
    user_salt:                                      ;0x28
        PrintString             db  '@PrintString'
                                times 256-($-PrintString) db 0      
        TerminateProgram        db  '@TerminateProgram'
                                times 256-($-TerminateProgram) db 0    
        PrintDwordAsHexString   db  '@PrintDwordAsHexString'
                                times 256-($-PrintDwordAsHexString) db 0

    user_data:
        user_msg1   db 0x0d,0x0a,0x0d,0x0a
                    db '**********User program is runing**********'
                    db 0x0d,0x0a,0
        user_msg2   db '  Disk data:',0x0d,0x0a,0

    user_code:
        mov eax,ds
        mov fs,eax

        mov eax,[user_stack_seg - user_program]
        mov ss,eax
        mov esp,0
     
        mov eax,[user_data_seg - user_program]
        mov ds,eax
     
        mov ebx,user_msg1 - user_data
        call far [fs:PrintString - user_program]

        mov edx,0xeeeeeeee
        call far [fs:PrintDwordAsHexString - user_program]
     
        mov ebx,user_msg2 - user_data
        call far [fs:PrintString - user_program]

        jmp far [fs:TerminateProgram - user_program]    ;将控制权返回到系统 
    user_end:
        times 0x200 db 0

section core_code align=16 vstart=0
load_relocate_program:      ;加载并重定位用户程序
                            ;输入：esi(程序位置)
                            ;返回：ax(指向程序头的选择子)
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ds
    push es

    mov eax,sel_core_data
    mov ds,eax                      ;ds:esi(程序位置)
    
    ;程序尺寸512字节对其
    mov eax,[esi]
    mov ebx,eax
    and ebx,0xfffffe00
    add ebx,0x200
    test eax,0x000001ff
    cmovnz eax,ebx

    ;读取用户程序
    mov ecx,eax
    call sel_sys_routine:allocate_memory
    mov edi,ecx                     ;es:edi(程序装载地址)
    push edi
    mov ecx,eax
    mov eax,sel_mem_4gb
    mov es,eax
    cld
    rep movsb

    pop edi                         ;程序起始线性地址
    ;建立程序头部段描述符
    mov eax,edi                     ;基址   0x00100000
    mov ebx,[es:edi+0x04]
    dec ebx                         ;界限   0x00000327
    mov ecx,0x00409200              ;属性
    call sel_sys_routine:GDT_make
    call sel_sys_routine:GDT_add
    mov [es:edi+0x04],cx

    ;建立程序代码段描述符
    mov eax,edi
    add eax,[es:edi+0x14]
    mov ebx,[es:edi+0x18]
    dec ebx                   
    mov ecx,0x00409800        
    call sel_sys_routine:GDT_make
    call sel_sys_routine:GDT_add
    mov [es:edi+0x14],cx

    ;建立程序数据段描述符
    mov eax,edi
    add eax,[es:edi+0x1c]  
    mov ebx,[es:edi+0x20]     
    dec ebx                
    mov ecx,0x00409200       
    call sel_sys_routine:GDT_make
    call sel_sys_routine:GDT_add
    mov [es:edi+0x1c],cx

    ;建立程序堆栈段描述符
    mov ecx,[es:edi+0x0c]           ;大小(4KB)
    mov ebx,0x000fffff
    sub ebx,ecx                     ;界限
    mov eax,4096                        
    mul dword [es:edi+0x0c]                         
    mov ecx,eax
    call sel_sys_routine:allocate_memory
    add eax,ecx                     ;基址 
    mov ecx,0x00c09600              ;属性
    call sel_sys_routine:GDT_make
    call sel_sys_routine:GDT_add
    mov [es:edi+0x08],cx

    ;重定位salt
    mov eax,[es:edi+0x04]
    mov es,eax
    mov edi,0x28                    ;es:edi(user_salt)
    mov eax,sel_core_data
    mov ds,eax
    mov esi,SALT                    ;ds:esi(core_salt)
    cld

    mov ecx,[es:0x24]               ;user_salt_items
    b0:
        push ecx
        push edi
        push esi

        mov ecx,salt_items          ;core_salt_items
        b1:
            push ecx
            push edi
            push esi

            mov ecx,64
            repe cmpsd
            jnz b2

            mov eax,[esi]           ;若匹配，esi恰好指向其后的地址数据
            mov [es:edi-256],eax    ;将字符串改写成偏移地址 
            mov ax,[esi+4]
            mov [es:edi-252],ax     ;以及段选择子 

            b2:
            pop esi
            add esi,salt_item_len
            pop edi
            pop ecx
            loop b1

        pop esi
        pop edi
        add edi,256
        pop ecx
        loop b0

    mov ax,es

    pop es
    pop ds
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

entry:                      ;内核入口
    mov eax,sel_core_data
    mov ds,eax
    mov es,eax

    mov ebx,msg_1
    call sel_sys_routine:show_string

    mov eax,0x80000002
    cpuid
    mov [cpu_brand + 0x00],eax
    mov [cpu_brand + 0x04],ebx
    mov [cpu_brand + 0x08],ecx
    mov [cpu_brand + 0x0c],edx
      
    mov eax,0x80000003
    cpuid
    mov [cpu_brand + 0x10],eax
    mov [cpu_brand + 0x14],ebx
    mov [cpu_brand + 0x18],ecx
    mov [cpu_brand + 0x1c],edx

    mov eax,0x80000004
    cpuid
    mov [cpu_brand + 0x20],eax
    mov [cpu_brand + 0x24],ebx
    mov [cpu_brand + 0x28],ecx
    mov [cpu_brand + 0x2c],edx

    mov ebx,cpu_brnd0
    call sel_sys_routine:show_string
    mov ebx,cpu_brand
    call sel_sys_routine:show_string
    mov ebx,cpu_brnd1
    call sel_sys_routine:show_string

    mov ebx,msg_5
    call sel_sys_routine:show_string
    mov esi,user_program
    call load_relocate_program

    mov ebx,do_status
    call sel_sys_routine:show_string
    mov [esp_pointer],esp   ;临时保存堆栈指针
    
    mov ds,ax               ;sel_user_head
    jmp far [0x10]

return_point:               ;用户程序返回点
    mov eax,sel_core_data
    mov ds,eax

    mov eax,sel_core_stack  ;切换回内核自己的堆栈
    mov ss,eax 
    mov esp,[esp_pointer]

    mov ebx,msg_6
    call sel_sys_routine:show_string

    ;这里可以放置清除用户程序各种描述符的指令
    ;也可以加载并启动其它程序
       
    hlt

section tail align=0x200
;core_end
