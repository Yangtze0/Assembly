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
    mov edx,[esp]                       ;获得EFLAGS寄存器内容
    add esp,4                           ;恢复堆栈指针

    mov eax,sel_core_data
    mov ds,eax

    test dx,0100_0000_0000_0000b        ;测试NT位
    jnz tt_ret                          ;当前任务是嵌套的，到.b1执行iretd 

    mov ebx,core_msg1                   ;当前任务不是嵌套的，直接切换到 
    call sel_sys_routine:show_string
    jmp far [tss_pm]                    ;程序管理器任务 
       
    tt_ret:
    mov ebx,core_msg0
    call sel_sys_routine:show_string
    iretd

section core_data align=16 vstart=0
    GDTR            dw 0
                    dd 0
    ram_alloc       dd 0x00100000           ;下次内存分配起始地址

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

    msg_1           db '  If you seen this message,that means we '
                    db 'are now in protect mode, and the system '
                    db 'core is loaded, and the video display '
                    db 'routine works perfectly.',0x0d,0x0a,0
    msg_2           db '  System wide CALL-GATE mounted.',0x0d,0x0a,0
    msg_3           db 0x0d,0x0a,'  Loading user program...',0
    do_status       db '  Done.',0x0d,0x0a,0
    msg_6           db 0x0d,0x0a,0x0d,0x0a,0x0d,0x0a
                    db '  User program terminated, control returned.',0

    bin_hex         db '0123456789abcdef'   ;show_hex_dword 查找表

    esp_pointer     dd 0

    cpu_brnd0       db 0x0d,0x0a,'  ',0
    cpu_brand       times 52 db 0
    cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

    tcb_chain       dd 0                    ;任务控制块链地址

    tss_pm          dd  0                   ;程序管理器TSS基址
                    dw  0                   ;程序管理器TSS描述符选择子 

    pm_msg1         db  0x0d,0x0a
                    db  '[PROGRAM MANAGER]: Hello! I am Program Manager, '
                    db  'run at CPL=0. Now, create user task and switch '
                    db  'to it by the CALL instruction...',0x0d,0x0a,0
                 
    pm_msg2         db  0x0d,0x0a
                    db  '[PROGRAM MANAGER]: I am glad to regain control. '
                    db  'Now, create another user task and switch to '
                    db  'it by the JMP instruction...',0x0d,0x0a,0
                 
    pm_msg3         db  0x0d,0x0a
                    db  '[PROGRAM MANAGER]: I am gain control again, '
                    db  'HALT...',0

    core_msg0       db  0x0d,0x0a
                    db  '[SYSTEM CORE]: Uh...This task initiated with '
                    db  'CALL instruction or an exeception interrupt, '
                    db  'should use IRETD instruction to switch back...'
                    db  0x0d,0x0a,0

    core_msg1       db  0x0d,0x0a
                    db  '[SYSTEM CORE]: Uh...This task initiated with '
                    db  'JMP instruction, should switch to Program '
                    db  'Manager directly by the JMP instruction...'
                    db  0x0d,0x0a,0

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
        user_msg1   db 0x0d,0x0a
                    db '[USER TASK]: Hi! nice to meet you, '
                    db 'I am run at CPL=',0
        user_msg2   db 0
                    db '. Now,I must exit...',0x0d,0x0a,0

    user_code:
        ;任务启动时，ds指向头部段，不需要设置堆栈
        mov eax,ds
        mov fs,eax

        mov eax,[user_data_seg - user_program]
        mov ds,eax
     
        mov ebx,user_msg1 - user_data
        call far [fs:PrintString - user_program]

        mov ax,cs
        and al,0000_0011b
        add al,0x30
        mov [user_msg2 - user_data],al

        ; mov edx,eax
        ; call far [fs:PrintDwordAsHexString - user_program]
     
        mov ebx,user_msg2 - user_data
        call far [fs:PrintString - user_program]

        call far [fs:TerminateProgram - user_program]    ;将控制权返回到系统 
    user_end:
        times 0x200 db 0

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

    ;创建LDT
    mov edi,[ebp+4*11]              ;参数1：tcb基址
    mov ecx,160                     ;允许安装20个描述符
    call sel_sys_routine:allocate_memory
    mov [es:edi+0x0c],ecx           ;登记LDT基址
    mov word [es:edi+0x0a],0xffff   ;登记LDT初始界限

    mov eax,sel_core_data
    mov ds,eax                      ;ds:esi(程序位置)
    mov esi,[esp+4*12]              ;参数2：程序位置

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
    mov [es:edi+0x06],ecx           ;登记程序加载基址
    mov edi,ecx                     ;es:edi(程序装载地址)
    mov ecx,eax
    cld
    rep movsb
    
    mov esi,[ebp+4*11]              ;tcb基址
    mov edi,[es:esi+0x06]           ;程序起始线性地址

    ;建立程序头部段描述符
    mov eax,edi                     ;基址
    mov ebx,[es:edi+0x04]
    dec ebx                         ;界限   0x00000327
    mov ecx,0x0040f200              ;属性：字节粒度数据段，特权3
    call sel_sys_routine:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b      ;设置选择子特权级3
    mov [es:esi+0x44],cx            ;登记程序头部段选择子
    mov [es:edi+0x04],cx            ;00000_111b

    ;建立程序代码段描述符
    mov eax,edi
    add eax,[es:edi+0x14]
    mov ebx,[es:edi+0x18]
    dec ebx                   
    mov ecx,0x0040f800              ;属性：字节粒度代码段，特权3
    call sel_sys_routine:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov [es:edi+0x14],cx            ;00001_111b

    ;建立程序数据段描述符
    mov eax,edi
    add eax,[es:edi+0x1c]  
    mov ebx,[es:edi+0x20]     
    dec ebx                
    mov ecx,0x0040f200              ;属性：字节粒度数据段，特权3
    call sel_sys_routine:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov [es:edi+0x1c],cx            ;00010_111b

    ;建立程序堆栈段描述符
    mov ecx,[es:edi+0x0c]           ;大小(4KB)
    mov ebx,0x000fffff
    sub ebx,ecx                     ;界限
    mov eax,4096                        
    mul ecx                       
    mov ecx,eax
    call sel_sys_routine:allocate_memory
    add eax,ecx                     ;基址 
    mov ecx,0x00c0f600              ;属性：4KB粒度堆栈段，特权3
    call sel_sys_routine:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov [es:edi+0x08],cx            ;00011_111b

    ;重定位salt
    add edi,0x28                    ;es:edi(user_salt)
    mov esi,salt                    ;ds:esi(core_salt)
    cld

    mov ecx,[es:edi-4]              ;user_salt_items
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

    ;创建0特权级堆栈
    mov ecx,4096                    ;大小
    mov eax,ecx                     ;为生成堆栈高端地址做准备 
    mov [es:esi+0x1a],ecx
    shr dword [es:esi+0x1a],12      ;登记大小(4KB)
    call sel_sys_routine:allocate_memory
    add eax,ecx                     ;基址(高端地址)
    mov [es:esi+0x1e],eax           ;登记基址
    mov ebx,0xffffe                 ;界限
    mov ecx,0x00c09600              ;4KB粒度，读写，特权级0
    call sel_sys_routine:make_seg
    mov ebx,esi 
    call LDT_add
    or cx,0000_0000_0000_0000b      ;设置选择子的特权级为0
    mov [es:esi+0x22],cx            ;登记选择子
    mov dword [es:esi+0x24],0       ;登记初始esp

    ;创建1特权级堆栈
    mov ecx,4096
    mov eax,ecx              
    mov [es:esi+0x28],ecx
    shr dword [es:esi+0x28],12
    call sel_sys_routine:allocate_memory
    add eax,ecx                   
    mov [es:esi+0x2c],eax  
    mov ebx,0xffffe            
    mov ecx,0x00c0b600              ;4KB粒度，读写，特权级1
    call sel_sys_routine:make_seg
    mov ebx,esi              
    call LDT_add
    or cx,0000_0000_0000_0001b      ;设置选择子的特权级为1
    mov [es:esi+0x30],cx          
    mov dword [es:esi+0x32],0

    ;创建2特权级堆栈
    mov ecx,4096
    mov eax,ecx             
    mov [es:esi+0x36],ecx
    shr dword [es:esi+0x36],12 
    call sel_sys_routine:allocate_memory
    add eax,ecx               
    mov [es:esi+0x3a],ecx      
    mov ebx,0xffffe     
    mov ecx,0x00c0d600              ;4KB粒度，读写，特权级2
    call sel_sys_routine:make_seg
    mov ebx,esi                
    call LDT_add
    or cx,0000_0000_0000_0010b      ;设置选择子的特权级为2
    mov [es:esi+0x3e],cx        
    mov dword [es:esi+0x40],0

    ;在GDT中创建LDT描述符
    mov eax,[es:esi+0x0c]           ;LDT段基址
    movzx ebx,word [es:esi+0x0a]    ;LDT段界限
    mov ecx,0x00408200              ;LDT段属性，特权级0，系统段
    call sel_sys_routine:make_seg
    call sel_sys_routine:GDT_add
    mov [es:esi+0x10],cx            ;登记LDT选择子到TCB

    ;创建用户程序TSS
    mov ecx,104                     ;TSS基本大小
    mov [es:esi+0x12],cx              
    dec word [es:esi+0x12]          ;登记TSS界限到TCB
    call sel_sys_routine:allocate_memory
    mov [es:esi+0x14],ecx           ;登记TSS基址到TCB

    ;登记TSS基本表格内容
    mov word [es:ecx+0],0           ;反向链=0
    mov edx,[es:esi+0x24]
    mov [es:ecx+4],edx              ;esp0
    mov dx,[es:esi+0x22]       
    mov [es:ecx+8],dx               ;ss0
    mov edx,[es:esi+0x32]    
    mov [es:ecx+12],edx             ;esp1
    mov dx,[es:esi+0x30]      
    mov [es:ecx+16],dx              ;ss1
    mov edx,[es:esi+0x40]  
    mov [es:ecx+20],edx             ;esp2
    mov dx,[es:esi+0x3e]
    mov [es:ecx+24],dx              ;ss2
    mov dx,[es:esi+0x10]    
    mov [es:ecx+96],dx              ;LDT selector
    mov dx,[es:esi+0x12]
    mov [es:ecx+102],dx             ;I/O位图偏移=TSS界限
    mov word [es:ecx+100],0         ;T
    mov dword [es:ecx+28],0         ;CR3(PDBR)

    ;访问用户程序头部，继续填充TSS
    mov edi,[es:esi+0x06]           ;用户程序加载基址
    mov edx,[es:edi+0x10] 
    mov [es:ecx+32],edx             ;eip
    mov dx,[es:edi+0x14]     
    mov [es:ecx+76],dx              ;cs
    mov dx,[es:edi+0x08]
    mov [es:ecx+80],dx              ;ss
    mov dx,[es:edi+0x04]         
    mov word [es:ecx+84],dx         ;ds，指向程序头部段
    mov word [es:ecx+72],0          ;es
    mov word [es:ecx+88],0          ;fs
    mov word [es:ecx+92],0          ;gs
    pushfd
    pop edx
    mov dword [es:ecx+36],edx       ;eflags

    ;在GDT中创建TSS描述符
    mov eax,[es:esi+0x14]           ;TSS基址
    movzx ebx,word [es:esi+0x12]    ;段界限
    mov ecx,0x00408900              ;TSS描述符，特权级0，系统段
    call sel_sys_routine:make_seg
    call sel_sys_routine:GDT_add
    mov [es:esi+0x18],cx            ;登记TSS选择子到TCB

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

    mov ebx,msg_1
    call sel_sys_routine:show_string

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
    mov ecx,104                     ;无其他特权级堆栈，0特级不会低向转移
    call sel_sys_routine:allocate_memory
    mov [tss_pm+0x00],ecx           ;tss_pm基址
    mov word [es:ecx+0x60],0        ;无LDT
    mov word [es:ecx+0x66],103      ;无I/O位图，0特权级不需要
    mov word [es:ecx+0x00],0        ;反向链=0
    mov dword [es:ecx+0x1c],0       ;CR3(PDBR)
    mov word [es:ecx+0x64],0        ;T=0

    ;创建TSS描述符，并安装到GDT中 
    mov eax,ecx                     ;tss_pm基址
    mov ebx,103                     ;界限
    mov ecx,0x00408900              ;TSS描述符，特权级0
    call sel_sys_routine:make_seg
    call sel_sys_routine:GDT_add
    mov [tss_pm+0x04],cx            ;保存tss_pm描述符选择子 

    ltr cx                          ;TR任务存在标志，指定当前任务

    mov ebx,pm_msg1                 ;任务管理器运行中
    call sel_sys_routine:show_string

    ;创建任务控制块，非处理器要求
    mov ecx,0x46
    call sel_sys_routine:allocate_memory
    call tcb_append

    ;使用栈传递过程参数
    push dword user_program         ;用户程序位置
    push ecx                        ;任务控制块地址
    call load_relocate_program

    ;执行任务切换
    call far [es:ecx+0x14]          ;dd(tss基址)dw(tss选择子)

    ;重新加载并切换任务
    mov ebx,pm_msg2
    call sel_sys_routine:show_string

    mov ecx,0x46
    call sel_sys_routine:allocate_memory
    call tcb_append
    push dword user_program         ;用户程序位置
    push ecx                        ;任务控制块地址
    call load_relocate_program

    jmp far [es:ecx+0x14]

    mov ebx,pm_msg3
    call sel_sys_routine:show_string

    hlt

section tail align=0x200
;core_end
