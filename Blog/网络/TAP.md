---
weight: 100
title: TAP
slug: tap
summary: TAP
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-27T16:53:09+08:00
lastmod: 2026-03-27T17:11:28+08:00
---

TAP 接口用于连接 Linux 内核态的网络协议栈和用户态的应用程序,当某些情况下物理网卡被接管后 (linux 已经没有其所有权),可以通过 TAP 接口将一些数据包直接发回 Linux 内核.

应用场景:

KVM/QEMU 的网桥:

主机将物理网卡连接到创建的网桥,当启动一台 KVM 虚拟机并连接到网桥时,会通过一个 TAP 接口 (在虚拟机内部是一张虚拟网卡.例如 eth0) 连接到主机的网桥 (主机识别到的是一个 TAP 类型的网络接口) 来实现 QEMU(用户态) 和 Linux 内核的数据交换,即 QEMU 通过 TAP 接口将虚拟机中产生的流量转发到了 linux 内核,并通过物理网卡转发到外部网络

VPP:

VPP 接管网卡之后,在 PPPoE 的场景时同样需要使用 TAP 接口,将实际的物理流量转发到 Linux 内核进行处理 (进行复杂的身份认证等过程)

二层 VPN:

普通的 VPN 只支持转发 IP 数据包,如果希望异地的两台机器可以处于同一广播域,可以互相发送 ARP,DHCP,甚至是 PPPoE 拨号等,必须使用 TAP 接口来转发完整的二层帧.与之相对的是 TUN(只工作在三层)
