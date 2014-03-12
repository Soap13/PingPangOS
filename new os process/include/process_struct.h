/**
 * 进程保存的结构体
 * 内容就是寄存器的顺序
 * 王征 2014-02-05
 */
 

 /**
  *寄存器信息
  */
typedef struct process_stack_msg {	/* proc_ptr points here				↑ Low			*/
	unsigned int	gs;		/* ┓						│			*/
	unsigned int	fs;		/* ┃						│			*/
	unsigned int	es;		/* ┃						│			*/
	unsigned int	ds;		/* ┃						│			*/
	unsigned int	edi;		/* ┃						│			*/
	unsigned int	esi;		/* ┣ pushed by save()				│			*/
	unsigned int	ebp;		/* ┃						│			*/
	unsigned int	kernel_esp;	/* <- 'popad' will ignore it			│			*/
	unsigned int	ebx;		/* ┃						↑栈从高地址往低地址增长*/		
	unsigned int	edx;		/* ┃						│			*/
	unsigned int	ecx;		/* ┃						│			*/
	unsigned int	eax;		/* ┛						│			*/
	unsigned int	retaddr;	/* return address for assembly code save()	│			*/
	unsigned int	eip;		/*  ┓						│			*/
	unsigned int	cs;		/*  ┃						│			*/
	unsigned int	eflags;		/*  ┣ these are pushed by CPU during interrupt	│			*/
	unsigned int	esp;		/*  ┃						│			*/
	unsigned int	ss;		/*  ┛						┷High			*/
}PROCESS_STACK;

/**
 *进程信息
 */
typedef struct process_msg{

 PROCESS_STACK registers; //寄存器信息 
 
 unsigned  int ldt_sel; //gdt-ldt选择子
 
 unsigned  int ldt_sel_first;  //ldt 第一个code 
 unsigned  int ldt_sel_second; //ldt 第二个是数据的
 
 unsigned  int statu;               //状态信息
 
 unsigned int pid;                       //进程信息的编号
 char name[16];                          //进程的名称
}PROCESS; 


/**
 * TSS信息
 */
typedef struct tss_msg {
	unsigned int	backlink;
	unsigned int	esp0;		/* stack pointer to use during interrupt */
	unsigned int	ss0;		/*   "   segment  "  "    "        "     */
	unsigned int	esp1;
	unsigned int	ss1;
	unsigned int	esp2;
	unsigned int	ss2;
	unsigned int	cr3;
	unsigned int	eip;
	unsigned int	flags;
	unsigned int	eax;
	unsigned int	ecx;
	unsigned int	edx;
	unsigned int	ebx;
	unsigned int	esp;
	unsigned int	ebp;
	unsigned int	esi;
	unsigned int	edi;
	unsigned int	es;
	unsigned int	cs;
	unsigned int	ss;
	unsigned int	ds;
	unsigned int	fs;
	unsigned int	gs;
	unsigned int	ldt;
	unsigned short int 	trap;
	unsigned short int	iobase;	/* I/O位图基址大于或等于TSS段界限，就表示没有I/O许可位图 */
	/*t_8	iomap[2];*/
}TSS; 

 //进程总的个数 根据这个开放ldt的个数
 #define NR_TASKS 5
 //进程表
 PROCESS  proc_table[NR_TASKS];
 
 PROCESS  *current_proc;
 
 //当前的任务个数
 unsigned int proc_count=0;
 
 //声明一个TSS
 TSS tss;
 
 //堆栈声明的
 #define TASK_STACK_LENGTH 512
 char task_stack[NR_TASKS][TASK_STACK_LENGTH]={0};