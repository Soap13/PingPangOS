         ;创建日期：2012-12-29 核心代码段的修改
;----------------------------------------------------------------------------------------------
;提供的方法 1.可以显示字符信息         put_char                 CL                     内部调用的
;           2.可以显示一串信息         put_string               DS:EBX  0结束
;			3.可以回车换行的实         put_another_line     
;           4.可以换行输出的           put_another_string       DS:EBX  0结束
;           5.硬盘读取的               read_hard_disk_0         EAX=逻辑扇区号
;                                                               DS:EBX=目标缓冲区地址
;                                                               返回：EBX=EBX+512
;           6.十六进制显示             put_hex_dword            EDX
;           7.中断描述符               make_int_description     EDX是偏移地址
;                                                               EDX:EAX(高地址：低地址)
;           8.实例化8259a的            Init8259A
;           9.通用的中断               normal_interrupt
;          10.时钟中断                 clock_interrupt          #0X20
;          11.键盘中断                 key_interrupt            #0X21
;          12.除法错误                 div_zeor_interrupt       #0X00
;          13.段不存在错误             section_no_interrupt     #0X0B
;          14.栈段故障                 stack_error_interrupt    #0X0C
;          15.常规保护                 protect_error_interrupt  #0X0D
;
;
;
;
;
;
;-----------------------------------------------------------------------------------------------
         ;以下常量定义部分。内核的大部分内容都应当固定 
		 ;40Tss
		 ;
         core_code_seg_sel     equ  0x38    ;#7内核代码段选择子           
         core_data_seg_sel     equ  0x30    ;#6内核数据段选择子 
         sys_routine_seg_sel   equ  0x28    ;#5系统公共例程代码段的选择子 
         video_ram_seg_sel     equ  0x20    ;#4视频显示缓冲区的段选择子
         core_stack_seg_sel    equ  0x18    ;#3内核堆栈段选择子
		 head_staart_seg_sel   equ  0x10    ;#2引导的代码段
         mem_0_4_gb_seg_sel    equ  0x08    ;#1整个0-4GB内存的段的选择子
;--------------------------------------------------------------------------------
         ;常用的信息加载地址段可能要修改
		 gdt_basic         equ 0x00007e00    ;全局段基地址
		 ldt_basic         equ 0x00008200    ;局部段描述符
		 interrupt_basic   equ 0x0000A000    ;中断加载的位置
		 tss_link          equ 0x00009000    ;任务的信息保存位置
		 tss_basic         equ 0x00008600    ;任务的起始地址
		 core_base_address equ 0x00040000    ;常数，内核加载的起始内存地址 
		 stack_tss_basic   equ 0x00005C00    ;堆栈信息
		 ;stack_task_basic  equ 0x00005C00    ;任务堆栈或者3的堆栈信息
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
;---------------------------------------------------------------------------------
put_another_string:                          ;DS:EBX输出 0结束的
        pusha
		call sys_routine_seg_sel:put_string
		call sys_routine_seg_sel:put_another_line
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
;------------------------------------------------------------------------------
;处理 代码段描述符
                                            ;输入：EAX=线性基地址
                                            ;      EBX=段界限
                                            ;      ECX=属性。各属性位都在原始
                                            ;          位置，无关的位清零 
                                            ;返回：EDX:EAX=描述符
make_gdt_description:
                      mov edx,eax
                      shl eax,16
                      or ax,bx                           ;描述符前32位(EAX)构造完毕

                      and edx,0xffff0000                 ;清除基地址中无关的位
                      rol edx,8
                      bswap edx                          ;装配基址的31~24和23~16  (80486+)

                      xor bx,bx
                      or edx,ebx                         ;装配段界限的高4位
                      or edx,ecx                         ;装配属性
                      retf
;-------------------------------------------------------------------------------
;构造门的描述符（调用门等)
make_gate_descriptor:                       ;构造门的描述符（调用门等）
                                            ;输入：EAX=门代码在段内偏移地址
                                            ;       BX=门代码所在段的选择子 
                                            ;       CX=段类型及属性等（各属
                                            ;          性位都在原始位置）
                                            ;返回：EDX:EAX=完整的描述符
         push ebx
         push ecx
      
         mov edx,eax
         and edx,0xffff0000                 ;得到偏移地址高16位 
         or dx,cx                           ;组装属性部分到EDX
       
         and eax,0x0000ffff                 ;得到偏移地址低16位 
         shl ebx,16                          
         or eax,ebx                         ;组装段选择子部分
      
         pop ecx
         pop ebx
      
         retf            
