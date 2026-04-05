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
lastmod: 2026-03-18T10:23:25+08:00
---

## 指针

### 不要使用指针判断空值和零值

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

### 值接收者和指针接收者

定义方法的时候,接收者可以是值,也可以是指针:

```go
func (p Person) String () string {

}

func (p *Person) String () string {

}
```

- 如果方法修改了接收者,则使用指针接收者
- 需要处理 `nil` 实例,则使用指针接收者
- 如果方法不会修改接收者,则可以使用值接收者

```go
type Counter struct {
	total       int
	lastUpdated time.Time
}

func (c *Counter) Increment() {
	c.total++
	c.lastUpdated = time.Now()
}

func (c Counter) String() string {
	return fmt.Sprintf("total: %d, last updtaed time: %v", c.total, c.lastUpdated)
}

func main() {
	c := Counter{
		total:       1,
		lastUpdated: time.Now(),
	}
	fmt.Println(c.String())
	(&c).Increment()
	fmt.Println(c.String())
}
```

上面的代码声明了 Counter 类型的两个方法,其中 `Increment` 方法因为要修改接收者的属性,所以使用了指针接收者,而在 `main` 函数中调用时使用了值的指针

实际上 go 语言有一个 " 语法糖 ",当你在调用方法时使用指针接收者并且本地变量是值类型时,Go 会自动获取本地变量的地址,反之也一样.因此下面的代码也是可以正常运行的:

```go
func main() {
	c := Counter{
		total:       1,
		lastUpdated: time.Now(),
	}
	fmt.Println((&c).String())
	c.Increment()
	fmt.Println((&c).String())
}
```

> 这样完全相反的使用在逻辑上是错误的,会降低代码可读性

> 对于是否为一个不修改接收者的方法使用值接收者，取决于该类型上声明的其他方法。当一个类型有任何指针接收者方法时，通常的做法是**保持一致**，**对所有方法都使用指针接收者**，即使是那些不修改接收者的方法。

向函数传递值的规则仍然适用,如果你给一个函数传递值类型,并在值类型上调用指针接收者方法,那么实际上是在值的副本上调用该方法:

```go
func main() {
	var c1 Counter
	doUpdataValue(c1)
	fmt.Println("in main:", c1.String())
	doUpdataPonit(&c1)
	fmt.Println("in main:", c1.String())

}
func doUpdataValue(c Counter) {
	c.Increment()
	fmt.Println("in doUpdateValue:", c.String())
}
// 传递给函数的时候需要指定是指针
func doUpdataPonit(c *Counter) {
	c.Increment()
	fmt.Println("in doUpdatePoint:", c.String())
}
```

运行结果:

```bash
$ go run main.go
in doUpdateValue: total: 1, last updtaed time: 2026-03-14 10:12:15.502990526 +0800 CST m=+0.000110355
# 更新失败,total和lastUpdated都是0值
in main: total: 0, last updtaed time: 0001-01-01 00:00:00 +0000 UTC

in doUpdatePoint: total: 1, last updtaed time: 2026-03-14 10:12:15.50300042 +0800 CST m=+0.000120249
in main: total: 1, last updtaed time: 2026-03-14 10:12:15.50300042 +0800 CST m=+0.000120249
```

下面的代码也表明实际上值传递是传递了一个副本:

```go
func main() {
	var c1 Counter
	fmt.Printf("in main c1's address:%p\n", &c1)
	doUpdataValue(c1)
	doUpdataPonit(&c1)
}
func doUpdataValue(c Counter) {
	c.Increment()
	fmt.Printf("in doUpdateValue, c's address: %p\n", &c)
}
func doUpdataPonit(c *Counter) {
	c.Increment()
	fmt.Printf("in doUpdatePoint, c's address: %p\n", c)
}
```

运行结果如下:

```bash
$ go run main.go 
in main c1's address:0xc0000c0060
in doUpdateValue, c's address: 0xc0000c0080
in doUpdatePoint, c's address: 0xc0000c0060
```

### 方法集

实际上 Go 语言的**指针实例的方法集既有指针接收者方法,也有值接收者方法**,但**值实例只有值接收者方法,没有指针接收者方法**,因此上面的代码中:

```go
func doUpdataValue(c Counter) {
	c.Increment()
	fmt.Println("in doUpdateValue:", c.String())
}
```

