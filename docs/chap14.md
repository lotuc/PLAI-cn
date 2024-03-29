# 14 控制指令

术语**控制**指的是编程语言中任何使得计算过程前进的指令，因为它“控制”了计算机的程
序计数器（program counter）。从这个意义上说，即使是简单的算术表达式也应该被认为
是一种“控制”，而像顺序执行、函数调用和返回这样的操作，就更应该是了。不过，实践中
我们通常用这个名词指代那些导致控制**非局部**转移的——尤其是除了函数、过程以及将要
学到的异常（exception）之外的——指令。本章我们将学习这类指令。

在研究这些控制指令时，需要指出的是，即使没有它们，我们的语言也是图灵完备的，也就
是说我们并没有获得额外的“能力”。因此，控制指令所做的是，改变、改善我们的表达方式
，从而增强程序的结构。所以，专注于程序的结构有益于本章的学习。

## 14.1 Web 上的控制

让我们从研究 Web 程序的结构开始。考虑下面的程序：【注释】

```Racket
(display
  (+ (read-number "First number")
     (read-number "Second number")))
```

> 今后，我们将把它称为“加法服务”。当然，你应该将它理解为更为复杂应用的一个简化版
> 。例如，应用可能提示输入的是旅程的起点和目的地，加法对应的实际服务可能是根据输
> 入的起点终点计算航线或者机票的价格。在两个（输入）步骤之间甚至可能也有计算：例
> 如，在输入第一个城市后，航空公司可能会提示我们可供选择的目的地。

为了测试这些想法，下面是 read-number 的实现：

```Racket
(define (read-number [prompt : string]) : number
  (begin
    (display prompt)
    (let ([v (read)])
      (if (s-exp-number? v)
          (s-exp->number v)
          (read-number prompt)))))
```

在控制台或 DrRacket 中运行时，该程序会提示我们输入一个数字，然后输入另一个数字，
最后显示它们的总和。

现在假设我们想在 Web 服务器上运行。我们立即遇到难点：服务器端 Web 程序的结构是这
样的：它们生成一个网页，比如请求第一个数字的网页，然后**停止**。结果，**程序的其
余部分**——在这里，提示第二个数字，然后求和，然后打印结果——丢失了。

**思考题**

> 为什么 Web 服务器的行为如此奇怪？

这种行为至少有两个原因：一个也许是历史的，另一个是技术的。历史原因是 Web 服务器
最初设计为供应**页面**，即静态内容。任何程序的运行都必须将其输出生成为文件，服务
器将该文件提供给客户端。很自然的，开发人员想到为什么同样的程序在 web 上就不能按
需运行。于是，后来 Web 上出现了**动态**内容。构成 Web 应用的最小增量单元不再是页
面，而是一个个执行结束后生成页面各个部分所需内容的程序。

更重要的原因——也是导致目前状况的原因——是技术性的。想象一下，我们的加法服务器已经
生成了第一个提示。回想一下，有相当多的计算要进行：第二个提示，求和和显示结果。这
些计算必须暂停，等待用户的输入。如果有成千上万的用户，那么必须暂停成千上万的计算
，这会产生巨大的性能问题。此外，假设用户实际上没有完成计算——类似于在网上书店或航
空公司网站上搜索，而不完成购买。服务器如何知道何时终止计算，甚至是否终止计算？而
在终止之前，与该计算相关的资源仍被占用。

因此，Web 协议从其概念上就被设计为**无状态的**（stateless）：它不将与中间计算相
关的状态存储在服务器上。这使得 Web 程序员被迫在其他地方维护所有必要的状态，每个
请求都需要携带能够完全恢复计算所需的状态。在实践中，Web 并不都是完全无状态的，但
是它们在很大程度上倾向这个方向，因此研究这类程序的结构是非常有教益的。

接下来考虑一下客户端的 Web 程序：那些在浏览器中运行的程序，通常用 JavaScript 编
写，或被编译成 JavaScript。假设某个计算需要与服务器进行通信。（JavaScript 提供的
）指令为 XMLHttpRequest。用户创建这个指令的实例，然后调用其`send`方法向服务器发
送消息。然而，与服务器通信并不是即时的（并且根据网络的状态，实际上可能永远不会完
成）。这导致发送进程被挂起。

JavaScript 的设计者决定让该语言是**单线程**的，即，任意时间只能有一个线程在执行
。【注释】这避免了赋值与线程结合而产生的各种风险。因此，JavaScript 进程会被锁定
以等待响应，这期间不可能做任何其他事情：例如，页面上的其他处理程序不再响应。

> 因为这会导致结构性问题，现在有各种提议，实际上是要为 JavaScript 添加“安全的”线
> 程。本章所描述的想法可以被看作是另一种方案，提供类似的结构优势。

为了避免这个问题，XMLHttpRequest 的设计要求开发者提供一个函数来响应请求（请求到
达时将调用该程序）。该回调函数在系统中注册。需要传递请求结果给该回调函数让其完
成**后续处理过程**。因此，并非处于性能方面的考虑，而是为了避免同步、非原子性和死
锁问题，客户端 Web 也发展出相同的程序模式。让我们更好地理解这种模式。

### 14.1.1 将程序分解成现在和以后

我们来考虑如何让上述程序在无状态的环境下——比如在 Web 服务器上——工作。首先我们需
要确定**第一个**交互，是提示输入第一个数字，因为 Racket 从左到右计算参数。将程序
分成两部分是有益的：第一个交互产生啥（现在就可以运行），以及之后需要发生什么（必
须以某种方式“记住”）。前者很容易：

```Racket
(read-number "First number")
```

我们已经用文字解释过剩下的东西了，但是现在是时候把它写成程序了。似乎应该类似于【
注释】

```Racket
(display
  (+ <第一个交互的返回值>
     (read-number "Second number")))
```

> 我们现在故意忽略 read-number 部分，但会回过来讨论它。现在，我们假设它是内置的
> 。

但是，Web 服务器不能执行这个东西，因为它显然不是**程序**。我们需要一种方式将其写
成程序。

观察一下这个计算的特点：

- 它是合法的程序。
- 它需要保持暂停状态，直到请求进入。
- 它需要某种方式——例如参数——来引用前一个交互的值。

综合这些特点，显然我们应该将其表示为函数：

```Racket
(lambda (v1)
  (display
    (+ v1
       (read-number "Second number"))))
```

### 14.1.2 部分的解决方案

在 Web 上，还有个额外的问题：每个带有输入元素的 Web 页面都需要引用存储在 Web 上
的程序，该程序将从表单接收数据并对其进行处理。这个程序是在表单的 action 字段中指
明的。因此，设想服务器生成一个新的标签，将前述函数存储在与该标签相关联的表格中，
并且在 action 字段中引用该表格。如果客户端最终提交了表单，这个时候，服务器提取出
关联的函数，向其提供表单的值，从而恢复执行。

**思考题**

> 上述方案是无状态的吗？

假设我们在自定义的 Web 服务器上维护这么一个表格。在这个服务器上，可能会有一个特
殊版本的 read-number，称之为 call-read-number/suspend，记录程序的其余部分：

```Racket
(read-number/suspend "First number"
                     (lambda (v1)
                       (display
                        (+ v1
                           (read-number "Second number")))))
```

为了测试，我们来实现这个子程序。首先，我们需要标签的表示法；用数字就好：

```Racket
(define-type-alias label number)
```

假设`new-label`在每次调用时都会生成新标签。

