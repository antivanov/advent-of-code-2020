(load "./lib/list.scm")
(load "./lib/parser.scm")

(define input
  (strip-spaces
    (string->list "3 + 4 * 2 / ( 1 - 5 ) ^ 2 ^ 3")))

(define ops-with-priorities
  (list
    (list #\^ 4 #f (lambda (x y) (expt x y)))
    (list #\* 3 #t (lambda (x y) (* x y)))
    (list #\/ 3 #t (lambda (x y) (/ x y)))
    (list #\+ 2 #t (lambda (x y) (+ x y)))
    (list #\- 2 #t (lambda (x y) (- x y)))))

(define ops
  (map
    car
    ops-with-priorities))

;TODO: Re-factor commonality between op-priority, op-lambda, is-left-associative?
(define (op-priority op)
  (let ((found-op
          (assoc op ops-with-priorities)))
    (if found-op
      (cadr found-op)
      -1)))

(define (is-left-associative? op)
  (let ((found-op
          (assoc op ops-with-priorities)))
    (if found-op
      (caddr found-op)
      #f)))

(define (op-lambda op)
  (let ((found-op
          (assoc op ops-with-priorities)))
    (if found-op
      (cadddr found-op)
      (error "Unknown op" op))))

(define (is-operator? token)
  (contains? token ops))

(define (is-left-bracket? token)
  (equal? token '#\())

(define (is-right-bracket? token)
  (equal? token '#\)))

; TODO: Consider using reduce or fold-left?
; TODO: Re-factor commonality between pop-operators-with-greater-or-equal-precedence and pop-upto-left-bracket
(define (pop-operators-with-greater-or-equal-precedence operator operators)
  (define (loop remaining-operators popped-operators)
    (if (null? remaining-operators)
      (cons remaining-operators (reverse popped-operators))
      (let ((current-operator (car remaining-operators)))
        (if (or
              (> (op-priority current-operator) (op-priority operator))
              (and
                (is-left-associative? current-operator)
                (= (op-priority current-operator) (op-priority operator))))
          (loop
            (cdr remaining-operators)
            (cons current-operator popped-operators))
          (cons remaining-operators (reverse popped-operators))))))
  (loop operators '()))

(define (pop-upto-left-bracket operators)
  (define (loop remaining-operators popped-operators)
    (if (null? remaining-operators)
      (cons remaining-operators (reverse popped-operators))
      (let ((current-operator (car remaining-operators)))
        (if (is-left-bracket? current-operator)
          (cons (cdr remaining-operators) (reverse popped-operators))
          (loop
            (cdr remaining-operators)
            (cons current-operator popped-operators))))))
  (loop operators '()))

; Based on https://en.wikipedia.org/wiki/Shunting-yard_algorithm
; https://brilliant.org/wiki/shunting-yard-algorithm/
(define (to-postfix expr)
  (define (handle-next remaining-tokens operators output)
    ;(newline)
    ;(display "handle-next(")
    ;(display remaining-tokens)
    ;(display ", ")
    ;(display operators)
    ;(display ", ")
    ;(display output)
    ;(display ")")
    ;(newline)
    (if (null? remaining-tokens) (append (reverse output) operators)
      (let ((current-token (car remaining-tokens)))
        (cond ((is-operator? current-token)
                (let ((updated-and-popped-operators
                       (pop-operators-with-greater-or-equal-precedence current-token operators)))
                  (let ((updated-operators (car updated-and-popped-operators))
                        (popped-operators (cdr updated-and-popped-operators)))
                    (handle-next
                      (cdr remaining-tokens)
                      (cons current-token updated-operators)
                      (append popped-operators output)))))
              ((is-left-bracket? current-token)
                (handle-next
                  (cdr remaining-tokens)
                  (cons current-token operators)
                  output))
              ((is-right-bracket? current-token)
                (let ((updated-and-popped-operators
                       (pop-upto-left-bracket operators)))
                  (let ((updated-operators (car updated-and-popped-operators))
                        (popped-operators (cdr updated-and-popped-operators)))
                    (handle-next
                      (cdr remaining-tokens)
                      updated-operators
                      (append popped-operators output)))))
          (else
            (handle-next
              (cdr remaining-tokens)
              operators
              (cons current-token output)))))))
  (handle-next expr '() '()))

(define (evaluate-postfix expr)
  (define (handle-next remaining-tokens stack)
    (if (null? remaining-tokens)
      (if (> (length stack) 1)
        (error "Invalid expression" expr "remaining stack" stack)
        (car stack))
      (let ((current-token (car remaining-tokens)))
        (cond ((is-operator? current-token)
                (if (< (length stack) 2)
                  (error "Not enough operands on the stack left" stack "remaining tokens" remaining-tokens)
                  (let ((left-operand
                          (car stack))
                        (right-operand
                          (cadr stack))
                        (op-function
                          (op-lambda current-token)))
                    (handle-next
                      (cdr remaining-tokens)
                      (cons
                        (op-function
                          left-operand
                          right-operand)
                        (cddr stack))))))
              (else
                (handle-next
                  (cdr remaining-tokens)
                  (cons
                    (string->number (char->string current-token))
                    stack)))))))
  (handle-next expr '()))

(newline)
(display
  (to-postfix
    input))
(newline)

(define postfix-expressions
  (map
    string->list
    (list
      "12+"
      "34-5+2*"
      "342*15-23^^/+")))

(newline)
(display
  (map
    evaluate-postfix
    postfix-expressions))
(newline)
