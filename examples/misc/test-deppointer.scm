; Build with:
;     gsc -cc-options -g -exe -o test-deppointer test-deppointer.scm
;
; You may check it with:
;     valgrind --leak-check=full ./test-deppointer
;
; You should get something like
;
; ==29668== Memcheck, a memory error detector
; ==29668== Copyright (C) 2002-2011, and GNU GPL'd, by Julian Seward et al.
; ==29668== Using Valgrind-3.7.0 and LibVEX; rerun with -h for copyright info
; ==29668== Command: ./test-deppointer
; ==29668==
; p is a: #<point* #2 0x5c04660>
; p has tags:
; (point* point)
; p.x: 3; p.y: 5
; initial dependencies are:
; ()
; dependencies are now:
; ((1 2))
; losing global reference to o
;
; a few garbage collections follow...
; (nothing much should happen since p is keeping o reachable)
; ...done collecting garbage
;
; killing p
; o checking out!
; done!
;
; ==29668==
; ==29668== HEAP SUMMARY:
; ==29668==     in use at exit: 0 bytes in 0 blocks
; ==29668==   total heap usage: 150 allocs, 150 frees, 3,198,437 bytes allocated
; ==29668==
; ==29668== All heap blocks were freed -- no leaks are possible
; ==29668==
; ==29668== For counts of detected and suppressed errors, rerun with: -v
; ==29668== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 2 from 2)

(c-declare "typedef struct { int x; int y; } point;")

(c-define-type point "point*" "DEPPOINTER_TO_SCMOBJ" "SCMOBJ_TO_DEPPOINTER" #f)

;XXX: make sure the tags are reachable.  The garbage collector will *NOT*
; scan the tags of a foreign object.
;
; If you don't care for type checking or you'll do your own, you may leave
; tags at #f.
(define tags '(point* point))

(define (make-point)
  (let ((ret
          ((c-lambda () point
            "___result = ___EXT(___alloc_rc)(sizeof(point));"))))
    ((c-lambda (scheme-object scheme-object) void
            "___FIELD(___arg1,___FOREIGN_TAGS) = ___arg2;")
     ret
     tags)
    ; I could have set a release function similarly, but the default no-op one
    ; will be fine for most purposes.
    ret))

(define p (make-point))

(define foreign-dependencies
  ;XXX type checking
  (c-lambda (scheme-object) scheme-object
    "___result = ___FIELD(___arg1,___FOREIGN_DEP);"))

(define (register-foreign-dependency! f o)
  ;XXX type checking
  ((c-lambda (scheme-object scheme-object) void
     "___FIELD(___arg1,___FOREIGN_DEP) = ___arg2;")
   f
   (cons o (foreign-dependencies f))))

(print "p is a: ")
(write p)
(newline)
(println "p has tags: ")
(write (foreign-tags p))
(newline)

(define p-x
  (c-lambda (point)
             int
     "___result = ((point*)___arg1)->x;"))

(define p-y
  (c-lambda (point)
             int
     "___result = ((point*)___arg1)->y;"))

(define p-x-set!
  (c-lambda (point int) void
     "((point*)___arg1)->x = ___arg2;"))

(define p-y-set!
  (c-lambda (point int) void
     "((point*)___arg1)->y = ___arg2;"))

(p-x-set! p 3)
(p-y-set! p 5)
(println "p.x: " (p-x p) "; p.y: " (p-y p))
(define o (list 1 2))
(make-will o (lambda (x) (println "o checking out!")))
(println "initial dependencies are:")
(write (foreign-dependencies p))
(newline)
(register-foreign-dependency! p o)
(println "dependencies are now:")
(write (foreign-dependencies p))
(newline)
(println "losing global reference to o")
(set! o #f)
(newline)
(println "a few garbage collections follow...")
(println "(nothing much should happen since p is keeping o reachable)")
(##gc)
(##gc)
(##gc)
(println "...done collecting garbage")
(newline)
(println "killing p")
(set! p #f)
(##gc)
(println "done!")
(newline)
