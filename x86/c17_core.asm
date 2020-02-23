; x86 Assembly
; TAB=4

	org 0x100
section install
    mov ax,cs
    mov es,ax

    mov ebx,section.core.start
    sub [cs:bx+0x00],ebx

    mov ax,[cs:bx+0x00]
    mov dx,[cs:bx+0x02]
    add ax,511
    mov bx,512
    div bx

    mov cx,ax
    mov ax,1
    mov bx,section.core.start
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

;-------------------------------------------------------------------------------
define:
    sel_code_4gb    equ 0x08
    sel_data_4gb    equ 0x10

    %macro alloc_core_linear 0
        mov ebx,[core_tcb+0x06]
        add dword [core_tcb+0x06],0x1000
        call sel_code_4gb:allocate_a_page
    %endmacro

    %macro alloc_user_linear 0
        mov ebx,[esi+0x06]
        add dword [esi+0x06],0x1000
        call sel_code_4gb:allocate_a_page
    %endmacro

section core align=0x200 vstart=0x80040000
    core_lenth      dd section.tail.start
    core_entry      dd entry

    [bits 32]
show_string:            ;显示以0终止的字符串并移动光标
                        ;输入：ebx(串地址)
    push ebx
    push ecx
    cli
    getc:
        mov cl,[ebx]
        or cl,cl
        jz exit
        mov ch,0x12
        call show_char
        inc ebx
        jmp getc
    
    exit:
    sti
    pop ecx
    pop ebx
    retf

 show_char:         ;显示一个字符并推进光标，仅段内调用
                    ;输入：cl(字符ASCII码)，ch(颜色属性)
    pushad

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
    and ebx,0x0000ffff  ;准备使用32位寻址方式访问显存 

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
    mov [0x800b8000+ebx],cx
    shr bx,1
    inc bx

    roll_screen:
    cmp bx,2000     ;光标超出屏幕？滚屏
    jl set_cursor

    mov esi,0x800b80a0
    mov edi,0x800b8000
    cld
    mov ecx,1920
    rep movsw

    push bx
    mov bx,3840     ;清除屏幕最底一行
    mov ecx,80
    cls:
        mov word [0x800b8000+ebx],0x0720
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

    popad
    ret

show_hex_dword:         ;以十六进制显示双字并推进光标，调试用
                        ;输入：edx(待显示双字)
    pushad
    cli
    mov ebx,bin_hex     ;指向核心数据段内的转换表
    mov ecx,8
    .xlt:    
        rol edx,4
        mov eax,edx
        and eax,0x0000000f
        xlat            ;Translate
      
        push ecx
        mov cl,al
        mov ch,0x42
        call show_char
        pop ecx
        loop .xlt
    sti
    popad
    retf

allocate_a_page:        ;分配并安装一个页
                        ;输入：ebx(页的线性地址)
    push eax
    push ebx
    push esi

    ;检查该线性地址对应页表是否存在
    mov esi,ebx
    and esi,0xffc00000
    shr esi,20                      ;得到页目录索引，并乘以4 
    or esi,0xfffff000               ;页目录自身的线性地址+表内偏移 
    test dword [esi],0x00000001     ;P位是否为1
    jnz .present                    
          
    ;若无对应页表，则创建 
    call allocate_4KB               ;分配一个页做为页表 
    or eax,0x00000007
    mov [esi],eax                   ;在页目录中登记该页表
          
    .present:
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
         
    xor eax,eax
    ap1:
        bts [page_bit_map],eax
        jnc ap2
        inc eax
        cmp eax,page_map_len*8
        jl ap1
         
        mov ebx,msg_3
        call sel_code_4gb:show_string
        hlt             ;没有可以分配的页，停机 
         
    ap2:
    shl eax,12          ;乘以0x1000 

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
         
    call allocate_4KB          
    mov ebx,eax
    or ebx,0x00000007
    mov [0xfffffff8],ebx    ;新页目录表登记到倒数第二目录项

    invlpg [0xfffffff8]
         
    mov esi,0xfffff000      ;ds:esi(当前页目录线性地址)
    mov edi,0xffffe000      ;es:esi(新页目录的线性地址)
    mov ecx,1024            ;目录项数
    cld
    repe movsd 
       
    pop edi
    pop esi 
    pop ecx
    pop ebx
    retf

