# 可变结构和变量

下列各表达式哪些意义相同的？

* `f = 3`
* `o.f = 3`
* `f = 3`

假设上面的表达式使用 Java 书写，则第一个和第三个的可能意义一样，并且，同时第二个可能和它们也相同：取决于 `f` 是本地标识符（如作为方法的参数）还是对象的一个字段（如，作为 `this.f = 3` 的简写）。

不管是哪种情况，求值器都将永久改变绑定到 `f` 的值。到目前为止，我们实现的求值过程对于一组相同的输入总是输出相同的东西。直到现在这种情形被打破了，一个计算过程的结果与它在何时 —— 在 `f` 的值被改变之前或之后 —— 相关。时间的引入对于代码的实际含义的考虑有深远影响。

还有需要注意的是，改变字段的值（`o.f = 3` 或者 `this.f = 3`）和改变一个标识符的值（`f = 3` 在方法内部被绑定而不是由对象绑定）有着非常大的区别。我们会依次讨论它们。我们将首先探讨字段，再在[变量]()那一节中探讨标识符。

## 可变结构

### 可变结构的一个简单模型

很快我们会带大家认识到对象其实就是一般化的结构；对象中的字段可认为是结构中字段的一般化的结果。理解可变对象对于理解可变性（mutation）大致足够了（并不完全足够）。为了方便讨论，我们简化一下问题，考虑只有一个字段的结构。我们称该结构为 `box`。在 Racket 中，它仅支持三种运算：

```scheme
box : ('a -> (boxof 'a))
unbox : ((boxof 'a) -> 'a)
set-box! : ((boxof 'a) 'a -> void)
```

`box` 接受一个值然后将其包裹在一个可变容器中返回。`unbox` 取出容器中当前值。`set-box!` 改变一个容器中的值，对于一个类型化的语言（typed language）来说，新值需要和旧值保持类型一致。如果对应到 Java 中的话，可能得到下面的代码，`box` 对应构造器，`unbox` 对应 `getter`，`set-box!` 对应 `setter`（由于只考虑一个字段，所以其中字段名无所谓）：

```Java
class Box<T> {
    private T the_value;
    Box(T v) {
        this.the_value = v;
    }
    T get() {
        return the_value;
    }
    void set(T v) {
        the_value = v;
    }
}
```

由于 mutation（才疏学浅，不知道翻译成什么词合适） 操作经常成组进行（例如，从一个银行账户中取出一些钱存放到另一个账户），去支持 mutation 操作的序列将非常有用。在 Racket 中，你可以使用 `begin` 表示一个操作的序列；它将依次计算序列中的每个表达式然后返回最后一个的求值结果作为其结果。

> 尝试使用 `let`（本身也是个语法糖，可以解开为 lambda 函数调用）来构造一个 `begin` 的语法糖。

尽管可以将 `begin` 实现为语法糖，但是后面我们将看到它能很好的帮助我们理解 mutation 的内部原理。所以我们还是决定直接在核心语言中支持序列操作，方便起见，我们只支持两个操作的序列（且不失一般性）。

### 脚手架

首先，为语言核心数据结构添加新的构造：

```scheme
(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)]
  [lamC (arg : symbol) (body : ExprC)]
  [boxC (arg : ExprC)]                 ;; box
  [unboxC (arg : ExprC)]               ;; unbox
  [setboxC (b : ExprC) (v : ExprC)]    ;; setbox
  [seqC (b1 : ExprC) (b2 : ExprC)])    ;; seq，操作序列
```

注意 `setboxC` 表达式，两个操作数（`box` 和新值）均为表达式（ExprC）。新值为表达式很自然，没什么奇怪的；但是 `box` 参数这样乍一看可能还挺奇怪的。它意味着我们可以写出这样的代码（下面使用的是 Racket 代码）：

```scheme
(let ([b0 (box 0)]
      [b1 (box 1)])
  (let ([l (list b0 b1)])
    (begin
      (set-box! (first l) 1)
      (set-box! (second l) 2)
      l)))
```

其计算结果为 `box` 的列表，第一项包含的值为 `1`，第二项包含的值为 `2`。拿其中第一个 `set-box!` 为例，其第一个参数为 `(first l)`，是一个计算结果为 `box` 的表达式而不是 `box` 字面值或标识符。和 Java 中下列代码类似：

```Java
public static void main (String[] args) {
    Box<Integer> b0 = new Box<Integer>(0);
    Box<Integer> b1 = new Box<Integer>(1);

    ArrayList<Box<Integer>> l = new ArrayList<Box<Integer>>();
    l.add(b0);
    l.add(b1);

    l.get(0).set(1);
    l.get(1).set(2);
}
```

注意到其中 `l.get(0)` 为一个复合表达式，它得到一个 `box` 对象，然后调用其 `set` 方法。

为方便起见，我们假设已经实现了下列语法糖：

1. `let`
2. 多于两个子表达式的序列

> 对于不熟悉的读者，糖1可以这样解开：
>
> `(let ([x val]) exp)` ==> `((lambda x exp) val)`
>
> 糖2可以通过嵌套 `seqC` 的方式解开，如：
>
> `(seq exp1 exp2 exp3)` ==> `(seq exp1 (seq exp2 exp3))`

