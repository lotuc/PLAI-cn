#lang plai

(define o-l
  (lambda (m)
    (case m
      [(add1) (lambda (x) (+ x 1))]
      [(sub1) (lambda (x) (- x 1))])))

(test ((o-l 'add1) 5) 6)

(define (msg o m . a)
  (apply (o m) a))

(test (msg o-l 'add1 5) 6)

(test ((o-l (string->symbol "add1")) 5) 6) ;; works on this desugared version
