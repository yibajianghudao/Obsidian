---
weight: 100  
title: ch341驱动  
slug: ch341驱动  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:36:36+08:00  
lastmod: 2025-11-20T09:36:36+08:00  
---
尝试在linux上通过USB转UART线(芯片ch341)连接交换机,发现能够正常连接但是效果不理想,无法正常使用,漏字,循环滚动输出等等  
```  
# 可以看到是ch341芯片  
dmesg | grep tty  
[    0.088775] printk: legacy console [tty0] enabled  
[    2.716934] ch341-uart ttyUSB0: break control not supported, using simulated break  
[    2.716990] usb 3-2: ch341-uart converter now attached to ttyUSB0  
```  
尝试使用:  
- minicom  
- screen  
- putty  
进行连接,效果均不理想,怀疑是芯片驱动的问题  
## 编译新驱动  
找到一个[驱动项目](https://github.com/WCHSoftGroup/ch341ser_linux)尝试编译:  
``` shell  
$ make  
make -C /lib/modules/6.14.0-33-generic/build  M=/home/mintuser/Code/driver/ch341ser_linux/driver  
make[1]: Entering directory '/usr/src/linux-headers-6.14.0-33-generic'  
make[2]: Entering directory '/home/mintuser/Code/driver/ch341ser_linux/driver'  
warning: the compiler differs from the one used to build the kernel  
  The kernel was built by: x86_64-linux-gnu-gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0  
  You are using:           gcc-13 (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0  
  CC [M]  ch341.o  
ch341.c:58:10: fatal error: asm/unaligned.h: No such file or directory  
   58 | #include <asm/unaligned.h>  
      |          ^~~~~~~~~~~~~~~~~  
compilation terminated.  
make[4]: *** [/usr/src/linux-headers-6.14.0-33-generic/scripts/Makefile.build:207: ch341.o] Error 1  
make[3]: *** [/usr/src/linux-headers-6.14.0-33-generic/Makefile:1997: .] Error 2  
make[2]: *** [/usr/src/linux-headers-6.14.0-33-generic/Makefile:251: __sub-make] Error 2  
make[2]: Leaving directory '/home/mintuser/Code/driver/ch341ser_linux/driver'  
make[1]: *** [Makefile:251: __sub-make] Error 2  
make[1]: Leaving directory '/usr/src/linux-headers-6.14.0-33-generic'  
make: *** [Makefile:7: default] Error 2  
```  
这是由于linux内核`6.12`版本将`asm/unaligned.h`迁移到了`linux/unaligned.h`,参考这个[pr](https://github.com/gnif/vendor-reset/pull/86)  
只需要手动将`ch341.c`中的`#include <asm/unaligned.h>`修改为`#include <linux/unaligned.h>`即可  
```shell  
$ ls  
ch341.c  ch341.ko   ch341.mod.c  ch341.o   modules.order  
ch341.h  ch341.mod  ch341.mod.o  Makefile  Module.symvers  
```  
编译完成之后有了`ch341.ko`文件,将该模块加载即可  
### 加载模块  
linux内核2.6.24版本内置了`ch341`的模块,该应该应该默认处于启动状态:  
```  
$ lsmod | grep ch341  
ch341                  24576  1  
usbserial              69632  3 ch341  
```  
通过`modinfo`可以看到它位于`/lib/modules/6.14.0-33-generic/kernel/drivers/usb/serial/ch341.ko.zst`  
```  
$ modinfo ch341 | grep filename  
filename:       /lib/modules/6.14.0-33-generic/kernel/drivers/usb/serial/ch341.ko.zst  
```  
首先需要卸载该模块:  
```  
# 这是由于没有拔除usb转换器,该模块正在使用,上面的lsmod命令也显示ch341在使用(1)  
$ sudo rmmod ch341  
rmmod: ERROR: Module ch341 is in use  
# 拔出usb转换器之后显示未在使用  
$ lsmod | grep ch341  
ch341                  24576  0  
usbserial              69632  1 ch341  
# 卸载模块  
$ sudo rmmod ch341  
$ sudo rmmod usbserial  
# 重新插入之后发现模块被自动加载但是没有使用  
$ lsmod | grep ch341  
ch341                  24576  0  
usbserial              69632  1 ch341  
# 再次卸载  
$ sudo rmmod ch341  
$ sudo rmmod usbserial  
# 验证卸载  
$ lsmod | grep ch341  
# 加载模块  
$ sudo insmod ./ch341.ko  
# 查看日志发现使用的新模块  
$ dmesg | tail  
[ 1199.594373] usbserial: USB Serial deregistering driver generic  
[ 1199.594501] usbcore: deregistering interface driver usbserial_generic  
[ 1210.906338] [UFW BLOCK] IN=wlp2s0 OUT= MAC=01:00:5e:00:00:01:3c:6a:48:b7:af:03:08:00 SRC=192.168.88.93 DST=224.0.0.1 LEN=32 TOS=0x00 PREC=0xC0 TTL=1 ID=0 DF PROTO=2  
[ 1212.085093] ch341: loading out-of-tree module taints kernel.  
[ 1212.085106] ch341: module verification failed: signature and/or required key missing - tainting kernel  
[ 1212.086318] usb_ch341 3-2:1.0: ttyCH341USB0: ch341 USB device  
[ 1212.086578] usbcore: registered new interface driver usb_ch341  
[ 1212.086586] ch341: USB serial driver for ch340, ch341, etc.  
[ 1212.086589] ch341: V1.8 On 2024.08  
[ 1214.297397] [UFW BLOCK] IN=wlp2s0 OUT= MAC=01:00:5e:00:00:fb:00:e0:1a:cf:17:05:08:00 SRC=192.168.88.133 DST=224.0.0.251 LEN=32 TOS=0x00 PREC=0x00 TTL=1 ID=60854 PROTO=2  
# 验证是否使用的是新模块  
$ cat /sys/module/ch341/version 2>/dev/null || echo "(no MODULE_VERSION)"  
V1.8 On 2024.08  
$ modinfo -F version ./ch341.ko 2>/dev/null || true  
V1.8 On 2024.08  
```  
观察`dmesg`日志可以看到现在的端口变成了`ttyCH341USB0`  
```  
dmesg | grep tty  
[ 1159.433898] ch341-uart ttyUSB0: break control not supported, using simulated break  
[ 1159.434136] usb 3-2: ch341-uart converter now attached to ttyUSB0  
[ 1198.110685] ch341-uart ttyUSB0: ch341-uart converter now disconnected from ttyUSB0  
[ 1212.086318] usb_ch341 3-2:1.0: ttyCH341USB0: ch341 USB device  
```  
现在可以通过下面三种方法连接:  
- `sudo minicom -s`配置完后连接  
- `sudo screen /dev/ttyCH341USB0 9600`  
- 使用putty gui界面配置并连接,参考[如何通过Console口连接并登录交换机](https://info.support.huawei.com/hedex/api/pages/EDOC1100413637/FZN1022J/01/resources/zh-cn_topic_0292458968.html)  
实际测试发现效果也不理想,screen效果好一些,其他两个依旧几乎无法使用,putty的效果最差