后面有时还会直接使用 Racket 代码展示一些功能，一方面是为了简洁（我们的核心语言将变得大且笨重），一方面是为了让你可以在未完全实现语言解释器的情况下，运行相关代码观察结果。也就是说我们会使用 Racket 中的可变对象和结构行为（它们在大部分主流语言行为也一致）作为我们实现的参照。

### 与闭包交互

考虑下面这个简单的计数器：

```scheme
(define new-loc
  (let ([n (box 0)])
    (lambda ()
      (begin
        (set-box! n (add1 (unbox n)))
        (unbox n)))))
```

每次调用，产生下一个计数：

```scheme
> (new-loc)
- number
1
> (new-loc)
- number
2
```

为什么会这样呢？这是因为其中的 `box` 只被创建了一次，然后绑定到了 `n`，然后该绑定被关进闭包。所有后面的操作**改变的都是同一个 `box`（使用标识符 `n` 引用）**。如果改成下面这样，代码的语义就被完全改变：

```scheme
(define new-loc-broken
  (lambda ()
    (let ([n (box 0)])
      (begin
        (set-box! n (add1 (unbox n)))
        (unbox n)))))
```

计算看看：

```scheme
> (new-loc-broken)
- number
1
> (new-loc-broken)
- number
1
```

这种情况下每次调用函数都会创建一个新的 `box`，所以每次的计算结果都相同（尽管程序内部也变动了 `box` 中的值）。我们对于 `box` 的实现也应该正确重现这种区别。

上面的例子给了我们一点关于实现上的提醒。显然，`new-loc` 对于关入环境中的 `box` 的每次引用应该引用的是同一个 `box`。然而我们还需要做一些工作来确保获得的 `box` 中的值每次都是不同的！仔细体会：它从词法上来看应该是相同，但是动态运行时值是不同的（it must be lexically the same, but dynamically different）。这个区分将是我们实现的核心。

### 理解 box 的实现

首先重现一下当前的解释器结构：

```scheme
(define (interp [expr : ExprC] [env : Env]) : Value
  (type-case ExprC expr
    [numC (n) (numV n)]
    [idC (n) (lookup n env)]
    [appC (f a) (local ([define f-value (interp f env)])
                  (interp (closV-body f-value)
                          (extend-env (bind (closV-arg f-value)
                                            (interp a env))
                                      (closV-env f-value))))]
    [plusC (l r) (num+ (interp l env) (interp r env))]
    [multC (l r) (num* (interp l env) (interp r env))]
    [lamC (a b) (closV a b env)]
    <boxC-case>
    <unboxC-case>
    <setboxC-case>
    <seqC-case>))
```

由于我们引入了新的类型的值，也需要更新一下值的数据结构：

```scheme
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)]
  [boxV (v : Value)])
```

先实现两种简单的情形。对于 `box` 表达式，直接求值并使用 `boxV` 包裹：

```scheme
; boxC-case
    [boxC (a) (boxV (interp a env))]
```

同样，从 `box` 中抽取值也很简单：

```scheme
; unboxC-case
    [unboxC (a) (boxV-v (interp a env))]
```

现在你可以写一些测试来保证新加代码行为同预期一样。

当然，现在还没有做到最难的部分。可以预见，所有有趣的行为都在 `setboxC` 的实现上。然而我们却要先看看 `seqC` 的实现（你会看到我们为什么应该把它加到核心语言中）。

首先考虑操作序列的一种非常自然的实现：

```scheme
    [seqC (b1 b2) (let ([v (interp b1 env)])
                    (interp b2 env))]
```

即先计算第一个式子，然后计算第二个并返回第二个的计算结果。

你可能会迅速察觉到一些问题，我们计算了第一个式子并把它的值绑定到了 `v`，但是后面的计算过程中没有使用到该值。这其实是没关系的：一般来说，第一个式子中很可能包含了一个 mutation 操作，其值也不太值得关注（注意 `set-box!` 返回一个 void 值）。还有一种显而易见的实现如下：

```scheme
    [seqC (b1 b2) (begin
                    (interp b1 env)
                    (interp b2 env))]
```

这里直接使用了 Racket 中的 `begin`。但是和之前那种实现一样，它不太可能是正确的！因为要使它行为正确，我们需要保证**第一个表达式中 mutation 操作的结果能够在某个地方被保留**，但是考虑到目前我们的解释器只是解释表达式的值，任何在 `(interp b1 env)` 中进行的 mutation 操作都将丢失，显然这不是我们想要的。

### 环境能帮我们解决这个问题吗？

（由于翻译的问题可能使得这一节读起来没那么通顺，你可以选择阅读原文，阅读时带着这一节的标题中问题去理解，而标题中提到的问题指的是解释过程中如何保留 mutation 的操作记录）

下面这个例子能给我一点启示：

```scheme
(let ([b (box 0)])
  (begin (begin (set-box! b (+ 1 (unbox b)))
                (set-box! b (+ 1 (unbox b))))
         (unbox b)))
```

在 Racket 中，它求值得 `2`。

