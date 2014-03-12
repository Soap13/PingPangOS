//字符串输出
void put_str(char *message);
void put_strln(char *message);

void put_int(int number);
void put_intln(int number);

void put_hex(int number);
void put_hexln(int number);


//系统函数
void sys_put_str(char *message);
void sys_put_strln(char *message);

void sys_put_int(int number);
void sys_put_intln(int number);

void sys_put_hex(int number);
void sys_put_hexln(int number);

//端口的读写操作
unsigned int port_read(unsigned int port);
void port_write(unsigned int msg,unsigned int port);