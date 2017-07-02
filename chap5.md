# 添加函数

下面尝试将其变成一个真正的变成语言。可以考虑添加诸如条件语句这种特性，但是不妨一步到位，添加最有意思的东西——函数，或者对于本节来说，我们添加一个等同函数的东西。

> **作业**
>
> 给语言添加条件语句。你可以选择添加 boolean 类型，或者方便起见，将 0
> 作为 false，其他东西作为 true。（下面是我的一个实现）
>
> ```racket
> #lang plai-typed
>
> (define-type ArithC
>   [numC (n : number)]
>   [ifC (cond : ArithC) (ifResut : ArithC) (elseResult : ArithC)]
>   [plusC (l : ArithC) (r : ArithC)]
>   [multC (l : ArithC) (r : ArithC)])
>
> (define-type ArithS
>   [numS (n : number)]
>   [plusS (l : ArithS) (r : ArithS)]
>   [bminusS (l : ArithS) (r : ArithS)]
>   [uminusS (e : ArithS)]
>   [multS (l : ArithS) (r : ArithS)]
>   [ifS (cond : ArithS) (ifResult : ArithS) (elseResult : ArithS)])
>
> (define (desugar [as : ArithS]) : ArithC
>   (type-case ArithS as
>     [numS (n) (numC n)]
>     [plusS (l r) (plusC (desugar l)
>                         (desugar r))]
>     [multS (l r) (multC (desugar l)
>                         (desugar r))]
>     [uminusS (e) (multC (numC -1) (desugar e))]
>     [bminusS (l r) (plusC (desugar l)
>                           (multC (numC -1) (desugar r)))]
>     [ifS (cond ifResult elseResult)
>          (ifC (desugar cond) (desugar ifResult) (desugar elseResult))]))
>
> (define (parse [s : s-expression]) : ArithS
>   (cond
>     [(s-exp-number? s) (numS (s-exp->number s))]
>     [(s-exp-list? s)
>      (let ([sl (s-exp->list s)])
>        (case (s-exp->symbol (first sl))
>          [(+) (plusS (parse (second sl)) (parse (third sl)))]
>          [(*) (multS (parse (second sl)) (parse (third sl)))]
>          [(-)
>           (if (= (length sl) 2)
>               (uminusS (parse (second sl)))
>               (bminusS (parse (second sl)) (parse (third sl))))]
>          [(if) (ifS (parse (second sl)) (parse (third sl)) (parse (third (rest sl))))]
>          [else (error 'parse "invalid list input")]))]
>     [else (error 'parse "invalid input")]))
>
> (define (interp [a : ArithC]) : number
>   (type-case ArithC a
>     [numC (n) n]
>     [plusC (l r) (+ (interp l) (interp r))]
>     [multC (l r) (* (interp l) (interp r))]
>     [ifC (cond ifResult elseResult)
>          (if (= (interp cond) 0)
>              (interp elseResult)
>              (interp ifResult))]))
>
> (interp (desugar (parse (read))))
> ```

想象一下，我们要构造一个像 DrRacket 一样的系统。开发者在编辑窗口中定义函数，然后在交互窗口中使用它们。我们先假设所有的函数只能在编辑窗口定义，定义的函数可以在交互窗口使用；所有的表达式只在交互窗口中使用（这些限制会随着内容的深入被解除）。即按现在假定，当运行程序（目前来说，就是解释一个表达式）时，默认函数已经被解析可供使用。所以，我们给解释器添加一个参数——函数定义的集合。

> 注意这里我们说的是函数集合，即，函数的定义中可以引用任意其它函数；这是我一个有意的设计。注意当你
> 设计自己的语言时，记住考虑这一点。

## 定义函数的数据表示

简单起见，我们仅考虑只有一个参数的函数。下面是一些 Racket 函数的例子：

```racket
(define (double x) (+ x x))
(define (quadruple x) (double (double x)))
(define (const5 x) 5)
```

函数的定义包含哪些内容？它包含一个名字（上面中的 `double`, `quadruple`, `const5`），我们将使用符号（symbol）类型表示（ `double` 等）它；其形参（ *formal parameter* ）也有个名字（`x`），也使用符号类型进行表示；最后还有个部分，函数体。我们后面会一步一步完善函数体的定义，现阶段考虑函数定义如下：

```racket
(define-type FuncDefC
  [fdC (name : symbol) (arg : symbol) (body : ExprC)])
```

