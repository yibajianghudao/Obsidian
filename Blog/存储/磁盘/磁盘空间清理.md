---
weight: 100
title: 磁盘空间清理
slug: 磁盘空间清理
description:
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-11-20T09:13:31+08:00
lastmod: 2025-12-15T10:14:29+08:00
---

首先使用`df -h`或`df -i`查看是磁盘空间不足还是inode使用率过高
## inode使用率过高  
```  
df -h  
root@cww:~# df -h  
Filesystem                         Size  Used Avail Use% Mounted on  
udev                               964M     0  964M   0% /dev  
tmpfs                              200M   24M  177M  12% /run  
/dev/mapper/ubuntu--vg-ubuntu--lv   15G   13G  1.3G  92% /  
tmpfs                              997M     0  997M   0% /dev/shm  
tmpfs                              5.0M     0  5.0M   0% /run/lock  
tmpfs                              997M     0  997M   0% /sys/fs/cgroup  
/dev/sda2                          974M   80M  827M   9% /boot  
tmpfs                              200M     0  200M   0% /run/user/0  
```  
这里看到磁盘空间没有满  
```  
root@cww:~# df -i  
Filesystem                        Inodes  IUsed  IFree IUse% Mounted on  
udev                              246659    425 246234    1% /dev  
tmpfs                             255153    703 254450    1% /run  
/dev/mapper/ubuntu--vg-ubuntu--lv 983040 983040      0  100% /  
tmpfs                             255153      1 255152    1% /dev/shm  
tmpfs                             255153      4 255149    1% /run/lock  
tmpfs                             255153     18 255135    1% /sys/fs/cgroup  
/dev/sda2                          65536    305  65231    1% /boot  
tmpfs                             255153     12 255141    1% /run/user/0  
```  
磁盘的inode使用率满了，这种情况是因为文件数量过多，删除无用的文件即可  
可以使用`find`命令递归查看目录下的文件,使用`wc`统计总个数:  
```  
find /var | wc -l  
```  
使用下面的脚本查看指定目录下每个目录中文件的总个数:  
```  
for i in /*; do echo $i; find $i | wc -l; done;  
```  
部分输出如下:  
```  
root@cww:~# for i in /*; do echo $i; find $i | wc -l; done;  
/lib  
9386  
/proc  
71183  
/var  
879628  
```  
然后排查一下`/var`目录下:  
```  
root@cww:~# for i in /var/*; do echo $i; find $i | wc -l; done;  
/var/spool  
867956  
/var/tmp  
7  
/var/www  
3  
```  
逐级排查后发现是`/var/spool/postfix/maildrop`目录下存在大量文件  
```  
root@cww:~# for i in /var/spool/postfix/*; do echo $i; find $i | wc -l; done;  
/var/spool/postfix/maildrop  
867828  
```  
尝试直接使用`rm`删除发现文件太多，传入的参数超出了rm命令可以接受的范围:  
```  
root@cww:/var/spool/postfix/maildrop# rm -rf ./*  
-bash: /bin/rm: Argument list too long  
```  
1. 可以去掉命令结尾的`*`，只传递目录给`rm`：
	```
	rm -rf ./
	```
2. 我们也可以使用`rsync`快速删除大量文件  
	```
	# 创建一个空目录
	mkdir /tmp/clear/
	# 同步/var/spool/postfix/maildrop/目录下的文件到/tmp/clear,多余的文件会被删除
	rsync -av --delete /tmp/clear/ /var/spool/postfix/maildrop/  
	```