**练习**

> 定义`new-label`。需要的话参考`new-loc`以获得灵感。

需要一个表，来存储代表程序其余部分的子程序。

```Racket
(define table (make-hash empty))
```

存储这些子程序：

```Racket
(define (read-number/suspend [prompt : string] rest)
  (let ([g (new-label)])
    (begin
      (hash-set! table g rest)
      (display prompt)
      (display " To enter it, use the action field label ")
      (display g))))
```

现在运行上面的 read-number/suspend 调用，系统会打印

```Racket
First number To enter it, use the action field label 1
```

这就相当于，在 Web 页面中打印提示，并在 action 字段中放入“标签 1”。因为我们在模
拟网页，需要有个东西来表示浏览器的提交过程。这里需要标签（来自 action 字段）和表
单中输入的值。给定了这两个值，这个子程序需要从表中提取出相关子程序，并将其应用于
表单值。

```Racket
(define (resume [g : label] [n : number])
  ((some-v (hash-ref table g)) n))
```

有了这些，我们现在可以模拟输入 3 并点击“提交”按钮的行为，运行：

```Racket
> (resume 1 3)
```

其中 1 是标签，3 是用户输入。不幸的是，这么做只会产生另一个提示，因为我们还没有
完成程序的转换。要去除 read-number，我们需要转换整个程序：

```Racket
(read-number/suspend "First number"
                     (lambda (v1)
                       (read-number/suspend "Second number"
                                            (lambda (v2)
                                              (display
                                               (+ v1 v2))))))
```

为了安全起见，我们还可以在 read-number/suspend 结束的地方添加报错，从而确保计算
在每次输出之后终止（以确保“挂起”的最极端形式）。

执行这个程序时，必须两次使用 resume：

```Racket
First number To enter it, use the action field label 1
halting: Program shut down
> (resume 1 3)
Second number To enter it, use the action field label 2
halting: Program shut down
> (resume 2 10)
13
```

其中两次用户输入分别是 3 和 10，总和给出是 13，而

```Racket
halting
```

信息是我们添加的报错命令生成的。

我们故意略去了程序中某些有趣部分的类型。来看看这些类型应该是什么
。read-number/suspend 的第二个参数是读入数字并返回最终结果的子程序
：`(number -> 'a)`。同样，resume 的返回类型也是`'a`。这些`'a`如何相互沟通？是通
过将标签映射到`(number -> ’a)`的表完成的。也就是说，计算过程中的每一步都产生相同
类型的结果。`read-number/suspend`写入表中，`resume`从表中读取。

### 14.1.3 实现无状态

实际上我们并没有实现无状态，因为服务器上有一大张表，而我们缺乏明确手段去除此表。
如果可以完全避免服务器上的状态就好了。这意味着我们必须将相关的状态移交给客户端。

服务器实际上以两种方式持有了状态。其一，可以存放任意多个——而不是常数个（比如线性
相关于程序本身的大小）——条目的哈希表，。其二，我们在表中存放的是实实在在的闭包，
而闭包中可以保有任意数量的状态。我们很快就会更清楚地看到这一点。

先从消除闭包开始着手。我们可以把所有的函数参数改成实名的全局函数（这迫使我们只会
拥有有限个闭包，因为程序的长度不可能是无限的）：

```Racket
(read-number/stateless "First number" prog1)

(define (prog1 v1)
  (read-number/stateless "Second number" prog2))

(define (prog2 v2)
  (display (+ v1 v2)))
```

注意到每块代码都只引用下一块代码的名称，而没有引入真正的闭包。参数的值来自于表单
。唯一的问题是：prog2 中的 v1 是未绑定的标识符！

解决这个问题的方法是，不要在每一步之后创建闭包，而是将 v1 发送到客户端并存储在那
里。存储在哪里呢？浏览器为此提供了两种机制：**Cookie**和**隐藏字段**。我们用哪一
个？

### 14.1.4 与状态互动

Cookie 和隐藏字段之间的本质区别是，**所有页面共享相同的 cookie，但每个页面都包含
自己的隐藏字段**。

先来考虑与现有程序的一串交互，（在两个地方都）使用 read-number/suspend。就像这样
：

```Racket
First number To enter it, use the action field label 1
> (resume 1 3)
Second number To enter it, use the action field label 2
> (resume 2 10)
13
```

因此，恢复标签 2 似乎表示将 3 加到给定的参数（即，表单字段值）。保险起见，

```Racket
> (resume 2 15)
18
```

一切正常。现在假设我们再次使用标签 1：

```Racket
> (resume 1 5)
Second number To enter it, use the action field label 3
```

注意，需要使用标签 3，而不是标签 1 来恢复这个新的程序执行。的确，

```Racket
> (resume 3 10)
15
```

但是我们应该问，如果重用标签 2 会发生什么？

**思考题**

> 试试`(resume 2 10)`。

这就是恢复之前的计算。因此，我们期望它产生和之前一样的结果：

```Racket
> (resume 2 10)
13
```

现在来创建一个有状态的实现。通过共享一个可变状态但是拥有自己环境的闭包可以模拟这
种行为。所以我们可以这样做，使用现有的 read-number/suspend，但是不依赖 lambda 的
闭包行为，即不使用任何自由变量。

```Racket
(define cookie '-100)

(read-number/suspend "First number"
                     (lambda (v1)
                       (begin
                         (set! cookie v1)
                         (read-number/suspend "Second number"
                                            (lambda (v2)
                                              (display
                                               (+ cookie v2)))))))
```

**练习**

> 对于之前的交互序列，现在的**期望**值是啥？

**思考题**

> 计算过程是什么样的？

起初，似乎没啥不同：

```Racket
First number To enter it, use the action field label 1
> (resume 1 3)
Second number To enter it, use the action field label 2
> (resume 2 10)
13
```

当再次使用最初的计算时，我们确实得到新的恢复标签：

```Racket
> (resume 1 5)
Second number To enter it, use the action field label 3
```

使用新标签时，计算结果如我们所期望的：

```Racket
> (resume 3 10)
15
```

关键的一步来了：

```Racket
> (resume 2 10)
15
```

标签 2 的两次恢复产生了不同的答案，这一点不足为奇，因为它们依赖于可变状态。问题
是，当我们将相同的行为转换到 Web 时会发生什么。

想象一下，访问某旅馆预订网站，寻找某个城市的旅馆。返回的网页中，你看到一个旅馆的
链表和标签 1。你在新（浏览器）标签或窗口中浏览其中的一个旅馆；这个页面中生成了那
个旅馆的信息，还有标签 2 用作预订旅馆。然而，你返回旅馆链表，并在新的标签或窗口
中查看了另一家旅馆。这产生了第二家旅馆的信息，还有标签 3 用作该旅馆的预订。然而
，你决定选择第一家旅馆，返回第一家旅馆的页面，然后选择预订按钮，也就是提交了标签
2。你想要预订的是哪家旅馆？尽管你预期订的是**第一家**，大多数旅游网站上，你要么
预订了**第二家**旅馆——即最后查看的，而不是预订按钮所在的网页上的那家——要么被报告
错误。这是因为在 Web 站点普遍使用了 cookie，这是大多数 Web API 所鼓励的做法。

## 14.2 Continuation 传递模式