所以函数体是什么呢？显然它应该是某种形式的算术表达式，且有时候应该可以使用`ArithC` 语言表示：例如，函数 `const5` 的函数体可以使用 `(numC 5)` 表示。但是要表示 `double` 函数的函数体需要更多东西：不仅需要加法（我们已经定义了），还需要 `x`。你可能会称它*变量* ，但是现在我们不使用该术语，我们叫它*标识符* 。

最后，我们看看 `quadruple` 的函数体，它包含另一种结构：函数调用（function application）。要特别注意 **函数定义** 和 **函数调用** 的区别。函数定义描述了函数是什么，而调用则是对函数的使用。里面一层的`double` 函数调用使用的参数是 `x` ； 外面的那层的 `double` 调用使用的参数是 `(double x)` 。可以看到，参数应该可以是任意复杂的表达式。

下面我们尝试把上面所有的东西糅合到解释器的基本数据类型定义中。显然我们选择扩展已有的语法（因为我们还想保留算术运算）。我们给新的数据类型一个名字：

```racket
(define-type ExprC
  [numC (n : number)]
  <idC-def> ;; 待实现
  <app-def> ;; 待实现
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)])
```

注意，*标识符*与形参关系紧密。当传递一个值作为参数来调用某个函数时，从效果来说实际上是将函数体中出现的形参实例替换为该值后计算函数体得值作为函数调用结果。为了简化这个搜索替换的过程，不妨使用与形参相同的数据类型来表示形参实例。而形参类型已经选好，于是：

```racket
  [idC (s : symbol)]
```

最后，函数调用。它包含两个部分：函数名和函数参数。上面已经说过函数的参数可以为任意合法的表达式（即也包含新增的标识符类型和其它函数调用类型）。至于函数名，让其保持和函数定义中的函数名类型一致符合直觉，就这样做吧。因此：

```racket
   [appC (fun : symbol) (arg : ExprC)]
```

该定义简单明了，函数名指明要调用哪个函数，然后后面提供函数调用所需参数。

使用该定义，之前的三个函数可以很容易的使用该数据类型表示：

- `(fdC 'double 'x (plusC (idC 'x) (idC 'x)))`
- `(fdC 'quadruple 'x (appC 'double (appC 'double (idC 'x))))`
- `(fdC 'const5 'x (numC 5))`

下面还需要选择函数定义集合的表示。使用列表这个类型去表示它是比较方便的。

> 注意这里我们使用了有序的列表来表示之前说过的无序的函数定义的集合。
> 测试实现阶段为了方便实现未尝不可，但是需要注意我们的程序不应该依赖列表的有序性。

## 开始实现解释器

> 这里将之前 `ArithC` 语言的解释器代码放在这方便查阅对比
>
> ```racket
> (define-type ArithC
>   [numC (n : number)]
>   [plusC (l : ArithC) (r : ArithC)]
>   [multC (l : ArithC) (r : ArithC)])
> 
> (define (parse [s : s-expression])
>   (cond
>     [(s-exp-number? s) (numC (s-exp->number s))]
>     [(s-exp-list? s)
>      (let ([sl (s-exp->list s)])
>        (case (s-exp->symbol (first sl))
>          [(+) (plusC (parse (second sl)) (parse (third sl)))]
>          [(*) (multC (parse (second sl)) (parse (third sl)))]
>          [else (error 'parse "invalid list input")]))]
>     [else (error 'parse "invalid input")]))
>
> (define (interp [a : ArithC]) : number
>   (type-case ArithC a
>              [numC (n) n]
>              [plusC (l r) (+ (interp l) (interp r))]
>              [multC (l r) (* (interp l) (interp r))]))
>
> (interp (parse (read)))
> ```

下面开始实现解释器。首先考虑我们的解释器输入是什么。之前，我们只需要传入一个表达式即可，现在它还需要额外传入一个函数定义列表。

```racket
(define (interp [a : ExprC] [fds : (listof FunDefC)]) : number
   ...)
```

稍微回顾一下我们前面实现的 `ArithC` 解释器。遇到数直接返回该数作为结果；遇到加法和乘法，递归的进行求解。相比之前的解释器，现在多了一个函数定义列表这个参数如何处理呢？由于表达式的解释过程既不需要添加也不需要移除函数定义，即函数定义集合保持不变，在递归解释时函数定义应该原封不动的进行传递。于是：

