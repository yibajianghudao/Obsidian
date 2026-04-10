---
weight: 100
title: VPN
slug: vpn
summary: VPN
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-02-24T09:31:20+08:00
lastmod: 2026-03-02T17:54:33+08:00
---

## 使用 NetworkManager VPN 代替 Windows VPN

有一个使用场景是:

在 Windows 环境下，使用 VPN 远程连接主机通常通过配置 VPN 并配合 `.bat` 脚本来实现拨号和路由添加:

```bash
@echo off
COLOR E
rasdial.exe "vpn" "123" "123123"
route  add 10.25.4.0 mask 255.255.0.0 172.16.0.1 
route  add 100.45.98.0 mask 255.255.252.0 172.16.0.1 
route  add 101.25.11.129 mask 255.255.255.0 172.16.0.1 
route  add 10.32.110.0 mask 255.255.255.0 172.16.0.1
timeout /nobreak /t 300
exit
pause
```

我们可以手动切换 Windows 设置的 VPN 类型来确定 VPN 的类型：

![](assets/VPN/使用NetworkManager%20VPN代替Windows%20VPN-20260224150332350.png)

从图中可以看出，这是一个 L2TP/IPsec 类型的 VPN。由于数据加密选项为可选，且连接过程中未手动配置预共享密钥 (PSK)，可以确定该连接未开启 IPsec 加密，即纯 L2TP 模式。

在 Linux 系统上可以直接使用 `NetworkManager` 的命令行工具 `nmcli` 来替代这个脚本，还可以通过 Linux 的路由机制实现更优雅的流量接管。

### 原理

#### VPN 分流

上述 `.bat` 脚本中的 `route add` 命令用于配置路由来实现 VPN 分流。如果不配置这些路由，连接 VPN 后，默认网关可能会改变，导致所有流量都经过 VPN 服务器。配置特定网段的路由后，只有访问 `10.25.4.0` 等特定网段时才走 VPN 隧道，其他流量正常走本地物理网卡。

#### Linux 路由配置

Windows 脚本中指定了固定的网关 IP：`172.16.0.1`。在 Linux 上处理 PPP (如 L2TP) 等点对点协议时，建议不指定网关 IP，而是直接将流量转发到虚拟网卡设备（如 `dev ppp1`）。

原因是，如果服务器动态分配的虚拟网关 IP 发生变化，指定固定 IP 的路由将会失效；而直接指向网卡设备的路由不受对端 IP 变化的影响。

### 配置

#### 安装依赖组件

安装 NetworkManager 的 L2TP 插件及底层加密组件：

```bash
sudo apt install network-manager-l2tp network-manager-l2tp-gnome xl2tpd strongswan libstrongswan-extra-plugins libcharon-extra-plugins
```

停用底层服务的独立自启动，避免占用端口导致 NetworkManager 拨号失败：

```bash
sudo systemctl stop xl2tpd strongswan-starter ipsec
sudo systemctl disable xl2tpd strongswan-starter ipsec
```

重启 NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

#### 创建和配置 VPN

通过 `nmcli` 创建和配置 VPN，将子网掩码转换为 CIDR 格式（如 `255.255.255.0` 转换为 `/24`）：

```bash
# 1. 创建 L2TP VPN 连接
nmcli connection add type vpn vpn-type l2tp con-name "MyL2TP_CLI" ifname "*"

# 2. 配置服务器 IP 和认证协议（注意关闭 ipsec）
nmcli connection modify "MyL2TP_CLI" vpn.data "gateway=101.20.138.165, user=123, refuse-pap=yes, refuse-chap=yes, refuse-eap=yes, ipsec-enabled=no"

# 3. 设置密码
nmcli connection modify "MyL2TP_CLI" vpn.secrets "password=123123"

# 4. 开启分流模式（仅配置的网段走 VPN）
nmcli connection modify "MyL2TP_CLI" ipv4.never-default yes

# 5. 添加路由
nmcli connection modify "MyL2TP_CLI" +ipv4.routes "10.25.4.0/16"
nmcli connection modify "MyL2TP_CLI" +ipv4.routes "100.45.98.0/22"
nmcli connection modify "MyL2TP_CLI" +ipv4.routes "101.25.11.0/24"
nmcli connection modify "MyL2TP_CLI" +ipv4.routes "10.32.110.0/24"
```