之前所说的函数是有名称的。虽然用 Web 描述问题，但是我们用的是更古老的概念：这类
函数被称为**continuation**（延续），而这种风格的程序被称为**continuation-passing
style**（Continuation 传递模式，简称 CPS）。【注释】这值得研究一下，因为它是学习
其他各种非平凡控制指令——如生成器——的基础。

> 我们会自由地将 CPS 当作名词和动词使用：一种特定的代码模式，将代码转化为此种模
> 式。

此前，我们将程序转化为，没有 Web 输入操作嵌套在另一个中。动机很简单：当程序终止
时，所有嵌套的计算都会丢失。对于 XMLHttpRequest 来说，类似的论据（在程序本地意义
上）成立：所有依赖于 Web 服务器响应结果的计算，都需要驻留在对服务器请求相关联的
回调中。

事实上，我们并不需要转化**每一个**表达式。只需要处理涉及实际 Web 交互的表达式。
比如说，如果要进行的计算不是加法，而是比它复杂得多的数学表达式，这个数学表达式我
们是不需要转换的（不涉及 Web 交互）。不过，如果这里有个函数调用，那么我们必须绝
对确定这个函数、它调用的函数、这些函数调用的函数（整个调用链）中不存在任何的 Web
调用，才可以不对它进行转换。否则，保险起见，我们必须转化所有的这些函数。总之，我
们必须转化每个我们无法确定不执行任何 Web 交互的表达方式。

因此，这里转化的核心就是把每个单参数函数`f`转换成具有额外参数的函数。这个额外的
参数就是 continuation，代表了其余的计算。Continuation 本身也是单参数的函数。这个
参数的输入是`f`**本来的**返回值，后续计算本来需要使用这个返回值继续。转换后`f`将
不再**返回**值，而是将原来的返回值**传递给**它的 continuation。

CPS 是种通用的转化，可以作用在任何程序上。因为它是一种程序转换，所以我们可以把它
看作是特殊的去语法糖：特别之处是，它不是把程序从大语言转化到小语言（类似于宏），
或者从一种语言转化到另一种语言（就像编译器那样），而是在**同一种**语言中的程序转
换：从完整语言转化到受限制的形式，遵从这里讨论的模式。因此，我们可以使用完整语言
的求值器对 CPS 程序求值。

### 14.2.1 用去语法糖实现

我们已经对去语法糖有了很好的支持，所以我们来它来定义 CPS 转换。具体来说，我们将
实现 CPS 宏。为了更加干净地将源语言与目标语言分开，我们所使用的大部分语言结构都
会用略有不同的名称：单变量的 rec 和 with 而不是 let 和 letrec；lam 而不是
lambda；cnd 而不是 if；seq 取代 begin；set 取代 set!。这会是足够丰富的语言，可以
编写一些有趣的程序！

> 后文中宏的子句按照我认为从容易到困难的顺序排列。但是，宏定义的代码必须避免模式
> 的重复，因此遵循不同的顺序。

```Racket
<cps-macro> ::=  ; CPS 宏

    (define-syntax (cps e)
      (syntax-case e (with rec lam cnd seq set quote display read-number)
        <cps-macro-with-case>
        <cps-macro-rec-case>
        <cps-macro-lam-case>
        <cps-macro-cnd-case>
        <cps-macro-display-case>
        <cps-macro-read-number-case>
        <cps-macro-seq-case>
        <cps-macro-set-case>
        <cps-macro-quote-case>
        <cps-macro-app-1-case>
        <cps-macro-app-2-case>
        <cps-macro-atomic-case>))
```

我们的 CPS 表示法会将**每个**表达式转变成单参数的函数，参数就是 continuation。转
换后的表达式最终要么提供值调用 continuation，要么将 continuation 传递给其他表达
式，归纳地说，其他表达式也遵从这个不变量关系，因此最终 continuation 会被提供某个
值。所以说，所有的 CPS 输出看起来都类似于`(lambda (k) ...)`（我们将依赖卫生来保
证所有引入的 k 不会相互冲突）。

首先，我们来处理简单的情况，原子值。尽管概念上来说它是最简单的，但是我们将其放在
最后一项，因为放在前面的话它会遮盖掉其他匹配。（理想情况下，我们应该将其放在第一
个位置，然后提供一个能精确定义我们原子值的匹配表达式，这里放宽要求是因为我们对其
他情况更为关心。）原子值的情况中，我们已经有一个值，将其传递给 continutaion 即可
：

```Racket
<cps-macro-atomic-case> ::=  ; 原子

    [(_ atomic)
     #'(lambda (k)
         (k atomic))]
```

被引用的常量也一样处理：

```Racket
<cps-macro-quote-case> ::=

    [(_ 'e)
     #'(lambda (k) (k 'e))]
```

我们还知道，with 和 rec 可以当作宏来处理：

```Racket
<cps-macro-with-case> ::=

    [(_ (with (v e) b))
     #'(cps ((lam (v) b) e))]

<cps-macro-rec-case> ::=

    [(_ (rec (v f) b))
     #'(cps (with (v (lam (arg) (error 'dummy "nothing")))
                  (seq
                   (set v f)
                   b)))]
```

赋值也是容易的：先求出新的值，然后再执行实际的更新操作：

```Racket
<cps-macro-set-case> ::=

    [(_ (set v e))
     #'(lambda (k)
         ((cps e) (lambda (ev)
                    (k (set! v ev)))))]
```

序列指令也是直白的：依次执行每个操作。请注意我们保持了序列的语义：不仅遵守了操作
的顺序，第一个子项（e1）的值在第二个（e2）的计算中不会被用到，所以该值所绑定到的
标识符的名称也就无关紧要。

```Racket
<cps-macro-seq-case> ::=

    [(_ (seq e1 e2))
     #'(lambda (k)
         ((cps e1) (lambda (_)
                     ((cps e2) k))))]
```

处理条件指令时，需要创建新的 continuation，用来记住我们在等待条件表达式的求值结
果。不过，一旦获得了其值，根据其值的不同我们可以选择进入已有的 continuation 分支
。

```Racket
<cps-macro-cnd-case> ::=

    [(_ (cnd tst thn els))
     #'(lambda (k)
         ((cps tst) (lambda (tstv)
                      (if tstv
                          ((cps thn) k)
                          ((cps els) k)))))]
```

处理函数调用时，有两种情况需要考虑。我们必须要处理语言中创建的函数，也就是单参数
函数。然而，为了编写示例程序，能够使用诸如+和\*之类的指令很有用。因此，**为了简
单起见**，我们将**假定**单参数函数是用户编写的，因此需要 CPS 转换，而双参数函数
是不会执行任何 Web 或其他控制操作的指令，因此可以直接调用； 我们**还**假定原生指
令可以直接写出（即，函数位置不是复杂表达式，本身不会执行 Web 交互）。

对于函数调用，我们必须先对函数和参数表达式求值，一旦获取了这些就可以实际进行函数
的调用。因此我们很容易将函数调用的转换写成这样：

```Racket
<cps-macro-app-1-case-take-1> ::=

    [(_ (f a))
     #'(lambda (k)
         ((cps f) (lambda (fv)
                    ((cps a) (lambda (av)
                               (k (fv av)))))))]
```

**思考题**

> 你看出为什么这是错的吗？

问题在于，虽然函数现在是值了，也就是闭包，其函数体可以很复杂：比如说，对函数体求
值可以导致进一步的 Web 交互，此时函数体的其余部分，包括待处理的`(k ...)`（即程序
的其余部分）将全部丢失。为了避免这种情况，我们必须把 k 提供给函数的值，让归纳不
变量保证 k 最终会被调用于 fv 作用于 av 的得到的值：

