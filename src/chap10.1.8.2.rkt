#lang plai

(define (msg/self o m . a)
  (apply (o m) o a))

(define o-self-no!
  (lambda (m)
    (case m
      [(first) (lambda (self x) (msg/self self 'second (+ x 1)))]
      [(second) (lambda (self x) (+ x 1))])))


(test (msg/self o-self-no! 'first 5) 7)
