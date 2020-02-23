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

write_floppy_disk:	    ;向软盘写入一个逻辑扇区
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

allocate_a_page:        ;分配并安装一个页
                        ;输入：ebx(页的线性地址)
    push eax
    push ebx
    push esi
    push ds

    mov eax,sel_mem_4gb
    mov ds,eax

    ;检查该线性地址对应页表是否存在
    mov esi,ebx
    and esi,0xffc00000
    shr esi,20                      ;得到页目录索引，并乘以4 
    or esi,0xfffff000               ;页目录自身的线性地址+表内偏移 
    test dword [esi],0x00000001     ;P位是否为1
    jnz ap0                    
          
    ;若无对应页表，则创建 
    call allocate_4KB               ;分配一个页做为页表 
    or eax,0x00000007
    mov [esi],eax                   ;在页目录中登记该页表
          
    ap0:
    ;开始访问该线性地址所对应的页表 
    mov esi,ebx
    shr esi,10
    and esi,0x003ff000              ;或者0xfffff000，因高10位是零 
    or esi,0xffc00000               ;得到该页表的线性地址

    ;得到该线性地址在页表内的对应条目（页表项） 
    and ebx,0x003ff000
    shr ebx,10                      ;相当于右移12位，再乘以4
    or esi,ebx                      ;页表项的线性地址 
    call allocate_4KB               ;分配一个页，这才是要安装的页
    or eax,0x00000007
    mov [esi],eax 
          
    pop ds
    pop esi
    pop ebx
    pop eax
    retf

 allocate_4KB:          ;分配一个4KB的页，仅段内调用
                        ;输入：无
                        ;输出：eax(页的物理地址)
    push ebx
    push ecx
    push edx
    push ds
         
    mov eax,sel_core_data
    mov ds,eax
         
    xor eax,eax
    ap1:
        bts [page_bit_map],eax
        jnc ap2
        inc eax
        cmp eax,page_map_len*8
        jl ap1
         
        mov ebx,msg_3
        call sel_sys_routine:show_string
        hlt             ;没有可以分配的页，停机 
         
    ap2:
    shl eax,12          ;乘以0x1000 

    pop ds
    pop edx
    pop ecx
    pop ebx 
    ret

copy_pdir:              ;复制当前页目录到新页目录
                        ;输入：无
                        ;输出：eax(新页目录物理地址)
    push ebx
    push ecx
    push esi
    push edi
    push ds
    push es
         
    mov ebx,sel_mem_4gb
    mov ds,ebx
    mov es,ebx
         
    call allocate_4KB          
    mov ebx,eax
    or ebx,0x00000007
    mov [0xfffffff8],ebx    ;新页目录表登记到倒数第二目录项
         
    mov esi,0xfffff000      ;ds:esi(当前页目录线性地址)
    mov edi,0xffffe000      ;es:esi(新页目录的线性地址)
    mov ecx,1024            ;目录项数
    cld
    repe movsd 
    
    pop es
    pop ds     
    pop edi
    pop esi 
    pop ecx
    pop ebx
    retf

make_seg:		        ;构造段描述符
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

make_gate:              ;构造门描述符
                        ;输入：eax(段内偏移)，bx(代码段选择子)，cx(段类型属性)
                        ;返回：edx:eax(完整描述符)
    push ebx
    push ecx
      
    mov edx,eax
    and edx,0xffff0000          
    or dx,cx                  
       
    and eax,0x0000ffff        
    shl ebx,16                          
    or eax,ebx   
      
    pop ecx
    pop ebx
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

terminate_task:         ;终止当前任务
    pushfd
    pop edx

    mov eax,sel_core_data
    mov ds,eax

    test dx,0100_0000_0000_0000b        ;测试NT位
    jnz tt_ret                          ;当前任务是嵌套的，到.b1执行iretd 
    jmp far [tss_pm]                    ;程序管理器任务 
    tt_ret:
    iretd

