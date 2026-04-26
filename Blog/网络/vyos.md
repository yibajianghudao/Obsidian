---
weight: 100
title: vyos
slug: vyos
summary: vyos
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-24T14:42:48+08:00
lastmod: 2026-04-16T15:10:08+08:00
---

## 安装

安装的镜像名称是 `vyos-2026.03.17-0027-rolling-generic-amd64.iso`,分配了两张网卡 (一个公网,一个内网):

启动之后选择 `KVM console`,另外一个 `Serial console` 是用于通过 console 线连接时使用的 (部署在路由器上)

启动之后使用用户 `vyos` 登录,密码也是 `vyos`

先运行 `install image` 安装系统

`console` 依旧选择 `kvm`,选择磁盘之后输入 `y` 确认删除所有数据,其它选项保持默认

安装之后运行 `root` 重启系统,加载时拔出 u 盘

## 配置

### 配置网络

运行 `ip a` 检查一下网卡名称:

![](assets/安装系统/Vyos-20260317153938667.png)

```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ec:54:75 brd ff:ff:ff:ff:ff:ff
    altname enp0s3
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:7b:4f:66 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
```

首先进入配置模式:

```
vyos@vyos$ configure
vyos@vyos#
```

进入配置模式的标志是命令提示符由 `$` 改为 `#`

接下来配置网络:

```
# 配置公网接口
set interfaces ethernet eth1 address '192.168.88.61/24'

# 配置内网接口
set interfaces ethernet eth0 address '192.168.56.3/24'
```

配置网关:

```
set protocols static route 0.0.0.0/0 next-hop '192.168.88.1'
```

配置 DNS:

```
set system name-server '8.8.8.8'
```

配置 ssh:

```
set service ssh port '22'
```

应用并保存:

```
commit
save
```

> 如果要修改静态 ip 为 dhcp,可以使用:
> ```
> delete interfaces ethernet eth1 address
> set interfaces ethernet eth1 address dhcp
> ```

### 配置 VPP

#### 系统底层预配置

VPP 高性能转发依赖底层的 CPU 隔离与大页内存。这些属于内核级改动，必须先行配置并重启系统。

```cli
configure

# 1. 预留大页内存 (Hugepages)
# 为 VPP 分配 4096 个 2MB 的大页内存（共约 8GB，请根据物理机内存容量酌情调整）
set system option kernel memory hugepage-size '2MB' hugepage-count '4096'

# 2. 内核 CPU 核心隔离与优化 (以隔离 8-11 核为例)
set system option kernel cpu disable-nmi-watchdog
set system option kernel cpu isolate-cpus '8-11'
set system option kernel cpu nohz-full '8-11'
set system option kernel cpu rcu-no-cbs '8-11'

# 3. 禁用不必要的中断与节能，防止 CPU 降频引发延迟抖动
set system option kernel disable-hpet
set system option kernel disable-mce
set system option kernel disable-power-saving
set system option kernel disable-softlockup

# 提交并保存内核配置
commit
save
exit

# 重启系统以应用内核隔离和大页内存
reboot
```

系统重启后，检查大页内存是否分配成功：

```bash
# 查看 2MB 大页的总量
cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
# 查看剩余可用的大页数量
cat /sys/kernel/mm/hugepages/hugepages-2048kB/free_hugepages
```

#### 配置 VPP 引擎并接管网卡

确认系统资源就绪后，开始配置 VPP 数据平面。

```
configure

# 1. 为 VPP 引擎分配计算资源（对应阶段一隔离的 4 个核心）
set vpp settings resource-allocation cpu-cores '4'

# 2. 允许使用不受官方支持的网卡 (针对 KVM virtio 或普通消费级物理网卡必开)
set vpp settings allow-unsupported-nics

# 3. 将物理网卡交由 VPP 接管，并开启多队列提升并发 (队列数建议不超过分配的 CPU 核心数)
set vpp settings interface eth1

set vpp settings interface eth1 num-rx-queues 4
set vpp settings interface eth1 num-tx-queues 4

# 分配之后需要重启查看是否生效
commit
save
exit

```

#### 配置 NAT 转换

下面是一个配置 NAT 转换的示例:

```
# 将网卡交给vpp接管
set vpp settings interface eth0
set vpp settings interface eth1

# 设置ip地址
set interfaces ethernet eth0 address '10.0.0.1/24'
set interfaces ethernet eth1 address '192.168.1.1/24'

# 配置Snat,不需要nat的跳过这个和下面的动态地址池
# 划定内外网边界
set vpp nat nat44 interface inside eth0
set vpp nat nat44 interface outside eth1

# 配置 translation 动态地址池
set vpp nat nat44 address-pool translation interface eth1

commit
save
exit
```

#### 检查状态

```
# 确认 VPP 服务已经被自动唤醒，状态应为 Active
sudo systemctl status vpp --no-pager

# 确认 VPP 视角的接口处于 UP 状态，且正确挂载了 IP
vppctl show interface address

# 确认底层的 NAT44 插件成功绑定了 inside 和 outside
vppctl show nat44 interfaces
```

`vppctl` 是 VPP 的内部控制台。可以直接执行 `vppctl <命令>`，或者输入 `vppctl` 进入交互模式。在交互模式下输入 `?` 可以获取命令补全和帮助提示。

## Web

### vymanager

vymanger 是社区制作的 web 页面,需要在单独的服务器 (而不是 vyos 主机) 上通过 docker compose 部署

