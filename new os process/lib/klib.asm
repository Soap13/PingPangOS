;-------------------------------------------
;当做是kernel的系统函数
;函数参数传递采用的是堆栈压入的方式
;
;cs,ds,es,fs,ss都指向了全局
;gs，用来表示显示
;------------------------------------------
;#1 输出字符串
;#2 内部使用输出字符
;#3 Copy内存的
;-------------------------------------------
;王征 2014-02-03
;------------------------------------------

;常量
gdt_basic        equ 0x00007e00 
interrupt_basic  equ 0x0000A000    ;中断加载的位置
ldt_basic        equ 0x00008200

;--------------------------
;函数地址
extern normal_interrupt_process
extern put_hexln
extern change_proc


;--------------------------
;变量或者指针地址
extern current_proc ;这个是进程表 因为这里开头放的是 堆栈信息
extern tss       ;tss的信息
extern StackTop  ;内核堆栈位置
extern sys_call_table ;地址系统函数选择地址
[bits 32]

[section .text]
global put_string       ;屏幕显示字符串0结尾，没有换行的
global MemCpy           ;内存copy （目的地址 源地址 长度）
global memset_p

global make_gdt_description ;GDT的安装需要从新加载
global make_ldt_description
global make_idt_description ;中断异常门安装
global Init8259A        ;实例化芯片中断
global clock_interrupt  ;时钟中断
global key_interrupt    ;键盘中断
global normal_interrupt ;普通中断
global system_interrupt ;系统函数调用
global exit             ;系统终止掉
global test_show_a
global test_show_b

global interrupt_number_00
global interrupt_number_01
global interrupt_number_02
global interrupt_number_03
global interrupt_number_04
global interrupt_number_05
global interrupt_number_06
global interrupt_number_07
global interrupt_number_08
global interrupt_number_09
global interrupt_number_10
global interrupt_number_11
global interrupt_number_12
global interrupt_number_13
global interrupt_number_14
global interrupt_number_15
global interrupt_number_16
global interrupt_number_17
global interrupt_number_18
global interrupt_number_19

global restart

global port_read
global port_write
;========================================================================
;                  void put_string(char * info);
;======================================================================== 
put_string:                                 ;显示0终止的字符串并移动光标 
                                            ;输入：DS:EBX=串地址
         push ecx
		 push ebx
		 
		 mov ebx,[esp+4*3]                ;保护参数两个，函数调用近的一个
  .getc:
         mov cl,[ebx]
         or cl,cl
         jz .exit
         call put_char
         inc ebx
         jmp .getc

  .exit:
         pop ebx
         pop ecx
         ret                               ;段间返回
