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
(test (numV 23)
      (fetch 2 (override-store
                (cell 1 (numV 20))
                (override-store
                 (cell 2 (numV 23)) mt-store))))

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

(define (parse [s : s-expression]) : ExprC
  (cond
    [(s-exp-number? s) (numC (s-exp->number s))]
    [(s-exp-symbol? s) (idC (s-exp->symbol s))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (if (s-exp-symbol? (first sl))
           (case (s-exp->symbol (first sl))
             [(+) (plusC (parse (second sl)) (parse (third sl)))]
             [(*) (multC (parse (second sl)) (parse (third sl)))]
             [(lambda) (lamC (s-exp->symbol (second sl))
                             (parse (third sl)))]
             [(box) (boxC (parse (second sl)))]
             [(unbox) (unboxC (parse (second sl)))]
             [(setbox) (setboxC (parse (second sl)) (parse (third sl)))]
             [(seq) (seqC (parse (second sl)) (parse (third sl)))])
           (appC (parse (first sl))
                 (parse (second sl)))))]))


(define (run s-exp)
  (interp (parse s-exp) mt-env mt-store))

(define (testResult s-exp result-value)
  (type-case Result (run s-exp) [v*s (v s) (test v result-value)]))

(testResult '(+ 1 2) (numV 3))
(testResult '(unbox (box 10)) (numV 10))
(testResult '((lambda a (+ a a)) 10) (numV 20))
(testResult '((lambda x (* x x)) 12) (numV 144))
(testResult '(seq 20 10) (numV 10))
(testResult '(setbox (box 10) 20) (numV 20))
(testResult '((lambda a (seq (setbox a 10) (unbox a))) (box 5)) (numV 10))
