/**
 * GDT的安装和使用
 * 王征 2014-02-05
 */
//内存实例化数据
void memset_p(unsigned int addr,unsigned int cha,unsigned int size);
 
void make_gdt_description(unsigned int addr,unsigned int limit,unsigned int attr,unsigned int index); //GDT的安装
void make_ldt_description(unsigned int addr,unsigned int limit,unsigned int attr,unsigned int index); //LDT的安装

void add_gdt();              //GDT会从新加载的
void restart();              //模拟中断返回

void exit();
