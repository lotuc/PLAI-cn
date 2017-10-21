# 2 本书有关语法分析的一切

语法分析（parsing）是将输入字符流转换成结构化内部表示的过程。常见的内部表示是树 ，可以使用程序递归的处理树这种数据结构。例如，给定输入流：

```text
23 + 5 - 6
```

我们可以将其转换成一颗根节点为加法，左边节点表示数字 `23` ，右边节点是用树表示 `5-6` 的树。语法分析机器（parser）是用于实现这种转换的程序。

![](./imgs/img0.png)

语法分析本身是一个比较复杂，且由于歧义的存在，还远没有被解决的问题。例如上面的例子，你还可以将其转换成根节点为减法，左边为表示 `23+5` 的树，右边为数字 `6` 的树。

![](./imgs/img1.png)

我们还需要考虑操作符（ `+` ， `-` ）的优先性、两个操作数的交换性等问题。要解析一个羽翼丰满的语言（说的不是自然语言），要考虑的问题只会越来越多、越来越复杂。

## 2.1 轻量级的，内建的语法分析器的前半部分

这些问题使得语法分析本身适合当作一个单独主题来讲，本书主题不专注于该方面。从我们的角度来说，语法分析是一层抽象，因为我们想学习的是编程语言的各个部分而不是语法分析本身。因此，我们使用 Racket 一个有用的特性来将输入流转换成树：read 。 read 和该语言的括号语法形式紧密关联。它将括号形式转换成内部树形式。运行 `(read)` 然后输入 ——

```racket
(+ 23 (- 5 6))
```

——会产出一个列表，其第一个元素是符号 `'+` ，第二个元素是数字 `23` ，第三个元素是一个列表；该列表其第一个元素是符号 `'-` ，第二个元素是数字 `5` ，第三个元素是数字 `6`。

## 2.2 快捷方式

你的程序都会需要反复测试，而每次都需要手工输入会很麻烦。你可能猜得到，括号表达式可以在Racket中用 _引号_ 来表达，也就是你刚才看到的 `'<expr>` 形式——其效果和运行 `(read)` 然后输入 `<expr>` 一样。 

## 2.3 语法分析得到的类型

事实上，我之前的描述并不准确。之前说 `(read)` 会返回列表等类型。在Racket中确实如此，但在 Typed PLAI 中，事情稍有不同， `(read)` 返回值类型为 s-expression （符号表达式的简写）。

```racket
> (read)
- s-expression
[type in (+ 23 (- 5 6))]
'(+ 23 (- 5 6))
```

Racket包含了一个强大的 s-expression 系统，其语法还甚至可以表达带循环的结构。不过我们只会用到其中的一部分。

在静态类型的语言中，s-expression被认为是和其他类型（例如数字、列表）都不同的数据。在计算机内部，s-expression是一种递归数据结构，其基本结构是原子值——例如数字、字符串、符号，组合形式可以是表、向量等。因此，原子值（数字、字符串、符号等）即是其自由类型，也是一种s-expression。这就造成了输入的歧义，我们后文讨论。

Typed PLAI 采取一种简单的方式来处理这种歧义：当直接输入时，原子结构就是它本身的类型；当输入为一个大结构的一部分时——包括read或者引用——它们就是s-expression类型。你可以通过类型转换将其转换为基本类型。例如：

```racket
> '+
- symbol
'+
> (define l '(+ 1 2))
> l
- s-expression
'(+ 1 2)
> (first l)
. typecheck failed: (listof '_a) vs s-expression in:
  first
  (quote (+ 1 2))
  l
  first
> (define f (first (s-exp->list l)))
> f
- s-expression
'+
```

这方面和Java程序的类型转换类似。我们后文再学习类型转换。

请注意，表结构的第一个元素的类型并不是符号：一个表形式的s-expression是一个由s-expressions组成的表。因此，

```racket
> (symbol->string f)
. typecheck failed: symbol vs s-expression in:
  symbol->string
  f
  symbol->string
  f
  first
  (first (s-exp->list l))
  s-exp->list
```

类型转换：

```racket
> (symbol->string (s-exp->symbol f))
- string
"+"
```

必须对s-expressions进行类型转换确实是一个麻烦事，但是某种程度的麻烦是不可避免的：因为我们的目的是把 _没有类型的_ 输入，通过严谨的 _类型_ 分析，转化为 _有类型_ 的。所以有些关于输入的假设必须明文列出。

好在我们只在语法分析中使用s-expressions，而我们的目的是 _尽快处理完语法分析_ ！所以，这一点只会帮助我们尽快摆脱语法分析。

## 2.4 完整的语法分析器

原则上 `read` 就是一个完整的语法分析器。不过其输出过于一般化：结构体中并不包含其意向的注释信息。所以我们倾向于使用一种更具体的表达方式，类似于前文中“表达加法”和“表达数字”的那种。

首先我们必须引入一种数据结构来表示这类关系。后文（第三章）会详细讨论为啥采用这种数据结构，还有我们如何得出该数据结构。现在请先假设它是给定的：

```
(define-type ArithC
  [numC (n : number)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])
```

目标是将 racket 给我们初步解析得到 s-expression 解析成该数据类型，代码简单直接：

```racket
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
```

注意，为简便起见，这里的代码有些东西没有考虑，比如我们只考虑了两位数的加法和乘法，且没有对传入参数的个数进行校验。简单运行如下：

```racket
> (parse (read))
- ArithC
(+ (* 2 3) (+ 3 6))
(plusC (multC (numC 2) (numC 3)) (plusC (numC 3) (numC 6)))
```

到此我们完成一个简单的语法分析器！虽然它的大部分工作是由 `read` 函数替我们做的，但是我们的代码成功的将输入程序解析成了自己定义的内部表示。

__习题__

> 如果传给语法分析器的参数忘了加引号，后果是啥？为什么？


## 2.5 结尾

Racket的语法继承自Scheme和Lisp，不乏争议。不过请观察它给我们带来的深层次好处：对传统语法进行解析会很复杂，而解析这种语法简单明了，不管是从字符流到s-expressions的解析还是进一步到语法树（前文的例子）的解析。

这种语法的好处就是其多用途性。需要的代码少，而且可以方便的插入各种应用场景。所以很多基于Lisp的语言其语义各不相同，但都保留了历史继承而来的这种语法。

当然，我们也可以采用XML，它更好用；或者JSON，它和s-expression有着本质的不同！
