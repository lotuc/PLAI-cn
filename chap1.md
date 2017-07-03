# 引言

## 本书使用的语言

本书使用的主要语言是 Racket 。然而跟很多操作系统一样，Racket 支持很多编程语言，所以你必须显式的告诉Racket 你在使用什么语言进行编程。在 Unix 系统的 shell 脚本中你需要在脚本开头添加下面这样一行来指明解释器：

```sh
#!/bin/sh
```

类似的，Racket 需要你声明你要使用的语言。 Racket 语言可能使用和 Racket 一样的括号语法，但是有不同的语义；或语义相同语法不同；或者有不同的语法和语义。因此每个 Racket 程序以 `#lang <语言名字>` 开头。默认的语言为 Racket（名字为 racket）。这本书中我们几乎总是使用语言：

```text
plai-typed
```

使用该语言时，在程序的第一行添加（本书后面例子代码中请假定我们添加了该行）：

```racket
#lang plai-typed
```

Typed PLAI 语言和传统的 Racket 最主要的不同是它是静态类型的。它还给你提供了一些有用的的东西（constructs）： `define-type` 、 `type-case` 和 `test` 。下面是他们的使用实例。创建新的数据类型：

```Racket
(define-type MisspelledAnimal
  [caml (humps : number)]
  [yacc (height : number)])
```

它做的事情类似于在 Java 中：创建一个抽象类 `MisspelledAnimal` ，它有两个实体子类： `caml` 和 `yacc` ，它们的构造参数分别为 `humps` 和 `height` 。

该语言中，我们通过下面方式可以创建实例：

```racket
(caml 2)
(yacc 1.9)
```

定义数据类型后，语言会自动给我生成类型判断函数和字段选择器：

```racket
;; 类型判断函数
(caml? (caml 2)) ;; true
(caml? (yacc 2)) ;; false

(yacc? (yacc 2)) ;; true
(yacc? (caml 2)) ;; false

;; 字段选择
(caml-humps (caml 2))   ;; 2
(yacc-height (yacc 10)) ;; 10
```

同名字暗示的一样，`define-type` 创建一个给定名字的类型。我们可以将实例绑定到名字：

```racket
(define ma1 : MisspelledAnimal (caml 2))
(define ma2 : MisspelledAnimal (yacc 1.9))
```

事实上这里你并不需要显式的声明类型，因为 Typed PLAI 会进行类型推测。因此上面的代码可以写成：

```racket
(define ma1 (caml 2))
(define ma2 (yacc 1.9))
```

但是出于使函数易于理解使用的原因，我们倾向于对函数的返回类型进行显式的声明。

类型的名字可以递归的使用，本书会经常使用这种方式。

该语言为我们提供了模式匹配，例如对于函数体：

```racket
(define (good? [ma : MisspelledAnimal]) : boolean
        (type-case MisspelledAnimal ma
                   [caml (humps) (>= humps 2)]
                   [yacc (height) (> height 2.1)]))
```

对于其中的表达式 `(>= humps 2)` ， `humps` 是要匹配的 `caml` 实例的构造参数。

最后，你可以使用 `test` 写测试。

```racket
(test (good? ma1) #t)
(test (good? ma2) #f)
```

当你运行上面的代码时，该语言会告诉你两个测试都通过了。对于未通过的代码，它会提示错误出现在哪。 要了解更多请阅读文档。

上面有些东西可能比较费解。我们在模式匹配中为了匹配数据字段时使用了和数据定义时相同的名字 `humps` （和 `height` ）。这是完全没有必要的，完全可以使用其它名字：

```racket
(define (good? [ma : MisspelledAnimal]) : boolean
  (type-case MisspelledAnimal ma
             [caml (h) (>= h 2)]
             [yacc (h) (> h 2.1)]))
```

因为每个 h 仅在对应的匹配分支中可见，所以上面的代码没有问题。

不使用模式匹配的话，也可以使用上面提到的类型判断函数和字段选择器也可以实现上面的函数：

```racket
(define (good? [ma : MisspelledAnimal]) : boolean
  (cond
    [(caml? ma) (>= caml-humps ma) 2]
    [(yacc? ma) (> (yacc-height ma) 2.1)]))
```

> 如果给函数传入了错误的数据类型会发生什么？如：
>
> `(good? "Should be a MisspelledAnimal, but a string")`
