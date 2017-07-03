#lang plai-typed

;; test
(test true true)

(define-type MisspelledAnimal
  [caml (humps : number)]
  [yacc (height : number)])

(test (caml? (caml 2)) true)
(test (caml? (yacc 2)) false)
(test (yacc? (yacc 2)) true)
(test (yacc? (caml 2)) false)

(test (caml-humps (caml 2)) 2)
(test (yacc-height (yacc 10)) 10)

(define ma1 : MisspelledAnimal (caml 2))
(define ma2 : MisspelledAnimal (yacc 1.9))

;; (define ma1 (caml 2))
;; (define ma2 (yacc 1.9))

(define (good? [ma : MisspelledAnimal]) : boolean
        (type-case MisspelledAnimal ma
                   [caml (humps) (>= humps 2)]
                   [yacc (height) (> height 2.1)]))

;; (define (good? [ma : MisspelledAnimal]) : boolean
;;   (cond
;;     [(caml? ma) (>= caml-humps ma) 2]
;;     [(yacc? ma) (> (yacc-height ma) 2.1)]))

(test (good? ma1) #t)
(test (good? ma2) #f)

;; type check failed
;; (good? "Should be a MisspelledAnimal, but a string")
