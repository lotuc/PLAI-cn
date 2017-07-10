# 4 初识语法糖

> 语法糖的概念这条微博讲的比较清晰： [寒冬winter的微博](http://weibo.com/1196343093/EmrdvbRDX)

## 4.1 扩展：添加双目减法操作

我们来给写好的解释器添加减法。由于我们的语言已经包含了数、加法和乘法，用这些操作就可以定义减法了：

```text
a - b = a + -1 × b
```

好的，这很简单！但是我们要怎样将它变成可运行的代码呢。首先，我们面临一个决定，将减法操作符放在哪？将其像其它两个操作符一样处理，在现有的 ArithC 数据类型中添加一条规则？——这种想法很诱人。

想一下：通过修改 ArithC 的这种做法有什么不好的地方呢？

这会导致几个问题：

* 首先，显然地，我们将需要修改所有处理了 ArithC 的代码。就目前而言，还很简单，只涉及到了我们的 parser 和 解释器。但是如果在一个更为复杂的语言中，修改这种基本的数据结构会导致大量代码的修改。
* 其次，要添加的结构是可以用已实现的语法结构定义的，去修改已有数据结构的方式让人觉得代码不够模块化。最后一点是修改 ArithC 这种行为让人感觉比较微妙，它有概念上的错误。因为 ArithC 是我们语言的核心部分。而减法 更应该是用户交互的部分，表层语言，添加它是为了让减法更容易使用，而不是添加了一个新的语言特性。

因此，我们尝试定义一个新的数据类型来反应我们的表层语言语法结构：

```racket
(define-type ArithS
  [numS (n : number)]
  [plusS (l : ArithS) (r : ArithS)]
  [bminusS (l : ArithS) (r : ArithS)]
  [multS (l : ArithS) (r : ArithS)])
```

它和 ArithC 看起来基本相同，遵从了相似的递归结构。

有了这个数据结构，我们需要做两件事。

修改 parser 去构造 `ArithS` （而不是 `ArithC` ）；实现 desugar 函数将 `ArithS` 转换成 `ArithC` 。

`desugar` 代码其实是比较容易的：

```racket
(define (desugar [as : ArithS]) : ArithC
  (type-case ArithS as
             [numS (n) (numC n)]
             [plusS (l r) (plusC (desugar l)
                                 (desugar r))]
             [multS (l r) (multC (desugar l)
                                 (desugar r))]
             [bminusS (l r) (plusC (desugar l)
                                   (multC (numC -1) (desugar r)))]))
```

>️注意上面代码，常见错误是忘了递归的对 `l` 和 `r` 进行 desugar 操作。

对代码的解析，读者可以仿照前面解析得到 `ArithC` 的代码书写。下面贴出这部分完整代码：

```racket
#lang plai-typed

(define-type ArithC
  [numC (n : number)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])

(define-type ArithS
  [numS (n : number)]
  [plusS (l : ArithS) (r : ArithS)]
  [bminusS (l : ArithS) (r : ArithS)]
  [multS (l : ArithS) (r : ArithS)])

(define (desugar [as : ArithS]) : ArithC
  (type-case ArithS as
    [numS (n) (numC n)]
    [plusS (l r) (plusC (desugar l)
                        (desugar r))]
    [multS (l r) (multC (desugar l)
                        (desugar r))]
    [bminusS (l r) (plusC (desugar l)
                          (multC (numC -1) (desugar r)))]))

(define (parse [s : s-expression]) : ArithS
  (cond
    [(s-exp-number? s) (numS (s-exp->number s))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (case (s-exp->symbol (first sl))
         [(+) (plusS (parse (second sl)) (parse (third sl)))]
         [(*) (multS (parse (second sl)) (parse (third sl)))]
         [(-) (bminusS (parse (second sl)) (parse (third sl)))]
         [else (error 'parse "invalid list input")]))]
    [else (error 'parse "invalid input")]))

(define (interp [a : ArithC]) : number
  (type-case ArithC a
    [numC (n) n]
    [plusC (l r) (+ (interp l) (interp r))]
    [multC (l r) (* (interp l) (interp r))]))

(interp (desugar (parse (read))))
```


## 4.2 扩展：取负数操作（unary negation）

下面考虑一个新的扩展语法，取负数操作。它使得你需要对 parser 进行一定修整，当你读到 `-` 符号时，你需要往前读（look ahead）以判断它是减法还是取负操作。这不是最有趣的部分！

实现取负操作可以有几种语法糖。很自然的我们会想到：

```text
-b = 0 - b
```

或者还可以这样：

```text
-b = 0 + -1 × b
```

你觉得这两种中哪个更好呢？为什么？

大家可能希望使用第一种方式，因为它看起来更为简单。使用该方式，首先扩展 `ArithS` 数据类型，添加一个取负的规则：

```racket
[uminusS (e : ArithS)]
```

对应 desugar 的实现也很直接：

```racket
[(uminusS (e) (desugar (bminusS (numS 0) e)))]
```

检查看有没有类型错误。上面的式子是对的。要注意不要 desugar 表达式 e 了， `bminusS` 接受的两个参数都是 `ArithS` 而 `e` 已经是 `ArithS` 类型了。这种将输入形式递归地嵌入到其它形式中是 desugaring 工具一种常见模式；它被称为 macro （这里的 macro 就是 `umiunsS` 的定义）。

然而该定义存在两个问题：

首先，该递归是 generative 的，我们得对其进行特别关注。我们可能会希望使用下面这种方式来重写它：

```racket
[uminusS (e) (bminusS (numS 0) (desugar e))]
```

它确实消除了 generativity 。

> 如果你没听过 generative 递归，可以阅读 HTDP 的[这一节](http://www.ccs.neu.edu/home/matthias/HtDP2e/part_five.html)。简单来说，generative 递归过程，递归调用的输入为函数完整的输入而不是一个子问题。

>️注意：很不幸的是，上面的转换有问题，试着找出问题吧，找不出的话，运行一下试试。

第二个问题是，它依赖于 `bminusS` 的意义，如果 `bminusS` 的意义发生变化，我们的 `bminusS` 意义也就发生了变化。

你可能会说，减法的意义不可能发生改变；但并不是这样的，它的实现可能会改变。例如，开发者决定为减法操作打印日志。

很幸运，这个例子我们还可以使用下面这种展开：

```text
-b = -1 × b
```
