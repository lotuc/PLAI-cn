# 3 解释器初窥

现在有了程序的表示方法，我们有很多方式可以用来操纵它们。我们可能想把程序打印的漂
亮点（pretty-print），将其转换成其它格式的代码（编译），查看其是否符合特定属性（
校验），等等。现在，我们专注于考虑得到其对应的值——计算（evaluation）——将程序规约
成值。

让我们来为我们的算术语言写个**解释器**形式的求值器。选择算术运算是出于下面三个主
要原因：（a）你已经知道怎么计算加减乘除了，我们可以专注于其实现；（b）基本上每门
语言都会包含算术运算，所以我们可以从它开始进行语言的扩展；（c）该问题大小合适，
足以展示我们要学习的很多要点。

## 3.1 算术表达式的表示

我们首先需要统一算术表达式的表示法。我们只打算支持两个运算符——加法和乘法——以及基
本的数。需要一种东西来表达算术**表达式**。算术表达式的嵌套规则是啥呢？表达式可以
任意地嵌套。

**思考题**

> 为什么我们不把除法也包括进来呢？这么做对前文总结会产生什么影响？

这里不包括除法的原因是，我们暂时不打算讨论什么表达式是合法的。显然 1 除以 2 是合
法的，但是 1 除以 0 就有争议了。1 除以（1 减去 1）就更有争议了。目前我们无需陷入
这种矛盾，以后再讨论。

于是我们可以使用如下的表达式：

```racket
(define-type ArithC  ; 具体算术
  [numC (n : number)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])
```

## 3.2 写个解释器

下面开始写该算术语言的解释器。首先我们考虑一下该解释器的类型：它的输入显然
是`ArithC`值，返回值的类型呢？当然是数啦。即我们的解释器是输入为`ArithC`输出为数
的函数。

**练习**

> 为该解释器写一些测试案例。

由于输入类型是递归定义的数据类型，很自然的解释器也应该递归地处理输入。程序模板如
下：【注释】

```racket
(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) ...]
             [multC (l r) ...]))
```

> 《程序设计方法》一书（又译《如何设计程序》）详细介绍了模板这一概念。

你很可能想当然的直接写出如下的代码：

```racket
(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) (+ l r)]
             [multC (l r) (* l r)]))
```

**思考题**

> 你能找到其中的错误吗？

首先，我们先补充模板代码：

```racket
(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) ... (interp l) ... (interp r) ...]
             [multC (l r) ... (interp l) ... (interp r) ...]))
```

填充必要部分得到解释器：

```racket
(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) (+ (interp l) (interp r))]
             [multC (l r) (* (interp l) (interp r))]))
```

这样，我们就完成了第一个解释器！我知道有点虎头蛇尾，但是我保证，它会变得越来越复
杂。

## 3.3 你注意到了吗？

有件事情我没和你讲清楚：

**思考题**

> 在这个语言中，加法和乘法的“意义”是啥？

太抽象了，不是吗？让我们把它变得更具体一些。计算机中有很多种不同的加法：

- 首先，有很多种不同的数：固定长度（例如，32 位）整数，带符号固定长度（例如，31
  位外加 1 个符号位）整数，任意精度整数；在有些语言中，有理数；各种不同格式的固
  定位数浮点数；在有些语言中，复数；如此等等。在确定数类型之后，加法可能只支持其
  中的一部分组合。

- 其次，某些语言支持某些（其他）数据类型的加法，比如矩阵加法。

- 再次，某些语言支持字符串“相加”。这里引号表示我们并没有进行数学上相加的操作，而
  是用语法上用+符号表示操作。有的语言用这表示字符串拼接；也有语言在这种情况下返
  回数（比如把字符串所表示的数相加）。

这些都是加法所代表的不同含义。**语义**是把语法（例如+）映射到含义（例如，以上列
举的部分或者所有）。

**于是游戏来了：以下哪些是相同的？**

- 1 + 2

- 1 + 2

- ’1’ + ’2’

- ’1’ + ’2’

回到之前的问题，我们用的语义是啥？我们直接使用了 Racket 所提供的语义，因为程序直
接把+映射到了 Racket 的+上。其实这也不一定是对的：比如说，如果 Racket 的`+`也支
持字符串，那么我们这里提供的操作就限制+只能用在数上（事实上 Racket 的`+`并不支持
字符串）。

如果我们想要不同的语义，需要显式的实现出来。

**练习**

> 需要哪些修改，这里的加法能支持带符号 32 位数的算术?

一般来说，我们需要避免简单的借用宿主语言的语义。后面我们还会讨论这个话题。

## 3.4 扩展此语言

我们选择的第一个语言功能非常有限，于是有很多种方式可以将其扩展。有的扩展，比如添
加数据结构和函数，就必须要增加解释器所支持的数据类型（假设我们并不打算采用哥德尔
计数法）。其他的扩展，比如增加更多算术操作，就不必修改核心语言及其解释器。我
们[下一章](./chap04.md)就讨论此问题。
