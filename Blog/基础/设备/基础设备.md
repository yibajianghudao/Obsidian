---
weight: 100
title: 基础设备
slug: 基础设备
summary: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true  
date: 2025-11-20T09:17:03+08:00  
lastmod: 2026-01-15T14:17:08+08:00
---
## 服务器  
服务器指的是在网络环境中为客户机(client)提供各种服务的、特殊的专用计算机。在网络中，服务器承担着数据的存储、转发、发布等关键任务  
- 从广义上讲，服务器是指网络中能对其他机器提供某些服务的计算机系统。  
- 从狭义上来讲，服务器是专指某些高性能计算机，能够通过网络，对外提供服务。  
### U位  
U是一种表示服务器外部尺寸的单位，是unit的缩略语。规定了服务器的尺寸.  
1U=4.445cm  
## 交换机  
交换机是一种为所连接的IT设备提供网络通信的设备  
主要作用是转发传输数据,实现网络设备之间的通信互联,主要功能包括:  
- 对网段进行分段和隔离,划分多个虚拟网段,提高网络安全性  
- 识别接收到的数据,精准向目标设备转发,提高网络性能  
- 对不同端口,用户,应用进行浏览控制和管理  
- 优化数据传输方式,提高传输速率  
交换机对数据包的转发是建立在物理地址(MAC地址)基础上的,交换机在转发数据包时,不知道目标主机和源主机的IP地址,只需要知道其MAC地址  
交换机在工作过程中会维护一个MAC地址表,它仅仅说明了某个MAC地址是在哪个端口上被发现的  
![](assets/基础设备/交换机-20251022161329258.png)  
当交换机收到一个TCP/IP数据包时，会先确认是否为广播数据包，如果是则将数据包广播到所有端口；如果不是则会在MAC地址表中查询目的MAC，以确认应该从哪个端口把数据包发出去（如果目的MAC地址与源MAC地址相同，会被视为无效数据包并丢弃）。  
如果目的MAC地址不能在地址表中找到时，交换机会如同处理广播数据包一样，把该数据包从接收端口除外的所有端口转发出去。对应端口回应后交换机会“学习”新的MAC地址，把新的MAC地址添加到MAC地址表中。  
## 路由器  
路由器是一个链接两个或多个网络的设备。接收数据后，路由器会先依据路由表找出通往目的IP地址的最短路径，然后转发到下一地址。  
路由器和交换机都可以在网络中传送转发数据，但是两者之间也有一定的区别:  
- 交换机主要功能是用于数据交换，路由器主要功能是用于路由转发。  
- 交换机根据MAC地址进行数据转发，而路由器是根据IP地址进行数据转发。  
- 路由器能在多条路径中选择最佳的路径，提升交换数据的传输速率。  
## 集线器  
集线器（Hub）是指将多条以太网双绞线或光纤集合连接在同一段物理介质下的设备。Hub有多个I/O端口，信号由任一端口进入后，经过再生或放大转发至其他所有端口。  
Hub无法储存数据，在接收之后必须立刻转发，所以在转发数据时需要进行冲突检测，防止产生冲突导致数据包丢弃。基于此，Hub只能以**半双工模式**工作。  
## 查看设备详情  
windows-server:  
```  
systeminfo  
系统制造商:         HP  
系统型号:           HP ProBook 445 14 inch G11 Notebook PC  
```  
Linux:  
```  
$ sudo dmidecode -t system  
Handle 0x0001, DMI type 1, 27 bytes  
System Information  
        Manufacturer: VMware, Inc.  
        Product Name: VMware Virtual Platform  
```  
也可以直接查看文件:  
```  
newuser@ubuntu22:~$ cat /sys/class/dmi/id/sys_vendor  
VMware, Inc.  
newuser@ubuntu22:~$ cat /sys/class/dmi/id/product_name  
VMware Virtual Platform  
newuser@ubuntu22:~$ cat /sys/class/dmi/id/product_name  
VMware Virtual Platform  
```  
还可以使用`lshw`命令:  
```  
newuser@ubuntu22:~$ sudo lshw -class system  
ubuntu22  
    description: Computer  
    product: VMware Virtual Platform  
    vendor: VMware, Inc.  
```