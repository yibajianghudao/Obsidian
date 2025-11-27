---
weight: 100  
title: 常见的网络端口  
slug: 常见的网络端口  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:33:10+08:00  
lastmod: 2025-11-20T09:33:10+08:00  
---
Web服务  
- HTTP: 80/tcp  
- HTTPS: 443/tcp,udp  
远程登录与连接  
- SSH: 22/tcp  
- Telnet: 23/tcp  
- RDP: 3389  
文件传输  
- FTP:  
	- 数据传输: 20/tcp  
	- 控制命令: 21/tcp  
- TFTP: 69/udp  
域名解析  
- DNS: 53/tcp,udp  
数据库服务:  
- MySQL/MariaDB: 3306/tcp  
- Oracle: 1521/tcp  
- SQL Server: 1433/tcp,1434/tcp  
- MongoDB: 27017/tcp  
- Redis: 6379/tcp  
容器编排:  
- Docker:  
	- 无TLS: 2375/tcp  
	- 有TLS: 2376/tcp  
- Kubernetes API服务器: 6443/tcp  
其他服务:  
- Nginx: 80/tcp,8080/tcp,443/tcp  
- SNMP: 161/udp,162/udp  
- Tomcat: 8080/tcp  
- Zabbix:  
	- Server: 10051/tcp  
	- Agent: 10050/tcp