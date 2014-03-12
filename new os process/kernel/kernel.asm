;===========================================
;kernel
;ds,es,fs,ss 因为c编译的原因在进入kernel的时候指向相同
;gs 显示段
;===========================================
;
;
;===========================================
;王征 2014-02-03
;===========================================
;这个内存规划
 gdt_basic        equ 0x00007e00 
 interrupt_basic  equ 0x0000A000
 
;外部进入函数 
extern show_title
extern init_idt
extern ini_process
extern put_hexln

extern restart ;模拟中断返回
extern init_tss

extern traversal_pic;pci遍历
[bits 32]


[section .data]
global pgdt    ;共享的数据信息

	  pgdt      dw 47
                dd gdt_basic      
				
	  lidt_des  dw 256*8-1
                dd interrupt_basic		
[SECTION .bss]
global StackTop

StackSpace		resb	2 * 1024
StackTop:		; kernel的堆栈使用
	
[section .text]

global _start
global add_gdt


_start:

    mov ax,0x0008
	mov ss,ax
	mov esp,StackTop
    
	call show_title
	
	cli 
	call init_idt
	lidt [lidt_des]
	;sti
;-----------------------------	
;pci读取测试
	call traversal_pic 
    jmp $	
;-----------------------------	
	;加载tss
	call init_tss
	call ini_process
	
	mov ax,0000_0000_00110_000B
	ltr ax
	;mov ax,0x003B  ;7权限3
	;lldt ax
	
	jmp restart
	
	jmp	$
;======================================
;这里只需要添加一个每次从新加载就可以了
;因为地址是规划过的
add_gdt:
    pushad
	mov ax,[pgdt]
	add ax,8
	mov word[pgdt],ax
	lgdt[pgdt]
	popad
	
	jmp dword 0x0028:.again
  .again:
	ret	