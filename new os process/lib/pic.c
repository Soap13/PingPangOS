/**
 * 遍历PIC
 * 目的寻找网卡信息
 * 王征 2014-03-10
 */
 
 #include "io.h"
 #include "pci.h"
 
 /**
  * 总线数 0-4
  * 设备号 0-31
  * 功能好 0-8
  */
 void traversal_pic(){
    put_strln("This will traversal the pci");
    unsigned int busNo=0,deviceNo=0,funcNo=0; 
	unsigned int msg=0x00000000;
	unsigned int return_msg;
	DEVICE_STRUCT now_device;
	
    for(busNo=0;busNo<5;busNo++)
	    for(deviceNo=0;deviceNo<32;deviceNo++)
		   for(funcNo=0;funcNo<8;funcNo++){
		     msg= 0x80000000
			     +(busNo<<16)
			     +(deviceNo<<11)
				 +(funcNo<<8);
		     //向端口写数据
			 port_write(msg,0xCF8);
			 //向端口读信息数据
		     return_msg=port_read(0xCFC);
			 
			 //判断是否有效
			 //put_hex(return_msg);
			 if(return_msg!=0xFFFFFFFF){ //代表设别存在
			    now_device.vendorID=(return_msg & 0xffff);
				now_device.devID=(return_msg>>16 & 0xffff);
				
				msg=(msg&0xFFFFFFF0)+0x00000008; //读取空间偏移8H
				
			    port_write(msg,0xCF8);
		        return_msg=port_read(0xCFC);
				now_device.version=return_msg&0xff;
				
				now_device.class1=(return_msg>>8)&0xff;
				
				now_device.class2=(return_msg>>16)&0xff;
				now_device.class3=(return_msg>>24)&0xff;
				if(funcNo==0){
				msg=(msg&0xFFFFFFF0)+0x0000000C; ///读取空间偏移0CH
			     port_write(msg,0xCF8);
		         return_msg=port_read(0xCFC);
				 if((return_msg>>16)&0x80==0)funcNo=8;//单功能
				}
				//信息输出下来
			     put_hex(now_device.vendorID);
			     put_str("  ");
			     put_hex(now_device.devID);
			     put_str("  ");
			     put_hex(now_device.version);
			     put_strln(" ");
			 }
		   }
            put_strln("The traversal pci over");
 }