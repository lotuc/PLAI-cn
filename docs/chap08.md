# 8 可变结构体和变量

游戏又来了

**下列各表达式哪些意义相同的？**

- `f = 3`
- `o.f = 3`
- `f = 3`

假设都是使用 Java 书写。第一个和第三个的意义可能一样，也可能和第二个相同：完全取
决于`f`是局域标识符（比如参数）还是对象的字段（如，作为`this.f = 3`的简写）。

不管是哪种情况，求值器都将永久改变绑定到`f`的值。这对其他观察者而言影响很大。到
目前为止，我们实现的计算过程对于相同的输入总是给出相同的输出。现在计算的答案还取
决于它在**何时**进行：在`f` 的值改变前还是后。时间的引入对于代码的推理有深远影响
。

此外，上述简单的语法包含了两种不同的改变：改变字段的值（`o.f = 3`或
者`this.f = 3`）和改变标识符的值（`f = 3`，其中`f`在方法内部被绑定而不是由对象绑
定）有着非常大的区别。我们会依次讨论它们。首先探讨字段，再在[变量](#变量)那一节
中探讨标识符。

## 8.1 可变结构体

### 8.1.1 可变结构体的简化模型

很快我们会带大家认识到，对象其实就是一般化的结构体。对象中的字段可认为是结构体中
字段的一般化的结果。要理解赋值，理解可变对象大致足够了（并不完全足够）。为了简单
起见，我们甚至不需要结构体具有多个字段：一个字段就足够了。我们称该结构
为**box**。在 Racket 中，box 仅支持三种运算：

```Racket
box : ('a -> (boxof 'a))
unbox : ((boxof 'a) -> 'a)
set-box! : ((boxof 'a) 'a -> void)
```

`box`接受一个值，将其包裹在可变容器中。`unbox`取出容器中的当前值。`set-box!`改变
容器中的值，对于静态类型的语言来说，新值需要和旧值保持类型一致。如果对应到 Java
中的话，box 大致等价于带类型参数的 Java 容器类，只有一个字段，外
加`getter`和`setter`:`box`对应构造器，`unbox`对应`getter`，`set-box!`对
应`setter`（由于只有一个字段，所以字段名也无所谓了）：

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

由于赋值操作经常成组进行（例如，从银行账户中取出一些钱存放到另一个账户中），支持
赋值操作的序列将非常有用。在 Racket 中，你可以使用`begin`表示操作的序列；它将依
次计算序列中的每个表达式然后返回最后一个的求值结果。

**练习**

> 尝试使用`let`对`begin`去语法糖（还可以进一步去语法糖到`lambda`）。

尽管可以将`begin`当作语法糖（从核心语言中）去除，但是它对理解赋值的内部原理非常
有用。因此我们还是决定直接在核心语言中支持简单的`begin`，该`begin`形式只允许两个
子项。

> 这也说明，去语法糖没有绝对的规范。我们选择在核心语言中加上这个构造，而它并不是
> 必须的。如果我们的目的是尽可能减小解释器的体积——即使增大输入程序的体积也在所不
> 惜——那么就不应该这么做。不过我们在本书中的目的是学习（适合教育目的的）解释器，
> 那么选择大一点的语言更加有指导性。

### 8.1.2 脚手架

首先，扩展语言的核心数据类型：

```Racket
(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)]
  [lamC (arg : symbol) (body : ExprC)]
  [boxC (arg : ExprC)]
  [unboxC (arg : ExprC)]
  [setboxC (b : ExprC) (v : ExprC)]
  [seqC (b1 : ExprC) (b2 : ExprC)])  ; 序列
```

注意`setboxC`表达式中，两个操作对象均为表达式。值（v）为表达式很自然，没什么奇怪
的；但是`box`参数（b）为表达式的话乍一看还挺奇怪的。它意味着我们可以写出对应于如
下 Racket 代码的程序：

```Racket
(let ([b0 (box 0)]
      [b1 (box 1)])
  (let ([l (list b0 b1)])
    (begin
      (set-box! (first l) 1)
      (set-box! (second l) 2)
      l)))
```

其计算结果为`box`的链表，第一个 box 包含的值为`1`，第二个包含的值为`2`。【注释】
观察程序中第一个`set-box!`指令，其第一个参数为`(first l)`，也就是说，是计算结果
为`box`的表达式，而不是字面的`box`也不是标识符。和 Java 中下列代码类似（放松类型
要求）：

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

> 输出可能是`’(#&1 #&2)`。`#&`是 Racket 中 box 类型的语法缩写形式。

注意到其中`l.get(0)`为复合表达式，它得到一个`box`对象，然后调用其`set`方法。

为方便起见，我们假设已经实现了下列去语法糖操作：

1. `let`
2. 必要的话，多于两个子项的序列（可以去语法糖为嵌套的序列）

有时我们还会直接使用 Racket 语法写程序，一方面是为了简洁（我们的核心语言将变得大
而笨重），一方面方便你可以直接在 Racket 中运行相关代码观察结果。也就是说，我们会
使用 Racket（大部分主流语言中可变对象和结构体行为都与之类似）作为我们实现的参照
。

### 8.1.3 与闭包的交互

考虑如下的简单计数器：

```Racket
(define new-loc
  (let ([n (box 0)])
    (lambda ()
      (begin
        (set-box! n (add1 (unbox n)))
        (unbox n)))))
```

每次调用，它都会返回下一个自然数：

```Racket
> (new-loc)
- number
1
> (new-loc)
- number
2
```

为什么会这样呢？这是因为其中的`box`只被创建了一次，它被绑定到了`n`，然后该绑定被
放进闭包。所有后续的赋值操作改变的都是**同一个`box`**。如果交换两行代码，结果就
完全不同了：

```Racket
(define new-loc-broken
  (lambda ()
    (let ([n (box 0)])
      (begin
        (set-box! n (add1 (unbox n)))
        (unbox n)))))
```

运行看看：

```Racket
> (new-loc-broken)
- number
1
> (new-loc-broken)
- number
1
```

这种情况下，每次调用函数都会创建新的`box`，所以每次的计算结果都是一样的（尽管程
序内部也变动了 `box`的值）。我们对于`box`的实现也应该正确重现这种区别。

上面的例子给了我们一点关于实现上的提醒。显然，`new-loc`的闭包中每次引用的必须是
同一个 `box`。然而我们还需要做些工作来确保获得的`box`中的值每次都是不同的！请仔
细体会：它从**词法**上来看必须是相同的，但是**动态**的值却是不同的。这个区分将是
我们实现的核心。

### 8.1.4 理解 box 的解释

首先重现一下当前的解释器：

```Racket
<interp-take-1> ::=  ; 解释器，第一次尝试

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
        <boxC-case>    ; box 子句
        <unboxC-case>  ; unbox 子句
        <setboxC-case> ; setbox 子句
        <seqC-case>))  ; 序列子句
```

由于引入了新类型的值——box，我们需要更新返回值的数据类型：

```Racket
<value-take-1> ::=  ; 值，第一次尝试

    (define-type Value
      [numV (n : number)]                                ; 数
      [closV (arg : symbol) (body : ExprC) (env : Env)]  ; 闭包
      [boxV (v : Value)])
```

先实现两种简单的情形。对于`box`表达式，直接求值并使用`boxV`包裹后返回：

```Racket
<boxC-case-take-1> ::=  ; box 子句，第一次尝试

    [boxC (a) (boxV (interp a env))]
```

同样，从`box`中提取值也很简单：

```Racket
<unboxC-case-take-1> ::=  ; unbox 子句，第一次尝试

    [unboxC (a) (boxV-v (interp a env))]
```

到这里你应该已经写过一组测试，来保证新加代码行为同预期一样。

当然，现在还没有做到难的部分。可以预见，所有有意思的行为都在对`setboxC`的处理上
。然而，我们却要先考察`seqC`（你会看到我们为什么把它加到核心语言中）。

先试试二目序列最自然的实现方式：

```Racket
<seqC-case-take-1> ::=  ; 序列子句，第一次尝试

    [seqC (b1 b2) (let ([v (interp b1 env)])
                    (interp b2 env))]
```

即先计算第一个子项，然后计算第二个子项并返回其计算结果。

你应当迅速察觉到一些问题，我们计算了第一个子项并把它的值绑定到了`v`，但是后面的
计算过程中没有用它。这倒没关系：正常来说，第一个子项中包含了某种赋值操作，其返回
值没啥用（确实，注意`set-box!`返回 void 值）。那么我们可以实现如下：

```Racket
<seqC-case-take-2> ::=  ; 序列子句，第二次尝试

    [seqC (b1 b2) (begin
                    (interp b1 env)
                    (interp b2 env))]
```

这种实现并不令人满意，它直接使用了 Racket 中的序列操作（无助于我们理解），更严重
的问题是，它不可能是正确的！因为，我们必须要把**赋值操作的结果存储起来**。但是，
我们的解释器只能求出表达式的值，任何在`(interp b1 env)`中进行的赋值操作都将丢失
。显然这不是我们想要的。

### 8.1.5 环境能帮我们解决问题吗？

下面这个例子能给我们一点启示：

```Racket
(let ([b (box 0)])
  (begin (begin (set-box! b (+ 1 (unbox b)))
                (set-box! b (+ 1 (unbox b))))
         (unbox b)))
```

在 Racket 中，它求值得`2`。

**练习**

> 使用`ExprC`表示该表达式。

考虑内层的`begin`的求值过程。它的两个子项（`(set-box! ...)`的`ExprC`表示）完全相
同。然而幕后肯定有什么东西悄悄改变了，因为`box`中的值会从 0 变成 2！上面的例子修
改一下我们能“看”得更清楚：

```Racket
(let ([b (box 0)])
  (+ (begin (set-box! b (+ 1 (unbox b)))
            (unbox b))
     (begin (set-box! b (+ 1 (unbox b)))
            (unbox b))))
```

这下求值得到 3。这里，当处理到加法时，需要对两个操作数调用两次`interp`，传给它们
的表达式是完全相同的。然而，第一个调用的行为显然会被第二个调用感知到。我们需要解
开背后的魔法。

如果给解释器输入了两个一模一样的表达式，它返回的结果怎么会不一样呢？最简单的解释
，解释器的另一个参数，即环境，发生了某些变化。我们现有的解释器在处理加法时，对俩
个操作数调用`interp`时用的环境是一样的；在处理序列时，对两个子项调用`interp`时用
的环境也是一样的。所以现有的解释器，是不可能产生我们想要的结果的——相同的输入总是
会得出相同的输出。

通过上述例子我们得到的一些启示：

1. 多次调用解释器，并且我们认为其返回值可能不同的情况下，我们需要确保传递给解释
   器的参数也不同
2. 解释器需要返回一种记录，其中保存了求值过程中进行过的赋值

由于输入的表达式不可能改变，所以第一条指引我们使用环境来反映不同调用之间的不同。
结合第二点我们很自然的想到让解释器**返回**环境，然后可以将它传递给下一个调用。于
是，大致来说解释器的类型可能就变成：

```Racket
; interp : ExprC * Env -> Value * Env
```

即，解释器接收表达式和环境作为参数；在该环境中求值，同时求值过程中更新环境；计算
完成后（和以前一样）返回求值结果，**同时还**返回更新后的环境。新的环境被传入解释
器的下一次调用中。`setboxC`的处理过程中应该会影响到环境，以反应它所执行的赋值操
作。

在着手实现之前，我们应先考虑这种改变的后果。环境已经负担了重任：保存被延迟的替换
操作的所需的信息。它已经有非常明确的语义 ——由替换给定——我们应该注意，不要影响这
层语义。它和替换之间的这种关系使得它成为了**词法作用域的信息仓库**。如果我们扩展
环境的功能，使得加法的一个参数分支中的绑定通过它可以传递到另一个参数分支中，例如
，考虑下面的程序：

```Racket
(+ (let ([b (box 0)])
     1)
   b)
```

显然该程序将报错：加法的第二个参数`b`是未绑定的（`b`的作用域终止于`let`表达式的
终结——如果上面的代码对你来说不够清晰，用函数把`let`语法糖去除）。但是，如果扩展
了环境的功能，解释完第一个参数后产生的环境中显然包含了`b`的绑定信息。

**练习**

> 尝试使用已有的解释器的逻辑运行这段代码，以确保真正理解上面表达的意思。

当然你可能考虑其它实现方式，不过它们一般来说都会导致类似的失败。比如你可能会想，
由于问题出在多余的绑定上，我们可以将返回的环境中多余的绑定直接移除。听上去不错，
但是你还记得我们还需要实现闭包吗？

**练习**

> 考虑如下程序的`ExpC`表示：
>
> ```Racket
> (let ([a (box 1)])
>   (let ([f (lambda (x) (+ x (unbox a)))])
>     (begin
>       (set-box! a 2)
>       (f 10))))
> ```
>
> 看看这个方案有啥问题。

要认识到，前面提到的两个启示中的**约束**都是有效的，但是**解决方案**并不在上面提
出的这些尝试中。再仔细想想，那两个启示中所提出的约束都没要通过环境去实现。而且环
境显然也**没法**负起这个职责。

### 8.1.6 引入贮存

通过上一节的讨论，我们意识到需要**额外的**仓库来记录表达式的解释过程。仓库之一是
环境，还是执行本来赋予它的职责，维护词法作用域。但是环境不能直接将标识符映射到值
，因为现在值是可能会变的。也即，我们需要额外的东西用于维护可变`box`的动态状态，
这个额外的东西被称之为**贮存**（store）。

和环境一样，贮存也是映射结构。它的值域可以是任意的名字的集合，不过自然的想法是将
其想作用于表示内存地址的数。这是因为，在语义上来说，存储就对应于（抽象的）计算机
的物理内存，而传统上内存地址一般采用数进行寻址。因此环境是将名字映射到地址，然后
贮存将地址映射到具体的值。

```Racket
(define-type-alias Location number)  ; 地址

(define-type Binding                 ; 绑定
  [bind (name : symbol) (val : Location)])

(define-type-alias Env (listof Binding))    ; 环境
(define mt-env empty)
(define extend-env cons)

(define-type Storage                        ; 贮存物
  [cell (location : Location) (val : Value)])

(define-type-alias Store (listof Storage))  ; 贮存
(define mt-store empty)                     ; 空贮存
(define override-store cons)                ; 覆盖贮存
```

我们还需要提供函数用于在贮存中查询值，就跟之前的环境一样（现在环境中查询的结果是
地址了）。

```Racket
(define (lookup [for : symbol] [env : Env]) : Location
  ...)
(define (fetch [loc : Location] [sto : Store]) : Value
  ...)
```

有了这些，就能完成解释器返回值的正确表示了：

```Racket
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)]
  [boxV (l : Location)])
```

**练习**

> 完成查询函数`lookup`和获取函数`fetch`的函数体部分。

### 8.1.7 解释器之解释`box`

现在有了贮存，环境可以返回之、可以更新之从而反映求值过程中的赋值，而且赋值本身不
需要修改环境中的内容。由于函数只能返回一个值，我们考虑定义一个数据结构用于存放解
释器的返回值：

```Racket
(define-type Result  ; 结果
  [v*s (v : Value) (s : Store)])
```

于是，解释器的类型变成了这样：

```Racket
<interp-mut-struct> ::=  ; 解释器，可变结构体

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

数的解释依然是最简单的。记住我们需要返回贮存，该贮存反映求值输入表达式过程中所发
生的全部赋值。由于数是常量，求值过程不会有赋值发生，所以，直接返回传入的贮存即可
：

```Racket
<ms-numC-case> ::=

    [numC (n) (v*s (numV n) sto)]
```

创建闭包也是一样；注意是闭包的创建而不是调用：

```Racket
<ms-lamC-case> ::=

    [lamC (a b) (v*s (closV a b env) sto)]
```

标识符的处理很直接。当然如果你的实现过于简单，类型系统会告诉你错在哪里：为了获取
返回值，你即要查询环境也要查询贮存：

```Racket
<ms-idC-case> ::=

    [idC (n) (v*s (fetch (lookup n env) sto) sto)]
```

注意到`lookup`和`fetch`组合在一起完成之前由`lookup`完成的工作。

接下来的事情才有意思呢。

考虑序列的处理。显然，我们需要解释两个子项：

```Racket
(interp b1 env sto)
(interp b2 env sto)
```

等一下。我们的目的是，当对第二个子项求值时**使用第一个子项返回的贮存**——否则这么
多改变就毫无意义了。因此我们必须先对第一个子项求值，获取其返回的贮存，用它对第二
个贮存的求值：

```Racket
<ms-seqC-case> ::=

    [seqC (b1 b2) (type-case Result (interp b1 env sto)
                    [v*s (v-b1 s-b1)
                         (interp b2 env s-b1)])]
```

先调用`(interp b1 env sto)`，其返回的值和贮存被分别命名为`v-b1`和`s-b1`；接下来
使用新的贮存对第二个子项求值：`(interp b2 env s-b1)`。它的返回值该子项的值和贮存
，正好是我们需要的东西。代码也可以反映出，第一个子项的唯一效果就是其返回的贮存：
虽然我们绑定了`v-b1`但后文并没有用到它。

**思考题**

> 你可以多花点时间玩味一下这段代码。后面将经常用到该种模式的代码。

下面来处理双目算术运算。它们和序列的求值类似，也含有两个子项要处理，但是这里我们
还需要用到两个子项各自的值。和以前一样，我们只给出`plusC`，`multC`的代码基本上相
同：

```Racket
<ms-plusC/multC-case> ::=

    [plusC (l r) (type-case Result (interp l env sto)
                   [v*s (v-l s-l)
                        (type-case Result (interp r env s-l)
                          [v*s (v-r s-r)
                               (v*s (num+ v-l v-r) s-r)])])]
```

同样的模式这里用了两层，以便我们分别取得两个返回值，然后将其传给`num+`。

这里可以看到环境和贮存的重要区别。当对子项求值时，根据语言的作用域规则，通常所有
子项都使用相同的环境。环境的传递遵从递归向下的模式。与之相对，贮存是线式传递的：
所有的分支并不使用同一个贮存，前一个分支产生的贮存后一个分支使用，最后一个分支的
贮存就是总的返回贮存。这种风格被称作**贮存传递模式（store-passing style）**。

现在谜题彻底揭晓，贮存传递模式就是我们的秘密神器：它在保障环境依旧正确处理词法作
用域的同时，给了我们能够记录赋值操作的方法。直觉告诉我们，环境肯定参与这个过程，
同一个表达式可以返回不同的值，现在我们可以看清这是怎么做到的了：不是直接修改环境
实现，而是环境间接的引用了贮存，而贮存会更新。下面我们需要看看贮存是如何“更新”自
己的。

首先考虑将值放到`box`中。我们得分配一块地方让贮存放东西。`box`的值会记住该地址，
用于之后`box`的赋值操作。

```Racket
<ms-boxC-case> ::=

    [boxC (a) (type-case Result (interp a env sto)
                [v*s (v-a s-a)
                     (let ([where (new-loc)])
                       (v*s (boxV where)
                            (override-store (cell where v-a)
                                            s-a)))])]
```

**思考题**

> 注意了注意了，上面的代码依赖于`new-loc`，而`new-loc`的实现中又用到了`box`。这
> 就很尴尬了。你能不能修改解释器，使其不再依赖于类似于`new-loc`这种本身需要赋值
> 的东西？

要消除`new-loc`这种类型的东西，最简单的方式是再给解释器添加参数和返回值，用于表
示当前使用过的最大地址。每次分配贮存地址的操作都会返回递增过的地址，而其它操作则
直接返回原最大地址。换一种说法，我们又用了一次贮存传递模式。这样去实现的话解释器
会显得太笨拙，以至于掩盖更重要的内容：用贮存传递模式实现贮存。这也就是为啥这里我
们没这么做的原因。但是，我们必须明白这么做是可行的：不依赖于`box`而在我们的语言
中实现`box`。

由于`box`记录内存地址，获取`box`中的值比较简单：

```Racket
<ms-unboxC-case> ::=

    [unboxC (a) (type-case Result (interp a env sto)
                  [v*s (v-a s-a)
                       (v*s (fetch (boxV-l v-a) s-a) s-a)])]
```

用到了同样的模式，具体来说我们调用`fetch`来获取该地址中的实际值。注意这里的代码
没有判断`a`的求值结果是否是`boxV`，而是依赖于宿主语言 Racket 在不是时抛出异常；
如果是别的宿主语言，不进行该类型判断就可能很危险了（比如 C 语言，相当于允许访问
任意内存）。

下面考虑怎么更新`box`中的值。首先还是要求值得到`box`和要放入的新值。`box`的值将
为`boxV`类型，其中含有地址。

原则上，我们是要“改变”，或者说覆盖贮存中对应地址上的值。有两种方式可以实现这点：

1. 遍历贮存，找到对应地址的绑定，然后替换该地址上绑定的值，贮存中的其它绑定保持
   不变。
2. 懒一点的做法，直接给贮存新增绑定，而查询贮存时只查找最新的绑定即可（就跟环境
   中 `lookup`函数的实现一样，没有理由`fetch`不这么干）。

两种选择都不会影响到下面的代码：

```Racket
<ms-setboxC-case> ::=

    [setboxC (b v) (type-case Result (interp b env sto)
                     [v*s (v-b s-b)
                          (type-case Result (interp v env s-b)
                            [v*s (v-v s-v)
                                 (v*s v-v
                                      (override-store (cell (boxV-l v-b)
                                                            v-v)
                                                      s-v))])])]
```

当然，由于前面`override-store`的实现就是`cons`而已，我们实际上使用的是比较偷懒的
方式（而且是有风险的选择，因为它还取决于`fetch`的实现）。

**练习**

> 实现另一种方式的贮存更新，更新原有的绑定关系，避免贮存中出现相同地址的多个绑定
> 。

**练习**

> 在更新步骤中，当我们查找贮存中的地址时，是否可能发生找不到某个地址的情况？如果
> 可能，请编写程序演示这种情况。如果不能，请指出解释器的哪个不变量避免了这种情况
> 的发生。

好了，现在我们只差函数调用的情况了！函数调用的整体流程我们已经很熟悉了：求值函数
部分，求值参数部分，扩展闭包的环境，然后再其中求值闭包的函数体部……但是贮存是如何
参与这一切的呢？

```Racket
<ms-appC-case> ::=

    [appC (f a)
          (type-case Result (interp f env sto)
            [v*s (v-f s-f)
                 (type-case Result (interp a env s-f)
                   [v*s (v-a s-a)
                        <ms-appC-case-main>])])]  ; 调用子句主体
```

从如何扩展闭包的环境入手好了。新增绑定的名字显然应该是函数的形参；但是它应该被绑
定到什么地址呢？为了避免使用已有地址将招致的困惑（我们后面将详细介绍会招致何种困
惑！），先使用新分配的地址吧。将该地址绑定到环境中，然后将求得的参数值存放在贮存
的该地址上：

```Racket
<ms-appC-case-main> ::=  ; 调用子句主体

    (let ([where (new-loc)])
      (interp (closV-body v-f)
              (extend-env (bind (closV-arg v-f)
                                where)
                          (closV-env v-f))
              (override-store (cell where v-a) s-a)))
```

我们也没说要把函数参数实现为可变的，所以其实也没必要这么实现函数调用。事实上使用
跟以前一样的策略没有任何问题。观察一下，在上面这种实现中，这个地址中的值也不会被
修改：只有`setboxC`能够改变现有地址的内容（严格来讲`override-store`只是对贮存
的**初始化**），而且只能改变`boxV`中的数据，但是这里并没有创建`box`。我们这么实
现是出于统一的考虑，并且这么做还可以减少需要处理的子句。

**练习**

> 将贮存地址限制为**只能**被`box`使用是很好的练习。有哪些代码需要改动？

### 8.1.8 回顾思考

尽管完成了解释器的实现，仍然还有不少微妙的问题和一些洞察值得拿出来讨论一下。

1. 我们的解释器实现中隐藏了一个巧妙但重要的设计抉择：**求值的顺序**。例如，为什
   么我们不按如下方式实现加法？

   > ```Racket
   > [plusC (l r) (type-case Result (interp r env sto)
   >                [v*s (v-r s-r)
   >                     (type-case Result (interp l env s-l)
   >                       [v*s (v-l s-l)
   >                            (v*s (num+ v-l v-r) s-l)])])]
   > ```

   事实上这样做也是自洽的。类似地，贮存传递模式中蕴含了先计算函数部分再计算参数
   部分这种抉择。注意到：

   - 以前，这种抉择直接代理给了宿主语言的实现，现在，贮存传递迫使我们把计算过
     程**顺序化**，因此该抉择是由我们自己作出的（不管是有意还是无意）。
   - 更为重要的是，**现在这是语义上的抉择了**。在没有赋值之前，加法一个分支上的
     计算不会影响另一个分支上的计算结果。【注释】而现在，分支上可能会执行赋值操
     作从而因此影响到另一分支，因此要使该语言的程序员能预测自己程序的行为，我
     们**必须**选择某种求值顺序！明确地写出贮存传递解释器也表明了这一点。

2. 观察函数调用的规则，可以发现，我们往下传递的是**动态的**贮存，即，先后经过了
   计算函数和计算参数的那个贮存。这种行为跟我们对于环境的要求正好相反。这是个关
   键的区别。贮存从其效果上来说，是“动态作用域的（dynamically scoped）”，这是由
   于它是用于反映计算的历史，而不是用来反映词法上的东西。由于我们已经使用了名词“
   作用域（scope）”来表示标识符的绑定，这时再用“动态作用域的”来描述贮存可能会造
   成困惑。于是我们引入新名词**持久的（persistent）**来描述贮存。

   一些语言中这两个概念混淆不清。例如在 C 语言中，绑定到局域标识符上的值（默认）
   在堆栈上分配。然而，堆栈对应于这里的环境，因此它们将随着函数调用的结束而消失
   。如果函数返回值中引用了这些值，那么这个引用将会指向某个未使用的地址，或者被
   用作他用的地址：C 语言中很大一部分错误来源于此。问题的关键是，值本身不会消失
   ；消失指向它们的、具有词法作用域的标识符。

3. 我们已经讨论过两种实现覆写贮存的策略：简单的扩展之（将依赖于`fetch`的实现，需
   要它总是取出最新的绑定）；或者采用“搜索替换”的方式。后面这种策略有个好处，不
   会存储那些无用的、永远不可能访问得到的数据。

   然而这么做还是会浪费内存。随着程序的运行，我们会永久失去访问某些`box`的能力：
   例如，某个`box`仅被绑定到一个标识符上，程序走出该标识符的作用域后（将再也不能
   访问到该`box`）。这些不能被访问到的位置被称为**垃圾**（garbage）。从概念上来
   讲，垃圾地址是那些清除之后对程序求值结果没有任何影响的地址。有很多用于辨别并
   回收垃圾的策略，通常被称作**垃圾回收**（garbage collection）。

4. 要注意，计算表达式的时候，总是要让后面的计算依赖之前返回的贮存以维护正确的执
   行历史。比如，考虑下面这种`unboxC`的实现：

   > ```Racket
   > [unboxC (a) (type-case Result (interp a env sto)
   >               [v*s (v-a s-a)
   >                    (v*s (fetch (boxV-l v-a) sto) s-a)])]
   > ```
   >
   > 注意到区别没有？我们没有从`s-a`而是从`sto`中获取值。但`sto`反映的
   > 是`unboxC`未求值之前的赋值历史，而没有包含它求值**过程中**的赋值历史
   > 。`unboxC`表达式求值过程中贮存可能发生改变吗？当然了！
   >
   > ```Racket
   > (let ([b (box 0)])
   >   (unbox (begin (set-box! b 1) b)))
   > ```
   >
   > 如果按照上面这种错误的实现，它将得到 0 而不是正确的值 1。

5. 下面是另一个类似的错误：

   > ```Racket
   > [unboxC (a) (type-case Result (interp a env sto)
   >               [v*s (v-a s-a)
   >                    (v*s (fetch (boxV-l v-a) s-a) sto)])]
   > ```
   >
   > 什么例子程序可以展示其错误呢？注意到，它返回的是原始的贮存，未经`unboxC`求
   > 值过程修改。所以我们需要在后续代码中访问贮存：
   >
   > ```Racket
   > (let ([b (box 0)])
   >   (+ (unbox (begin (set-box! b 1)
   >                    b)
   >      (unbox b)))
   > ```
   >
   > 它本应求值得 2，但是由于返回的贮存中 b 的值一直绑定为 0，导致结果为 1。

   如果把前述二点中的错误结合起来——解释器子句中最后一行两次都使用`sto`而不
   是`s-a`——该表达式的结果将变成 0.

   **练习**

   > 将解释器中所有贮存，逐一替换为更新前的贮存；对每一个这样的修改，给出能够显
   > 示其错误的测试案例；请确保你最后得到覆盖所有情况的测试案例集。

6. 观察前述对“旧”贮存的使用，它允许我们进行**时间回溯**：赋值引入了时间的概念；
   使用原先的贮存则允许我们回到过去，也就是赋值没有发生之前。这听起来一方面蛮有
   趣另一方面有悖常情；它有合理用途吗？

   有！想象一下，我们不直接改变贮存，而是引入日志的概念，表示贮存中**意向中
   的**更新。日志的实现方式类似于贮存，线性传递。（语言中）添加创建新日志的指令
   ；对于查询操作，首先检查日志，仅当日志中找不到某个地址的绑定时，才在实际贮存
   中查找。还要添加两个新指令：**丢弃**（discard）某个日志（用于进行时间回溯），
   以及 **提交**（commit）操作（将某个日志中的修改全部应用到贮存中）。

   事实上这就是**软件事务内存**（Software Transactional Memory）的概念。（每条线
   程都只能看到自己的日志和全局的贮存，看不到其他线程的日志，）其他线程在提交日
   志之前所做的修改对本线程是透明的。这就是说，每个线程看到的世界都是一致的（能
   看到自己所做的修改，因为它们都在日志中）。如果事务成功完成（提交），那么所有
   线程都都会看到更新后的全局贮存；如果事务中止（丢弃），被丢弃的日志也带走了其
   中所有的修改，状态还原（其他线程做提交还是会生效）。

   多线程编程会带来很多难题，软件事务内存提供了一种非常合理的解决办法，如果线程
   间必须共享可变状态的话。大部分计算机都只有一个全局存储，维护日志成本可能会很
   高，所有人们花了很大精力优化它们。另一种解决方案是，某些硬件架构开始提供对事
   务内存的直接支持，这使得日志的创建、维护和提交可以和操作全局存储一样高效，移
   除了采用该想法的一个重大阻碍。

   **练习**

   > 修改语言，增加日志功能以实现软件事务内存。

**练习**

> 另一种实现策略是，在环境中将名字映射到**box**类型的值。这里我们没有这样做是因
> 为：
>
> 1. 这样做的话有种作弊的感觉
> 2. 学不到不使用 box 实现该特性的方法
> 3. 不一定能扩展到其他赋值操作
> 4. 更重要的是，不能让我们获得这些**洞见**
>
> 不过理解该策略还是很有用的，而且你在实现自己的语言的时候可能会觉得采用这也是个
> 好主意。因此，试试使用这种策略实现一下我们的解释器。你还需要贮存传递模式吗？为
> 什么？
>
> 唯一的影响是，某个分支可能会报错或者永不终止——当然这都是外部可见的影响，但是它
> 们都是更高层次的影响。如果程序正常返回的话，不管选择哪种求值顺序，返回值还都是
> 一样的。）

## 8.2 变量

搞定了可变结构体，接下来考虑另一种情况：变量赋值。

### 8.2.1 术语

首先，关于名词的选择。之前我们一直坚持使用“标识符”，这是因为我们想将“变量”留给将
要学习的东西。在 Java 中，当我们写出（这里假设`x`为局域绑定的，比如是某个方法的
参数）

```Java
x = 1;
x = 3;
```

我们是在要求**改变**`x`的值。经过第一次赋值之后，`x`的值为 1；第二次之后为 3。因
此，`x`的值会在方法的执行过程中**变化**。

我们在数学中通常也会使用“变量”这个词表示函数参数。例如，在**`f(y) = y + 3`**中，
我们称**`y`**为“变量”。这里它被称为变量是由于**不同的调用之间**`y`的值也不同；然
而，在同一次调用**内部**，在其作用域内它的值总是一样的。之前的标识符对应于这种意
义上的变量。【注释】与之相对的，程序变量在每次调用**内部**都可以变化，如上面
Java 代码中的`x`。

> 如果某个标识符被绑定到一个`box`，那么它将总是被绑定到同一个`box`值。会发生改变
> 的是`box`的内容，标识符和`box`的绑定关系不会变。

从今往后，我们使用**变量**表示在其作用域内值可以发生变化的标识符，而值不能变化的
使用**标识符**表示。如果情况存疑时，安全一点，我们就称之为“变量”；如果这种区分不
太重要时，我们也可能使用其中任意一个。不要被这些名词搞得头大，重要的是理解它们的
区别。

### 8.2.2 语法

大部分语言使用`=`或者`:=`表示赋值，Racket 选择了不同的语法：使用`set!`进行变量赋
值。这就要求 Racket 程序员直面我们在本章开头所提到的区别。当然，这里我们绕开语法
区别，在我们的核心语言中使用不同的结构分别表示 box 和变量。

关于变量赋值，首先要认识到的是，尽管它和 box 赋值（setboxC）一样有两个子项，但是
两者的语法是完全不同的。为了理解其中区别，先考虑下面的 Java 代码：

```Java
x = 3;
```

在这个语句中，`x`的位置不能为任意表达式：它必须是标识符本身。这是因为，如果该位
置为任意表达式，那么我们就必须对其进行求值，然后得到某个值：例如，如果`x`之前绑
定到 1，那就意味着我们将会产生下面这样的式子：

```Java
1 = 3;
```

但显然这是没意义的！我们不能给 1 赋值，事实上 1 就是所谓的不变量。我们想要的是找
到`x`在贮存中的**位置**，然后改变该位置上存的值。

再看个例子。假设局域变量`o`被绑定到某个字符串对象**`s`**，然后我们写出下面的语句
：

```Java
o = new String("a new string")
```

我们是打算修改**`s`**吗？当然不是。该指令应该保持**`s`**不变，我们只是想改
变`o`指向的值，使得后面程序中`o`被求值时得到的是这个新的字符串对象。

### 8.2.3 解释器之解释变量

首先修改语法：

```Racket
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

可以看见我们丢弃了`box`相关操作，但是保留了序列，因为赋值和序列操作息息相关。注
意我们添加的`setC`形式，其第一个子项不是表达式而是变量的名字。同时我们还
将`idC`改作`varC`。

由于去掉了`box`，`box`值也不需要了：

```Racket
(define-type Value
  [numV (n : number)]
  [closV (arg : symbol) (body : ExprC) (env : Env)])
```

可能和你想的一样，为了支持变量，出于和前面相同的原因，我们仍需要用到贮存传递模式
（[8.1.7 节](#817-解释器之解释 box)）。区别在于如何使用它。注意到之前序列的实现
不需要变动（它并不依赖于要改变的东西是 box 还是变量），于是就只剩下变量赋值需要
处理了。

首先还是要对新值表达式求值，并获取更新后的贮存：

```Racket
<setC-case> ::=

    [setC (var val) (type-case Result (interp val env sto)
                      [v*s (v-val s-val)
                           <rest-of-setC-case>])]  ; setC 子句其余部分
```

接下来呢？前面讨论过了，对于变量部分，我们不应对求其值（这么做只会获取其旧值），
而是应该获取它对应的存储地址，然后更新该地址中的内容，**最后**这步和之前 box 的
处理类似：

```Racket
<rest-of-setC-case> ::=  ; setC 子句其余部分

    (let ([where (lookup var env)])
      (v*s v-val
           (override-store (cell where v-val)
                           s-val)))
```

这个新模式才是意义所在。在处理 box 的过程中，对于`idC`的处理是：先从环境中找出标
识符的地址，然后直接从贮存中获取其值；两步之后得到值，和（在解释器中）增加贮存之
前进行查找获得的是一种东西。而现在，新的模式是：对于变量标识符的处理**止步于**从
环境中获取其存储地址（**并不**继续获取其值）。这样获得的值按按照传统被称为**左
值**，“（赋值语句）左侧的值”之意。这是“存储地址”花哨的说法，它和贮存中存储的真实
值不同：注意到它并不和`Value`中任何类型对应。

这个解释器已经完成了！所有的难点已经在之前实现贮存传递模时（包括处理函数调用时，
给新变量分配地址）搞定了。

## 8.3 设计语言时状态的考虑

尽管大部分语言都包含状态，我们所学习的两种状态之一或者两者都有；但是它们的选入不
应该被当做一件微不足道或者理所当然的事。一方面，状态的引入带来了明显的好处：

- 状态提供了某种形式的**模块化**。拿我们上面实现的解释器为例，如果没有显式的状态
  操作（而要达到同样效果）：
  - 为了传递贮存，需要将其放入所有函数的参数和返回值中
  - **所有**可能会涉及到状态的函数都需要修改，维护信息的传递链可以将编程语言中的
    状态理解为**在所有函数间隐式流动的的参数和返回值**，而无需程序员费力地维护。
    它使得不同函数可以进行“超距”通信，中间子程序无需知晓这种通信。
- 状态得以让我们构造动态、环形的数据结构，或者至少提供了一种简洁直观的方式做到
  （[第九章](./chap09.md)会讨论）
- 状态赋予子程序**内存**，比如前述的 new-loc。如果某个子程序没法自己记住事情，那
  么其调用者就必须帮它完成，本质上就是做类似于传递贮存的事情。这么做不仅不方便，
  还给调用者恶意修改内存的机会（比如说，子程序的调用者可以故意送回旧的贮存，从而
  获取已经交给其他调用方的引用，通过这种方式发起正确性或安全攻击）。

另一方面，状态也给程序员和处理程序的程序（如编译器）带来不少麻烦。其中一个是“别
名（aliasing）”，以后我们会讨论到。另一个是“引用透明（referential
transparency）”，也是希望以后我们能讨论到。最后，上面我们说过状态提供了某种形式
的模块化。然而，换个角度看，两个子程序之间通过秘密渠道进行了通信，而它们的中间人
无法获知也无法监控这种通信。某些情况下（特别是安全系统和分布式系统中），这种秘密
渠道非常危险，也不受欢迎。

没有完美的方案，所以一种明智的选择是，提供赋值操作，同时又对其区别对待。例如
，Standard ML 中没有变量，因为它被认为不是必要的。但是该语言包含了等价于`box`的
东西（叫做 ref(引用)）。你可以很容易的用`box`模拟变量（例如，研究 new-loc 函数，
看看怎么用变量而不是 box 实现它），所以语言的表达能力并没减少，尽管由于 box 使用
不慎可能（和变量相比）导致更严重的别名问题。

作为回报，开发者得到一种有意义的**类型**：除非某个数据结构中包含 ref，否则它就可
以被认为是不可变的；ref 的存在也提醒开发人员和程序（如编译器），底下的值可能会发
生改变。比如说，如果 b 是 box，程序员就应该知道，将`(unbox b)`绑定到 v，然后用 v
替换程序中所有的`(unbox b)`是不明智的做法：原来程序总是去获取 box 的**当前**值，
改了之后就变成访问原先的值了。（反过来，如果程序员需要某个时间的值，无论以后 box
怎么被赋值，那么就可以获取当前值，将其绑定，而不是老是去 unbox。）

## 8.4 参数传递

我们当前实现的解释器中，对于每个函数调用，总是分配新地址用于存储参数。这意味着：

```Racket
(let ([f (lambda (x) (set! x 3))])
  (let ([y 5])
    (begin
      (f y)
      y)))
```

会计算得到 5 而不是 3。这是因为，形参 x 的值和实参 y 的值存放在不同的地址，所以
对 x 赋值不会影响 y。

现在，试想程序以下面说的这种方式执行。当实参为变量时——它在内存中在有个地址——我们
不再为该值重新分配地址，而是直接使用变量原来的地址。于是现在形参和实参指向的是内
存中的**同一块地址**：即它们为**变量别名**（variable aliases）。这样对形参的赋值
会影响调用者；上面的例子将计算得到 3 而不是 5。这被称为**传引用调
用**（call-by-reference）参数传递策略。

> 相反，我们的解释器实现了**传值调用**（call-by-value），Java 等语言也采取这种参
> 数传递策略。一个有点费解之处是，**如果传递的值本身是可变的**（译注：类似于我们
> 的 box），在被调用函数中进行的修改能被调用者看到。这仅仅是可变数据的产物，而不
> 是传递策略导致的。请区分清楚！

在一段时间里，传引用调用被认为是好主意。使用它可以写出一些有用的抽象，比如 swap
函数，调用该函数将交换调用者手上**两个变量的值**。不过，这种特性的劣势远大于其优
势：

- 粗心的程序员可能会无意间创建了别名变量，然后修改其值（而没有意识到自己这么做了
  ），调用者可能永远不会注意到这种错误，直到某个特别条件触发了该修改。
- 有些人认为这种策略效率更高所以是必然的选择：他们如果不是传引用的话，其他策略需
  要**拷贝**大量数据。但是，传值调用也可以仅传递数据结构的地址。仅在这种情况（a
  并且 b 并且 c）下需要拷贝数据：(a)数据结构是可变的，(b)不希望被调用者（译注，
  原文此处为调用者，逻辑关系并不合理故如此翻译）改变参数的值，(c)语言本身没有提
  供符号支持或者其他机制将此参数标记为不可变。
- 它必然会导致不统一的、非模块化的推理。例如，考虑如下的子程序：
  ```Racket
  (define (f g)
    (let ([x 10])
      (begin
        (g x)
        ...)))
  ```
  如果允许传引用参数传递的话，程序员将不能仅看局部代码——也就只看这一段——就确定省
  略号中`x`的值。

如果某个语言非要允许传引用调用的话，至少需要让**调用者**决定是传引用——让在被调用
者内部共享传入的内存地址——还是不使用传引用。然而即使使用这种方式也不怎么样，因为
现在被调用者面临对称的问题——它的参数是不是个别名呢。传统的顺序式程序中，这还不是
个问题，但是如果子程序是**可重入的**，被调用者就面临这种窘境。

所以是时候考虑一下引入任何这种东西是否值得了。如果调用者想要某个子程序执行某种赋
值操作，传`box`值就好了。`box`表明，调用者接受——甚至说请求——被调用者进行赋值操作
，执行结束后调用者只需从 box 中抽取出值。当然这样我们就不能写出很简洁的`swap`子
程序，但是为了真实世界软件工程的考虑，这点小代价还是花的起的。