> 尝试使用 `ExprC` 表示一下该式子。
>
> ```scheme
> ;; 这里直接把 let 解开成 lambda 调用，如果你自己实现了 let 语法糖会略有不同
> (appC
>  (lamC 'b
>        (seqC (seqC
>               (setboxC (idC 'b) (plusC (numC 1) (unboxC (idC 'b))))
>               (setboxC (idC 'b) (plusC (numC 1) (unboxC (idC 'b)))))
>              (unboxC (idC 'b))))
>  (boxC (numC 0)))
> ```

考虑内侧的 `begin`。其两个操作的表达式（`(set-box! ...)`）完全相同。然而幕后有什么东西悄悄改变了，因为我们看到了 `box` 中的值直接从 0 变成了 2！上面的例子修改一下我们能看的更清楚：

```scheme
(let ([b (box 0)])
  (+ (begin (set-box! b (+ 1 (unbox b)))
            (unbox b))
     (begin (set-box! b (+ 1 (unbox b)))
            (unbox b))))
```

这下求值得到 3。注意到这段代码中 `+` 的两个操作数部分就字面上看是完全相同的，但是 `+` 的第一个操作数的行为显然被第二个操作符表达式感知到。我们需要解开背后的魔法。

如果给解释器喂了两个一模一样的表达式，它们的结果怎么做到不同的呢？唯一的可能就是解释器的另一个参数，即环境，不知怎么的发生了变化。但是按照现有解释器来看 `+` 的两个参数求值所使用的环境也是相同的，所以对于现有的解释器来说，是不可能产生上面这种我们想要的结果。

通过上述例子我们得到的一些启示：

1. 我们需要通过某些方式使得解释器获得不同的参数以使其像上面那样得到不同的结果
2. 在计算其参数表达式时需要返回与 mutation 操作相关的纪录

由于输入的表达式不应该被改变，所以第一点指引我们使用环境来反映两次调用之间的不同。结合第二点我们很自然的想到让让解释器可以返回环境（在其中携带 mutation 的记录），这样就可以将它传递给下次调用。于是，解释器的类型可能就变成了：

```scheme
; interp : ExprC * Env -> Value * Env
```

即，解释器接收一个表达式和一个环境作为参数；在环境中求值，求值过程中更新环境，然后和以前一样返回求值结果，同时还附加了一个更新后的环境，然后该环境被传入解释器的下次调用中。`setboxC` 的处理过程中应该会影响到环境，以反应它所执行的 mutation 操作。

在开始实现之前，我们应该考虑一下这种改变的后果。环境已经负担了一个重任：保存被延迟的替换操作的所需信息。它已经有一个非常明确的语义——由替换给定——我们应该注意，不要影响这层语义。它和替换之间的这种关系使得它成为了**词法作用域信息的仓库**。如果我们扩展环境的功能，使得加法的一个参数分支中的绑定通过它可以传递到另一个参数分支中，例如，考虑下面的程序：

```scheme
(+ (let ([b (box 0)])
     1)
   b)
```

显然该程序将出错。加法的第二个参数 `b` 应该是未绑定的（如果上面的代码对你来说不够清晰，使用函数把 let 语法糖解开），如果错误的扩展了环境的功能，我们将使得加法第一个参数中产生的 `b` 的绑定被第二个参数使用。

> 尝试使用已有的解释器的逻辑自行人肉解释一下上面的代码以确保真正理解上面要表达的意思。

当然你可能考虑其它实现方式。比如你可能想，由于问题出在多余的绑定上，我们可以将返回的环境中多余的绑定直接移除掉。但是你还记得我们之前闭包的实现吗？

> 考虑下面程序：
>
> ```scheme
> (let ([a (box 1)])
>   (let ([f (lambda (x) (+ x (unbox a)))])
>     (begin
>       (set-box! a 2)
>       (f 10))))
> ```
>
> 看看这个方案方案有什么问题。

要认识到，前面提到的两个启示中的约束都是有效的，但是解决方案并不在上面提出的这些尝试中。再仔细想想，事实那两个启示中所提出的约束没必要非得通过环境去实现。而且环境显然也**不应该**负起这个职责（正如前面说的，它自己已经有明确且单纯的语义）。

（到此为止我们应该认识到，考虑使用环境解决 mutation 操作的记录不是一种特别好的方式，这就带着我们进入下一节）

### 引入 Store（存储）

通过上一节的讨论我们应该意识到需要一个额外的仓库来达成表达式的解释过程。一个仓库是环境，还是执行赋予它的职责，维护一个本地作用域。但是环境不该再直接将标识符映射到值，因为现在值是可能会变的。也即，我们需要额外的东西用于维护可变 `box` 的动态状态，这个额外的东西我们称之为 `store`。

和环境一样，store 也是一个映射结构。它的域可以为任意的名字的集合（所谓域，这里可以通俗理解为映射结构的索引／key部分），但是将其想作用于表示内存地址的数也是一种很自然的想法。这是由于 store（存储） 在其语义上来说就直接对应于机器的物理内存的抽象，而物理内存一般采用数来寻址。因此环境是将名字映射到一个地址，然后通过该地址可以寻到值。

```scheme
(define-type-alias Location number)
(define-type Binding
  [bind (name : symbol) (val : Location)])

(define-type-alias Env (listof Binding))
(define mt-env empty)
(define extend-env cons)

(define-type Storage
  [cell (location : Location) (val : Value)])

(define-type-alias Store (listof Storage))
(define mt-store empty)
(define override-store cons)
```

