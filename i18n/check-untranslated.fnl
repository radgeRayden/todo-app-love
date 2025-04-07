(local languages
  { :en-US (require :i18n.en-US)
    :pt-BR (require :i18n.pt-BR) })

(local strings {})
(each [_ langfile (pairs languages)]
  (each [k _ (pairs langfile)]
    (set (. strings k) true)))

(each [k _ (pairs strings)]
  (each [langname langfile (pairs languages)]
    (if (not (. langfile k))
      (print (string.format "untranslated key '%s' in language file '%s'" k langname)))))
