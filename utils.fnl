(local fennel (require :lib.fennel))

(λ pprint [value]
   (print (fennel.view value)))

(λ rrequire [name]
   (let [dir (string.match 
              (. (debug.getinfo 2 :S) :short_src)
              "^%.?%/?(.+)/.+$")
         prefix (dir:gsub "%/" "%.")]
     (require (.. prefix :. name))))

{
    : pprint
    : rrequire
}
