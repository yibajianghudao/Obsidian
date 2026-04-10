---
weight: 100
title: 网络配置
slug: 网络配置
summary: 网络配置
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-01-21T14:56:37+08:00
lastmod: 2026-01-21T16:07:14+08:00
---

## Ubuntu2204

### 网络配置

在 ubuntu22.04 中网络配置已从传统的 `ifcfg` 文件迁移到 **Netplan** 系统,网络配置文件位于 `/etc/netplan/` 目录,默认存在一个 `50-cloud-init.yaml`:  

```bash  
# This file is generated from information provided by the datasource.  Changes  
# to it will not persist across an instance reboot.  To disable cloud-init's  
# network configuration capabilities, write a file  
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:  
# network: {config: disabled}  
network:  
    ethernets:  
        ens33:  
            addresses:  
            - 10.0.0.80/24  
            nameservers:  
                addresses:  
                - 223.5.5.5  
                search: []  
            routes:  
            -   to: default  
                via: 10.0.0.2  
    version: 2  
```  

按照配置文件的注释,需要新建一个 `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` 文件才能在重启后不自动使用配置  

```bash  
sudo vim /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg  
network: {config: disabled}  
```  

把 `50-cloud-init.yaml` 重命名为 `50-cloud-init.yaml.bak`(或者直接删除) ,并创建自己的网络配置文件:  

```bash  
vim /etc/netplan/01-static-config.yaml  
network:  
  ethernets:  
    ens33:  
      dhcp4: no  
      addresses:  
        - 11.0.0.80/24  
      routes:  
        - to: default  
          via: 11.0.0.1  
      nameservers:  
        addresses: [223.5.5.5]  
  version: 2  
```  

重新生成和使用配置:  

```bash  
netplan generate  
netplan apply  
```  

查看 IP:

```bash
ip address  
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000  
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00  
    inet 127.0.0.1/8 scope host lo  
       valid_lft forever preferred_lft forever  
    inet6 ::1/128 scope host  
       valid_lft forever preferred_lft forever  
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000  
    link/ether 00:0c:29:ad:9c:33 brd ff:ff:ff:ff:ff:ff  
    altname enp2s1  
    inet 11.0.0.80/24 brd 11.0.0.255 scope global ens33  
       valid_lft forever preferred_lft forever  
    inet6 fe80::20c:29ff:fead:9c33/64 scope link  
       valid_lft forever preferred_lft forever  
```

### 新增网卡并配置  

在虚拟机中新增一个网卡:  
![](assets/安装系统/network.png)

查看新的网卡名:  

```bash  
ip address  
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000  
 link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00  
 inet 127.0.0.1/8 scope host lo  
    valid_lft forever preferred_lft forever  
 inet6 ::1/128 scope host  
    valid_lft forever preferred_lft forever  
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000  
 link/ether 00:0c:29:9f:d3:7c brd ff:ff:ff:ff:ff:ff  
 altname enp2s1  
 inet 11.0.0.80/24 brd 11.0.0.255 scope global ens33  
    valid_lft forever preferred_lft forever  
 inet6 fe80::20c:29ff:fe9f:d37c/64 scope link  
    valid_lft forever preferred_lft forever  
3: ens37: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000  
 link/ether 00:0c:29:9f:d3:86 brd ff:ff:ff:ff:ff:ff  
 altname enp2s5  
    valid_lft forever preferred_lft forever  
 inet6 fe80::20c:29ff:fe9f:d386/64 scope link  
    valid_lft forever preferred_lft forever  
```  

网卡名是 `ens37`  
然后在配置文件 `/etc/netplan/01-static-config.yaml` 给该网卡配置 IP:  

```bash  
network:  
ethernets:  
  ens33:  
    dhcp4: no  
    addresses:  
      - 11.0.0.80/24  
    routes:  
      - to: default  
        via: 11.0.0.1  
    nameservers:  
      addresses: [223.5.5.5]   
  ens37:  
    dhcp4: no  
    addresses:  
	  - 192.168.163.80/24  
  version: 2  
```  

应用即可:  

```bash  
netplan generate  
netplan apply  
```  

### 切换为网桥模式

服务器默认网卡配置如下:

```bash
$ ip a
8: ens1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 90:e2:ba:8b:8c:ec brd ff:ff:ff:ff:ff:ff
    altname enp5s0
    inet 10.0.0.5/24 brd 10.0.0.255 scope global ens1
       valid_lft forever preferred_lft forever
    inet6 fe80::92e2:baff:fe8b:8cec/64 scope link 
       valid_lft forever preferred_lft forever

$ ip route
default via 10.0.0.1 dev ens1 proto static 
10.0.0.0/24 dev ens1 proto kernel scope link src 10.0.0.5 
```

传统方式是使用 `bridge-utils` 里的 `brctl` 命令创建网桥,也可以直接使用 `netplan` 声明式的配置,我现在的配置文件如下:

