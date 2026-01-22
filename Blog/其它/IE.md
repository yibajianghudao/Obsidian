---
weight: 100
title: IE
slug: ie
summary: IE
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-01-16T11:04:26+08:00
lastmod: 2026-01-16T11:09:54+08:00
---

HP服务器的iLO(带外)管理页面太老旧了,远程控制台在新的浏览器上无法使用,一种方法是使用一个应用程序连接,另外就是安装旧的IE浏览器.

下面是在一个windows server 2008 R2 SP1 上安装IE11的过程:

首先在这个[链接](https://www.microsoft.com/zh-cn/download/details.aspx?id=40901&utm_source=chatgpt.com)下载IE11的安装包,然后在这个[链接](https://learn.microsoft.com/en-us/previous-versions/troubleshoot/browsers/installation/prerequisite-updates-for-ie-11)安装里面必要的前置更新,其中`[2533623]`不需要安装.

更新安装之后重启服务器,然后运行安装包安装IE11即可.
