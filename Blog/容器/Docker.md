---
weight: 100
title: Docker
slug: docker
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-12-19T10:04:40+08:00
lastmod: 2026-01-20T16:57:40+08:00
---

## 安装

### CentOS7

```bash
# 安装阿里云的docker-ce源
curl -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 清理旧缓存,生成新缓存
sudo yum clean all
sudo yum makecache fast

# 安装docker-ce 24.0.7版本
yum install -y docker-ce-24.0.7-1.el7 docker-ce-cli-24.0.7-1.el7 containerd.io
```

## 经验

### docker compose

#### mysql 数据卷未清理导致数据库没有被创建

在做 [docker训练营第二期专业阶段](https://cnb.cool/opencamp/learning-docker/docker-training-advanced-2) 的第三题时,多次请求,返回数值没有递增.

```bash
exercise3 git:(main) ✗ curl http://localhost:8080/count Count: 0# ➜ exercise3 git:(main) ✗ curl http://localhost:8080/count Count: 0# ➜ exercise3 git:(main) ✗ curl http://localhost:8080/count Count: 0# ➜ exercise3 git:(main) ✗ curl http://localhost:8080/count Count: 0#
```

`docker-compose.yaml` 文件如下:

```bash
# 作业要求：
# 1. 使用 Docker Compose 编排 Golang Web 服务、MySQL 和 Nginx 三个服务。
# 2. Golang Web 服务需实现 /count 路径，计数存储在 MySQL。
# 3. Nginx 反向代理 8080 端口到 Web 服务。
# 4. 所有服务通过自定义网络通信，Web 仅对 Nginx 暴露。
# 5. 提供测试脚本验证计数功能。
#
# 说明：
# - app 服务通过 Dockerfile 构建，依赖 MySQL。
# - nginx 服务挂载自定义配置文件。
# - 统一使用 app-network 网络。
# - MYSQL_DSN 环境变量用于配置数据库连接。
# - mysql-data 是 named volume，用于持久化 MySQL 数据。

version: '3.8'

# 在这里编写你的 docker-compose.yml 文件

services:
  app:
    build: ./app
    depends_on: 
      - mysql
    networks:
      - app-network
    environment:
      MYSQL_DSN: "root:123456@tcp(mysql:3306)/counter"
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      MYSQL_DATABASE: "counter"
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - app-network
  nginx:
    image: nginx:latest
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "8080:80"
    networks:
      - app-network
    depends_on: 
      - app
networks:
  app-network:
   driver: bridge
volumes:
  mysql-data:
# 测试:
# docker compose up -d --build 启动服务
# curl http://localhost:8080/count 验证计数功能

```

我编写的 Dockerfile 文件如下:

```bash
# 作业目标：
# 构建 Golang Web 服务镜像，实现计数功能并连接 MySQL。
#
# 关键步骤说明：
# - 选择合适的 Golang 基础镜像
# - 下载依赖并编译应用
# - 拷贝可执行文件到最终镜像
# - 设置容器启动命令
# - 最好使用多阶段构建，减少最终镜像体积

FROM golang:1.21-alpine AS builder

# 在这里编写你的 Dockerfile
COPY . /app

WORKDIR /app

RUN go mod tidy && go build -o app

FROM alpine:latest

COPY --from=builder /app/app /

EXPOSE 3000

CMD ["./app"]
```

进入 MySQL 的容器之后发现数据库中没有 `counter` 库:

```bash
mysql> SHOW DATABASES;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
4 rows in set (0.01 sec)
```

原来是我关闭 docker compose 集群时使用的命令是

```bash
➜  exercise3 git:(main) ✗ docker compose down
WARN[0000] /workspace/exercise3/docker-compose.yml: `version` is obsolete 
[+] Running 4/4
 ✔ Container exercise3-nginx-1    Removed                                                                            0.8s 
 ✔ Container exercise3-app-1      Removed                                                                            0.7s 
 ✔ Container exercise3-mysql-1    Removed                                                                            1.2s 
 ✔ Network exercise3_app-network  Removed                                                                            0.2s 
```

可以看到该命令没有删除创建的 volume,而我第一次运行时没有添加环境变量 `MYSQL_DATABASE: "counter"`,导致该卷中一直存在着数据,而 MySQL 的 `MYSQL_DATABASE` 环境变量只有在 volume 为空时才会被使用.

而正确的命令是:

```bash
➜  exercise3 git:(main) ✗ docker compose down -v
WARN[0001] /workspace/exercise3/docker-compose.yml: `version` is obsolete 
[+] Running 5/5
 ✔ Container exercise3-nginx-1    Removed                                                                                           0.7s 
 ✔ Container exercise3-app-1      Removed                                                                                           0.5s 
 ✔ Container exercise3-mysql-1    Removed                                                                                           1.9s 
 ✔ Volume exercise3_mysql-data    Removed                                                                                           0.0s 
 ✔ Network exercise3_app-network  Removed                                                                                           0.2s 
```

volume 被删除,检查一下确实没有了:

```bash
# 剩余的是之前作业一创建的mysql-data volume
➜  exercise3 git:(main) ✗ docker volume ls | grep mysql-data
local     exercise1_mysql-data
```

重新启动集群之后,测试正常
