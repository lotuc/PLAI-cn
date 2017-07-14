#lang plai

(define (msg o m . a)
  (apply (o m) a))

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

(test (let ([o (o-static-1 1000)])
        (msg o 'count))
      1)

(test (let ([o (o-static-1 0)])
        (msg o 'count))
      2)
