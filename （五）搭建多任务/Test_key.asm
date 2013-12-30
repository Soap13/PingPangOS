         ;创建日期：2012-12-29 核心代码段的修改
;--------------------------------------------------------------------------------
;提供的方法 1.可以显示字符信息         put_char     CL
;           2.可以显示一串信息         put_string   DS:EBX
;			3.可以回车换行的实         put_another_line
;           
;--------------------------------------------------------------------------------
         ;以下常量定义部分。内核的大部分内容都应当固定 
         core_code_seg_sel     equ  0x38    ;#7内核代码段选择子           
         core_data_seg_sel     equ  0x30    ;#6内核数据段选择子 
         sys_routine_seg_sel   equ  0x28    ;#5系统公共例程代码段的选择子 
         video_ram_seg_sel     equ  0x20    ;#4视频显示缓冲区的段选择子
         core_stack_seg_sel    equ  0x18    ;#3内核堆栈段选择子
		 head_staart_seg_sel   equ  0x10    ;#引导的代码段
         mem_0_4_gb_seg_sel    equ  0x08    ;#1整个0-4GB内存的段的选择子
;--------------------------------------------------------------------------------
         ;常用的信息加载地址段可能要修改
		 gdt_basic        equ 0x00007e00    ;全局段基地址
		 interrupt_basic  equ 0x00008000    ;中断加载的位置
;-------------------------------------------------------------------------------
         ;以下是系统核心的头部，用于加载核心程序 
         core_length      dd core_end       ;核心程序总长度#00

         sys_routine_seg  dd section.sys_routine.start
                                            ;系统公用例程段位置#04

         core_data_seg    dd section.core_data.start
                                            ;核心数据段位置#08

         core_code_seg    dd section.core_code.start
                                            ;核心代码段位置#0c


         core_entry       dd start          ;核心代码段入口点#10
                          dw core_code_seg_sel

;===============================================================================
         [bits 32]
;===============================================================================
SECTION sys_routine vstart=0                ;系统公共例程代码段 
;-------------------------------------------------------------------------------
         ;字符串显示例程
put_string:                                 ;显示0终止的字符串并移动光标 
                                            ;输入：DS:EBX=串地址
         push ecx
  .getc:
         mov cl,[ebx]
         or cl,cl
         jz .exit
         call put_char
         inc ebx
         jmp .getc

  .exit:
         pop ecx
         retf                               ;段间返回
;-------------------------------------------------------------------------------		 
put_another_line:                           ;另起一行
        pushad
		mov cl,0x0a
		call put_char
		mov cl,0x0d
		call put_char
		popad
		retf
;-------------------------------------------------------------------------------
put_char:                                   ;在当前光标处显示一个字符,并推进
                                            ;光标。仅用于段内调用 
                                            ;输入：CL=字符ASCII码 
         pushad

         ;以下取当前光标位置
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         inc dx                             ;0x3d5
         in al,dx                           ;高字
         mov ah,al

         dec dx                             ;0x3d4
         mov al,0x0f
         out dx,al
         inc dx                             ;0x3d5
         in al,dx                           ;低字
         mov bx,ax                          ;BX=代表光标位置的16位数

         cmp cl,0x0d                        ;回车符？
         jnz .put_0a
         mov ax,bx
         mov bl,80
         div bl
         mul bl
         mov bx,ax
         jmp .set_cursor

  .put_0a:
         cmp cl,0x0a                        ;换行符？
         jnz .put_other
         add bx,80
         jmp .roll_screen

  .put_other:                               ;正常显示字符
         push es
         mov eax,video_ram_seg_sel          ;0xb8000段的选择子
         mov es,eax
         shl bx,1
         mov [es:bx],cl
         pop es

         ;以下将光标位置推进一个字符
         shr bx,1
         inc bx

  .roll_screen:
         cmp bx,2000                        ;光标超出屏幕？滚屏
         jl .set_cursor

         push ds
         push es
         mov eax,video_ram_seg_sel
         mov ds,eax
         mov es,eax
         cld
         mov esi,0xa0                       ;小心！32位模式下movsb/w/d 
         mov edi,0x00                       ;使用的是esi/edi/ecx 
         mov ecx,1920
         rep movsd
         mov bx,3840                        ;清除屏幕最底一行
         mov ecx,80                         ;32位程序应该使用ECX
  .cls:
         mov word[es:bx],0x0720
         add bx,2
         loop .cls

         pop es
         pop ds

         mov bx,1920

  .set_cursor:
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         inc dx                             ;0x3d5
         mov al,bh
         out dx,al
         dec dx                             ;0x3d4
         mov al,0x0f
         out dx,al
         inc dx                             ;0x3d5
         mov al,bl
         out dx,al

         popad
         ret                                