当然我们还需要提供一些函数用于在 store 中查询值，就跟之前环境一样，当然现在环境的查询函数返回的是地址了。

```scheme
(define (lookup [for : symbol] [env : Env]) : Location
  ...)
(define (fetch [loc : Location] [sto : Store]) : Value
  ...)
```

然后，提炼出解释器返回值的正确表示：

```scheme
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)]
  [boxV (l : Location)])
```

> 练习：自行实现函数 `lookup` 和 `fetch`

### 解释器之 `box`

现在我们有了可以让环境返回、更新并能反映求值过程中 mutation 的东西，且不需要修改环境的任何行为。由于我们的解释器只能返回一个值，考虑定义一个数据结构用于存储解释器返回的结果：

```scheme
(define-type Result
  [v*s (v : Value) (s : Store)])
```

于是，解释器的类型变成了这样：

```scheme
(define (interp [expr : ExprC] [env : Env] [sto : Store]) : Result
  <ms-numC-case>
  <ms-idC-case>
  <ms-appC-case>
  <ms-plusC/multC-case>
  <ms-lamC-case>
  <ms-boxC-case>
  <ms-unboxC-case>
  <ms-setboxC-case>
  <ms-seqC-case>)
```

数的解释依然是最简单的。记住我们需要返回用于反映求值给定表达式过程中发生的 mutation 的 store。由于数是常量，求值过程不会有 mutation 发生，所以，直接返回不经修改的 store 即可：

```scheme
;; ms-numC-case
  [numC (n) (v*s (numV n) sto)]
```

对于闭包的创建也是一样；注意是闭包的创建而不是调用：

```scheme
;; ms-lamC-case
  [lamC (a b) (v*s (closV a b env) sto)]
```

对于标识符的求值也是简单直接，要获取到其绑定值，你需要同时查询环境和 store，当然，查询过程可能会抛出异常：

```scheme
;; ms-idC-case
  [idC (n) (v*s (fetch (lookup n env) sto) sto)]
```

注意到 `lookup` 和 `fetch` 组合在一起产出之前由 `lookup` 一个直接产出的值。

下面，事情开始变得有意思了。

考虑操作序列。显然，我们需要求值下面两个式子：

```scheme
  (interp b1 env sto)
  (interp b2 env sto)
```

注意，这里的关键是要使用第一个式子求值产生结果中的 store 来对第二个式子进行求值，这也是我们最初考虑引入 store 的缘由。因此，我们需要先对第一个式子进行求值，然后取出其结果中的 store，传入第二个表达式的求值过程：

```scheme
;; ms-seqC-case
  [seqC (b1 b2) (type-case Result (interp b1 env sto)
                  [v*s (v-b1 s-b1)
                       ;; 匹配 b1 的解释结果，对于其值部分 v-b1 我们就直接，丢弃
                       ;; b2的 求值使用它产出的 store 部分 s-b1
                       (interp b2 env s-b1)])]
```

简单明了，不多做解释了。

> 你可以多花几秒玩味一下上面的代码，后面将经常用到该种模式的代码。

下面进入到双目算术运算的求值过程。它们和上面操作序列的求值类似，也含有两个子表达式，但是这里我们只需要分别考虑两个分支各自的求值。和以前一样， `plusC` 和 `multC` 的代码基本上相同，只拿 `plusC` 的实现做个示例：

```scheme
  [plusC (l r) (type-case Result (interp l env sto)
                 [v*s (v-l s-l)
                      (type-case Result (interp r env s-l)
                        [v*s (v-r s-r)
                             (v*s (num+ v-l v-r) s-r)])])]
```

这里可以看到环境和 store 的一个重要区别。当计算一个表达式时，根据语言的作用域规则，通常其所有子表达式使用相同的环境；与之相对，store 需要从一个分支的求值过程传递到另一个分支，最后再将 store 返回。这种风格被称作 **store-passing style**。

现在谜题彻底揭晓，所有魔法都被破除，**store-passing style** 就是我们的秘密神器：它在保证环境依旧正确处理本地作用域的同时，给了我们能够记录 mutation 操作的方法。我们的直觉告诉我们环境应该参与了获取同一个表达式不同值的这个过程，现在我们终于能看清这是怎么做到的了：它不是通过直接修改自己的实现达成这点，而是间接的引用了 store，而 store 作为更新实际发生的始作俑者。下面我们需要看看 store 是如何“改变”自己的。

首先考虑如何存储一个值到 `box` 中（`boxing`）。我们得分配一块地方让 store 能够存放值。对应于 `box` 的值会记住该地址，用于之后 `box` 的 mutation 操作。

```scheme
;; ms-boxC-case
  [boxC (a) (type-case Result (interp a env sto)
              [v*s (v-a s-a)
                   (let ([where (new-loc)])
                    (v*s (boxV where)
                         (override-store (cell where v-a)
                                         s-a)))])]
```

> 解决这个问题！
>
> 注意了注意了，上面的代码依赖 `new-loc`，而它自己的实现（前面[与闭包交互]()那一节）本身就依赖于 `box`，这就很尴尬了。考虑一下怎么修改使得解释器不需要这样一个依赖于可变结构的 `new-loc` 的实现。

