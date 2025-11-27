---
weight: 100  
title: Grafana  
slug: grafana  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:34:55+08:00  
lastmod: 2025-11-20T09:34:55+08:00  
---
## 安装  
参考[Install Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/installation/)  
默认监听在3000端口,初始帐号和密码都是`admin`,第一次登陆需要修改密码  
## 配置  
### 修改Web语言  
[Change organization language](https://grafana.com/docs/grafana/latest/setup-grafana/installation/)  
### 配置`Grafana-Zabbix`  
参考[安装教程](https://grafana.com/docs/plugins/alexanderzobnin-zabbix-app/latest/installation/)  
```  
# 查看插件列表  
grafana-cli plugins list-remote  
# 安装grafana-zabbix插件  
grafana-cli plugins install alexanderzobnin-zabbix-app  
# 重启  
systemctl restart grafana-server  
```  
在 管理-插件和数据-插件 页面启用Zabbix插件  
在 连接-数据源 页面新建一个数据源,选择zabbix  
配置:  
- `Connection.url`: zabbix服务器地址后添加`/api_jsonrpc.php`,例如`http://localhost/zabbix/api_jsonrpc.php`  
- `Authentication`: 选择验证方式,没配置则不用填  
- `Zabbix Connection`: 输入用户密码