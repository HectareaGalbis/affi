
(defsystem "affi"
  :author "Héctor Galbis Sanchis"
  :description "Another foreign function interface"
  :depends-on ("alexandria")
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "error")
                             (:file "util")
                             (:file "type")
                             #+sbcl
                             (:file "sbcl")
                             #+clisp
                             (:file "clisp")
                             (:file "interface"))))
  :in-order-to ((test-op (test-op "affi/test"))))

(defsystem "affi/test"
  :author "Héctor Galbis Sanchis"
  :description "A minimal and common foreign interface"
  :depends-on ("affi")
  :serial t
  :components ((:module "test"
                :components ((:file "package")
                             (:file "test"))))
  :perform (test-op (o c)
             (unless (uiop:symbol-call :test-affi :run-tests)
               (error "affi tests failed"))))

(defsystem "affi/docs"
  :author "Héctor Galbis Sanchis"
  :description "Documentation for affi"
  :defsystem-depends-on (:adp-github)
  :depends-on ("affi")
  :serial t
  :class :adp-github
  :components ((:module "scribble"
                :serial t
                :components ((:file "package")
                             (:scribble "README")
                             (:scribble "tutorial")))))
