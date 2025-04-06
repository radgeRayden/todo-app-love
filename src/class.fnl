;; fennel-ls: macro-file

(λ class [name ?super]
  (assert (and (= (type name) :table)) "class name must be a symbol")
  (let [class `(require :lib.batteries.class)
        [name] name
        super ?super]
    (assert (= (type name) :string) "class name must be a symbol")
    `(local ,(sym name) (,class {:name ,name :extends ,super}))))

{ : class }
