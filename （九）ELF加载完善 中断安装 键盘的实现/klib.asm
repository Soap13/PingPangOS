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

extern put_int
[bits 32]

[section .text]
global put_string       ;屏幕显示字符串0结尾，没有换行的
global MemCpy           ;内存copy （目的地址 源地址 长度）
global make_idt_description ;中断异常门安装
global Init8259A        ;实例化芯片中断
global key_interrupt    ;键盘中断
global interrupt_return ;异常的iret返回，配合c语言的函数调用
global exit             ;系统终止掉
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
;================================================================================
;                 门的实例化、安装；这里处理那个中断
;                 void 	make_idt_description(线性基地址，界限，属性,位置);	 
;================================================================================
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
                      
					                                     ;添加
	                  push esi
                      mov esi,[esp+4*8]
                      mov [interrupt_basic+esi*8],eax
                      mov [interrupt_basic+esi*8+4],edx					  
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
interrupt_return:
                 add esp,4
				 iret
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
exit:
     hlt	 
;==========================================================	
[section data]
 normal_interrupt_title    db 'The normal interrupt is triggered! The system will stop!',0x0a,0x0d,0
 key_map                   db 0
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