---
weight: 100
title: Wayland
slug: wayland
summary: Wayland
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-04-10T11:31:51+08:00
lastmod: 2026-04-10T11:33:43+08:00
---

尝试在 linux mint 中启用 Wayland,fcitx5 遇到了一些问题,修改了环境变量,配置了 gtk 的几个设置 (fcitx5 wiki 都有) 之后,又把之前的旧配置覆盖过来才修好

然后是 firefox 问题,firefox 由于缩放问题导致切换到 wayland 后模糊,在 `about:config` 中修改 `widget.wayland.fractional-scale.enabled` 为 `false` 后解决,然后可以编辑 `layout.css.devPixelsPerPx` 手动修改缩放倍数,例如 `1.5` 是放大到 `150%`.

但是发现一些软件比如 vscode 发生了很严重的画面撕裂,最后还是换回了 x11.
