/**
 * 中断和异常处理函数
 * 王征 2014-02-05
 */
//=========================================
void Init8259A(); 
//安装中断
void make_idt_description(unsigned int addr,unsigned int gdt_select,unsigned int attr,unsigned int index);

void normal_interrupt(); //普通中断处理
void clock_interrupt(); //时钟中断
void key_interrupt();   //键盘中断
void system_interrupt(); //系统中断
void exit();            //系统终止
//中断
void interrupt_number_00();
void interrupt_number_01();
void interrupt_number_02();
void interrupt_number_03();
void interrupt_number_04();
void interrupt_number_05();
void interrupt_number_06();
void interrupt_number_07();
void interrupt_number_08();
void interrupt_number_09();
void interrupt_number_10();
void interrupt_number_11();
void interrupt_number_12();
void interrupt_number_13();
void interrupt_number_14();
void interrupt_number_15();
void interrupt_number_16();
void interrupt_number_17();
void interrupt_number_18();
void interrupt_number_19(); 