---
weight: 100
title: git
slug: git
summary: 
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2025-11-27T10:21:00+08:00
lastmod: 2026-01-15T14:17:58+08:00
---
## upstream
在使用git时遇到这样的场景：  
我发现了[远程仓库](https://github.com/jaywcjlove/linux-command)的`groupmod`命令描述不准确，然后就准备修改它，经过了一下步骤：  
1. Fork的一个分支到[我的仓库](https://github.com/yibajianghudao/linux-command)
2. 本地`git clone`、修改、`git commit`、`git push`
3. 提交了一个[PR](https://github.com/jaywcjlove/linux-command/pull/676)

这时我想要再解决一下这个[issue](https://github.com/jaywcjlove/linux-command/issues/640)  
此时我的PR还没有被merge，而我在修改之前忘记了`git branch`新建一个分支，导致我现在的master已经是修改后的版本，现在我想要重新提一个PR就需要重新获得一个干净的远程分支，而且此时远程分支已经merge了一个新的[PR](https://github.com/jaywcjlove/linux-command/pull/675)，我的本地master分支已经不是最新的了。  
我现在可以新建一个分支，然后把master分支通过`git rebase`重置到远程仓库，然后重新修改。也可以直接使用`upstream`从远程仓库获得一个干净的分支：
### 使用upstream
当前的状态：
```
$ git remote -v
origin	git@github.com:yibajianghudao/linux-command.git (fetch)
origin	git@github.com:yibajianghudao/linux-command.git (push)
```
添加一个`upstream`：
```
$ git remote add upstream https://github.com/jaywcjlove/linux-command.git
```
再次查看当前的状态：
```
$ git remote -v
origin	git@github.com:yibajianghudao/linux-command.git (fetch)
origin	git@github.com:yibajianghudao/linux-command.git (push)
upstream	https://github.com/jaywcjlove/linux-command.git (fetch)
upstream	https://github.com/jaywcjlove/linux-command.git (push)
```
> 这里使用https是因为仓库比较大，使用ssh速度比较慢
同步upstream到本地：
```
$ git fetch upstream
```
新建并切换到分支：
```
$ git checkout -b issue-640 upstream/master
branch 'issue-640' set up to track 'upstream/master'.
Switched to a new branch 'issue-640'
```
修改upstream为ssh：
```
$ git remote set-url upstream git@github.com:jaywcjlove/linux-command.git
```
修改完之后将代码推送到`origin`而不是`upstream`，直接推送到`upsteam`可能会导致权限问题，应该首先推送到自己的fork仓库的新分支，然后重新请求一个PR
```
# 推送到fork仓库新的issue-640分支
$ git push origin issue-640
```