要移除这种风格的 `new-loc`，最容易想到的方式当然是再给解释器添加一个参数用于表示当前使用过的最大的地址。store 每次分配地址的操作都会返回一个递增过的地址，而其它操作直接返回原最大地址。即我们又添加了一层 **store-passing** 模式进解释器。这样去实现的话会显得太笨拙。不管怎样，我们清楚的知道，不能依赖还没实现的 `box` 来实现我们的语言中的 `box`。

由于 `box` 记录内存地址，获取 `box` 中的值比较简单：

```scheme
;; ms-boxC-case
  [unboxC (a) (type-case Result (interp a env sto)
                [v*s (v-a s-a)
                     (v*s (fetch (boxV-l v-a) s-a) s-a)])]
```

我们根据求得的 `box` 的地址从 store 中提取实际值。注意这里的代码没有直接判断 `a` 的求值结果是否的确是一个 `box`，而是依赖于实现该语言的宿主语言（pali-typed）抛出异常；考虑对于 C 语言，如果直接访问一个任意内存而不检测地址的类型将会产生多么严重的后果。

下面考虑怎么更新一个 `box` 中的值。首先我们需要求值得到 `box` 和要更新的新值。而 `box` 的值将为 `boxV`，其中含有一个地址。

原则上，我们是要“改变”，或者说复写 store 中对应地址上的值，我们可以通过两种方式实现这点：

1. 遍历 store，找到对应地址的绑定，然后替换该地址上绑定的值，store 中其它的绑定保持不变。
2. 或者懒一点，直接给 store 新增一个绑定，我们每次查询 store 时只查找最新得绑定即可。（就跟之前环境中 `lookup` 函数的实现一样）

两种选择都不会影响到下面的代码：

```scheme
;; ms-setboxC-case
  [setboxC (b v) (type-case Result (interp b env sto)
                   [v*s (v-b s-b)
                        (type-case Result (interp v env s-b)
                          [v*s (v-v s-v)
                               (v*s v-v
                                    (override-store (cell (boxV-l v-b) v-v)
                                                    s-v))])])]
```

当然，由于前面 `override-store` 是使用 `cons` 实现的，所以实际上我们使用的是第二种方式（注意这种选择是会影响 `fetch` 的实现的）。

> 练习
>
> 1. 使用另一种方式实现 store，避免 store 中出现对相同地址的多个绑定。
> 2. 考虑一下，上面我们查找存储值的地址时是否可能发生找不到的情况。如果不能，请指出解释器的哪个部分避免了这种情况的发生。

好了，现在我们只差函数调用的情况了！函数调用的整体流程我们已经很熟悉了：求值函数部分，求值参数部分，在闭包的环境中求值闭包的躯体部分。但是 store 是如何参与这一切的呢？

```scheme
;; ms-appC-case
  [appC (f a)
        (type-case Result (interp f env sto)
          [v*s (v-f s-f)
              (type-case Result (interp a env s-f)
                [v*s (v-a s-a)
                     <ms-appC-case-main>])])]
```

我们来考虑一下该怎么扩展闭包的环境。新增到环境中的绑定的名字显然应该是函数的参数名；但是它应该被绑定到什么地址呢？为了避免使用已有地址将招致的困惑（我们后面将详细介绍会招致何种困惑！），先使用新分配的地址吧。将该地址绑定到环境中，然后将求得的参数值存放在 store 的该地址上：

```scheme
(let ([where (new-loc)])
  (interp (closV-body v-f)
          (extend-env (bind (closV-arg v-f) where)
                      (closV-env v-f))
          (override-store (cell where v-a) s-a)))
```

我们也没说要把函数参数实现为可变的，所以其实也没必要考虑将参数实现为可变的。事实上使用跟以前一样的策略没有任何问题。观察一下，在上面这种实现中，参数的可变性也不会被用到：只有 `setboxC` 能够改变已有地址内容（严格来讲 `override-store` 只是对 store 的初始化），即只有一个地址被 `boxV` 引用了才可能被改变，但是上面并没有创建 `box`。上面这种实现中，参数求值结果放在 store 中只是出于一致性的考虑（我们现在环境中的绑定只有名字到地址的绑定，你当然可以添加一类绑定，即名字直接到值的绑定，但这样会导致很多额外的判断，具体情况请看下面练习）。

> 但是作为练习，考虑 store 的地址只能被 `box` 使用是非常有益的，想一下，需要改动什么？

（到这里我们又完成了一个解释器！照例，贴一下完整代码在这）

