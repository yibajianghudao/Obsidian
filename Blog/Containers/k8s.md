---
weight: 100
title: k8s
slug: k8s
description:
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-12-19T10:04:40+08:00
lastmod: 2026-01-20T16:57:40+08:00
---

## 介绍

k8s是云原生微服务应用的编排器,它的特点有:

- 服务发现和负载均衡
- 存储编排
- 自动部署和回滚
- 自动分配CPU/内存资源(弹性伸缩)
- 自我修复(在需要时启动新容器)

## 架构

### 节点

我们通常把k8s集群中的机器称为节点(Node)

k8s集群中有两种类型的节点:

- 控制平面节点(control plane node)
- 工作节点(worker node)
  > 在一些旧文档中可能会将控制节点称为"主节点"这个术语已被淘汰.