section core_data align=16 vstart=0
    GDTR            dw 0
                    dd 0
    page_bit_map    db 0xff,0xff,0xff,0xff,0xff,0x55,0x55,0xff  ;0x28000-0x38000
                    db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                    db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff
                    db 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff  ;1MB
                    db 0x55,0x55,0x55,0x55,0x55,0x55,0x55,0x55
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
                    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00  ;2MB
    page_map_len    equ $-page_bit_map

    salt:
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
                    dd terminate_task
                    dw sel_sys_routine

        salt_item_len   equ $-salt_4
        salt_items      equ ($-salt)/salt_item_len

    msg_0           db '  Working in system core, protect mode.'
                    db 0x0d,0x0a,0x0d,0x0a,0
    msg_1           db '  Paging is enabled. System core is mapped to'
                    db ' address 0x80000000.',0x0d,0x0a,0x0d,0x0a,0
    msg_2           db '  System wide CALL-GATE mounted.',0x0d,0x0a,0
    msg_3           db '********No more pages********',0
    msg_4           db 0x0d,0x0a,'  Task switching...@_@',0x0d,0x0a,0
    msg_5           db 0x0d,0x0a,'  Processor HALT.',0

    bin_hex         db '0123456789abcdef'   ;show_hex_dword 查找表

    cpu_brnd0       db 0x0d,0x0a,'  ',0
    cpu_brand       times 52 db 0
    cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

    tcb_chain       dd 0                    ;任务控制块链地址

    ;内核信息
    core_next_laddr dd 0x80100000           ;内核空间中下一个可分配地址
    tss_pm          dd 0                    ;程序管理器TSS基址
                    dw 0                    ;程序管理器TSS描述符选择子 

    align 16
user_program:
    user_len        dd user_end - user_program      ;0x00
    user_entry      dd user_code - user_program     ;0x04
    user_salt_pos   dd user_salt - user_program     ;0x08
    user_salt_items dd (user_data - user_salt)/256  ;0x0c
    user_salt:                                      
        PrintString             db  '@PrintString'
                                times 256-($-PrintString) db 0      
        TerminateProgram        db  '@TerminateProgram'
                                times 256-($-TerminateProgram) db 0  
        reserved                times 256*16  db 0  ;保留一个空白区，以演示分页
        PrintDwordAsHexString   db  '@PrintDwordAsHexString'
                                times 256-($-PrintDwordAsHexString) db 0

    user_data:
        user_msg1   db 0x0d,0x0a
                    db '  ............User task is running with '
                    db 'paging enabled!............',0x0d,0x0a,0
        user_msg2   db 0x20,0x20,0

    user_code:
        mov ebx,user_msg1 - user_program
        call far [PrintString - user_program]

        xor esi,esi
        mov ecx,88
        u1:
            mov ebx,user_msg2 - user_program
            call far [PrintString - user_program] 
         
            mov edx,[esi*4]
            call far [PrintDwordAsHexString - user_program]
         
            inc esi
            loop u1
     
        call far [TerminateProgram - user_program]    ;将控制权返回到系统 
    user_end:
        times 0x1000 db 0

section core_code align=16 vstart=0
LDT_add:                    ;在LDT内安装一个新的描述符
                            ;输入：edx:eax(描述符)，ebx(tcb基址)
                            ;输出：cx(描述符选择子)
    push eax
    push edx
    push edi
    push ds

    mov ecx,sel_mem_4gb
    mov ds,ecx
    mov edi,[ebx+0x0c]      ;LDT基址

    xor ecx,ecx
    mov cx,[ebx+0x0a]       ;LDT界限
    inc cx                  ;新描述符偏移地址

    mov [edi+ecx+0x00],eax
    mov [edi+ecx+0x04],edx  ;安装描述符

    add cx,8                           
    dec cx                  ;新的LDT界限

    mov [ebx+0x0a],cx       ;更新LDT界限值到TCB

    mov ax,cx
    xor dx,dx
    mov cx,8
    div cx
         
    mov cx,ax
    shl cx,3                ;左移3位，并且使TI位=1，指向LDT，最后使RPL=00 
    or cx,0000_0000_0000_0100b

    pop ds
    pop edi
    pop edx
    pop eax
    ret

