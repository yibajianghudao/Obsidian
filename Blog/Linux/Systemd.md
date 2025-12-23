---
weight: 100
title: Systemd
slug: systemd
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-12-23T15:43:41+08:00
lastmod: 2025-12-23T15:46:25+08:00
---

## 模板文件
有一些单元的名称包含一个 `@` 符号（例如：`name@string.service`），这意味着它是模板单元 `name@.service` 的一个 [实例](https://0pointer.net/blog/projects/instances.html)，模板单元的实际文件名中不包括 `_string_` 部分（如 `name@.service`）。`_string_` 被称作实例标识符，在 _systemctl_ 调用模板单元时，会将其当作一个参数传给模板单元，模板单元会使用这个传入的参数代替模板中的 `%i` 指示符。在启动单元时，尝试从模板单元实例化之前，_systemd_ 会先检查 `name@string.suffix` 文件是否存在。如果存在，就直接使用这个文件，而不是模板实例化（不过，这种“碰撞”非常少见）。大多数情况下，包含 `@` 标记都意味着这个文件是模板。如果一个模板单元被调用时没有指定实例标识符，该调用通常会失败，除非是在某些特殊的*systemctl*命令（如`cat`）中使用。
