;目的是中断门

[org 0x7c00]
[bits 16]
		;定义全局描述符的常量又不占用内存空间
		 gdt_basic        equ 0x00007e00 
        ;#1 数据段                4G
		 data_basic      equ 0x0000000
        ;#2 当前的程序代码段      512
 		 code_basic      equ 0x00007c00
		;#3 全局堆栈基地址        4kb
		 stack_basic     equ 0x00007c00
		;#4 显示描述基地址  
         show_basic      equ 0x000B8000	
		;$1 中断向量表安装的位置
		 interrupt_basic  equ 0x00008000 ;这样高四位0好算 256*8=2^11+00009000
		 
        mov ax,cs
		mov ds,ax
		
		call show_style                    ;设置显示模式 主要是清屏
		
		;计算GDT所在的逻辑段地址 
         mov eax,gdt_basic                 ;得到描述符的基地址  
         xor edx,edx
		 mov ebx,16
         div ebx            
         mov ds,eax                         ;令DS指向该段以进行操作
         mov ebx,edx                        ;段内起始偏移地址 
         
         ;创建0#描述符，它是空描述符，这是处理器的要求
		 
        ;#1创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间
         mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
         mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

         ;#2创建保护模式下初始代码段描述符
         mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，界限0x1FF 
         mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 
         
		 
         ;#3建立保护模式下的堆栈段描述符      ;基地址为0x00007C00，界限0xFFFFE 
         mov dword [ebx+0x18],0x7c00fffe     ;粒度为4KB 
         mov dword [ebx+0x1c],0x00cf9600
         
         ;#4建立保护模式下的显示缓冲区描述符   
         mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
         mov dword [ebx+0x24],0x0040920b    ;粒度为字节
		 
		 ;===============================================================		 
		 
         ;初始化描述符表寄存器GDTR
		 ;因为上面吧数据段地址改了所以这利用代码段
         mov word [cs:pgdt], 39 ;描述符表的界限（总字节数减一） n*8-1;            
         lgdt [cs:pgdt]

		 
         in al,0x92                         ;南桥芯片内的端口 
         or al,0000_0010B
         out 0x92,al                        ;打开A20

         cli                                ;保护模式下中断机制尚未建立，应 
                                            ;禁止中断 
         mov eax,cr0
         or eax,1
         mov cr0,eax                        ;设置PE位
         ;以下进入保护模式... ...
         jmp dword 0x0010:protect_loader-0x7C00;16位的描述符选择子：32位偏移
		 
		 ;hlt                    ;程序终止
;===================showStyle=============================
show_style:                   ;设置显示方式
 	mov ah,0x00
	mov al,0x03
	int 10h
    ret	
;=========================================================
[bits 32]
        protect_loader:
		               mov eax,0x0018
					   mov ss,eax
					   xor esp,esp			   
		cli			   
					   	 ;$1硬件中断 依据代码段#2
		 mov eax,0x0008
		 mov ds,eax       ;4G
	
         mov eax,0x0010                    ;代码段描述子
		 shl eax,16
		 mov ebx,interrupt_show            ;中断实现的偏移量
		 sub ebx,0x7c00                    ;因为知道高16位肯定为0
		 and ebx,0x0000FFFF
		 or eax,ebx
		 
		 mov ebx,interrupt_basic            ;中断描述符的地方
		 xor esi,esi
		 mov ecx,256
		 
	.loop_idt: 
		 mov dword [ebx+esi+0x00],eax 
         mov dword [ebx+esi+0x04],0x00008E00    ; 
		 add esi,8
		 loop .loop_idt
		 
		 ;重新初始化时钟中断0x70
		 mov eax,0x0010                    ;代码段描述子
		 shl eax,16
		 mov ebx,time_interrupt            ;中断实现的偏移量
		 sub ebx,0x7c00    
         and ebx,0x0000FFFF
		 or eax,ebx
		 mov ebx,interrupt_basic 
		 mov dword[ebx+0x20*8],eax
		 mov dword[ebx+0x20*8+4],0x00008E00  
		 
		 lidt [ds:interrupt_des]	
         
         call    Init8259A  		 
      
		 sti
		 .loop:
		        jmp .loop;  
						
