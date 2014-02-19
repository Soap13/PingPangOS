/**
 *对输出的转换
 */

void put_string(char *message);
//===========================================
/**
 *输出字符串
 */
void put_str(char *message){
  put_string(message);
}

/**
 *输出字符串换行
 */
void put_strln(char *message){
  put_string(message);
  put_string("\r\n");
}

/**
 *输出整形数字
 */
void put_int(int number){
  
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
  
  put_str(p-count);
}

void put_intln(int number){
  put_int(number);
  put_str("\r\n");
}
/**
 *输出十六进制
 */
void put_hex(int  number){
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
  
  put_str(message);
}
void put_hexln(int num){
 put_hex(num);
 put_str("\r\n");
}