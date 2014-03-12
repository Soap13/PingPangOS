 /**
  * 王征 2014-03-12
  * PCI结构体声明
  */
 
 
 typedef struct device{
        unsigned short int vendorID;//供应商代码
		unsigned short int devID;   //设备标示
		unsigned short int version; //版本号
		unsigned short int class1;  //分类1
		unsigned short int class2;  //分类2
		unsigned short int class3;  //分类3
		unsigned short int funcNo; //单多功能
		unsigned short int headType; //投标类型
 }DEVICE_STRUCT;