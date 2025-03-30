(local live (require :live))
(local fennel (require :lib.fennel))
(local app (rrequire :app))

(local app-options {
        :live-reload-source ""
       })

(λ rslice [t n]
   (icollect [i v (ipairs t)] (if (>= i n) v)))

(λ set-option! [key value]
   (if (. app-options key)
       (set (. app-options key) value)
       (print (string.format "unrecognized option: %s" key))))

(λ parse-arg [arg]
   (case (string.match arg "^%-%-(.+)%=(.+)$")
     (key value) (values key value)
     _ (string.match arg "^%-%-(.+)$")))

(λ parse-options! [args]
  (var args args)
  (var positional-arg-index 1)
  (while (> (length args) 0)
    (let [[key-or-pair ?value & rest] args]
      (case (parse-arg key-or-pair)
        (key value) (do (set-option! key value) (set args (rslice args 2)))
         key (do (set-option! key ?value) (set args rest))
         _ (do
             (set-option! positional-arg-index key-or-pair)
             (set args (rslice args 2))
             (set positional-arg-index (+ positional-arg-index 1)))))))

(fn fennel-loadfile [path _ env]
  (fn [] (fennel.dofile path {:filename path : env})))

(λ setup-live-coding-env! [module]
   (live.setup module
     {:callbacks 
       [ :keypressed 
         :keyreleased
         :resize
         :mousepressed
         :mousereleased ]
       :loadfile (if (module:find "%.fnl$") fennel-loadfile loadfile)
       :require_patterns ["%s.lua" "%s.fnl"]}))

(fn love.load [args]
  (parse-options! args)
  (case app-options.live-reload-source
    "" (app.init!)
    path (setup-live-coding-env! path)))

(fn love.update [dt])
