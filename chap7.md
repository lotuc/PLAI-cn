# 7 任意位置的函数

Scheme语言报告修订版报告的概述（[r6rs 概述](http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-3.html#node_chap_Temp_3)，[r5rs（中文）](http://www.math.pku.edu.cn/teachers/qiuzy/progtech/scheme/r5rscn.pdf)）中指出如下的设计原则：

> 程序语言的设计不应该是特性的简单堆砌，而应消除语言的弱点和缺陷，使得剩下的特性显得必要。

这是个无须争辩的设计原则。（当然有些缺陷是迫不得已的，但是此原则迫使我们去认真思考引入这些缺陷的必要性，而不是把它们当作理所当然的。）下面我们试着遵从该原则来引入函数。

在[第五章](./chap5.md)中我们引入函数时并没有特别指明函数定义所在的位置。可以说我们是按照理想化的DrRacket模型引入的函数，即将函数的定义和使用分离。下面我们使用Scheme的设计原则来重新思考一下这种设计的**必要性**。

为什么函数的定义不可以也是一种表达式呢？我们现在实现的算术语言中有个尴尬的问题：“函数的定义表示的是什么值？”，在现有设计中没有很好的答案。对于真正的语言来说，计算结果当然不可能只有数，所以也没必要给我们的语言作出这种限制；跳出这个框框，便可以给出很好的回答：“函数值”。让我们试试如何实现它。

将函数作为值，能用它做什么呢？显然，函数和数是不同类型的值，你不能对函数做加法运算。但是，有件它显然能做的事：传入参数调用它！因此我们应该允许函数值出现在函数调用那个位置。其行为，显然是调用该函数。因此，我们的语言中应该允许如下的表达式作为合法程序（这里使用方括号以方便阅读）：

```Racket
(+ 2 ([define (f x) (* x 3)] 4))
```

计算它得到`(+ 2 (* 4 3))`，也就是`14`。（注意到没？这里使用了替换计算模型。）

## 7.1 函数作为表达式和值

首先在我们的核心语言中添加函数定义：

```Racket
<expr-type> ::=  ;表达式类型

    (define-type ExprC
      [numC (n : number)]
      [idC (s : symbol)]
      <app-type>  ;调用类型
      [plusC (l : ExprC) (r : ExprC)]
      [multC (l : ExprC) (r : ExprC)]
      <fun-type>)  ;函数类型
```

现在，我们简单把函数定义复制到表达式语言中，以后需要的话还可以修改这一点。这样做我们现在可以复用已有的测试案例。

```Racket
<fun-type-take-1> ::=  ;函数类型，第一次尝试

    [fdC (name : symbol) (arg : symbol) (body : ExprC)]
```

接下来确定函数调用是什么样的。函数的位置应该放什么呢？我们希望它可以是函数定义，而不是像之前那样只能是定义好的函数的名字。由于现在函数定义类型和其它表达式类型混在了一起，这里让函数的位置可以放任意表达式吧，但是需要记住我们其实只希望它为函数定义：

```Racket
<app-type> ::=  ;调用类型

    [appC (fun : ExprC) (arg : ExprC)]
```

> 另一种可以考虑的做法是，把函数定义和其他类型的表达式区分开。也就是定义不同类型的表达式。我们在后文学习类型时会考虑这种做法。

有了这个定义后，我们不再需要通过名字查找函数了，所以我们的解释器也可以不用再传入函数定义链表。当然之后有需要我们还可以将预定义函数链表加回来，现在我们只探究**即时函数**——在函数调用处定义的函数。

接下来修改解释器`interp`。需要添加子句来处理函数定义，该部分代码大致会是这样：

```Racket
  [fdC (n a b) expr]
```

__思考题__
> 解释器中添加了该语句会导致什么？

显然，这是爆炸性的改变：解释器不再总是返回数了，于是出现类型错误。

在之前解释器实现过程中，也不时的需要注意其返回值类型，但并没专门给其定义数据类型。现在是时候需要这么做了：

```Racket
<answer-type-take-1> ::=  ;返回值类型，第一次尝试

    (define-type Value
      [numV (n : number)]
      [funV (name : symbol) (arg : symbol) (body : ExprC)])
```

我们使用后缀`V`表示值（value），即求值的结果。`funV`部分正对应`fdC`；`fdC`为输入，`funV`为输出。通过区分这两者类型，我们可以分别修正它们两个。

下面我们尝试使用该输出类型重写解释器，从类型开始：

```Racket
<interp-hof> ::=  ;解释器，高阶函数

    (define (interp [expr : ExprC] [env : Env]) : Value
      (type-case ExprC expr
        <interp-body-hof>))  ;解释器主体，高阶函数
```

这就要求我们同样修改`Binding`和辅助函数`lookup`的类型。

__练习__
> 修改`Binding`和辅助函数`lookup`。

```Racket
<interp-body-hof> ::=  ;解释器主体，高阶函数

    [numC (n) (numV n)]
    [idC (n) (lookup n env)]
    <app-case>  ;调用子句
    <plus/mult-case>  ;加法/乘法子句
    <fun-case>  ;函数子句
```

对于数，显然要使用新的返回值类型构造器对其包裹一下。对于标识符，一切不变。对于加法／乘法，需要进行简单的修改使其能正确的返回`Value`类型而不是简单的数：

```Racket
<plus/mult-case> ::=  ;加法/乘法子句

    [plusC (l r) (num+ (interp l env) (interp r env))]
    [multC (l r) (num* (interp l env) (interp r env))]
```

辅助函数`num+`和`num*`我们以其中一个为例：

```Racket
(define (num+ [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (+ (numV-n l) (numV-n r)))]
    [else
     (error 'num+ "one argument was not a number")]))  ;有参数不是数
```

请留意，在实际做加法前，我们检查了参数的类型确定其为数。后面会有章节继续谈论类型这个主题。

还有两段代码要完成。先是函数定义。上面说过，函数值就是其类型的数据：

```Racket
<fun-case-take-1> ::=  ;函数子句，第一次尝试

    [fdC (n a b) (funV n a b)]
```

最后剩下函数调用的代码。尽管我们不再需要从函数定义链表中查询函数定义，但是这里还是尽量保留之前函数调用的代码的结构：

```Racket
<app-case-take-1> ::=  ;调用子句，第一次尝试

    [appC (f a) (let ([fd f])
                  (interp (fdC-body fd)
                          (extend-env (bind (fdC-arg fd)
                                            (interp a env))
                                      mt-env)))]
```

在原来是lookup查找的地方，我们直接引用了`f`作为函数定义。注意由于在函数应该出现的位置事实上可能出现任何表达式，我们最好编码检测它是否实是函数。

__思考题__
> 这里“是”是什么意思呢？我们是要检查它是作为语法结构上的函数（即`fdC`构造），还是只是检查该表达式的计算结果是否是函数值（即`funV`）呢？这两种做法有什么区别？换一种说法，你能不能找出具体的例子来展示其区别？

我们面临选择：

1. 检查它在语法上是否是`fdC`构造，如果不是，抛出异常。
2. 对其进行求值，然后检查其返回**值**是否是函数，如果不是，抛出异常。

我们选择后一种做法，它会使得我们的语言更为灵活。即使我们人类不一定需要这么做，但对于程序来说，第二种选择可以处理更多情况，比如程序生成代码。并且我们也会用到这个功能，就在[匿名之上的语法糖](#75-匿名之上的语法糖)的讨论中。于是，修改函数调用部分代码得到：

```Racket
<app-case-take-2> ::=  ;调用子句，第二次尝试

    [appC (f a) (let ([fd (interp f env)])
                  (interp (funV-body fd)
                          (extend-env (bind (funV-arg fd)
                                            (interp a env))
                                      mt-env)))]
```

__练习__
> 修改代码实现两种不同方式的类型检查。

信不信由你，到此为止，一个可运行的解释器又完成了。最后我们照旧给出两个测试案例：

```Racket
(test (interp (plusC (numC 10) (appC (fdC 'const5 '_ (numC 5)) (numC 10)))
              mt-env)
      (numV 15))

(test/exn (interp (appC (fdC 'f1 'x (appC (fdC 'f2 'y (plusC (idC 'x) (idC 'y)))
                                          (numC 4)))
                        (numC 3))
                  mt-env)
          "name not found")
```

## 7.2 什么？嵌套？

函数定义的函数体部分可以是任意表达式。而函数定义本身也是表达式。于是函数定义中可以包含···函数定义。例如：

```Racket
<nested-fdC> ::=  ;嵌套的fdC

    (fdC 'f1 'x
         (fdC 'f2 'x
              (plusC (idC 'x) (idC 'x))))
```

对它求值还不是特别有意思：

```Racket
(funV 'f1 'x (fdC 'f2 'x (plusC (idC 'x) (idC 'x))))
```

当时如果我们调用上面的函数：

```Racket
<applied-nested-fdC> ::=  ;调用嵌套的fdC

    (appC <nested-fdC>
          (numC 4))
```

再求值，结果就有点意思了：

```Racket
(funV 'f2 'x (plusC (idC 'x) (idC 'x)))
```

这个结果就好像外部函数的调用对内部的函数没有任何影响一样。那么，为什么应该是这样的呢？外部函数引入的参数被内部函数引入的**同名**参数覆盖（mask）了，因此遵从静态作用域（必须的）的规则，内部的参数应该覆盖外部参数。但是，我们看看下面这个程序：

```Racket
(appC (fdC 'f1 'x
           (fdC 'f2 'y
                (plusC (idC 'x) (idC 'y))))
      (numC 4))
```

求值得到：

```Racket
(funV 'f2 'y (plusC (idC 'x) (idC 'y)))
```

嗯，有点意思。

__思考题__
> 想想有意思的点在哪？

为了看看到底有意思在哪，我们调用一下该函数：

```Racket
(appC (appC (fdC 'f1 'x
                 (fdC 'f2 'y
                      (plusC (idC 'x) (idC 'y))))
            (numC 4))
      (numC 5))
```

它将抛出异常告诉我们没找到标识符`x`绑定的值！

但是，它不是应该通过函数`f1`的调用被绑定吗？清晰起见，我们切换为（假定的）Racket语法：

```Racket
((define (f1 x)
   ((define (f2 y)
      (+ x y))
    4))
 5)
```

在调用外层函数时，x应该被替换成5，结果是：

```Racket
((define (f2 y)
   (+ 5 y))
 4)
```

继续调用、替换得到`(+ 5 4)`也就是`9`，并没有出错。

换一种说法，我们肯定是某个地方做错了以至于没有捕捉到函数调用时的参数替换。【注释】函数值需要**记住调用过程中执行的替换操作**。由于我们使用环境来表示这种替换，因此函数值需要包含记录了该替换的环境。这样得到的数据结构称为**闭包（closure）**：

> 另一方面，如果我们使用替换模型，`x`会被替换成`(numV 4)`，函数体就变成`(plusC (numV 5) (idC ’y))`，而它并没有合适的类型。换一种说法，替换模型假设返回值的类型是合法语法。其实尊崇该假设也能学习很多高级编程概念，只是我们不打算往这个方向继续讨论。

注意一下，在解释器的`appC`子句中用到了`funV-arg`和`funV-body`，但是没用到`funV-name`。想一下我们之前为什么需要名字这种东西？因为需要通过名字找到函数。但是这里我们通过解释器找到函数，函数名只是作为描述性的存在罢了。换一种说法，函数并不需要名字，就跟常数一样：我们每次使用3的时候并不需要给它命名，那么对于函数为什么要呢？函数**本质上**是匿名的，我们也应该将其定义和命名分开来。

（但是你可能会说，这种论点只在函数直接定义并使用的情况才成立。如果我们想在某个地方定义，然后在其它地方使用它，我们不还是需要名字的么？是的，正是，后面的[匿名之上的语法糖](#75-匿名之上的语法糖)中会说到这个主题）

## 7.3 实现闭包

首先将函数值类型改为闭包结构体，而不仅仅是函数本体：

```Racket
<answer-type> ::=  ;返回值类型

    (define-type Value
      [numV (n : number)]
      [closV (arg : symbol) (body : ExprC) (env : Env)])
```

同时，我们可以修改函数类型，去除没用的函数名部分。由于历史原因，该构造被称为**lambda**：

```Racket
<fun-type> ::=  ;函数类型

    [lamC (arg : symbol) (body : ExprC)]
```

现在，当解释器遇到函数时，需要记录下到目前为止进行过的所有替换：【注释】

```Racket
<fun-case> ::=  ;函数子句

    [lamC (a b) (closV a b env)]
```

> “Save the environment! Create a closure today!” —Cormac Flanagan

然后在调用函数时，需要使用这个保存下来的环境，而不是空白环境。

```Racket
<app-case> ::=  ;调用子句

    [appC (f a) (let ([f-value (interp f env)])
                  (interp (closV-body f-value)
                          (extend-env (bind (closV-arg f-value)
                                            (interp a env))
                                      (closV-env f-value))))]
```

事实上这段代码还可以有另一个选择：使用函数调用处的环境：

```Racket
[appC (f a) (local ([define f-value (interp f env)])
              (interp (closV-body f-value)
                      (extend-env (bind (closV-arg f-value)
                                        (interp a env))
                                  env)))]
```

__思考题__
> 如果我们使用动态的环境（即函数调用处的环境），会导致什么？

回过头来看，现在可以理解为何我们在解释函数体时使用空白环境了。如果函数是定义在程序顶层的，那么它就没有“包含”任何的标识符。因此我们之前的函数实现是现在这种的特殊情况。

## 7.4 再次聊聊替换

我们已经看到，通过替换这种非常符合直觉的方式可以帮助理解如何实现`lambda`函数。然而，对于替换本身我们需要小心一些陷阱！考虑下面这个函数（这里使用Racket语法）：

```Racket
(lambda (f)
  (lambda (x)
    (f 10)))
```

假设`f`被替换为lambda表达式`(lambda (y) (+ x y))`。注意这里有个自由变量`x`，所以如果它被求值，我们应该会得到未绑定变量错误。但是使用替换模型，我们将得到：

```Racket
(lambda (x)
  ((lambda (y) (+ x y)) 10))
```

自由变量消失了！

这是由于我们的替换操作实现的太过简单。为了避免这种异常情况（这也是动态绑定的一种形式），我们需要实现**非捕获型的替换（capture-free substitution）**。大致来说它是这样工作的：我们**总是**将绑定标识符**重命名**为从未用过的（**新鲜的，fresh**）名字。比如说，我们给每个标识符加个数字后缀来保证不会出现重名：

```Racket
(lambda (f1)
  (lambda (x1)
    (f1 10)))
```

（请注意，我们把f的绑定和被绑定出现都替换成了f1。）接下来对被替换的表达式也进行同样的重命名：

```Racket
(lambda (y1) (+ x y1))
```

于是替换`f1`得到：【注释】

```Racket
(lambda (x1)
  ((lambda (y1) (+ x y1)) 10))
```

> 这里为什么不对作为`x`进行重命名呢？因为它可能是引用全局的定义，要么我们也对全局定义进行同样的重命名。这就是所谓的一致性重命名原则。对这个例子来说，这没啥区别。

现在，`x`仍然是自由变量！这才是正确的替换方式。

等一等。怎么使用环境模型解释器处理这个例子，后果是啥？

__思考题__
> 试一下。

试了你就知道，一切正确：程序报告有未绑定变量。环境模型实际上实现了非捕获型替换。

__练习__
> 使用环境是怎么避免替换中的捕获问题的？

## 7.5 匿名之上的语法糖

让我们回过头考虑函数命名问题，对于实际编程来说它有明显的价值。注意我们现在**已经**有命名东西的方法：通过函数的调用，参数的值和参数名构成了局部绑定关系。在函数体中，我们只需要用形参就可以引用实参了。

所以说，我们可以用函数来给一系列函数定义命名。例如，考虑Racket代码：

```Racket
(define (double x) (+ x x))
(double 10)
```

等价于：

```Racket
(define double (lambda (x) (+ x x)))
(double 10)
```

一种方法是直接内联（inline）double的定义。不过为了保留命名过程，我们让其等价于：

```Racket
((lambda (double)
   (double 10))
 (lambda (x) (+ x x)))
```

这种模式——我们暂且称为“left-left-lambda”——实际上是种局部命名方式。它非常有用，以至于Racket为它提供了专门的语法：

```Racket
(let ([double (lambda (x) (+ x x))])
  (double 10))
```

`let`可以通过定义成上面那种语法糖来实现。

下面是个稍微复杂点的例子：

```Racket
(define (double x) (+ x x))
(define (quadruple x) (double (double x)))
(quadruple 10)
```

这可以被改写成：

```Racket
(let ([double (lambda (x) (+ x x))])
  (let ([quadruple (lambda (x) (double (double x)))])
    (quadruple 10)))
```

一切正常。改变一下顺序就不行了：

```Racket
(let ([quadruple (lambda (x) (double (double x)))])
  (let ([double (lambda (x) (+ x x))])
    (quadruple 10)))
```

这是由于`quadruple`中“看不见”`double`。这里我们也能看到全局绑定和局部绑定的区别：位于顶层的全局绑定有“无限的作用域”。这是其强大的地方也是问题的来源。

下面还有个更为微妙的问题，和递归有关。考虑如下的简单无限循环程序：

```Racket
(define (loop-forever x) (loop-forever x))
(loop-forever 10)
```

转换成`let`：

```Racket
(let ([loop-forever (lambda (x) (loop-forever x))])
  (loop-forever 10))
```

看上去好像没毛病，是吧？重写成`lambda`的形式：

```Racket
((lambda (loop-forever)
   (loop-forever 10))
 (lambda (x) (loop-forever x)))
```

显然，最后一行中的`loop-forever`没有被绑定！

对于全局绑定这个问题就不存在。该怎么理解呢？这需要我们理解递归的含义。很快我们将揭开这层神秘的面纱。