项目的仓库是 [仓库](https://github.com/Community-VyProjects/VyManager)

#### 安装过程

##### vyos 主机

```
# Enter configuration mode
configure

# Create an API key (replace YOUR_SECURE_API_KEY with a strong random key)
set service https api keys id vymanager key YOUR_SECURE_API_KEY

# Enable REST functionality (VyOS 1.5+ only)
set service https api rest

# Enable GraphQL (required for dashboard streaming)
set service https api graphql

# Set GraphQL authentication to use the API key defined above
set service https api graphql authentication type key

# Save and apply
commit
save
exit
```

> 这里的密钥是后面 web 页面初始化的时候需要的

##### docker 主机

在一个控制主机 (安装有 docker) 中创建两个文件:

`docker-compose.yaml`

```
services:
  postgres:
    image: postgres:16-alpine
    container_name: vymanager-postgres
    environment:
      POSTGRES_USER: vymanager
      POSTGRES_PASSWORD: CHANGE_ME_POSTGRES_PASSWORD
      POSTGRES_DB: vymanager
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    networks:
      - vymanager-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vymanager -d vymanager"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  backend:
    image: ghcr.io/community-vyprojects/vymanager-backend:beta
    container_name: vymanager-backend
    ports:
      - "8000:8000"
    env_file:
      - .env
    restart: unless-stopped
    networks:
      - vymanager-network
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/docs"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  frontend:
    image: ghcr.io/community-vyprojects/vymanager-frontend:beta
    container_name: vymanager-frontend
    ports:
      - "3000:3000"
    env_file:
      - .env
    depends_on:
      backend:
        condition: service_healthy
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - vymanager-network

networks:
  vymanager-network:
    driver: bridge

volumes:
  postgres_data:
    driver: local
```

`.env`

```
# ── Backend ──────────────────────────────────────────────
# CHANGE_ME_POSTGRES_PASSWORD must match POSTGRES_PASSWORD in docker-compose.yml
DATABASE_URL=postgresql://vymanager:CHANGE_ME_POSTGRES_PASSWORD@postgres:5432/vymanager
FRONTEND_URL=http://frontend:3000

# CHANGE THIS — use a long random string (e.g. openssl rand -base64 32)
# Must match the BETTER_AUTH_SECRET value below — both services use this file
BETTER_AUTH_SECRET=Change-This-To-Something-Secret

# CHANGE THIS — use a long random hex string (e.g. openssl rand -hex 32)
SSH_ENCRYPTION_KEY=Change-This-To-A-Hex-String

# ── Frontend ─────────────────────────────────────────────
NODE_ENV=production
VYMANAGER_ENV=production

# Must be the same value as BETTER_AUTH_SECRET above
BETTER_AUTH_SECRET=Change-This-To-Something-Secret

# CHANGE THIS — set to the URL where users access VyManager in their browser
BETTER_AUTH_URL=http://<YOUR_SERVER_IP>:3000
NEXT_PUBLIC_APP_URL=http://<YOUR_SERVER_IP>:3000

# Internal Docker network URL — do not change unless you rename the backend service
BACKEND_URL=http://backend:8000

# CHANGE THIS — comma-separated list of every URL users will access VyManager from
# Example: http://192.168.1.50:3000,http://vymanager.lan:3000
TRUSTED_ORIGINS=http://<YOUR_SERVER_IP>:3000,http://localhost:3000
```

需要修改的内容:

- `POSTGRES_PASSWORD`: 可以使用 `openssl rand -hex 32` 生成,需要同时在 `docker-compose.yaml` 文件中替换 `CHANGE_ME_POSTGRES_PASSWORD` 字段
- `BETTER_AUTH_SECRET`: 可以使用 `openssl rand -base64 32` 生成,用于签名和验证会话令牌,`.env` 中出现了两次,要保持一致
- `SSH_ENCRYPTION_KEY`: 可以使用 `openssl rand -hex 32` 生成,用于加密静态存储的 ssh 私钥
- `<YOUR_SERVER_IP>`: 替换为 docker 主机的 ip,用户需要通过此 ip 访问这个 web 页面

替换之后运行 `docker compose up -d` 启动集群,可以先手动从国内镜像站下载镜像:

```
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/postgres:16-alpine
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/community-vyprojects/vymanager-backend:beta
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/ghcr.io/community-vyprojects/vymanager-frontend:beta
```

> 下载完之后记得手动修改一下标签

### vycontrol

由于在 VyOS 1.4 和 1.5 中 api 经过了破坏性重构,经过测试 vycontrol 已经不能在 vyos1.5 上使用,下面是部署过程中的笔记,仅供参考.

可以自行研究 vyos1.3 是否可行,使用 1.3 请参考下面两个文章链接的 vyos 配置过程和我的笔记的 docker 安装和镜像制作部分

参考 [VyControl Installation on Standalone VyOS Router](https://brezular.com/2021/05/31/vycontrol-installation-on-standalone-vyos-router/) 和 [Docker Installation on VyOS](https://brezular.com/2021/04/01/docker-installation-on-vyos/)

#### 安装 docker

文章提供了一个脚本,但是它适配的是 `vyos1.3(debian10)`,并且不适合国内网络环境.

下面的流程适用于 `vyos1.5(debian12)`:

```
# 配置apt镜像源
echo "deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free" > /etc/apt/sources.list
apt-get update

# 安装一些工具
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# 配置密钥和docker国内源
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update

# 创建一个目录用于自启动docker
sudo mkdir -p /config/user-data/docker
sudo ln -s /config/user-data/docker /var/lib/docker

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 禁用docker自带的自启动,配置手动自启动
sudo systemctl disable docker
# 网络和防火墙完全就绪后，再自动启动 Docker
sudo sh -c "echo 'systemctl start docker' >> /config/scripts/vyos-postconfig-bootup.script"

# 手动启动一下docker
sudo systemctl start docker
```

这里需要禁用 docker 的自启动,防止它抢在 VyOS 防火墙加载前启动而导致网络规则冲突

#### 制作镜像

修改 `vycontrol/vycontrol/vycontrol/setting.py` 文件,添加上主机的 ip:

```
ALLOWED_HOSTS = ['127.0.0.1', '192.168.56.1']
```

确保 Dockerfile 文件中配置了 `0.0.0.0:8000`:

```
$ grep '0.0.0.0:8000' Dockerfile

CMD ["runserver", "--settings=vycontrol.settings_available.production", "0.0.0.0:8000"]
```

然后构建镜像:

```
$ docker compose build
```

保存镜像:

```
$ docker save -o docker.tar vycontrol:latest
```

然后通过 scp 复制过去:

```
$ scp ./docker.tar vyos@192.168.56.3:/home/vyos/vycontrol
```

复制之后不能直接导入和运行镜像,因为 vyos 本身运行在可写层上,而 docker 会再尝试运行一层可写层,linux 内核禁止这样做,所以我们需要手动创建一个虚拟硬盘挂载给 docker(和其使用的 containd)

```
sudo systemctl stop docker containerd

sudo mkdir -p /config/docker-root
# 创建虚拟硬盘并挂载docker,containerd到硬盘中
sudo dd if=/dev/zero of=/config/docker-disk.img bs=1M count=3072
sudo mount -o loop /config/docker-disk.img /config/docker-root
sudo mkdir -p /config/docker-root/docker
sudo mkdir -p /config/docker-root/containerd
sudo rm -rf /var/lib/docker /var/lib/containerd
sudo ln -s /config/docker-root/docker /var/lib/docker
sudo ln -s /config/docker-root/containerd /var/lib/containerd

sudo systemctl start containerd
sudo systemctl start docker

sudo docker load -i docker.tar
sudo docker run -d -p 8000:8000 -t vycontrol
```

还需要设置一下开机自启:

```
# 设置开机自动挂载(在启动docker之前)
sudo vim /config/scripts/vyos-postconfig-bootup.script
```

运行起来镜像之后发现添加 `ALLOWED_HOST` 的文件找错了,可能是教程太古老了,在现在的 Dockerfile 文件中是这样写的:

```
FROM python:3  
ENV PYTHONUNBUFFERED 1  
RUN mkdir /code  
WORKDIR /code  
COPY requirements.txt /code/  
RUN pip install -r requirements.txt  
COPY vycontrol/ /code/  
COPY vycontrol/vycontrol/settings_example/ /code/vycontrol/settings_available/  
  
WORKDIR /code  
RUN python3 manage.py makemigrations config --settings=vycontrol.settings_available.production    
RUN python3 manage.py makemigrations --settings=vycontrol.settings_available.production    
RUN python3 manage.py migrate --settings=vycontrol.settings_available.production    
RUN python3 manage.py createcachetable --settings=vycontrol.settings_available.production    
  
EXPOSE 8000  
STOPSIGNAL SIGINT  
ENTRYPOINT ["python", "manage.py"]  
CMD ["runserver", "--settings=vycontrol.settings_available.production", "0.0.0.0:8000"]
```

最终结果是程序读取的是 `vycontrol/vycontrol/settings_example/production.py` 文件中的 `ALLOWED_HOST`

~~可以先进入容器直接运行 `sed -i "s/ALLOWED_HOSTS = \['127.0.0.1', \]/ALLOWED_HOSTS = \['127.0.0.1', '192.168.56.3'\]/g" /code/vycontrol/settings_available/production.py` 临时解决~~

永久解决需要手动编辑这个文件然后重新打包.

#### 配置 api

现在开放 api 的命令变成了:

```
vyos@vyos# set service https api keys id vycontrol key 'vyos'
vyos@vyos# run generate pki certificate self-signed install vycontrol-cert

vyos@vyos# set service https certificates certificate vycontrol-cert

vyos@vyos# set service https api rest
vyos@vyos# set service https api graphql
vyos@vyos# set service https api graphql authentication type key

set service https listen-address 192.168.56.3
```

默认运行在 `443` 端口

经过测试已经无法运行,当连接上 instance 后尝试查看 interface 页面时报错:

```
TypeError at /interface/

'bool' object is not iterable

Request Method: 	GET
Request URL: 	http://192.168.56.3:8000/interface/
Django Version: 	5.2.12
Exception Type: 	TypeError
Exception Value: 	

'bool' object is not iterable

Exception Location: 	/code/vyos.py, line 141, in get_firewall_all
Raised during: 	interface.views.index
Python Executable: 	/usr/local/bin/python
Python Version: 	3.14.3
Python Path: 	

['/code',
 '/usr/local/lib/python314.zip',
 '/usr/local/lib/python3.14',
 '/usr/local/lib/python3.14/lib-dynload',
 '/usr/local/lib/python3.14/site-packages']

Server time: 	
```

## 配置 pppoe

### PPPoE 客户端

#### 内核应用层

下面的配置是对于 linux 内核 (应用层) 的 pppoe 客户端配置,而不是 vpp 下的 pppoe 配置:

```
configure
# 解除这张网卡的vpp设置
delete vpp ettings interface eth2
# 删除之前配置的NAT转换
delete vpp nat nat44 interface inside eth2
# 删除网卡的ip设置(pppoe不需要配置IP)
delete interfaces ethernet eth2 address
```

配置 pppoe:

```
# 指定 PPPoE 拨号使用的物理底层网卡
set interfaces pppoe pppoe0 source-interface 'eth2'

# 配置 iKuai 服务端设定的拨号账号和密码
set interfaces pppoe pppoe0 authentication username '1'
set interfaces pppoe pppoe0 authentication password '1'

# 添加接口备注
set interfaces pppoe pppoe0 description 'test'

# 设置 MTU 为 1492（PPPoE 标准最优值，扣除了 8 字节的 PPP 头部）
set interfaces pppoe pppoe0 mtu '1492'

# 开启 IPv4 自动调整 MSS 值
set interfaces pppoe pppoe0 ip adjust-mss 'clamp-mss-to-pmtu'

# 提交和保存
commit
save
```

查看 pppoe1 的状态:

```
show interfaces pppoe pppoe0
 authentication {
     password 1
     username 1
 }
 description test
 ip {
     adjust-mss clamp-mss-to-pmtu
 }
 mtu 1492
 source-interface eth2
[edit]
```

删除 pppoe0 的命令是:

```
delete interfaces pppoe pppoe0
```

#### VPP

经过测试 VPP 根本不支持当作 PPPoE 客户端来拨号,只支持当作 PPPoE 服务端,可以查看这个 [官方接口文档](https://s3-docs.fd.io/vpp/26.06/cli-reference/clis/clicmd_src_plugins_pppoe.html),社区有一个项目是 [vpp-pppoeclient](https://github.com/raydonetworks/vpp-pppoeclient),但最近一次提交是 2018 年了,支持的应该是 VPP 的 1710 版本.

下面的步骤是根据一个 VPP 当作 PPPoE 服务端时进行自动拨号的博客进行的失败的逆向尝试:

- [Learning VPP: Automating PPPoE server session creation](https://haryachyy.wordpress.com/2025/05/20/learning-vpp-automating-pppoe-server-session-creation/)
- [Automating PPPoE Server Session Creation with VPP](https://medium.com/@denys.haryachyy/automating-pppoe-server-session-creation-with-vpp-1d83a97114cc)

首先启用 vpp 接管这张网卡:

```
set vpp settings interface eth2 
vppctl set interface state eth2 up
```

创建一个 tap 接口:

```
vppctl create tap id 0 host-if-name vpp-tap-cp
vppctl set interface state tap0 up
```

可以用下面的命令查看 vpp 接口:

```
vppctl show interface

Name                              Idx    State  
eth2                              1      up
tap0                              5      up
```

配置 pppoe 包转发:

```
vppctl create pppoe map dp eth2 cp tap0
```

意思是将 `eth2` 的 `pppoe` 请求转发到 `tap0` 接口

拨号之前还需要将 `eth2` 和 `tap0` 二层连接起来 (即互相转发任何请求),否则 tap0 的请求会被 eth2 直接丢弃:

```
vppctl set interface l2 xconnect eth2 tap0
vppctl set interface l2 xconnect tap0 eth2
vppctl set interface state eth2 up
vppctl set interface state tap0 up
```

然后进行拨号:

```
sudo pppd pty "pppoe -I vpp-tap-cp" user 1 password 1 nodetach debug noauth defaultroute lcp-echo-interval 0
```

最好另起一个终端进行抓包:

```
sudo tcpdump -e -n -i vpp-tap-cp pppoes or pppoed
```

下面是拨号成功时 `pppd` 的输出和 `tcpdump` 的输出:

```
$ sudo pppd pty "pppoe -I vpp-tap-cp" user 1 password 1 nodetach debug noauth defaultroute lcp-echo-interval 0

...
rcvd [CHAP Success id=0xd3 "Access granted"]
CHAP authentication succeeded: Access granted
CHAP authentication succeeded
...
local  IP address 172.16.0.2    # ISP分配给的IP
remote IP address 10.0.100.1    # ISP网关的IP

$ sudo tcpdump -e -n -i vpp-tap-cp pppoes or pppoed

...
# 服务端mac > 客户端mac [ses 0x1] 的意思是sessions的id是1
02:28:41.958123 28:a6:db:4c:b4:4a > 02:fe:bd:7b:98:fa, ethertype PPPoE S (0x8864), length 60: PPPoE  [ses 0x3] LCP (0xc021), length 10: LCP, Echo-Request (0x09), id 69, length 10
02:28:41.958208 02:fe:bd:7b:98:fa > 28:a6:db:4c:b4:4a, ethertype PPPoE S (0x8864), length 30: PPPoE  [ses 0x3] LCP (0xc021), length 10: LCP, Echo-Reply (0x0a), id 69, length 10
```

> PPPoE 的心跳检测 (Echo-Request) 通常是由服务器发起的,因此第一行是服务器 mac 地址 > 客户端 mac 地址

我们需要提取上面的三个参数: ISP 的 IP(10.0.100.1),服务端的 mac 地址 (02:fe:bd:7b:98:fa) 和 session id(1)

### PPPoE 服务端

目标：将一台启用 VPP 的 VyOS 服务器作为 PPPoE 服务端 (称作 vpp 服务器)，另一台 VyOS 服务器作为 PPPoE 客户端 (称作 vyos 服务器) 发起多个会话并聚合数据，测试 VPP 作为 PPPoE 服务端的性能。

架构如下:

![](assets/vyos/配置数据面-20260414112801075.png)

- **认证请求**：客户端 → eth2 → tap4096 → Linux 内核 (accel-ppp) → 鉴权/IP 分配
- **业务请求**：客户端 → eth2 → VPP 直接查 fib 表 → eth3 → 10.0.0.2（完全绕过 Linux 内核）

#### 配置控制面

##### vpp 启动 PPPoE 服务器

```bash
configure
# 为 VPP 引擎分配计算资源
set vpp settings resource-allocation cpu-cores '4'
# 允许使用不受官方支持的网卡 (针对 KVM virtio 或普通消费级物理网卡必开)
set vpp settings allow-unsupported-nics
# 将物理网卡交由 VPP 接管，并开启多队列提升并发
set vpp settings interface eth2
set vpp settings interface eth2 num-rx-queues '4'
set vpp settings interface eth2 num-tx-queues '4'
# 直接让 PPPoE 监听已经被 VPP 接管的 eth2 物理网卡
set service pppoe-server interface eth2
# PPPoE 服务端参数
set service pppoe-server access-concentrator 'VPP-Gateway'
set service pppoe-server authentication mode 'local'
set service pppoe-server authentication local-users username test password 'test'
set service pppoe-server client-ip-pool MY-POOL range '10.200.200.100-10.200.200.200'
set service pppoe-server default-pool 'MY-POOL'
set service pppoe-server gateway-address '10.200.200.1'
commit
save
exit
```

##### vyos 启动 PPPoE 客户端

客户端使用下面的命令配置后会自动发起拨号:

```bash
configure
set interfaces pppoe pppoe0 source-interface eth3
set interfaces pppoe pppoe0 authentication user 'test'
set interfaces pppoe pppoe0 authentication password 'test'
commit
save
exit
```

然后在客户端和服务端都可以看到 Clinet IP,Session id 等信息:

```
# 客户端
$ show interfaces pppoe
Codes: S - State, L - Link, u - Up, D - Down, A - Admin Down
Interface        IP Address                        S/L  Description
---------        ----------                        ---  -----------
pppoe0           10.200.200.100/32                 u/u

# 服务端
$ show pppoe-server sessions
 ifname     | username |       ip       | ip6 | ip6-dp |    calling-sid    | rate-limit | state  |  uptime  | rx-bytes | tx-bytes
----------------+----------+----------------+-----+--------+-------------------+------------+--------+----------+----------+----------
 pppoe_session0 | test     | 10.200.200.100 |     |        | 6c:92:bf:3a:8a:4b |            | active | 00:00:17 | 0 B      | 0 B

$ vppctl show pppoe session
Number of PPPoE sessions: 1
[0] sw-if-index 3 client-ip4 0.0.0.0 client-ip6 0.0.0.0/0 session-id 1 encap-if-index 1 decap-fib-index 0
    local-mac 90:e2:ba:25:43:2c  client-mac 6c:92:bf:3a:8a:4b
```

注意,客户端的 `show interfaces pppoe` 命令必须退出配置模式后运行:

```
vyos@vyos# show interfaces pppoe
 pppoe pppoe0 {
     authentication {
         password test
         username test
     }
     source-interface eth3
 }
[edit]
vyos@vyos# exit
Warning: configuration changes have not been saved.
exit
vyos@vyos:~$ show interfaces pppoe
Codes: S - State, L - Link, u - Up, D - Down, A - Admin Down
Interface        IP Address                        S/L  Description
---------        ----------                        ---  -----------
pppoe0           10.200.200.101/32                 u/u
```

#### 配置数据面

##### 配置 lookup

通过上面的配置虽然获取到了 IP 和 Session，但是此时通道还不能使用，客户端尝试 ping 无法 ping 通。

查看 vpp 的 PPPoE 会话信息:

```
$ vppctl show pppoe session
Number of PPPoE sessions: 1
[0] sw-if-index 3 client-ip4 0.0.0.0 client-ip6 0.0.0.0/0 session-id 1 encap-if-index 1 decap-fib-index 0
    local-mac 90:e2:ba:25:43:2c  client-mac 6c:92:bf:3a:8a:4b
```

在客户端抓包网卡可以看到已经正常的发出了 ping 请求:

```
$ sudo tcpdump -i eth3 -n
02:22:35.162658 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 1, length 64
02:22:36.202238 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 2, length 64
02:22:37.226243 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 3, length 64
02:22:38.250238 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 4, length 64
02:22:39.274233 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 5, length 64
02:22:40.298235 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 6, length 64
02:22:41.322237 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 7, length 64
02:22:42.346236 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 8, length 64
02:22:43.370235 PPPoE  [ses 0x1] IP 10.200.200.100 > 10.200.200.1: ICMP echo request, id 3926, seq 9, length 64
```

在服务端查看 vppctl 的错误信息:

```
$ vppctl show error
   Count                  Node                              Reason               Severity
         9             null-node                      blackholed packets           error
        10            pppoe-input                 good packets decapsulated        error
         1            pppoe-input                 good packets decapsulated        error
```

`good packets decapsulated` 表示成功解封装,`blackholed packets` 表示 ping 请求直接被扔到了黑洞 (blackholed) 中

查看 VPP 的 FIB 表:

```
$ vppctl show ip fib 10.200.200.1/32
ipv4-VRF:0, fib_index:0, flow hash:[src dst sport dport proto flowlabel ] epoch:0 flags:none locks:[default-route:1, lcp-rt:1, ]
0.0.0.0/0 fib:0 index:0 locks:2
  default-route refs:1 entry-flags:drop, src-flags:added,contributing,active,
    path-list:[0] locks:2 flags:drop, uPRF-list:0 len:0 itfs:[]
      path:[0] pl-index:0 ip4 weight=1 pref=0 special:  cfg-flags:drop,
        [@0]: dpo-drop ip4

 forwarding:   unicast-ip4-chain
  [@0]: dpo-load-balance: [proto:ip4 index:1 buckets:1 uRPF:0 to:[29:2436]]
    [0] [@0]: dpo-drop ip4
```

该 ip 没有 fib 表,所以被 `0.0.0.0/0` 条目捕获, 意味着 VPP 不知道 `10.200.200.1` 就是自己,没有找到相关的路由就把包直接被丢弃了

可以直接在 vpp 中创建一个 `loop0` 网卡,并配置上网关 (`10.200.200.1/32`) 的 IP,然后 VPP 会自动添加到 FIB 表,这样目标 ip 是网关的请求就不会被丢弃:

```
vyos@vyos:~$ vppctl create loopback interface
loop0
vyos@vyos:~$ vppctl set interface state loop0 up
vyos@vyos:~$ vppctl set interface ip address loop0 10.200.200.1/32
vyos@vyos:~$ vppctl show ip fib 10.200.200.1/32
ipv4-VRF:0, fib_index:0, flow hash:[src dst sport dport proto flowlabel ] epoch:0 flags:none locks:[default-route:1, lcp-rt:1, ]
10.200.200.1/32 fib:0 index:12 locks:2
  interface refs:1 entry-flags:connected,local, src-flags:added,contributing,active, cover:0
    path-list:[25] locks:2 flags:local, uPRF-list:15 len:0 itfs:[]
      path:[32] pl-index:25 ip4 weight=1 pref=0 receive:  oper-flags:resolved, cfg-flags:local,
        [@0]: dpo-receive: 10.200.200.1 on loop0

 forwarding:   unicast-ip4-chain
  [@0]: dpo-load-balance: [proto:ip4 index:13 buckets:1 uRPF:15 to:[0:0]]
    [0] [@12]: dpo-receive: 10.200.200.1 on loop0
```

此时可以看到 `10.200.200.1 on loop0` 代表 VPP 会直接处理它.

PPPoE 隧道建立后客户端自动配置好了网关:

```
$ ip r
default nhid 40 dev pppoe0 proto static metric 20
10.200.200.1 dev pppoe0 proto kernel scope link src 10.200.200.102
192.168.1.0/24 dev eth2 proto kernel scope link src 192.168.1.1
192.168.2.0/24 dev eth0 proto kernel scope link src 192.168.2.2 dead linkdown
192.168.88.0/24 dev eth1 proto kernel scope link src 192.168.88.107
```

现在从 Vyos 服务器上就可以直接 ping 通 VPP 服务器上联的测试服务端 `10.0.0.2`:

```
$ ping 10.0.0.2
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=63 time=0.103 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=63 time=0.061 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=63 time=0.065 ms
64 bytes from 10.0.0.2: icmp_seq=4 ttl=63 time=0.059 ms
64 bytes from 10.0.0.2: icmp_seq=5 ttl=63 time=0.065 ms
```

可以查看 `vppctl show interface` 的输出确定 (eth2 和 eth3 的传入/传出数同时增加) 或者查看链路:

```
vyos@vyos:~$ vppctl clear trace
vyos@vyos:~$ vppctl trace add dpdk-input 10
vyos@vyos:~$ vppctl show trace

00:20:28:825521: dpdk-input
  eth3 rx queue 3      <-- 【外网回包从 eth3 硬件队列进入。注意这里是 Thread 2 (vpp_wk_1)，证明你的多核多线程 RSS 起作用了！】
  ...
00:20:28:825527: ip4-lookup
  ICMP: 10.0.0.2 -> 10.200.200.102   <-- 【VPP 查表，发现目标 10.200.200.102 属于拨号用户】
  ...
00:20:28:825527: ip4-midchain
  tx_sw_if_index 5 dpo-idx 9 : ipv4 via 0.0.0.0 pppoe_session0  <-- 【VPP 触发隧道封装机制，准备为这个纯 IP 包穿上 PPPoE 衣服】
  ...
00:20:28:825528: tunnel-output
  adj-midchain:[9]:ipv4 via 0.0.0.0 pppoe_session0
00:20:28:825529: eth2-tx
  eth2 tx queue 2      <-- 【穿好 PPPoE 和以太网外衣后，直接由 eth2 硬件网卡发射回客户端。闭环完成！】
```

##### 配置 SNAT

此时 VyOS 服务器下联的的两台测试客户端还无法 ping 通测试服务端:

```
$ sudo tcpdump -i eth3 -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth3, link-type EN10MB (Ethernet), snapshot length 262144 bytes
02:25:31.856158 PPPoE  [ses 0x1] IP 192.168.1.101 > 10.0.0.2: ICMP echo request, id 2630, seq 1, length 64
02:25:32.855329 PPPoE  [ses 0x1] IP 192.168.1.101 > 10.0.0.2: ICMP echo request, id 2630, seq 2, length 64
02:25:33.855333 PPPoE  [ses 0x1] IP 192.168.1.101 > 10.0.0.2: ICMP echo request, id 2630, seq 3, length 64
02:25:34.855314 PPPoE  [ses 0x1] IP 192.168.1.101 > 10.0.0.2: ICMP echo request, id 2630, seq 4, length 64
```

这是因为还没有配置 NAT 转换,在 VPP 服务器上错误是这样的:

```
$ vppctl show error
   Count                  Node                              Reason               Severity
        29            pppoe-input                 good packets decapsulated        error
        18             dpdk-input                          no error                error
```

可以在 VPP 上抓包一下 trace 路径:

```
vyos@vyos:~$ vppctl clear trace
vyos@vyos:~$ vppctl trace add dpdk-input 10
vyos@vyos:~$ vppctl show trace
------------------- Start of thread 0 vpp_main -------------------
No packets in trace buffer
------------------- Start of thread 1 vpp_wk_0 -------------------
Packet 1

00:56:56:744514: dpdk-input
  eth2 rx queue 0
  buffer 0x13f475: current data 0, length 106, buffer-pool 0, ref-count 1, trace handle 0x1000000
                   ext-hdr-valid
  PKT MBUF: port 0, nb_segs 1, pkt_len 106
    buf_len 2176, data_len 106, ol_flags 0x180, data_off 128, phys_addr 0x75dd1dc0
    packet_type 0x1 l2_len 0 l3_len 0 outer_l2_len 0 outer_l3_len 0
    rss 0x0 fdir.hi 0x0 fdir.lo 0x0
    Packet Offload Flags
      PKT_RX_IP_CKSUM_GOOD (0x0080) IP cksum of RX pkt. is valid
      PKT_RX_L4_CKSUM_GOOD (0x0100) L4 cksum of RX pkt. is valid
    Packet Types
      RTE_PTYPE_L2_ETHER (0x0001) Ethernet packet
  PPPOE_SESSION: 6c:92:bf:3a:8a:4b -> 90:e2:ba:25:43:2c
00:56:56:744517: ethernet-input
  frame: flags 0x3, hw-if-index 1, sw-if-index 1
  PPPOE_SESSION: 6c:92:bf:3a:8a:4b -> 90:e2:ba:25:43:2c
00:56:56:744519: pppoe-input
  PPPoE decap from pppoe_session0 session_id 1 next 1 error 0
00:56:56:744519: ip4-input
  ICMP: 192.168.1.101 -> 10.0.0.2
    tos 0x00, ttl 63, length 84, checksum 0x848b dscp CS0 ecn NON_ECN
    fragment id 0xeb0e, flags DONT_FRAGMENT
  ICMP echo_request checksum 0xb7bb id 3232
00:56:56:744520: ip4-lookup
  fib 0 dpo-idx 9 flow hash: 0x00000000
  ICMP: 192.168.1.101 -> 10.0.0.2
    tos 0x00, ttl 63, length 84, checksum 0x848b dscp CS0 ecn NON_ECN
    fragment id 0xeb0e, flags DONT_FRAGMENT
  ICMP echo_request checksum 0xb7bb id 3232
00:56:56:744521: ip4-rewrite
  tx_sw_if_index 2 dpo-idx 9 : ipv4 via 10.0.0.2 eth3: mtu:1500 next:6 flags:[] 6c92bf044b2190e2ba25432d0800 flow hash: 0x00000000
  00000000: 6c92bf044b2190e2ba25432d080045000054eb0e40003e01858bc0a801650a00
  00000020: 00020800b7bb0ca000019cbcdd6900000000f8a90200000000001011
00:56:56:744521: eth3-output
  eth3 flags 0x0018000d
  IP4: 90:e2:ba:25:43:2d -> 6c:92:bf:04:4b:21
  ICMP: 192.168.1.101 -> 10.0.0.2
    tos 0x00, ttl 62, length 84, checksum 0x858b dscp CS0 ecn NON_ECN
    fragment id 0xeb0e, flags DONT_FRAGMENT
  ICMP echo_request checksum 0xb7bb id 3232
00:56:56:744522: eth3-tx
  eth3 tx queue 1
  buffer 0x13f475: current data 8, length 98, buffer-pool 0, ref-count 1, trace handle 0x1000000
                   ext-hdr-valid
                   l2-hdr-offset 0 l3-hdr-offset 14
  PKT MBUF: port 0, nb_segs 1, pkt_len 98
    buf_len 2176, data_len 98, ol_flags 0x180, data_off 136, phys_addr 0x75dd1dc0
    packet_type 0x1 l2_len 0 l3_len 0 outer_l2_len 0 outer_l3_len 0
    rss 0x0 fdir.hi 0x0 fdir.lo 0x0
    Packet Offload Flags
      PKT_RX_IP_CKSUM_GOOD (0x0080) IP cksum of RX pkt. is valid
      PKT_RX_L4_CKSUM_GOOD (0x0100) L4 cksum of RX pkt. is valid
    Packet Types
      RTE_PTYPE_L2_ETHER (0x0001) Ethernet packet
  IP4: 90:e2:ba:25:43:2d -> 6c:92:bf:04:4b:21
  ICMP: 192.168.1.101 -> 10.0.0.2
    tos 0x00, ttl 62, length 84, checksum 0x858b dscp CS0 ecn NON_ECN
    fragment id 0xeb0e, flags DONT_FRAGMENT
  ICMP echo_request checksum 0xb7bb id 3232

Packet 2

00:56:56:744556: dpdk-input
  eth3 rx queue 2
  buffer 0x151f0d: current data 0, length 98, buffer-pool 0, ref-count 1, trace handle 0x1000001
                   ext-hdr-valid
  PKT MBUF: port 1, nb_segs 1, pkt_len 98
    buf_len 2176, data_len 98, ol_flags 0x182, data_off 128, phys_addr 0x7567c3c0
    packet_type 0x11 l2_len 0 l3_len 0 outer_l2_len 0 outer_l3_len 0
    rss 0x666a73fa fdir.hi 0x0 fdir.lo 0x666a73fa
    Packet Offload Flags
      PKT_RX_IP_CKSUM_GOOD (0x0080) IP cksum of RX pkt. is valid
      PKT_RX_L4_CKSUM_GOOD (0x0100) L4 cksum of RX pkt. is valid
      PKT_RX_RSS_HASH (0x0002) RX packet with RSS hash result
    Packet Types
      RTE_PTYPE_L2_ETHER (0x0001) Ethernet packet
      RTE_PTYPE_L3_IPV4 (0x0010) IPv4 packet without extension headers
  IP4: 6c:92:bf:04:4b:21 -> 90:e2:ba:25:43:2d
  ICMP: 10.0.0.2 -> 192.168.1.101
    tos 0x00, ttl 64, length 84, checksum 0xca1a dscp CS0 ecn NON_ECN
    fragment id 0xe47f
  ICMP echo_reply checksum 0xbfbb id 3232
00:56:56:744557: ethernet-input
  frame: flags 0x3, hw-if-index 2, sw-if-index 2
  IP4: 6c:92:bf:04:4b:21 -> 90:e2:ba:25:43:2d
00:56:56:744557: ip4-input-no-checksum
  ICMP: 10.0.0.2 -> 192.168.1.101
    tos 0x00, ttl 64, length 84, checksum 0xca1a dscp CS0 ecn NON_ECN
    fragment id 0xe47f
  ICMP echo_reply checksum 0xbfbb id 3232
00:56:56:744558: ip4-lookup
  fib 0 dpo-idx 0 flow hash: 0x00000000
  ICMP: 10.0.0.2 -> 192.168.1.101
    tos 0x00, ttl 64, length 84, checksum 0xca1a dscp CS0 ecn NON_ECN
    fragment id 0xe47f
  ICMP echo_reply checksum 0xbfbb id 3232
00:56:56:744558: ip4-drop    // 10.0.0.2返回之后没有找到路由,直接丢弃
    fib:0 adj:0 flow:0x00000000
  ICMP: 10.0.0.2 -> 192.168.1.101
    tos 0x00, ttl 64, length 84, checksum 0xca1a dscp CS0 ecn NON_ECN
    fragment id 0xe47f
  ICMP echo_reply checksum 0xbfbb id 3232
00:56:56:744558: error-drop
  rx:eth3
00:56:56:744559: drop
  dpdk-input: no error
```

可以看到因为 Vyos 服务器上没有配置 NAT 转换,导致错误的使用测试服务端的 IP 请求,在 VPP 服务器上由于配置了默认路由,因此成功转发到了 `10.0.0.2` 服务器,`10.0.0.2` 服务器同样由于配置了默认路由也返回了 VPP,但是 VPP 内部没有找到该局域网的地址,直接丢弃了返回的请求

在 Vyos 和 `10.0.0.2` 上抓包也印证了这一点:

```
vyos@vyos:~$ sudo tcpdump -i eth3 -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on eth3, link-type EN10MB (Ethernet), snapshot length 262144 bytes
02:35:38.362604 PPPoE  [ses 0x1] LCP, Echo-Request (0x09), id 169, length 10
02:35:38.362759 PPPoE  [ses 0x1] LCP, Echo-Reply (0x0a), id 169, length 10
02:35:43.439898 PPPoE  [ses 0x1] IP 192.168.1.101 > 10.0.0.2: ICMP echo request, id 3232, seq 1, length 64

[root@100 ~]# sudo tcpdump -i ens3f1 -n
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ens3f1, link-type EN10MB (Ethernet), capture size 262144 bytes
20:05:02.147354 IP 192.168.1.101 > 10.0.0.2: ICMP echo request, id 3232, seq 1, length 64
20:05:02.147367 IP 10.0.0.2 > 192.168.1.101: ICMP echo reply, id 3232, seq 1, length 64
```

在 vyos 上配置内核的 nat 转换,把所有源 ip 是 `192.168.1.0/24`,出口是 `pppoe0` 的请求进行 SNAT 转换:

```
vyos@vyos# set nat source rule 100 outbound-interface name 'pppoe0'
[edit]
vyos@vyos# set nat source rule 100 source address '192.168.1.0/24'
[edit]
vyos@vyos# set nat source rule 100 translation address 'masquerade'
[edit]
vyos@vyos# commit
[edit]
vyos@vyos# save
[edit]
vyos@vyos# exit
exit
```

然后就可以正常的转发请求:

```
[root@101 ~]# ping 10.0.0.2 -c 1
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=62 time=0.232 ms

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.232/0.232/0.232/0.000 ms
```

#### 操作 PPPoE 客户端

关闭 PPPOE 客户端可以使用:

```
vyos@vyos:~$ configure
[edit]
vyos@vyos# set interfaces pppoe pppoe0 disable
[edit]
vyos@vyos# commit
```

重新打开的时候运行:

```
vyos@vyos# delete interfaces pppoe pppoe0 disable
[edit]
vyos@vyos# commit
[edit]
```

#### 通过 Packet Trace 分析数据报文转发机制

现在当成功建立起 PPPoE 隧道之后 PPPoE session 中显示的 `client-ip4` 是 `0.0.0.0`:

```
vyos@vyos:~$ show pppoe-server sessions
 ifname     | username |       ip       | ip6 | ip6-dp |    calling-sid    | rate-limit | state  |  uptime  | rx-bytes | tx-bytes
----------------+----------+----------------+-----+--------+-------------------+------------+--------+----------+----------+----------
 pppoe_session0 | test     | 10.200.200.100 |     |        | 6c:92:bf:3a:8a:4b |            | active | 00:13:15 | 0 B      | 0 B
```

但此时依旧可以正常的转发,trace 抓包如下:

```
vyos@vyos:~$ vppctl clear trace
vyos@vyos:~$ vppctl trace add dpdk-input 10
vyos@vyos:~$ vppctl show trace
------------------- Start of thread 0 vpp_main -------------------
No packets in trace buffer
------------------- Start of thread 1 vpp_wk_0 -------------------
Packet 1

00:21:46:304594: dpdk-input
  eth2 rx queue 0
  buffer 0x194d92: current data 0, length 106, buffer-pool 0, ref-count 1, trace handle 0x1000000
                   ext-hdr-valid
  PKT MBUF: port 0, nb_segs 1, pkt_len 106
    buf_len 2176, data_len 106, ol_flags 0x180, data_off 128, phys_addr 0x74736500
    packet_type 0x1 l2_len 0 l3_len 0 outer_l2_len 0 outer_l3_len 0
    rss 0x0 fdir.hi 0x0 fdir.lo 0x0
    Packet Offload Flags
      PKT_RX_IP_CKSUM_GOOD (0x0080) IP cksum of RX pkt. is valid
      PKT_RX_L4_CKSUM_GOOD (0x0100) L4 cksum of RX pkt. is valid
    Packet Types
      RTE_PTYPE_L2_ETHER (0x0001) Ethernet packet
  PPPOE_SESSION: 6c:92:bf:3a:8a:4b -> 90:e2:ba:25:43:2c
00:21:46:304602: ethernet-input
  frame: flags 0x3, hw-if-index 1, sw-if-index 1
  PPPOE_SESSION: 6c:92:bf:3a:8a:4b -> 90:e2:ba:25:43:2c
00:21:46:304605: pppoe-input
  PPPoE decap from pppoe_session0 session_id 1 next 1 error 0
00:21:46:304606: ip4-input
  ICMP: 10.200.200.100 -> 10.0.0.2
    tos 0x00, ttl 63, length 84, checksum 0x8408 dscp CS0 ecn NON_ECN
    fragment id 0xda72, flags DONT_FRAGMENT
  ICMP echo_request checksum 0x86b5 id 2458
00:21:46:304609: ip4-lookup
  fib 0 dpo-idx 9 flow hash: 0x00000000
  ICMP: 10.200.200.100 -> 10.0.0.2
    tos 0x00, ttl 63, length 84, checksum 0x8408 dscp CS0 ecn NON_ECN
    fragment id 0xda72, flags DONT_FRAGMENT
  ICMP echo_request checksum 0x86b5 id 2458
00:21:46:304612: ip4-rewrite
  tx_sw_if_index 2 dpo-idx 9 : ipv4 via 10.0.0.2 eth3: mtu:1500 next:6 flags:[] 6c92bf044b2190e2ba25432d0800 flow hash: 0x00000000
  00000000: 6c92bf044b2190e2ba25432d080045000054da7240003e0185080ac8c8640a00
  00000020: 0002080086b5099a00014c58e069000000006e1a0e00000000001011
00:21:46:304612: eth3-output
  eth3 flags 0x0018000d
  IP4: 90:e2:ba:25:43:2d -> 6c:92:bf:04:4b:21
  ICMP: 10.200.200.100 -> 10.0.0.2
    tos 0x00, ttl 62, length 84, checksum 0x8508 dscp CS0 ecn NON_ECN
    fragment id 0xda72, flags DONT_FRAGMENT
  ICMP echo_request checksum 0x86b5 id 2458
00:21:46:304614: eth3-tx
  eth3 tx queue 1
  buffer 0x194d92: current data 8, length 98, buffer-pool 0, ref-count 1, trace handle 0x1000000
                   ext-hdr-valid
                   l2-hdr-offset 0 l3-hdr-offset 14
  PKT MBUF: port 0, nb_segs 1, pkt_len 98
    buf_len 2176, data_len 98, ol_flags 0x180, data_off 136, phys_addr 0x74736500
    packet_type 0x1 l2_len 0 l3_len 0 outer_l2_len 0 outer_l3_len 0
    rss 0x0 fdir.hi 0x0 fdir.lo 0x0
    Packet Offload Flags
      PKT_RX_IP_CKSUM_GOOD (0x0080) IP cksum of RX pkt. is valid
      PKT_RX_L4_CKSUM_GOOD (0x0100) L4 cksum of RX pkt. is valid
    Packet Types
      RTE_PTYPE_L2_ETHER (0x0001) Ethernet packet
  IP4: 90:e2:ba:25:43:2d -> 6c:92:bf:04:4b:21
  ICMP: 10.200.200.100 -> 10.0.0.2
    tos 0x00, ttl 62, length 84, checksum 0x8508 dscp CS0 ecn NON_ECN
    fragment id 0xda72, flags DONT_FRAGMENT
  ICMP echo_request checksum 0x86b5 id 2458
```

去程负责**解封装**，回程负责**按需封装**。

去程链路：客户端 ➔ VPP ➔ 外网 (如 10.0.0.2)

**核心特征：** 剥离 PPPoE 隧道，执行标准 IP 路由转发。

1. **`dpdk-input` (物理入站)**：携带 PPPoE 头部的以太网帧从下联物理网卡（`eth2`）进入 VPP 内存缓冲。
2. **`pppoe-input` (隧道解封)**：VPP 校验报文的 MAC 地址与 PPPoE Session ID。验证通过后，直接剥离 PPPoE 及底层以太网头部，露出内层纯 IPv4 报文。
3. **`ip4-input` (安全校验)**：对裸露的 IPv4 报文进行基础合法性检查（如 Checksum、头部长度、TTL）。
4. **`ip4-lookup` (路由查找)**：根据目标 IP (`10.0.0.2`) 查询硬件 FIB 表。命中直连路由或默认路由，确定出接口为上联物理口 `eth3`。
5. **`ip4-rewrite` (二层重写)**：标准的路由转发动作。将报文的目标 MAC 改写为下一跳网关 MAC，源 MAC 改写为 `eth3` MAC，TTL 减 1。
6. **`eth3-tx` (物理出站)**：将处理完毕的标准 IP 报文交由 DPDK，从物理网卡发送至外网。

回程链路：外网 (如 10.0.0.2) ➔ VPP ➔ 客户端

**核心特征：** 精准命中主机路由，触发动态隧道封装。

1. **`dpdk-input` (物理入站)**：外网返回的标准纯 IP 报文从上联物理网卡（`eth3`）进入。
2. **`ethernet-input` & `ip4-input` (二三层解析)**：识别以太网帧并进行基础 IP 校验（此时报文无 PPPoE 头部）。
3. **`ip4-lookup` (路由查找)**：根据目标 IP (`10.200.200.100`) 查询 FIB 表。**命中由 VyOS 控制面通过 API 动态下发的 `/32` 客户端专属主机路由**，确定出接口为虚拟隧道接口 `pppoe_session0`。
4. **`ip4-midchain` (隧道封装 - 核心步骤！)**：由于出接口是隧道，VPP 触发中间链（Midchain）处理机制。在此节点，VPP 将原本的纯 IP 报文作为 Payload，强行在其外部封装上之前协商好的 PPPoE 头部（含 Session ID）和对应的客户端 MAC 地址。
5. **`tunnel-output` (虚拟出站)**：完成隧道打包，将封装好的报文引流至底层的承载物理接口。
6. **`eth2-tx` (物理出站)**：携带完整 PPPoE 头部的数据帧从下联物理网卡发送回客户端，完成网络闭环。

回程之所以能通，根本原因在于 VyOS 的控制面（大脑）在建立 PPPoE 会话的瞬间，通过 `vl_api_ip_route_add_del_t` 接口，向 VPP 强行注入了一条指向该客户端的 `/32` 主机路由。

去程依靠网络基础路由配置（网段/默认路由），回程依靠控制面动态下发的主机路由。VPP 实现了完美的**无状态数据面**，只认流表，不问来源。

可以看到在 `ip4-lookup` 环节之后直接进行了 `ip4-midchain`,然后从 `eth3` 接口转发了出去,这是因为 vpp 成功从 fib 中查找到了此 ip 的路由表:

```
vyos@vyos:~$ vppctl show ip fib 10.200.200.100/32
ipv4-VRF:0, fib_index:0, flow hash:[src dst sport dport proto flowlabel ] epoch:0 flags:none locks:[adjacency:1, default-route:1, lcp-rt:1, ]
10.200.200.100/32 fib:0 index:18 locks:2
  API refs:1 entry-flags:attached, src-flags:added,contributing,active,
    path-list:[31] locks:2 flags:shared, uPRF-list:21 len:1 itfs:[5, ]
      path:[39] pl-index:31 ip4 weight=1 pref=0 attached-nexthop:  oper-flags:resolved, cfg-flags:attached,
        10.200.200.100 pppoe_session0 (p2p)
      [@0]: ipv4 via 0.0.0.0 pppoe_session0: mtu:9000 next:7 flags:[] 6c92bf3a8a4b90e2ba25432c88641100000100000021
             stacked-on:
               [@2]: eth2-tx-dpo:

 forwarding:   unicast-ip4-chain
  [@0]: dpo-load-balance: [proto:ip4 index:19 buckets:1 uRPF:21 to:[10:840]]
    [0] [@6]: ipv4 via 0.0.0.0 pppoe_session0: mtu:9000 next:7 flags:[] 6c92bf3a8a4b90e2ba25432c88641100000100000021
        stacked-on:
          [@2]: eth2-tx-dpo:
```

#### 通过 API Trace 分析 FIB 路由下发机制

我们可以通过检查 api trace 来查看这个过程:

```
# 客户端停止pppoe隧道
vyos@vyos:~$ configure
[edit]
vyos@vyos# set interfaces pppoe pppoe0 disable
[edit]
vyos@vyos# commit
[edit]

# 服务端查看fib表,可以看到已经消失(被捕获到0.0.0.0):
vyos@vyos:~$ vppctl show ip fib 10.200.200.100/32
ipv4-VRF:0, fib_index:0, flow hash:[src dst sport dport proto flowlabel ] epoch:0 flags:none locks:[adjacency:1, default-route:1, lcp-rt:1, ]
0.0.0.0/0 fib:0 index:0 locks:2
  default-route refs:1 entry-flags:drop, src-flags:added,contributing,active,
    path-list:[0] locks:2 flags:drop, uPRF-list:0 len:0 itfs:[]
      path:[0] pl-index:0 ip4 weight=1 pref=0 special:  cfg-flags:drop,
        [@0]: dpo-drop ip4

 forwarding:   unicast-ip4-chain
  [@0]: dpo-load-balance: [proto:ip4 index:1 buckets:1 uRPF:0 to:[0:0]]
    [0] [@0]: dpo-drop ip4

# 服务端清空并打开trace记录
vyos@vyos:~$ vppctl api trace free
vyos@vyos:~$ vppctl api trace on

# 客户端重新打开PPPoE隧道
vyos@vyos# delete interfaces pppoe pppoe0 disable
[edit]
vyos@vyos# commit
[edit]
vyos@vyos# exit
Warning: configuration changes have not been saved.
exit

vyos@vyos:~$ show interfaces pppoe
Codes: S - State, L - Link, u - Up, D - Down, A - Admin Down
Interface        IP Address                        S/L  Description
---------        ----------                        ---  -----------
pppoe0           10.200.200.101/32                 u/u

# 查看新路由的fib表
vyos@vyos:~$ vppctl show ip fib 10.200.200.101/32
ipv4-VRF:0, fib_index:0, flow hash:[src dst sport dport proto flowlabel ] epoch:0 flags:none locks:[adjacency:1, default-route:1, lcp-rt:1, ]
10.200.200.101/32 fib:0 index:18 locks:2
  API refs:1 entry-flags:attached, src-flags:added,contributing,active,
    path-list:[31] locks:2 flags:shared, uPRF-list:21 len:1 itfs:[5, ]
      path:[39] pl-index:31 ip4 weight=1 pref=0 attached-nexthop:  oper-flags:resolved, cfg-flags:attached,
        10.200.200.101 pppoe_session0 (p2p)
      [@0]: ipv4 via 0.0.0.0 pppoe_session0: mtu:9000 next:7 flags:[] 6c92bf3a8a4b90e2ba25432c88641100004000000021
             stacked-on:
               [@2]: eth2-tx-dpo:

 forwarding:   unicast-ip4-chain
  [@0]: dpo-load-balance: [proto:ip4 index:19 buckets:1 uRPF:21 to:[0:0]]
    [0] [@6]: ipv4 via 0.0.0.0 pppoe_session0: mtu:9000 next:7 flags:[] 6c92bf3a8a4b90e2ba25432c88641100004000000021
        stacked-on:
          [@2]: eth2-tx-dpo:
```

查看 api trace 记录:

```
vyos@vyos:~$ vppctl api trace dump
vl_api_pppoe_add_del_session_t:
  is_add: 1
  session_id: 64
  client_ip: 0.0.0.0
  decap_vrf_id: 0
  client_mac: 6c92.bf3a.8a4b
  disable_fib: 1
vl_api_sw_interface_dump_t:
  sw_if_index: 5
  name_filter_valid: 0
  name_filter:
vl_api_control_ping_t:
vl_api_feature_enable_disable_t:
  sw_if_index: 5
  enable: 0
  arc_name: ip4-unicast
  feature_name: ip4-not-enabled
vl_api_ip_route_add_del_t:
  is_add: 1
  is_multipath: 0
  route:
    table_id: 0
    stats_index: 0
    prefix: 10.200.200.101/32
    n_paths: 1
    paths:
      sw_if_index: 5
      table_id: 0
      rpf_id: 0
      weight: 0
      preference: 0
      type: FIB_API_PATH_TYPE_NORMAL
      flags: FIB_API_PATH_FLAG_NONE
      proto: FIB_API_PATH_NH_PROTO_IP4
      nh:
        address:
          ip4: 0.0.0.0
          ip6: ::
        via_label: 0
        obj_id: 0
        classify_table_index: 0
      n_labels: 0
```

可以看到主要是运行了 5 个 api:

1. `vl_api_pppoe_add_del_session_t` 建立 PPPoE 隧道,可以看到它传递的 ip 确实是 `client_ip: 0.0.0.0`,实际上并不会用到它
2. `vl_api_sw_interface_dump_t` 查询状态,检查 `sw_if_index: 5` 状态
3. `vl_api_control_ping_t` 同步机制,确保前面的 api 已经处理完
4. `vl_api_feature_enable_disable_t` 激活接口属性,`ip4-not-enabled` 表示开启 ipv4 转发能力
5. `vl_api_ip_route_add_del_t` 注入路由,这一步把真实的 `client ip` 注入到 fib 路由中

#### 踩坑过程

##### client-ip4

一开始查看的 PPPoE 会话信息中的 client-ip4 是 `0.0.0.0`,认为可能 ping 不通是因为没有正确的设置上 client-ip4:

查看 vpp 的 PPPoE 会话信息:

```
$ vppctl show pppoe session
Number of PPPoE sessions: 1
[0] sw-if-index 3 client-ip4 0.0.0.0 client-ip6 0.0.0.0/0 session-id 1 encap-if-index 1 decap-fib-index 0
    local-mac 90:e2:ba:25:43:2c  client-mac 6c:92:bf:3a:8a:4b
```

可以看到客户端 IP 没有被成功同步 (`0.0.0.0`),手动重建一下会话:

```
vyos@vyos:~$ vppctl create pppoe session client-ip 0.0.0.0 session-id 1 client-mac 6c:92:bf:3a:8a:4b del
vyos@vyos:~$ vppctl create pppoe session client-ip 10.200.200.100 session-id 1 client-mac 6c:92:bf:3a:8a:4b
```

可以看到成功的修改了客户端 IP:

```
vyos@vyos:~$ show pppoe-server sessions
 ifname     | username |       ip       | ip6 | ip6-dp |    calling-sid    | rate-limit | state  |  uptime  | rx-bytes | tx-bytes
----------------+----------+----------------+-----+--------+-------------------+------------+--------+----------+----------+----------
 pppoe_session0 | test     | 10.200.200.100 |     |        | 6c:92:bf:3a:8a:4b |            | active | 00:27:56 | 0 B      | 0 B
```

再次尝试 ping 依旧不通,这是因为 client-ip4 对于 VPP 转发没用,VPP 解包请求之后会直接检查 fib 表,检查到请求的目标 IP 之后直接从相应的网卡转发出去 (那返回的时候查的是原目标 ip 的 fib 表吗?)

##### 直接 pingPPPoE 服务端

测试的时候直接从 PPPoE 客户端 pingPPPoE 服务端,服务端监控到的错误如下:

```
vyos@vyos:~$ vppctl show error
   Count                  Node                              Reason               Severity
        17            pppoe-input                 good packets decapsulated        error
        14           ip4-icmp-input                      unknown type              error
         1            pppoe-input                 good packets decapsulated        error
```

这是由于 VPP 本身并没有 ICMP 的响应模块,直接测试通过 VPP 转发到其上联服务器恢复正常
