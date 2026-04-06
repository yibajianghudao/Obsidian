---
weight: 100
title: npm
slug: npm
summary: npm
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-12T15:02:21+08:00
lastmod: 2026-03-12T15:04:56+08:00
---

## 使用代理安装软件包

正常情况下直接使用镜像源：

```bash
npm install -g packagename --registry=https://registry.npmmirror.com
```

但有些软件包的依赖项是直接去 github 下载，此时可以使用 [github 代理](https://gh-proxy.com/) 加速：

```bash
git config --global url."https://hk.gh-proxy.org/https://github.com/".insteadOf "https://github.com/"
```
