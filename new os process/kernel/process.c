/**
 * 主要处理进程信息的
 *
 * 王征 2014-02-05
 */
 
 #include "io.h"
 #include "process.h"
 #include "process_struct.h"
 #include "gloable.h"
 #include "unistd.h"
 /**
  * 思路有两种
  * 1.书上这个是进行初始化很多东西人后切换的
  * 2.也可以直接iret模拟返回过去就可以了
  * 3.用户权限的东西应该怎么搞？
  */
 
 /**
  *安装一个tss 信息基本是固定的
  *位置是从第六个开始的
  */
  void init_tss(){
  
    put_str("Init the tss!\r\n");
	
	memset_p((unsigned int)&tss,(unsigned int)0,(unsigned int)sizeof(tss));
	
	tss.ss0=0x0008;
	
	tss.iobase	=(unsigned short int)sizeof(tss);	/* 没有I/O许可位图 */

	short int index=pgdt;//得到当前的选择子个数
	
    make_gdt_description((unsigned int)&tss,sizeof(tss)-1,0x00408900,(index+1)/8);
   
	add_gdt();//从新挤在jdt
	
  }
  
 /**
  * 安装一个ldt
  * NR_TASKS 任务个数 
  * 当前的任务个数
  **/  
  void init_ldt(){
     
	 put_str("Init the LDT!\r\n");
	 
	if(proc_count<NR_TASKS){
	
	 proc_count++; //任务数+1
	 
	 //算出ldt->gdt的位置 
	 unsigned int ldt_position=LDT_BASIC+(proc_count-1)*8*2;
	
	 short int index=pgdt;
	 //ldt的个数有两个
     make_gdt_description(ldt_position,8*2-1,0x0040E200,(index+1)/8);//0x82
	 
	 //得到lldt的选择子 向左移动三位
	 //权限3 ldt的选择子
	 index=(((index+1)/8)<<3)|0x03;
	 
	 proc_table[proc_count-1].ldt_sel=index;
	 
	 proc_table[proc_count-1].ldt_sel_first=0x07;
	 proc_table[proc_count-1].ldt_sel_second=0x0F;
	 
	 //默认的标志状态为0
	 proc_table[proc_count-1].statu=0;
	 //安装两个ldt位置确定 从0开始的
	 make_ldt_description((unsigned int)0x0,0xFFFFF,0x00C0F800,(proc_count-1)*2);//代码
	 
	 make_ldt_description((unsigned int)0x0,0xFFFFF,0x00C0F200,((proc_count-1)*2+1));//数据
	 
	 add_gdt();
	 
	}else{
	  put_str("The process total is over!\r\n");
	} 
  }
  
  /*
  *一个测试进程
  */
 void test_pro_a(){
     //put_string("ok\r\n");
	 
	sys_put_str("A");
	 while(1){
	 int i=0,j=1;
	 for(;i<10000;i++){
	   for(;j<1000;j++){
	    sys_put_intln(j);
	   }
	 }
	}
    
 }
 
  void test_pro_b(){
     //put_string("ok\r\n");
	 
	sys_put_str("B");
	 while(1){
	 
	  int i=0,j=0;
	 for(;i<10000;i++){
	   for(;j<1000;j++){
	   
	   }
	 }
	 
	}
    
 }
//新添加任务的入口地址 
void init_process(unsigned int addr){

    //1.判断是否可以有条件分配
	//2.有了分配
	//3.没有了暂且什么也不做
	if(proc_count<NR_TASKS){
	    
    init_ldt();
	
	PROCESS *proc=&proc_table[proc_count-1]; 
	
	//目前是ldt的0 和 1 权限3级别 
	proc->registers.cs=0x07;
	proc->registers.ds=0x0F;
	proc->registers.es=0x0F;
	proc->registers.fs=0x0F;
	proc->registers.ss=0x0F;
	proc->registers.gs=0x0023;
	proc->registers.eip=addr;
    proc->registers.esp=(unsigned int)task_stack[proc_count-1]+TASK_STACK_LENGTH;//声明的数组
    proc->registers.eflags=0x1202; // IF=1, IOPL=1, bit 2 is always 1.
	   
	}else{
	  put_str("The process total is over!\r\n");
	}
} 

 /**
  * 实例化信息
  */
 void ini_process(){
	
	memset_p((unsigned int)proc_table,0,sizeof(PROCESS)*NR_TASKS);
	
	init_process((unsigned int)test_pro_a);
	
	init_process((unsigned int)test_pro_b);
	
	//init_process((unsigned int)test_pro_b);
	
	//init_process((unsigned int)test_pro_b);
	
	//init_process((unsigned int)test_pro_a);
	
	if(proc_count>0){
	
	  put_hexln(proc_count);
	  
	  proc_table[0].statu=1;
	  current_proc=&proc_table[0];
	  
	  put_str("Init a proc over!\r\n");
	  
	}else{
	  put_str("There is no task!\r\n");
	  exit();
	}
 }
 
 void change_proc(){
    //遍历得到整个进程 正在执行的状态为1
	int i=0,current=0;
	for(;i<proc_count;i++){
	 if(proc_table[i].statu==1){
		proc_table[i].statu=0;
		break;
	 }
	}
	   current=(i+1)%proc_count;
	   put_int(0); 
    	 proc_table[current].statu=1;
	  //下一个进程
	 current_proc=&proc_table[current];
	
 }
