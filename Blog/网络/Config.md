---
weight: 100  
title: OAuth  
slug: oauth  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:33:32+08:00  
lastmod: 2025-11-20T09:33:32+08:00  
---

## Linux内核配置
### IPV4转发
检查IPv4转发是否开启:
```
sysctl net.ipv4.ip_forward
```
如果输出是 net.ipv4.ip_forward = 0，则说明转发被关闭了。
```
# 临时开启：
$ sudo sysctl -w net.ipv4.ip_forward=1

# 永久开启：
$ vim /etc/sysctl.conf

net.ipv4.ip_forward=1

# 生效
$ sudo sysctl -p
```