由于`/tmp/clear/`是空文件,因此所有文件会被删除  
> 如果/tmp/clear 文件夹不能创建,可以先使用下面的脚本先删除一些文件:  
> `ls -t ./ | tail -n 1000 | xargs -I {} rm -v /var/spool/postfix/maildrop/{}`  
>   
> 关于`rsync`,`rm`和`perl`删除文件的讨论:  
> [Efficiently delete large directory containing thousands of files](https://unix.stackexchange.com/questions/37329/efficiently-delete-large-directory-containing-thousands-of-files)  

删除完后inode使用率变成了12%:  

```  
root@cww:/var/spool/postfix/maildrop# df -i  
Filesystem                        Inodes  IUsed  IFree IUse% Mounted on  
udev                              246659    425 246234    1% /dev  
tmpfs                             255153    692 254461    1% /run  
/dev/mapper/ubuntu--vg-ubuntu--lv 983040 115221 867819   12% /  
tmpfs                             255153      1 255152    1% /dev/shm  
tmpfs                             255153      4 255149    1% /run/lock  
tmpfs                             255153     18 255135    1% /sys/fs/cgroup  
/dev/sda2                          65536    305  65231    1% /boot  
tmpfs                             255153     12 255141    1% /run/user/0  
```  
> [为什么`/var/spool/postfix/maildrop/`会有这么多文件](https://serverfault.com/questions/680782/why-are-there-so-many-files-in-var-spool-postfix-maildrop)  
> 该文件夹主要是由系统生成的,如果postfix发送邮件失败,会给root发送一个邮件,大多数邮件是由`crontab`生成的,可以在`crontab`中的脚本前加上`MAILTO=""`解决  

## 存储空间不足
存储空间不足，则使用`du`命令查看是哪个目录占用的空间比较多。  
`du`命令常用参数:  
- `-h`，以人类可读的单位显示文件大小
- `-d`，即`--max-depth`，限制目录深度，设置为`0`则仅显示当前目录的总大小，相当于`-s`
- `-x`，只显示当前文件系统上的目录
- `-a`，显示文件
- `-c`，额外显示目录总和
- `-s`，只显示目录总和
### 清理MySQL Binlog日志
```
# df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              197M  1.4M  196M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   14G   13G  878M  94% /
tmpfs                              982M     0  982M   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          1.7G  252M  1.4G  16% /boot
tmpfs                              197M  4.0K  197M   1% /run/user/1000
tmpfs                              197M  4.0K  197M   1% /run/user/0
```
发现磁盘剩余空间比较少，使用`du`命令查看是哪个目录：  
```
# du -h --max-depth1 / | sort -rh
14G     /
6.9G    /var
3.6G    /usr
1.3G    /snap
252M    /boot
7.2M    /etc
1.4M    /run
92K     /tmp
92K     /home
72K     /root
16K     /lost+found
4.0K    /srv
4.0K    /opt
4.0K    /mnt
4.0K    /media
4.0K    /cdrom
0       /sys
0       /proc
0       /dev
```
逐个目录排查：
```
# du -h --max-depth=1 /var/lib/ | sort -rh
5.4G    /var/lib/
4.4G    /var/lib/mysql
553M    /var/lib/snapd
```
发现是由于`/var/lib/mysql/`目录下的binlog日志文件过多导致的：  
```
# du -ah --max-depth=1 /var/lib/mysql | sort -rh
4.4G    /var/lib/mysql
1.1G    /var/lib/mysql/zabbix
101M    /var/lib/mysql/#innodb_redo
101M    /var/lib/mysql/binlog.000052
101M    /var/lib/mysql/binlog.000050
101M    /var/lib/mysql/binlog.000048
101M    /var/lib/mysql/binlog.000046
98M     /var/lib/mysql/binlog.000045
98M     /var/lib/mysql/binlog.000044
98M     /var/lib/mysql/binlog.000043
```
mysql的binlog(二进制日志文件)是一种记录数据库所有更改操作的日志，文件存储了数据修改的原始信息，而不是查询的结果，使得它对数据库的复制，恢复和故障处理等功能至关重要。  
删除之前先通过`scp`备份文件到主机：  
```
# 使用''包裹可以阻止通配符在本地解析
$ scp 'root@42.225.98.24:/var/lib/mysql/binlog.*' ./Downloads
```
然后登录到mysql通过：
```
PURGE BINARY LOGS TO 'binlog.000051';
```
删除小于`binlog.000051`的所有 binlog。  
通过`PURGE BINARY LOGS`清理可以清理掉binlog的索引文件(`binlog.index`)，其中记载着存在的binlog文件，直接通过`rm`删除需要手动清理该文件。  
清理完之后可以先进行一次全量备份：
```
# mysqldump -u root -p --single-transaction --all-databases > full.sql
```
然后修改mysql的配置文件配置binlog自动删除：
```
vim /etc/mysql/mysql.conf.d/mysqld.cnf 
[mysqld]
# 保留7天
binlog_expire_logs_seconds = 604800
# binlog文件大小
max_binlog_size = 100M
```
随后重启mysql服务：
```
# systemctl restart mysql 
```
再次登录mysql查看配置状态：
```
mysql> SHOW VARIABLES LIKE 'binlog_expire_logs_seconds';
+----------------------------+---------+
| Variable_name              | Value   |
+----------------------------+---------+
| binlog_expire_logs_seconds | 2592000 |
+----------------------------+---------+
1 row in set (0.01 sec)
```

### df 与 du 结果不一致
- `df`(disk free)用于显示文件系统的磁盘空间使用情况，它直接读取文件系统元数据（superblock）中的磁盘使用块，查询速度快。
- `du`(disk usage)用于统计文件和目录的磁盘空间使用情况，它通过遍历目录树并读取 inode 中记录的**文件实际占用 block 大小**来计算总量。

> `df`使用`statfs()`系统调用来统计磁盘空间使用情况，`du`使用`stat()`系统调用来统计文件和目录的磁盘空间使用情况。


`df -h`查看文件系统实际占用的磁盘块，`du -xhd0 /`查看根目录所在文件系统中 inode 记录的文件 block 大小总和。
> 注意：`du` 不会统计那些已经被删除但仍被进程持有的文件，因为它们已经不在目录树中。  


通常`du`的输出不会大于`df`的输出，除非`du`没有添加`-x`参数，统计到了其他文件系统上的文件，例如`tmpfs`  

当`df`的输出大于`du`的输出时，常见原因如下：  
#### 文件句柄未释放
在Linux系统中删除文件(rm)只是删除目录项(即文件名)，如果此时仍有进程持有该文件的句柄(fd)，该文件的inode和数据块不会立即释放。  
这种情况典型出现于日志文件，例如正在运行的 Web 服务器（Apache / Nginx）。日志不断写入，管理员删除日志文件后空间并不会释放，因为进程仍持有文件句柄。  
可以通过下面的命令：
```
lsof | grep deleted
```
列出所有已经被删除(deleted)但仍被进程持有的文件。  
##### 原理

##### 实验复现
有一台ubuntu2204服务器，已经安装了nginx服务：
```
root@ubuntu2204:~# du -xhd0 /
4.4G    /
root@ubuntu2204:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs            96M  1.1M   95M   2% /run
/dev/sda2        16G  4.4G   11G  30% /
tmpfs           479M     0  479M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs            96M  4.0K   96M   1% /run/user/1000
```
安装`apache2-utils`软件包以使用`ApacheBench`模拟请求来提高日志文件的体积：
```
# 请求之前的体积：
root@ubuntu2204:~# ls -lh /var/log/nginx/access.log 
-rw-r----- 1 www-data adm 0 Dec 10 06:17 /var/log/nginx/access.log

# 模拟请求
root@ubuntu2204:~# ab -n 2000000 -c 5000 http://127.0.0.1/

# 请求之后的体积
root@ubuntu2204:~# ls -lh /var/log/nginx/access.log 
-rw-r--r-- 1 root root 2.1G Dec 10 07:51 /var/log/nginx/access.log
```
也可以直接使用`dd`命令创建一个大文件：  
```
dd if=/dev/zero of=/var/log/nginx/access.log bs=1M count=2000
```
再次查看一下`df`和`du`的输出：
```
root@ubuntu2204:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/sda2        16G  7.1G  7.9G  48% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           392M  4.0K  392M   1% /run/user/1000
root@ubuntu2204:~# du -xhd0 /
7.1G    /
```
删除`/var/log/nginx/access.log`之后：
```
root@ubuntu2204:~# rm -f /var/log/nginx/access.log

root@ubuntu2204:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/sda2        16G  7.1G  7.9G  48% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           392M  4.0K  392M   1% /run/user/1000

root@ubuntu2204:~# du -xhd0 /
5.0G    /
```
可以看到`du`的输出比`df`少了2.1G(刚好是nginx 日志的体积)，通过`lsof | grep deleted`可以查看到该文件:
```
root@ubuntu2204:~# lsof | grep deleted
nginx     1508                           root    4w      REG                8,2 2207152139     406582 /var/log/nginx/access.log (deleted)
nginx     1509                       www-data    4w      REG                8,2 2207152139     406582 /var/log/nginx/access.log (deleted)
nginx     1510                       www-data    4w      REG                8,2 2207152139     406582 /var/log/nginx/access.log (deleted)
nginx     1511                       www-data    4w      REG                8,2 2207152139     406582 /var/log/nginx/access.log (deleted)
nginx     1512                       www-data    4w      REG                8,2 2207152139     406582 /var/log/nginx/access.log (deleted)
```
用`ps`也可以看到刚好是nginx的主进程和worker进程：
```
$ ps aux | grep nginx
root        1508  0.0  0.0  55232  1676 ?        Ss   07:49   0:00 nginx: master process /usr/sbin/nginx -g daemon on; master_process on;
www-data    1509  5.8  0.1  55996  6392 ?        S    07:49   0:32 nginx: worker process
www-data    1510  6.7  0.1  55996  6392 ?        S    07:49   0:37 nginx: worker process
www-data    1511  3.5  0.1  55996  6392 ?        S    07:49   0:19 nginx: worker process
www-data    1512  2.9  0.1  55864  6392 ?        S    07:49   0:16 nginx: worker process
```
##### 存在已删除但未释放的文件
###### 释放文件句柄
可以通过以下方法释放文件句柄：  
1. 使用`kill -USR1`(等同于`nginx -s reopen`):  
	```
	root@ubuntu2204:~# kill -USR1 $(cat /run/nginx.pid)
	```
	Nginx 支持 Unix 信号控制，传入`USR1`可以重新加载日志文件（会关闭旧文件句柄）。Nginx master 收到`USR1`后所有`worker`进程会重新打开日志文件，原 deleted 文件句柄会被关闭，df 空间立即释放。  
	> Nginx提供了`nginx -s reopen`来给进程传递`USR1`信号，对于其他可能未实现的应用可以直接使用`kill -USR1`。  
2. 使用`kill -HUP`(等同于`nginx -s reload`)  
	```
	root@ubuntu2204:~# kill -HUP $(cat /run/nginx.pid)
	```
	传入`HUP`信号可以重新加载配置文件。相比于`USR1`仅重载日志文件，传入`HUP`信号后Nginx会优雅地重建worker进程，成本略高。  
3. 重启服务  
	重启服务会导致所有连接立即断开，未传输完的数据全部丢失，客户端可能看到`502`错误等问题，是不优雅的方案。
	```
	root@ubuntu2204:~# systemctl restart nginx
	```
4. `kill -9`强行杀死进程  
	如果服务无法正常重启，使用`kill -9`杀死进程，这是一种不推荐的方案，仅在上面的方法无效的情况下使用。
	```
	root@ubuntu2204:~# kill -9 $(cat /run/nginx.pid)
	```

> 如果上面的方法都无法使用，例如磁盘空间已满，应用不支持发送Unix信号，服务不能停止。  
> 可以使用`truncate`命令将仍然被保留的`deleted`文件`block`块大小清零  
>  **注意：truncate 只是用于“磁盘已经满了且服务无法重启”的紧急情况，不是标准日志轮转方案。**  
> ```
> # 首先找到nginx的pid
> root@ubuntu2204:~# cat /run/nginx.pid 
> 1508
> # 检查/proc/1508/fd/ 目录下哪个文件描述符指向被删除的日志文件
> root@ubuntu2204:~# ls -l /proc/1508/fd/*
> l-wx------ 1 root root 64 Dec 10 08:05 /proc/1508/fd/15 -> '/var/log/nginx/access.log (deleted)'
> # 使用truncate将文件大小清零
> root@ubuntu2204:~# truncate -s 0 /proc/1508/fd/15
> ```
> truncate 清空 deleted 文件后，并不会让进程自动切换到新的日志文件。进程仍然继续向这个匿名 inode 写日志，因此 df 空间会继续增长；而 du 不会察觉这个匿名 inode。  
> **清空后应当立即使用上面的任一方法释放掉文件句柄**，否则新的日志仍无法写入正常文件。  
> 清空后新产生的日志内容可以使用`cat /proc/1508/fd/15 > /tmp/access.log`取出（需要在文件句柄释放前取出）。


使用上面的任意方法后，都可以发现`df -h`的输出正常：
```
root@ubuntu2204:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/sda2        16G  5.0G  9.9G  34% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           392M  4.0K  392M   1% /run/user/1000
root@ubuntu2204:~# du -xhd0 /
5.0G    /
```
并且`lsof`不存在`deleted`文件，`/var/log/nginx/access.log`存在：
```
root@ubuntu2204:~# lsof | grep deleted
root@ubuntu2204:~# ls -l /var/log/nginx/access.log
-rw-r--r-- 1 root root 0 Dec 10 09:32 /var/log/nginx/access.log
```
###### 文件存储原理
假如要存储`a.txt`到`/tmp`目录，存储时：  
1. 从 inode table 中找到一个空闲的 inode 号分配给`a.txt`，例如`2222`，然后将`inode map(imap)`中`2222`这个 inode 号标记为"已使用".
2. 在`/tmp`的 data block 中添加一条`a.txt`文件的记录，该记录中包括一个指向 inode 号的指针，例如`0x2222`。
3. 从`block map(bmap)`中找到空闲的 data block，并开始将`a.txt`中的数据写入到 data block 中，每写一段空间(ext4每次分配一次空间)就从 bmap 中找一次空闲的 data block，直到存完所有数据。
4. 设置 inode table 中关于`2222`这条记录的 data block 指针，通过该指针可以找到`a.txt`使用了哪些 data block。

删除`a.txt`文件时：
1. 在inode table中删除指向a.txt的data block指针。这里只要一删除，外界就找不到a.txt的数据了。但是这个文件还存在，只是它是被”损坏”的文件，因为没有任何指针指向数据块。
2. 在imap中将2222的inode号标记为未使用。于是这个inode号就被释放，可以被后续的文件重用。
3. 删除父目录/tmp的data block中关于a.txt的记录。这里只要一删除，外界就看不到也找不到这个文件了。
4. 在bmap中将a.txt占用的block标记为未使用。这里被标记为未使用后，这些data block就可以被后续文件覆盖重用。

当一个文件被删除时，如果此时还有进程在使用这个文件，删除过程会进行完第3步，而文件的block不会被标记为未使用，由于进程在加载文件时已经获取到了该文件占用的block地址，因此进程仍然可以写入和读取文件。


#### 子目录被挂载到其他文件系统
当我们将一个新的磁盘或分区挂载到一个已存在文件的目录上时，新挂载的文件系统会覆盖原目录下的所有文件 。此时，du命令只能统计新挂载文件系统中的文件大小，而df命令会统计整个挂载点所在分区的空间使用情况，包括那些被隐藏的原文件所占用的空间 。  
例如在`/data`目录下有一个`2G`大小的文件:  
```
$ ls -lh 111.txt 
-rw-r--r-- 1 root root 2.0G Dec 11 08:18 111.txt
```
此时的`df`和`du`输出相同:  
```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/sda2        16G  7.0G  8.0G  47% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           392M  4.0K  392M   1% /run/user/1000

$ du -xhd0 /
7.0G    /
```
然后我们把`/dev/sdb1`挂载到`/data`目录上，`/dev/sdb1`是一个空的文件系统:
```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.1M  391M   1% /run
/dev/sda2        16G  7.0G  8.0G  47% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           392M  4.0K  392M   1% /run/user/1000
/dev/sdb1       452M   24K  417M   1% /data

$ du -xhd0 /
5.0G    /
```
可以看到`du`的输出比`df`少了2G。  
如果遇到这种情况，可以直接使用`mount`命令查看磁盘挂载情况，然后临时卸载掉磁盘：
```
$ mount
/dev/sdb1 on /data type ext4 (rw,relatime)

$ umount /dev/sdb1 

$ du -xhd0 /
7.0G    /
```
卸载后发现`du`输出恢复正常。
#### 其他可能的情况
- 错误的使用`du`命令：当使用`du -sh *`命令时，不会读取当前目录下的隐藏文件和隐藏目录，使用`du -sh ./`即可。  
- ~~`du`重复计算硬链接占用(未复现)~~
- ~~使用了磁盘保留分区(未复现)~~
- ~~文件系统损坏(未复现)~~

## 参考
- [当磁盘满了，df和du却“各执一词”，真相只有5个](https://mp.weixin.qq.com/s/PfCVixxKRyrungL3GbsycA)
- [如何处理df和du输出不一致的问题](https://help.aliyun.com/zh/alinux/support/what-do-i-do-if-the-df-and-du-command-outputs-are-inconsistent)
- [使用du与df命令查看磁盘容量不一致](https://help.aliyun.com/zh/ecs/user-guide/the-use-of-du-do-not-agree-with-the-df-command-view-disk-capacity)
- [du](https://wangchujiang.com/linux-command/c/du.html)
- [详细分析du和df的统计结果为什么不一样](https://www.yunweipai.com/39386.html)