general_exception_handler:  ;通用的异常处理过程
    mov ebx,excep_msg
    call sel_code_4gb:show_string
    cli
    hlt

general_interrupt_handler:  ;通用的中断处理过程
    push eax
          
    mov al,0x20             ;中断结束命令EOI 
    out 0xa0,al             ;向从片发送 
    out 0x20,al             ;向主片发送
         
    pop eax  
    iretd

rtm0x70_interrupt_handler:  ;实时时钟中断处理过程
    pushad

    mov al,0x20                         ;中断结束命令EOI
    out 0xa0,al                         ;向8259A从片发送
    out 0x20,al                         ;向8259A主片发送

    mov al,0x0c                         ;寄存器C的索引。且开放NMI
    out 0x70,al
    in al,0x71                          ;读一下RTC的寄存器C，否则只发生一次中断

    ;找当前任务（状态为忙的任务）在链表中的位置
    mov eax,tcb_chain                  
    .b0:                                ;EAX=链表头或当前TCB线性地址
        mov ebx,[eax]                   ;EBX=下一个TCB线性地址
        or ebx,ebx
        jz .irtn                        ;链表为空，或已到末尾，从中断返回
        cmp word [ebx+0x04],0xffff      ;是忙任务（当前任务）？
        je .b1
        mov eax,ebx                     ;定位到下一个TCB（的线性地址）
        jmp .b0         

    ;将当前为忙的任务移到链尾
    .b1:
    mov ecx,[ebx]                       ;下游TCB的线性地址
    mov [eax],ecx                       ;将当前任务从链中拆除
    .b2:                                ;此时，EBX=当前任务的线性地址
        mov edx,[eax]
        or edx,edx                      ;已到链表尾端？
        jz .b3
        mov eax,edx
        jmp .b2

    .b3:
    mov [eax],ebx                       ;将忙任务的TCB挂在链表尾端
    mov dword [ebx],0x00000000          ;将忙任务的TCB标记为链尾

    ;从链首搜索第一个空闲任务
    mov eax,tcb_chain
    .b4:
        mov eax,[eax]
        or eax,eax                      ;已到链尾（未发现空闲任务）
        jz .irtn                        ;未发现空闲任务，从中断返回
        cmp word [eax+0x04],0x0000      ;是空闲任务？
        jnz .b4

    ;将空闲任务和当前任务的状态都取反
    not word [eax+0x04]                 ;设置空闲任务的状态为忙
    not word [ebx+0x04]                 ;设置当前任务（忙）的状态为空闲
    jmp far [eax+0x14]                  ;任务转换

    .irtn:
    popad
    iretd

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

    pop edx
    pop ebx
    pop eax
    retf 

terminate_task:         ;终止当前任务
    pushfd
    pop edx

    test dx,0100_0000_0000_0000b        ;测试NT位
    jnz tt_ret                          ;当前任务是嵌套的，到.b1执行iretd 
    jmp far [tss_pm]                    ;程序管理器任务 
    tt_ret:
    iretd

