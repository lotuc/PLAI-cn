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

#### 10.1.8.1 使用 mutation 实现自引用

是的，我们可以，之前实现递归的时候我们已经见过这种模式了；类似当时实现递归的方法，这里 `box` 中我们不引用函数而是引用对象：

```scheme
(define o-self!
  (let ([self 'dummy])
    (begin
      (set! self
            (lambda (m)
              (case m
                [(first) (lambda (x) (msg self 'second (+ x 1)))]
                [(second) (lambda (x) (+ x 1))])))
      self)))
```

可以看见上面这个代码和前面[递归函数](./chap9.md)的实现模式一样，稍微调整了一下。在方法 `first` 中使用自引用调用了方法 `second`。

```scheme
(test (msg o-self! 'first 5) 7)
```

#### 10.1.8.2 不使用 mutaion 实现自引用

如果你知道怎么不使用 mutation 实现递归，那么你会发现改种解决方案也适用于这里。

```scheme
(define o-self-no!
  (lambda (m)
    (case m
      [(first) (lambda (self x) (msg/self self 'second (+ x 1)))]
      [(second) (lambda (self x) (+ x 1))])))
```

现在每个方法需要传入 `self` 参数。这意味着方法调用也需要修改：

```scheme
(define (msg/self o m . a)
  (apply (o m) o a))
```

即，当调用对象 `o` 的方法时，需要将 `o` 作为参数传给方法。显然这种方式存在隐患，调用方法的时候你可以传入一个不同的对象作为 `self`。因此让开发者显式传递 `self` 值可能是个坏主意；如果要使用这种方式，它应该是作为语法糖存在。

### 10.1.9 动态分发（dynamic dispatch）

最后我们希望我们的对象可以处理对象系统的一个特性，即让调用者可以在无需知道或者决定哪个对象可以处理调用请求的时候进行方法调用。假设我们有一个二叉树的数据结构，树中要么是不含值的节点或者含值的叶子。传统的函数中我们需要实现某种形式的条件式——`cond`、`type-case` 或者模式匹配或其它等价它们的东西——能穷举不同形式的树。如果树的定义扩展了，那么对应部分的代码段必须修改。动态分发通过将该条件选择移到语言内部使得用户程序可以不用处理它。它的关键特性是使得条件式变得可扩展。它也是对象提供的可扩展性的一个纬度。

下面定义上面说的两个树对象：

```scheme
(define (mt)
  (let ([self 'dummy])
    (begin
      (set! self
            (lambda (m)
              (case m
                [(add) (lambda () 0)])))
      self)))
 
(define (node v l r)
  (let ([self 'dummy])
    (begin
      (set! self
            (lambda (m)
              (case m
                [(add) (lambda () (+ v
                                     (msg l 'add)
                                     (msg r 'add)))])))
      self)))
```

于是，我们可以构造一棵树：

```scheme
(define a-tree
  (node 10
        (node 5 (mt) (mt))
        (node 15 (node 6 (mt) (mt)) (mt))))
```

最后，测试一下：

```scheme
(test (msg a-tree 'add) (+ 10 5 15 6))
```

注意到测试案例和 `node` 的 `add` 方法实现中都调用了 add 方法且没有检查当前节点是 `mt` 还是 `node`。我们将在运行时获取对象 `add` 的具体实现并执行。这种使用户程序中没有条件表达式的实现正是动态分发的精髓。

## 10.2 成员权限控制设计

对于成员名称的处理我们已经有两个正交的纬度。一个维度是名字使静态给定还是动态计算的，另一纬使名字的数量是固定的还是可变的：

|            | 名字是静态的  | 名字是动态求得的   |
|------------|--------------|-----------------|
| **成员数量固定** | Java 基础语法 | Java 中通过反射计算出的名字 |
| **成员数量可变** | 无法想象      | 大部分脚本语言             |

只有一种情况毫无意义：强制开发者在源码中显式指定成员名，又不允许添加新的可访问的成员。其它的几种情况都已经在其它语言中被尝试过了。

右下方那种情况对应于那些使用哈希表作为对象表示的语言。成员名字即该哈希表的索引。一些语言将这种风格推到极限，它使数字索引的实现和普通名字无差异，于是字典对象和数组被弄得混淆了。即使考虑只处理“成员名字”，这种风格也会给类型检查带来极大困难。

因此，后面的章节，我们将坚持使用“传统”对象，成员数量固定，甚至会让它的名字只能是静态的（对应于左上角那种）。即使做出这种限制，我们将发现仍然有很多待学习的东西。

## 10.3 else 中放什么？

截至目前，我们 `case` 表达式中 `else` 部分还是留空的（动态分发部分代码）。一个原因是，如果我们的成员及成员数量可变，那么使用其它方式实现可能是更好的选择：例如上面讨论的哈希表；相对的对象成员固定，使用 `case` 条件表达式能更好的服务于演示的目的（因为这种实现方式强调了成员固定这一点，而哈希表则相对开放）。还有一点原因是，我们可以在 `else` 部分移交分发控制权如，给其父对象，这也被成为**继承**。