```scheme
#lang plai-typed

;; 语言核心结构
(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  [lamC (arg : symbol) (body : ExprC)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)]
  [boxC (arg : ExprC)]
  [unboxC (arg : ExprC)]
  [setboxC (b : ExprC) (v : ExprC)]
  [seqC (b1 : ExprC) (b2 : ExprC)])

;; 值
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)]
  [boxV (l : Location)])

;; 环境，存储（store）
(define-type-alias Location number)
(define-type Binding
  [bind (name : symbol) (val : Location)])

(define-type-alias Env (listof Binding))
(define mt-env empty)
(define extend-env cons)

(define-type Storage
  [cell (location : Location) (val : Value)])

(define-type-alias Store (listof Storage))
(define mt-store empty)
(define override-store cons)

(define (lookup [for : symbol] [env : Env]) : Location
  (cond
    [(= 0 (length env)) (error 'lookup "Can't find binding")]
    [else (let [(b (first env))]
            (if (symbol=? for (bind-name b))
                (bind-val b)
                (lookup for (rest env))))]))
(define (fetch [loc : Location] [sto : Store]) : Value
  (cond
    [(= 0 (length sto)) (error 'fetch "Invalid address")]
    [else (let [(storage (first sto))]
            (if (= loc (cell-location storage))
                (cell-val storage)
                (fetch loc (rest sto))))]))

;; 环境／存储得查询／寻值测试
(test 2 (lookup 'a (extend-env (bind 'b 1) (extend-env (bind 'a 2) mt-env))))
(test (numV 23) (fetch 2 (override-store (cell 1 (numV 20)) (override-store (cell 2 (numV 23)) mt-store))))

;; 值类型得加减操作
(define (num+ [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (+ (numV-n l) (numV-n r)))]
    [else (error 'num+ "one argument was not number")]))
(define (num* [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (* (numV-n l) (numV-n r)))]
    [else (error 'num* "one argument was not number")]))

(define-type Result
  [v*s (v : Value) (s : Store)])
(define new-loc
  (let ([n 0])
    (lambda ()
      (begin (set! n (+ n 1))
             n))))

;; 解释器
(define (interp [expr : ExprC] [env : Env] [sto : Store]) : Result
  (type-case ExprC expr
    [numC (n) (v*s (numV n) sto)]
    [idC (s) (v*s (fetch (lookup s env) sto) sto)]
    [appC (fun arg) (type-case Result (interp fun env sto)
                      ;; 【以此为例】 解释得到类型 Result
                      ;; 第一个子表达式的结果 v-fun 和计算过程返回的新的 store
                      [v*s (v-fun s-fun)
                           ;; 计算第二个子表达式使用了第一个子表达式返回的 store s-fun
                           (type-case Result (interp arg env s-fun)
                             ;; 第二个子表达式的结果 v-arg 和新的 store
                             [v*s (v-arg s-arg)
                                  ;; 根据具体的 case 得出最后的返回值 (v*s 值 新的store)
                                  (let ([where (new-loc)])
                                    (interp (closV-body v-fun)
                                            (extend-env (bind (closV-arg v-fun) where)
                                                        (closV-env v-fun))
                                            (override-store (cell where v-arg) s-arg)))])])]
    [plusC (l r) (type-case Result (interp l env sto)
                   [v*s (v-l s-l)
                        (type-case Result (interp r env s-l)
                          [v*s (v-r s-r)
                               (v*s (num+ v-l v-r) s-r)])])]
    [multC (l r) (type-case Result (interp l env sto)
                   [v*s (v-l s-l)
                        (type-case Result (interp r env s-l)
                          [v*s (v-r s-r)
                               (v*s (num* v-l v-r) s-r)])])]
    [lamC (arg body) (v*s (closV arg body env) sto)]
    [boxC (arg) (type-case Result (interp arg env sto)
                  [v*s (v-arg s-arg)
                       (let ([where (new-loc)])
                         (v*s (boxV where) (override-store (cell where v-arg) s-arg)))])]
    [unboxC (arg) (type-case Result (interp arg env sto)
                    [v*s (v-arg s-arg)
                         (v*s (fetch (boxV-l v-arg) s-arg) sto)])]
    [setboxC (b v) (type-case Result (interp b env sto)
                     [v*s (v-b s-b)
                          (type-case Result (interp v env s-b)
                            [v*s (v-v s-v)
                                 (v*s v-v (override-store (cell (boxV-l v-b) v-v) s-v))])])]
    [seqC (b1 b2) (type-case Result (interp b1 env sto)
                    [v*s (v-b1 s-b1)
                         (type-case Result (interp b2 env s-b1)
                           [v*s (v-b2 s-b2)
                                (v*s v-b2 s-b2)])])]
    ))

(type-case Result (interp (numC 10) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
(type-case Result (interp (unboxC (boxC (numC 10))) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
(type-case Result (interp (appC (lamC 'a (plusC (idC 'a) (idC 'a))) (numC 5)) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
(type-case Result (interp (appC (lamC 'a (plusC (idC 'a) (idC 'a))) (numC 5)) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
(type-case Result (interp (seqC (numC 20) (numC 10)) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
(type-case Result (interp (setboxC (boxC (numC 5)) (numC 10)) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
(type-case Result (interp (appC (lamC 'a (seqC (setboxC (idC 'a) (numC 10)) (unboxC (idC 'a)))) (boxC (numC 5))) mt-env mt-store) [v*s (v s) (test (numV 10) v)])
```

### 回顾思考

尽管前面完成了解释器的实现，仍然还有一些微妙的问题和一些洞察值得拿出来讨论一下。

