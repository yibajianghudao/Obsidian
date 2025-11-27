---
weight: 100  
title: 修改密码  
slug: 修改密码  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:36:03+08:00  
lastmod: 2025-11-20T09:41:42+08:00  
---
## 正常修改密码  
### Windows  
使用`net`命令:  
```  
net  
此命令的语法是:  
NET  
    [ ACCOUNTS | COMPUTER | CONFIG | CONTINUE | FILE | GROUP | HELP |  
      HELPMSG | LOCALGROUP | PAUSE | SESSION | SHARE | START |  
      STATISTICS | STOP | TIME | USE | USER | VIEW ]  
net user administrator 123456  
```  
Linux  
使用`passwd`命令  
```  
passwd 参数 用户名  
# 修改本用户密码  
passwd  
# 修改其他用户密码  
passwd user1  
```  
如果`sudo`命令没有配置禁止`/usr/bin/passwd`命令,则拥有sudo权限的用户可以通过`sudo passwd`修改root用户密码  
## 忘记密码后重置密码  
### Linux  
#### 启动条目:  
- 64 位 IBM Power 系列: `linux` 行  
- 基于 x86-64 BIOS 的系统: `linux16` 行  
- UEFI 系统: `linuxefi` 行  
#### 使用bash作为init  
重启操作系统,在grub引导页面,按`e`进入编辑模式,将`init=/bin/bash`附加到[[修改密码#启动条目]]  
然后按`ctrl+x`启动系统:  
![](assets/修改密码/使用bash作为init-20251022174003651.png)  
现在操作系统以单用户模式启动,以只读方式挂载root文件系统,需要重新挂载为读写方式:  
```  
mount -n -o remount,rw /  
```  
使用`passwd`命令为root用户创建新密码  
判断SELINUX是否启动:  
```  
cat /etc/selinux/config  
```  
观察`SELINUX`字段的值,如果是`enforcing`或`permissive`,需要创建自动重新标记文件  
```  
touch /.autorelabel  
```  
> 如果不创建自动标记文件,重启后可能会卡死  
最后使用`exec /sbin/init`或`reboot -f`重新启动  
参考[更改和重置Root密码](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/system_administrators_guide/ch-working_with_the_grub_2_boot_loader#sec-Changing_and_Resetting_the_Root_Password)  
#### 使用debug shell  
可以使用下面两种方法进入**debug shell**  
1. 在[[修改密码#启动条目]]上添加:`systemd.debug-shell`  
2. 需要一个具有sudo权限的用户,使用该用户启动`debug-shell.service`  
然后切换到tty9中(ctrl + alt + 9)运行`passwd`  
![](assets/修改密码/使用debug%20shell-20251023094830572.png)  
运行完后停止`debug-shell.service`并回到其他tty即可.  
此方法不需要关闭SELinux,并且修改完root密码后立即生效