;-------------------------------------------------------------------------------
;添加全局描述符
;CX描述符的选择子
;EDX:EAX 描述符的高：低地址
add_gdt_description:
                     ;pushad
					 cli      ;关闭中断
					 mov ecx,core_data_seg_sel
					 mov ds,ecx                 ;内核数据段
					 mov edi,gdt_des
					 
					 mov ecx,mem_0_4_gb_seg_sel ;全局段
					 mov es,ecx
					 mov esi,gdt_basic
					 
					 ;读取当前的位置
					 xor ebx,ebx
					 mov word bx,[ds:edi]            ;读取描述符的地址位置
					 add bx,1                   ;位置向后移动一位
					 
					 ;添加描述
					 mov dword [es:esi+ebx+0x00],eax
					 mov dword [es:esi+ebx+0x04],edx
					 
                     add bx,7                   ;
					 mov word [ds:edi],bx        ;从新写入描述个数
					 lgdt[ds:edi]               ;重新加载
					 
                     ;popad
					 
					 xor cx,cx
                     xor dx,dx
                     mov ax,bx
                     mov bx,8
                     div bx
                     mov cx,ax
                     shl cx,3
					 
					 sti      ;打开中断
					
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
	       
	        mov	al, 11111100b	; 仅仅开启定时器中断
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
				
				 ;输出错误的CS
                pop eax     ;EIP
				pop edx     ;CS
				call pring_error_position
				push edx
				add eax,2
				push eax
				
                iret				
;-------------------------------------------------------------------------------
;#int 0x20时钟中断的处理
;主动声明了一个堆栈保存用户的信息
clock_interrupt:
                ;pushad
			    
				 
				;mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                ;mov ds,ecx
				;mov ebx,clock_int_message
		        ;call sys_routine_seg_sel:put_string
				;popad                              ;保存完整的信息
				
			    push dword 0
				pushad
				push  ds
				push  es
				push  fs
				push  gs
				
				;jmp .end
				;得到当前正在执行的任务是第几个
				 mov eax,mem_0_4_gb_seg_sel
		         mov es,eax
		         mov ebx,tss_link
		         mov edx,dword[es:ebx] ;获取任务的个数 最后一个是当前执行切换过来的
		                               ;0或者1都不执行直接返回吧。
	             cmp edx,2             ;<2直接结束掉
				 jl .end               
				 
				                       ;ecx就是任务的数
				 
				                       ;得到当前正在执行的额任务
				mov eax,dword[es:ebx+edx*4]
				
				shr eax,16
				;mov eax,1
                mov bl,72
				mul bl
				mov ebx,0x00006C00
				sub ebx,eax             ;高位eip
				mov ecx,18              ;寄存器个数
			.loop:
                pop eax
                mov dword[es:ebx],eax
				add ebx,4
                loop .loop				
				
				                       ;得到下一个执行的任务
				call sys_routine_seg_sel:get_task
				mov ebx,tss_link
				
			    mov edx,dword[es:ebx]
                mov eax,dword[es:ebx+edx*4]				
				shr eax,16             ;下一个执行的任务位置
                ;-----------------------------------------
			    ;mov edx,eax
				;call sys_routine_seg_sel:put_hex_dword
				;call sys_routine_seg_sel:put_another_line
			;------------------------------------------	
			   ; mov eax,1
                mov bl,72
                mul bl
                mov ebx,0x0000
                sub ebx,eax
				sub ebx,0x1000
                mov esp,ebx		
                mov eax,core_stack_seg_sel				
			.end:			
				mov al,0x20                        ;中断结束命令EOI
                out 0xa0,al                        ;向8259A从片发送
                out 0x20,al                        ;向8259A主片发送 
			
			
			 		
				pop gs
				pop fs
				pop es
				pop ds
				popad
				add esp,4
			;	hlt
				iret
;-------------------------------------------------------------------------------
;添加任务的描述
;寻找下一个执行的任务
;开头表明任务的总个数
;任务从几开始哪
; |----0--15--|---16--31--|
;
;  任务           状态
;
; 处理如果位置为0是一个暂停
;
; 如果保存1的话表明任务正在执行的


get_task:
         pushad
		 mov eax,mem_0_4_gb_seg_sel
		 mov es,eax
		 mov ebx,tss_link
		 mov ecx,dword[es:ebx] ;获取任务的个数 最后一个是当前执行切换过来的
		                       ;0或者1都不执行直接返回吧。
	     cmp ecx,2             ;<2
		 jl .end
		 mov eax,dword[es:ebx+4]
		 mov edx,dword[es:ebx+ecx*4]
		                       ;交换数据
	     and edx,0xFFFFFFFE
         mov dword[es:ebx+4],edx

         or  eax,0x00000001
         mov dword[es:ebx+ecx*4],eax
         		 
       .end:  
         popad	   
         retf
