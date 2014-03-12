//系统函数
void sys_put_str(char *message);
//===========================================

/**
 *输出字符串换行
 */
void sys_put_strln(char *message){
  sys_put_str(message);
  sys_put_str("\r\n");
}

/**
 *输出整形数字
 */
void sys_put_int(int number){
  
  char *p=0;
  char leave=0;
  int count=0,length=1;
  
  
  while(number!=0){
  
    leave=(number%10) & 0xFF; //余数
	
	number/=10;
	
	leave+='0';
	
    *p++ =leave;
	count++;
  }
  
 
    *p=0;  
 
  while(count/2>=length){
    leave=*(p-count+length-1);
	*(p-count+length-1)=*(p-length);
	*(p-length)=leave;
	length++;
  } 
  
  sys_put_str(p-count);
}

void sys_put_intln(int number){
  sys_put_int(number);
  sys_put_str("\r\n");
}
/**
 *输出十六进制
 */
void sys_put_hex(int  number){
  char *message=0,*p=0;
  int i=0;
  char ch=0;
  
  message=p;
  *p++='0';
  *p++='x';
  
  if(number==0){
  *p++='0';
  }else{
   for(i=28;i>=0;i-=4){
    ch = (number >> i) & 0xF;
    ch+='0';
	if(ch>'9'){
	ch+=7;
	}
	*p++=ch;
   }
   *p++=0;
  }
  
  sys_put_str(message);
}
void sys_put_hexln(int num){
 sys_put_hex(num);
 sys_put_str("\r\n");
}