```bash
$ cat /etc/netplan/01-static-config.yaml 
network:
  ethernets:
    ens1:
      dhcp4: no
      addresses:
        - 10.0.0.5/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses: [223.5.5.5]
  version: 2
```

修改配置文件为:

```bash
network:
  version: 2
  renderer: networkd
  ethernets:
    ens1:
      dhcp4: no
      
  bridges:
    br0:
      interfaces: [ens1]
      addresses:
        - 10.0.0.5/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses: [223.5.5.5,8.8.8.8]
```

主要就是新增一个网桥 `br0` 然后把 `ens1` 添加到网桥中,把原本 `ens1` 的网络配置配置到 `br0` 上

可以看到 `ens1` 的 ip 已经没有了,且状态显示为 `master br0`,现在 IP 配置在 `br0` 网卡上:

```bash
$ ip a
8: ens1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master br0 state UP group default qlen 1000
    link/ether 90:e2:ba:8b:8c:ec brd ff:ff:ff:ff:ff:ff
    altname enp5s0
23: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 26:36:b0:44:1f:08 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.5/24 brd 10.0.0.255 scope global br0
       valid_lft forever preferred_lft forever
    inet6 fe80::2436:b0ff:fe44:1f08/64 scope link 
       valid_lft forever preferred_lft forever
```

网关也变成了走 `br0`:

```bash
$ ip r
default via 10.0.0.1 dev br0 proto static 
10.0.0.0/24 dev br0 proto kernel scope link src 10.0.0.5 
```

## Centos79

### 网络配置  

一个网卡 (`eth0` 用于公网:

```bash
$ cat /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE=Ethernet     # 网络类型  
BOOTPROTO=none    # 获取静态IP的方式
NAME=eth0         # 名称
DEVICE=eth0  
ONBOOT=yes        # 开机自启 
IPADDR=10.0.0.200 # IP地址
PREFIX=24         # 子网掩码
GATEWAY=10.0.0.2  # 网关  
DNS1=223.5.5.5    # DNS服务器  
```

一个网卡 (`eth1`) 用于内网:

```bash  
$ cat /etc/sysconfig/network-scripts/ifcfg-eth1
TYPE=Ethernet
BOOTPROTO=none    
NAME=eth1         
DEVICE=eth1      
ONBOOT=yes       
IPADDR=172.16.1.200   
PREFIX=24         
```  

配置完后需要重启网络服务:  

```bash  
systemctl restart network  
```  

然后就可以看到两张网卡的 IP 了:  

```bash  
ip add  
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000  
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00  
    inet 127.0.0.1/8 scope host lo  
       valid_lft forever preferred_lft forever  
    inet6 ::1/128 scope host  
       valid_lft forever preferred_lft forever  
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000  
    link/ether 00:0c:29:4d:6a:ce brd ff:ff:ff:ff:ff:ff  
    inet 10.0.0.200/24 brd 10.0.0.255 scope global noprefixroute eth0  
       valid_lft forever preferred_lft forever  
    inet6 fe80::20c:29ff:fe4d:6ace/64 scope link  
       valid_lft forever preferred_lft forever  
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000  
    link/ether 00:0c:29:4d:6a:d8 brd ff:ff:ff:ff:ff:ff  
    inet 172.16.1.200/24 brd 172.16.1.255 scope global noprefixroute eth1  
       valid_lft forever preferred_lft forever  
    inet6 fe80::20c:29ff:fe4d:6ad8/64 scope link  
       valid_lft forever preferred_lft forever  
```  

## Debian13

### NetworkManager

Debian13 带图形化环境的版本使用的是 `NetworkManager` 作为管理工具,读取 `/etc/NetworkManager/system-connections` 目录下的以 `.nmconnection` 结尾的权限为 `600` 的配置文件

网络配置:

```bash
$ cat /etc/NetworkManager/system-connections/enp1s0-static.nmconnection 
[connection]
id=enp1s0              # 网络配置名
type=ethernet
interface-name=enp1s0  # 网卡名
autoconnect=true

[ipv4]
method=manual
address1=10.0.0.6/24,10.0.0.1
dns=223.5.5.5;8.8.8.8;
ignore-auto-dns=true

[ipv6]
method=ignore
```

完成之后需要先删除自带的 `'Wired connection 1'` 配置文件,否则重启 `NetworkManager` 服务也不会配上 IP:

```bash
$ sudo mv "/etc/NetworkManager/system-connections/W
ired\ connection\ 1" /root/
```

然后重启 `NetworkManager` 服务:

```bash
$ sudo systemctl restart NetworkManager
```

查看网络配置:

```bash
$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:21:e4:38 brd ff:ff:ff:ff:ff:ff
    altname enx52540021e438
    inet 10.0.0.6/24 brd 10.0.0.255 scope global noprefixroute enp1s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe21:e438/64 scope link proto kernel_ll 
       valid_lft forever preferred_lft forever

$ ip r
default via 10.0.0.1 dev enp1s0 proto static metric 100 
10.0.0.0/24 dev enp1s0 proto kernel scope link src 10.0.0.6 metric 100 
```
