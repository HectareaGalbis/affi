
(defsystem "trivial-ffi"
  :author "Héctor Galbis Sanchis"
  :description "A minimal and common foreign interface"
  :depends-on (:alexandria)
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
                             (:file "interface")))))

(defsystem "trivial-ffi/test"
  :author "Héctor Galbis Sanchis"
  :description "A minimal and common foreign interface"
  :depends-on (:trivial-ffi)
  :serial t
  :components ((:module "test"
                :components ((:file "package")
                             (:file "test")))))

(defsystem "trivial-ffi/docs"
  :author "Héctor Galbis Sanchis"
  :description "Documentation for trivial-ffi"
  :defsystem-depends-on (:adp-github)
  :depends-on (:trivial-ffi)
  :serial t
  :class :adp-github
  :components ((:module "scribble"
                :serial t
                :components ((:file "package")
                             (:scribble "README")
                             (:scribble "reference")))))