```Racket
<cps-macro-app-1-case> ::=

    [(_ (f a))
     #'(lambda (k)
         ((cps f) (lambda (fv)
                    ((cps a) (lambda (av)
                               (fv av k))))))]
```

处理内置双目操作的特殊情况比较容易：

```Racket
<cps-macro-app-2-case> ::=

    [(_ (f a b))
     #'(lambda (k)
         ((cps a) (lambda (av)
                    ((cps b) (lambda (bv)
                               (k (f av bv)))))))]
```

用户定义的函数不能使用这个模式，因为我们假设这里 f 的调用总是会返回，而不进行任
何不寻常的控制转移。

函数本身就是一种值，该值本身应该被返回给挂起的计算（一个 continuation）。然而，
前面函数调用的情况表明，函数转化后需要传入额外的参数——调用点的 continuation。这
就留下一个问题：该向函数体提供哪个 continuation？

```Racket
<cps-macro-lam-case-take-1> ::=

    [(_ (lam (a) b))
     (identifier? #'a)
     #'(lambda (k)
         (k (lambda (a dyn-k)
              ((cps b) ...))))]
```

也就是说，在这里的...位置上，我们该填入 k 还是 dyn-k？

**思考题**

> 该填入哪个 continuation 呢？

前者是**闭包创建位置**的 continuation。后者是**闭包调用位置**的 continuation。换
一种说法，前者是“静态的”，后者是“动态的 ”。这里，我们需要使用动态的
continuation，否则会发生非常奇怪的事情：程序会返回到创建闭包的地方，而不是它被使
用的地方！这会导致非常奇怪的程序行为，所以我们避免这么做。请注意，这里我们有意识
地选择动态的 continuation，就如同在处理作用域时，我们选择了静态的环境。

```Racket
<cps-macro-lam-case> ::=

    [(_ (lam (a) b))
     (identifier? #'a)
     #'(lambda (k)
         (k (lambda (a dyn-k)
              ((cps b) dyn-k))))]
```

最后，为了建模 Web 编程的目的，我们需要添加输入和输出指令。输出遵循前述函数调用
的模式：

```Racket
<cps-macro-display-case> ::=

    [(_ (display output))
     #'(lambda (k)
         ((cps output) (lambda (ov)
                         (k (display ov)))))]
```

对于输入，使用现有的 read-number/suspend 就可以了，不过这里由我们来**生成**其使
用，而不是让程序员来创建：

```Racket
<cps-macro-read-number-case> ::=

    [(_ (read-number prompt))
     #'(lambda (k)
         ((cps prompt) (lambda (pv)
                         (read-number/suspend pv k))))]
```

请注意，绑定为 k 的 continuation 就是在 Web 交互处我们需要存储的 continuation。

测试 CPS 转换后的代码有些小麻烦，因为所有 CPS 项都需要读入 continuation。最初的
continuation 可以是（a）读入值并返回它，或者（b）读入值并打印它，或者（c）读入值
，打印它并准备好进行下一个计算（DrRacket 的交互窗口就是这么做的）。这三者其实都
只是恒等函数的变体。所以，我们定义以下函数辅助测试：

```Racket
(define (run c) (c identity))
```

例如，

```Racket
(test (run (cps 3))                           3)
(test (run (cps ((lam ()    5)       )))      5)
(test (run (cps ((lam (x)   (* x x)) 5)))     25)
(test (run (cps (+ 5 ((lam (x) (* x x)) 5)))) 30)
```

也可以测试之前的 Web 程序：

```Racket
(run (cps (display (+ (read-number "First")
                      (read-number "Second")))))
```

为了避免你迷失在众多代码之中，我强调一下这里的重点：**我们恢复了代码的结构**。换
种说法，即借由恰当的嵌套表达式以及帮助将其翻译以使其可以和底层 API 协作的代码的
编译器（本例中即 CPS 转换程序），我们得以使用**直述的风格（direct style）**编写
程序。这正是优秀的编程语言所应做的！

### 14.2.2 例子的转化

让我们来看看上面的例子是怎么转换的。你可以手工操作，也可以采取简单的办法，用
DrRacket 的 Macro Stepper（宏步进器）完成。【注释】放入 run 函数传入的恒等函数，
我们得到：

```Racket
(lambda (k)
  ((lambda (k)
     ((lambda (k)
        ((lambda (k)
           (k "First")) (lambda (pv)
                          (read-number/suspend pv k))))
      (lambda (lv)
        ((lambda (k)
           ((lambda (k)
              (k "Second")) (lambda (pv)
                              (read-number/suspend pv k))))
         (lambda (rv)
           (k (+ lv rv)))))))
   (lambda (ov)
     (k (display ov)))))
```

> 这里，为了获取的 Macro Stepper 的全部功能，请使用`#lang racket`语言。

什么！这和我们手写的版本完全不同！

实际上，这个程序中充满了所谓的**管理性**lambda（administrative lambda），由我们
所用的 CPS 算法引入。【注释】请不用担心！如果我们逐一调用这些 lambda，完成替代，
那么——

**思考题**

> 完成此步。

——这个程序会简化为

```Racket
(read-number/suspend "First"
                     (lambda (lv)
                       (read-number/suspend "Second"
                                            (lambda (rv)
                                              (identity
                                               (display (+ lv rv)))))))
```

这正是我们想要的。

> 设计更好的 CPS 算法，消除不必要的管理性 lambda，是个研究前沿问题。

### 14.2.3 在核心中实现

在研究了通过去语法糖实现 CPS 之后，我们应该问问，是否可将其以放在核心中。

回想一下，我们说过 CPS 适用于任何程序。有一个我们特别感兴趣的程序：解释器。显然
，我们可以将 CPS 转换应用于其上，从而获得事实上的 continuation。

首先，这里使用函数来表示闭包较为方便（译注，12.1 节）。我们让解释器读入多读入一
个参数，该参数读入值（需要传给 continuation 的那些值）并最终返回它们：

```Racket
<cps-interp> ::=             ; CPS 解释器

    (define (interp/k [expr : ExprC] [env : Env] [k : (Value -> Value)]) : Value
      <cps-interp-body>)     ; CPS 解释器主体
```

对于简单的情况，我们不直接返回值，而是将其传递给 continuation 参数即可：

```Racket
<cps-interp-body> ::=

    (type-case ExprC expr
      [numC (n) (k (numV n))]
      [idC (n) (k (lookup n env))]
      <cps-interp-plusC-case>
      <cps-interp-appC-case>
      <cps-interp-lamC-case>)
```

（请注意，multC 的处理完全类似于 plusC。）

还是从简单的情况开始，plusC。第一步我们解释左子表达式。该计算的 continuation 进
行右子表达式的解释。这个计算的 continuation 对结果求和。求和的结果怎么处理？在
interp 中，它被返回，返回到那个调用解释 plusC 的计算。请记住，现在我们不再返回值
；反之，我们将其传给 continuation：

```Racket
<cps-interp-plusC-case> ::=

    [plusC (l r) (interp/k l env
                           (lambda (lv)
                             (interp/k r env
                                       (lambda (rv)
                                         (k (num+ lv rv))))))]
```

**习题**

> 实现 multC。

还剩下两种相互关联的情况，它们相对更难些。