1. 我们的解释器隐含了一个微妙但重要的设计抉择：**求值顺序**。例如，为什么我们不按如下方式实现加法？
    >
    > ```scheme
    > [plusC (l r) (type-case Result (interp r env sto)
    >                [v*s (v-r s-r)
    >                     (type-case Result (interp l env s-l)
    >                       [v*s (v-l s-l)
    >                            (v*s (num+ v-l v-r) s-l)])])]
    > ```
   事实上这样做完全没有问题。与之类似的，我们的 **store-passing** 模式的实现，实际上蕴含了先计算函数部分再计算参数部分这种抉择。注意到：

   * 以前，这种抉择直接代理给了宿主语言的实现（比如以前进行加法运算时，实际上直接将两个参数丢给了宿主语言的加法运算符，读者应该回去看看自己理一下），现在，**store-passing** 迫使我们顺序化了计算过程，因此该抉择实际上是由我们自己作出的（不管是有意还是无意）。
   * 更为重要的是，**这个抉择是语义上的**。在以前，加法一个分支参数上的计算不会影响另一个分支上的计算结果。而现在，分支上可能会执行 mutation 操作并因此影响到另一分之，因此作为该语言的程序员**必须**选择一定的顺序并预测程序按预期方式执行！
2. 观察调用规则，可以发现，我们沿途传递着动态 store，如，在计算函数部分和参数部分时传递的那个 store。这种行为跟我们对于环境的要求正好相对。这是个关键区别。store 从其效果上来说，是“动态作用域的（dynamically scoped）”，这是由于它是用于反映计算的历史，而不是用来反映词法上的东西。由于我们已经使用了名词“作用域（scope）”来表示标识符的绑定，这时再使用“动态作用域的”来描述 store 会造成困惑。于是我们引入一个新的名词，我们称它为 **persistent**。

   一些语言很容易将这两个概念搞混。例如在 C 语言中，绑定到本地标识符上的值（默认）在栈上分配。然而，这里栈对应于环境，因此它们将随着调用的结束而消失。如果返回值中引用了这些值，那么这个引用将会指向一个未定义地址，向该地址写入值可能导致数据被覆写：C 语言中很大一部分的错误来源于此。问题的关键是，值本身应该是**persist（持久的）**；只是指向它的那个标识符处在本地作用域中。

3. 我们已经讨论过两种实现覆写 store 的策略：简单的扩展它（将依赖于 `fetch` 的实现，需要它总是取出最新的绑定值）；或者采用“搜索替换”的方式。后面这种策略将使我们永久丢失对应地址上之前绑定的值。

   然而我们并没有考虑过内存管理。随着程序的运行，我们可能永久失去访问特定 `box` 的能力，如一个 `box` 仅被绑定到一个标识符，而该标识符不在处于当前作用域的时候。这样的位置被称为**垃圾**。从概念上来讲，垃圾的地址是那些清除之后对程序求值结果没有任何影响的地址。有很多用于辨别并回收垃圾的策略，通常被称作“垃圾回收”。

4. 要注意，计算每个表达式的时候，总是要让后面的计算依赖之前返回的 store 以正确维护执行历史。比如，考虑下面这种 `unboxC` 的实现：
   > ```scheme
   > [unboxC (a) (type-case Result (interp a env sto)
   >               [v*s (v-a s-a)
   >                    (v*s (fetch (boxV-l v-a) sto) s-a)])]
   > ```
   注意到没有，我们不是从 `s-a` 而是从 `sto` 中搜索值。但是 `sto` 反映的是 `unboxC` 未求值之前的执行历史（即反映的是那之前所有 mutation 操作）。考虑下面这段程序：
   > ```scheme
   > (let ([b (box 0)])
   >   (unbox (begin (set-box! b 1) b)))
   > ```
   如果按照上面这种错误的实现，它将得到 0 而不是正确的值 1。

5. 下面是另一个常见错误：
   > ```scheme
   > [unboxC (a) (type-case Result (interp a env sto)
   >               [v*s (v-a s-a)
   >                    (v*s (fetch (boxV-l v-a) s-a) sto)])]
   > ```
   这个实现错在哪呢？注意到，它返回的是原始的 store，因此，`unboxC` 求值过程中的 mutation 操作对之后其它的求值将不能造成正确的影响。考虑代码：
   > ```scheme
   > (let ([b (box 0)])
   >   (+ (unbox (begin (set-box! b 1)
   >                    b)
   >      (unbox b)))
   > ```
   它本应该得 2，但是由于加法第一个表达式求值过程中的 mutation 操作没有被正确记录，导致结果为 1。

   如果把第4点和第5点中 bug 结合起来，该表达式的结果将变成 0.

   > 练习，回头看看实现的编辑器，看看有没有这些 bug，修复它们。

6. 注意到我们可以通过使用旧的 store 进行时间回溯：是 mutation 在程序中引入了时间的概念；我们可以通过撤销 mutation 操作来达到回溯的目的。这听起来好像很有趣还有点任性；它有使用场景吗？

   有！想象一下我们不直接改变 store，而是引入 **intended update** 得日志的概念到 store中。日志像前面 store 那样线性的实现。一些指令用于创建新的日志；对于查询操作，它首先检查日志，如果没有找到相关绑定，再在实际 store 中查找。还要添加两个指令：**discard**（忽略）日志（用于进行时间回溯），以及 **commit**（提交）操作（用于将日志中的修改应用到实际 store 中）。

   事实上这就是软件事物内存（Software Transactional Memory, STM）。每条线程维护自己的日志，未提交部分的改变只有自己能看到。每个线程可以维护自己的状态，如果 commit 成功，那么其提交的绑定将通过全局 store 被所有其它线程看到；如果提交失败，也可以很容易的通过 discard 剔除改变。

   STM 提供了一种很直观的多线程编程的方法。