;-------------------------------------------------------------------------------
read_hard_disk_0:                           ;从硬盘读取一个逻辑扇区
                                            ;EAX=逻辑扇区号
                                            ;DS:EBX=目标缓冲区地址
                                            ;返回：EBX=EBX+512
         push eax 
         push ecx
         push edx
      
         push eax
         
         mov dx,0x1f2
         mov al,1
         out dx,al                          ;读取的扇区数

         inc dx                             ;0x1f3
         pop eax
         out dx,al                          ;LBA地址7~0

         inc dx                             ;0x1f4
         mov cl,8
         shr eax,cl
         out dx,al                          ;LBA地址15~8

         inc dx                             ;0x1f5
         shr eax,cl
         out dx,al                          ;LBA地址23~16

         inc dx                             ;0x1f6
         shr eax,cl
         or al,0xe0                         ;第一硬盘  LBA地址27~24
         out dx,al

         inc dx                             ;0x1f7
         mov al,0x20                        ;读命令
         out dx,al

  .waits:
         in al,dx
         and al,0x88
         cmp al,0x08
         jnz .waits                         ;不忙，且硬盘已准备好数据传输 

         mov ecx,256                        ;总共要读取的字数
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [ebx],ax
         add ebx,2
         loop .readw

         pop edx
         pop ecx
         pop eax
      
         retf                               ;段间返回 

;-------------------------------------------------------------------------------
;汇编语言程序是极难一次成功，而且调试非常困难。这个例程可以提供帮助 
put_hex_dword:                              ;在当前光标处以十六进制形式显示
                                            ;一个双字并推进光标 
                                            ;输入：EDX=要转换并显示的数字
                                            ;输出：无
         pushad
         push ds
      
         mov ax,core_data_seg_sel           ;切换到核心数据段 
         mov ds,ax
      
         mov ebx,bin_hex                    ;指向核心数据段内的转换表
         mov ecx,8
  .xlt:    
         rol edx,4
         mov eax,edx
         and eax,0x0000000f
         xlat
      
         push ecx
         mov cl,al                           
         call put_char
         pop ecx
       
         loop .xlt
      
         pop ds
         popad
         retf
;-------------------------------------------------------------------------------
;处理 中断信息描述
                                            ;edx,偏移地址
                                            ;返回：EDX:EAX=描述符
make_int_description:
                     push edx
                     mov eax,sys_routine_seg_sel
					 shl eax,16
					 and edx,0x0000FFFF
                     or eax,edx             ;得到选择子和偏移地址的低16位
                     pop edx
                     and edx,0xFFFF0000
                     or edx,0x00008E00					 
                     retf					 
;-------------------------------------------------------------------------------
;初始化中断的设置
Init8259A:  
            pushad
			     ;设置8253计数器
			MOV AL,36H
            OUT 43H,AL ;送控制字到8253的控制寄存器
			mov ax,0xff00
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
	       
	        mov	al, 11111101b	; 仅仅开启定时器中断
	        ;mov	al, 11111111b	; 屏蔽主8259所有中断
	        out	021h, al	; 主8259, OCW1.
	        
	        mov	al, 11111111b	; 屏蔽从8259所有中断
	        out	0A1h, al	; 从8259, OCW1.

         ;设置和时钟中断相关的硬件 
	       popad
    retf
;-------------------------------------------------------------------------------
;一般性质的中断显示提示
normal_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,normal_int_message
		        call sys_routine_seg_sel:put_string
                popad
                iret				
;-------------------------------------------------------------------------------
;时钟中断的处理
clock_interrupt:
                pushad
			    mov al,0x20                        ;中断结束命令EOI
                out 0xa0,al                        ;向8259A从片发送
                out 0x20,al                        ;向8259A主片发送 
				 
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,clock_int_message
		        call sys_routine_seg_sel:put_string
				popad
				iret
;-------------------------------------------------------------------------------
;键盘中断的处理
key_interrupt:
              pushad
			  xor eax,eax
			  
              mov al,0x20                        ;中断结束命令EOI
              out 0xa0,al                        ;向8259A从片发送
              out 0x20,al
			  
              mov al,0xAD                        ;关闭键盘
			  out 0x64,al
			  
			  ;获取状态
			  in al,0x64
			  test al,0x01
			  jz .end                            ;结束 输出缓冲区没有内容
			  	  
			  in al,0x60                         ;读取数据
			  test al,0x80
			  jnz .end
			  
			  mov ecx,eax
              ;得到数据段的地址
              mov eax,core_data_seg_sel
              mov ds,eax
              mov ebx,key_map
              mov byte cl,[ebx+ecx]			  

			  call put_char
			  
        .end:	
              mov al,0xAE                        ;开启键盘
			  out 0x64,al
		  
			  popad
              iret