对于函数调用，还是需要解释两个子表达式，然后将结果的闭包应用于参数。不过，我们已
经说好了，每个调用都需要带上 continuation 参数。因此，必须更新一下值的定义：

```Racket
(define-type Value
  [numV (n : number)]
  [closV (f : (Value (Value -> Value) -> Value))])
```

接下来必须决定传给它啥 continuation。对于函数调用，就是传入解释器的
continuation：

```Racket
<cps-interp-appC-case> ::=

    [appC (f a) (interp/k f env
                          (lambda (fv)
                            (interp/k a env
                                      (lambda (av)
                                        ((closV-f fv) av k)))))]
```

最后处理 lamC 的情况。和以前一样，我们必须使用 lambda 创建 closV。不过，这个函数
需要两个参数：实际的参数和调用的 continuation。关键的问题是，后者该是什么？

有两个选择。k 表示**静态的**continuation：在闭包**创建**位置的那个
continuation。不过，我们想要的是在闭包**调用**之处的 continuation，也就是**动态
的**continuation。

```Racket
<cps-interp-lamC-case> ::=

    [lamC (a b) (k (closV (lambda (arg-val dyn-k)
                            (interp/k b
                                      (extend-env (bind a arg-val)
                                                  env)
                                      dyn-k))))]
```

要测试这个修改后的解释器，我们需要用某个初始 continuation 调用 interp/k。这个子
程序表示的是无需任何其他计算。自然的选择是恒等函数：

```Racket
(define (interp [expr : ExprC]) : Value
  (interp/k expr mt-env
            (lambda (ans)
              ans)))
```

为了强调这只是 interp/k 的顶层接口，interp 放弃了环境参数，自动传递空环境给
interp/k。如果需要特别确定没有意外地递归使用这个函数，我们可以在其最后插入一个对
error 的调用，以防止它返回，或者其返回值被使用。

## 14.3 生成器

现在许多编程语言都拥有**生成器**（generator）这一概念。生成器类似于函数，可以被
调用。区别在于，常规函数总是从头开始执行，生成器从最后一次停止的地方**恢复**。当
然，这意味着生成器需要“在完成之前退出”的概念。这就是所谓的**yield**（让位），即
把控制权归还给调用者。

### 14.3.1 各种设计

生成器有许多不同的变体。可以想见，不同之处在于如何进入和退出生成器：

- 在某些语言中，生成器是一种对象，需要和其他对象一样实例化，恢复其执行是通过调用
  方法（例如 Python 中的 next）。在其他语言中，生成器则类似于函数，而且重入是通
  过像函数一样调用。【注释】

- 在某些语言中，让位操作——例如 Python 的 yield——只能在生成器的语法主体中使用。在
  其他语言中，例如 Racket，yield 是在生成器主体中被绑定的、可调用的值，正由于它
  是值，它可以被抽象的传递、存储于数据结构中，等等。

> 在有些语言中，除了普通的函数，其他值也可以用做调用，所有这些值被统称为**可调用
> 值**（applicable）。

Python 的设计代表了一种极端，生成器是**任何包含关键字 yield 的函数**。此外
，Python 的 yield 不能作为参数传递给另一个函数，由该函数代理来执行让位。

还有个关于命名的小问题。在许多支持生成器的语言中，让位指令就是**字面上**的
yield：要么是关键字（如 Python），要么是绑定为可调用值的标识符（如在 Racket 中）
。还有种可能，生成器的用户必须在生成器表达式中指明让位指令的名字。【注释】也就是
说，生成器是这样的

```Racket
(generator (yield) (from)
           (rec (f (lam (n)
                     (seq
                       (yield n)
                       (f (+ n 1)))))
             (f from)))
```

但是等价的写法

```Racket
(generator (y) (from)
           (rec (f (lam (n)
                     (seq
                       (y n)
                       (f (+ n 1)))))
             (f from)))
```

如果这个让位指令实际上是值，那么用户也可以这样抽象地使用：

```Racket
(generator (y) (from)
           (rec (f (lam (n)
                     (seq
                       ((yield-helper y) n)
                       (f (+ n 1)))))
             (f from)))
```

其中 yield-helper 会去调用让位指令。

实际上还有两个设计上的决定：

1. yield 是声明还是表达式？在许多语言中，它是表达式，这意味着它有值：在恢复生成
   器时提供的值。这使得生成器更加灵活，因为生成器的使用者可以使用参数来改变生成
   器的行为，而不是**被迫**使用状态来传达所需的改变。
2. 生成器执行结束时会发生什么？在很多语言中，生成器会产生异常来表示完成。

> 奇怪的是，Python 在对象中期望用户来确定 self 或 this 的名称，但是它没有为
> yield 提供相同的灵活性，因为这是唯一确定哪些函数是生成器的方式！

### 14.3.2 实现生成器

要实现生成器，有效的方式是使用我们的 CPS 宏语言。先来确定这个设计决定的意义。我
们用调用来表示生成器：即，要获得来自生成器的下一个值，是通过将其应用于任何必要的
参数来完成的。类似的，让位指令也是可调用的值，并且还是表达式。虽然我们已经研究过
宏如何自动捕获名称（译注：13.5 节），但是简单起见我们还是明确给出让位指令的名称
好了。最后，当生成器执行完成时，我们会报错。

生成器如何工作？ 要 yield，生成器必须

- 记住它现在执行到哪里，
- 知道应该返回到调用者的哪里。

而当生成器被调用时，它应该

- 记住它的调用者执行到哪里，
- 知道它应该返回到其主体内的哪里。

请注意调用与让位之间的对偶。

你可能猜到了，这些“哪里”就是 continuation。

我们来逐步实现生成器，这相当于添加一条 cps 宏的规则。先写下模式的头部：

```Racket
<cps-macro-generator-case> ::=  ; CPS 宏，生成器子句

    [(_ (generator (yield) (v) b))
     (and (identifier? #'v) (identifier? #'yield))
     <generator-body>]          ; 生成器主体
```

主体第一部分很简单：CPS 中的所有代码都需要先读入 continuation，而且由于生成器是
值，所以这个值要被传给 continuation：

```Racket
<generator-body> ::=            ; 生成器主体

    #'(lambda (k)
        (k <generator-value>))  ; 生成器的值
```

下一步要处理生成器的核心了。

回忆一下，生成器是可调用的值。这就是说，它可以被放在函数调用的位置，因此它必须具
有与函数相同的“接口”：函数有两个参数，第一个是值，第二个是调用位置的
continuation。这个子程序应该做什么？我们刚刚描述过这个。首先，生成器必须记住它的
调用者正在执行的地方，这正是调用位置的 continuation；“记住”这里最简单的意思是“必
须保存在状态中”。然后，生成器应该返回到它之前所在的地方，即它**自己**的
continuation，这个显然必须被保存过。因此，这里可调用值的核心是：

```Racket
<generator-core> ::=   ; 生成器的核心

    (lambda (v dyn-k)
      (begin
        (set! where-to-go dyn-k)
        (resumer v)))
```

这里，where-to-go 记录了调用者的 continuation，让位时恢复；resumer 是生成器的本
地 continuation。让我们考虑一下它们的初始值是什么：

- where-to-go 没有初始值（因为生成器尚未被调用），所以如果它被调用，需要抛出错误
  。幸运的是，这个错误永远不会发生，因为第一次进入生成器时会对 where-to-go 赋值
  ，所以这个错误只是防范实现中出现 bug。
