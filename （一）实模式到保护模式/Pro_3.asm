;目的是实模式到保护模式的练习
;时间 2013-12-7 凌晨 周六
[org 0x7c00]
[bits 16]
        mov ax,cs
		mov ds,ax
		
		call show_style        ;设置显示模式
		;计算GDT所在的逻辑段地址 
         mov ax,[gdt_base]        ;低16位 
         mov dx,[gdt_base+0x02]   ;高16位 
         mov bx,16        
         div bx            
         mov ds,ax                          ;令DS指向该段以进行操作
         mov bx,dx                          ;段内起始偏移地址 
      
         ;创建0#描述符，它是空描述符，这是处理器的要求
         mov dword [bx+0x00],0x00
         mov dword [bx+0x04],0x00  

         ;创建#1描述符，保护模式下的代码段描述符
		 mov eax,flush
		 shl eax,16
		 or eax,0x000001ff
         mov dword [bx+0x08],eax     
         mov dword [bx+0x0c],0x00409800     

         ;创建#2描述符，保护模式下的数据段描述符（文本模式下的显示缓冲区） 
         mov dword [bx+0x10],0x8000ffff     
         mov dword [bx+0x14],0x0040920b     
         
		 ;创建#3描述符，                     创建数据段；用es来表示大小512=2^9
		 mov dword [bx+0x18],0x7c000200      ;只读
         mov dword [bx+0x1c],0x00409000
		 
         ;初始化描述符表寄存器GDTR
         mov word [cs:gdt_size],31  ;描述符表的界限（总字节数减一）   
          
         lgdt [cs:gdt_size]
      
         in al,0x92                         ;南桥芯片内的端口 
         or al,0000_0010B
         out 0x92,al                        ;打开A20

         cli                                ;保护模式下中断机制尚未建立，应 
                                            ;禁止中断 
         mov eax,cr0
         or eax,1
         mov cr0,eax                        ;设置PE位
      
         ;以下进入保护模式... ...
         jmp dword 0x0008:0             ;16位的描述符选择子：32位偏移
		 
		 ;hlt                    ;程序终止
;===================showStyle=============================
show_style:                   ;设置显示方式
	mov ah,0x00
	mov al,0x03
	int 10h
    ret		
;=======================================================
  [bits 32] 
    flush:
         mov cx,00000000000_10_000B         ;加载数据段选择子(0x10)
         mov ds,cx
         
		 mov cx,00000000000_11_000B         ;加载0x7c00段
		 mov es,cx
		 
		 mov di,0
		 mov si,0
		 xor ecx,ecx
		 mov cx,512
	loop1:	 
		 mov byte dh,[es:si]           ;高位字节dh
		 mov ah,dh                     ;地位字节ah
         
		 shr dh,4
		 cmp dh,10
         jge char1          
    number1:
	     add dh,48
		 jmp cmp2
	char1:
		 add dh,55
		 jmp cmp2
		 
	cmp2:
	     and ah,0x0f
         cmp ah,10
         jge char2		 
	number2:
         add ah,48
		 jmp show
    char2:	 
	     add ah,55
		 jmp show
	show: 
         ;以下在屏幕上显示"Protect mode OK." 
         mov byte [di],dh	
         mov byte [di+2],ah
		 
		 mov byte [di+4],0
		 
		 add di,6
		 add si,1
		 
		loop loop1 

         hlt                                ;已经禁止中断，将不会被唤醒 
		
;--------------数据段--------------------------------------------	
    gdt_size       dw 0
	gdt_base       dd 0x00007e00     ;GDT的物理地?
	fill times 510-($-$$) db 0 
                   db 0x55 ;引导识别标示
                   db 0xaa	