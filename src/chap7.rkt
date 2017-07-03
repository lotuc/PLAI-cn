#lang plai-typed

(define-type ExprC
  [numC (n : number)]
  [idC (s : symbol)]
  [fdC (name : symbol) (arg : symbol) (body : ExprC)]
  [appC (fun : ExprC) (arg : ExprC)]
  [plusC (l : ExprC) (r : ExprC)]
  [multC (l : ExprC) (r : ExprC)])

(define-type Value
  [numV (n : number)]
  [funV (name : symbol) (arg : symbol) (body : ExprC)])

;; 定义环境相关数据结构与操作
(define-type Binding
  [bind (name : symbol) (val : Value)])
(define-type-alias Env (listof Binding))
(define mt-env empty)
(define extend-env cons)

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
    [multC (l r) (num* (interp l env) (interp r env))]))

(test (interp (plusC (numC 10) (appC (fdC 'const5 '_ (numC 5)) (numC 10)))
              mt-env)
      (numV 15))
(test/exn (interp (appC (fdC 'f1 'x (appC (fdC 'f2 'y (plusC (idC 'x) (idC 'y)))
                                          (numC 4)))
                        (numC 3))
                  mt-env)
          "Can't find binding")

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
             [(def) (fdC (s-exp->symbol (second sl))
                      (s-exp->symbol (third sl))
                      (parse (fourth sl)))])
           (appC (parse (first sl))
                 (parse (second sl)))))]))

(define (run s-exp)
  (interp (parse s-exp) mt-env))

;; tests
(test (run '42) (numV 42))
(test (run '(+ 10 32)) (numV 42))
(test (run '(* 6 7)) (numV 42))
(test (run '(+ (* 4 5) 22)) (numV 42))
(test (run '(+ (* 4 5) (+ 10 12))) (numV 42))

(test (run '(def f x (* x x))) (funV 'f 'x (multC (idC 'x) (idC 'x))))
(test (run '((def f x (* x x)) 10)) (numV 100))