```racket
(define (interp [a : ExprC] [fds : (listof FunDefC)]) : number
  [numC (n) n]
  <idC-interp-case>
  <appC-interp-case>
  [plusC (l r) (+ (interp l fds) (interp r fds))]
  [multC (l r) (* (interp l fds) (interp r fds))])
```

下面尝试实现函数调用，首先我们需要根据函数名从函数定义中寻找到对应函数定义，我们可以实现下面这个帮助函数：

```racket
(define (get-fundef [n : symbol] [fds : (listof FunDefC)]) : FunDefC
  (cond
    [(empty? fds) (error 'get-fundef "reference to undefined function")]
    [(cons? fds) (cond
                   [(equal? n (fdC-name (first fds))) (first fds)]
                   [else (get-fundef n (rest fds))])]))
```

假设我们通过该函数找到了函数定义，下面需要计算其函数体。之前说过函数调用效果上等效于使用参数搜索替换函数体中参数实例后计算再函数体。这个搜索替换过程足够重要，值得花一小节介绍一下。

## 参数的搜索替换

参数的搜索替换是将一个表达式（这里指的是函数体）中名字（这里指的是形参）替换成其它表达式（这里指的是实参，即调用函数传入的值）的过程。

我们来写该过程帮助函数：

```racket
(define (subst [what : ExprC] [for : symbol] [in : ExprC]) : ExprC
  <subst-body>)
```

该函数的作用是将表达式 `what` 中的符号 `for` 替换成表达式 `in` 。

> 想一想：
>
> 考虑之前几个例子函数，将参数 `x` 替换为 `3` 结果是什么？

对于 `double` 函数来说，替换结果为 `(+ 3 3)`；对于 `quadruple`函数，结果为 `(double (double 3))`；对于函数 `const5`，结果就为 `5`（函数体中没有出现形参实例需要被替换）。

这个例子几乎涵盖了所有函数调用的情况。函数体就一个数的话，无需替换任何东西；函数体为一个不同于形参的标识符，你可能猜到了，保留之；其它情况下递归的替换各子表达式。

还要考虑一种情况，根据之前的设计，标识符可能作为一个函数的名字，**这种情况我们应该如何处理呢**？

对于这个问题，有很多解答。一种答案是从设计上来考虑的：即函数的名字有其自己的命名空间，它和程序中其它标识符不同。还有一些语言（如 C 和 Common Lisp）实现上则略有不同，它们会根据标识符使用的上下文的不同将其解析到不同的命名空间。而其它语言，则不做这些区分。

现在，我们从编程的角度来考虑这个问题。由于我们的表达式解释结果为数，意味着如果将函数的标识符解释成数将是最方便的。但是，要注意不能使用数对函数进行命名，只可以使用符号。

现在，我们可以写出搜索替换函数体了：

```racket
(define (subst [what : ExprC] [for : symbol] [in : ExprC]) : ExprC
  (type-case ExprC in
    [numC (n) in]
    [idC (s) (cond
              [(symbol=? s for) what]
              [else in])]
    [appC (f a) (appC f (subst what for a))]
    [plusC (l r) (plusC (subst what for l)
                        (subst what for r))]
    [multC (l r) (multC (subst what for l)
                        (subst what for r))]))
```

## 继续实现解释器

下面我们继续解释器的实现。函数调用的一个大头就是参数的搜索替换，上节我们已经完成（至少我们感觉已经完成）。于是很容易写出下面这样的代码：

```racket
  [appC (f a) (let ([fd (get-fundef f fds)]
                (subst a
                       (fdC-arg fd)
                       (fdC-body fd))))]
```

但是这是错的，看出为什么了吗？

观察一下该段代码的返回值，`subst`函数返回值是什么？表达式！解释器的结果应该是数，应该返回对搜索替换后的函数体解释的结果：

```racket
  [appC (f a) (let ([fd (get-fundef f fds)]
                (interp (subst a
                              (fdC-arg fd)
                              (fdC-body fd)
                        fds)))]
```

好了，还剩下一个基本类型需要解释器进行解释：标识符。我们该拿它怎么办，它看上去应该和数一样简单才对。但是既然把它留到了最后，你可能也猜到了它的处理可能有点微妙或者说有点复杂。

> 可以停一下，自己考虑应该如何处理标识符。

假设我们有一个函数 `double` 定义如下：

```racket
(define (double x) (+ x y))
```

