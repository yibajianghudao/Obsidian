---
weight: 100  
title: ceph  
slug: ceph  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-24T16:36:17+08:00  
lastmod: 2025-12-23T10:36:51+08:00
---
ceph是一个开源的分布式存储系统,用于构建高性能,高可扩展性,高可靠性的存储集群.常用于云计算,企业数据中心,大规模存储等场景  
## 特点  
ceph的特点:  
- 高性能  
	- 摒弃集中式存储元数据寻址方案,采用`CRUSH`算法,数据分布均衡并行度高  
	- 考虑容灾隔离,能实现各类负载副本放置规则,例如跨机房,机架感知等  
	- 支持上千存储节点的规模,支持TB到PB级数据  
- 高可扩展性  
	- 去中心化,扩展灵活,随节点增加而线性增加  
- 高可用性  
	- 副本数量可以灵活控制  
	- 支持故障分域,数据强一致性  
	- 多种故障场景自动进行修复自愈  
	- 无单点故障,自动管理  
- 接口丰富  
	- 支持块存储,文件存储,对象存储  
	- 支持自定义接口,支持多语言驱动  
## 架构  
### 存储  
#### 统一存储  
- ceph支持: 文件存储 + 块存储 + 对象存储  
- 传统存储支持: 文件存储 + 块存储  
#### 原生对象存储  
ceph将文件转换为4MB的对象集合,对象唯一标识符保存在kv数据库中,提供扁平寻址空间,提供规模扩展和性能提升可行性.  
### 三层架构  
![](assets/ceph/统一存储-20251124172851483.png)  
![](assets/ceph/三层架构-20251206151931213.png)
![](assets/ceph/ceph.svg)
#### RADOS  
ceph的核心是`RADOS`对象存储系统,它把一切数据看作对象,在这一层实现数据的复制,强一致性,不直接对用户提供服务(通过上面提到的多种方式访问).`RADOS`具有自我修复,自我管理的功能.  
`RADOS`由Monitor,MDS,OSD等系统组成.  
##### Monitor  
##### MDS  
##### OSD  
OSD具有多种底层驱动  
- filestore: 需要磁盘具有文件系统,按照文件系统的规则进行读写  
- kvstore  
- memstore  
- bluestore: 操作底层空间,不需要文件系统,速度快,支持WAL预写机制  
#### 访问接口  
ceph提供了多种方式给客户端访问:  
- `LIBRADOS`: 提供访问API,允许应用程序通过多种语言调用接口  
- `RADOSGW`: 提供RESTFUL风格的**对象存储**网关,支持应用程序通过`S3`和`Swift`协议访问,基于`LIBRADOS`  
- `RBD`: 提供**块存储**接口,同样基于`LIBRADOS`  
- `CephFS`: 提供**文件存储**接口,提供**POSIX接口**,支持**FUSE**,使用它必须启动**MDS服务进程**  
#### 硬件平台  
分布式的服务器集群通过**ceph服务**对外提供服务.  
## 核心组件  
### 池(Pool)  
Ceph 存储集群将数据对象存储在名为 **Pool（池）** 的逻辑分区中。  
Ceph 管理员可以创建用于特定类型数据的池，例如块设备、对象网关，或用于隔离不同用户组。  
从 Ceph 客户端的视角来看，池表现为一个具有访问控制的逻辑分区；但实际上，**池在 Ceph 集群的数据分布、存储策略和耐久性机制中扮演着关键角色**。  
#### 池类型(Pool Type):
池类型决定池使用的数据持久性方式，并且对客户端透明。池的数据耐久策略在整个池范围内保持统一，并在池创建后不可修改。  
池支持两种主要的数据持久方式：  
- **副本池(Replica Pools)**：使用多个深度副本，并通过 CRUSH 将其分布到不同硬件上，确保在局部硬件故障时仍能保持数据可用。  
- **纠删码池(Erasure-Coded Pools)**：纠删码池将每个对象分成 K+M 个碎片，其中 K 为数据碎片，M 为编码碎片。K+M 的总数代表存储一个对象所需的 OSD 数量，而 M 表示在最多 M 个 OSD 故障的情况下仍然能够恢复数据。  
### 放置组(Placement Groups, PG)
Ceph 将一个池切分为多个放置组（PG）。PG将对象作为一个组放入OSD。Ceph在内部以PG为粒度管理数据，这比直接管理单个RADOS对象具有更好的扩展性。
- PG 是对象与 OSD 之间的中间映射单元  
- CRUSH 算法根据对象名称计算其所属 PG，并计算该 PG 的 Acting Set（负责存储该 PG 的 OSD 集合）  
- 每个对象先映射到 PG，再由 PG 映射到多个 OSD  
管理员在创建或调整pool时设置 PG 数量（即 pool 被切成多少个 PG）  
### CRUSH
CRUSH(Controlled Replication Under Scalable Hashing 受控复制的可扩展哈希算法)是一种基于哈希的数据分布算法。以数据唯一标识符，当前存储集群的拓扑结构以及数据备份策略作为CRUSH输入，可以随时随地通过计算获取数据所在的底层存储设备位置并直接与其通信，从而避免查表操作，实现去中心化和高度并发。  
CRUSH同时支持多种数据备份策略，如镜像，RAID，纠删码等。并受控地将数据的多个备份映射到集群不同物理区域中的底层存储设备之上，从而保证数据可靠性。  
### OSD

Pool,PG,OSD的数量关系：  
- Pool中PG的数量由ceph管理员设定(pg_num)  
- 每个PG包含的OSD数量有Pool的副本数或纠删码决定  
- 每个OSD承载的PG数量由CRUSH自动均衡((Pool 的 PG 数量 × 副本数) / OSD 总数)