#### 启动和测试

启动 VPN：

```bash
nmcli connection up "MyL2TP_CLI"
```

通过 `ip a` 命令查看 `ppp` 网卡：

```bash
$ ip a
11: ppp1: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1400 qdisc fq_codel state UNKNOWN group default qlen 3
    link/ppp 
    inet 172.16.0.51 peer 172.16.0.1/32 scope global ppp1
       valid_lft forever preferred_lft forever
```

开启分流模式后，没有配置的网段不会走 VPN。使用 `ip route get` 查看一个没有配置的 IP 的路由：

```bash
# 未配置的 IP 走本地物理网卡 (enp1s0)
$ ip route get 20.0.0.123    
20.0.0.123 via 192.168.88.1 dev enp1s0 src 192.168.88.7 uid 1000 
    cache 
```

手动把网段添加路由之后就可以走 VPN 了:

```bash
$ nmcli connection modify "MyL2TP_CLI" +ipv4.routes "20.0.0.0/24"

$ nmcli connection down "MyL2TP_CLI"
Connection 'MyL2TP_CLI' successfully deactivated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/7)

$ nmcli connection up "MyL2TP_CLI" 
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/8)
```

测试路由:

```bash
$ ip route get 20.0.0.123  
20.0.0.123 dev ppp1 src 172.16.0.51 uid 1000 
    cache 
```

## 使用 Linux 版本的 OpenVPN