;================================================================================
;                 cl的值输出到当前屏幕的地方		 
;================================================================================		 
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
         ;push es
         ;mov eax,video_ram_seg_sel          ;0xb8000段的选择子
         ;mov es,eax
         shl bx,1
         mov [gs:bx],cl
         ;pop es

         ;以下将光标位置推进一个字符
         shr bx,1
         inc bx

  .roll_screen:
         cmp bx,2000                        ;光标超出屏幕？滚屏
         jl .set_cursor

         push ds
         push es
		 
         mov eax,gs
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
         mov word[gs:bx],0x0720
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
;================================================================================
;                 void MemCpy(*目的地址，*原始地址，*大小）		 
;================================================================================
MemCpy:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	esi, [ebp + 12]	; Source
	mov	ecx, [ebp + 16]	; Counter
.1:
	cmp	ecx, 0		; 判断计数器
	jz	.2		; 计数器为零时跳出

	mov	al, [ds:esi]		; ┓
	inc	esi			; ┃
					; ┣ 逐字节移动
	mov	byte [es:edi], al	; ┃
	inc	edi			; ┛

	dec	ecx		; 计数器减一
	jmp	.1		; 循环
.2:
	mov	eax, [ebp + 8]	; 返回值
	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp
	
	ret			; 函数结束，返回
; ------------------------------------------------------------------------
; void memset(void* p_dst, char ch, int size);
; ------------------------------------------------------------------------
memset_p:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	edx, [ebp + 12]	; Char to be putted
	mov	ecx, [ebp + 16]	; Counter
.1:
	cmp	ecx, 0		; 判断计数器
	jz	.2		; 计数器为零时跳出

	mov	byte [edi], dl		; ┓
	inc	edi			; ┛

	dec	ecx		; 计数器减一
	jmp	.1		; 循环
.2:

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret			; 函数结束，返回	
;================================================================================
;                 GDT
;                 void 	make_gdt_description(线性基地址，界限，属性,位置);	 
;================================================================================
;------------------------------------------------------------------------------
;处理 代码段描述符
                                            ;输入：EAX=线性基地址
                                            ;      EBX=段界限
                                            ;      ECX=属性。各属性位都在原始
                                            ;          位置，无关的位清零 
                                            ;返回：EDX:EAX=描述符
make_gdt_description:
                      push eax
					  push ebx
					  push ecx
					  push edx
					  
					  mov eax,[esp+4*5]
		              mov ebx,[esp+4*6]
	                  mov ecx,[esp+4*7] 
					  
                      mov edx,eax
                      shl eax,16
                      or ax,bx                           ;描述符前32位(EAX)构造完毕

                      and edx,0xffff0000                 ;清除基地址中无关的位
                      rol edx,8
                      bswap edx                          ;装配基址的31~24和23~16  (80486+)

                      xor bx,bx
                      or edx,ebx                         ;装配段界限的高4位
                      or edx,ecx                         ;装配属性
					  
					  push esi
                      mov esi,[esp+4*9]
		 
                      mov [gdt_basic+esi*8],eax
                      mov [gdt_basic+esi*8+4],edx
                      pop esi
					  
					  pop edx
                      pop ecx
                      pop ebx
                      pop eax
						
                      ret
;处理 代码段描述符
                                            ;输入：EAX=线性基地址
                                            ;      EBX=段界限
                                            ;      ECX=属性。各属性位都在原始
                                            ;          位置，无关的位清零 
                                            ;返回：EDX:EAX=描述符
make_ldt_description:
                      push eax
					  push ebx
					  push ecx
					  push edx
					  
					  mov eax,[esp+4*5]
		              mov ebx,[esp+4*6]
	                  mov ecx,[esp+4*7] 
					  
                      mov edx,eax
                      shl eax,16
                      or ax,bx                           ;描述符前32位(EAX)构造完毕

                      and edx,0xffff0000                 ;清除基地址中无关的位
                      rol edx,8
                      bswap edx                          ;装配基址的31~24和23~16  (80486+)

                      xor bx,bx
                      or edx,ebx                         ;装配段界限的高4位
                      or edx,ecx                         ;装配属性
					  
					  push esi
                      mov esi,[esp+4*9]
		 
                      mov [ldt_basic+esi*8],eax
                      mov [ldt_basic+esi*8+4],edx
                      pop esi
					  
					  pop edx
                      pop ecx
                      pop ebx
                      pop eax
						
                      ret					  
;================================================================================
;                 门的实例化、安装；这里处理那个中断
;                 void 	make_gdt_description(线性基地址，选择子，属性,位置);	 
;================================================================================
;构造门的描述符（调用门等)
make_idt_description:                       ;构造门的描述符（调用门等）
                                            ;输入：EAX=门代码在段内偏移地址
                                            ;       BX=门代码所在段的选择子 
                                            ;       CX=段类型及属性等（各属
                                            ;          性位都在原始位置）
                                            ;返回：EDX:EAX=完整的描述符
         push eax
		 push ebx
         push ecx
		 push edx
      
	     mov eax,[esp+4*5]
		 mov ebx,[esp+4*6]
	     mov ecx,[esp+4*7]
	  
         mov edx,eax
         and edx,0xffff0000                 ;得到偏移地址高16位 
         or dx,cx                           ;组装属性部分到EDX
       
         and eax,0x0000ffff                 ;得到偏移地址低16位 
         shl ebx,16                          
         or eax,ebx                         ;组装段选择子部分
      
	     push esi
         mov esi,[esp+4*9]
		 
         mov [interrupt_basic+esi*8],eax
         mov [interrupt_basic+esi*8+4],edx
         pop esi
		 
	     pop edx
         pop ecx
         pop ebx
         pop eax
		 
         ret           
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
    ret
;=========================================================
;中断处理过程中已经压入了栈
;如果压入的没有权限关系的则 eip,ip,flages
;                      code,eip,ip,flages
;这样我在调用c的函数则可以得到值了
;=========================================================
normal_interrupt:
                 push 0xFFFFFFFF;描述编号
				 push 20
                 call normal_interrupt_process
                 iret          ;没有作用
				 
interrupt_number_00:
                 push 0xFFFFFFFF
                 push 0
                 call normal_interrupt_process 
                 iret
interrupt_number_01:
                 push 0xFFFFFFFF
                 push 1
                 call normal_interrupt_process 
                 iret
interrupt_number_02:
                 push 0xFFFFFFFF
                 push 2
                 call normal_interrupt_process 
                 iret
interrupt_number_03:
                 push 0xFFFFFFFF
                 push 3
                 call normal_interrupt_process 
                 iret
interrupt_number_04:
                 push 0xFFFFFFFF
                 push 4
                 call normal_interrupt_process 
                 iret
interrupt_number_05:
                 push 0xFFFFFFFF
                 push 5
                 call normal_interrupt_process 
                 iret
interrupt_number_06:
                 push 0xFFFFFFFF
                 push 6
                 call normal_interrupt_process 
                 iret
interrupt_number_07:
                 push 0xFFFFFFFF
                 push 7
                 call normal_interrupt_process 
                 iret
