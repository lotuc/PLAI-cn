# 10 对象

当一门语言将函数作为值，它便为开发者提供了最为自然的用于表示计算过程的最小单位。任何一门语言都允许函数参数为字符串、数字这种被动数据（passive data），但是支持参数为 active data（翻译无能）是非常吸引人的：即传递进去的数据实际上是一个计算过程，你可以通过它计算得出一个结果，可能是针对特定信息的响应。如果传递进函数 `f` 的 active data 是一个词法作用域函数，那么调用者就可以在无需将某些数据泄漏给 `f` 的情况下使用这些数据了，这给安全和隐私提供了基石。正因如此，词法作用域函数成为很多安全编程技巧设计的核心。

函数是一种非常美好的东西，从概念上来说，太非常简洁，但是太过简洁了。有时候我们希望多个函数闭合于一份共享的数据；当这份数据被某个函数改变而我们希望其他函数能够看到这些改变是尤为如此。

## 10.1 不支持继承的对象

最简单的关于对象的定义为——可能是唯一的所有谈论对象的人都能统一的定义——对象是：

* 是一个值
* 该值能够将一些名字映射成
* 其它东西：其它值或者“方法”

从极简主义的角度来说，方法似乎就是函数，由于在自己的语言中已经实现了函数，我们先放下它们之间的区别。

> 之后我们会发现“方法”和函数极其相似，但是在一些很重要的方面有所不同，主要是调用方式及所绑定的东西上。

### 10.1.1 语言核心中实现对象

从我们实现的将函数作为第一类值的语言开始，实现一个最简单的对象系统。首先扩展值的定义：

```scheme
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)]
  [objV (ns : (listof symbol)) (vs : listof Value)])
```

然后添加表达式语法以支持对象表达式：

```scheme
[objC (ns : (listof symbol)) (es : (listof ExprC))]
```

对该对象表达式的计算非常简单：直接计算表达式列表中的每个表达式即可：

```scheme
[objC (ns es) (objV ns (map (lambda (e)
                              (interp e env))
                            es))]
```

到目前为止我们还不能使用一个对象：很显然，我们没有获取对象内部内容的构造。于是，下面我们来给它添加一个获取成员的操作符：

```scheme
[msgC (o : ExprC) (n : symbol)]
```

添加它的动机明显，行为直白：

```scheme
[msgC (o n) (lookup-msg n (interp o env))]
```

**练习**

> 实现函数
>
> ```scheme
> ;; lookup-msg : symbol * Value -> Value
> ```
>
> 第二个参数期望值应该是 `objV`。

原则上 `msgC` 可以被用于获取任意类型的成员，但是简单起见，我们假设成员中只有函数。使用它，需要给其传入参数值。将它实现到核心语言会使语法有点笨拙，使用语法糖实现这点。我们创建如下语法糖：

```scheme
[msgS (o : ExprS) (n : symbol) (a : ExprS)]
```

解开成 `msgC` 并调用：

```scheme
[msgS (o n a) (appC (msgC (desugar o) n) (desugar a))]
```

至此，一个包含对象为第一类值的语言就诞生了。例如，下面是对象定义和调用：

```scheme
(letS 'o (objS (list 'add1 'sub1)
               (list (lamS 'x (plusS (idS 'x) (numS 1)))
                     (lamS 'x (plusS (idS 'x) (numS -1)))))
      (msgS (idS 'o) 'add1 (numS 3)))
```

它计算得 `(numV 4)`。

### 10.1.2 通过语法糖实现对象

在语言核心中定义实现对象也许很值得，但是对于学习它来说这种实现方式有点笨重。替代方案是我们直接使用 Racket 语言中那些我们的解释器中已经实现的部分来表示对象。即假设我们看到的是 *desugaring* 的结果。


**注意：**后面所有的代码都使用 `#lang plai`，而不是 `typed` 语言。

