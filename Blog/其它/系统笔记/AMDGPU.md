---
weight: 100
title: AMDGPU
slug: amdgpu
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-12-16T15:20:24+08:00
lastmod: 2025-12-16T15:20:24+08:00
---

我的电脑最近在编辑文档的时候经常崩溃，最初我以为是`kate`编辑器的问题，然后换了`gedit`，甚至是`neovim`，都发生了崩溃，似乎经常发生在复制或粘贴的时候。  
电脑直接卡死，重启后看到了一些日志:
```
12月 16 14:59:32 HPLinuxMint kernel: amdgpu 0000:04:00.0: [drm] *ERROR* [CRTC:79:crtc-0] flip_done timed out
12月 16 14:59:25 HPLinuxMint kernel: [UFW BLOCK] IN=enp1s0 OUT= MAC=01:00:5e:00:00:fb:5e:64:27:db:41:82:08:00 SRC=192.168.88.118 DST=224.0.0.251 LEN=32 TOS=0x00 PREC=0x00 TTL=1 ID=16456 PROTO=2 
12月 16 14:59:21 HPLinuxMint kernel: amdgpu 0000:04:00.0: [drm] *ERROR* dc_dmub_srv_log_diagnostic_data: DMCUB error - collecting diagnostic data
```
尝试搜索了一下，搜到了这两个帖子：  
- [](https://bbs.archlinux.org/viewtopic.php?id=302499)
- [](https://community.frame.work/t/system-gets-really-slow/61854)

打算先试一试`amdgpu.dcdebugmask=0x10`内核参数