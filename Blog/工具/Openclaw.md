---
weight: 100
title: Openclaw
slug: openclaw
summary: Openclaw
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-11T14:59:54+08:00
lastmod: 2026-03-11T15:17:32+08:00
---

## Ubuntu2204 部署

官方脚本如下:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

脚本提供了两种方法安装 openclaw: node 和 git

可以手动安装 nodejs 和 openclaw:

```bash
$ sudo curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

$ nvm install --lts

$ npm -v
11.9.0
$ node -v
v24.14.0
$ npm install -g openclaw@latest
```