回到上面实现的对象模型。为了实现继承，需要给对象“一些东西”让其可以代理它识别不了的方法。“那些东西”是什么将导致迥异的结果。

现在我们的答案可能是另一个对象：

```scheme
(case m
  ...
  [else (parent-object m)])
```

基于我们现有的实现，这种方式，我们将在父对象中搜索当前对象不存在的方法。如果沿着继承链直到最上面都没有找到该名字的方法，最上面的对象将抛出“message not found”错误。

**练习**
> Observe that the application (parent-object m) is like “half a msg”, just like an l-value was “half a value lookup” [REF]. Is there any connection?

下面扩展一下我们的树实现另一个方法，`size`。我们写一个“扩展”（你可能想叫它“子类”，但现在请先忍住），为 `node` 和 `mt` 分别实现 `size` 方法。

### 10.3.1 类

很快我们就发现了一点问题。下面这是构造参数模式吗？

```scheme
(define (node/size parent-object v l r)
  ...)
```

上面的代码显示父对象和构造参数处于“同一级别”。这看上去很合理，只要所有这些参数都被给定，该对象也就被“完全定义”了。然而，我们的代码中仍然还有：

```scheme
(define (node v l r)
  ...)
```

我们真的要把所有这些参数写两遍吗？（每当我们需要将同样的东西写两次，就应该考虑一下我们是不是没有保持一致，并因此引入一些微妙的错误。）有个替代方案：`node/size` 可以构造一个其父的实例。即我们传入的不是对象本身而是对象构造器：

```scheme
(define (node/size parent-maker v l r)
  (let ([parent-object (parent-maker v l r)]
        [self 'dummy])
    (begin
      (set! self
            (lambda (m)
              (case m
                [(size) (lambda () (+ 1
                                     (msg l 'size)
                                     (msg r 'size)))]
                [else (parent-object m)])))
      self)))
 
(define (mt/size parent-maker)
  (let ([parent-object (parent-maker)]
        [self 'dummy])
    (begin
      (set! self
            (lambda (m)
              (case m
                [(size) (lambda () 0)]
                [else (parent-object m)])))
      self)))
```

在每次调用构造函数构造对象的时候都需要记得传入父对象构造器：

```scheme
(define a-tree/size
  (node/size node
             10
             (node/size node 5 (mt/size mt) (mt/size mt))
             (node/size node 15
                        (node/size node 6 (mt/size mt) (mt/size mt))
                        (mt/size mt))))
```

显然我们应该可以通过合适的语法糖简化上面这一堆东西。首先写两个测试测试确定原功能和新加功能正确：

```scheme
(test (msg a-tree/size 'add) (+ 10 5 15 6))
(test (msg a-tree/size 'size) 4)
```

**练习**
> Rewrite this block of code using self-application instead of mutation.

上面做的已经抓住了类的精髓。Each function parameterized over a parent is...well, it’s a bit tricky, really. Let’s call it a blob for now. A blob corresponds to what a Java programmer defines when they write a class:

```java
class NodeSize extends Node { ... }
```

**Do Now!**
> So why are we going out of the way to not call it a “class”?

当开发者调用 Java 的类构造器时，从效果上来看等同于沿着继承链往上构建对象（现实中，编译器会进行优化使得这个过程只需要进行一次构造器调用和一次对象分配）。这些对象中的每一个都是对应父类的一个针对该构造对象的一个私有拷贝。关于这些对象到底有多少是可见的，Java 的选择是对于一个指定名字（和签名）只保留一个方法，不管该方法在继承链上被实现了多少次，然而所有的字段是都被保留了的，可以通过强制类型转换去获取继承链上特定类的字段值。后者细想是比较合理的，因为每个字段都可能有一些不变量在管理它，所以保证它们彼此分离（因此所有的都存在）是很有必要的。与之相对，很容易想出来一种方式可以使所有方法可用，而不只是最下面那个（通过继承链往上找到的第一个），很多脚本语言使用了这种方法。

### 10.3.2 原型

按照前面的描述，我们给每个类一个关于其父类的描述。构造对象实例时将沿着继承链创建链上每个类的实例。关于父辈还有一种考虑方式：父辈不是一个需要实例化的类，而就是对象本身。这样拥有相同父辈的后辈看到的将是相同的对象，这意味着从某个子对象中修改该对象内部状态将对其它子对象可见。该共有对象被称为原型（prototype）。

一些语言设计者认为原型比类更为基础，因为通过一些诸如函数的这种基础技术可以在基于原型的语言中实现类——但是反之则不行。前面我们本质上也就是这么做的：我们的每个“类”函数中参数中包含一个父对象描述，而类就是一个返回对象的函数。如果修改类函数使得父对象描述那个参数为父对象，我们将得到类似原型的东西。

> 基于原型的原型语言是 [Self](http://selflanguage.org/)。尽管你可能也听说过 JavaScript 是“基于” Self 的，但是从一个概念的最初源头去学习它还是很有必要的，而且 Self 中展示了原型这个概念最本真的形式。

**练习**
> 修改继承模式，实现一个类似 Self 的基于原型的语言。由于类为每个对象提供父辈对象的不同拷贝，而在基于原型的语言可能通过拷贝操作来模拟类的行为。
