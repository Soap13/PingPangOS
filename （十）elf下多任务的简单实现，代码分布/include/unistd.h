/**
 * 新添加的系统调用库表
 * 王征 2014-02-08
 */
 
 
#define _NR_PUT_STRING  0   //输出函数
#define _NR_EXIT        1   //程序终止


extern sys_put_string;     //输出 有个地址参数
extern sys_exit;           //终止程序







unsigned int sys_call[]={
                         sys_put_string,
						 sys_exit
                        };

//没有参数的
void sys_call_parameter0(int num){
  int void (*fn)();
  fn=sys_call[num];
  fn();
}

//有一个参数
void sys_call_parameter1(int unm,int par){
   int void (*fn)();
   fn=sys_call[num];
   fn(par); 
}