;-------------------------------------------------------------------------------
key_interrupt_test:
              pushad
			  xor eax,eax
			  mov al, 0x20
	          out 0xa0,al                        ;向8259A从片发送
              out 0x20, al
			   
              in al, 0x60 ;读取按键的扫描码

              test al,0x80
			  jnz .end
    
              mov ecx,eax
              ;得到数据段的地址
              mov eax,core_data_seg_sel
              mov ds,eax
              mov ebx,key_map
              mov byte cl,[ebx+ecx]			  
              mov edx,ecx
			  call sys_routine_seg_sel:put_hex_dword

    ;对键盘进行复位处理
    ;先禁用键盘，然后重新允许使用
      in al, 0x61
    nop
    nop
    or al, 0x80
    nop
    nop
    out 0x61, al
    nop
    nop
    and al, 0x7F
    out 0x61, al

	
.end:	
    
  popad
    iret



;-------------------------------------------------------------------------------------
;除0错误
div_zeor_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,div_int_message
		        call sys_routine_seg_sel:put_string
				popad
				iret
;-------------------------------------------------------------------------------	
;页故障处理
;===============================================================================
SECTION core_data vstart=0                  ;系统核心的数据段
;-------------------------------------------------------------------------------
        ;进入内核信息提示
		core_show_message db '===Welcome to the PingPang OS',0x0a,0x0d
		                  db '===Now in the Core...',0x0d,0x0a
						  db '===Init the interrupt...',0x0d,0x0a,0
        ;基本中断的信息提示
		normal_int_message db '===A interrupt is triggered',0x0a,0x0d,0
		clock_int_message  db '===Clock interrupt is working...',0x0a,0x0d,0
		div_int_message    db '===The divisor is zero',0x0a,0x0d,0
		key_int_message    db '===You press the keyboard',0x0a,0x0d,0
		;for my Macbook Pro keyboard
        key_map            db 0
                           db 0                    		;+1 esc
                           db "1234567890-="       
                           db 0                         ;+0xe bksp
                           db 0						    ;+0x0f tab
                           db "qwertyuiop[]"
                           db 0x0d                      ;enter 回车键
                           db 0x1d                      ; ctrl key(left)
                           db "asdfghjkl"               
						   db 0                         ;+0x27RGUI
						   db "'"                       ;+0x28 '
						   db "`"                       ;+0x29
						   db 0                         ;+0x2a L SHFT
                           db "\zxcvbnm,./"             ;+0x36 R CTRL 下一个
                           times 128 db 0
						   
		bin_hex           db '0123456789ABCDEF'	           ;16进制对应转换的表  

        lidt_des          dw 256*8-1
                          dd interrupt_basic
        gdt_des           dw 0
                          dd gdt_basic		
        						  
;===============================================================================
SECTION core_code vstart=0
;-------------------------------------------------------------------------------
start:
         ;堆栈是已经在进入内核的时候已经初始化好了
         mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
         mov ds,ecx
		 
         ;加载显示进入内核的信息提示
		 mov ebx,core_show_message
		 call sys_routine_seg_sel:put_string
		 
		 cli
		 mov edx,normal_interrupt
		 call sys_routine_seg_sel:make_int_description;EDX:EAX
		 
		 mov ecx,mem_0_4_gb_seg_sel     ;#1加载数据段
		 mov es,ecx
		 mov ebx,interrupt_basic
		 mov ecx,256
	.init_int:
         mov [es:ebx],eax
         mov [es:ebx+0x04],edx
         add ebx,0x08
         loop .init_int
         
		;int 20H实例化时钟中断0x20
		mov edx,clock_interrupt
		call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x08*8],eax
		mov [es:ebx+0x08*8+4],edx
		;int 21h实例化键盘中断0x21
		mov edx,key_interrupt_test
		call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x09*8],eax
		mov [es:ebx+0x09*8+4],edx
		;int 0H实例化除法错误处理
        mov edx,div_zeor_interrupt
        call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x00*8],eax
		mov [es:ebx+0x00*8+4],edx		
		;实例化页错误处理 
		
		lidt [lidt_des]
        ;call sys_routine_seg_sel:Init8259A
		sti
		
		xor ebx,ebx
		;div ebx
		 jmp $
         ;这里可以放置清除用户程序各种描述符的指令
         ;也可以加载并启动其它程序
       
         hlt
            
;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end: