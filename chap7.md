# 7 Function Anywhere

Scheme 语言修订报告中概述（[r6rs 概述](http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-3.html#node_chap_Temp_3)，[r5rs（中文）](http://www.math.pku.edu.cn/teachers/qiuzy/progtech/scheme/r5rscn.pdf)）中指出该语言如下的设计原则：

> 程序语言的设计不应该是特性的简单堆砌，而应尽量通过设计去消除语言的弱点和缺陷以避免引入新的不必要的特性来改善这些弱点和缺陷。

这是一个无须争辩的设计原则（当然有一些特性有很好的理由被引入一门语言，但是此原则迫使我们去认真思考引入这些特性的种种利弊，而不是把它们当作理所当然的）。下面我们试着遵从该原则来引入函数。

在[章节-添加函数](https://zhuanlan.zhihu.com/p/24720187)中我们没有作太多思考就引入了函数，你可能会说我们是按照 DrRacket 的一个理想化模型引入的函数，即将函数的定义和使用进行分离。下面我们使用 Scheme 的设计原则来重新思考一下这种设计的必要性。

为什么函数的定义不可以作为一个表达式呢？我们现在实现的算术语言中有一个尴尬的问题：“函数的定义表示的是什么值？”，在现有设计中不能给出很好的答案。对于一个真正的语言来说，计算结果当然不可能只有数，所以我们也没必要给该算术语言作出这种限制；跳出这个框框，我们便可以给该出一个很好的回答：“函数值”。下面尝试一下如何实现。

将函数作为值，应该怎么做呢？显然，函数和数不同类的值，你不能对其做加法运算。但是，有一件它显然能做的事：传入参数调用它！因此我们应该允许函数值出现在函数调用的函数那个地方。其行为——显然是调用该函数。按照该想法，我们的语言中应该允许下面的表达式作为合法程序（这里使用方括号方便阅读）：

```scheme
(+ 2 ([define (f x) (* x 3)] 4))
```

计算它得到 `(+ 2 (* 4 3))`，得到 `14`。（注意到没？这里使用了替换的计算模型。）


## 7.1 函数作为表达式和值

首先在我们的核心语言中添加函数定义：

```scheme
(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  <fun-type> ;; 函数值
  <app-type> ;; 函数调用
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)]
  )
```

现在先直接重用之前的函数定义：

```scheme
;; fun-type
  [fdC (name : symbol) (arg : symbol) (body : ExprC)]
```

下面来确定函数定义是什么样的。函数的位置应该放什么呢？我们希望它可以为函数定义，而不是像之前那样只能是函数定义的名字。由于现在函数定义类型和其它表达式（ExprC）类型混在了一起，这里让函数的位置可以放任意表达式吧，但是我们需要记住我们其实只希望它为函数定义：

```scheme
  [appC (fun : ExprC) (arg : ExprC)]
```

有了这个定义后，我们不再需要通过名字查找函数了，所以我们的解释器也可以不用再传入函数定义列表。当然之后有需要我们还可以将预定义函数列表加回来，现在我们探索一下即时函数（immediate function）—— 在函数定义处调用函数。

下面，修改一下解释器 `interp`。需要添加对函数定义的处理，该部分代码大致会是这样：

```scheme
  [fdC (n a b) expr]
```

> 考虑一下：
>
> 解释器中添加了该语句会导致什么？

显然，这是一个爆炸性的改变，解释器不再总是返回数了，于是出现类型错误。

在之前解释器实现过程中，也不时的需要注意其返回值类型，但并没有给我们造成太多困扰，现在，我们需要认真考虑返回值的类型，显然我们需要给返回值增加函数的构造：

```scheme
(define-type Value
  [numV (n : number)]
  [funV (name : symbol) (arg : symbol) (body : ExprC)]
  )
```

我们使用后缀 `V` 表示值（value），如求值的结果。`funV` 部分正对应 `fdC`；`fdC` 为输入，`funV` 为输出。通过区分这两者，我们可以分别修正优化它们两个。

下面我们尝试使用该输出类型重写解释器：

```scheme
(define (interp [expr : ExprC] [env : Env]) : Value
  (type-case ExprC expr
    <interp-body-hof>))
```

同样的，你需要对于环境的数据类型 `Binding` 和辅助函数 `lookup` 做响应修改。

> 自己尝试一下。

解释器主题代码结构还是老样子：

```scheme
# <interp-body-hof>
  [numC (n) (numV n)]
  [idC (n) (lookup n env)]
  <app-case>
  <plus/mult-case>
  <fun-case>
```

对于数，你显然要使用新的值类型构造对其包裹一下。 对于标识符，我们还是直接调用 `lookup` 函数从环境中取出其值。对于加法／乘法，需要进行简单的修改使其能正确的返回 `Value` 类型。

```scheme
# <plus/mult-case>
  [plusC (l r) (num+ (interp l env) (interp r env))]
  [multC (l r) (num* (interp l env) (interp r env))]
```

其中辅助函数 `num+` 和 `num*` 显然是用于实现 `Value` 的加和乘操作的。很简单，那其中一个为例：

```scheme
(define (num+ [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (+ (numV-n l) (numV-n r)))]
    [else
     (error 'num+ "one argument was not a number")]))
```

显然，当有一个参数值类型不为数时，应该抛出一个运行时错误，后面会有章节谈论类型这个主题。

还有两段代码要完成。上面说过，函数值 `funV` 来自 `funC`，按其定义得到：

```scheme
# <fun-case>
  [fdC (n a b) (funV n a b)]
```

于是，我们还剩下函数调用的代码。尽管我们不再需要从函数定义列表中查询函数定义，但是这里还是尽量保留之前函数调用的代码的结构：

```scheme
# <app-case>
    [appC (f arg) (let ([fd f)])  ;; 注意这里
                    (interp (fdC-body fd)
                            (extend-env (bind (fdC-arg fd)
                                              (interp arg env))
                                        mt-env)
                            fds))]
```

这里我们直接引用了 `f` 作为函数定义，注意由于在函数应该出现的位置事实上可能出现任何表达式，我们最好编码检测它是否实是个函数。

> 这是什么意思呢？我们是要检查它是作为语法结构上的函数（即一个 `fdC` 构造），还是只是检查该表达式的计算结果是否是函数值（即 `funV`）呢？想象这两者的区别，找出一个具体的例子来展示区别。

我们面临一个选择：

1. 检查它在语法上是否是个 `fdC` 构造，如果不是，抛出异常。
2. 对其进行求值，然后检查其返回值是否是函数，如果不是，抛出异常。

我们选择后者，它会使得我们的语言更为灵活（显然第二种情况可以覆盖第一种情况， `fdC` 求值的结果就是一个函数值）。于是，修改代码得到：

```scheme
# <app-case>
    [appC (f arg) (let ([fd (interp f env))])  ;; 注意这里
                    (interp (fdC-body fd)
                            (extend-env (bind (funV-arg fd) ;; 这里
                                              (interp arg env))
                                        mt-env)
                            fds))]
```

当然你还要检查解释得到的值 `fd` 是否是函数再执行相应操作，这一步你应该自己去实现，不过这边我（译者）还是把代码放在这边方便阅读。

```scheme
# <app-case>
    [appC (f arg) (let ([fd (interp f env)])
                    (if (funV? fd)
                        (interp (funV-body fd)
                                (extend-env (bind (funV-arg fd)
                                                  (interp arg env))
                                            mt-env)
                                )
                        (error 'interp "Not a function")
                        ))]
```

信或者不信，到此为止，一个可运行的解释器又完成了。

对于那些想运行一下的朋友，最好的方式当然是看了之后自行修改以前的解释器然后把这个调通，但是这里还是把完整代码放在这边：

```scheme
#lang plai-typed

(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  [fdC (name : symbol) (arg : symbol) (body : ExprC)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)])

(define-type Value
  [numV (n : number)]
  [funV (name : symbol) (arg : symbol) (body : ExprC)])

;; 定义环境相关数据结构与操作
(define-type Binding
  [bind (name : symbol) (val : Value)])
(define-type-alias Env (listof Binding))
(define mt-env empty)
(define extend-env cons)

;; 在环境 env 中查找标识符 n 绑定的值
(define (lookup [n : symbol] [env : Env]) : Value
  (cond
    [(= 0 (length env)) (error 'lookup "Can't find binding")]
    [else (let [(b (first env))]
            (if (symbol=? n (bind-name b))
                (bind-val b)
                (lookup n (rest env))))]))

(define (num+ [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (+ (numV-n l) (numV-n r)))]
    [else (error 'num+ "one argument was not number")]))
(define (num* [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (* (numV-n l) (numV-n r)))]
    [else (error 'num+ "one argument was not number")]))

;; 解释器多了一个参数,传入预定义的函数列表
(define (interp [a : ExprC] [env : Env]) : Value
  (type-case ExprC a
    [numC (n) (numV n)]
    [idC (n) (lookup n env)]
    [fdC (n a b) (funV n a b)]
    [appC (f arg) (let ([fd (interp f env)])
                    (if (funV? fd)
                        (interp (funV-body fd)
                                (extend-env (bind (funV-arg fd)
                                                  (interp arg env))
                                            mt-env)
                                )
                        (error 'interp "Not a function")
                        ))]

    [plusC (l r) (num+ (interp l env) (interp r env))]
    [multC (l r) (num* (interp l env) (interp r env))]))

(test (interp (plusC (numC 10) (appC (fdC 'const5 '_ (numC 5)) (numC 10)))
              mt-env)
      (numV 15))
(test/exn (interp (appC (fdC 'f1 'x (appC (fdC 'f2 'y (plusC (idC 'x) (idC 'y)))
                                          (numC 4)))
                        (numC 3))
                  mt-env)
          "Can't find binding")
```

最后添加了两个测试，当然这段代码没有纳入 `parser`，也很简单，这里附上译者的一个粗陋的版本：

```scheme

;; parser
(define (parse [s : s-expression]) : ExprC
  (cond
    [(s-exp-number? s) (numC (s-exp->number s))]
    [(s-exp-symbol? s) (idC (s-exp->symbol s))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (if (s-exp-symbol? (first sl))
           (case (s-exp->symbol (first sl))
             [(+) (plusC (parse (second sl)) (parse (third sl)))]
             [(*) (multC (parse (second sl)) (parse (third sl)))]
             [else (fdC (s-exp->symbol (first sl))
                        (s-exp->symbol (second sl))
                        (parse (third sl)))])
           (appC (parse (first sl))
                         (parse (second sl)))))]))
```

注意最后一个测试，其解释过程会抛出异常，下面一节来解决这个问题。

## 7.2 什么？嵌套？

函数定义的函数体部分可以是任意表达式。而函数定义本身也是一个表达式。
于是函数定义中可以包含一个函数定义···例如：

```scheme
# <嵌套的-fdC>
(fdC 'f1 'x
     (fdC 'f2 'x
          (plusC (idC 'x) (idC 'x))))
```

对其求值还不是特别有意思：

```scheme
(funV 'f1 'x (fdC 'f2 'x (plusC (idC 'x) (idC 'x))))
```

当时如果我们调用上面的函数：

```scheme
(appC <嵌套的-fdC> (numC 4))
```

再求值，结果就有点意思了：

```scheme
(funV 'f2 'x (plusC (idC 'x) (idC 'x)))
```

这个结果就好像外部函数的调用对内部的函数没有任何影响一样。那么，为什么应该是这样的呢？
外部函数引入的参数被内部函数引入的**同名**参数覆盖（masked）了，因此遵从静态作用域的规则，
内部的参数应该覆盖外部参数。但是，我们看看下面这个程序：

```scheme
(appC (fdC 'f1 'x
           (fdC 'f2 'y
                (plusC (idC 'x) (idC 'y))))
      (numC 4))
```

求值得到：

```scheme
(funV 'f2 'y (plusC (idC 'x) (idC 'y)))
```

嗯，非常有趣。

> 想想有趣的点在哪？

为了看看到底有趣在哪，我们调用一下该函数：

```scheme
(appC (appC (fdC 'f1 'x
                 (fdC 'f2 'y
                      (plusC (idC 'x) (idC 'y))))
            (numC 4))
      (numC 5))
```

它将抛出异常告诉我们没找到标识符 `x` 绑定的值！

但是，显然它应该通过函数 `f1` 的调用被绑定。清晰起见，

我们应该是某些地方做错了以至于没有捕捉到函数调用时的参数绑定。
一个函数值需要**记住调用过程中执行的替换操作**。由于我们使用环境来表示这种替换，
因此一个函数值需要包含一个记录了该替换的环境。于是我们得到了一个新的称为 **closure（闭包）**
的结构：

注意一下，在解释器的 `appC` 部分代码中，我们使用了 `funV-arg` 和 `funV-body`，
但是没有使用 `funV-name`。想一下我们之前为什么需要名字这种东西，
因为需要通过名字找到一些东西。但是这里我们并不需要查找什么，它只是作为一个描述性的存在了。
即函数并不需要名字，就跟常数一样：我们每次使用 3 的时候并不需要一个名字，那么对于函数为什么要呢？
函数具有其**内在**的匿名性，我们应该将其定义和命名分开来。

（但是你可能说了，只在需要的地方定义然后使用函数的情况下这种论调当然没有问题。
但是如果我们想在某个地方定义，然后在其它地方使用它，我们不还是需要名字的么？
是的，正是，后面的“匿名之上的语法糖”中会说到这个主题）

## 7.3 实现 closure

首先将函数值类型改为我们要用的闭包类型：

```scheme
# <answer-type>
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)])
```

同时，我们需要函数定义类型（`fdC`），由于历史原因，该构造被称为 `lambda`：

```scheme
# <fun-type>
  [lamC (arg : symbol) (body : ExprC)]
```

现在，当解释器遇到函数时，需要记住到目前为止进行过的所有替换：

```scheme
  [lamC (a b) (closV a b env)]
```

> “Save the environment! Create a closure today!” —Cormac Flanagan

然后在调用函数时，需要在 **closure** 的环境中添加参数与参数值的绑定。

```scheme
  [appC (f a) (let ([f-value (interp f env)])
                (interp (closV-body f-value)
                        (extend-env (bind (closV-arg f-value)
                                          (interp a env))
                                    (closV-env f-value))))]
```

事实上这段代码还可以有一个版本：

```scheme
  [appC (f a) (let ([f-value (interp f env)])
                (interp (closV-body f-value)
                        (extend-env (bind (closV-arg f-value)
                                          (interp a env))
                                    env))] ;; 这里
```

即直接动态的扩展环境变量。

> 想想这会导致什么。

考虑初始环境中没有任何绑定的情况有助于我们理清状况，这时如果在最上层定义一个函数，
它对应的 `closure（闭包）` 没有闭合任何标识符（即没有任何标识符被绑定到了值。
译者注，这个地方这么一解释，closure 就变得合情合理了，从 close 来的吧）。
因此前一种实现是后一种的特殊情况。

> 再想想这里的使用了这种使用方式难道不会导致前面章节中说过的动态绑定的各种缺点吗？


## 7.4 再次聊到替换

我们已经看到，通过替换这种非常符合直觉的方式如何实现了 `lambda` 函数。
然而，对于替换本身我们需要担心一些陷阱。考虑下面这个函数（这里是 Racket 语法）：

```scheme
(lambda (f)
  (lambda (x)
    (f 10)))
```

如果使用表达式 `(lambda (y) (+ x y))` 作为参数调用该函数，
注意该函数中有一个自由变量 `x`，但是使用之前的替换函数，我们将得到：

```scheme
(lambda (x)
  ((lambda (y) (+ x y)) 10))
```

自由变量消失了！

这是由于我们的替换操作实现的太过天真。为了避免这种异常情况（这也是动态绑定的一种形式），
我们需要实现一个非捕获型的替换函数（capture-free substitution）。
它的实现大致描述一下就是我们总是将绑定的标识符重命名为从未用过的名字。想象一下，
我们给每个标识符加个数字后缀来保证不会出现重名：

```scheme
(lambda (f1)
  (lambda (x1)
    (f1 10)))
```

以参数 `(lambda (y1) (+ x y1))` 进行调用，执行替换，得到：

```scheme
(lambda (x1)
  ((lambda (y1) (+ x y1)) 10))
```

现在，`x` 仍然是自由变量！

> 这里为什么不对作为参数的函数中的 `x` 进行重命名呢？
>
> 因为它的值可能出现在最上层的环境中，即运行的初始环境中。

> 想一想怎么使用环境才能避免替换导致的捕获问题。

> 笔者：
>
> 可以将这部分代码
>
> ```scheme
> (interp (closV-body f-value)
>     (extend-env (bind (closV-arg f-value)
>                 (interp a env))
>                 (closV-env f-value)))
> ```
>
> 改成
>
> ```scheme
> (let ([unusedId (create-unused-id)])
>     (interp ((substId (closV-arg f-value) unusedId closV-body) f-value)
>         (extend-env (bind (unusedId f-value)
>                     (interp a env))
>                     (closV-env f-value))))
> ```

## 7.5 匿名之上的语法糖

回到函数命名问题，它对于实际编程来说有明显的价值。注意我们现在**已经**有命名的方法：通过函数的调用，参数的值和参数名构成了本地绑定。

例如考虑 Racket 代码：

```scheme
(define (double x) (+ x x))
(double 10)
```

等价于：

```scheme
(define double (lambda (x) (+ x x)))
(double 10)
```

等价于：

```scheme
((lambda (double)
   (double 10))
 (lambda (x) (+ x x)))
```

这种模式——我们暂且称为 “left-left-lambda”——是一种本地命名方式。它非常有用，以至于 Racket 为它提供了专门的语法：

```scheme
(let ([double (lambda (x) (+ x x))])
  (double 10))
```

`let` 可以通过定义成上面那种调用的语法糖实现。

下面是个稍微复杂点的例子：

```scheme
(define (double x) (+ x x))
(define (quadruple x) (double (double x)))
(quadruple 10)
```

可以被改写成：

```scheme
(let ([double (lambda (x) (+ x x))])
  (let ([quadruple (lambda (x) (double (double x)))])
    (quadruple 10)))
```

改变一下顺序就不行了：

```scheme
(let ([quadruple (lambda (x) (double (double x)))])
  (let ([double (lambda (x) (+ x x))])
    (quadruple 10)))
```

这是由于 `quadruple` 中“看不见” `double`。这里我们也能看到顶级绑定和本地绑定的区别：顶级作用域有一个“无限的作用域”。这是其强大的地方也是问题的来源。

下面还有一个更为微妙的问题，和递归有关。考虑下面程序：

```scheme
(define (loop-forever x) (loop-forever x))
(loop-forever 10)
```

转换成 `let`：

```scheme
(let ([loop-forever (lambda (x) (loop-forever x))])
  (loop-forever 10))
```

看上去好像没毛病，是吧？重写成 `lambda` 的形式：

```scheme
((lambda (loop-forever)
   (loop-forever 10))
 (lambda (x) (loop-forever x)))
```

显然，最后一行中的 `loop-forever` 没有被绑定！

对于顶级绑定这个问题就不存在，该怎么实现呢？很快我们将揭开这层神秘的面纱。
