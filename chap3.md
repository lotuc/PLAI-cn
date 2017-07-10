# 3 解释器初窥

现在有了程序的表示，我们有很多方式可以用来操纵它们。我们可能想把程序打印的漂亮点（pretty-print），将其转换成其它格式的代码（编译），查看其是否符合特定属性（校验），等。现在，我们专注于考虑得到其对应的值——计算（evaluation）——将程序规约成值。

现在来为我们的算术语言写个解释器形式的求值器。选择算术运算是出于下面三个主要原因：

你已经知道怎么计算加减乘除了，我们可以专注于其实现；基本上每门语言都会包含算术运算，所以我们可以从它开始进行语言的扩展；该问题很简单，但是可以扩展出复杂的情况以展示我们要展示的观点。


## 3.1 算术表达式的表示

我们首先确认一下要使用的算术表达式的表示。现在我们只支持两个运算符——加法和乘法——而且是针对自然数的。

```Racket
(define-type ArithC
  [numC (n : number)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])
```

## 3.2 写个解释器

下面开始写该算术语言的解释器。首先我们考虑一下该解释器的类型：它的输入显然是 `ArithC` 值，返回值的类型呢？ 当然是数啦。即我们的解释器是一个输入为 `ArithC` 输出为数的函数。

由于输入类型是一个递归定义的数据类型，我们可以很自然的在解释器进行对其进行递归的解释。形如：

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
             [multC (l r) (+ l r)]))
```

略微观察就能发现其错误。显然解释器代码应该形似下面这样（由于 `l` 和 `r` 都是 `ArithC` 类型的需要被解释）：

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

这样，我们就完成了第一个解释器。