;------------------------------------------
;声明任务的
;push ss
;push esp
;push flage
;push cs
;push eip		 
add_task:
         pushad 
		 mov eax,mem_0_4_gb_seg_sel
		 mov es,eax
		 mov ebx,tss_link
		 mov ecx,dword[es:ebx] ;获取任务的个数 最后一个是当前执行切换过来的
		 inc ecx
		 mov dword[es:ebx],ecx ;任务个数+1；
		
		 cmp ecx,1             ;如果是第一个
		 je  .first
		 jg  .second
  .first:
         ;hlt  ;如果只有一个任务标记为运行   
         shl ecx,16
         add ecx,1
         mov dword[es:ebx+4],ecx		 
		 jmp .end
  .second:
                              ;以前任务后移动
         dec ecx
         mov eax,dword[es:ebx+ecx*4]
         mov dword[es:ebx+ecx*4+4],eax
		 
         mov eax,ecx
		 inc ecx
         shl ecx,16
         mov dword[es:ebx+eax*4],ecx	 
    .end: 
	      ;hlt                     ;堆栈的位置如何添加
		 mov eax,[es:ebx]          ;得到个数
		 
         sub eax,1
		 mov bl,72
         mul bl            
         mov edx,eax
		 
		 mov eax,core_data_seg_sel
		 mov ds,eax
		 
		 mov ecx,5
		 mov ebx,0x00006C00
         sub ebx,edx          ;减法得到堆栈的位置 
         xor esi,esi
		 mov esi,stack_des
   .loop:
         sub ebx,4
         mov eax,dword[ds:esi]
		 mov dword[es:ebx],eax
		 
		 add esi,4
		 ;sub ebx,4
        loop .loop		
	
	     popad
         retf		 
;-------------------------------------------------------------------------------
;#int 0x21键盘中断的处理
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
;#int 0x00除0错误
div_zeor_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,div_int_message
		        call sys_routine_seg_sel:put_string
				
				popad
				
				 ;输出错误的CS
                pop eax     ;EIP
				pop edx     ;CS
				call pring_error_position
				push edx
				add eax,2
				push eax
				iret
;#int  13这里是个异常错误 这个例子是13号中断
tss_error_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,tss_int_message
		        call sys_routine_seg_sel:put_string
				mov ebx,exception_message
				call sys_routine_seg_sel:put_string
                popad
				
				pop edx          ;edx是错误代码下面将要打印出来
				call sys_routine_seg_sel:put_hex_dword
				call sys_routine_seg_sel:put_another_line
		
				 ;输出错误的CS
                pop eax     ;EIP
				pop edx     ;CS
				call pring_error_position
				push edx
				add eax,2
				push eax
				iret
;-------------------------------------------------------------------------------
;#int  11这里是个异常错误 这个例子是11号中断
section_no_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				xor ecx,ecx
				mov ebx,section_int_message
		        call sys_routine_seg_sel:put_string
				mov ebx,exception_message
				call sys_routine_seg_sel:put_string
                popad
				
				pop edx          ;edx是错误代码下面将要打印出来
				call sys_routine_seg_sel:put_hex_dword
				call sys_routine_seg_sel:put_another_line
				
				 ;输出错误的CS
                pop eax     ;EIP
				pop edx     ;CS
				call pring_error_position
				push edx
				add eax,2
				push eax
				
                iret				
;-------------------------------------------------------------------------------
;#int  12堆栈错误
stack_error_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,stack_int_message
		        call sys_routine_seg_sel:put_string
				mov ebx,exception_message
				call sys_routine_seg_sel:put_string
                popad
				
				pop edx          ;edx是错误代码下面将要打印出来
				call sys_routine_seg_sel:put_hex_dword
				call sys_routine_seg_sel:put_another_line
				
		        ;输出错误的CS
                pop eax     ;EIP
				pop edx     ;CS
				call pring_error_position
				push edx
				add eax,2
				push eax
                iret				
;-------------------------------------------------------------------------------
;#int  13这里是个异常错误 这个例子是13号中断
protect_error_interrupt:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,protect_int_message
		        call sys_routine_seg_sel:put_string
				mov ebx,exception_message
				call sys_routine_seg_sel:put_string
                popad
				
				pop edx          ;edx是错误代码下面将要打印出来
				call sys_routine_seg_sel:put_hex_dword
				call sys_routine_seg_sel:put_another_line
	
				
		        ;输出错误的CS
                pop eax     ;EIP
				pop edx     ;CS
				call pring_error_position
				
				push edx
				add eax,2
				push eax
                iret				