;-------------------------------------------------------------------------------
;core_data
    GDTR            dw 0
                    dd 0
    IDTR            dw 0
                    dd 0x8001f000
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
                    dw sel_code_4gb

        salt_2      db '@ReadDiskData'
                    times 256-($-salt_2) db 0
                    dd 0
                    dw sel_code_4gb

        salt_3      db '@PrintDwordAsHexString'
                    times 256-($-salt_3) db 0
                    dd show_hex_dword
                    dw sel_code_4gb

        salt_4      db '@TerminateProgram'
                    times 256-($-salt_4) db 0
                    dd terminate_task
                    dw sel_code_4gb

        salt_item_len   equ $-salt_4
        salt_items      equ ($-salt)/salt_item_len
    
    msg_0           db '  Working in system core with protection '
                    db 'and paging are all enabled.System core is mapped '
                    db 'to address 0x80000000.',0x0d,0x0a,0
    msg_1           db '  System wide CALL-GATE mounted.',0x0d,0x0a,0
    msg_3           db '********No more pages********',0
    msg_4           db 0x0d,0x0a,'  Task switching...@_@',0x0d,0x0a,0
    msg_5           db 0x0d,0x0a,'  Processor HALT.',0
    excep_msg       db '********Exception encounted********',0x0d,0x0a,0
    core_msg0       db '  System core task running!',0x0d,0x0a,0

    bin_hex         db '0123456789abcdef'   ;show_hex_dword 查找表

    cpu_brnd0       db 0x0d,0x0a,'  ',0
    cpu_brand       times 52 db 0
    cpu_brnd1       db 0x0d,0x0a,0x0d,0x0a,0

    tcb_chain       dd 0                    ;任务控制块链地址
    core_tcb        times  32  db 0         ;内核（程序管理器）的TCB

    ;内核信息
    core_next_laddr dd 0x80100000           ;内核空间中下一个可分配地址
    tss_pm          dd 0                    ;程序管理器TSS基址
                    dw 0                    ;程序管理器TSS描述符选择子 
;-------------------------------------------------------------------------------
    align 16
user_program1:
    .len            dd .end - user_program1     ;0x00
    .entry          dd .code - user_program1    ;0x04
    .salt_pos       dd .salt - user_program1    ;0x08
    .salt_items     dd (.data - .salt)/256      ;0x0c
    .salt:                                      
        .PrintString            db  '@PrintString'
                                times 256-($-.PrintString) db 0      
        .TerminateProgram       db  '@TerminateProgram'
                                times 256-($-.TerminateProgram) db 0  
        .PrintDwordAsHexString  db  '@PrintDwordAsHexString'
                                times 256-($-.PrintDwordAsHexString) db 0

    .data:
        .msg0       db '  User task A->;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'
                    db 0x0d,0x0a,0

    .code:
        mov ebx,.msg0 - user_program1
        call far [.PrintString - user_program1]
        jmp .code
     
        call far [.TerminateProgram - user_program1]    ;将控制权返回到系统 
    .end:
        times 0x1000 db 0
;-------------------------------------------------------------------------------
user_program2:
    .len            dd .end - user_program2     ;0x00
    .entry          dd .code - user_program2    ;0x04
    .salt_pos       dd .salt - user_program2    ;0x08
    .salt_items     dd (.data - .salt)/256      ;0x0c
    .salt:                                      
        .PrintString            db  '@PrintString'
                                times 256-($-.PrintString) db 0      
        .TerminateProgram       db  '@TerminateProgram'
                                times 256-($-.TerminateProgram) db 0  
        .PrintDwordAsHexString  db  '@PrintDwordAsHexString'
                                times 256-($-.PrintDwordAsHexString) db 0

    .data:
        .msg0       db '  User task B->;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'
                    db 0x0d,0x0a,0

    .code:
        mov ebx,.msg0 - user_program2
        call far [.PrintString - user_program2]
        jmp .code
     
        call far [.TerminateProgram - user_program2]    ;将控制权返回到系统 
    .end:
        times 0x1000 db 0
;-------------------------------------------------------------------------------
LDT_add:                    ;在LDT内安装一个新的描述符
                            ;输入：edx:eax(描述符)，ebx(tcb基址)
                            ;输出：cx(描述符选择子)
    push eax
    push edx
    push edi

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

    pop edi
    pop edx
    pop eax
    ret

