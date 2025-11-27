---
weight: 100  
title: 磁盘满了怎么处理  
slug: 磁盘满了怎么处理  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:13:31+08:00  
lastmod: 2025-11-20T09:13:31+08:00  
---
首先使用`df -h`或`df -i`查看是空间不足还是inode满了  
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
是由于inode使用率满了  
## inode使用率过高  
大多数是因为文件数量过多,删除无用的文件即可  
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
尝试直接使用`rm`删除发现文件太多:  
```  
root@cww:/var/spool/postfix/maildrop# rm -rf ./*  
-bash: /bin/rm: Argument list too long  
```  
可以去掉命令结尾的`*`,变成`rm -rf ./`来运行  
我们也可以使用`rsync`快速删除大量文件  
```  
# 创建一个空目录  
mkdir /tmp/clear/  
# 同步/var/spool/postfix/maildrop/目录下的文件到/tmp/clear,多余的文件会被删除  
root@cww:# rsync -av --delete /tmp/clear/ /var/spool/postfix/maildrop/  
```  
由于`/tmp/clear/`是空文件,因此所有文件会被删除  
>如果/tmp/clear 文件夹不能创建,可以先使用下面的脚本删除一些文件:  
>`ls -t ./ | tail -n 1000 | xargs -I {} rm -v /var/spool/postfix/maildrop/{}`  
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
```  
root@cww:~# cat /etc/netplan/00-installer-config.yaml  
# This is the network config written by 'subiquity'  
network:  
  ethernets:  
    ens160:  
      addresses:  
      - 42.225.98.24/27  
      gateway4: 42.225.98.1  
      nameservers:  
        addresses:  
        - 114.114.114.114  
        search: []  
  version: 2  
```  
```  
root@cww:~# ip a  
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000  
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00  
    inet 127.0.0.1/8 scope host lo  
       valid_lft forever preferred_lft forever  
    inet6 ::1/128 scope host  
       valid_lft forever preferred_lft forever  
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000  
    link/ether 00:0c:29:d0:a2:d5 brd ff:ff:ff:ff:ff:ff  
    inet 42.225.98.24/27 brd 42.225.98.31 scope global ens160  
       valid_lft forever preferred_lft forever  
    inet6 fe80::20c:29ff:fed0:a2d5/64 scope link  
       valid_lft forever preferred_lft forever  
```