实际上 `c` 实例根本没有 `Increment` 方法,这同样是一个语法糖,它在编译时被转换为:

```go
func doUpdataValue(c Counter) {
	(&c).Increment()
	fmt.Println("in doUpdateValue:", c.String())
}
```

### 处理 nil 实例

如果在 nil 实例上调用方法,go 会尝试调用而不是直接产生错误,如果方法是值接收者,会直接 `panic`,因为指针没有指向任何值,如果是带有指针接收者的方法,同时编写方法时考虑到了 nil 实例的特殊情况,它是可以正常执行的:

```go
type Logger struct {
	Prefix string
}

func (l *Logger) Print(msg string) {
	if l == nil {
		return
	}
	fmt.Printf("[%s] %s", l.Prefix, msg)
}

type Server struct {
	logger *Logger
	port   int
}

func (s Server) Start() {
	s.logger.Print("Server is start now.\n")
	fmt.Printf("server start at %v\n", s.port)
	s.logger.Print("Server is started.\n")
}

func main() {
	s1 := Server{
		logger: &Logger{Prefix: "DEBUG"},
		port:   8080,
	}
	s1.Start()

	s2 := Server{
		port: 8080,
	}
	s2.Start()
}
```

运行结果如下:

```bash
$ go run .
[DEBUG] Server is start now.
server start at 8080
[DEBUG] Server is started.
server start at 8080
```

尤其要注意的是 `Server` 结构体中的 `logger` 属性必须是指针类型,因为指针类型才可以表示 `nil`,如果换成值类型,那么就算初始化实例时没有传递参数,它依旧会被初始化为零值,例如:

```go
type Server struct {
	logger Logger
	port   int
}
func main() {
	s1 := Server{
		logger: Logger{Prefix: "DEBUG"},
		port:   8080,
	}
	s1.Start()

	s2 := Server{
		port: 8080,
	}
	s2.Start()
}
```

代码的输出如下:

```bash
$ go run .
[DEBUG] Server is start now.
server start at 8080
[DEBUG] Server is started.
[] Server is start now.
server start at 8080
[] Server is started.
```

这是因为 `logger` 的 `Prefix` 属性被初始化为空字符串,`if l == nil` 并没有捕获到它

### 方法和函数

我们可以把实例的方法赋值给变量或传递给需要相同函数类型的参数,这被称为 " 方法值 ":

```go
type Adder struct {
	start int
}

func (a Adder) Addto(val int) int {
	return a.start + val
}

func main() {
	// 常规调用
	adder := Adder{start: 10}
	fmt.Println(adder.Addto(15))

	// 方法值
	addto := adder.Addto
	fmt.Println(addto(15))
}
```

还可以直接从类型的方法创建一个函数,这被称为 " 类型表达式 "

```go
type Adder struct {
	start int
}

func (a Adder) Addto(val int) int {
	return a.start + val
}

func main() {
	// 常规调用
	adder := Adder{start: 10}
	fmt.Println(adder.Addto(15))

	// 方法值
	addto := adder.Addto
	fmt.Println(addto(15))
}
```

方法表达式的第一个参数是这个方法的一个实例

方法还可以传递给需要函数的参数:

```go
func main() {
	adder := Adder{start: 10}
	fmt.Println(DoMath(5, Double))
	fmt.Println(DoMath(10, adder.Addto))
}

func DoMath(val int, operation func(int) int) int {
	return operation(val)
}
func Double(val int) int {
	return val * 2
}
```

- 使用函数: 无状态逻辑,只依赖于输入参数
- 使用结构体存储数据,方法运行逻辑: 有状态逻辑,依赖除输入参数以外的其它数据,例如配置信息),内部可能会改变的状态,缓存,上一次计算的结果等

```go
type DBClient struct {
    connectionURL string
    timeout       int
}

func (db *DBClient) GetUser(id int) string {
    fmt.Printf("连接到 %s，设置超时 %d 秒，正在查询用户 %d…\n", db.connectionURL, db.timeout, id)
    return "UserName"
}

func main() {
    client := &DBClient{
        connectionURL: "192.168.1.100:3306",
        timeout:       5,
    }
    
    client.GetUser(999) 
}
```

## iota

go 语言中使用 `iota` 实现 " 枚举 ",`iota` 是一个常量计数器,它在 `const` 代码块中为一组常量提供递增的数字.