- 最初，生成器的其余部分是整个生成器，所以 resumer 应该被绑定到 b（的 CPS）。它
  的 continuation 是什么？是整个生成器的 continuation，即当生成器结束时该做啥。
  我们已经讨论过，这里也应该给出错误（区别是，在这种情况下错误确实会发生，如果生
  成器被要求产生比它配备的更多的值）。

还需要绑定 yield。正如我们已经指出的，它对称于生成器的恢复：将本地 continuation
保存在 resumer 中，然后通过调用 where-to-go 返回。

把这些片段放到一起，我们得到：

```Racket
<generator-value> ::=  ; 生成器的值

    (let ([where-to-go (lambda (v) (error 'where-to-go "nothing"))])
      (letrec([resumer (lambda (v)
                         ((cps b) (lambda (k)
                                    (error 'generator "fell through"))))]
              [yield (lambda (v gen-k)
                       (begin
                         (set! resumer gen-k)
                         (where-to-go v)))])
        <generator-core>))
```

**思考题**

> 为什么这里使用 let 和 letrec，而不只用 let？

请注意这些代码片段之间的依赖关系。where-to-go 不依赖于 resumer 或 yield。yield
显然依赖于 where-to-go 和 resumer。但是，为什么 resumer 和 yield 相互引用呢？

**思考题**

> 试试不这么做。

你可能会遗漏的巧妙依赖是，resumer 中包含 b，生成器的主体，它可能包含对 yield 的
引用。因此，它需要包含退位指令的绑定。

**练习**

> 生成器与协程（coroutine）和线程（thread）有什么不同？使用类似的策略来实现协程
> 和线程。

## 14.4 Continuation 和堆栈

虽然看上去不明显，但是 CPS 转换实际上对程序执行的**栈**（译注，调用栈）本质提供
了深入的了解。首先要理解的是，continuation 实际上就是**栈本身**。这可能看起来很
奇怪，因为堆栈是底层的机器实现，而 continuation 看似复杂。那么栈到底是什么呢？

- 栈是还有待完成的计算的记录。continuation 也是。
- 栈传统上被认为是**栈帧**（stack frame）的链表。也就是说，每个帧都引用该帧完成
  后剩余的帧。类似地，每个 continuation 都是个小程序，其中引用——因此包含——自己的
  continuation。如果为程序指令选择不同的表示形式，将其与闭包的数据结构表示相结合
  ，我们将得到一种与计算机堆栈基本相同的 continuation 表示法。
- 每个栈帧中还存储了函数的参数。continuation 的子程序表示法隐式地管理了此项信息
  ，明确地由数据结构（绑定）表示。
- 栈帧中还有“局部变量”的空间。continuation 原则上也是如此，尽管我们使用宏实现本
  地绑定，因此相当于将一切都还原成函数参数。然而从概念上讲，其中一些是“真实的”函
  数参数，而另一些是通过宏变成函数参数的局部绑定。
- 栈引用了堆，但没有内含堆。因此，堆中的变化在不同的栈帧都是可见的。同样地，闭包
  中引用了贮存，但不内含贮存，所以对贮存的修改在不同闭包中都是可见的。

因此，传统上，栈负责维护词法范围，而我们使用（静态范围的语言中的）闭包自动获得此
功能。

现在我们可以研究各种子项的转换，从而解到堆栈的映射。例如，考虑函数应用的转换：

```Racket
[(_ (f a))
 #'(lambda (k)
     ((cps f) (lambda (fv)
                ((cps a) (lambda (av)
                           (fv av k))))))]
```

该怎么“读”呢？这样：

- 我们用 k 表示函数调用之前的栈。
- 在对函数位置（`f`）求值时，创建新的栈帧（`(lambda (fv) ...)`）。该帧包含一个自
  由标识符：`k`。因此，它的闭包需要记录环境中的这个元素，即栈的其余部分。
- 栈帧的代码部分表示一旦我们获得了函数的值，剩下的工作：计算参数，执行调用，将结
  果返回给等待调用结果的栈：k。
- 对 f 的求值完成后，对 a 求值，这也需要创建栈帧：`(lambda (av) ...)`。该帧
  有**两个**自由标识符：k 和 fv。这说明：
  - 我们不再需要对函数位置求值的栈帧了，但是
  - 我们需要用**临时变量**记录函数位置求值的结果，它最好是函数值。
- 这第二个帧的代码部分代表也是剩下要做的事情：对参数调用函数，在等待调用结果的栈
  中进行。

条件指令也是同样的推理：

```Racket
[(_ (cnd tst thn els))
 #'(lambda (k)
     ((cps tst) (lambda (tstv)
                  (if tstv
                      ((cps thn) k)
                      ((cps els) k)))))]
```

它说的是，要对条件表达式求值，我们先要创建新的栈帧。该帧中包含等待整个条件表达式
值的栈。该帧根据条件表达式的值来决定，调用其子表达式之一。在判断了条件的值之后，
为了求它的值而创建的帧就不再需要了，因此求值可以在 k 中继续。

从这个角度出发，我们可以更好的解释生成器的操作。每个生成器都有自己的私有栈，当执
行超越其栈底时，我们的实现会报错。被调用时，生成器将表示“剩余程序”的栈的引用存储
在 where-to-go 中，然后恢复自己的栈。在让位时，系统交换堆栈的引用。协程，线程和
生成器在概念上都是相似的：它们都是创建“许多小堆栈”的机制，而不仅仅只是单个的全局
堆栈。

## 14.5 尾调用

观察上面的栈模式，为当前栈添加帧，执行一些计算，最终总是返回到当前栈。特别要注意
的是，在函数调用中，我们需要栈的空间来对函数求值，然后是对参数求值，但是一旦所有
这些求值完成，我们就使用函数调用开始之前的栈来恢复计算。换一种说法，**函数调用本
身不需要消耗栈空间**：我们只需要空间来计算参数。

但是，并非所有的语言都遵守或尊重这一属性。在这样做的语言中，程序员可以使用**递
归**来获得**迭代行为**：即，一系列函数调用不会比没有函数调用的情况下消耗更多空间
。这消除了创建特殊循环结构的需要；实际上，循环可以简单地表示为语法糖。

当然，这个属性不适用于一般情况。如果调用 f 来计算调用 g 所需的参数，那么对 f 的
调用相对于围绕 g 的上下文仍然会占用空间。因此，我们需要说明表达式之间的关系：一
个表达式的处于另一表达式的**尾位置**，如果对它的求值不需要另一表达式（求值）之外
的额外空间。在我们的 CPS 宏中，所有使用 k 作为其 continuation 的表达式——例如，在
所有子表达式求值完成之后的函数调用，或者条件表达式的 then 和 else 分支——都在其外
层表达式的尾位置（也许递归地还在其外层的尾位置）。反之，所有必须创建新栈帧的表达
式都不在尾位置。

有些语言对**尾递归**——某个函数在其函数体的尾位置调用自己——有特殊的支持。这显然是
有用的，因为它使得递归得以有效地实现循环。然而，它破坏了不能被挤入单个递归函数的
“循环”。例如，当实现状态机时，最方便的方法是用一组函数，每个函数代表一个状态，然
后通过（尾）调用表示状态转换。把它们变成单一的递归函数会非常繁琐（并且失去了意义
）。但是，如果一种语言能够识别尾调用，它就可以（和函数内调用自己一样）优化这些跨
函数的调用。

