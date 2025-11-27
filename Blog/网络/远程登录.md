---
weight: 100  
title: 远程登录  
slug: 远程登录  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:33:23+08:00  
lastmod: 2025-11-20T09:34:14+08:00  
---
## SSH  
SSH(Secure Shell)主要用于Linux操作系统远程登录  
- 强身份验证,基于密码或密钥的身份验证  
- 对传输数据进行加密  
- 通常用于网络设备和系统的安全远程管理  
- SSH 是一种在不安全的网络上提供安全加密通道的协议  
- 支持SCP或SFTP进行文件传输  
## Telnet  
- 专为局域网设计  
- 以纯文本传输数据  
- 没有身份验证策略  
- 不提供文件传输  
## RDP  
- 远程控制  
- 使用TLS/SSL加密  
- 使用压缩和优化技术减少带宽占用  
- 支持多用户同时连接  
## VNC  
VNC是一种屏幕画面分享及远程操作软件。此软件借由网络，可发送键盘与鼠标的动作及即时的屏幕画面。  
- 跨平台使用  
- 需要密码,数据传输经过加密但并不安全,可设计使用SSH/VPN传输  
- 需要桌面环境  
## Console线  
可以使用Console线通过Concole口登录交换机:  
前置条件:  
1. 准备PC,Console线(可能需要USB转DB-9串口转接线)  
2. 将Console线的DB9孔插头插入PC机的串口(COM)中,再将RJ-45端插入交换机的Console中  
3. 通过计算机的设备管理器-端口(COM和LPT) 查看PC上串口的通信端口号,例如COM1  
可以使用PuTTY进行连接:  
![](assets/远程登录/Console线-20251022170440151.png)  
在Session - Connection type中选择`Serial`  
在Connection - Serial 中配置通信参数,例如对于下面的交换机参数:  
| 参数                 | 值         |  
| ------------------ | --------- |  
| 传输速率(Speed)        | 9600bit/s |  
| 流控方式(Flow control) | 不进行流控     |  
| 校验方式(Parity)       | 不进行校验     |  
| 停止位(Stop bits)     | 1         |  
| 数据位(Data bits)     | 8         |  
应该配置为:  
![](assets/远程登录/Console线-20251022170825920.png)