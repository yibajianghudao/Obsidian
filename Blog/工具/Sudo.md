---
weight: 100
title: Sudo
slug: sudo
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-01-09T10:20:59+08:00
lastmod: 2026-01-09T10:55:21+08:00
---

## Secure Path
`secure_path`是在sudo`1.9.16`版本被默认启用的,它会使用一个被认为安全的值来覆盖用户的PATH环境变量.通常这意味着只包含系统二进制目录.  
查看我的`secure_path`配置:
```
[~]$ sudo -l | grep -i secure_path
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin, use_pty, pwfeedback

# 也可以在visudo查看
[~]$ sudo visudo
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
```
使用`sudo env`验证:
```
$ sudo env | grep '^PATH='
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
```
关于[为什么要启用`secure_path`](https://www.sudo.ws/posts/2024/09/why-sudo-1.9.16-enables-secure_path-by-default/):

> 虽然 sudo 本身在 sudoers 文件中匹配的是**完全限定路径名**，但通过 sudo 启动的应用程序可能会在运行过程中再调用其他程序，而这些调用并不一定使用完整路径。例如，设想一个通过 sudo 运行的应用程序需要删除一个临时文件，于是它执行了：  
> `rm /tmp/prog.tmp`  
> 如果没有启用 `secure_path`，用户就有可能在自己可控的目录中创建一个名为 `rm` 的恶意程序，并将该目录放在 PATH 的最前面。这样一来，当 sudo 运行的命令调用 `rm` 时，实际执行的将是这个恶意程序，而不是系统自带的 `/bin/rm`。  
> 在 sudoers 文件中设置 `secure_path` 可以防止这种攻击。通过 sudo 运行的应用程序只能从管理员认为是安全的路径中执行程序，而运行中的应用程序所使用的 PATH 也同样是这个安全值.



## 问题
### sudo secure path
尝试通过sudo运行一个go程序:
```
$ sudo go run .  
sudo: go: command not found
```
发现使用sudo之后找不到go命令
```
$ sudo whereis go
go: /usr/local/go
```
但是不使用sudo是可以正常看到的:
```
$ whereis go
go: /usr/local/go /usr/local/go/bin/go
```
想起来我的这个路径添加到`$PATH`是在`~/.zshrc`中配置的,~~root读不到也正常~~(这种想法是错误的,实际上sudo默认不会使用root的环境变量):
```
$ cat ~/.zshrc | grep go
export PATH=$PATH:/usr/local/go/bin
```
然后我把它加到了`/etc/profile.d/go.sh`(并注释了`~/.zshrc`的配置)
```
$ cat /etc/profile.d/go.sh 
export PATH=$PATH:/usr/local/go/bin

```
重启之后发现还是不行,而且非常奇怪:
```
[~]$ sudo whereis go
go: /usr/local/go

[~]$ whereis go
go: /usr/local/go /usr/local/go/bin/go

[~]$ sudo echo $PATH         
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin

[~]$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin
```
~~可以发现普通用户和sudo下都可以看到这个路径~~,普通用户可以直接运行,但是sudo就是找不到.  
> 实际上`sudo echo $PATH`并不是输出sudo下的环境变量,而是先在当前shell中解释出`$PATH`然后由sudo调用`echo`命令输出(`sudo -i echo $PATH`也一样),真正的sudo下的环境变量要用`sudo env`查看

然后发现是[Secure Path](Sudo.md#Secure%20Path)导致的.直接使用sudo,环境变量会被`secure_path`覆盖.    
查看一下sudo下的环境变量:
```
[~]$ sudo env | grep '^PATH='
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
```
果然只有`secure_path`中的路径  
可以直接使用`sudo -i`使用`login shell`来获得root的环境变量:
```
[~]$ sudo -i env | grep '^PATH='                            
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/usr/local/go/bin

[~]$ sudo -i go version
go version go1.25.4 linux/amd64
```
更优雅的方法是把`/usr/local/go/bin/go`添加一个软链接到`secure_path`中的路径:
```
[~]$ sudo ln -s /usr/local/go/bin/go /usr/local/bin/go
[~]$ sudo ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt 
[~]$ ll /usr/local/bin/go*
lrwxrwxrwx 1 root root 20  1月  9 10:29 /usr/local/bin/go -> /usr/local/go/bin/go
lrwxrwxrwx 1 root root 23  1月  9 10:29 /usr/local/bin/gofmt -> /usr/local/go/bin/gofmt

[~]$ sudo go version         
go version go1.25.4 linux/amd64
```
