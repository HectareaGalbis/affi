
(in-package #:tffi)


(define-condition syntax-error (program-error)
    ((sources :initform nil :accessor syntax-error-sources)
     (message :initarg :message :initform (error "Need a message") :reader syntax-error-message))
    (:report (lambda (c s)
               (let ((*print-circle* nil))
                 (loop for source in (syntax-error-sources c)
                       do (format s "> ~s~%" source))
                 (format s "~a" (syntax-error-message c))))))

(defun syntax-error (fmt &rest args)
  (error 'syntax-error :message (apply #'format nil fmt args)))

(define-compiler-macro syntax-error (fmt &rest args)
  `(error 'syntax-error :message (format nil ,fmt ,@args)))

(defun push-syntax-error-source-lambda (source)
  (lambda (c)
    (let ((last-source (car (syntax-error-sources c))))
      (unless (eq source last-source)
        (push source (syntax-error-sources c))))))

(defmacro with-syntax-error-handler (source &body body)
  `(handler-bind
       ((syntax-error (push-syntax-error-source-lambda ,source)))
     ,@body))