load_relocate_program:      ;加载并重定位用户程序
                            ;输入：push(程序位置)
                            ;     push(tcb基址)
    pushad
    push ds
    push es

    mov ebp,esp
    mov eax,sel_mem_4gb
    mov es,eax

    ;清空当前页目录的前半部分（对应低2GB的局部地址空间） 
    mov ebx,0xfffff000
    xor esi,esi
    mov ecx,512
    l0:
        mov dword [es:ebx+esi*4],0x00000000
        inc esi
        loop l0

    mov eax,sel_core_data
    mov ds,eax                      ;ds:esi(程序位置)
    mov esi,[esp+4*12]              ;参数2：程序位置

    ;程序尺寸4KB对其
    mov eax,[esi]
    mov ebx,eax
    and ebx,0xfffff000
    add ebx,0x1000
    test eax,0x00000fff
    cmovnz eax,ebx

    mov ecx,eax
    shr ecx,12                      ;程序占用4KB页数
    mov edx,[ebp+4*11]              ;TCB基址
    l1:
        mov ebx,[es:edx+0x06]       ;取得可用的线性地址，从0开始
        call sel_sys_routine:allocate_a_page
        add dword [es:edx+0x06],0x1000
        mov edi,ebx                 ;es:edi(程序装载地址)
        push ecx
        mov ecx,1024
        cld
        rep movsd
        pop ecx
        loop l1
    
    mov esi,[ebp+4*11]              ;tcb基址

    ;在内核地址空间内创建用户任务的TSS
    mov ebx,[core_next_laddr]       ;用户任务的TSS必须在全局空间上分配 
    call sel_sys_routine:allocate_a_page
    add dword [core_next_laddr],4096
         
    mov [es:esi+0x14],ebx           ;在TCB中填写TSS的线性地址 
    mov word [es:esi+0x12],103      ;在TCB中填写TSS的界限值 

    ;在用户任务的局部地址空间内创建LDT 
    mov ebx,[es:esi+0x06]           ;从TCB中取得可用的线性地址
    call sel_sys_routine:allocate_a_page
    add dword [es:esi+0x06],0x1000
    mov [es:esi+0x0c],ebx           ;填写LDT线性地址到TCB中 

    ;建立程序代码段描述符
    mov eax,0x00000000
    mov ebx,0x000fffff               
    mov ecx,0x00c0f800              ;4KB粒度代码段，特权3
    call sel_sys_routine:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+76],cx              ;填写TSS的CS域 

    ;建立程序数据段描述符
    mov eax,0x00000000
    mov ebx,0x000fffff                
    mov ecx,0x00c0f200              ;4KB粒度数据段，特权3
    call sel_sys_routine:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+84],cx              ;填写TSS的DS域 
    mov [es:ebx+72],cx              ;填写TSS的ES域
    mov [es:ebx+88],cx              ;填写TSS的FS域
    mov [es:ebx+92],cx              ;填写TSS的GS域

    ;将数据段作为用户任务的3特权级固有堆栈 
    mov ebx,[es:esi+0x06]           ;从TCB中取得可用的线性地址
    add dword [es:esi+0x06],0x1000
    call sel_sys_routine:allocate_a_page
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+80],cx              ;填写TSS的SS域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址 
    mov [es:ebx+56],edx             ;填写TSS的ESP域 

    ;在用户任务的局部地址空间内创建0特权级堆栈
    mov ebx,[es:esi+0x06]           ;从TCB中取得可用的线性地址
    add dword [es:esi+0x06],0x1000
    call sel_sys_routine:allocate_a_page
    mov eax,0x00000000
    mov ebx,0x000fffff
    mov ecx,0x00c09200              ;4KB粒度的堆栈段描述符，特权级0
    call sel_sys_routine:make_seg
    mov ebx,esi                     ;TCB的基地址
    call LDT_add
    or cx,0000_0000_0000_0000b      ;设置选择子的特权级为0

    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+8],cx               ;填写TSS的SS0域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址
    mov [es:ebx+4],edx              ;填写TSS的ESP0域 

    ;在用户任务的局部地址空间内创建1特权级堆栈
    mov ebx,[es:esi+0x06]           ;从TCB中取得可用的线性地址
    add dword [es:esi+0x06],0x1000
    call sel_sys_routine:allocate_a_page
    mov eax,0x00000000
    mov ebx,0x000fffff
    mov ecx,0x00c0b200              ;4KB粒度的堆栈段描述符，特权级1
    call sel_sys_routine:make_seg
    mov ebx,esi                     ;TCB的基地址
    call LDT_add
    or cx,0000_0000_0000_0001b      ;设置选择子的特权级为1

    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+16],cx              ;填写TSS的SS1域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址
    mov [es:ebx+12],edx             ;填写TSS的ESP1域 

    ;在用户任务的局部地址空间内创建2特权级堆栈
    mov ebx,[es:esi+0x06]           ;从TCB中取得可用的线性地址
    add dword [es:esi+0x06],0x1000
    call sel_sys_routine:allocate_a_page
    mov eax,0x00000000
    mov ebx,0x000fffff
    mov ecx,0x00c0d200              ;4KB粒度的堆栈段描述符，特权级2
    call sel_sys_routine:make_seg
    mov ebx,esi                     ;TCB的基地址
    call LDT_add
    or cx,0000_0000_0000_0010b      ;设置选择子的特权级为2

    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+24],cx              ;填写TSS的SS2域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址
    mov [es:ebx+20],edx             ;填写TSS的ESP2域 

    ;重定位salt
    mov edi,[es:0x08]               ;es:edi(user_salt)
    mov esi,salt                    ;ds:esi(core_salt)
    cld

    mov ecx,[es:0x0c]               ;user_salt_items
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
            or ax,00000000_00000011b    ;以用户特权使用，故RPL=3
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

    mov esi,[ebp+4*11]              ;tcb基址

    ;在GDT中创建LDT描述符
    mov eax,[es:esi+0x0c]           ;LDT段基址
    movzx ebx,word [es:esi+0x0a]    ;LDT段界限
    mov ecx,0x00408200              ;LDT段属性，特权级0，系统段
    call sel_sys_routine:make_seg
    call sel_sys_routine:GDT_add
    mov [es:esi+0x10],cx            ;登记LDT选择子到TCB

    ;登记TSS基本表格内容
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+96],cx              ;填写TSS的LDT域 
    mov word [es:ebx+0],0           ;反向链=0
    mov dx,[es:esi+0x12]
    mov [es:ebx+102],dx             ;I/O位图偏移=TSS界限
    mov word [es:ebx+100],0         ;T
    mov eax,[es:0x04] 
    mov [es:ebx+32],eax             ;eip
    pushfd
    pop edx
    mov dword [es:ebx+36],edx       ;eflags

    ;在GDT中创建TSS描述符
    mov eax,[es:esi+0x14]           ;TSS基址
    movzx ebx,word [es:esi+0x12]    ;段界限
    mov ecx,0x00408900              ;TSS描述符，特权级0，系统段
    call sel_sys_routine:make_seg
    call sel_sys_routine:GDT_add
    mov [es:esi+0x18],cx            ;登记TSS选择子到TCB

    ;创建用户任务的页目录
    call sel_sys_routine:copy_pdir
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov dword [es:ebx+28],eax       ;填写TSS的CR3(PDBR)域

    pop es
    pop ds
    popad
    ret 8

