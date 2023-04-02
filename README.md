# PLAI-cn

![](./docs/imgs/PLAI-cover.jpg)

1. The translation has not been checked by the
   <a href="mailto:shriram@gmail.com" target="_top">original author</a>
2. The correct, definitive version is at the
   [original link](http://cs.brown.edu/courses/cs173/2012/book/index.html).

## 译者

- [lotuc](https://github.com/lotuc)
- [MrMathematica](https://github.com/mrmathematica)

本翻译版权属于两位译者

### 编译发布

内容通过
[mkdocs](https://github.com/mkdocs/mkdocs)（[mkdocs-material](https://github.com/squidfunk/mkdocs-material)
主题）编译生成 html 进行发布。

发布在 [PLAI-cn](https://lotuc.github.io/PLAI-cn).

### 翻译准则

1. 代码中 `<XXX>` 全部保留，在同一行最后分号注释加上中文翻译，比如

   ```
   <answer-type-take-1> ::= ;返回值类型，第一次尝试
   ```

2. 术语翻译，可以在第一次出现/定义的地方后附括号，括号内标注英文，比如闭包
   （Closure）
3. Excise 和 Think now 统一翻译成练习和思考题
4. 注释也请翻译，根据实际情况，直接放在文中相应位置，或者标明【注释】放在下一段
   文字之前。
5. 代码中出现的英文字符串，也在同一行后加中文注释，比如

   ```
   (error 'num+ "one argument was not a number") ;有一个参数不是数字
   ```

6. 英文原文的斜体和粗体字，统一对应为中文的粗体字
7. 文档使用 [prettier](https://prettier.io/) 进行格式化:

   ```bash
   prettier --print-width 80 --prose-wrap always --write *.md
   ```