Racket 的实现保证尾调用不会分配额外的栈空间。有人把这称为“尾调用的优化”，但这个
术语是误导性的：优化是可选性的，而某种语言是否承诺正确实现尾调用是种**语义**特性
。程序员需要了解语言的行为方式，因为这会影响他们的编程方式。

由于这个特性，观察 CPS 转换之后的程序的有趣之处：其中所有的函数调用本身都是尾调
用的！从本章开头的 read-number/suspend 例子开始，你就可以看到这点：所有待处理的
计算都被放入了 continuation 参数。假设程序可能在任何调用中终止，等同于根本不使用
任何栈空间（因为栈将会被清除）。

**练习**

> 程序如何在没有栈的情况下运行？

## 14.6 语言特性中支持 continuation

了解 continuation 和栈之间的这种关联之后，现在可以回过头讨论函数的处理：我们忽略
了在**创建**闭包时的 continuation，而只使用了在闭包调用时的 continuation。当然，
这对应于普通的函数行为。但现在我们可以问，如果我们用创建时的 continuation 呢？这
等同于，在“程序”创建时保存对栈的（副本）的引用，然后在调用函数时忽略动态的求值，
返回到函数创建点。

实际上，我想说的是，让 lambda 保持不变，而给我们的语言提供新的、对于与这种行为的
指令：

```Racket
<cps-macro-let/cc-case> ::=  ; CPS 宏

    [(_ (let/cc kont b))
     (identifier? #'kont)
     #'(lambda (k)
         (let ([kont (lambda (v dyn-k)
                       (k v))])
           ((cps b) k)))]
```

这说的是，两种情况下，控制都将返回到直接包含 let/cc 的表达式：要么通过正常返回（
因为主体 b 的 continuation 是 k），要么通过更有意思的方式，调用 continuation，这
会丢弃动态的 continuation dyn/k，简单地忽略它直接返回到 k。

最简单的测试是：

```Racket
(test (run (cps (let/cc esc 3)))
      3)
```

这证实了，如果我们从不使用 continuation，那么对主体的求值就好像 let/cc 根本不存
在一样（因为`((cps b) k)`）。如果我们使用它，传给 continuation 的值返回到创建点
：

```Racket
(test (run (cps (let/cc esc (esc 3))))
      3)
```

当然，这个例子揭露的还不够，不过考虑这个：

```Racket
(test (run (cps (+ 1 (let/cc esc (esc 3)))))
      4)
```

这证实了加法会实际执行。那么动态的 continuation 呢？

```Racket
(test (run (cps (let/cc esc (+ 2 (esc 3)))))
      3)
```

这表明加 2 不会发生，即动态 continuation 确实被忽略了。为了确保创建位置的
continuation 被保留，请观察：

```Racket
(test (run (cps (+ 1 (let/cc esc (+ 2 (esc 3))))))
      4)
```

从这些例子中，你可能已经注意到熟悉的模式：esc 在这里的表现类似于异常。也就是说，
如果你不抛出异常（在这里，调用 continuation）它就好像不在那里，但是如果你抛出异
常，所有未完成的中间计算都将被忽略，计算返回到异常创建点。

**练习**

> 使用 let/cc 和宏实现异常的抛出和捕获机制。

然而，这些例子只用到了最浅层的（let/cc 的）能力，因为这里调用点处的 continuation
总是创建点处的 continuation 的扩展：即后者在栈中比前者更早。然而，没有任何东西要
求 k 和 dyn-k 之间存在相关。它们实际上可以是**无**关的，这意味着它们可以是两个独
立的栈，所以我们可以用它轻松地实现栈切换功能。

**练习**

> 为了真正与 lambda 类似，我们应该引入如下展开的构造，称其为 cont-lambda 好了：
>
> ```Racket
> [(_ (cont-lambda (a) b))
>  (identifier? #'a)
>  #'(lambda (k)
>      (k (lambda (a dyn-k)
>           ((cps b) k))))]
> ```
>
> 为什么我们没有这么做呢？从两方面考虑，静态类型的角度，还有，我们如何使用这个构
> 造来构建上述类似于异常的行为。

### 14.6.1 用语言表达

用我们的小玩具语言编写程序很快会变得令人沮丧。幸运的是，Racket 已经提供了叫做
call/cc 的构造，用来操作 continuation。call/cc 是单参数的函数，其参数本身又是单
参数的函数，Racket 会将当前 continuation 传给它进行调用，而当前 continuation 也
是单参数的子程序。能理解吗？

幸运的是，我们可以用 call/cc 轻松地将 let/cc 实现为宏，然后用它来编写程序。这样
：

```Racket
(define-syntax let/cc
  (syntax-rules ()
    [(let/cc k b)
     (call/cc (lambda (k) b))]))
```

之前的所有测试仍然通过：

```Racket
(test (let/cc esc 3) 3)
(test (let/cc esc (esc 3)) 3)
(test (+ 1 (let/cc esc (esc 3))) 4)
(test (let/cc esc (+ 2 (esc 3))) 3)
(test (+ 1 (let/cc esc (+ 2 (esc 3)))) 4)
```

### 14.6.2 定义生成器

现在我们可以创建有趣的抽象了。比如，让我们来编写生成器。之前我们需要将表达式 CPS
转化，并传递 continuation，现在都可以通过 call/cc 自动完成。因此，当需要目前的
continuation 时，我们都可以简单地召唤它而无需改变程序。所以，额外的`...-k`参数都
会消失，在同一个地方可以用 let/cc 捕获相同的 continuation：

```Racket
(define-syntax (generator e)
  (syntax-case e ()
    [(generator (yield) (v) b)
     #'(let ([where-to-go (lambda (v) (error 'where-to-go "nothing"))])
         (letrec ([resumer (lambda (v)
                             (begin b
                                    (error 'generator "fell through")))]
                  [yield (lambda (v)
                           (let/cc gen-k
                             (begin
                               (set! resumer gen-k)
                               (where-to-go v))))])
           (lambda (v)
             (let/cc dyn-k
               (begin
                 (set! where-to-go dyn-k)
                 (resumer v))))))]))
```

请观察这段代码和去语法糖到 CPS 代码实现的生成器之间的密切相似性。具体而言，我们
去掉了额外的 continuation 参数，用 let/cc 调用替换它们，这些调用能捕获完全相同的
continuation。其余的代码基本不变。

**练习**

> 如果我们将（两处）let/cc 和赋值移到 begin 内的第一个语句，会发生什么呢？

例如，我们可以编写从初始值向上迭代的生成器：

```Racket
(define g1 (generator (yield) (v)
                      (letrec ([loop (lambda (n)
                                       (begin
                                         (yield n)
                                         (loop (+ n 1))))])
                        (loop v))))
```

其行为是：

```Racket
> (g1 10)
10
> (g1 10)
11
> (g1 0)
12
>
```

因为（生成器）主体只引用了初始值，调用 yield 所返回的值被忽略，所以在后续调用传
入的值不起作用。相反，考虑这个生成器：

```Racket
(define g2 (generator (yield) (v)
                      (letrec ([loop (lambda (n)
                                       (loop (+ (yield n) n)))])
                        (loop v))))
```

在第一次调用时，它返回输入的值。在此后的调用中，该值被加到后续调用生成器所提供的
值上。换一种说法，该发生器累加它的所有输入值：

```Racket
> (g2 10)
10
> (g2 15)
25
> (g2 5)
30
```

**练习**

> 现在我们已经使用 call/cc 和 let/cc 实现了生成器，请用它们实现协程和线程。