load_relocate_program:      ;加载并重定位用户程序
                            ;输入：push(程序位置)
                            ;     push(tcb基址)
    pushad

    mov ebp,esp

    ;清空当前页目录的前半部分（对应低2GB的局部地址空间） 
    mov ebx,0xfffff000
    xor esi,esi
    mov ecx,512
    .l0:
        mov dword [ebx+esi*4],0x00000000
        inc esi
        loop .l0

    mov eax,cr3
    mov cr3,eax                     ;刷新TLB 

    mov esi,[ebp+4*10]              ;ds:esi(程序位置)

    ;程序尺寸4KB对其
    mov eax,[esi]
    mov ebx,eax
    and ebx,0xfffff000
    add ebx,0x1000
    test eax,0x00000fff
    cmovnz eax,ebx

    mov ecx,eax
    shr ecx,12                      ;程序占用4KB页数
    mov edx,[ebp+4*9]               ;TCB基址
    l1:
        mov ebx,[edx+0x06]
        add dword [edx+0x06],0x1000
        call sel_code_4gb:allocate_a_page
        mov edi,ebx                 ;es:edi(程序装载地址)
        push ecx
        mov ecx,1024
        cld
        rep movsd
        pop ecx
        loop l1
    
    mov esi,[ebp+4*9]              ;tcb基址

    ;在内核地址空间内创建用户任务的TSS
    alloc_core_linear
         
    mov [es:esi+0x14],ebx           ;在TCB中填写TSS的线性地址 
    mov word [es:esi+0x12],103      ;在TCB中填写TSS的界限值 

    ;在用户任务的局部地址空间内创建LDT 
    alloc_user_linear
    mov [es:esi+0x0c],ebx           ;填写LDT线性地址到TCB中 

    ;建立程序代码段描述符
    mov eax,0x00000000
    mov ebx,0x000fffff               
    mov ecx,0x00c0f800              ;4KB粒度代码段，特权3
    call sel_code_4gb:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+76],cx              ;填写TSS的CS域 

    ;建立程序数据段描述符
    mov eax,0x00000000
    mov ebx,0x000fffff                
    mov ecx,0x00c0f200              ;4KB粒度数据段，特权3
    call sel_code_4gb:make_seg
    mov ebx,esi
    call LDT_add
    or cx,0000_0000_0000_0011b
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+84],cx              ;填写TSS的DS域 
    mov [es:ebx+72],cx              ;填写TSS的ES域
    mov [es:ebx+88],cx              ;填写TSS的FS域
    mov [es:ebx+92],cx              ;填写TSS的GS域

    ;将数据段作为用户任务的3特权级固有堆栈 
    alloc_user_linear
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+80],cx              ;填写TSS的SS域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址 
    mov [es:ebx+56],edx             ;填写TSS的ESP域 

    ;在用户任务的局部地址空间内创建0特权级堆栈
    alloc_user_linear
    mov eax,0x00000000
    mov ebx,0x000fffff
    mov ecx,0x00c09200              ;4KB粒度的堆栈段描述符，特权级0
    call sel_code_4gb:make_seg
    mov ebx,esi                     ;TCB的基地址
    call LDT_add
    or cx,0000_0000_0000_0000b      ;设置选择子的特权级为0

    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+8],cx               ;填写TSS的SS0域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址
    mov [es:ebx+4],edx              ;填写TSS的ESP0域 

    ;在用户任务的局部地址空间内创建1特权级堆栈
    alloc_user_linear
    mov eax,0x00000000
    mov ebx,0x000fffff
    mov ecx,0x00c0b200              ;4KB粒度的堆栈段描述符，特权级1
    call sel_code_4gb:make_seg
    mov ebx,esi                     ;TCB的基地址
    call LDT_add
    or cx,0000_0000_0000_0001b      ;设置选择子的特权级为1

    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov [es:ebx+16],cx              ;填写TSS的SS1域
    mov edx,[es:esi+0x06]           ;堆栈的高端线性地址
    mov [es:ebx+12],edx             ;填写TSS的ESP1域 

    ;在用户任务的局部地址空间内创建2特权级堆栈
    alloc_user_linear
    mov eax,0x00000000
    mov ebx,0x000fffff
    mov ecx,0x00c0d200              ;4KB粒度的堆栈段描述符，特权级2
    call sel_code_4gb:make_seg
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

    mov esi,[ebp+4*9]              ;tcb基址

    ;在GDT中创建LDT描述符
    mov eax,[es:esi+0x0c]           ;LDT段基址
    movzx ebx,word [es:esi+0x0a]    ;LDT段界限
    mov ecx,0x00408200              ;LDT段属性，特权级0，系统段
    call sel_code_4gb:make_seg
    call sel_code_4gb:GDT_add
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
    call sel_code_4gb:make_seg
    call sel_code_4gb:GDT_add
    mov [es:esi+0x18],cx            ;登记TSS选择子到TCB

    ;创建用户任务的页目录
    call sel_code_4gb:copy_pdir
    mov ebx,[es:esi+0x14]           ;从TCB中获取TSS的线性地址
    mov dword [es:ebx+28],eax       ;填写TSS的CR3(PDBR)域

    popad
    ret 8

