---
weight: 100
title: Link
slug: link
description: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-12-25T11:14:43+08:00
lastmod: 2025-12-26T09:12:53+08:00
---


  

## 前置条件

  

硬件环境:

  

| IP | 节点作用 |

| -------------- | ------------------ |

| 192.168.163.80 | ansible 节点 |

| 192.168.163.81 | 中间件运行节点 |

| 192.168.163.82 | 运行前后端服务节点 |

| 192.168.163.83 | 前后端项目构建节点 |

  

ssh密钥

  

ansible使用前需要确保ansible节点服务器的公共 SSH 密钥已添加到每个主机上的 `authorized_keys` 文件中

  

```

# 生成密钥

ssh-keygen

  

# 复制密钥

ssh-copy-id -i ~/.ssh/id_rsa.pub -p 22 newuser@192.168.163.81

ssh-copy-id -i ~/.ssh/id_rsa.pub -p 22 newuser@192.168.163.82

ssh-copy-id -i ~/.ssh/id_rsa.pub -p 22 newuser@192.168.163.83

```

  

## 安装  过程

  

Ansible可以使用python的包管理器安装(例如`pip3`,`uv`)

  

```

# 安装pip

sudo apt-get install -y python3-pip

  

# 安装ansible

pip install ansible

```

  



## ,.[]命令 -  

## ,.[]命令#-  

```

ansible <host-pattern> [options]

-v #显示详细信息

-i #主机清单文件路径，默认是在/etc/ansible/hosts

-m #使用的模块名称，默认使用command模块

-a #使用的模块参数，模块的具体动作

-k #提示输入ssh密码，而不使用基于ssh的密钥认证

-C #模拟执行测试，但不会真的执行

-T #执行命令的超时

-f <FORKS>, --forks <FORKS> #指定要使用的并行进程数（默认=5）

-u #连接服务器的用户名

--become #提升特权,默认为root

-b #使用become(提权)运行操作

```

  

### UbunTTU - 24141

  

使用`-become`参数提权,同时附加`--ask-become-pass`从命令行读取输入密码

  

```

ansible web -i inventory.yml -m file -a "dest=/home/newuser/wordpress state=absent" --become --ask-become-pass

BECOME password:

```
### CentoU --- 24141
  
### ARCH---24141  
### ROCKy ----- 24141

### LINUX-LINUX
### LINUX(2024)

## mon daemon错误

  

![ansible_inv_start](Ansileb/ansible_inv_start-1754414566489-3.svg)

  

大多数Ansible环境具有三个主要组件:

  

- 控制节点(control node): 安装Ansible的系统,可以在控制节点上运行Ansible命令,例如`ansible`或`ansible-inventory`

- 清单(inventory): 以逻辑方式组织的受控节点列表,在控制节点上创建清单来向ansible描述主机部署

- 受控节点(managed nodes): Ansible控制的远程系统或主机

  

![img](Ansileb/5e757e423cb7cf4dda000002.png)

  

1. 连接插件`connection plugins`用于连接被控节点

2. 核心模块`core modules`连接主机实现操作， 它依赖于具体的模块来做具体的事情

3. 自定义模块`custom modules`根据自己的需求编写具体的模块

4. 插件`plugins`完成模块功能的补充

5. 剧本`playbook`是ansible中的脚本,定义多个任务，由ansible自动执行

6. 主机清单`inventory`定义被控节点的信息

  

> 除非使用`ansible-pull`,否则被控节点也需要安装`ansible`

  

##   WS WPS ''""

  

Ansible配置文件的读取顺序(越往上优先级越高):

  

- `ANSIBLE_CONFIG`（如果设置了环境变量）

- `ansible.cfg`（在当前目录中）

- `~/.ansible.cfg`（在主目录中）

- `/etc/ansible/ansible.cfg`

  

可以使用`ansible-config list`指令显示当前配置

  

## 构建,清单

  

构建清单(build inventory)是存放受控节点的系统信息和网络位置的文件

  

可以使用 `INI` 文件或 `YAML` 创建清单,对于少量节点推荐使用`ini`格式,对于多节点使用`yaml`

  

```

# ini格式

# vim inventory.ini

[myhosts]

192.168.163.81

192.168.163.82

192.168.163.83

```

  

可以使用`ansible-inventory`命令验证清单

  

```

newuser@ubuntu:~/ansible_start$ ansible-inventory -i inventory.ini --list

{

"_meta": {

"hostvars": {}

},

"all": {

"children": [

"ungrouped",

"myhosts"

]

},

"myhosts": {

"hosts": [

"192.168.163.81",

"192.168.163.82",

"192.168.163.83"

]

}

}

  

# --list参数也可以换成--graph

newuser@ubuntu:~/ansible_start$ ansible-inventory -i inventory.ini --graph

@all:

|--@ungrouped:

|--@myhosts:

| |--192.168.163.81

| |--192.168.163.82

| |--192.168.163.83

```

  

