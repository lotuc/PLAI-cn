# 3 解释器初窥

现在有了程序的表示，我们有很多方式可以用来操纵它们。我们可能想把程序打印的漂亮点（pretty-print），将其转换成其它格式的代码（编译），查看其是否符合特定属性（校验），等。现在，我们专注于考虑得到其对应的值——计算（evaluation）——将程序规约成值。

现在来为我们的算术语言写个解释器形式的求值器。选择算术运算是出于下面三个主要原因：

你已经知道怎么计算加减乘除了，我们可以专注于其实现；基本上每门语言都会包含算术运算，所以我们可以从它开始进行语言的扩展；该问题很简单，但是可以扩展出复杂的情况以展示我们要展示的观点。


## 3.1 算术表达式的表示

我们首先确认一下要使用的算术表达式的表示。现在我们只支持两个运算符——加法和乘法——以及基本的数字。首先需要一种东西来表达算术表达式，那么规则是啥呢？表达式可以任意嵌套。

__思考题__

> 为什么我们不把除法也包括进来呢？这么做对前文总结会产生什么影响？

这里不包括除法的原因是，我们暂时不打算讨论什么表达式是合法的。显然1除以2是合法的，但是1除以0就有争议了。1除以（1减去1）就更有争议了。目前我们不需要陷入这种矛盾，以后再讨论。

于是我们可以使用如下的表达式：

```racket
(define-type ArithC
  [numC (n : number)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])
```

## 3.2 写个解释器

下面开始写该算术语言的解释器。首先我们考虑一下该解释器的类型：它的输入显然是 `ArithC` 值，返回值的类型呢？ 当然是数啦。即我们的解释器是一个输入为 `ArithC` 输出为数的函数。

__习题__

> 为该解释器写一些测试案例。

由于输入类型是一个递归定义的数据类型，很自然的解释器也应该递归地处理输入。形如：

```racket
(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) ...]
             [multC (l r) ...]))
```

你很可能想当然的直接写出下面的代码：

```racket
(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) (+ l r)]
             [multC (l r) (* l r)]))
```

__思考题__

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

下面是完整代码：

```racket
#lang plai-typed

(define-type ArithC
  [numC (n : number)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])

(define (parse [s : s-expression])
  (cond
    [(s-exp-number? s) (numC (s-exp->number s))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (case (s-exp->symbol (first sl))
         [(+) (plusC (parse (second sl)) (parse (third sl)))]
         [(*) (multC (parse (second sl)) (parse (third sl)))]
         [else (error 'parse "invalid list input")]))]
    [else (error 'parse "invalid input")]))

(define (interp [a : ArithC]) : number
  (type-case ArithC a
             [numC (n) n]
             [plusC (l r) (+ (interp l) (interp r))]
             [multC (l r) (* (interp l) (interp r))]))

(interp (parse (read)))
```

这样，我们就完成了第一个解释器。我知道很简单，但是我保证，它会变得越来越复杂。

## 3.3 你注意到了吗？

有件事情我没和你讲清楚：

__思考题__

> 在这个语言中，加法和乘法的“意义”是啥？

太抽象了，不是吗？让我们把它变得更具体一些。计算机中有很多种不同的加法：

+ 首先，有很多种不同的数字：固定长度（例如，32位）整数，带符号固定长度（例如，31位外加1个符号位）整数，任意精度整数；在有些语言中，有理数；各种不同格式的固定位数浮点数；在有些语言中，复数；如此等等。在确定数字类型之后，加法可能只支持其中的一部分组合。

+ 其次，某些语言支持某些（其他）数据类型的加法，比如矩阵加法。

+ 再次，某些语言支持字符串“相加”。这里引号表示我们并没有进行数学上相加的操作，而是用语法上用+符号表示操作。有的语言用这表示字符串拼接；也有语言在这种情况下返回数字（比如把字符串所表示的数字相加）。

这些都是加法所代表的不同含义。_语义_ 是把语法（例如+）映射到含义（例如，以上列举的部分或者所有）。

__于是游戏来了：以下哪些是相同的？__

+ 1 + 2

+ 1 + 2

+ ’1’ + ’2’

+ ’1’ + ’2’

回到之前的问题，我们用的语义是啥？我们直接使用了Racket所提供的语义，因为程序直接把+映射到了Racket的+上。其实这也不一定是对的：比如说，如果Racket的+也支持字符串，那么我们这里提供的操作就限制+只能用在数字上（事实上Racket的+并不支持字符串）。

如果我们想要不同的语义，需要显式的实现出来。

__习题__

> 需要哪些修改，这里的加法能支持带符号32位数的算术?

一般来说，我们需要避免简单的借用宿主语言的语义。后面我们还会讨论这个话题。

## 3.4 扩展此语言

我们选择的第一个语言功能非常有限，于是有很多种方式可以将其扩展。有的扩展，比如添加数据结构和函数，就必须要增加解释器所支持的数据类型（假设我们并不打算采用哥德尔计数法）。其他的扩展，比如增加更多算术操作，就不必修改核心语言及其解释器。我们下一章就讨论此问题。