tcb_append:                 ;在tcb链上追加任务控制块
                            ;输入：ecx(tcb线性基址)
    push eax
    push edx
                                       
    mov eax,tcb_chain       
    .last:
        mov ebx,[eax]
        or ebx,ebx
        jz .empty
        mov eax,ebx             
        jmp .last
         
    .empty:
    cli
    mov [eax],ecx  
    mov dword [ecx],0x00000000
    sti
         
    pop edx
    pop eax   
    ret

entry:                      ;内核入口
    ;创建中断描述符表IDT
    ;在此之前，禁止调用show_string过程，以及任何含有sti指令的过程。
    
    ;安装前20个异常中断处理过程，处理器异常
    mov eax,general_exception_handler   ;门代码在段内偏移地址
    mov bx,sel_code_4gb                 ;门代码所在段的选择子
    mov cx,0x8e00                       ;32位中断门，0特权级
    call sel_code_4gb:make_gate
    mov ebx,[IDTR+2]                    ;中断描述符表的线性地址
    xor esi,esi
    .idt_20:
        mov [ebx+esi*8],eax
        mov [ebx+esi*8+4],edx
        inc esi
        cmp esi,20        
        jl .idt_20

    ;其余为普通的中断处理过程，保留或硬件使用
    mov eax,general_interrupt_handler  
    mov bx,sel_code_4gb      
    mov cx,0x8e00                    
    call sel_code_4gb:make_gate
    mov ebx,[IDTR+2]     
    .idt_256:
        mov [ebx+esi*8],eax
        mov [ebx+esi*8+4],edx
        inc esi
        cmp esi,256      
        jl .idt_256

    ;设置实时时钟中断处理过程
    mov eax,rtm0x70_interrupt_handler   ;门代码在段内偏移地址
    mov bx,sel_code_4gb                 ;门代码所在段的选择子
    mov cx,0x8e00                       ;32位中断门，0特权级
    call sel_code_4gb:make_gate
    mov ebx,[IDTR+2]
    mov [ebx+0x70*8],eax
    mov [ebx+0x70*8+4],edx

    ;准备开放中断
    mov word [IDTR],256*8-1             ;IDT的界限
    lidt [IDTR]                         ;加载中断描述符表寄存器IDTR

    ;设置8259A中断控制器
    mov al,0x11
    out 0x20,al                         ;ICW1：边沿触发/级联方式
    mov al,0x20
    out 0x21,al                         ;ICW2:起始中断向量
    mov al,0x04
    out 0x21,al                         ;ICW3:从片级联到IR2
    mov al,0x01
    out 0x21,al                         ;ICW4:非总线缓冲，全嵌套，正常EOI

    mov al,0x11
    out 0xa0,al                         ;ICW1：边沿触发/级联方式
    mov al,0x70
    out 0xa1,al                         ;ICW2:起始中断向量
    mov al,0x04
    out 0xa1,al                         ;ICW3:从片级联到IR2
    mov al,0x01
    out 0xa1,al                         ;ICW4:非总线缓冲，全嵌套，正常EOI

    ;设置和时钟中断相关的硬件 
    mov al,0x0b                         ;RTC寄存器B
    or al,0x80                          ;阻断NMI
    out 0x70,al
    mov al,0x12                         ;设置寄存器B，禁止周期性中断，开放更
    out 0x71,al                         ;新结束后中断，BCD码，24小时制

    in al,0xa1                          ;读8259从片的IMR寄存器
    and al,0xfe                         ;清除bit 0(此位连接RTC)
    out 0xa1,al                         ;写回此寄存器

    mov al,0x0c
    out 0x70,al
    in al,0x71                          ;读RTC寄存器C，复位未决的中断状态

    sti                                 ;开放硬件中断

    mov ebx,msg_0
    call sel_code_4gb:show_string

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
    call sel_code_4gb:show_string
    mov ebx,cpu_brand
    call sel_code_4gb:show_string
    mov ebx,cpu_brnd1
    call sel_code_4gb:show_string

    ;安装系统服务调用门
    mov edi,salt
    mov ecx,salt_items
    .sys_gate:
        push ecx
        mov eax,[edi+256]
        mov bx,[edi+260]
        mov cx,1_11_0_1100_000_00000b
        call sel_code_4gb:make_gate
        call sel_code_4gb:GDT_add
        mov [edi+260],cx
        add edi,salt_item_len
        pop ecx
        loop .sys_gate

    ;调用门测试，双字偏移量被忽略
    mov ebx,msg_1
    call 0x0018:0

    ;初始化创建程序管理器任务的任务控制块TCB
    mov word [core_tcb+0x04],0xffff         ;任务状态：忙碌
    mov dword [core_tcb+0x06],0x80100000    ;内核虚拟空间的分配从这里开始。
    mov word [core_tcb+0x0a],0xffff         ;登记LDT初始的界限到TCB中（未使用）
    mov ecx,core_tcb
    call tcb_append                         ;将此TCB添加到TCB链中

    ;为程序管理器的TSS分配内存空间
    alloc_core_linear                       ;宏：在内核的虚拟地址空间分配内存

    ;在程序管理器的TSS中设置必要的项目 
    mov word [ebx+0],0                      ;反向链=0
    mov eax,cr3
    mov dword [ebx+28],eax                  ;登记CR3(PDBR)
    mov word [ebx+96],0                     ;没有LDT。处理器允许没有LDT的任务。
    mov word [ebx+100],0                    ;T=0
    mov word [ebx+102],103                  ;没有I/O位图。0特权级事实上不需要。
         
    ;创建程序管理器的TSS描述符，并安装到GDT中 
    mov eax,ebx                             ;TSS的起始线性地址
    mov ebx,103                             ;段长度（界限）
    mov ecx,0x00408900                      ;TSS描述符，特权级0
    call sel_code_4gb:make_seg
    call sel_code_4gb:GDT_add
    mov [core_tcb+0x18],cx                  ;登记内核任务的TSS选择子到其TCB

    ltr cx                                  ;现在可认为“程序管理器”任务正执行中

    ;创建用户任务的任务控制块 
    alloc_core_linear                       ;宏：在内核的虚拟地址空间分配内存
    mov word [ebx+0x04],0                   ;任务状态：空闲 
    mov dword [ebx+0x06],0                  ;用户任务局部空间的分配从0开始。
    mov word [ebx+0x0a],0xffff              ;登记LDT初始的界限到TCB中
 
    push dword user_program1                ;用户程序1
    push ebx                                ;任务控制块地址
    call load_relocate_program
    mov ecx,ebx
    call tcb_append

    ;创建用户任务的任务控制块 
    alloc_core_linear                       ;宏：在内核的虚拟地址空间分配内存
    mov word [ebx+0x04],0                   ;任务状态：空闲 
    mov dword [ebx+0x06],0                  ;用户任务局部空间的分配从0开始。
    mov word [ebx+0x0a],0xffff              ;登记LDT初始的界限到TCB中

    push dword user_program2                ;用户程序2
    push ebx                                ;任务控制块地址
    call load_relocate_program
    mov ecx,ebx
    call tcb_append

    .core:
        mov ebx,core_msg0
        call sel_code_4gb:show_string
         
        ;这里可以编写回收已终止任务内存的代码
          
        jmp .core

;-------------------------------------------------------------------------------
section tail align=0x200
;core_end
