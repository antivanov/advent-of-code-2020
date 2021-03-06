(load "./lib/list.scm")
(load "./lib/tuples.scm")

(define input-data "
35
20
15
25
47
40
62
55
65
95
102
117
150
182
127
219
299
277
309
576
")
(define preamble-size 5)

; Parser
(define (parse-numbers input)
  (let ((numbers-input (split-list-by input '#\newline)))
    (map
      (lambda (x) (string->number (list->string x)))
      (filter
        (lambda (x) (> (length x) 0))
        numbers-input))))

; Solution
(define (allowed-next-numbers preamble)
  (map
    (lambda (p)
      (+ (car p) (cadr p)))
    (unique-pairs-of preamble)))

(define (find-first-invalid-xmas-number xmas-numbers preamble-size)
  (define (find-number remaining-xmas-numbers preamble)
    (if (null? remaining-xmas-numbers) #f
      (let ((current-number (car remaining-xmas-numbers))
            (allowed-numbers (allowed-next-numbers preamble)))
        (if (contains? current-number allowed-numbers)
          (find-number
            (cdr remaining-xmas-numbers)
            (append
              (drop preamble 1)
              (list current-number)))
          current-number))))
  (find-number (drop xmas-numbers preamble-size) (take xmas-numbers preamble-size)))

(define (find-range-summing-to-invalid-xmas-number xmas-numbers invalid-number)
  (define xmas-numbers-length (length xmas-numbers))
  (define (is-desired-range? range)
    (equal? (apply + range) invalid-number))
  (define (find-range-starting-at-index range-start-index)
    (define (find-range-of-length-greater-or-equal range-length)
      (let ((range-end-index (+ range-start-index range-length)))
        (if (>= range-end-index xmas-numbers-length) #f
          (let ((range (sublist range-start-index range-end-index xmas-numbers)))
            (if (is-desired-range? range) range
              (find-range-of-length-greater-or-equal (+ 1 range-length)))))))
    (let ((found-range-at-start-index (find-range-of-length-greater-or-equal 2)))
      (if found-range-at-start-index found-range-at-start-index
        (let ((next-start-index (+ 1 range-start-index)))
          (if (>= next-start-index xmas-numbers-length) #f
            (find-range-starting-at-index next-start-index))))))
    (find-range-starting-at-index 0))

(define (sum-of-max-and-min l)
  (let ((min-number (apply min l))
        (max-number (apply max l)))
    (+ min-number max-number)))

(define (find-weakness xmas-numbers invalid-number)
  (let ((weakness-range (find-range-summing-to-invalid-xmas-number xmas-numbers invalid-number)))
    (if weakness-range
      (sum-of-max-and-min weakness-range)
      #f)))

(define parsed-numbers
  (parse-numbers
    (string->list input-data)))

(newline)
(display "Part 1:")
(newline)
(define first-invalid-number
  (find-first-invalid-xmas-number
    parsed-numbers
    preamble-size))
(display first-invalid-number)
(newline)

(newline)
(display "Part 2:")
(newline)
(display
  (find-weakness
    parsed-numbers
    first-invalid-number))
(newline)