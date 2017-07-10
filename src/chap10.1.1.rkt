#lang plai-typed

(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  [boolC (b : boolean)]
  [eqC (e1 : ExprC) (e2 : ExprC)]
  [ifC (condition : ExprC) (ifResut : ExprC) (elseResult : ExprC)]
  [fdC (name : symbol) (arg : symbol) (body : ExprC)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)]
  [objC (ns : (listof symbol)) (es : (listof ExprC))]
  [msgC (o : ExprC) (n : symbol)])

(define-type ExprS
  [numS (n : number)]
  [idS (s : symbol)]
  [boolS (b : boolean)]
  [eqS (e1 : ExprS) (e2 : ExprS)]
  [ifS (condition : ExprS) (ifResut : ExprS) (elseResult : ExprS)]
  [fdS (name : symbol) (arg : symbol) (body : ExprS)]
  [appS (fun : ExprS) (arg : ExprS)]
  [plusS (l : ExprS) (r : ExprS)]
  [multS (l : ExprS) (r : ExprS)]
  [objS (ns : (listof symbol)) (es : (listof ExprS))]
  [msgS (o : ExprS) (n : symbol) (a : ExprS)])

(define (parse [s : s-expression]) : ExprS
  (cond
    [(s-exp-number? s) (numS (s-exp->number s))]
    [(s-exp-symbol? s)
     (let ([sb (s-exp->symbol s)])
       (cond
         [(eq? sb 'true) (boolS true)]
         [(eq? sb 'false) (boolS false)]
         [else (idS sb)]))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (if (s-exp-symbol? (first sl))
           (case (s-exp->symbol (first sl))
             [(+) (plusS (parse (second sl)) (parse (third sl)))]
             [(*) (multS (parse (second sl)) (parse (third sl)))]
             [(if) (ifS (parse (second sl)) (parse (third sl)) (parse (fourth sl)))]
             [(eq?) (eqS (parse (second sl)) (parse (third sl)))]
             [(def) (fdS (s-exp->symbol (second sl))
                         (s-exp->symbol (third sl))
                         (parse (fourth sl)))])
           (appS (parse (first sl))
                 (parse (second sl)))))]))

(define (desugar [e : ExprS]) : ExprC
  (type-case ExprS e
             [numS (n) (numC n)]
             [idS (s) (idC s)]
             [boolS (b) (boolC b)]
             [eqS (e1 e2) (eqC (desugar e1) (desugar e2))]
             [ifS (condition ifResult elseResult)
                  (ifC (desugar condition)
                       (desugar ifResult)
                       (desugar elseResult))]
             [fdS (name arg body) (fdC name arg (desugar body))]
             [appS (fun arg) (appC (desugar fun) (desugar arg))]
             [plusS (l r) (plusC (desugar l) (desugar r))]
             [multS (l r) (multC (desugar l) (desugar r))]
             [objS (ns es) (objC ns (map (lambda (e) (desugar e)) es))]
             [msgS (o n a) (appC (msgC (desugar o) n) (desugar a))]))

(define-type Value
  [numV (n : number)]
  [boolV (b : boolean)]
  [funV (name : symbol) (arg : symbol) (body : ExprC)]
  [objV (ns : (listof symbol)) (vs : (listof Value))])

;; 定义环境相关数据结构与操作
(define-type Binding
  [bind (name : symbol) (val : Value)])
(define-type-alias Env (listof Binding))
(define mt-env empty)
(define extend-env cons)

(define (find-value (s : symbol) (ns : (listof symbol)) (vs : (listof Value)))
  (if (or (= (length ns) 0)
          (= (length vs) 0))
      (error 'find-value "Not found in object")
      (if (eq? s (first ns))
          (first vs)
          (find-value s (rest ns) (rest vs)))))
;; lookup-msg : symbol * Value -> Value
(define (lookup-msg (s : symbol) (v : Value))
  (type-case Value v
             [objV (ns vs)
                   (find-value s (objV-ns v) (objV-vs v))]
             [else (error 'looup-msg "Not an object")]))

;; 在环境 env 中查找标识符 n 绑定的值
(define (lookup [n : symbol] [env : Env]) : Value
  (cond
    [(= 0 (length env)) (error 'lookup "Can't find binding")]
    [else (let [(b (first env))]
            (if (symbol=? n (bind-name b))
                (bind-val b)
                (lookup n (rest env))))]))

(define (num+ [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (+ (numV-n l) (numV-n r)))]
    [else (error 'num+ "one argument was not number")]))
(define (num* [l : Value] [r : Value]) : Value
  (cond
    [(and (numV? l) (numV? r))
     (numV (* (numV-n l) (numV-n r)))]
    [else (error 'num+ "one argument was not number")]))

(define (interp [a : ExprC] [env : Env]) : Value
  (type-case ExprC a
             [numC (n) (numV n)]
             [boolC (b) (boolV b)]
             [idC (n) (lookup n env)]
             [fdC (n a b) (funV n a b)]
             [appC (f arg) (let ([fd (interp f env)])
                             (if (funV? fd)
                                 (interp (funV-body fd)
                                         (extend-env (bind (funV-arg fd)
                                                           (interp arg env))
                                                     mt-env)
                                         )
                                 (error 'interp "Not a function")
                                 ))]
             [plusC (l r) (num+ (interp l env) (interp r env))]
             [multC (l r) (num* (interp l env) (interp r env))]
             [eqC (e1 e2) (let ([v1 (interp e1 env)]
                                [v2 (interp e2 env)])
                            (boolV (or (and (numV? v1) (numV? v2) (= (numV-n v1) (numV-n v2)))
                                       (and (boolV? v1) (boolV? v2) (eq? (boolV-b v1) (boolV-b v2))))))]
             [ifC (condition ifResult elseResult)
                  (let ([cond-value (interp condition env)])
                    (if (boolV? cond-value)
                        (if (boolV-b cond-value)
                            (interp ifResult env)
                            (interp elseResult env))
                        (error 'interp "Not bool")))]
             [objC (ns es) (objV ns (map (lambda (e)
                                           (interp e env))
                                         es))]
             [msgC (o n) (lookup-msg n (interp o env))]))

(test (interp (plusC (numC 10) (appC (fdC 'const5 '_ (numC 5)) (numC 10)))
              mt-env)
      (numV 15))
(test/exn (interp (appC (fdC 'f1 'x (appC (fdC 'f2 'y (plusC (idC 'x) (idC 'y)))
                                          (numC 4)))
                        (numC 3))
                  mt-env)
          "Can't find binding")

(define (run s-exp)
  (interp (desugar (parse s-exp)) mt-env))

;; tests
(test (run '42) (numV 42))
(test (run '(+ 10 32)) (numV 42))
(test (run '(* 6 7)) (numV 42))
(test (run '(+ (* 4 5) 22)) (numV 42))
(test (run '(+ (* 4 5) (+ 10 12))) (numV 42))

(test (run '(if true 1 2)) (numV 1))
(test (run '(eq? true true)) (boolV true))
(test (run '(eq? true false)) (boolV false))
(test (run '(eq? 42 42)) (boolV true))
(test (run '(eq? (+ 20 22) (+ 20 22))) (boolV true))
(test (run '(eq? 20 (+ (* -1 22) 42))) (boolV true))

(test (run '(def f x (* x x))) (funV 'f 'x (multC (idC 'x) (idC 'x))))
(test (run '((def f x (* x x)) 10)) (numV 100))

;; 10.1.1
(test
 (interp
  (desugar
   (msgS (objS (list 'add1 'sub1)
               (list (fdS 'add1 'x (plusS (idS 'x) (numS 1)))
                     (fdS 'sub1 'x (plusS (idS 'x) (numS -1)))))
         'add1
         (numS 3)))
  mt-env)
 (numV 4))
