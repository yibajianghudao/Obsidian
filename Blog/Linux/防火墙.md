---
weight: 100
title: 防火墙
slug: 防火墙
summary: 防火墙
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-02-02T16:55:22+08:00
lastmod: 2026-02-02T16:55:22+08:00
---

## firewalld

查看开放的端口:

```bash
firewall-cmd --list-port
```

允许端口:

```bash
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --reload
```