在 Windows 环境下，通常通过 OpenVPN 客户端导入 `client.ovpn` 文件进行连接。 Linux 系统同样支持 OpenVPN，安装及官方说明详见 [官网](https://community.openvpn.net/Pages/OpenVPN3Linux#stable-repository-debian-ubuntu)。

在 Linux 上，可以使用 `openvpn3` 命令行工具来管理配置和控制连接。

### 管理配置

导入配置：

```bash
$ openvpn3 config-import -c client.ovpn   
Configuration imported.  Configuration path: /net/openvpn/v3/configuration/eefc239dxf193x409bx933exb272bbc65dae
```

导入配置时，默认会将使用的路径和文件名作为配置的名称，例如：

```bash
Configuration Name                                        Last used
--------------------------------------------------------------------------
../client.ovpn                                            -
--------------------------------------------------------------------------
```

可以使用 `-n` 参数手动指定配置名称：

```bash
$ openvpn3 config-import -c ../client.ovpn -n client.ovpn
Configuration imported.  Configuration path: /net/openvpn/v3/configuration/befb7fe8x55e8x4eddx8dc2xa8cf28ff66e8

```

查看已导入的配置列表：

```bash
$ openvpn3 configs-list       
Configuration Name                                        Last used
------------------------------------------------------------------------------
client.ovpn                                               -
------------------------------------------------------------------------------
```

查看详细配置信息：

```bash
# 查看详细配置
$ openvpn3 configs-list --json         
{
	"/net/openvpn/v3/configuration/eefc239dxf193x409bx933exb272bbc65dae" : 
	{
		"acl" : 
		{
			"locked_down" : false,
			"owner" : "mintuser",
			"public_access" : false
		},
		"dco" : false,
		"imported" : "2026-01-07 10:00:20",
		"imported_tstamp" : 1767751220,
		"lastused" : "",
		"lastused_tstamp" : 0,
		"name" : "client.ovpn",
		"transfer_owner_session" : false,
		"use_count" : 0,
		"valid" : true
	}
}

```

可以使用配置路径 (`/net/openvpn/v3/configuration/*`) 删除指定配置。确认删除时必须输入大写的 `YES`：

```bash
$ openvpn3 config-remove --path /net/openvpn/v3/configuration/04d47ef7xb903x4fdcx9e1axbcf3a51e00bd
This operation CANNOT be undone and removes this configuration profile completely.

Are you sure you want to do this? (enter yes in upper case) YES
Configuration removed.

```

也可以直接使用配置名称进行删除：

```bash
$ openvpn3 config-remove -c client.ovpn
This operation CANNOT be undone and removes this configuration profile completely.
Are you sure you want to do this? (enter yes in upper case) YES
Configuration removed.

```

### 管理会话

使用指定配置启动 VPN 会话（启动前需确保已关闭其他代理服务）：

```bash
$ openvpn3 sessions-start -c client.ovpn

```

查看当前活动的会话状态：

```bash
$ openvpn3 sessions-list                
-----------------------------------------------------------------------------
        Path: /net/openvpn/v3/sessions/5ab7e47ds81des4659saf29sc31adbb71f09
     Created: 2026-01-07 10:58:49                       PID: 20736
       Owner:                                Device: tun0
 Config name: client.ovpn
Connected to: tcp:
      Status: Connection, Client connected
-----------------------------------------------------------------------------

```

停止指定的 VPN 会话连接：

```bash
$ openvpn3 session-manage -D -c client.ovpn

Initiated session shutdown.

Connection statistics:
     BYTES_IN……………..1005136
     BYTES_OUT……………..138148
     PACKETS_IN……………….836
     PACKETS_OUT………………775
     TUN_BYTES_IN…………..115241
     TUN_BYTES_OUT………….977833
     TUN_PACKETS_IN……………762
     TUN_PACKETS_OUT…………..924

```

## 使用 SSH 隧道访问带外

需要访问内网服务器的带外管理界面,该带外服务器通过一台 Linux 管理机相连,本地主机无法直接访问，需要通过一台跳板机（服务器 1）进行中转。

> 如果连接的是 Windows 管理机则可以直接通过 RDP 远程连接到 windows 管理机然后 [通过 IE 浏览器访问带外](../其它/IE.md)。

### 原方案

在 Windows 环境下，通常配合 Proxifier 软件实现：

先通过 `ssh` 远程连接到跳板机（服务器 1）:

```bash
ssh root@跳板机ip
```

然后在跳板机上运行 SOCKS 代理，将跳板机的 `7070` 端口代理到内网管理机（服务器 2）：

```bash
ssh -XY -vCNgD 0.0.0.0:7070 -o ServerAliveInterval=20 -o ConnectTimeout=60 -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o GSSAPIAuthentication=no -p 22 root@内网管理机IP
```

最后在 Windows 主机上使用 **Proxifier** 软件，连接到跳板机的 `7070` 端口。随后即可在主机的浏览器中直接访问带外 IP。

### Linux 替代方案

Linux 上没有**Proxifier** 软件,该软件主要是给其他软件设置代理,我访问带外使用的 firefox 浏览器本身就可以配置代理,可以直接使用 SSH 隧道的本地端口转发功能，配合浏览器的代理设置来实现相同的效果。

#### 建立 SOCKS 代理

与原方案相同，首先在跳板机（服务器 1）上执行上述命令，建立连接到内网管理机（服务器 2）的 SOCKS 代理，并监听在跳板机的 `7070` 端口。

```bash
ssh root@跳板机ip

ssh -XY -vCNgD 0.0.0.0:7070 -o ServerAliveInterval=20 -o ConnectTimeout=60 -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o GSSAPIAuthentication=no -p 22 root@内网管理机IP
```

#### 配置本地端口转发

在本地 Linux 主机上运行以下命令，将本地的 `7070` 端口通过 SSH 隧道映射到跳板机的 `127.0.0.1:7070` 端口：

```bash
ssh -N -L 7070:127.0.0.1:7070 root@跳板机IP
```

#### 配置浏览器代理

在本地浏览器（如 Firefox）的网络设置中，将代理配置为 SOCKS5，地址填写为 `127.0.0.1`，端口填写为 `7070`。

完成设置后，即可通过本地浏览器直接访问位于内网的带外管理界面。
