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
lastmod: 2026-04-07T17:47:36+08:00
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