interrupt_number_08:
                 push 8
                 call normal_interrupt_process 
                 iret
interrupt_number_09:
                 push 0xFFFFFFFF
                 push 9
                 call normal_interrupt_process 
                 iret
interrupt_number_10:
                 push 10
                 call normal_interrupt_process 
                 iret
interrupt_number_11:
                 push 11
                 call normal_interrupt_process 
                 iret
interrupt_number_12:
                 push 12
                 call normal_interrupt_process 
                 iret
interrupt_number_13:
                 push 13
                 call normal_interrupt_process 
                 iret
interrupt_number_14:
                 push 14
                 call normal_interrupt_process 
                 iret
interrupt_number_15:
                 push 0xFFFFFFFF
                 push 15
                 call normal_interrupt_process 
                 iret
interrupt_number_16:
                 push 0xFFFFFFFF
                 push 16
                 call normal_interrupt_process 
                 iret
interrupt_number_17:
                 push 17
                 call normal_interrupt_process 
                 iret
interrupt_number_18:
                 push 0xFFFFFFFF
                 push 18
                 call normal_interrupt_process 
                 iret
interrupt_number_19:
                 push 0xFFFFFFFF
                 push 19
                 call normal_interrupt_process 
                 iret					 
;=========================================================
;#int 0x20时钟中断的处理
clock_interrupt:
                sub esp,4 ;默认添加一个进入
                pushad
				push ds
				push es
				push fs
				push gs
				
				mov dx,ss
				mov es,dx
				mov ds,dx
				
				mov esp,StackTop
				
				;inc byte[gs:0]
				;测试显示一句话吧
				push clock_interrupt_title
				call put_string
				
				mov ecx,0xffffff
			.loop:
			    nop
				loop .loop
				
				call change_proc
				
				mov al,0x20                        ;中断结束命令EOI
                out 0xa0,al                        ;向8259A从片发送
                out 0x20,al                        ;向8259A主片发送 
				
				call restart
					
;=========================================================
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
              ;mov eax,core_data_seg_sel
              ;mov ds,eax
              mov ebx,key_map
              mov byte cl,[ebx+ecx]			  

			  call put_char
			  
        .end:	
              mov al,0xAE                        ;开启键盘
			  out 0x64,al
			  
			  popad
              iret
;==========================================================
;系统函数调用处理
;通过比较eax确定函数的调用
;eax的值的大小 从这步起 eax，ebx，ecx,edx,esi,edi值不能改变
;==========================================================			  
system_interrupt:
                 ;
                 cli
				 call save
				 call [sys_call_table+eax*4]
				 sti
                 ret	
;==========================================================
;寄存器信息保存
;因为是调用的所以有个如入栈了，这里只有系统函数使用才调用
save:
     pushad
	 push ds
	 push es
	 push fs
	 push gs
     
	 ;堆栈用内核的堆栈
	 mov esi,esp
	 mov esp,StackTop
	 ;这里程序的基本用内核级别的了
	
	 ;放一个进程的入口地址
	 push restart
	 ;跳转回刚进来的位置
     jmp [esi+12*4]	 
;==========================================================	
exit:
     hlt	  
;==========================================================	
align 4
restart:
    ;cli
	;push dword [current_proc]
	;call put_hexln
	
	mov	esp,[current_proc] ;得到一个地址
	
	lldt [esp+18*4]
	;hlt
	;切记内核中3的esp使用大小只限于信息保存
	;mov	eax, [esp + 16*4]
	mov eax,esp
	add eax,18*4
	mov	dword [tss + 1*4], eax
	
	pop	gs
	;hlt
	pop	fs
	pop	es
	pop	ds
	popad
	add	esp, 4
	;sti ;开中断
	iretd			 
;==========================================================	
;端口的读写内核态
port_read:
          push ebx
          mov ebx,esp
		  mov edx,[ebx+4*2]
		  in eax,dx
		  pop ebx
		  ret
;==========================================================	
;端口读内核态
;C的函数调用预定
port_write:
           push ebx
           mov ebx,esp
		   mov eax,[ebx+4*2]
		   mov edx,[ebx+4*3]
		   out dx,eax
           pop ebx
		   ret
;==========================================================	
[section data]
  clock_interrupt_title    db '.',0
 key_map                   db 0
                           db 0                    		;+1 esc
                           db "1234567890-="       
                           db 0                         ;+0xe bksp
                           db 0						    ;+0x0f tab
                           db "qwertyuiop[]"
                           db 0x0d                      ;enter 回车键
                           db 0x1d                      ; ctrl key(left)
                           db "asdfghjkl"               
						   db ';'                       ;+0x27RGUI
						   db "'"                       ;+0x28 '
						   db "`"                       ;+0x29
						   db 0                         ;+0x2a L SHFT
                           db "\zxcvbnm,./"             ;+0x36 R CTRL 下一个
                           times 128 db 0	 