**练习**
> [TODO](http://cs.brown.edu/courses/cs173/2012/book/Objects.html#%28part._.Objects_by_.Desugaring%29)

### 10.1.3 作为名字集合的对象

首先重现我们已经实现的语言。对象是一个值，可以给该值传递一个名字，将分发得到对象内该名字对应的成员。简单起见，使用 `lambda` 表示对象，使用 `case` 实现分发过程：

```scheme
(define o-l
  (lambda (m)
    (case m
      [(add1) (lambda (x) (+ x 1))]
      [(sub1) (lambda (x) (- x 1))])))
```

这和本章前面的定义的对象相同，其方法的使用方式也相同：

```scheme
(test ((o-l 'add1) 5) 6)
```

当然，这种嵌套的函数调用有点臃肿，考虑到之后还有更多这种调用，我们定义一个函数做这种事，它看上去和之前的 `msgS` 一样：

```scheme
(define (msg o m . a)
  (apply (o m) a))
```

**想想**
> 转换到语法糖的方式后，一些重要的东西发生了改变。你意识到是什么了吗？

回忆我们之前定义的语法：

```scheme
[msgC (o : ExprC) (n : symbol)]
```

注意到“名字”的位置是**符号**。即开发者在该位置需要写上一个符号字面值。而在这个语法糖的版本中，名字的位置只是一个必须要计算得到符号的表达式；例如，我们可以写：

```scheme
(test ((o-l (string->symbol "add1")) 5) 6)
```

这是语法糖的共有的一个毛病：目标语言可能允许一些在源码中没有对应表示的表达式，于是它们不能映射回去。不过幸运的是，我们不常需要进行这种反向映射，在一些调试和程序分析工具中可能需要做这种事。而更微妙的是，我们必须保证目标语言中不会产生在源码中无法对应的**值**。

现在我们有了一个基本的对象实现，下面开始添加那些大部分对象系统中都有的特性。

### 10.1.4 构造器

构造器只是一个在对象构造时调用的函数。现在我们缺乏这样的函数。通过将对象从一个字面值转换成接受构造参数的函数可以达到这种效果：

```scheme
(define (o-constr-l x)
  (lambda (m)
    (case m
      [(addX) (lambda (y) (+ x y))])))

(test (msg (o-constr-1 5) 'addX 3) 8)
(test (msg (o-constr-1 2) 'addX 3) 5)
```

第一个测试式子中构造参数为 5，于是加 3 得到 8。第二个测试也是类似的。构造函数的不同次调用不会影响彼此。

### 10.1.5 状态

很多人认为对象的主要目的就是用来封装状态。我们可以很容易实现多个方法对同一个状态的操作，如：

```scheme
(define (o-state-1 count)
  (lambda (m)
    (case m
      [(inc) (lambda () (set! count (+ count 1)))]
      [(dec) (lambda () (set! count (- count 1)))]
      [(get) (lambda () count)])))
```

可以使用下面的代码测试一下：

```scheme
(test (let ([o (o-state-1 5)])
        (begin (msg o 'inc)
               (msg o 'dec)
               (msg o 'get)))
      5)
```

应该注意到对一个对象中状态的改变不会影响到另一个：

```scheme
(test (let ([o1 (o-state-1 3)]
            [o2 (o-state-1 3)])
        (begin (msg o1 'inc)
               (msg o1 'inc)
               (+ (msg o1 'get)
                  (msg o2 'get))))
      (+ 5 3))
```

### 10.1.6 私有成员

另一个非常常见的面向对象语言特性是私有成员：那些只在对象内部可见的成员。看上去这个特性还有待我们去实现，但事实上我们实现的本地作用域、本地绑定变量已经可以实现这点了：

```scheme
(define (o-state-2 init)
  (let ([count init])
    (lambda (m)
      (case m
        [(inc) (lambda () (set! count (+ count 1)))]
        [(dec) (lambda () (set! count (- count 1)))]
        [(get) (lambda () count)]))))
```

上面这个语法糖的实现没有提供任何直接访问变量 count 的方式，这是通过本地作用域确保它对外部世界不可见。

### 10.1.7 静态成员

另一个非常有用的特性是静态成员：对所有“相同”类型对象实例来说通用的成员。这，实际上就是在构造器外面一层的本地作用域标识符：

```scheme
(define o-static-1
  (let ([counter 0])
    (lambda (amount)
      (begin
        (set! counter (+ 1 counter))
        (lambda (m)
          (case m
            [(inc) (lambda (n) (set! amount (+ amount n)))]
            [(dec) (lambda (n) (set! amount (- amount n)))]
            [(get) (lambda () amount)]
            [(count) (lambda () counter)]))))))
```

上面的代码我们在构造器中对计数值 `counter` 进行了加一操作，当然，在方法中也可以使用 `counter` 值。

下面构造多个对象测试一下：

```scheme
(test (let ([o (o-static-1 1000)])
        (msg o 'count))
      1)
 
(test (let ([o (o-static-1 0)])
        (msg o 'count))
      2)
```

### 10.1.8 带自引用的对象

目前为止，我们的对象还只是打包在一起的一组命名了的函数。可以看到很多对象系统中被认为很重要的特性可以通过函数和作用域实现。

对象系统一大不同与众不同的特征是每个对象都自动装填了对对象自己的引用，常被称为 `self` 或者 `this`。这可以很容易的被实现吗？

### 10.1.8.1 使用 mutation 实现自引用

是的，我们可以，之前实现递归的时候我们已经见过这种模式了；