在对 `(double 5)` 进行解释时，执行搜索替换后得到 `(+ 5 y)`，按上面实现的代码，对该结果进行解释即得到函数调用结果。但是剩下的 `y` 应该替换成什么呢？事实上从一开始我们就应该意识到这个 `double` 函数定义是有问题的。我们称 `y` 这个标识符为 **自由（free）的** 。换句话说，即解释器无法处理该标识符。所有标识符在解释代码过程中应该通过参数替换的方式被替换掉（换个专业点的名词，即参数**绑定**，与自由对应）。因此，当解释器直面一个标识符时，只能进行报错：

```racket
  [idC (_) (error 'interp "shouldn't get here")]
```

这样我们的解释器就完成了。照例，方便大家使用，我将该解释器代码贴在下面：

```racket
#lang plai-typed

(define-type ExprC
  [idC (s : symbol)]
  [appC (fn : symbol) (arg : ExprC)]
  [numC (n : number)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)])

(define-type FunDefC
  [fdC (name : symbol) (arg : symbol) (body : ExprC)])

(define (subst [what : ExprC] [for : symbol] [in : ExprC]) : ExprC
  (type-case ExprC in
    [numC (n) in]
    [idC (s) (cond
              [(symbol=? s for) what]
              [else in])]
    [appC (f a) (appC f (subst what for a))]
    [plusC (l r) (plusC (subst what for l)
                        (subst what for r))]
    [multC (l r) (multC (subst what for l)
                        (subst what for r))]))

(define (get-fundef [n : symbol] [fds : (listof FunDefC)]) : FunDefC
  (cond
    [(empty? fds) (error 'get-fundef "reference to undefined function")]
    [(cons? fds) (cond
                   [(equal? n (fdC-name (first fds))) (first fds)]
                   [else (get-fundef n (rest fds))])]))


(define (parse [s : s-expression]) : ExprC
  (cond
    [(s-exp-number? s) (numC (s-exp->number s))]
    [(s-exp-symbol? s) (idC (s-exp->symbol s))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (case (s-exp->symbol (first sl))
         [(+) (plusC (parse (second sl)) (parse (third sl)))]
         [(*) (multC (parse (second sl)) (parse (third sl)))]
         [else (appC (s-exp->symbol (first sl))
                     (parse (second sl)))]))]))

(define (interp [a : ExprC] [fds : (listof FunDefC)]) : number
  (type-case ExprC a
    [numC (n) n]
    [idC (_) (error 'interp "shouldn't get here")]
    [appC (fn arg) (let ([f (get-fundef fn fds)])
                     (interp (subst arg (fdC-arg f) (fdC-body f))
                             fds))]
    [plusC (l r) (+ (interp l fds) (interp r fds))]
    [multC (l r) (* (interp l fds) (interp r fds))]))


;; 下面读取一个输入并解释
(interp (parse (read))
        (list (fdC 'double 'x (plusC (idC 'x) (idC 'x)))
               (fdC 'quadruple 'x (appC 'double (appC 'double (idC 'x))))))
;; 输入 (+ 2 (double (quadruple 10))) 得到 82
```

## 注意，还有个重要的东西！

考虑对于我们上面 `subst` 的实现，其类型如下：

```racket
; subst : ExprC * symbol * ExprC -> ExprC
```

在解释 `(double (+ 1 2))` 时会发生什么，很简单——它会执行搜索替换操作然后得到：

```racket
(+ (+ 1 2) (+ 1 2))
```

这可能是我们不太想看到的，因为同一个表达式将会被解释计算两次。你可能会想到，我们可以先计算参数的结果在对参数结果执行搜索替换操作。这样的话，搜索替换函数的类型就变成了：

```racket
; subst : number * symbol * ExprC -> ExprC
```

> 读者可以修改上面的编辑器使用这种搜索替换方式

注意我们这里遇到的问题是程序语言中一个基本设计抉择。在搜索替换前计算参数结果的行为被称为是贪婪的（eager application），对应的被称为惰性的（Lazy）——它有很多变种。我们这里倾向于使用贪婪的实现，这也是大部分主流语言使用的方式；后面会再介绍到贪婪求值及其应用。

> 注意，其实我们这里的 `subst` 还是有问题的，这里没有处理被称为“名字捕获（name capture）”的问题。
> 解决这个问题比较复杂，解决方式比较微妙，我们会在本书的推进过程中渐渐介绍其解决。如果你迫不及待了，可以
>去自行去了解并学习 lambda calculus

---

这一章在我们的算术语言中引入了函数，使用替换模型实现了函数的求值，非常有意思，再后面一节会更进一步，引入函数求值的环境模型，欢迎继续关注。
