---
weight: 100  
title: Smokeping  
slug: smokeping  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:35:03+08:00  
lastmod: 2025-11-20T10:17:27+08:00  
---
## 安装  
首先配置[[docs/Linux/安装操作系统#修改软件源|apt国内源]]  
然后安装`smokeping`软件包  
```  
sudo apt install smokeping  
```  
postfix只作为smokeping的依赖安装,选择`local only`即可,邮件域名随意设置  
smokeping会自带一个apache的配置文件:  
```  
newuser@ubuntu22:/$ cat /etc/apache2/conf-available/smokeping.conf  
ScriptAlias /smokeping/smokeping.cgi /usr/lib/cgi-bin/smokeping.cgi  
Alias /smokeping /usr/share/smokeping/www  
<Directory "/usr/share/smokeping/www">  
    Options FollowSymLinks  
    Require all granted  
    DirectoryIndex smokeping.cgi  
</Directory>  
```  
此时可以通过访问`http://ip:port/smokeping/smokeping.cgi`访问  
然后在`/etc/apache2/mods-available/dir.conf`内添加`smokeping.cgi`,然后只需要访问http://ip:port/smokeping`即可  
### 添加Basic认证  
```  
root@cww:~# sudo apt install apache2-utils  
root@cww:~# sudo htpasswd -c /etc/apache2/.htpasswd 123  
New password:  
Re-type new password:  
root@cww:~# sudo vim /etc/apache2/conf-available/smokeping.conf  
ScriptAlias /smokeping/smokeping.cgi /usr/lib/cgi-bin/smokeping.cgi  
Alias /smokeping /usr/share/smokeping/www  
<Directory "/usr/share/smokeping/www">  
    AuthType Basic  
    AuthName "Restricted Area"  
    AuthUserFile /etc/apache2/.htpasswd  
    Options FollowSymLinks  
    Require valid-user granted  
</Directory>  
```  
再次访问页面需要输入密码  
![](assets/Smokeping/添加Basic认证-20251025114603710.png)  
### 配置  
配置文件在`/etc/smokeping/conf.d/Targets`:  
配置文件格式如下:  
```  
*** Targets ***
# 测试方法  
probe = FPing  
menu = Top  
title = Network Latency Grapher  
remark = Welcome to the SmokePing website of xxx Company. \  
         Here you will learn all about the latency of our network.  
+ Other  
menu = 网络监控  
title = 监控统计  
++ dianxin  
menu = 电信  
title = 电信节点网络监控列表  
host = /Other/dianxin/guizhouguiyangdianxin  
+++ guizhouguiyangdianxin  
menu = 贵州贵阳电信  
title = 贵州贵阳电信  
host =  
+++ gansulanzhoudianxin  
menu = 甘肃兰州电信  
title = 甘肃兰州电信  
host =  
+++ chongqingchongqingdianxin  
menu = 重庆重庆电信  
title = 重庆重庆电信  
host =  
+++ liaoningshenyangdianxin  
menu = 辽宁沈阳电信  
title = 辽宁沈阳电信  
host =  
```  
`+`,`++`,`+++`表示层级,后面的是标识符  
menu是在菜单中显示的名称,title是页面显示的标题  
host是主机,可以指定ip地址,也可以指定标识符层级,例如`/Other/dianxin/qinghaihaidongdianxin`,多个主机用空格分隔,最终会显示到层页面上:  
![](assets/Smokeping/配置-20251025115757028.png)  
页面最后还有一个总结图  
![](assets/Smokeping/配置-20251025115835469.png)  
## 问题  
### 图片无法显示中文  
安装字体软件包:`apt install ttf-wqy-*`,主要是`ttf-wqy-zenhei`软件包  
安装完字体包后发现部分图像依旧无法正常显示  
![](assets/Smokeping/图片无法显示中文-20251024102216754.png)  
这是因为该条目收集的时间长,短时间内数据没有更新,因此还没有使用新安装的字体生成图像  
检查一下配置中图像缓存地址:  
```  
$ grep imgcache /etc/smokeping/config.d/*  
/etc/smokeping/config.d/pathnames:imgcache = /var/cache/smokeping/images  
```  
cd到指定目录,发现是以一级标题的标识号分为不同的文件夹(配置文件中是`+ Other`)  
```  
newuser@ubuntu22:/var/cache/smokeping/images$ ls  
__chartscache  Local       Other        smokeping.png  TELCOM  WANGWANGDUI  
CMCC           __navcache  rrdtool.png  tance          UNICOM  
```  
找到想要更新的图像,删除即可  
```  
newuser@ubuntu22:/var/cache/smokeping/images$ cd Other/  
newuser@ubuntu22:/var/cache/smokeping/images/Other$ ls  
alibaba                    dianxin_last_31104000.png   liantong_mini.png  
alibaba_last_108000.png    dianxin_last_864000.png     qita_mini.png  
alibaba_last_10800.png     dianxin.maxheight           yidong  
alibaba_last_31104000.png  dianxin_mini.png            yidong_last_108000.png  
alibaba_last_864000.png    liantong                    yidong_last_10800.png  
alibaba.maxheight          liantong_last_108000.png    yidong_last_31104000.png  
alibaba_mini.png           liantong_last_10800.png     yidong_last_864000.png  
dianxin                    liantong_last_31104000.png  yidong.maxheight  
dianxin_last_108000.png    liantong_last_864000.png    yidong_mini.png  
dianxin_last_10800.png     liantong.maxheight  
newuser@ubuntu22:/var/cache/smokeping/images/Other$ sudo rm -r dianxin_last_31104000.png  
```  
打开浏览器清除缓存或新建一个隐私窗口后发现图像已经更新:  
![](assets/Smokeping/图片无法显示中文-20251024102350282.png)  
## 其它  
### Python脚本  
这里有一个Python脚本  
{{< code file="assets/Smokeping/readTitleHostFromXLSX.py" language="python" >}}  
![](assets/Smokeping/image.png)  
负责从上图格式的`.xslx`文件中提取其中(探测点,探测源IP)两列的数据,并将其生成为smokeping所用的Target的配置文件,格式类似于:  
```  
++ liaoning  
menu = 辽宁  
title = 辽宁  
host = 1.180.240.1  
++ heilongjiang  
menu = 黑龙江  
title = 黑龙江  
host = 222.170.0.61  
++ jilin  
menu = 吉林  
title = 吉林  
host = 222.168.78.1  
++ shandong  
menu = 山东  
title = 山东  
host = 42.199.255.100  
```  
也可以按照给定的标签分类,类似于:  
```  
+ dianxin  
menu = 电信  
title = 电信  
++ beijingdianxin  
menu = 北京电信  
title = 北京电信  
host = 220.181.111.37  
++ tianjindianxin  
menu = 天津电信  
title = 天津电信  
host = 42.122.0.1  
++ hebeidianxin  
menu = 河北电信  
title = 河北电信  
host = 47.92.159.1  
++ neimenggudianxin  
menu = 内蒙古电信  
title = 内蒙古电信  
host = 42.123.64.1  
```