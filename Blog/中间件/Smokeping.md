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
lastmod: 2025-12-19T17:28:35+08:00
---
## 安装  
### ubuntu
首先配置`apt`国内源,然后安装`smokeping`软件包  
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
然后在`/etc/apache2/mods-available/dir.conf`内添加`smokeping.cgi`,然后只需要访问`http://ip:port/smokeping`即可  
#### 添加Basic认证  
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
### CentOS
如果是在CentOS系统上，需要配置`EPEL`仓库才能安装`smokeping`软件包，软件包会自动安装apache2(httpd软件包).  
```
yum install -y smokeping
```
安装完成后，apache配置目录会存在一个配置文件`/etc/httpd/conf.d/smokeping.conf`:
```
<Directory "/usr/share/smokeping" >
  Require local
  # Require ip 2.5.6.8
  # Require host example.org
</Directory>

<Directory "/var/lib/smokeping" >
  Require local
  # Require ip 2.5.6.8
  # Require host example.org
</Directory>

# .fcgi : smokeping by mod_fcgid aka fastcgi
# _cgi  : plain old fashion cgi
ScriptAlias /smokeping/sm.cgi  /usr/share/smokeping/cgi/smokeping.fcgi
#ScriptAlias /smokeping/sm.cgi  /usr/share/smokeping/cgi/smokeping_cgi

Alias       /smokeping/images  /var/lib/smokeping/images
Alias       /smokeping         /usr/share/smokeping/htdocs
```

其中`Require local`表明只允许本地访问，我们可以修改为基于Basic认证的方式：
```
<Directory "/usr/share/smokeping" >
  AuthType Basic
  AuthName "SmokePing Restricted"
  AuthUserFile /etc/httpd/conf/.htpasswd_smokeping
  Require valid-user
</Directory>

<Directory "/var/lib/smokeping" >
  AuthType Basic
  AuthName "SmokePing Restricted"
  AuthUserFile /etc/httpd/conf/.htpasswd_smokeping
  Require valid-user
</Directory>
```
然后生成一下密码文件：
```
[root@localhost ~]# htpasswd -c /etc/httpd/conf/.htpasswd_smokeping username
```
### Docker
这是一个使用CentOS7部署的手册

添加防火墙规则
```
firewall-cmd --permanent --add-port=8881/tcp
```
配置镜像源,docker-ce源
```
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo  
curl -o /etc/yum.repos.d/docker-ce.repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```
清理旧缓存,生成新缓存
```
yum clean all
yum makecache fast
```
安装docker-ce 24.0.7版本
```
yum install -y docker-ce-24.0.7-1.el7 docker-ce-cli-24.0.7-1.el7 containerd.io
```
启用docker
```
systemctl enable --now docker
```
创建普通用户，添加到wheel,docker组
```
useradd -m newuser
usermod -aG wheel newuser
usermod -aG docker newuser
```
切换到 newuser
```
su - newuser
```
设置密码
```
passwd
```
创建config和data目录
```
sudo mkdir -p /opt/smokeping/config
sudo mkdir -p /opt/smokeping/data

# 修改权限
sudo chown -R newuser:newuser /opt/smokeping
```
查看当前用户的uid,gid.
```
$ id
uid=1000(newuser) gid=1000(newuser) groups=1000(newuser),10(wheel),995(docker)
```
#### 不需要Basic auth
Smokeping有打包好的[镜像](https://hub.docker.com/r/linuxserver/smokeping)
```
# 使用镜像站拉取
docker pull m.daocloud.io/docker.io/linuxserver/smokeping:2.7.3

# 修改一下tag
docker tag m.daocloud.io/docker.io/linuxserver/smokeping:2.7.3 smokeping:2.7.3

# 删除旧镜像
docker rmi m.daocloud.io/docker.io/linuxserver/smokeping:2.7.3
```
运行：
```
docker run -d --name=smokeping -p 8881:80 -e PUID=1000 -e PGID=1000 -v /opt/smokeping/config:/config -v /opt/smokeping/data:/data --restart unless-stopped smokeping:2.7.3
```
目录结构:
```
/opt/smokeping/
├── config      # smokeping配置文件目录
├── data        # smokeping数据目录
```
#### 需要Basic auth
smokeping容器内自带一个apache服务器，但是在直接设置Basic auth无法使用，参考这个[issue](https://github.com/linuxserver/docker-smokeping/issues/85)，我们可以再使用一个Nginx容器(也可以是apache)在外部进行Basic auth认证。  
拉取smokeping[镜像](https://hub.docker.com/r/linuxserver/smokeping)和Nginx镜像
```
docker pull m.daocloud.io/docker.io/linuxserver/smokeping:2.7.3
docker pull swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nginx:1.27.0

# 修改一下tag
docker tag m.daocloud.io/docker.io/linuxserver/smokeping:2.7.3 smokeping:2.7.3
docker tag swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nginx:1.27.0  docker.io/nginx:1.27.0
# 删除旧镜像
docker rmi m.daocloud.io/docker.io/linuxserver/smokeping:2.7.3
docker rmi swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nginx:1.27.0
```

安装htpasswd命令，创建密码文件
```
sudo yum install -y httpd-tools
htpasswd -c /opt/smokeping/htpasswd 123
```

编辑`docker-compose.yaml`文件:
```
services:
  smokeping:
    image: smokeping:2.7.3
    container_name: smokeping
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
    volumes:
      - /opt/smokeping/config:/config
      - /opt/smokeping/data:/data
    restart: unless-stopped
    networks:
      - proxy-net

  nginx-proxy:
    image: nginx:1.27.0
    container_name: smokeping-nginx
    ports:
      - "8881:80"
    volumes:
      - /opt/smokeping/htpasswd:/etc/nginx/.htpasswd:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - smokeping
    restart: unless-stopped
    networks:
      - proxy-net

networks:
  proxy-net:
    driver: bridge
```
编辑`nginx.conf`文件
```
server {
    listen 80;

    server_name _;
    location /smokeping/ {
        auth_basic "SmokePing Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://smokeping:80/smokeping/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
    }
}
```
使用`docker compose`命令运行容器
```
docker compose up -d
```
然后可以使用 http://ip:port/smokeping/ 访问网页    
目录结构:
```
/opt/smokeping/
├── config      # smokeping配置文件目录
├── data        # smokeping数据目录
├── docker-compose.yml
├── htpasswd    # basic auth密码文件
└── nginx.conf  # nginx配置文件
```


## 配置  
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
host = 1.150.240.1  
++ heilongjiang  
menu = 黑龙江  
title = 黑龙江  
host = 222.230.0.61  
++ jilin  
menu = 吉林  
title = 吉林  
host = 212.168.78.1  
++ shandong  
menu = 山东  
title = 山东  
host = 42.129.255.100  
```  
也可以按照给定的标签分类,类似于:  
```  
+ dianxin  
menu = 电信  
title = 电信  
++ beijingdianxin  
menu = 北京电信  
title = 北京电信  
host = 220.141.111.37  
++ tianjindianxin  
menu = 天津电信  
title = 天津电信  
host = 2.122.0.1  
++ hebeidianxin  
menu = 河北电信  
title = 河北电信  
host = 4.92.159.1  
++ neimenggudianxin  
menu = 内蒙古电信  
title = 内蒙古电信  
host = 42.13.64.1  
```