## 变量

上面实现了可变结构，下面考虑另一种情况：变量。

### 术语

首先，关于名词的选择。之前我们一直坚持使用单词“标识符”，这是因为我们想将“变量”留给我们将要学习的东西。在 Java 中，当我们写出（这里假设 `x` 为本地绑定的，如作为一个方法的参数）

```Java
x = 1;
x = 3;
```

我们是在要求**改变** `x` 的值。在第一个赋值语句之后，`x` 的值为 1；第二个之后为 3。因此， `x` 会在方法的执行过程中发生**变化**。

我们在数学中通常也会使用“变量”这个词表示函数参数。例如，在 `f(y) = y + 3` 中，我们说 `y` 为“变量”。这里它被称为变量是由于**不同的调用中** `y`  的值可能不同；而在每次调用中，在其作用域内它的值不会发生改变。之前的标识符对应于这种意义上的变量。与之相对的，程序变量在每次调用内部都有可能发生变化，如上面 Java 代码中的 `x`。

此后，我们使用**变量**表示在其作用域内值可以发生变化的标识符，而值不能变化的使用**标识符**表示。在对一个符号属于哪种情况存疑的时候，我们安全点称之为“变量”；如果这种区分不太重要时，我们可能使用其中任意一个。不要被这些名词搞得头大，重要的是理解它们的区别。

> 如果一个标识符被绑定到一个 `box`，那么它将总是被绑定到同一个 `box` 值。会发生改变的是 `box` 的内容，而其绑定的 `box` 不会改变。

### 语法

大部分语言使用语法形式 `=` 活着 `:=` 表示赋值，在 Racket 中这不太一样：`set!` 用于表示变量赋值。

关于变量赋值首先要认识到的是，尽管它和 box mutation （setboxC） 一样有两个子表达式，但是从语法上看是完全不同的。为了理解其中区别，先考虑下面的 Java 代码段：

```Java
x = 3;
```

在这个赋值语句中，`x` 的位置不能为任意表达式：它必须为要改变的那个变量标识符。这是因为，如果该位置为任意表达式，那么我们就必须可以对其进行求值，然后得到一个值：例如，如果 `x` 之前绑定到 1，那就意味着我们将会产生下面这样的式子：

```Java
1 = 3;
```

但显然这是没意义的！我们事实上想要的是找到 `x` 在 store 中的位置，然后改变该位置上存的值。

再看一个例子。假设本地变量 `o` 被绑定到一个字符串对象 `s`，然后我们写出下面的语句：

```Java
o = new String("a new string");
```

考虑该语句，我们是想在任何意义上对 `s` 进行改变吗？当然不是。我们显然只是想改变 `o` 表示的值，以使得后面程序中 `o` 被求值时得到的是这个新的字符串对象。

### 解释器之变量

首先定义语法：

```scheme
(define-type ExprC
  [numC (n : number)]
  [varC (s : symbol)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)]
  [lamC (arg : symbol) (body : ExprC)]
  [setC (var : symbol) (arg : ExprC)]
  [seqC (b1 : ExprC) (b2 : ExprC)])
```

可以看见我们丢弃了 `box` 相关操作，但是保留了序列，因为包含可变值的程序中它很好用。注意我们添加的 `setC` 形式，其第一个子句不是一个表达式而是变量的名字。同时我们还将 `idC` 改作 `varC`。

由于移除了 `box`，值也需要作改变：

```scheme
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)])
```

可能和你你想的一样，为了支持变量，处于和前面相同的原因，我们仍需要前面提出的 *store-passing style*。区别仅在于如何使用它。注意到之前序列操作部分的实现并不依赖于要改变的东西是什么（box 还是变量），因此这部分代码将不需要变动。于是就只剩下变量赋值需要处理了。

对于赋值操作，我们应该还是先要获取对值部分求值更新后的 store：

```scheme
;; setC-case
 [setC (var val) (type-case Result (interp val env sto)
                   [v*s (v-val s-val)
                        <rest-of-setC-case>])]
```

前面也讨论过，对于变量部分，我们不应该求出其值（这样会面临 `1=1` 的尴尬），而是应该获取它对应的存储地址，然后更新该地址中的内容，和之前 box 的处理类似：

```scheme
;; rest-of-setC-case
  (let ([where (lookup var env)])
    (v*s v-val
         (override-store (cell where v-val)
                         s-val)))
```

在 box 的处理过程中，对于 `idC` 的处理是：先从环境中找到该标识符绑定的地址，然后再直接返回从 store 中寻得的值；其结果是一个值，和放到 store 中的是同一类东西。而现在，对于变量标识符的处理止步于从环境中获取值的存储地址；这里的返回值按按照传统被称为“左值”，“（赋值语句）左侧的值”之意。是存储地址，而不是 store 中存储的真实值，注意到它并不和 `Value` 中任何类型对应。

然后就没有然后了！这个解释器已经完成了。所有麻烦事已经在之前实现 *store-passing style* 时做完了。

（妈呀，这一章太长了，最后一节看上去不怎么好翻译，先把前面的发出来吧）