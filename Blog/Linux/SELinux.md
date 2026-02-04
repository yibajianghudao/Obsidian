---
weight: 100  
title: SELinux  
slug: selinux  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:36:48+08:00  
lastmod: 2026-02-02T16:56:06+08:00
---

## 关闭 selinux  

临时关闭  

```bash  
# 切换为 Permissive（警告模式，不拦截）  
sudo setenforce 0  
# 验证  
getenforce  
# 输出: Permissive  
```  

永久关闭  

```bash  
sudo vim /etc/selinux/config  
# 把enforcing改成disabled  
SELINUX=disabled  
sudo reboot  
```  

> 修改为 permissive 可以允许但保留日志
