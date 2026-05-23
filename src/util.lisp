
(in-package #:tffi)

(defmacro %setf-key-value (table &rest key-values)
  (with-gensyms (table-sym)
    `(let ((,table-sym ,table))
       (setf ,@(loop for (key value . tail) on key-values by #'cddr
                     collect `(gethash ',key ,table-sym)
                     collect `',value)))))
