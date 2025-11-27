<%*
// 中文转换函数
function slugify(str) {
  return str
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[\s\_]+/g, '-')
    .replace(/[^\w\u4e00-\u9fa5-]/g, '')
    .replace(/^-+|-+$/g, '');
}

const newFileName = await tp.system.prompt("Enter a name for this file:");
let finalTitle = tp.file.title;

// 如果输入了新文件名，就重命名文件
if (newFileName && newFileName.trim() !== "") {
  await tp.file.rename(newFileName);
  finalTitle = newFileName;
}

// 判断是否为 _index
const isIndex = finalTitle === "_index";

// 生成 slug
const slug = slugify(finalTitle);

// 获取当前文件夹名（用于 _index 的 title）
const folder = tp.file.folder();
const folderName = folder ? folder.split("/").pop() : finalTitle;

if (isIndex) {
  // _index 用的 front matter 和内容
  tR += `---
title: "${folderName}"
type: chapter
weight: 50
---

{{% children type="list" description=true %}}
`;
} else {
  // 非 _index 用的 front matter 和内容
  tR += `---
weight: 100
title: "${finalTitle}"
slug: "${slug}"
description: ${tp.file.cursor()}
draft: false
author: jianghudao
tags:
isCJKLanguage: true
---

`;
}
%>
