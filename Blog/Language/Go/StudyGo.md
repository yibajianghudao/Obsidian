---
weight: 100
title: StudyGo
slug: studygo
summary: StudyGo
draft: false
author: jianghudao
tags:
isCJKLanguage: true
date: 2026-03-11T17:43:05+08:00
lastmod: 2026-03-13T16:49:44+08:00
---

## 不要使用指针判断空值和零值

Go 指针常用于区分已被赋予零值的变量或字段，和完全未被赋值的变量或字段,例如,可能会有代码这样写:

```go
func main() {
	var nojoin = []int{1, 2, 16}

	var users = []int{1, 2, 3, 10, 16}
	for _, u := range users {

		s := getScore(u, nojoin)
		if s == nil {
			fmt.Println(u, "not join, vaule is nil.")
		} else {
			fmt.Println(u, "vaule is ", *s)
		}
	}
}
func getScore(userId int, nojoin []int) *int {
	if slices.Contains(nojoin, userId) {
		return nil
	}
	s := 0
	return &s
}
```

这种情况下如果忘记判断返回值是否为 `nil`,则会直接导致 `panic`

更好的做法是使用 `comma ok` 的写法:

```go
func main() {
	var nojoin = []int{1, 2, 16}

	var users = []int{1, 2, 3, 10, 16}
	for _, u := range users {

		s, ok := getScore(u, nojoin)
		if !ok {
			fmt.Println(u, "not join, vaule is nil.")
		}
		fmt.Println(u, "vaule is ", s)
	}
}
func getScore(userId int, nojoin []int) (int, bool) {
	if slices.Contains(nojoin, userId) {
		return 0, false
	}
	return 0, true
}
```

### 优先返回结构体而不是结构体的指针

如果需要在函数内部创建一个结构体并返回,返回结构体比返回它的指针拥有更好的性能,参考 [Go functions: returning structs vs pointers](https://macias.info/entry/201802102230_go_values_vs_references.md)

如果需要修改一个已有结构体的值,传递和返回结构体的指针

## 方法

### 定义

go 语言的方法声明比函数声明多了一个 " 接收者 ":

```go
type Person struct {
	FirstName string
	LastName string
	Age int
}

func (p Person) String () string {

}
```

在其它语言中经常使用 `this` 或 `self` 指代自身,而在 go 语言中通常使用类型名字的首字母.