tcb_append:                 ;在tcb链上追加任务控制块
                            ;输入：ecx(tcb线性基址)
    push eax
    push edx
    push ds
    push es
         
    mov eax,sel_core_data
    mov ds,eax
    mov eax,sel_mem_4gb
    mov es,eax
         
    mov dword [es:ecx+0x00],0                                
    mov eax,[tcb_chain]          
    or eax,eax      
    jz tcb_empty
         
    tcb_last:
        mov edx,eax
        mov eax,[es:edx+0x00]
        or eax,eax               
        jnz tcb_last
         
    mov [es:edx+0x00],ecx
    jmp tcb_ret
         
    tcb_empty:
    mov [tcb_chain],ecx                ;若为空表，直接令表头指针指向TCB
         
    tcb_ret:
    pop es
    pop ds
    pop edx
    pop eax     
    ret

entry:                      ;内核入口
    mov eax,sel_core_data
    mov ds,eax

    mov eax,sel_mem_4gb
    mov es,eax

    xor eax,eax
    mov fs,eax
    mov gs,eax

    ;显示CPU品牌信息
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

    mov ebx,msg_0
    call sel_sys_routine:show_string

    ;准备打开分页机制
    mov ebx,0x00020000                  ;内核页目录表PDT基址
    xor esi,esi
    mov ecx,1024                        ;目录项项数目
    p0:
        mov dword [es:ebx+esi],0x00000000
        add esi,4
        loop p0

    mov dword [es:ebx+4092],0x00020003  ;目录项，指向页目录自身(0xfffff000=0x00020000)
    mov dword [es:ebx+0],0x00021003     ;目录项，指向首页表(0xffc00000=0x00021000)

    mov ebx,0x00021000                  ;首页表基址
    xor eax,eax                         ;起始页的物理地址 
    xor esi,esi
    p1:       
        mov edx,eax
        or edx,0x00000003                                                      
        mov [es:ebx+esi*4],edx          ;登记页表项
        add eax,0x1000     
        inc esi
        cmp esi,256                     ;仅低端1MB内存对应页有效 
        jl p1
         
    p2:                                 ;其余的页表项置为无效
        mov dword [es:ebx+esi*4],0x00000000  
        inc esi
        cmp esi,1024
        jl p2

    ;令CR3寄存器指向页目录，并正式开启页功能 
    mov eax,0x00020000                  ;PCD=PWT=0
    mov cr3,eax

    mov eax,cr0
    or eax,0x80000000
    mov cr0,eax                         ;开启分页机制

    ;在页目录内创建与线性地址0x80000000对应的目录项
    mov ebx,0xfffff000                  ;页目录自己的线性地址 
    mov esi,0x80000000                  ;映射的起始地址
    shr esi,22                          ;线性地址的高10位是目录索引
    shl esi,2
    mov dword [es:ebx+esi],0x00021003   ;目录项，指向首页表(0x80000000)
                            
    ;将GDT中的段描述符映射到线性地址0x80000000
    sgdt [GDTR]
    mov ebx,[GDTR+2]
    or dword [es:ebx+0x10+4],0x80000000
    or dword [es:ebx+0x18+4],0x80000000
    or dword [es:ebx+0x20+4],0x80000000
    or dword [es:ebx+0x28+4],0x80000000
    or dword [es:ebx+0x30+4],0x80000000
    or dword [es:ebx+0x38+4],0x80000000

    or dword [GDTR+2],0x80000000        ;GDTR也用的是线性地址 
    lgdt [GDTR]

    jmp sel_core_code:flush             ;刷新段寄存器cs，启用高端线性地址                         

