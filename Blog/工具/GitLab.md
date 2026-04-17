---
weight: 100
title: Gitlab
slug: gitlab
summary: gitlab
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-12T15:02:21+08:00
lastmod: 2026-03-12T15:04:56+08:00
---
## 安装
在Ubuntu上安装GitLab:
```
# 安装依赖
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl

# 使用postfix发送邮件是可选的
sudo apt-get install -y postfix
```

配置镜像源:
```
curl -L get.gitlab.cn | bash
```

配置环境变量,包括示例IP地址和root密码等:
```
sudo EXTERNAL_URL="http://10.0.0.21" GITLAB_ROOT_PASSWORD=Gitlab123! apt-get install -y gitlab-jh
```
> 参考[设置初始账户](https://gitlab.cn/docs/omnibus/installation/#set-up-the-initial-account),如果没有设置,则需要访问`/etc/gitlab/initial_root_password`使用随机密码登录后修改密码.

安装后启动:
```
$ sudo gitlab-ctl start
ok: run: alertmanager: (pid 7038) 23s
ok: run: gitaly: (pid 5535) 314s
ok: run: gitlab-exporter: (pid 6989) 26s
ok: run: gitlab-kas: (pid 5405) 443s
ok: run: gitlab-workhorse: (pid 6957) 28s
ok: run: logrotate: (pid 4828) 473s
ok: run: nginx: (pid 6967) 27s
ok: run: node-exporter: (pid 6975) 27s
ok: run: postgres-exporter: (pid 7050) 23s
ok: run: postgresql: (pid 5030) 450s
ok: run: prometheus: (pid 7012) 25s
ok: run: puma: (pid 6546) 85s
ok: run: redis: (pid 4883) 467s
ok: run: redis-exporter: (pid 6997) 25s
ok: run: sidekiq: (pid 6579) 79s
```

## 命令
gitlab常用命令:
```
gitlab-ctl start
gitlab-ctl stop
gitlab-ctl restart
gitlab-ctl status
gitlab-ctl reconfigure
gitlab-ctl tail
```