```

# yaml格式

newuser@ubuntu:~/ansible_start$ cat inven.yaml

myhosts:

hosts:

my_host_01:

ansible_host: 192.168.163.81

my_host_02:

ansible_host: 192.168.163.82

my_host_03:

ansible_host: 192.168.163.83

newuser@ubuntu:~/ansible_start$ ansible-inventory -i inven.yaml --list

{

"_meta": {

"hostvars": {

"my_host_01": {

"ansible_host": "192.168.163.81"

},

"my_host_02": {

"ansible_host": "192.168.163.82"

},

"my_host_03": {

"ansible_host": "192.168.163.83"

}

}

},

"all": {

"children": [

"ungrouped",

"myhosts"

]

},

"myhosts": {

"hosts": [

"my_host_01",

"my_host_02",

"my_host_03"

]

}

}

```

  

### bianliaNg a,., 22 ()

  

变量设置受管节点的值，例如 IP 地址、FQDN(完全限定域名)、操作系统和 SSH 用户，因此您无需在运行 Ansible 命令时传递它们。

  

变量可以应用于特定主机。

  

```

webservers:

hosts:

webserver01:

ansible_host: 192.0.2.140

http_port: 80

webserver02:

ansible_host: 192.0.2.150

http_port: 443

```

  

```

# 使用别名来管理客户端

[webs]

web01 ansible_ssh_host=10.0.0.7 ansible_ssh_port=22

web02 ansible_ssh_host=10.0.0.8

```

  

变量也可以应用于组中的所有主机。

  

```

webservers:

hosts:

webserver01:

ansible_host: 192.0.2.140

http_port: 80

webserver02:

ansible_host: 192.0.2.150

http_port: 443

vars:

ansible_user: my_server_user

```

  

```

#方式一、主机组变量+主机+密码

[db_group]

db01 ansible_ssh_host=10.0.0.51

db02 ansible_ssh_host=10.0.0.52

[db_group:vars]

ansible_ssh_pass='1'

  

#方式二、主机组变量+主机+密钥

[web_group]

web01 ansible_ssh_host=10.0.0.7

web02 ansible_ssh_host=10.0.0.8

```

  

### 元组

  

还可以使用`元组`来组织清单中的多个组

  

```

metagroupname:

children:

```

  

例如下例中的`webserver`元组

  

```

newuser@ubuntu:~/ansible_start$ cat inventory.yaml

db:

hosts:

db01:

ansible_host: 192.168.163.81

db02:

ansible_host: 192.168.163.82

web:

hosts:

web01:

ansible_host: 192.168.163.83

webserver:

children:

db:

web:

  

newuser@ubuntu:~/ansible_start$ ansible-inventory -i inventory.yaml --list

{

"_meta": {

"hostvars": {

"db01": {

"ansible_host": "192.168.163.81"

},

"db02": {

"ansible_host": "192.168.163.82"

},

"web01": {

"ansible_host": "192.168.163.83"

}

}

},

"all": {

"children": [

"ungrouped",

"webserver"

]

},

"db": {

"hosts": [

"db01",

"db02"

]

},

"web": {

"hosts": [

"web01"

]

},

"webserver": {

"children": [

"db",

"web"

]

}

}

```

  

```

vim hosts

[db_group]

db01 ansible_ssh_host=10.0.0.51

db02 ansible_ssh_host=10.0.0.52

  

[web_group]

web01 ansible_ssh_host=10.0.0.7

web02 ansible_ssh_host=10.0.0.8

  

[lnmp:children]

db_group

web_group

  

# -m 指定使用的模块名称

newuser@ubuntu:~/ansible_start$ ansible lnmp -m ping -i hosts --list-hosts

hosts (4):

db01

db02

web01

web02

```

  
  
  

## 剧本

  

剧本(playbook)是以`yaml`格式编写的自动化蓝图,ansible利用它在受控节点上执行部署和配置操作

  

- 剧本(playbook): 由多个"场景"(play)组成的有序列表，Ansible从上至下执行这些场景以实现整体目标。

- 场景(play): 与清单(inventory)中受管节点映射的有序任务(task)列表,定义任务执行的角色

- 任务(task): 对单个模块(module)的引用,定义ansible执行的具体操作,定义具体的任务

- 模块(module): 在受控节点上执行的代码单元(脚本或二进制文件),ansible模块以集合(collection)形式组织,每个模块拥有完全限定集合名称(FQCN)