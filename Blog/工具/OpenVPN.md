---
weight: 100
title: OpenVPN
slug: openvpn
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-01-07T10:02:35+08:00
lastmod: 2026-01-07T11:03:22+08:00
---

OpenVPN也有Linux版本,详见[官网](https://community.openvpn.net/Pages/OpenVPN3Linux#stable-repository-debian-ubuntu)  

导入配置:
```
$ openvpn3 config-import -c client.ovpn   
Configuration imported.  Configuration path: /net/openvpn/v3/configuration/eefc239dxf193x409bx933exb272bbc65dae
```
导入配置的时候会默认将使用的路径和文件名当作配置的名称,例如:
```
Configuration Name                                        Last used
--------------------------------------------------------------------------
../client.ovpn                                            -
--------------------------------------------------------------------------
```
可以直接指定配置名称:
```
$ openvpn3 config-import -c ../client.ovpn -n client.ovpn
Configuration imported.  Configuration path: /net/openvpn/v3/configuration/befb7fe8x55e8x4eddx8dc2xa8cf28ff66e8

```
查看配置:
```
$ openvpn3 configs-list       
Configuration Name                                        Last used
------------------------------------------------------------------------------
client.ovpn                                               -
------------------------------------------------------------------------------

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
可以根据详细配置的路径(`/net/openvpn/v3/configuration/*`)删除配置:
```
$ openvpn3 config-remove --path /net/openvpn/v3/configuration/04d47ef7xb903x4fdcx9e1axbcf3a51e00bd
This operation CANNOT be undone and removes this configuration profile completely.
# 这里的yes必须使用大写
Are you sure you want to do this? (enter yes in upper case) YES
Configuration removed.

```
也可以根据配置名删除:
```
$ openvpn3 config-remove -c client.ovpn
This operation CANNOT be undone and removes this configuration profile completely.
Are you sure you want to do this? (enter yes in upper case) YES
Configuration removed.

```
按照配置启动会话,启动之前需要关闭其他代理:
```
$ openvpn3 sessions-start -c client.ovpn

```
可以查看会话状态:
```
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
停止会话连接:
```
$ openvpn3 session-manage -D -c client.ovpn

Initiated session shutdown.

Connection statistics:
     BYTES_IN.................1005136
     BYTES_OUT.................138148
     PACKETS_IN...................836
     PACKETS_OUT..................775
     TUN_BYTES_IN..............115241
     TUN_BYTES_OUT.............977833
     TUN_PACKETS_IN...............762
     TUN_PACKETS_OUT..............924

```