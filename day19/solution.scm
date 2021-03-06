(load "./lib/list.scm")
(load "./lib/parser.scm")
(load "./lib/string.scm")
(load "./lib/timings.scm")

(define input-data "
42: 9 14 | 10 1
9: 14 27 | 1 26
10: 23 14 | 28 1
1: a
11: 42 31
5: 1 14 | 15 1
19: 14 1 | 14 14
12: 24 14 | 19 1
16: 15 1 | 14 14
31: 14 17 | 1 13
6: 14 14 | 1 14
2: 1 24 | 14 4
0: 8 11
13: 14 3 | 1 12
15: 1 | 14
17: 14 2 | 1 7
23: 25 1 | 22 14
28: 16 1
4: 1 1
20: 14 14 | 1 15
3: 5 14 | 16 1
27: 1 6 | 14 18
14: b
21: 14 1 | 1 14
25: 1 1 | 1 14
22: 14 14
8: 42
26: 14 22 | 1 20
18: 15 15
7: 14 5 | 1 21
24: 14 1

abbbbbabbbaaaababbaabbbbabababbbabbbbbbabaaaa
bbabbbbaabaabba
babbbbaabbbbbabbbbbbaabaaabaaa
aaabbbbbbaaaabaababaabababbabaaabbababababaaa
bbbbbbbaaaabbbbaaabbabaaa
bbbababbbbaaaaaaaabbababaaababaabab
ababaaaaaabaaab
ababaaaaabbbaba
baabbaaaabbaaaababbaababb
abbbbabbbbaaaababbbbbbaaaababb
aaaaabbaabaaaaababaa
aaaabbaaaabbaaa
aaaabbaabbaaaaaaabbbabbbaaabbaabaaa
babaaabbbaaabaababbaabababaaab
aabbbbbaabbbaaaaaabbbbbababaaaaabbaaabba
")

(define modified-rules "
8: 42 | 42 8
11: 42 31 | 42 11 31
")

; Parser
(define (parse-input input)
  (let ((input-parts
          (omit-empty
            (split-list-by
              (split-list-by
                input
                '#\newline)
                '()))))
    (cons
      (parse-rules (car input-parts))
      (parse-messages (cadr input-parts)))))

(define (parse-modified-rules input)
  (let ((input-parts
          (omit-empty
            (split-list-by
              input
              '#\newline))))
    (parse-rules input-parts)))

(define (parse-rules input)
  (map
    parse-rule
    input))

(define (parse-rule input)
  (let ((rule-parts
         (split-list-by
           input
           #\space)))
    (let ((rule-id
            (char-list->string
                (drop-from-tail (car rule-parts) 1)))
          (rule-definition
            (map char-list->string (cdr rule-parts))))
      (cons rule-id (parse-or rule-definition)))))

(define (parse-or input)
  (let ((or-parts (split-list-by input "|")))
    (if (> (length or-parts) 1)
      (apply
        rule-one-of
        (map
          parse-seq
          or-parts))
      (parse-seq (car or-parts)))))

(define (parse-seq input)
    (if (> (length input) 1)
      (apply
        rule-sequence
        (map
          parse-simple-rule
          input))
      (parse-simple-rule (car input))))

(define (parse-simple-rule input)
  (if (string-is-number? input)
    (rule-reference input)
    (rule-character
      (car
        (string->list input)))))

(define (parse-messages input)
  (map
    list->string
    input))

; Rules
(define (rule-character ch)
  (define (match str)
    (cond ((null? str) (list (cons #f 0)))
          ((equal? (car str) ch) (list (cons #t 1)))
          (else (list (cons #f 0)))))
  (define (dispatch op)
    (cond ((eq? op 'match) match)
          ((eq? op 'as-list) (list "ch:" ch))
          (else (error "Unsupported op for rule-character:" op))))
  dispatch)

(define (rule-sequence . rules)
  (define (loop remaining-rules remaining-str offset)
    (cond ((null? remaining-rules) (list (cons #t offset)))
          ((null? remaining-str) (list (cons #f offset)))
          (else (let ((next-rule
                        (car remaining-rules)))
                  (let ((next-rule-matches ((next-rule 'match) remaining-str)))
                    (apply
                      append
                      (map
                        (lambda (next-rule-match)
                          (let ((offset-increment (cdr next-rule-match)))
                            (loop
                              (cdr remaining-rules)
                              (drop remaining-str offset-increment)
                              (+ offset offset-increment))))
                        (filter
                          (lambda (next-rule-match)
                            (car next-rule-match))
                          next-rule-matches))))))))
  (define (match str)
    (loop rules str 0))
  (define (dispatch op)
    (cond ((eq? op 'match) match)
          ((eq? op 'as-list) (list "seq:"
            (map
              (lambda (rule)
                (rule 'as-list))
              rules)))
          (else (error "Unsupported op for rule-sequence:" op))))
  dispatch)

(define (rule-one-of . rules)
  (define (loop remaining-rules str)
    (cond ((null? remaining-rules) (list (cons #f 0)))
          ((null? str) (list (cons #f 0)))
          (else (let ((next-rule
                        (car remaining-rules)))
                  (let ((next-rule-matches ((next-rule 'match) str)))
                    (let ((positive-next-rule-matches
                            (filter
                              (lambda (next-rule-match)
                                (car next-rule-match))
                              next-rule-matches)))
                      (append
                        positive-next-rule-matches
                        (loop
                          (cdr remaining-rules)
                          str))))))))
  (define (match str)
    (loop rules str))
  (define (dispatch op)
   (cond ((eq? op 'match) match)
         ((eq? op 'as-list) (list "one-of:"
           (map
             (lambda (rule)
               (rule 'as-list))
             rules)))
         (else (error "Unsupported op for rule-one-of:" op))))
  dispatch)

(define (rule-reference rule-id)
  (define (match str)
    (let ((found-rule (assoc rule-id rules)))
      (if found-rule
        (((cdr found-rule) 'match) str)
        (error "Could not find rule with id" rule-id rules))))
  (define (dispatch op)
   (cond ((eq? op 'match) match)
         ((eq? op 'as-list) (list "ref:" rule-id))
         (else (error "Unsupported op for rule-reference:" op))))
  dispatch)

(define (matches-rule? rule)
  (lambda (str)
    (let ((rule-match-and-offset-pairs
          ((rule 'match) str)))
      (>
        (length
          (filter
            (lambda (rule-match-and-offset)
              (let ((rule-match (car rule-match-and-offset))
                    (rule-match-offset (cdr rule-match-and-offset)))
                (and
                  rule-match
                  (=
                    rule-match-offset
                    (length str)))))
            rule-match-and-offset-pairs))
        0))))

; Display the results
(define parsed
  (parse-input
    (string->list input-data)))

(define rules
  (car parsed))

(define messages
  (cdr parsed))

(define rule-zero
  (matches-rule?
    (rule-reference "0")))

(define (matching-messages)
  (filter
    (lambda (m)
      (rule-zero
        (string->list m)))
    messages))

(define (number-of-matching-messages)
  (length
    (filter
      (lambda (m)
        (rule-zero
          (string->list m)))
      messages)))

(newline)
(display "Part 1:")
(newline)
(display
  (with-timings
    (lambda ()
      (number-of-matching-messages))
    write-timings))
(newline)

(define parsed-modified-rules
  (parse-modified-rules
    (string->list modified-rules)))

(define rules
  (append
    parsed-modified-rules
    rules))

(newline)
(display "Part 2:")
(newline)
(display
  (with-timings
    (lambda ()
      (number-of-matching-messages))
    write-timings))
(newline)
