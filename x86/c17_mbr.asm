; x86 Assembly
; TAB=4

	org 0x100
section install
    mov ax,cs
    mov es,ax
    mov bx,section.mbr.start

    mov dl,0	;Floppy Disk (A:)
    mov dh,0	;C
    mov ch,0	;H
    mov cl,1	;S
    mov al,1	;n
    mov ah,3	;write
    int 13h

    mov ax,4c00h
    int 21h

section mbr align=16 vstart=0x7c00
	; FAT12 Format Floppy
    jmp entry           ;0xeb,0x4e
    db 0x90             ;0x90
    db "HELLOIPL"       ;IPL名称
    dw 512              ;sector大小（扇区大小固定）
    db 1                ;cluster大小（簇大小固定）
    dw 1                ;FAT起始位置 (第一扇区)
    db 2                ;FAT个数 (固定)
    dw 224              ;根目录大小（一般为224项）
    dw 2880             ;磁盘大小 (扇区数固定)
    db 0xf0             ;磁盘种类 (0xf0固定)
    dw 9                ;FAT长度 (9扇区固定)
    dw 18               ;sector/track 每磁道扇区数 (固定)
    dw 2                ;磁头数 (固定)
    dd 0                ;不使用分区（固定）
    dd 2880             ;重写一次磁盘大小
    db 0,0,0x29         ;意义不明（固定）
    dd 0xffffffff       ;（可能）卷标号码
    db "DOG-OS     "    ;磁盘名称（11B）
    db "FAT12   "       ;磁盘格式名称（8B）
    times 18 db 0		;空闲

entry:
	mov ax,cs
	mov ss,ax
	mov sp,$$

	;Core loading...
	mov ax,[cs:CORE+0x00]
	mov dx,[cs:CORE+0x02]
	mov bx,16
	div bx
	mov es,ax
	mov bx,dx

	mov ax,1
	call read_floppy_disk

	mov ax,[es:bx+0x00]
	mov dx,[es:bx+0x02]
	add ax,0x1ff
	mov cx,0x200
	div cx
	cmp ax,2
	jb next
	mov cx,ax
	dec cx
	mov ax,1
	read_loop:
		inc ax
		mov dx,es
		add dx,0x20
		mov es,dx
		call read_floppy_disk
		loop read_loop
	
	next:
	;Protect mode preparing...
	mov ax,[cs:GDTR+0x02]
	mov dx,[cs:GDTR+0x04]
	mov bx,16
	div bx
	mov ds,ax
	mov bx,dx

	;GDT#0	NULL
	mov dword [bx+0x00],0x00000000
	mov dword [bx+0x04],0x00000000

	;GDT#1	Code(4GB)
	mov dword [bx+0x08],0x0000ffff
	mov dword [bx+0x0c],0x00cf9800

	;GDT#2	Data/Stack(4GB)
	mov dword [bx+0x10],0x0000ffff
	mov dword [bx+0x14],0x00cf9200

	;GDTR
	mov word [cs:GDTR],23
	lgdt [cs:GDTR]

	;A20
	in al,0x92
	or al,0000_0010b
	out 0x92,al

	cli
	;PE into 32
	mov eax,cr0
	or eax,1
	mov cr0,eax

	;flush pipeline
	jmp dword 0x0008:setup

	[bits 32]
setup:
	mov eax,0x0010	;Data/Stack(4GB)
	mov ds,eax
	mov es,eax
	mov fs,eax
	mov gs,eax
	mov ss,eax
	mov esp,$$

	;准备打开分页机制
    mov ebx,0x00020000                  ;内核页目录表PDT基址
    xor esi,esi
    mov ecx,1024                        ;目录项项数目
    p0:
        mov dword [ebx+esi],0x00000000
        add esi,4
        loop p0

    mov dword [ebx+0xffc],0x00020003  	;目录项，指向页目录自身(0xffc00000=0x00020000)
    mov dword [ebx+0x000],0x00021003   	;目录项，指向首页表(0x00000000=0x00000000)
	mov dword [ebx+0x800],0x00021003	;目录项，指向首页表(0x80000000=0x00000000)

    mov ebx,0x00021000                  ;首页表基址
    xor eax,eax                         ;起始页的物理地址 
    xor esi,esi
    p1:       
        mov edx,eax
        or edx,0x00000003                                                      
        mov [ebx+esi*4],edx          	;登记页表项
        add eax,0x1000     
        inc esi
        cmp esi,256                     ;仅低端1MB内存对应页有效 
        jl p1
         
    p2:                                 ;其余的页表项置为无效
        mov dword [ebx+esi*4],0x00000000  
        inc esi
        cmp esi,1024
        jl p2

	;令CR3寄存器指向页目录，并正式开启页功能 
    mov eax,0x00020000                  ;PCD=PWT=0
    mov cr3,eax

    mov eax,cr0
    or eax,0x80000000
    mov cr0,eax                         ;开启分页机制

	or dword [GDTR+2],0x80000000      	;将GDT的线性地址映射到从0x80000000 
    lgdt [GDTR]

	;将堆栈映射到高端，这是非常容易被忽略的一件事
    add esp,0x80000000 

	jmp [0x80040004]

read_floppy_disk:	;从软盘读取一个逻辑扇区
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
	mov ah,2	;read
	pop bx
	int 13h

	pop dx
	pop cx
	pop ax
	ret

GDT_make:		;构造描述符
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

	ret

CORE	dd 0x00040000
GDTR	dw 0x0000
		dd 0x00007e00

times 510-($-$$) db 0
db 0x55,0xaa
