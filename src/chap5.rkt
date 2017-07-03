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

;; 注意这个解析器漏洞百出，但是用于测此代码应该是足够了
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


(define (run s-exp)
  (interp (parse s-exp)
          (list (fdC 'double 'x (plusC (idC 'x) (idC 'x)))
                (fdC 'quadruple 'x (appC 'double (appC 'double (idC 'x)))))))

;; tests
(test (run '42) 42)
(test (run '(+ 10 32)) 42)
(test (run '(* 6 7)) 42)
(test (run '(+ (* 4 5) 22)) 42)
(test (run '(+ (* 4 5) (+ 10 12))) 42)

(test (run '(double 21)) 42)
(test (run '(+ (double (double 2)) 34)) 42)
(test (run '(+ (quadruple 2) 34)) 42)
(test (run '(double (+ 20 1))) 42)