;-------------------------------------------------------------------------------	
;页故障处理
;===============================================================================
;打印出错位置的ip:eip 段内调用
pring_error_position:
                pushad
				mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
                mov ds,ecx
				mov ebx,error_positon
				call sys_routine_seg_sel:put_string
				
                call sys_routine_seg_sel:put_hex_dword
				
                mov cl,':'
                call put_char
				;输出错误的EIP
				mov edx,eax
				call sys_routine_seg_sel:put_hex_dword
				call sys_routine_seg_sel:put_another_line 
				popad
				ret					
;-------------------------------------------------------------------------------
;ring3状态下的门调用输出一个字符信息的
test_ring3:
           pushad
		   mov cl,'3'
		   call sys_routine_seg_sel:put_char
		   popad
           retf		   
;-------------------------------------------------------------------------------
test_ring0:
           pushad
		   call sys_routine_seg_sel:put_char 
		   popad
		   retf
;-------------------------------------------------------------------------------
test_tss:	
		  mov eax,0x0023
		  mov es,eax
		  xor ebx,ebx
		.loop:   
		  mov ecx,0xFFFFF
		  
		.loop2:  
		  nop
		  nop
		  nop
		  loop .loop2
		  
		  mov byte [es:ebx+0],'3'
		  add ebx,2
		  
		  jmp .loop
		 ; jmp .loop		 
		  retf
;-------------------------------------------------------------------------------		  
test_gate:
          mov eax,0x0020
		  mov es,eax
		  xor ebx,ebx
		  mov ebx,80*25
		.loop:   
		  mov ecx,0xFFFFF
		  
		.loop2:  
		  nop
		  nop
		  nop
		  loop .loop2
		  
		  mov byte [es:ebx+0],'0'
		  sub ebx,2
		  
		  jmp .loop
		  retf			  
;-------------------------------------------------------------------------------
SECTION core_data vstart=0                  ;系统核心的数据段
;-------------------------------------------------------------------------------
        ;进入内核信息提示
		core_show_message db '===Welcome to the PingPang OS',0x0a,0x0d
		                  db '===Now in the Core...',0x0d,0x0a
						  db '===Init the interrupt...',0x0d,0x0a,0
        ;基本中断的信息提示
		exception_message  db '***Error Message  is:',0
		error_positon      db '***Error position is:',0
		normal_int_message db '===A interrupt is triggered',0x0a,0x0d,0
		clock_int_message  db '===Clock interrupt is working...',0x0a,0x0d,0
		div_int_message    db '===The divisor is zero,Please check the code!',0x0a,0x0d,0
		key_int_message    db '===You press the keyboard',0x0a,0x0d,0
	   section_int_message db '===The Set is not right,Please check the code!',0x0a,0x0d,0
		 stack_int_message db '===The Stack choice error!',0x0a,0x0d,0
	   protect_int_message db '===The Protected check error,Please check it!',0x0a,0x0d,0 
	   tss_int_message     db '===The TSS error,Please check it!',0x0a,0x0d,0 
	   tss_test_message         db '===Tss test!',0x0a,0x0d,0
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
						   
		bin_hex            db '0123456789ABCDEF'	           ;16进制对应转换的表  

        lidt_des           dw 256*8-1
                           dd interrupt_basic
						   
        gdt_des            dw 8*8-1                                ;填充这个数值
                           dd gdt_basic		
						   
        stack_des          dd 0                                     ;ss                                   
                           dd 0		                                ;esp
						   dd 0
						   dd 0
						   dd 0
