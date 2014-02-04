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
 interrupt_basic  equ 0x0000A000    ;娑擃厽鏌囬崝鐘烘祰閻ㄥ嫪缍呯純?
 
;外部进入函数 
extern put_string
extern show_title
extern init_idt

[bits 32]


[section .data]
    test_put_str db 'This just a test, i dont kow why i think lyy,Happy new year!',0x0d,0x0a,0

	
	
	  pgdt      dw 47
                dd gdt_basic      ;GDT閻ㄥ嫮澧块悶鍡楁勾閸р偓
	  lidt_des  dw 256*8-1
                dd interrupt_basic		
[SECTION .bss]
StackSpace		resb	2 * 1024
StackTop:		; kernel的堆栈使用
	
[section .text]

global _start

_start:

    mov ax,0x0008
	mov ss,ax
	mov esp,StackTop
    
	call show_title
	
	cli 
	call init_idt
	lidt [lidt_des]
	sti
	
	jmp	$
