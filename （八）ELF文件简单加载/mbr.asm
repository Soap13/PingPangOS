         ;修改代码
         ;文件说明：硬盘主引导扇区代码 
         ;创建日期：2014-02-01 10:35        ;设置堆栈段和栈指针 
;=================常量的定义============================================         
         core_base_address equ 0x00040000   ;常数，内核加载的起始内存地址 
         core_start_sector equ 0x00000001   ;常数，内核的起始逻辑扇区号 
        
		 page_dir equ 0x00020000
		 page     equ 0x00021000
		;定义全局描述符的常量又不占用内存空间
		 gdt_basic        equ 0x00007e00 
		 ldt_basic        equ 0x00008200
        ;#1 数据段                4G
		 data_basic       equ 0x0000000
        ;#2 当前的程序代码段      512
 		 code_basic       equ 0x00007c00
		;#3 全局堆栈基地址        4kb
		 stack_basic      equ 0x00007c00
		;#4 显示描述基地址  
         show_basic       equ 0x000B8000	
        ;中断代码段
		 interrupt_basic  equ 0x0000A000  
;================常量定义结束==============================================		 
         mov ax,cs      
         mov ss,ax
         mov sp,0x7c00
         ;调整下显示格式
		 call show_style                    ;设置显示模式 主要是清屏
         ;计算GDT所在的逻辑段地址
         mov eax,[cs:pgdt+0x7c00+0x02]      ;GDT的32位物理地址 
         xor edx,edx
         mov ebx,16
         div ebx                            ;分解成16位逻辑地址 

         mov ds,eax                         ;令DS指向该段以进行操作
         mov ebx,edx                        ;段内起始偏移地址 

         ;跳过0#号描述符的槽位 
         ;#1创建描述符，这是一个数据段，     对应0~4GB的线性地址空间
         mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
         mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

         ;#2创建保护模式下初始代码段描述符
         mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，界限0x1FF 
         mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 

         ;#3建立保护模式下的堆栈段描述符      ;基地址为0x00007C00，界限0xFFFFE 
         mov dword [ebx+0x18],0x7c00fffD    ;粒度为4KB 
         mov dword [ebx+0x1c],0x00cf9600
         
         ;#4建立保护模式下的显示缓冲区描述符   
         mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
         mov dword [ebx+0x24],0x0040F20b    ;粒度为字节
         
		 ;#5创建一个全局可执行段
		 mov dword[ebx+0x28],0x0000ffff
		 mov dword[ebx+0x2c],0x00cf9800
		 
         ;#5初始化描述符表寄存器GDTR
         mov word [cs: pgdt+0x7c00],47     ;描述符表的界限   
 
         lgdt [cs: pgdt+0x7c00]
      
         in al,0x92                         ;南桥芯片内的端口 
         or al,0000_0010B
         out 0x92,al                        ;打开A20

         cli                                ;中断机制尚未工作

         mov eax,cr0
         or eax,1
         mov cr0,eax                        ;设置PE位
      
         ;以下进入保护模式... ...
         jmp dword 0x0010:flush             ;16位的描述符选择子：32位偏移
                                            ;清流水线并串行化处理器
;===================showStyle=============================
show_style:                   ;设置显示方式
	mov ah,0x00
	mov al,0x03
	int 10h
    ret	
;=========================================================	
         [bits 32]               
  flush: 
         ;初始化不常用的寄存器防止莫名其妙错误
		 mov ax,cx
         mov gs,ax
         mov fs,ax
         
		 
         mov eax,0x0008                     ;加载数据段(0..4GB)选择子
         mov ds,eax
         mov es,eax         
		 
         mov eax,0x0018                     ;加载堆栈段选择子 
         mov ss,eax
         xor esp,esp                        ;堆栈指针 <- 0 
         
         ;以下加载系统核心程序 
         mov edi,core_base_address          ;加载到内存的位置
         mov eax,core_start_sector          ;选择开始的扇区号
                 
         mov ebx,edi                        ;起始地址 
         call read_hard_disk_0              ;以下读取程序的起始部分（一个扇区） 
         
		 inc eax                            ;这里默认加载了三个扇区
		 call read_hard_disk_0
		 
		 inc eax
		 call read_hard_disk_0
		 ;首先判断是elf的可执行文件
		 ;0x00 四个字节 .elf
		 ;0x10 两个字节 2
		 
		 mov dword edx,[edi]
         cmp edx,0x464C457F ;.elf
         jne .end		 
		 
		 mov word dx,[edi+0x10]
         cmp dx,0x00000002
		 jne .end
		 
		 mov eax,0x0020
         mov es,eax  		
		 
		 ;可以进行接下来的
         mov esi,[edi+0x1c];头偏移量
         add esi,edi       ;内存中的位置
         
		 mov edx,[edi+0x18];入口地址
		 sub edx,[esi+0x08];目的地址
		 add edx,core_base_address;加载地址+偏移地址
		
		 mov eax,0x0020
         mov es,eax 
		 
		 push ss
		 push esp
		 push 0x0028
		 push edx
		 retf
		 hlt
		  
    .end:
        mov eax,0x0020
        mov es,eax          ;显存数据
        mov byte [es:0x00],'E'
        mov byte [es:0x01],0x05 ;红色
  		mov byte [es:0x02],'R'
        mov byte [es:0x03],0x05 ;红色
		mov byte [es:0x04],'R'
        mov byte [es:0x05],0x05 ;红色
		mov byte [es:0x06],'O'
        mov byte [es:0x07],0x05 ;红色
		mov byte [es:0x06],'R'
        mov byte [es:0x07],0x05 ;红色
        hlt; 		 
;-------------------------------------------------------------------------------
read_hard_disk_0:                        ;从硬盘读取一个逻辑扇区
                                         ;EAX=逻辑扇区号
                                         ;DS:EBX=目标缓冲区地址
                                         ;返回：EBX=EBX+512 
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                       ;读取的扇区数

         inc dx                          ;0x1f3
         pop eax
         out dx,al                       ;LBA地址7~0

         inc dx                          ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                       ;LBA地址15~8

         inc dx                          ;0x1f5
         shr eax,cl
         out dx,al                       ;LBA地址23~16

         inc dx                          ;0x1f6
         shr eax,cl
         or al,0xe0                      ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                          ;0x1f7
         mov al,0x20                     ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                      ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                     ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         ret
;-------------------------------------------------------------------------------
         pgdt             dw 0
                          dd gdt_basic      ;GDT的物理地址
;-------------------------------------------------------------------------------                             
         times 510-($-$$) db 0
                          db 0x55,0xaa