;----------------------------------------------------------------						
 interrupt_show:
                      pushad
					   xor eax,eax
					   mov eax,0x0020           ;#4显示段的选择子
					   mov es,eax               
					   mov eax,0x0008           ;#1数据段选择子
					   mov ds,eax
					   
					   xor ebx,ebx
					   xor edx,edx
					   mov word bx,[ds:show_position]
					   mov word dx,[ds:show_position+2] ;这个是初始值0-白色 1-黄色的话变色 
					  
					   cmp dx,0
					   jg .show_blue
					   
					.show_white:                    ;0
					   mov byte [es:ebx],'O'
					   mov byte [es:ebx+1],0x07
					   inc dx
					   jmp .show_end
					.show_blue:
					   mov byte [es:ebx],'S'
                       mov byte [es:ebx+1],0x0e
                       dec dx					   
					.show_end:                      ;1
					   mov word [ds:show_position+2],dx
					   add bx,2
					   call show_index
					   mov word [ds:show_position],bx
                         popad
                       iretd
;------------------------------------------------------------------					   
show_index:
             cmp bx,80*2*25
			 jle .init1 
		     sub bx,80*2*25
	 .init1:   
             ret	
; IR0中断-----------0x70-----------------------------------------------------------			 
time_interrupt:
              pushad
			  
			  mov al,0x20                      ;中断结束命令EOI
              out 0xa0,al                        ;向8259A从片发送
              out 0x20,al                        ;向8259A主片发送
			  
			  
			  ;暂且随便调用一个中断
			  int 10h
				
			  popad
			  iretd
; Init8259A ---------------------------------------------------------------------------------------------  
Init8259A:  
            pushad
			     ;设置8253计数器
			MOV AL,36H
            OUT 43H,AL ;送控制字到8253的控制寄存器
			mov ax,0xff01
            OUT 40h,al ;送时间常数到2号通道
            out 40h,al
			
		        ;设置8259A中断控制器
            mov	al, 011h
	        out	020h, al	; 主8259, ICW1.

	        out	0A0h, al	; 从8259, ICW1.

	        mov	al, 020h	; IRQ0 对应中断向量 0x20
	        out	021h, al	; 主8259, ICW2.
	       
	        mov	al, 028h	; IRQ8 对应中断向量 0x28
	        out	0A1h, al	; 从8259, ICW2.
	       
	        mov	al, 004h	; IR2 对应从8259
	        out	021h, al	; 主8259, ICW3.
	        

	        mov	al, 002h	; 对应主8259的 IR2
	        out	0A1h, al	; 从8259, ICW3.
	        
	        mov	al, 001h
	        out	021h, al	; 主8259, ICW4.
	     
	        out	0A1h, al	; 从8259, ICW4.
	       
	        mov	al, 11111110b	; 仅仅开启定时器中断
	        ;mov	al, 11111111b	; 屏蔽主8259所有中断
	        out	021h, al	; 主8259, OCW1.
	        
	        mov	al, 11111111b	; 屏蔽从8259所有中断
	        out	0A1h, al	; 从8259, OCW1.

         ;设置和时钟中断相关的硬件 
		   
	       popad
    ret

;--------------数据段--------------------------------------------
        show_position  dw 0                 ;80*25=2000 2^16=	
		               dw 0
		
        pgdt           dw 0
	                   dd gdt_basic             ;GDT的物理地?
					   
		interrupt_des  dw 256*8-1               ;idt
                       dd interrupt_basic
				   
	         times 510-($-$$) db 0 
                   db 0x55 ;引导识别标示
                   db 0xaa	