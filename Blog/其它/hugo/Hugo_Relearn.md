---
weight: 100  
title: Hugo_Relearn  
slug: hugo-relearn  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T10:25:16+08:00  
lastmod: 2025-12-25T17:02:05+08:00
---
### 显示代码文件  
参考[# Hugo Shortcode 渲染外部代码和文件](https://blog.lockshell.com/posts/hugo-shortcode-render-external-file/)  
把代码从文件中读取并渲染在页面上,使用[hugo shortcode](https://gohugo.io/content-management/shortcodes)实现  
在hugo仓库根目录下新建`layouts/shortcodes/code.html`,写入:  
```  
{{- /* 获取传入的相对路径，比如 assets/Smokeping/readTitleHostFromXLSX.py */ -}}  
{{- $relPath := .Get "file" -}}  
{{- /* 代码语言，默认 text，可以传 python/js 等 */ -}}  
{{- $lang := .Get "language" | default "text" -}}  
{{- /* 当前页面所在目录，比如 content/Blog/中间件/Smokeping/ */ -}}  
{{- $pageDir := .Page.File.Dir -}}  
{{- /* 拼出实际文件路径 */ -}}  
{{- $fullPath := printf "%s%s" $pageDir $relPath -}}  
{{- /* 读文件内容 */ -}}  
{{- $content := readFile $fullPath -}}  
{{- /* 包一层 Markdown 三引号代码块，再交给 markdownify 渲染 */ -}}  
{{- (print "```" $lang "\n" $content "\n```") | markdownify -}}  
```  
然后在文章中按照下面的格式导入即可:  
```  
{{</* code file="assets/Smokeping/readTitleHostFromXLSX.py" language="python" */>}}  
```  
> 实际上如果在文章中也按照上面显示的格式写,会被hugo错误的解释为读取一个不存在的py文件,并导致显示出现错误,因此上面的代码在文件中写的其实是:  
> ```  
> {{</*/* code file="assets/Smokeping/readTitleHostFromXLSX.py" language="python" */*/>}}  
> ```  
### 行末添加空格  
在Obsidian中默认的回车会被渲染为换行,而在hugo中两个空格后的回车才被显示为换行
在Obsidian的设置中可以设置严格换行,但只在源码模式中有效(切换为阅读视图时严格换行),在实时预览模式下无效  
可以安装[增强编辑](https://github.com/obsidian-canzi/Enhanced-editing)插件  
首先在第三方插件搜索[BRAT](https://github.com/TfTHacker/obsidian42-brat)插件并安装,然后在其中添加增强编辑插件(输入仓库url即可)  
![](assets/Hugo_Relearn/行末添加空格-20251122140923857.png)  
### 顺序  
hugo的目录和文件都有一个`weight`属性,这个数字越小,目录或文件的顺序越靠前

### 文章标题格式转换
Obsidian有一个好用的功能是关系图谱，使用它可以很容易的查看到文章直接的关系，在文章引用其他文章也可以复用重复的操作笔记，比如为`ubunut`配置软件源。  
但是Obsidian默认的wiki式的链接不能被Hugo框架读取，似乎有一个[开源项目](https://github.com/devidw/obsidian-to-hugo)做了这样的转换，我没有仔细研究，我在配置图片的时候就已经关闭了wiki短链接，而是使用markdown原格式，一个文件链接类似于这样:
```
[显示文字](文章名.md#标题名)
```
默认情况下在Obsidian输入两个`[`就会有弹窗可以很方便的链接其他文章，但是Obsidian链接的标题格式和hugo将标题转换为的url格式有很大区别，一个表格如下:  
```
文章源标题			Obsidian引用					Hugo转换后url标题

,.[]命令#-			,.[]命令%20-					命令-
WS WPS ''""			WS%20WPS%20''""				ws-wps-
LINUX-LINUX			LINUX-LINUX					linux-linux
UbunTTU -- 24141	UbunTTU%20--%2024141		ubunttu--24141
CentoU --- 24141 	CentoU%20---%2024141		centou--24141
ARCH---24141		ARCH---24141				arch24141
ROCKy ----- 24141 	ROCKy%20-----%2024141		rocky--24141
```
虽然脚本已经尽可能做到适配，但是有以下问题无法解决，是由于Obsidian自身链接过程中丢失了原标题内容的信息，因此无法被脚本读取到，只能尽量避免使用:
1. 标题内使用`#`,Obsidian的链接会将`#`转换为`%20`(和空格一样)
2. 标题内使用两个及以上连续的空格,Obsidian的链接会将两个以上的空格合并为一个，而hugo没有合并
