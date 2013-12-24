;目的是分页的练习
;时间 2013-12-14 下午 周六

;分页的demo
;一个也目录，一个页表1024个页*4k=4M大小
;那么需要一个页目录，1M空间需要2^20/2^12=2^8=1024/4=256个

;因为上面已经把1M空间对应--对应了，那么修改的范围是

;根据512KB=2^9*2^10=2^19=0x00080000       大小4k 
;            /2^12=2^7=128
;    520KB=             =0x00082000       大小4K

;指向同一个页
;我加载的段描述符的位置在0x00007e00        距离1ff/8=64个描述符可用
;0-4=0;
;512/4=128------> 
;520/4=130------>指向128的描述符位置就可以了
;段描述符位置为两个5,6 然后512写入hello,world 520读取
[org 0x7c00]
[bits 16]
		page_dir                equ 0x00020000
		page                    equ 0x00021000
		ldt_description         equ 0x00007F00
				 
        mov ax,cs
		mov ds,ax
		
		call show_style                    ;设置显示模式 主要是清屏
		
		;计算GDT所在的逻辑段地址 
         mov eax,[pgdt+0x02]           ;得到描述符的基地址  
         xor edx,edx
		 mov ebx,16
         div ebx            
         mov ds,eax                         ;令DS指向该段以进行操作
         mov ebx,edx                        ;段内起始偏移地址 
         
         ;创建0#描述符，它是空描述符，这是处理器的要求
		 
        ;创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间
         mov dword [ebx+0x08],0x0000ffff    ;基地址为0，段界限为0xFFFFF
         mov dword [ebx+0x0c],0x00cf9200    ;粒度为4KB，存储器段描述符 

         ;创建保护模式下初始代码段描述符
         mov dword [ebx+0x10],0x7c0001ff    ;基地址为0x00007c00，界限0x1FF 
         mov dword [ebx+0x14],0x00409800    ;粒度为1个字节，代码段描述符 

         ;建立保护模式下的堆栈段描述符      ;基地址为0x00007C00，界限0xFFFFE 
         mov dword [ebx+0x18],0x7c00fffe    ;粒度为4KB 
         mov dword [ebx+0x1c],0x00cf9600
         
         ;建立保护模式下的显示缓冲区描述符   
         mov dword [ebx+0x20],0x80007fff    ;基地址为0x000B8000，界限0x07FFF 
         mov dword [ebx+0x24],0x0040920b    ;粒度为字节
		 
		 ;============510=512两个数据段分别是 5=================
		 ;为了测试句不断选择子，大小就8个字节也就是一个ldt
		 mov eax,ldt_description
		 shl eax,16
		 or eax,0x0000000f
         mov dword [ebx+0x28],eax    ;基地址为0，段界限为8
         mov dword [ebx+0x2c],0x00408200    ;粒度为4KB，存储器段描述符 
		  
         ;=========================================================  		 
		 
		 
         ;初始化描述符表寄存器GDTR
		 ;因为上面吧数据段地址改了所以这利用代码段
         mov word [cs:pgdt],55  ;描述符表的界限（总字节数减一） n*8-1;  
          
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
		               
		                xor eax,eax
		                mov eax,0000_0000_00100_000B     ;#4 显示段
					    mov es,eax                     
						
						mov byte[es:0x00],'H'
						mov byte[es:0x02],'E'
						mov byte[es:0x04],'L'
						mov byte[es:0x06],'L'
						mov byte[es:0x08],'O'
						mov byte[es:0x0a],','
						mov byte[es:0x0c],'O'
						mov byte[es:0x0e],'S'
		                
						mov eax,0000_0000_00001_000B  ;#1数据段 4G
						mov es,eax
						
	                    xor ebx,ebx
						mov ebx,ldt_description; 得到偏移地址
						
						
						mov dword [es:ebx+0x00],0x7c0001ff
						mov dword [es:ebx+0x04],0x00409800    ;拼凑一个lldt的选择子
						
						
						xor eax,eax
						mov ax,0000_0000_00101_000B     ;第五个描述符的位置
						
						lldt ax       ;加载lldt
						
						;hlt
						
						jmp dword 0x0004:ldt_loader-0x7c00
                        hlt 	 ;程序终止		
;----------------------------------------------------------------
	    ldt_loader:
		xor eax,eax
		                mov eax,0000_0000_00100_000B     ;#4 显示段
					    mov es,eax                     
						
						mov byte[es:0x00+0xa0],'L'
						mov byte[es:0x02+0xa0],'L'
						mov byte[es:0x04+0xa0],'D'
						mov byte[es:0x06+0xa0],'T'
		           hlt;
		            
					
						
;--------------数据段--------------------------------------------	
        pgdt       dw 0
	               dd 0x00007e00     ;GDT的物理地?
	         times 510-($-$$) db 0 
                   db 0x55 ;引导识别标示
                   db 0xaa	