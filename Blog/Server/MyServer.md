---
weight: 100
title: MyServer
slug: myserver
summary: MyServer
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-18T09:34:09+08:00
lastmod: 2026-03-18T09:36:09+08:00
---

我的服务器部署了以下服务:

## 一个游戏的服务器

使用 docker 通过 wine 运行 (只有 windows 版本),dockerfile 如下:

```
FROM debian:bookworm-slim

# Install wine etc.
RUN dpkg --add-architecture i386 && apt-get update && \
    apt-get install -y --no-install-recommends wine64 wine32 && \
    apt-get clean && rm -rf /var/cache/* /var/log/* /tmp/* \
    /usr/share/man/* /usr/share/doc/*

WORKDIR /server
VOLUME ["/server"]
ENV PATH="$PATH:/usr/lib/wine"
EXPOSE 30618/udp
CMD ["wine", "WSELoaderServer.exe", "-r", "duifu.txt", "-m", "Napoleonic Wars"]
```

启动命令:

```
docker run -dit --name greatming --network host -v /home/greatming/GreatMing_Battle/NapoleonicWarsDedicated:/server greatmingbattle

```