flush:
    mov eax,sel_core_stack
    mov ss,eax

    mov eax,sel_core_data
    mov ds,eax

    mov eax,sel_mem_4gb
    mov es,eax

    mov ebx,msg_1
    call sel_sys_routine:show_string

    ;安装系统服务调用门
    mov edi,salt
    mov ecx,salt_items
    g0:
        push ecx
        mov eax,[edi+256]
        mov bx,[edi+260]
        mov cx,1_11_0_1100_000_00000b
        call sel_sys_routine:make_gate
        call sel_sys_routine:GDT_add
        mov [edi+260],cx
        add edi,salt_item_len
        pop ecx
        loop g0
    
    ;调用门测试，双字偏移量被忽略
    mov ebx,msg_2
    call 0x0040:0

    ;创建程序管理器TSS，特权0
    mov ebx,[core_next_laddr]
    call sel_sys_routine:allocate_a_page
    add dword [core_next_laddr],4096

    mov eax,cr3
    mov dword [es:ebx+0x1c],eax     ;CR3(PDBR)
    mov word [es:ebx+0x60],0        ;无LDT
    mov word [es:ebx+0x66],103      ;无I/O位图，0特权级不需要
    mov word [es:ebx+0x00],0        ;反向链=0
    mov word [es:ebx+0x64],0        ;T=0
    mov [tss_pm+0x00],ebx 

    ;创建TSS描述符，并安装到GDT中 
    mov eax,ebx                     ;tss_pm基址
    mov ebx,103                     ;界限
    mov ecx,0x00408900              ;TSS描述符，特权级0
    call sel_sys_routine:make_seg
    call sel_sys_routine:GDT_add
    mov [tss_pm+0x04],cx            ;保存tss_pm描述符选择子 

    ltr cx                          ;TR任务存在标志，指定当前任务

    ;创建任务控制块，非处理器要求
    mov ebx,[core_next_laddr]
    call sel_sys_routine:allocate_a_page
    add dword [core_next_laddr],4096

    mov dword [es:ebx+0x06],0       ;用户任务局部空间的分配从0开始
    mov word [es:ebx+0x0a],0xffff   ;登记LDT初始的界限到TCB中
    mov ecx,ebx
    call tcb_append

    ;使用栈传递过程参数
    push dword user_program         ;用户程序位置
    push ecx                        ;任务控制块地址
    call load_relocate_program

    mov ebx,msg_4
    call sel_sys_routine:show_string

    ;执行任务切换
    call far [es:ecx+0x14]          ;dd(tss基址)dw(tss选择子)

    mov ebx,msg_5
    call sel_sys_routine:show_string

    hlt

section tail align=0x200
;core_end
