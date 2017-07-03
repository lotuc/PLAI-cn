#lang plai-typed

(define-type ArithC
  [numC (n : number)]
  [ifC (condition : ArithC) (ifResut : ArithC) (elseResult : ArithC)]
  [plusC (l : ArithC) (r : ArithC)]
  [multC (l : ArithC) (r : ArithC)])

(define-type ArithS
  [numS (n : number)]
  [plusS (l : ArithS) (r : ArithS)]
  [bminusS (l : ArithS) (r : ArithS)]
  [uminusS (e : ArithS)]
  [multS (l : ArithS) (r : ArithS)]
  [ifS (condition : ArithS) (ifResult : ArithS) (elseResult : ArithS)])

(define (desugar [as : ArithS]) : ArithC
  (type-case ArithS as
    [numS (n) (numC n)]
    [plusS (l r) (plusC (desugar l)
                        (desugar r))]
    [multS (l r) (multC (desugar l)
                        (desugar r))]
    [uminusS (e) (multC (numC -1) (desugar e))]
    [bminusS (l r) (plusC (desugar l)
                          (multC (numC -1) (desugar r)))]
    [ifS (condition ifResult elseResult)
         (ifC (desugar condition) (desugar ifResult) (desugar elseResult))]))

(define (parse [s : s-expression]) : ArithS
  (cond
    [(s-exp-number? s) (numS (s-exp->number s))]
    [(s-exp-list? s)
     (let ([sl (s-exp->list s)])
       (case (s-exp->symbol (first sl))
         [(+) (plusS (parse (second sl)) (parse (third sl)))]
         [(*) (multS (parse (second sl)) (parse (third sl)))]
         [(-)
          (if (= (length sl) 2)
              (uminusS (parse (second sl)))
              (bminusS (parse (second sl)) (parse (third sl))))]
         [(if) (ifS (parse (second sl)) (parse (third sl)) (parse (third (rest sl))))]
         [else (error 'parse "invalid list input")]))]
    [else (error 'parse "invalid input")]))

(define (interp [a : ArithC]) : number
  (type-case ArithC a
    [numC (n) n]
    [plusC (l r) (+ (interp l) (interp r))]
    [multC (l r) (* (interp l) (interp r))]
    [ifC (condition ifResult elseResult)
         (if (= (interp condition) 0)
             (interp elseResult)
             (interp ifResult))]))

(define (run s-exp) (interp (desugar (parse s-exp))))

;; tests
(test (run '42) 42)
(test (run '(+ 10 32)) 42)
(test (run '(* 6 7)) 42)
(test (run '(+ (* 4 5) 22)) 42)
(test (run '(+ (* 4 5) (+ 10 12))) 42)

(test (run '(if 1 42 24)) 42)
(test (run '(if 0 24 42)) 42)
(test (run '(if (- 2 1) 42 24)) 42)
(test (run '(if (- 1 1) 24 42)) 42)
