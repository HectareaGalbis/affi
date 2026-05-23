
(defsystem "trivial-ffi"
  :author "Héctor Galbis Sanchis"
  :description "A minimal and common foreign interface"
  :depends-on (:alexandria)
  :serial t
  :components ((:module "src"
                :components ((:file "package")
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
