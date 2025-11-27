---
weight: 100  
title: Hugo_Lotusdocs  
slug: hugo-lotusdocs  
description:  
draft: false  
author: jianghudao  
tags:  
isCJKLanguage: true  
date: 2025-11-20T09:16:20+08:00  
lastmod: 2025-11-24T11:35:33+08:00
---
~~打算把文章从hexo框架迁移到hugo框架,使用lotusdocs主题,本地使用Obsidian编辑~~  
迁移失败,现在使用hugo+[relearn](https://github.com/McShelby/hugo-theme-relearn)主题
## 安装  
### 安装hugo  
参考[Install Hugo on Linux](https://gohugo.io/installation/linux/)  
### 安装lotusdocs  
参考[How to deploy Lotus Docs on GitHub Pages](https://lotusdocs.dev/docs/deployment/platforms/github-pages/)  
注意该教程漏写了一步  
```  
hugo mod tidy  
```  
在编辑`hugo.toml`之后,`hugo new docs/example-page.md`之前.参考这个[issue](https://github.com/colinwilson/lotusdocs/issues/220)  
## 配置  
存在两个文件夹:  
- git仓库,我这里是`~/Code/yibajianghudao.github.io`  
- Obsidian文档目录,我这里是`/home/mintuser/Code/obsidian`,用于本地使用Obsidian编辑文章  
整体思路:  
1. 创建完仓库后,在Obsidian应用中打开该Obsidian文档目录,新建一个`docs`目录,在其中编写文章  
2. 通过`~/Code/obsidian/copy.sh`脚步将`~/Code/obsidian/docs`目录下的所有文章复制到~/Code/yibajianghudao.github.io/content/docs`并推送到远程仓库  
### Obsidian配置  
安装的插件:  
- [Templater](https://github.com/SilentVoid13/Templater),用于自定义模板  
- [Linter](https://github.com/platers/obsidian-linter),用于自动更新文章修改时间  
#### 模板  
通过模板可以配置文章的`front matter`,包括:  
- `hugo`框架需要的配置,例如`weight`,`title`,`draft`  
- `lotusdocs`主题需要的配置,例如目录下的`_index.md`文件的`icon`,`title`(使用所在最后一级目录名)  
首先需要在 设置-核心插件 中禁用自带的模板插件,安装第三方`Templater`插件  
在`~/Code/obsidian/Template`新建模板文件:  
index.md:  
``` yaml  
---
weight: 100  
title: "<% (tp.file.folder() ? tp.file.folder().split('/').pop() : tp.file.title) %>"  
description: <% tp.file.cursor() %>  
icon: article  
date: <% tp.date.now("YYYY-MM-DD[T]HH:mm:ssZ") %>  
draft: false  
toc: true  
lastmod: <% tp.date.now("YYYY-MM-DD[T]HH:mm:ssZ") %>  
---
```  
post.md:  
```yaml  
---
weight: 200  
title: <% tp.file.title %>  
description: <% tp.file.cursor() %>  
icon: menu_book  
lead: ""  
date: <% tp.date.now("YYYY-MM-DD[T]HH:mm:ssZ") %>  
lastmod: <% tp.date.now("YYYY-MM-DD[T]HH:mm:ssZ") %>  
draft: false  
images: []  
---
```  
在创建文章文件之后,在左侧的功能区点击`templater`,选择`post`即可  
在创建目录之后,首先创建一个命名为`_index`的文章,然后同样选择`index`模板即可,参考[Auto-Generated Menu](https://lotusdocs.dev/docs/quickstart/#auto-generated-menu)  
## 参考  
[My Obsidian + Hugo blogging setup](https://4rkal.com/posts/obsidianhugo/)