## 部署
### 准备工作
Ceph集群上的主机都需要满足以下要求：
- Python3
- Systemd
- Podman or Docker 来运行容器
- 时间同步(Chrony或者ntpd)
- LVM2 配置存储设备
#### 配置软件源
安装阿里云`epel`和`docker-ce`软件源
```
curl -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
curl -o /etc/yum.repos.d/epel-7.repo  http://mirrors.aliyun.com/repo/epel-7.repo

yum clean all 
yum makecache
```
#### 关闭防火墙和SELinux
```
systemctl disable --now firewalld

vim /etc/selinux/config
SELINUX=disabled

reboot
```
#### 设置服务器名
```
hostnamectl set-hostname ceph1
hostnamectl set-hostname ceph2
hostnamectl set-hostname ceph3
```
#### 安装chrony
安装chrony进行时间同步
```
yum install chrony -y

# 服务端配置
vim /etc/chrony.conf

pool ntp.aliyun.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
allow 192.168.1.0/24
local stratum 10
keyfile /etc/chrony.keys
logdir /var/log/chrony
leapsectz right/UTC

# 客户端配置
vim /etc/chrony.conf

pool 192.168.1.2 iburst # 这里是服务端IP
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
keyfile /etc/chrony.keys
logdir /var/log/chrony
leapsectz right/UTC
```
安装后使用`chronyc sources -v`在客户端进行验证。  
#### 安装python3
安装编译用到的软件和openssl 1.1.1(自带的openssl 1.0太旧，python需要至少openssl 1.1.1)
```
yum groupinstall "Development Tools"
yum install bzip2-devel libffi-devel zlib-devel
#需要EPEL仓库
#安装openssl11，后期的pip3安装网络相关模块需要用到ssl模块。
yum install -y openssl11 openssl11-devel
```
进入刚解压缩的目录
```
cd /root/Python-3.11.0
```
在编译之前需要确保python的`configure`脚本能够找到正确的ssl头文件和lib文件位置  
在Centos上安装`openssl`和`openssl11-devel`软件包之后，相关文件位于：  
```
$ whereis openssl11
openssl11: /usr/bin/openssl11 /usr/lib64/openssl11 /usr/include/openssl11 /usr/share/man/man1/openssl11.1.gz

#此目录下存在ssl.h头文件
$ ls /usr/include/openssl11/
openssl

# 此目录下存在lib文件
$ ls /usr/lib64/openssl11/
libcrypto.so  libssl.so
# 实际上该目录中的文件是指向/usr/lib64目录下头文件的软链接
$ ll /usr/lib64/openssl11/
total 0
lrwxrwxrwx. 1 root root 22 Dec 15 14:05 libcrypto.so -> ../libcrypto.so.1.1.1k
lrwxrwxrwx. 1 root root 19 Dec 15 14:05 libssl.so -> ../libssl.so.1.1.1k
```
查看`configure`脚本可以看到，这两个目录的位置是无法被脚本找到的：
```
            if test x"$PKG_CONFIG" != x""; then
                OPENSSL_LDFLAGS=`$PKG_CONFIG openssl --libs-only-L 2>/dev/null`
                if test $? = 0; then
                    OPENSSL_LIBS=`$PKG_CONFIG openssl --libs-only-l 2>/dev/null`
                    OPENSSL_INCLUDES=`$PKG_CONFIG openssl --cflags-only-I 2>/dev/null`
                    found=true
                fi
            fi

            # no such luck; use some default ssldirs
            if ! $found; then
                ssldirs="/usr/local/ssl /usr/lib/ssl /usr/ssl /usr/pkg /usr/local /usr"
            fi


fi
    # note that we #include <openssl/foo.h>, so the OpenSSL headers have to be in
    # an 'openssl' subdirectory

    if ! $found; then
        OPENSSL_INCLUDES=
        for ssldir in $ssldirs; do
            { $as_echo "$as_me:${as_lineno-$LINENO}: checking for openssl/ssl.h in $ssldir" >&5
$as_echo_n "checking for openssl/ssl.h in $ssldir... " >&6; }
            if test -f "$ssldir/include/openssl/ssl.h"; then
                OPENSSL_INCLUDES="-I$ssldir/include"
                OPENSSL_LDFLAGS="-L$ssldir/lib"
                OPENSSL_LIBS="-lssl -lcrypto"
                found=true
                { $as_echo "$as_me:${as_lineno-$LINENO}: result: yes" >&5
$as_echo "yes" >&6; }
                break
            else
                { $as_echo "$as_me:${as_lineno-$LINENO}: result: no" >&5
$as_echo "no" >&6; }
            fi
        done
```
脚本首先会查看`PKG_CONFIG`环境变量，如果不存在，则在预定义的几个目录中查找，我们的`/usr`目录虽然也在预定义的目录中，但是其查找的是`/usr/include/openssl/ssl.h`，而我们的文件在`/usr/include/openssl11/openssl/ssl.h`。同理，脚本查找的lib文件在`/usr/lib`目录下，而我们的文件在`/usr/lib64`(存在软链接在`/usr/lib64/openssl/`)。  
可以创建软链接来解决：
```
$ ln -s /usr/include/openssl11/openssl/ /usr/include/openssl
$ ln -s /usr/lib64/openssl11/libcrypto.so /usr/lib/libcrypto.so
$ ln -s /usr/lib64/openssl11/libssl.so /usr/lib/libssl.so
```
开始编译:
```
./configure --prefix=/usr/python --with-openssl=/usr
#指定python3的安装目录为/usr/python并编译ssl模块，指定目录好处是后期删除此文件夹就可以完全删除软件了
make -j $(nproc)
```
测试`ssl`是否编译成功：
```
$ ./python -c "import ssl; print(ssl.OPENSSL_VERSION)"
OpenSSL 1.1.1k  FIPS 25 Mar 2021
```
安装：
```
make install
#源码编译并安装
ln -s /usr/python/bin/python3 /usr/bin/python3
ln -s /usr/python/bin/pip3 /usr/bin/pip3
```
#### 安装docker
```
yum install -y yum-utils device-mapper-persistent-data lvm2

# 需要docker-ce软件仓库
yum install -y docker-ce-24.0.7-1.el7 docker-ce-cli-24.0.7-1.el7 containerd.io
```
配置Docker的"live restore"，即允许在不重新启动所有正在运行的容器的情况下重新启动 Docker 引擎  
```
vim /etc/docker/daemon.json
{
  "live-restore": true
}

systemctl restart docker
```
### 安装 CEPHADM
以下内容在 主服务器(ceph1) 上操作：  
安装 CEPHADM，注意从[releases页面](https://docs.ceph.com/en/latest/releases/#active-releases)查看想要安装版本的最新版本，例如我想要安装的是Octopus版本，那么版本号就是15.2.17:  
```
CEPH_RELEASE=15.2.17

curl --silent --remote-name --location https://download.ceph.com/rpm-18.2.0/el9/noarch/cephadm
```
然而上面的链接似乎已经失效了，下载下来的是一个404错误消息，可以手动访问ceph仓库，切换到该版本的分支并前往`ceph/src/cephadm/cephadm`查看文件内容，将链接中的`blob`换成`raw`即可通过网络下载：
```
curl --silent --remote-name --location https://github.com/ceph/ceph/raw/octopus/src/cephadm/cephadm
```
下载之后可以发现`cephadm`实际上是一个python脚本。  
```
# 给予运行权限
chmod +x cephadm

# 添加一个yum存储库，这里需要指定的是版本名称，而不是版本号
./cephadm add-repo --release octopus

# 安装cephadm命令的软件包
./cephadm install 

# 确认命令是否成功安装
$ which cephadm
/usr/sbin/cephadm
```
### 创建集群
首先需要确保：
1. 主机名不能太长，例如`localhost.localdomain`就太长
2. 主机上存在主机名的DNS解析
3. SSH端口是默认的`22`，否则需要手动传入SSH配置文件
4. 需要一个集群内部其他机器可访问的IP地址

```
# 修改主机名
hostnamectl set-hostname ceph1

# 添加主机名的DNS解析
vim /etc/hosts

127.0.0.1   localhost ceph1
::1         localhost ceph1
192.168.1.2 localhost ceph1

# 创建一个SSH的配置文件
vim ssh_config

Host *
  Port 5678
  User root
  StrictHostKeyChecking no
```
然后通过`cephadm`命令创建一个集群：  
```
# 这里使用和其他Ceph机器同处的局域网IP即可
cephadm bootstrap --mon-ip 192.168.1.2 --ssh-config ./ssh_config
```
然后需要安装`ceph`命令，[官方文档](https://docs.ceph.com/en/latest/cephadm/install/#enable-ceph-cli)有几种方法：
- `cephadm shell`
- `cephadm shell -- ceph -s`
- `cephadm install ceph-common`

我这里选择第三种
```
# 官方源下载太慢，这里换成清华源
sed -i 's_download.ceph.com_mirrors.tuna.tsinghua.edu.cn/ceph_g' /etc/yum.repos.d/ceph.repo 

# 安装ceph-common软件包
cephadm install ceph-common
```
然后就可以使用`ceph`命令
```
# 查看集群状态
ceph status
  cluster:
    id:     59f56c2c-dafa-11f0-a750-68a8297ec412
    health: HEALTH_WARN    # 这里有一个warn很正常，是由于还没有添加OSD
            OSD count 0 < osd_pool_default_size 3
 
  services:
    mon: 1 daemons, quorum ceph1 (age 3h)
    mgr: ceph1.zxojlm(active, since 3h)
    osd: 0 osds: 0 up, 0 in
 
  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:     
```
### 添加主机
首先需要把集群的公共SSH密钥添加到新主机root用户的`authorized_keys`文件：
```
ssh-copy-id -f -i /etc/ceph/ceph.pub root@192.168.1.3
ssh-copy-id -f -i /etc/ceph/ceph.pub root@192.168.1.4
```
然后告诉Ceph新节点是集群的一部分：
```
# 命令是: ceph orch host add *<newhost>* [*<ip>*] [*<label1> ...*]，其中 newhost 必须是主机的hostname
ceph orch host add ceph2 192.168.1.3 --labels _admin

# 也可以先添加主机，后添加标签
ceph orch host add ceph3 192.168.1.4 
ceph orch host label add ceph3 _admin
```
> 默认情况下，`ceph.conf`和`ceph.client.admin.keyring`密钥环只在具有`_admin`标签的主机上存在，最好为多个主机提供`_admin`标签(创建集群的主机默认具有该权限)，以便 Ceph Cli 能够在多个主机上访问，否则一旦该主机故障，其他主机需要先复制下来这些文件才能访问 Ceph Cli。

查看当前集群的状态：
```
ceph orch host ls
HOST   ADDR         LABELS  STATUS  
ceph1  ceph1                        
ceph2  192.168.1.3  _admin          
ceph3  192.168.1.4  _admin          
```
状态没有显示，可能是已经`online`了，可以查看运行的容器，观察有没有运行在新的主机上：
```
ceph orch ps
ceph orch ps
NAME                 HOST   STATUS         REFRESHED  AGE  VERSION  IMAGE NAME                                IMAGE ID      CONTAINER ID  
alertmanager.ceph1   ceph1  running (39m)  2m ago     4h   0.20.0   quay.io/prometheus/alertmanager:v0.20.0   0881eb8f169f  84a620ebf962  
crash.ceph1          ceph1  running (4h)   2m ago     4h   15.2.17  quay.io/ceph/ceph:v15                     93146564743f  8a574d091104  
crash.ceph2          ceph2  running (39m)  2m ago     39m  15.2.17  quay.io/ceph/ceph:v15                     93146564743f  ab182ee00a2f  
crash.ceph3          ceph3  running (3m)   2m ago     3m   15.2.17  quay.io/ceph/ceph:v15                     93146564743f  f6e9ab35a36e  
```
默认集群中只有一个`Mon`，如果集群里的所有主机都在同一个子网，`cephadm`会自动管理Mon的数量，通常建议值是三到五个Mon，他们会自动分散到不同的主机上，可以手动干预指定Mon放置的主机：
```
ceph orch apply mon --placement="ceph1,ceph2,ceph3"
```
### 添加OSD
Ceph上使用的磁盘必须满足以下条件：
1. 没有分区
2. 不具有任何LVM状态
3. 没有被挂载
4. 不包含文件系统
5. 不包含Ceph BlueStore OSD
6. 空间大于5GB

列出所有节点上可用的磁盘：
```
ceph orch device ls
```
如果有存在的数据(lvm,文件系统,磁盘分区等)导致不可用，可以先手动擦除存在的数据：
```
$ ceph orch device zap ceph1 /dev/sdb --force
```
可以手动指定设备：
```
ceph orch daemon add osd ceph1:/dev/sdb
```
也可以直接消耗所有可用的设备：
```
ceph orch apply osd --all-available-devices
```
## 使用
### OSD
创建OSD之前可以先手动擦除可能存在的数据：
```
$ ceph orch device zap ceph1 /dev/sdb --force
```
列出所有节点上可用的磁盘：
```
ceph orch device ls
```
查看所有OSD：
```
$ ceph osd tree
ID  CLASS  WEIGHT    TYPE NAME       STATUS  REWEIGHT  PRI-AFF
-1         51.87561  root default                             
-3         51.87561      host ceph1                           
 9    hdd   5.45799          osd.9       up   1.00000  1.00000
10    hdd   5.45799          osd.10      up   1.00000  1.00000
11    hdd   5.45799          osd.11      up   1.00000  1.00000
12    hdd   5.45799          osd.12      up   1.00000  1.00000
13    hdd   5.45799          osd.13      up   1.00000  1.00000
14    hdd   5.45799          osd.14      up   1.00000  1.00000
15    hdd   5.45799          osd.15      up   1.00000  1.00000
16    hdd   5.45799          osd.16      up   1.00000  1.00000
17    hdd   5.45799          osd.17      up   1.00000  1.00000
 6    ssd   0.91789          osd.6       up   1.00000  1.00000
 7    ssd   0.91789          osd.7       up   1.00000  1.00000
 8    ssd   0.91789          osd.8       up   1.00000  1.00000
```
`ceph -s`也会显示当前集群OSD的数量：
```
$ ceph -s
  cluster:
    id:     501cba44-dd42-11f0-bf96-68a8282ec412
    health: HEALTH_OK
 
  services:
    mon: 1 daemons, quorum ceph1 (age 66m)
    mgr: ceph1.pkpqfn(active, since 65m)
    osd: 12 osds: 12 up (since 5m), 12 in (since 5m); 1 remapped pgs
 
  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   12 GiB used, 52 TiB / 52 TiB avail
    pgs:     1 active+clean
 
```
查看运行的osd容器：
```
ceph orch ps --daemon-type osd
NAME    HOST   STATUS        REFRESHED  AGE  VERSION  IMAGE NAME             IMAGE ID      CONTAINER ID  
osd.10  ceph1  running (6m)  3m ago     6m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  b6e4afa6f4e4  
osd.11  ceph1  running (6m)  3m ago     6m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  06b2e4cea3a6  
osd.12  ceph1  running (6m)  3m ago     6m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  bab97c139e2b  
osd.13  ceph1  running (5m)  3m ago     5m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  f82ac7e58180  
osd.14  ceph1  running (4m)  3m ago     4m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  3fb8acbdff4c  
osd.15  ceph1  running (4m)  3m ago     4m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  eab4786260d8  
osd.16  ceph1  running (4m)  3m ago     4m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  90cd940be157  
osd.17  ceph1  running (3m)  3m ago     3m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  71c0655d10a7  
osd.6   ceph1  running (8m)  3m ago     8m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  e16cb2aaa6d9  
osd.7   ceph1  running (7m)  3m ago     7m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  e1c3e86f0ae4  
osd.8   ceph1  running (7m)  3m ago     7m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  742b27b751c3  
osd.9   ceph1  running (7m)  3m ago     7m   15.2.17  quay.io/ceph/ceph:v15  93146564743f  b2b79aff8869  
```
查看磁盘上运行着哪个OSD:
```
# 进入集群环境
[root@ceph1 ~]# cephadm shell
Inferring fsid e34c50e0-dedc-11f0-9b15-68a8282ec412
Inferring config /var/lib/ceph/e34c50e0-dedc-11f0-9b15-68a8282ec412/mon.ceph1/config
Using recent ceph image quay.io/ceph/ceph@sha256:c08064dde4bba4e72a1f55d90ca32df9ef5aafab82efe2e0a0722444a5aaacca


[ceph: root@ceph1 /]# ceph-volume lvm list
====== osd.0 =======
  [block]       /dev/ceph-aea67dae-52d6-4881-b3d0-2313ff9d2c01/osd-block-bdbce2f6-508b-409a-a9ff-843c5147573a

      block device              /dev/ceph-aea67dae-52d6-4881-b3d0-2313ff9d2c01/osd-block-bdbce2f6-508b-409a-a9ff-843c5147573a
      block uuid                UGscNo-Absm-iSDU-vkuO-yMj7-8MDr-DjI7gK
      cephx lockbox secret      
      cluster fsid              e34c50e0-dedc-11f0-9b15-68a8282ec412
      cluster name              ceph
      crush device class        
      encrypted                 0
      osd fsid                  bdbce2f6-508b-409a-a9ff-843c5147573a
      osd id                    0
      osdspec affinity          all-available-devices
      type                      block
      vdo                       0
      devices                   /dev/sdb
      
[ceph: root@ceph1 /]# ceph-volume inventory --format json-pretty
[
    {
        "available": false,
        "device_id": "HP_LOGICAL_VOLUME_PDNNF0ARH8R0F7",
        "lsm_data": {},
        "lvs": [
            {
                "comment": "not used by ceph",
                "name": "swap"
            },
            {
                "comment": "not used by ceph",
                "name": "home"
            },
            {
                "comment": "not used by ceph",
                "name": "root"
            }
        ],
        "path": "/dev/sda",
        "rejected_reasons": [
            "Has partitions",
            "locked",
            "LVM detected",
            "Insufficient space (<10 extents) on vgs"
        ],
        "sys_api": {
            "human_readable_size": "745.18 GB",
            "locked": 1,
            "model": "LOGICAL VOLUME",
            "nr_requests": "128",
            "partitions": {
                "sda1": {
                    "holders": [],
                    "human_readable_size": "1.00 GB",
                    "sectors": "2097152",
                    "sectorsize": 512,
                    "size": 1073741824.0,
                    "start": "2048"
                },
                "sda2": {
                    "holders": [
                        "dm-0",
                        "dm-1",
                        "dm-3"
                    ],
                    "human_readable_size": "744.18 GB",
                    "sectors": "1560657920",
                    "sectorsize": 512,
                    "size": 799056855040.0,
                    "start": "2099200"
                }
            },
            "path": "/dev/sda",
            "removable": "0",
            "rev": "2.52",
            "ro": "0",
            "rotational": "0",
            "sas_address": "",
            "sas_device_handle": "",
            "scheduler_mode": "deadline",
            "sectors": 0,
            "sectorsize": "512",
            "size": 800132521984.0,
            "support_discard": "0",
            "vendor": "HP"
        }
    },
```
### 删除集群
```
$ ceph -s
  cluster:
    id:     501cba44-dd42-11f0-bf96-68a8282ec412
    health: HEALTH_WARN
            Reduced data availability: 1 pg inactive, 1 pg stale
            Degraded data redundancy: 1 pg undersized
 
  services:
    mon: 1 daemons, quorum ceph1 (age 2d)
    mgr: ceph1.pkpqfn(active, since 2d)
    osd: 12 osds: 12 up (since 47h), 12 in (since 47h)
 
  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   12 GiB used, 52 TiB / 52 TiB avail
    pgs:     100.000% pgs not active
             1 stale+undersized+remapped+peered
$ cephadm rm-cluster --force  --fsid 501cba44-dd42-11f0-bf96-68a8282ec412
```
### 主机
查看集群中主机信息：
```
$ ceph orch host ls
HOST   ADDR         LABELS  STATUS  
ceph1  ceph1                        
ceph2  192.168.1.3  _admin          
ceph3  192.168.1.4  _admin          
```
### 结构
ceph的daemon由systemd管理，通过docker启动在容器中运行，在添加到集群的主机中的`/var/lib/ceph`目录下存储集群使用daemon的内容：
```
/var/lib/ceph/
├── 59f56c2c-dafa-11f0-a750-68a8282ec412
│   ├── mon.ceph2
│   │   ├── config
│   │   ├── keyring
│   │   ├── kv_backend
│   │   ├── store.db
│   │   │   ├── 021416.sst
│   │   │   ├── 021417.sst
│   │   │   ├── 021418.sst
│   │   │   ├── 021419.log
│   │   │   ├── 021420.sst
│   │   │   ├── CURRENT
│   │   │   ├── IDENTITY
│   │   │   ├── LOCK
│   │   │   ├── MANIFEST-002608
│   │   │   ├── OPTIONS-002608
│   │   │   └── OPTIONS-002611
│   │   ├── unit.configured
│   │   ├── unit.created
│   │   ├── unit.image
│   │   ├── unit.poststop
│   │   └── unit.run
└── e34c50e0-dedc-11f0-9b15-68a8282ec412
    ├── mon.ceph2
    │   ├── config
    │   ├── keyring
    │   ├── kv_backend
    │   ├── store.db
    │   │   ├── 000004.sst
    │   │   ├── 000018.log
    │   │   ├── CURRENT
    │   │   ├── IDENTITY
    │   │   ├── LOCK
    │   │   ├── MANIFEST-000017
    │   │   ├── OPTIONS-000017
    │   │   └── OPTIONS-000020
    │   ├── unit.configured
    │   ├── unit.created
    │   ├── unit.image
    │   ├── unit.poststop
    │   └── unit.run
```
在目录中存在集群fsid的文件夹，内部是每个daemon的文件，比如`unit.run`中存储的是daemon的启动命令，这些文件在daemon启动使用的systemd service文件中被使用，例如:
```
cat /etc/systemd/system/ceph-59f56c2c-dafa-11f0-a750-68a8282ec412@.service

# generated by cephadm
[Unit]
Description=Ceph %i for 59f56c2c-dafa-11f0-a750-68a8282ec412

# According to:
#   http://www.freedesktop.org/wiki/Software/systemd/NetworkTarget
# these can be removed once ceph-mon will dynamically change network
# configuration.
After=network-online.target local-fs.target time-sync.target docker.service
Wants=network-online.target local-fs.target time-sync.target
Requires=docker.service


PartOf=ceph-59f56c2c-dafa-11f0-a750-68a8282ec412.target
Before=ceph-59f56c2c-dafa-11f0-a750-68a8282ec412.target

[Service]
LimitNOFILE=1048576
LimitNPROC=1048576
EnvironmentFile=-/etc/environment
ExecStart=/bin/bash /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/%i/unit.run
ExecStop=-/bin/docker stop ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-%i
ExecStopPost=-/bin/bash /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/%i/unit.poststop
KillMode=none
Restart=on-failure
RestartSec=10s
TimeoutStartSec=120
TimeoutStopSec=120
StartLimitInterval=30min
StartLimitBurst=5

[Install]
WantedBy=ceph-59f56c2c-dafa-11f0-a750-68a8282ec412.target

```
其中使用了`/var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/%i/unit.run`作为daemon容器的启动脚本:
```
cat /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/mon.ceph2/unit.run 
set -e
/bin/install -d -m0770 -o 167 -g 167 /var/run/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412
# mon.ceph2
! /bin/docker rm -f ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mon.ceph2 2> /dev/null
/bin/docker run --rm --ipc=host --net=host --entrypoint /usr/bin/ceph-mon --privileged --group-add=disk --name ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mon.ceph2 -e CONTAINER_IMAGE=quay.io/ceph/ceph:v15 -e NODE_NAME=ceph2 -v /var/run/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412:/var/run/ceph:z -v /var/log/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412:/var/log/ceph:z -v /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/crash:/var/lib/ceph/crash:z -v /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/mon.ceph2:/var/lib/ceph/mon/ceph-ceph2:z -v /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/mon.ceph2/config:/etc/ceph/ceph.conf:z -v /dev:/dev -v /run/udev:/run/udev quay.io/ceph/ceph:v15 -n mon.ceph2 -f --setuser ceph --setgroup ceph --default-log-to-file=false --default-log-to-stderr=true '--default-log-stderr-prefix=debug ' --default-mon-cluster-log-to-file=false --default-mon-cluster-log-to-stderr=true
```
> systemd service中的`%i`参数指
## 排错
### mon daemon错误
在执行`ceph -s`观察到demon有三个错误:
```
$ ceph -s
  cluster:
    id:     e34c50e0-dedc-11f0-9b15-68a8282ec412
    health: HEALTH_WARN
            3 failed cephadm daemon(s)
 
  services:
    mon: 1 daemons, quorum ceph1 (age 61m)
    mgr: ceph1.djiyps(active, since 61m), standbys: ceph3.didzkk  # 注意这里ceph2没有mgr
    osd: 39 osds: 36 up (since 23s), 36 in (since 23s)
 
  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   36 GiB used, 156 TiB / 156 TiB avail
    pgs:     1 active+clean
```
通过`ceph health detail`查看，发现两个mon，一个osd.19挂掉了：
```
ceph health detail
HEALTH_WARN 3 failed cephadm daemon(s)
[WRN] CEPHADM_FAILED_DAEMON: 3 failed cephadm daemon(s)
    daemon mon.ceph2 on ceph2 is in error state
    daemon osd.19 on ceph2 is in error state
    daemon mon.ceph3 on ceph3 is in error state
```
查看一下集群容器状态：
```
$ ceph orch ps

NAME                 HOST   STATUS         REFRESHED  AGE  VERSION    IMAGE NAME                                IMAGE ID      CONTAINER ID  
alertmanager.ceph1   ceph1  running (15m)  6m ago     66m  0.20.0     quay.io/prometheus/alertmanager:v0.20.0   0881eb8f169f  e4cc03120e6f  
crash.ceph1          ceph1  running (66m)  6m ago     66m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  2428e08d018a  
crash.ceph2          ceph2  running (16m)  6m ago     16m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  3d516e3cdbb6  
crash.ceph3          ceph3  running (15m)  6m ago     15m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  664b7cca137c  
grafana.ceph1        ceph1  running (66m)  6m ago     66m  6.7.4      quay.io/ceph/ceph-grafana:6.7.4           557c83e11646  65d8c05b439d  
mgr.ceph1.djiyps     ceph1  running (67m)  6m ago     67m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  bb6ad5c67fe6  
mgr.ceph3.didzkk     ceph3  running (15m)  6m ago     15m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  d85729e7391a  
mon.ceph1            ceph1  running (67m)  6m ago     68m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  4b15eaef36a1  
mon.ceph2            ceph2  error          6m ago     15m  <unknown>  quay.io/ceph/ceph:v15                     <unknown>     <unknown>     
mon.ceph3            ceph3  error          6m ago     15m  <unknown>  quay.io/ceph/ceph:v15                     <unknown>     <unknown>     
node-exporter.ceph1  ceph1  running (66m)  6m ago     66m  0.18.1     quay.io/prometheus/node-exporter:v0.18.1  e5a616e4b9cf  4588a749a1ae  
osd.0                ceph1  running (30m)  6m ago     30m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  488ba56f54f9  
osd.1                ceph1  running (30m)  6m ago     30m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  374f1b5f1bf4  
osd.10               ceph1  running (30m)  6m ago     30m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  665c92b67f95  
osd.11               ceph1  running (30m)  6m ago     30m  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  03f0ab2d97e9  
osd.12               ceph2  running (9m)   6m ago     9m   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  acc1a989f157  
osd.13               ceph2  running (9m)   6m ago     9m   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  2a0c7e464202  
osd.15               ceph2  running (9m)   6m ago     9m   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  9c0554ec7871  
osd.16               ceph2  running (9m)   6m ago     9m   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  4ccf7313c3ff  
osd.17               ceph2  running (9m)   6m ago     9m   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  991e3d1b14af  
osd.19               ceph2  error          6m ago     9m   <unknown>  quay.io/ceph/ceph:v15                     <unknown>     <unknown>     
```
查看一下mon的容器状态：
```
ceph orch ps --daemon-type mon --format yaml
daemon_type: mon
daemon_id: ceph1
hostname: ceph1
container_id: 4b15eaef36a1
container_image_id: 93146564743febec815d6a764dad93fc07ce971e88315403ac508cb5da6d35f4
container_image_name: quay.io/ceph/ceph:v15
version: 15.2.17
status: 1
status_desc: running
is_active: false
last_refresh: '2025-12-22T06:16:50.826494Z'
created: '2025-12-22T02:21:19.637580Z'
started: '2025-12-22T02:21:22.141901Z'
events:
- 2025-12-22T02:22:38.357550Z daemon:mon.ceph1 [INFO] "Reconfigured mon.ceph1 on host
  'ceph1'"
---
daemon_type: mon
daemon_id: ceph2
hostname: ceph2
container_image_name: quay.io/ceph/ceph:v15
status: -1
status_desc: error
is_active: false
last_refresh: '2025-12-22T06:16:50.067226Z'
created: '2025-12-22T03:13:30.828172Z'
events:
- 2025-12-22T03:13:30.881061Z daemon:mon.ceph2 [INFO] "Deployed mon.ceph2 on host
  'ceph2'"
---
daemon_type: mon
daemon_id: ceph3
hostname: ceph3
container_image_name: quay.io/ceph/ceph:v15
status: -1
status_desc: error
is_active: false
last_refresh: '2025-12-22T06:16:49.038519Z'
created: '2025-12-22T03:13:29.222681Z'
events:
- 2025-12-22T03:13:29.254455Z daemon:mon.ceph3 [INFO] "Deployed mon.ceph3 on host
  'ceph3'"
```
> 这里的 mon-ceph1 的`inactive`是`false`是正常的，这个只有在存在多个mon时，选举出来的主MON会显示`active`。  

尝试查看一下`mon.ceph2`的日志：
```
cephadm logs --name mon.ceph2 --fsid e34c50e0-dedc-11f0-9b15-68a8282ec412
ERROR: Daemon not found: mon.ceph2. See `cephadm ls`
```
结果提示该daemon不存在，`ceph orch ps`能够看到它的状态是`error`，但一些信息是`unknow`，查看`cephadm ls`发现集群中确实不存在这三个daemon。  
此时可以先ssh到目标主机，然后查看`journal`日志(`systemd`的日志)，`ceph orch ps`默认显示daemon所在的主机：
```
ceph orch ps

NAME                 HOST   STATUS        REFRESHED  AGE  VERSION    IMAGE NAME                                IMAGE ID      CONTAINER ID  
osd.19               ceph2  error         8m ago     3h   <unknown>  quay.io/ceph/ceph:v15                     <unknown>     <unknown>  
```
service的命名规则是`ceph-集群id@daemon名`
```
journalctl -u ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service

Dec 22 11:14:53 ceph2 bash[475]: Uptime(secs): 0.0 total, 0.0 interval
Dec 22 11:14:53 ceph2 bash[475]: Flush(GB): cumulative 0.000, interval 0.000
Dec 22 11:14:53 ceph2 bash[475]: AddFile(GB): cumulative 0.000, interval 0.000
Dec 22 11:14:53 ceph2 bash[475]: AddFile(Total Files): cumulative 0, interval 0
Dec 22 11:14:53 ceph2 bash[475]: AddFile(L0 Files): cumulative 0, interval 0
Dec 22 11:14:53 ceph2 bash[475]: AddFile(Keys): cumulative 0, interval 0
Dec 22 11:14:53 ceph2 bash[475]: Cumulative compaction: 0.00 GB write, 0.00 MB/s write, 0.00 GB read, 0.00 MB/s read, 0.0 seconds
Dec 22 11:14:53 ceph2 bash[475]: Interval compaction: 0.00 GB write, 0.00 MB/s write, 0.00 GB read, 0.00 MB/s read, 0.0 seconds
Dec 22 11:14:53 ceph2 bash[475]: Stalls(count): 0 level0_slowdown, 0 level0_slowdown_with_compaction, 0 level0_numfiles, 0 level0_numfiles_with_compaction, 0 stop for pend
Dec 22 11:14:53 ceph2 bash[475]: ** File Read Latency Histogram By Level [default] **
Dec 22 11:14:53 ceph2 bash[475]: debug 2025-12-22T03:14:53.121+0000 7fb09d29c6c0  0 mon.ceph2 does not exist in monmap, will attempt to join an existing cluster
Dec 22 11:14:53 ceph2 bash[475]: debug 2025-12-22T03:14:53.122+0000 7fb09d29c6c0  0 using public_addr v2:192.168.1.3:0/0 -> [v2:192.168.1.3:3300/0,v1:192.168.1.3:6789/0]
Dec 22 11:14:53 ceph2 bash[475]: debug 2025-12-22T03:14:53.123+0000 7fb09d29c6c0  0 starting mon.ceph2 rank -1 at public addrs [v2:192.168.1.3:3300/0,v1:192.168.1.3:6789/0
Dec 22 11:14:53 ceph2 bash[475]: debug 2025-12-22T03:14:53.126+0000 7fb09d29c6c0  1 mon.ceph2@-1(???) e0 preinit fsid e34c50e0-dedc-11f0-9b15-68a8282ec412
Dec 22 11:14:53 ceph2 bash[475]: debug 2025-12-22T03:14:53.128+0000 7fb09d29c6c0 -1  Processor -- bind unable to bind to v2:192.168.1.3:3300/0: (98) Address already in use
Dec 22 11:14:53 ceph2 bash[475]: debug 2025-12-22T03:14:53.128+0000 7fb09d29c6c0 -1  Processor -- bind was unable to bind. Trying again in 5 seconds
Dec 22 11:14:58 ceph2 bash[475]: debug 2025-12-22T03:14:58.129+0000 7fb09d29c6c0 -1  Processor -- bind unable to bind to v2:192.168.1.3:3300/0: (98) Address already in use
Dec 22 11:14:58 ceph2 bash[475]: debug 2025-12-22T03:14:58.129+0000 7fb09d29c6c0 -1  Processor -- bind was unable to bind. Trying again in 5 seconds
Dec 22 11:15:03 ceph2 bash[475]: debug 2025-12-22T03:15:03.129+0000 7fb09d29c6c0 -1  Processor -- bind unable to bind to v2:192.168.1.3:3300/0: (98) Address already in use
Dec 22 11:15:03 ceph2 bash[475]: debug 2025-12-22T03:15:03.129+0000 7fb09d29c6c0 -1  Processor -- bind was unable to bind after 3 attempts: (98) Address already in use
Dec 22 11:15:03 ceph2 bash[475]: debug 2025-12-22T03:15:03.129+0000 7fb09d29c6c0 -1 unable to bind monitor to [v2:192.168.1.3:3300/0,v1:192.168.1.3:6789/0]
Dec 22 11:15:03 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service: main process exited, code=exited, status=1/FAILURE
Dec 22 11:15:03 ceph2 systemd[1]: Unit ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service entered failed state.
Dec 22 11:15:03 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service failed.
Dec 22 11:15:13 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service holdoff time over, scheduling restart.
Dec 22 11:15:13 ceph2 systemd[1]: Stopped Ceph mon.ceph2 for e34c50e0-dedc-11f0-9b15-68a8282ec412.
Dec 22 11:15:13 ceph2 systemd[1]: start request repeated too quickly for ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service
Dec 22 11:15:13 ceph2 systemd[1]: Failed to start Ceph mon.ceph2 for e34c50e0-dedc-11f0-9b15-68a8282ec412.
Dec 22 11:15:13 ceph2 systemd[1]: Unit ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service entered failed state.
Dec 22 11:15:13 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service failed.
```
通过查看日志发现：`mon.ceph2 does not exist in monmap, will attempt to join an existing cluster`，`unable to bind monitor to [v2:192.168.1.3:3300/0,v1:192.168.1.3:6789/0]`。指`mon.ceph2`发现自己没有在`monmap`中，于是尝试以新成员身份加入集群，但是在进程试图绑定`3300`端口的时候发现端口已经被使用，我们查看一下这台机器的端口使用情况:
```
ss -tnulp | grep  -E ':3300|:6789'
tcp    LISTEN     0      128    192.168.1.3:3300                  *:*                   users:(("ceph-mon",pid=2486,fd=30))
tcp    LISTEN     0      128    192.168.1.3:6789                  *:*                   users:(("ceph-mon",pid=2486,fd=31))
```
发现确实被旧的mon进程占用，然后我尝试查看该机器的docker容器状态，发现这个mon处于up状态：
```
docker ps -a
CONTAINER ID   IMAGE                                      COMMAND                  CREATED       STATUS       PORTS     NAMES
6645d7384a98   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.26
8ec665545a5d   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.25
a0b38a765e41   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.24
de2de082d710   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.23
f5207aefebee   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.22
87517df22a23   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.21
418529bb4b13   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.20
991e3d1b14af   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.17
4ccf7313c3ff   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.16
9c0554ec7871   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.15
2a0c7e464202   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.13
acc1a989f157   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.12
3d516e3cdbb6   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-crash…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-crash.ceph2
4e94952280db   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-mgr -…"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mgr.ceph2.jqoppg
6015d791566b   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-mon -…"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mon.ceph2
55a8a8523fe6   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-crash…"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-crash.ceph2
75f408b8eb61   quay.io/prometheus/node-exporter:v0.18.1   "/bin/node_exporter …"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-node-exporter.ceph2
```
既然容器状态是正常的，那为什么mon日志存在错误？为什么集群显示mon状态是error？  
仔细看docker容器名，发现原来是ceph-mon容器属于一个旧ceph集群！我在先前删除了一个测试用的ceph集群，在这个节点上的daemon却并没有被删除，因此当我重新建立一个集群并加入主机之后，新创建的daemon端口被旧集群的daemon占用，不仅仅是`mon`,还有`mgr`,`crash`和`node-exporter`再查看一下ceph3上的容器状态：
```
docker ps -a

f219e6d76471   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-crash…"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-crash.ceph3
77e573335397   quay.io/ceph/ceph:v15                      "/usr/bin/ceph-mon -…"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mon.ceph3
e5829016067e   quay.io/prometheus/node-exporter:v0.18.1   "/bin/node_exporter …"   4 days ago    Up 4 days              ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-node-exporter.ceph3
```
ceph3上只有`mon`,`crash`和`node_exporter`存在，`mgr`是正常的，这也和`ceph -s`的结果一致(只有ceph1和ceph3两个`mgr`)  
下面来停止这些daemon，ceph虽然使用容器启动daemon，但是实际上是通过systemd管理的
> 刚才查看日志的时候就是查看的systemd的日志，由于容器内部将日志发送到stdout和stderr，所以可以在systemd的日志系统jounal中查看

systemd service文件在`/etc/systemd/system/`，下面是ceph2-mon的单元文件:
```
cat /etc/systemd/system/ceph-59f56c2c-dafa-11f0-a750-68a8282ec412@.service
# generated by cephadm
[Unit]
Description=Ceph %i for 59f56c2c-dafa-11f0-a750-68a8282ec412

# According to:
#   http://www.freedesktop.org/wiki/Software/systemd/NetworkTarget
# these can be removed once ceph-mon will dynamically change network
# configuration.
After=network-online.target local-fs.target time-sync.target docker.service
Wants=network-online.target local-fs.target time-sync.target
Requires=docker.service


PartOf=ceph-59f56c2c-dafa-11f0-a750-68a8282ec412.target
Before=ceph-59f56c2c-dafa-11f0-a750-68a8282ec412.target

[Service]
LimitNOFILE=1048576
LimitNPROC=1048576
EnvironmentFile=-/etc/environment
ExecStart=/bin/bash /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/%i/unit.run
ExecStop=-/bin/docker stop ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-%i
ExecStopPost=-/bin/bash /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/%i/unit.poststop
KillMode=none
Restart=on-failure
RestartSec=10s
TimeoutStartSec=120
TimeoutStopSec=120
StartLimitInterval=30min
StartLimitBurst=5

[Install]
WantedBy=ceph-59f56c2c-dafa-11f0-a750-68a8282ec412.target

```
它的启动命令是运行的下面的文件：
```
cat /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/mon.ceph2/unit.run 
set -e
/bin/install -d -m0770 -o 167 -g 167 /var/run/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412
# mon.ceph2
! /bin/docker rm -f ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mon.ceph2 2> /dev/null
/bin/docker run --rm --ipc=host --net=host --entrypoint /usr/bin/ceph-mon --privileged --group-add=disk --name ceph-59f56c2c-dafa-11f0-a750-68a8282ec412-mon.ceph2 -e CONTAINER_IMAGE=quay.io/ceph/ceph:v15 -e NODE_NAME=ceph2 -v /var/run/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412:/var/run/ceph:z -v /var/log/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412:/var/log/ceph:z -v /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/crash:/var/lib/ceph/crash:z -v /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/mon.ceph2:/var/lib/ceph/mon/ceph-ceph2:z -v /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/mon.ceph2/config:/etc/ceph/ceph.conf:z -v /dev:/dev -v /run/udev:/run/udev quay.io/ceph/ceph:v15 -n mon.ceph2 -f --setuser ceph --setgroup ceph --default-log-to-file=false --default-log-to-stderr=true '--default-log-stderr-prefix=debug ' --default-mon-cluster-log-to-file=false --default-mon-cluster-log-to-stderr=true
```
可以看到它的启动和停止是使用的docker,`--net=host`表明它使用主机的网络端口。  
停止mon和其他daemon的service：
```
systemctl stop ceph-59f56c2c-dafa-11f0-a750-68a8282ec412@mon.ceph2.service
systemctl stop ceph-59f56c2c-dafa-11f0-a750-68a8282ec412@crash.ceph2
systemctl stop ceph-59f56c2c-dafa-11f0-a750-68a8282ec412@mgr.ceph2.jqoppg
systemctl stop ceph-59f56c2c-dafa-11f0-a750-68a8282ec412@node-exporter.ceph2
```
查看一下docker容器，发现它们都没有了：
```
docker ps -a
CONTAINER ID   IMAGE                   COMMAND                  CREATED       STATUS       PORTS     NAMES
6645d7384a98   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.26
8ec665545a5d   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.25
a0b38a765e41   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.24
de2de082d710   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.23
f5207aefebee   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.22
87517df22a23   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.21
418529bb4b13   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.20
991e3d1b14af   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.17
4ccf7313c3ff   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.16
9c0554ec7871   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.15
2a0c7e464202   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.13
acc1a989f157   quay.io/ceph/ceph:v15   "/usr/bin/ceph-osd -…"   5 hours ago   Up 5 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-osd.12
3d516e3cdbb6   quay.io/ceph/ceph:v15   "/usr/bin/ceph-crash…"   6 hours ago   Up 6 hours             ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412-crash.ceph2
```
然后删除`/var/lib/ceph`目录下这个集群的所有内容：
```
rm -rf /var/lib/ceph/59f56c2c-dafa-11f0-a750-68a8282ec412/
```
然后尝试在`ceph1`直接重新部署mon-ceph2：
```
ceph orch daemon redeploy mon.ceph2
```
等了一会发现还是失败：
```
ceph orch ps
NAME                 HOST   STATUS         REFRESHED  AGE  VERSION    IMAGE NAME                                IMAGE ID      CONTAINER ID  
alertmanager.ceph1   ceph1  running (5h)   46s ago    6h   0.20.0     quay.io/prometheus/alertmanager:v0.20.0   0881eb8f169f  e4cc03120e6f  
crash.ceph1          ceph1  running (6h)   46s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  2428e08d018a  
crash.ceph2          ceph2  running (5h)   47s ago    5h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  3d516e3cdbb6  
crash.ceph3          ceph3  running (5h)   67s ago    5h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  664b7cca137c  
grafana.ceph1        ceph1  running (6h)   46s ago    6h   6.7.4      quay.io/ceph/ceph-grafana:6.7.4           557c83e11646  65d8c05b439d  
mgr.ceph1.djiyps     ceph1  running (6h)   46s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  bb6ad5c67fe6  
mgr.ceph3.didzkk     ceph3  running (5h)   67s ago    5h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  d85729e7391a  
mon.ceph1            ceph1  running (6h)   46s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  4b15eaef36a1  
mon.ceph2            ceph2  unknown        47s ago    5h   <unknown>  quay.io/ceph/ceph:v15                     <unknown>     <unknown>     
mon.ceph3            ceph3  error          67s ago    5h   <unknown>  quay.io/ceph/ceph:v15                     <unknown>     <unknown>     
```
查看容器状态发现容器没有起来，查看日志发现还是有报错:
```
journalctl -u ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service

Dec 22 17:02:59 ceph2 bash[30329]: debug 2025-12-22T09:02:59.868+0000 7f645a7736c0  0 mon.ceph2 does not exist in monmap, will attempt to join an existing cluster
Dec 22 17:02:59 ceph2 bash[30329]: debug 2025-12-22T09:02:59.869+0000 7f645a7736c0 -1 no public_addr or public_network specified, and mon.ceph2 not present in monmap or ce
Dec 22 17:02:59 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service: main process exited, code=exited, status=1/FAILURE
Dec 22 17:02:59 ceph2 systemd[1]: Unit ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service entered failed state.
Dec 22 17:02:59 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service failed.
Dec 22 17:03:10 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service holdoff time over, scheduling restart.
Dec 22 17:03:10 ceph2 systemd[1]: Stopped Ceph mon.ceph2 for e34c50e0-dedc-11f0-9b15-68a8282ec412.
Dec 22 17:03:10 ceph2 systemd[1]: start request repeated too quickly for ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service
Dec 22 17:03:10 ceph2 systemd[1]: Failed to start Ceph mon.ceph2 for e34c50e0-dedc-11f0-9b15-68a8282ec412.
Dec 22 17:03:10 ceph2 systemd[1]: Unit ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service entered failed state.
Dec 22 17:03:10 ceph2 systemd[1]: ceph-e34c50e0-dedc-11f0-9b15-68a8282ec412@mon.ceph2.service failed.
```
错误`no public_addr or public_network specified, and mon.ceph2 not present in monmap or ce`表明Ceph 配置中没有为 mon.ceph2 明确指定 public_addr，我们在`ceph1`上手动指定一下：
```
ceph orch daemon rm mon.ceph2 --force
Removed mon.ceph2 from host 'ceph2'

ceph orch daemon add mon ceph2:192.168.1.3
Deployed mon.ceph2 on host 'ceph2'
```
然后ceph2.mon成功运行：
```
ceph orch ps
NAME                 HOST   STATUS         REFRESHED  AGE  VERSION    IMAGE NAME                                IMAGE ID      CONTAINER ID  
alertmanager.ceph1   ceph1  running (6h)   80s ago    6h   0.20.0     quay.io/prometheus/alertmanager:v0.20.0   0881eb8f169f  e4cc03120e6f  
crash.ceph1          ceph1  running (6h)   80s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  2428e08d018a  
crash.ceph2          ceph2  running (6h)   81s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  3d516e3cdbb6  
crash.ceph3          ceph3  running (6h)   82s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  664b7cca137c  
grafana.ceph1        ceph1  running (6h)   80s ago    6h   6.7.4      quay.io/ceph/ceph-grafana:6.7.4           557c83e11646  65d8c05b439d  
mgr.ceph1.djiyps     ceph1  running (6h)   80s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  bb6ad5c67fe6  
mgr.ceph3.didzkk     ceph3  running (6h)   82s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  d85729e7391a  
mon.ceph1            ceph1  running (6h)   80s ago    6h   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  4b15eaef36a1  
mon.ceph2            ceph2  running (2m)   81s ago    2m   15.2.17    quay.io/ceph/ceph:v15                     93146564743f  3bf208da40a0  
```
同样的步骤：
```
ceph orch daemon rm mon.ceph3 --force
Removed mon.ceph3 from host 'ceph3'

# 这里是因为间隔太长，新的mon.ceph3被自动运行
ceph orch daemon add mon ceph3:192.168.1.4
Error EINVAL: name mon.ceph3 already in use

ceph orch daemon rm mon.ceph3 --force
Removed mon.ceph3 from host 'ceph3'
```
等待一小段时间之后mon.ceph3也恢复正常:
```
ceph orch ps
NAME                 HOST   STATUS         REFRESHED  AGE  VERSION    IMAGE NAME                                IMAGE ID      CONTAINER ID  
mon.ceph1            ceph1  running (23h)  9m ago     23h  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  4b15eaef36a1  
mon.ceph2            ceph2  running (16h)  9m ago     16h  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  3bf208da40a0  
mon.ceph3            ceph3  running (16h)  9m ago     16h  15.2.17    quay.io/ceph/ceph:v15                     93146564743f  5795a64576d1  
```
随后再来查看这个`osd.19`，发现我的OSD数量是正常的(36):
```
ceph -s
  cluster:
    id:     e34c50e0-dedc-11f0-9b15-68a8282ec412
    health: HEALTH_WARN
            1 failed cephadm daemon(s)
            noout,nobackfill,norebalance,norecover flag(s) set
 
  services:
    mon: 3 daemons, quorum ceph1,ceph2,ceph3 (age 16h)
    mgr: ceph1.djiyps(active, since 23h), standbys: ceph3.didzkk
    osd: 39 osds: 36 up (since 22h), 36 in (since 22h)
         flags noout,nobackfill,norebalance,norecover
 
  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   36 GiB used, 156 TiB / 156 TiB avail
    pgs:     1 active+clean
    
    
# 每个节点12个磁盘
ceph osd tree
ID   CLASS  WEIGHT     TYPE NAME       STATUS  REWEIGHT  PRI-AFF
 -1         155.60193  root default                             
 -3          51.87561      host ceph1                           
  3    hdd    5.45799          osd.3       up   1.00000  1.00000
  4    hdd    5.45799          osd.4       up   1.00000  1.00000
  5    hdd    5.45799          osd.5       up   1.00000  1.00000
  6    hdd    5.45799          osd.6       up   1.00000  1.00000
  7    hdd    5.45799          osd.7       up   1.00000  1.00000
  8    hdd    5.45799          osd.8       up   1.00000  1.00000
  9    hdd    5.45799          osd.9       up   1.00000  1.00000
 10    hdd    5.45799          osd.10      up   1.00000  1.00000
 11    hdd    5.45799          osd.11      up   1.00000  1.00000
  0    ssd    0.91789          osd.0       up   1.00000  1.00000
  1    ssd    0.91789          osd.1       up   1.00000  1.00000
  2    ssd    0.91789          osd.2       up   1.00000  1.00000
 -7          51.85071      host ceph2                           
 12    hdd    5.45799          osd.12      up   1.00000  1.00000
 13    hdd    5.45799          osd.13      up   1.00000  1.00000
 15    hdd    5.45799          osd.15      up   1.00000  1.00000
 16    hdd    5.45799          osd.16      up   1.00000  1.00000
 17    hdd    5.45799          osd.17      up   1.00000  1.00000
 23    hdd    5.45799          osd.23      up   1.00000  1.00000
 24    hdd    5.45799          osd.24      up   1.00000  1.00000
 25    hdd    5.45799          osd.25      up   1.00000  1.00000
 26    hdd    5.45799          osd.26      up   1.00000  1.00000
 20    ssd    0.90959          osd.20      up   1.00000  1.00000
 21    ssd    0.90959          osd.21      up   1.00000  1.00000
 22    ssd    0.90959          osd.22      up   1.00000  1.00000
-10          51.87561      host ceph3                           
 30    hdd    5.45799          osd.30      up   1.00000  1.00000
 31    hdd    5.45799          osd.31      up   1.00000  1.00000
 32    hdd    5.45799          osd.32      up   1.00000  1.00000
 33    hdd    5.45799          osd.33      up   1.00000  1.00000
 34    hdd    5.45799          osd.34      up   1.00000  1.00000
 35    hdd    5.45799          osd.35      up   1.00000  1.00000
 36    hdd    5.45799          osd.36      up   1.00000  1.00000
 37    hdd    5.45799          osd.37      up   1.00000  1.00000
 38    hdd    5.45799          osd.38      up   1.00000  1.00000
 27    ssd    0.91789          osd.27      up   1.00000  1.00000
 28    ssd    0.91789          osd.28      up   1.00000  1.00000
 29    ssd    0.91789          osd.29      up   1.00000  1.00000
 14                 0  osd.14            down         0  1.00000
 18                 0  osd.18            down         0  1.00000
 19                 0  osd.19            down         0  1.00000
```
`osd.19`确实是挂掉了，但是在这个磁盘上已经重新启动了另外一个osd。  
确认这个osd.19已经down并且weight是0，所以可以移除这个osd:
```
# 移除daemon
ceph orch daemon rm osd.19 --force

# 标记为 destroy
ceph osd destroy osd.19 --force

# 可以看到状态已经变成了destroyed
ceph osd tree | grep osd.19
 19                 0  osd.19          destroyed         0  1.00000

# 彻底删除，删除后ceph osd tree就没有osd.19了
ceph osd purge osd.19 --yes-i-really-mean-it
```
顺手把另外两个down掉的osd也删除(前提是weright是0，没有数据):
```
[root@ceph1 ~]# ceph osd destroy osd.14 --force
destroyed osd.14
[root@ceph1 ~]# ceph osd destroy osd.18 --force
destroyed osd.18
[root@ceph1 ~]# ceph osd tree | grep -E 'osd.14|osd.18'
 14                 0  osd.14          destroyed         0  1.00000
 18                 0  osd.18          destroyed         0  1.00000
[root@ceph1 ~]# ceph osd purge osd.14 --yes-i-really-mean-it
purged osd.14
[root@ceph1 ~]# ceph osd purge osd.18 --yes-i-really-mean-it
purged osd.18
```
随后状态恢复正常:
```
 ceph -s
  cluster:
    id:     e34c50e0-dedc-11f0-9b15-68a8282ec412
    health: HEALTH_WARN
            noout,nobackfill,norebalance,norecover flag(s) set
 
  services:
    mon: 3 daemons, quorum ceph1,ceph2,ceph3 (age 17h)
    mgr: ceph1.djiyps(active, since 24h), standbys: ceph3.didzkk
    osd: 36 osds: 36 up (since 23h), 36 in (since 23h)
         flags noout,nobackfill,norebalance,norecover
 
  data:
    pools:   1 pools, 1 pgs
    objects: 0 objects, 0 B
    usage:   36 GiB used, 156 TiB / 156 TiB avail
    pgs:     1 active+clean
```
## 参考
- [# Red Hat Ceph Storage 架构指南](https://docs.redhat.com/zh-cn/documentation/red_hat_ceph_storage/8/html/architecture_guide/index)
- [](https://www.wuzao.com/ceph/en/latest/cephadm/install/index.html#cephadm-install-curl)
- [](https://www.cnblogs.com/Pigs-Will-Fly/p/18671388#_label3_0)
- [](https://docs.ceph.com/en/latest/cephadm/)
- [](https://www.yuque.com/xianzhou-eiffx/aklhoc/vz2kwrequbkhoxhv)