使用 `iota` 很简单,通常使用 `int` 定义一个类型,然后在 `const` 代码块中使用它赋值:

```go
type MailCategory int

const (
    Uncategorized MailCategory = iota // 0
    Personal                          // 1
    Spam                              // 2
    Social                            // 3
    Advertisements                    // 4
)
```

`iota` 的规则如下:

- `iota` 从 `0` 开始,并会在遇到 `const` 块后刷新
- `iota` 在每一行递增,即使这一行没有使用 `iota`
- 如果 `const` 块中定义的常量没有指定类型和赋值,则继承自上一个非空表达式

```go
const (
    Field1 = 0          // 第0行：iota=0，但这里没用iota，显式赋值为 0
    Field2 = 1 + iota   // 第1行：iota=1，计算 1 + 1，结果为 2
    Field3 = 20         // 第2行：iota=2，显式赋值为 20
    Field4              // 第3行：iota=3，隐式复制上一行表达式，结果为 20
    Field5 = iota       // 第4行：iota=4，直接赋值，结果为 4
)
```

因为 `iota` 本质上是 `int` 数字 (一般使用 `int`),因此可以使用位运算符来生成标志位:

```go
type FilePermission int

const (
	Read FilePermission = 1 << iota  // 1
	Write                            // 2
	Execute                          // 4
)
```

使用 `iota` 时要注意其初始值是 `0`,它可以用来定义默认状态,如果没有则可以使用 `_` 跳过它

`iota` 应该仅用于内部逻辑,如果枚举值对应外部系统,数据库或网络状态,则不应该使用 `iota`,如果未来的维护者在 `const` 中新增了一行新的常量,其后的所有值都会被 `+1`,这会引发及其隐蔽的错误.

下面是一个使用 `iota` 设置权限位的示例:

```go 
package main

import (
	"fmt"
	"strings"
)

type FilePermission int

const (
	Read FilePermission = 1 << iota
	Write
	Execute
)

func Grant(current FilePermission, perm FilePermission) FilePermission {
	return current | perm
}
func HasPermission(current FilePermission, perm FilePermission) bool {
	return current&perm == perm
}
func Revoke(current, perm FilePermission) FilePermission {
	return current &^ perm
}

func (p FilePermission) String() string {
	if p == 0 {
		return "None"
	}
	var perms []string

	if p&Read == Read {
		perms = append(perms, "Read")
	}
	if p&Write == Write {
		perms = append(perms, "Write")
	}
	if p&Execute == Execute {
		perms = append(perms, "Execute")
	}

	return strings.Join(perms, "|")
}

func main() {
	var cur FilePermission = Read
	cur = Grant(cur, Write)
	if !HasPermission(cur, Write) {
		panic("error, cur don't have write permission.")
	}
	cur = Revoke(cur, Read)
	if HasPermission(cur, Read) {
		panic("error, cur have read permission.")
	}
	fmt.Println("all test is right!")
	cur = Grant(cur, Read)
	cur = Grant(cur, Execute)
	fmt.Println(cur)
}
```

这段代码的三个函数分别用来 " 增加权限 ", " 验证权限 " 和 " 删除权限 ".其中的逻辑使用了 go 语言的 [位操作符]()

方法 `String` 是用来格式化打印 `FilePermission` 类型,只要类型实现了 `String` 这个接口,`fmt.Println` 就会调用这个方法来打印字符串.

### 组合

go 语言中没有继承,可以使用组合来提升代码的重用功能:

```go
type Employee struct {
	id   string
	name string
}

func (e Employee) Description() string {
	return fmt.Sprintf("%s %s", e.name, e.id)
}

type Manager struct {
	Employee
	Report []Employee
}

func (m Manager) FindNewEmployees() []Employee {
	return []Employee{}
}
```

在 `Manager` 类型中设置了一个 `Employee` 类型的字段,该字段没有分配名称,因此称为 " 内嵌字段 ",在内嵌字段中声明的任何字段和方法都可以被提升到包含的结构体中,并可以直接调用:

```go
func main() {
	m := Manager{
		Employee: Employee{
			name: "Bob",
			id:   "12345",
		},
		Report: []Employee{},
	}
	fmt.Println(m.name)
	fmt.Println(m.Description())
}
```

## 参考

- 大部分内容参考 "Go 语言学习指南: 惯例模式与编程实践 ([美] 乔恩·博德纳)"
