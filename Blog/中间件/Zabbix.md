---
weight: 100  
title: Zabbix  
slug: zabbix  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:35:21+08:00  
lastmod: 2025-11-20T09:41:09+08:00  
---
Zabbix是一个开源的分布式监控软件  
## 安装  
在[zabbix下载页面](https://www.zabbix.com/cn/download)选择希望安装的版本  
例如,对于ubuntu22.04-Server,Frontend,Agent2-MySQL-Apache-7.0LTS,下载步骤包括:  
(`#`表示root用户命令,`##`表示注释)  
```  
## 下载仓库  
# wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu22.04_all.deb  
# dpkg -i zabbix-release_latest_7.0+ubuntu22.04_all.deb  
# apt update  
## 安装zabbix server frontend agent2 agent2 plugins  
# apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2  
# apt install zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql  
## 安装数据库  
# apt install mysql-server  
# systemctl enable --now mysql.service  
## 创建数据库  
# mysql -uroot -p  
password  
mysql> create database zabbix character set utf8mb4 collate utf8mb4_bin;  
mysql> create user zabbix@localhost identified by 'password';  
mysql> grant all privileges on zabbix.* to zabbix@localhost;  
mysql> set global log_bin_trust_function_creators = 1;  
mysql> quit;  
## 导入初始架构和数据  
# zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix  
## 关闭 log_bin_trust_function_creators  
# mysql -uroot -p  
password  
mysql> set global log_bin_trust_function_creators = 0;  
mysql> quit;  
## 修改配置文件中的数据库密码  
# vim /etc/zabbix/zabbix_server.conf  
DBPassword=password  
## 启用并启动服务  
# systemctl restart zabbix-server zabbix-agent2 apache2  
# systemctl enable zabbix-server zabbix-agent2 apache2  
```  
在创建数据库之前,最好先运行数据库安全脚本:  
```  
sudo mysql  
mysql> ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password';  
mysql> quit  
sudo mysql_secure_installation  
```  
> 在运行mysql安全安装脚本以前,需要先给root用户添加一个密码,否则脚本会出错,参考[这篇文章](https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-22-04#step-2-how-to-configure-mysql-on-ubuntu)  
此时访问`http://ip/zabbix`即可访问Web页面  
![](assets/Zabbix/安装-20251025144935832.png)  
无法选择中文是因为还没有生成中文的locale  
```  
sudo apt install locales  
sudo locale-gen zh_CN.UTF-8  
sudo systemctl restart apache2.service  
# 或者  
sudo systemctl restart php*.*-fpm nginx  
```  
根据指引配置完后,使用账号:`Admin`,密码:`zabbix`登录后台  
## 迁移  
参考[官方手册]([3 模板](https://www.zabbix.com/documentation/7.0/zh/manual/xml_export_import/templates))  
首先迁移主机用到的模板,然后迁移主机  
### 模板  
在 数据采集-模板 页面选择要迁移的模板并导出  
在新的Zabbix服务器上相同的页面导入文件  
### 主机  
在 数据采集-主机 页面选择要迁移的主机并导出  
在新的Zabbix服务器上相同的页面导入文件  
### 告警  
在 告警-媒介 页面选择要迁移的媒介导出  
在新的Zabbix服务器上相同的页面导入文件  
在 告警-动作-触发器动作 页面新建一个动作(当添加多个条件后才会显示计算方式)  
在 用户 页面给指定的用户添加报警媒介  
## 错误  
### 图表不能显示中文  
进入后台发现有些图表无法正常显示中文:  
![](assets/Zabbix/图表不能显示中文-20251025145841767.png)  
通过`grep`命令发现在zabbix的配置文件中指定的图形字体是`graphfont`:  
```  
newuser@ubuntu22:/usr/share/zabbix$ grep -r "font" | grep graph  
...  
include/defines.inc.php:define('ZBX_GRAPH_FONT_NAME',           'graphfont'); // font file name  
include/defines.inc.php:define('ZBX_FONT_NAME', 'graphfont');  
...  
```  
我们继续用`grep`查看`ZBX_GRAPH_FONT_NAME`变量使用的位置:  
```bash  
newuser@ubuntu22:/usr/share/zabbix$ grep -r "ZBX_GRAPH_FONT_NAME" /usr/share/zabbix  
/usr/share/zabbix/include/defines.inc.php:define('ZBX_GRAPH_FONT_NAME',  'graphfont'); // font file name  
/usr/share/zabbix/include/graphs.inc.php:       if ((preg_match(ZBX_PREG_DEF_FONT_STRING, $string) && $angle != 0) || ZBX_FONT_NAME == ZBX_GRAPH_FONT_NAME) {  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_GRAPH_FONT_NAME.'.ttf';  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_GRAPH_FONT_NAME.'.ttf';  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_GRAPH_FONT_NAME.'.ttf';  
```  
可以看到`ttf`变量组合了`ZBX_FONTPATH`和`ZBX_GRAPH_FONT_NAME`,我们继续寻找`ZBX_FONTPATH`的位置  
```  
newuser@ubuntu22:/usr/share/zabbix$ grep -r "ZBX_FONTPATH." /usr/share/zabbix  
/usr/share/zabbix/include/defines.inc.php:define('ZBX_FONTPATH',         realpath('assets/fonts')); // where to search for font (GD > 2.0.18)  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_FONT_NAME.'.ttf';  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_GRAPH_FONT_NAME.'.ttf';  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_GRAPH_FONT_NAME.'.ttf';  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_FONT_NAME.'.ttf';  
/usr/share/zabbix/include/graphs.inc.php:               $ttf = ZBX_FONTPATH.'/'.ZBX_GRAPH_FONT_NAME.'.ttf'  
```  
找到了`ZBX_FONTPATH`的值是`assets/fonts`  
```  
newuser@ubuntu22:/usr/share/zabbix$ ll assets/fonts/  
total 204  
drwxr-xr-x 2 root root   4096 Oct 25 06:15 ./  
drwxr-xr-x 5 root root   4096 Oct 25 06:14 ../  
lrwxrwxrwx 1 root root     38 Oct 25 06:15 graphfont.ttf -> /etc/alternatives/zabbix-frontend-font  
-rw-r--r-- 1 root root 149851 Sep 29 15:14 zabbix-icons.svg  
-rw-r--r-- 1 root root  22072 Sep 29 15:14 zabbix-icons.ttf  
-rw-r--r-- 1 root root  11716 Sep 29 15:14 zabbix-icons.woff  
-rw-r--r-- 1 root root   9756 Sep 29 15:14 zabbix-icons.woff2  
```  
发现`/usr/share/zabbix/assets/fonts/graphfont.ttf`是一个指向`/etc/alternatives/zabbix-frontend-font`文件的软链接  
继续查看`/etc/alternatives/zabbix-frontend-font`文件:  
```  
newuser@ubuntu22:/usr/share/zabbix$ ll /etc/alternatives/zabbix-frontend-font  
lrwxrwxrwx 1 root root 47 Oct 25 06:15 /etc/alternatives/zabbix-frontend-font -> /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf  
```  
发现`/etc/alternatives/zabbix-frontend-font`指向的是`/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`  
我们只需要把`/etc/alternatives/zabbix-frontend-font`指向的字体修改成一个中文字体即可:  
```  
sudo apt install -y fonts-noto-cjk  
sudo ln -sf /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc /etc/alternatives/zabbix-frontend-font  
ll /etc/alternatives/zabbix-frontend-font  
lrwxrwxrwx 1 root root 54 Oct 25 07:13 /etc/alternatives/zabbix-frontend-font -> /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc  
```  
之后重启`apache2`或`nginx`服务即可  
```  
sudo systemctl restart apache2.service  
# 或者  
sudo systemctl restart php*.*-fpm nginx  
```  
![](assets/Zabbix/图表不能显示中文-20251025151539309.png)  
可以看到图表已正常显示中文  
### 自动重启  
导入一些主机之后发现zabbix-server service在不断的重启,部分报错日志如下:  
```  
newuser@ubuntu22:~$ tail -f /var/log/zabbix/zabbix_server.log 127632:20251027:014018.111 server #0 started [main process] 127634:20251027:014018.114 server #1 started [service manager #1] 127635:20251027:014018.115 server #2 started [configuration syncer #1] 127635:20251027:014019.381 0: /usr/sbin/zabbix_server: configuration syncer [syncing configuration](_start+0x25) [0x556ce5ad0c65] 127635:20251027:014019.381 [file:dbconfig.c,line:231] __zbx_shmem_malloc(): out of memory (requested 48 bytes)  
127635:20251027:014019.382 [file:dbconfig.c,line:231] __zbx_shmem_malloc(): please increase CacheSize configuration parameter 127632:20251027:014019.401 One child process died (PID:127635,exitcode/signal:1). Exiting ... 127633:20251027:014019.401 HA manager has been paused 127633:20251027:014019.410 HA manager has been stopped 127632:20251027:014019.415 Zabbix Server stopped. Zabbix 7.0.19 (revision a2d0368f1b9).  
```  
可以看到主要是因为`out of memory`内存不足导致的,根据提示修改配置文件中的`CacheSize`即可  
编辑zabbix-server的配置文件:  
```  
sudo vim /etc/zabbix/zabbix_server.conf  
# CacheSize=32M  
CacheSize=256M  
```