### 14.6.3 定义线程

完成生成器之后，我们再做个类似的功能：线程。具体来说，我们希望能够编写如下的程序
：

```Racket
(define d display) ; 有用的简写

(scheduler-loop-0
 (list
  (thread-0 (y) (d "t1-1  ") (y) (d "t1-2  ") (y) (d "t1-3 "))
  (thread-0 (y) (d "t2-1  ") (y) (d "t2-2  ") (y) (d "t2-3 "))
  (thread-0 (y) (d "t3-1  ") (y) (d "t3-2  ") (y) (d "t3-3 "))))
```

输出应该是：

```Racket
t1-1  t2-1  t3-1  t1-2  t2-2  t3-2  t1-3 t2-3 t3-3
```

我们来创建必要的组件实现此功能。

我们先来定义线程调度器。它读入“线程”的链表，我们假设线程的接口读入
continuation，并最终将控制返回给此 continuation。每当调度器重新激活某个线程时，
都会向其提供 continuation。调度器可以用简单的循环（round-robin）方式选择线程，也
可以使用更复杂的算法；这里我们不关心如何选择的细节。

类似于生成器，我们假定让位由调用用户命名的子程序完成，例如这里的 y。我们也可以使
用名称捕获（译注，13.5 节）自动绑定其名称，比如 yield。

这里的要点的是，请注意让位由线程系统的用户手动控制。这就是所谓的**协作式多任务处
理**（cooperative multitasking）。相反，我们可以选择通过生成定时器或其他内在机制
自动触发让位，而无需用户许可。这被称为**抢占式多任务处理**（preemptive
multitasking）（因为系统从线程中“抢占”——也就是夺取了——控制权）。虽然这种区别对于
构建系统来说是非常重要的，但从设置 continuation 的角度来看，这并不重要。

**练习**

> 在完成协作式多任务之后，实现抢占式多任务。哪里需要修改？

陈述了这些限制，我们可以着手编写调度器了。它读入线程的链表，只要还有剩下的线程就
继续执行。每次，它将线程应用于 continuation，这个 continuation 表示返回到调度器
并继续下一个线程：

```Racket
(define (scheduler-loop-0 threads)
  (cond
    [(empty? threads) 'done]
    [(cons? threads)
     (begin
       (let/cc after-thread ((first threads) after-thread))
       (scheduler-loop-0 (append (rest threads)
                                 (list (first threads)))))]))
```

当接收线程调用绑定到 after-thread 的 continuation 时，控制返回到 begin 序列中第
一个语句的结尾。因此，提供给 continuation 的值会被忽略（所以可以用任何值；我们选
择用`'dummy`，以便其莫名出现时方便地发现问题）。将最近调用的线程附加到线程表的末
尾（即，将该链表视为循环队列）之后，控制将继续调度器循环的其余部分。

接下来我们定义线程。我们说过，它是单参数的函数，参数就是调度器的 continuation。
由于线程需要能**恢复**，也就是从停止的地方继续，所以它必须存储上次执行到的位置：
我们将其称为 thread-resumer。起初 thread-resumer 是整个线程体，但在后续的实例中
，它将是 continuation：调用 yield 的 continuation。于是，我们得到如下的框架：

```Racket
(define-syntax thread-0
  (syntax-rules ()
    [(thread (yielder) b ...)
     (letrec ([thread-resumer (lambda (_)
                                (begin b ...))])
       (lambda (sched-k)
         (thread-resumer 'dummy)))]))
```

还剩下 yielder 没实现。它是无参数的函数，将线程的 continuation 存入
thread-resumer，然后用`'dummy`调用调度器的 continuation。不过，调用**哪个**调度
器的 continuation 呢？不是线程初始化时传入的那个，而是最新的那个。因此，我们必须
以某种方式将 sched-k 中的值“thread”（译注，传递）给 yielder。有很多种方式可以实
现，但最简单的，也许是最暴力的方式是，简单地为每个线程恢复重建 yielder，总是包含
sched-k 的最新值：

```Racket
(define-syntax thread-0
  (syntax-rules ()
    [(thread (yielder) b ...)
     (letrec ([thread-resumer (lambda (_)
                                (begin b ...))]
              [yielder (lambda () (error 'yielder "nothing here"))])
       (lambda (sched-k)
         (begin
           (set! yielder
                 (lambda ()
                   (let/cc thread-k
                     (begin
                       (set! thread-resumer thread-k)
                       (sched-k 'dummy)))))
           (thread-resumer 'tres))))]))
```

将这些放到一起运行，我们得到：

```Racket
t1-1  t2-1  t3-1  t1-2  t2-2  t3-2  t1-3 t2-3 t3-3
```

嘿，这就是我们想要的！但是运行继续：

```Racket
t1-3 t2-3 t3-3 t1-3 t2-3 t3-3 t1-3 t2-3 t3-3
```

嗯。

怎么回事？恩，我们并没有说明当线程运行结束时需要怎么处理。实际上，控制只是返回到
线程调度器，调度器将线程追加到队列的末尾，然后，当线程再次到达队列的头部时，控制
从之前存储的那个 continuation 中恢复：对应于打印第三个值。打印，控制返回，线程被
追加到队尾……无限循环。

显然，在线程终止时，我们需要通知线程调度器，这样调度器可以将其从线程队列中移除。
我们创建简单的数据类型来表示该信号：

```Racket
(define-type ThreadStatus
  [Tsuspended]
  [Tdone])
```

（当然，在真实的系统中，这些状态消息也可以带上和计算相关的值。）那么我们必须修改
调度器，实际检查和使用这些值：

```Racket
(define (scheduler-loop-1 threads)
  (cond
    [(empty? threads) 'done]
    [(cons? threads)
     (type-case ThreadStatus (let/cc after-thread ((first threads) after-thread))
       [Tsuspended () (scheduler-loop-1 (append (rest threads)
                                                (list (first threads))))]
       [Tdone () (scheduler-loop-1 (rest threads))])]))
```

线程的表示中有两个地方需要修改：中间返回的时候它必须传 Tsuspended 给调度器的
continuation，终止时传 Tdone。哪里是终止呢？在执行完线程体代码`b ...`之后。最后
，请注意和退位一样，终止程序必须也使用最新的调度器 continuation。因而：

```Racket
(define-syntax thread-1
  (syntax-rules ()
    [(thread (yielder) b ...)
     (letrec ([thread-resumer (lambda (_)
                                (begin b ...
                                       (finisher)))]
              [finisher (lambda () (error 'finisher "nothing here"))]
              [yielder (lambda () (error 'yielder "nothing here"))])
       (lambda (sched-k)
         (begin
           (set! finisher
                 (lambda ()
                   (let/cc thread-k
                     (sched-k (Tdone)))))
           (set! yielder
                 (lambda ()
                         (let/cc thread-k
                           (begin
                             (set! thread-resumer thread-k)
                             (sched-k (Tsuspended))))))
           (thread-resumer 'tres))))]))
```

用 scheduler-loop-1 和 thread-1 替换 scheduler-loop-0 和 thread-0，重新运行前面
的示例程序，就能得到正确的输出。

### 14.6.4 更好的 Web 编程指令

最后，我们回过头看看 read-number：请注意，如果运行服务器程序的语言有 call/cc，我
们就不必 CPS 整个程序，而是可以简单地捕获当前 continuation，将其保存在哈希表中，
从而使程序结构保持不变。
