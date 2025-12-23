---
weight: 100
title: Docker
slug: docker
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-12-19T10:04:40+08:00
lastmod: 2025-12-19T11:09:45+08:00
---

## 安装
### CentOS7
```
# 安装阿里云的docker-ce源
curl -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 清理旧缓存,生成新缓存
sudo yum clean all
sudo yum makecache fast

# 安装docker-ce 24.0.7版本
yum install -y docker-ce-24.0.7-1.el7 docker-ce-cli-24.0.7-1.el7 containerd.io
```