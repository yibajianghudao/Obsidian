---
weight: 100
title: 通过Linux跳板机访问带外
slug: 通过linux跳板机访问带外
summary: 通过Linux跳板机访问带外
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-01-19T16:30:38+08:00
lastmod: 2026-01-19T16:36:02+08:00
---

需要访问一个服务器的带外,这个带外没有 windows 管理机 (与服务器同处于一个内网中),在 windows 管理机上可以直接通过 RDP 远程连接到 windows 管理机然后 [IE|通过IE浏览器访问带外](IE.md)

## 原方案

先远程连接到一台跳板机 (服务器 1):

```bash
ssh root@ip
```

然后在这个跳板机上运行一个 SOCKS 代理,将跳板机的 `7070` 端口代理到内网服务器 (服务器 2) ,内网服务器和要访问的带外处于同一内网中:

```bash
ssh -XY -vCNgD 0.0.0.0:7070   -o ServerAliveInterval=20 -o ConnectTimeout=60 -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o GSSAPIAuthentication=no -p 22 root@ip
```

然后通过一个软件**Proxifier**连接到服务器 1 的 `7070` 端口,接着就能在主机的浏览器上访问带外的 IP

## linux 替代方案

然而在 linux 上没有**Proxifier**这个软件,可以使用 `ssh` 隧道来代替:

首先还是在跳板机上运行一个 SOCKS 代理,然后在主机上运行:

```bash
ssh -N -L 7070:127.0.0.1:7070 root@ip
```

将跳板机的 `7070` 端口映射到本地的 `7070` 端口

然后在浏览器 (我这里是 firefox) 上设置代理为 SOCKS5,地址是 `127.0.0.1:7070`:

![](assets/通过Linux跳板机访问带外/-20260119161832107.png)

然后就能通过浏览器访问带外
