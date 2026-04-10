---
weight: 100  
title: 题目  
slug: 题目  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:32:50+08:00  
lastmod: 2025-11-22T13:58:31+08:00
---
### Linux  
### 如何配置SSH允许Root远程登陆  
1. 确保`openssh-server`包已安装且正常运行  
2. 在配置文件中编辑`PermitRootLogin yes`允许Root登录 和 `PasswordAuthentication yes`允许密码登录  
3. 在实际工作中一般还要修改Root的登陆端口`Port 22`  
## Nginx  
### 正向代理和反向代理的区别  
正向代理是客户端的代理，它隐藏了客户端的真实IP，反向代理是服务端的代理，他隐藏了服务端的真实IP。  
例如位于百度服务器的Nginx服务器就是反向代理，而位于公司内网的上网代理服务器就是正向IP  
### Nginx如何配置正向代理  
首先需要设置服务监听的端口`listen 8080`  
然后设置DNS解析器`resolver 114.114.114.114;`  
然后对所有请求进行代理,指向原来的请求地址:  
```nginx  
location / {  
	proxy_pass http://$http_host$request_uri;  
	proxy_set_header Host $http_host;  
	proxy_set_header X-Real-IP $remote_addr;  
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  
	}  
```  
### Nginx如何配置SSL  
Nginx配置SSL主要是为了启用HTTPS,实现网站流量的加密,保证数据安全,在配置之前我们需要两个核心文件:  
- SSL证书文件(通常以`.crt`或`rpm`结尾)  
- SSL私钥文件(通常以`.key`结尾)  
这些文件可以从云服务商获取,也可以从一些CA机构申请,其中私钥文件一般需要设置权限为`600`  
在Nginx的配置文件中,在`server`块的`listen`端口修改为`443`,并且结尾加上`ssl`以启用SSL模块,`server_name`可以换成域名  
然后再指定证书和私钥的绝对路径  
- `ssl_certificate /etc/nginx/ssl/domain.com.crt;`  
- `ssl_certificate_key /etc/nginx/ssl/domain.com.key;`  
```nginx  
server {  
    listen 443 ssl; # 在443端口监听，并启用ssl模块  
    server_name yourdomain.com www.yourdomain.com; # 域名  
    # 指定证书和私钥的路径（绝对路径）  
    ssl_certificate /etc/nginx/ssl/yourdomain.com.crt;  
    ssl_certificate_key /etc/nginx/ssl/yourdomain.com.key;  
    # 其他常规配置，比如网站根目录  
    root /var/www/html;  
    index index.html index.htm;  
    # ... 其他location配置等  
}  
```  
另外,最好在原本的HTTP`server`块中做一个重定向,把80端口的流量自动跳转到443端口  
```nginx  
server {  
    listen 80;  
    server_name yourdomain.com www.yourdomain.com;  
    # 301永久重定向到HTTPS版本  
    return 301 https://$server_name$request_uri;  
}  
```  
## 错误排查  
### 如何排查高负载  
首先使用`top`命令,查看几个关键指标:  
1. `Load Average`(平均负载): 这三个数字是负载的直接体现,一般来说,平均负载高于cpu核心数,就说明系统过载  
2. CPU使用率:  
	1. `%us`(user): 用户空间占用,如果这个值很高,通常是应用程序自身的问题  
	2. `%sy`(system): 内核空间进程占用,如果这个值很高,可能是系统调用频繁,或者上下文切换过多  
	3. `%wa`(wait I/O): IO等待,如果这个值很高,说明CPU在等待磁盘IO,瓶颈在磁盘  
3. 内存使用率: 查看还有多少可用内存,以及swap分区是否被使用.如果swap频繁被读写,会引发严重的IO等待,导致负载飙升  
如果是cpu问题,我需要按`P`按照cpu使用率排序,或使用`ps`命令查看是哪个进程消耗CPU较多,找到进程之后结合业务进行分析,比如:  
- 如果是java应用,可能代码遇到了死循环  
- 如果是PHP/Python应用,可能遇到了计算密集型任务  
- 如果是数据库,可能是慢查询突然增多  
如果`%wa`很高,证明遇到了IO瓶颈,可以使用`iostat`命令查看磁盘的详细指标,重点关注:  
- `%util`: 设备的繁忙程度,接近%100代表设备IO饱和了  
- `await`: IO请求的平均等待时间,这个值越大,说明磁盘越慢  
- `r/s,w/s`: 每秒的读写请求数  
还可以使用`iotop`命令直接查看是哪个进程占用IO资源比较多  
常见的磁盘IO瓶颈:  
- 数据库正在执行大的全表扫描或没有索引的查询  
- 应用程序正在频繁的读写日志或日志级别设置不当  
- 系统正在进行大量的文件拷贝或压缩  
- 内存不足导致swap被频繁调用  
内存不足虽然不会直接引起负载过高,但也可能因为`swap`分区的使用导致磁盘IO等待,间接导致高负载,可以使用:  
- `free -m`查看内存和swap的使用情况  
- `vmstat 1 5` 关注`si`(swap in)和`so`(swap out)两列.如果他们持续大于0,表示内存压力大,系统在频繁使用swap  
找到消耗资源的进程后,还需要结合业务进行分析  
- 查看应用日志,在高负载的时间点有没有报错,有没有特别多的请求  
- 查看系统日志,`dmesg`查看有没有内存溢出的错误  
- web服务器查看并发连接数  
- 数据库服务器查询慢连接日志  
## 监控  
### Zabbix是什么  
Zabbix是一个企业级的、开源的、分布式监控解决方案。它能监控各种网络参数,保证服务器,服务,应用的的健康状态,并在发生故障时及时告警  
监控对象: 服务器(CPU,内存,磁盘,网络),网络设备(交换机,路由器),应用服务(Web服务,数据库)  
核心功能: 数据采集->数据存储->告警通知->可视化展示  
核心组件: Zabbix Server,Zabbix agent,webUI