;===============================================================================
SECTION core_code vstart=0
;-------------------------------------------------------------------------------
start:
         ;堆栈是已经在进入内核的时候已经初始化好了
         mov ecx,core_data_seg_sel           ;使ds指向核心数据段 
         mov ds,ecx
		 
		 mov ecx,core_stack_seg_sel
		 mov ss,ecx
		 xor esp,esp
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
		mov [es:ebx+0x20*8],eax
		mov [es:ebx+0x20*8+4],edx
		;int 21h实例化键盘中断0x21
		mov edx,key_interrupt
		call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x21*8],eax
		mov [es:ebx+0x21*8+4],edx
		;int 0H实例化除法错误处理
        mov edx,div_zeor_interrupt
        call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x00*8],eax
		mov [es:ebx+0x00*8+4],edx
		;int 10h TSS错误
		mov edx,tss_error_interrupt
        call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x0A*8],eax
		mov [es:ebx+0x0A*8+4],edx	
		;int 11h 段描述付不再内存中，也就是P位=0
        mov edx,section_no_interrupt
        call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x0B*8],eax
		mov [es:ebx+0x0B*8+4],edx			
		
		;int 12h 栈段错误
        mov edx,stack_error_interrupt
        call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x0C*8],eax
		mov [es:ebx+0x0C*8+4],edx
		
		;int 13h 一般的保护性错误
        mov edx,protect_error_interrupt
        call sys_routine_seg_sel:make_int_description;EDX:EAX
		mov ebx,interrupt_basic
		mov [es:ebx+0x0D*8],eax
		mov [es:ebx+0x0D*8+4],edx
		
		lidt [lidt_des]
        call sys_routine_seg_sel:Init8259A
		;sti
;-----------------------------------------------------------------------------------		
		;#8可以安装一个TSS描述符 执行的段
		mov  eax,core_base_address+section.sys_routine.start     ;基地址
		mov  ebx,0x0000FFFF
		mov ecx,0x0040F800
		call sys_routine_seg_sel:make_gdt_description
		call sys_routine_seg_sel:add_gdt_description
		
		;#9安装一个堆栈是用来
		mov eax,stack_tss_basic
		mov ebx,0x000FFFFE
		mov ecx,0x00C0F600
		call sys_routine_seg_sel:make_gdt_description
		call sys_routine_seg_sel:add_gdt_description
		
		;call 0x0040:test_tss 
	;-------------------------------------------------------------------	
		mov ebx,mem_0_4_gb_seg_sel
		mov es,ebx
		mov ebx,tss_basic
		mov dword[es:ebx+0x00],0
        mov dword[es:ebx+4],0                           ;到ESP0
        mov word [es:ebx+8],0x0018                      ;到SS0
        mov dword[es:ebx+32],test_gate                  ;eip
		mov word [es:ebx+76],sys_routine_seg_sel        ;cs
		mov word [es:ebx+102],103
		mov word [es:ebx+100],0                         ;T
		mov word [es:ebx+28],0                          ;CR3
		
		;#10
		mov  eax,tss_basic     ;基地址
		mov  ebx,103
		mov  ecx,0x0040E900
		call sys_routine_seg_sel:make_gdt_description
		call sys_routine_seg_sel:add_gdt_description
		ltr  cx
		
		;#11
		mov  eax,test_gate     ;基地址
		mov  bx,sys_routine_seg_sel
		mov  cx,0xEC00
		call sys_routine_seg_sel:make_gate_descriptor
		call sys_routine_seg_sel:add_gdt_description
		
		;#12
		mov  eax,test_ring3     ;基地址
		mov  bx,sys_routine_seg_sel
		mov  cx,0xEC00
		call sys_routine_seg_sel:make_gate_descriptor
		call sys_routine_seg_sel:add_gdt_description
		
		;#13
		mov eax,0x4C00
		mov ebx,0x000FFFFE
		mov ecx,0x00C0F600
		call sys_routine_seg_sel:make_gdt_description
		call sys_routine_seg_sel:add_gdt_description
		
	;------------------------------------------------------------------
        ;任务1
		mov eax,core_data_seg_sel
		mov ds,eax
		mov ebx,stack_des
		mov dword[ds:ebx+0],0x004b
		mov dword[ds:ebx+4],0
		pushfd
		pop eax
		mov dword[ds:ebx+8],eax
		mov dword[ds:ebx+12],0x0043
		mov dword[ds:ebx+16],test_tss
		
		call sys_routine_seg_sel:add_task
		;retf
		
		;任务2
		mov dword[ds:ebx+0],0x006B
		mov dword[ds:ebx+4],0
		pushfd
		pop eax
		mov dword[ds:ebx+8],eax
		mov dword[ds:ebx+12],0x0043
		mov dword[ds:ebx+16],test_gate
		
		call sys_routine_seg_sel:add_task
		
		;call sys_routine_seg_sel:add_task
		;sti
		;----------------------------------------------
		      
		;-----------------------------------------------
		push dword 0x004b
		push dword 0
		pushfd
		push dword 0x0043
		push dword test_tss
		iret
	;------------------------------------------------------------------	
		jmp $
		;call 0x0040:test_tss 
        
		;安装一个
		

		jmp $
        hlt
            
;===============================================================================
SECTION core_trail
;-------------------------------------------------------------------------------
core_end: