/**
 * 新添加的系统调用库表
 * 王征 2014-02-08
 */
  
#define _NR_PUT_STRING  0   //输出函数
#define _NR_EXIT        1   //程序终止

void sys_put_string();//系统输出函数别的地方不用

unsigned int sys_call_table[]={
                         (unsigned int)sys_put_string//函数输出
                        };





