(local live (require :live))
(local fennel (require :lib.fennel))
(local app (rrequire :app))

(local app-options {
        :live-reload-source ""
        :enable-repl false
        :blocking-repl false
        :no-window false
       })

(λ rslice [t n]
   (icollect [i v (ipairs t)] (if (>= i n) v)))

(λ set-option! [key value]
   (if (~= (. app-options key) nil)
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
    "" (do (app.init!) (app.save!))
    path (setup-live-coding-env! path))
  (if app-options.no-window
      (do
        (set app-options.enable-repl true)
        (set app-options.blocking-repl true))
      (love.window.setMode 800 600 { :resizable true }))
  (when app-options.enable-repl
    (if (not app-options.blocking-repl)
     (: (love.thread.newThread 
       "local repl_to_main, main_to_repl =
          love.thread.getChannel('repl-to-main'),
          love.thread.getChannel('main-to-repl')
        while not (main_to_repl:pop() == 'exit') do
          local input = io.read()
          love.thread.getChannel('repl-to-main'):push(input)
        end")
       :start)
      (do 
        (fennel.repl)
        (love.event.quit)))))

(fn process-repl-input []
  (let [channel (love.thread.getChannel :repl-to-main)
        input (channel:pop)]
    (if input (pprint (fennel.eval input {:env _G})))))

(fn love.update [dt]
  (if app-options.enable-repl (process-repl-input)))

(fn love.quit []
  (let [channel (love.thread.getChannel :main-to-repl)]
    (channel:push "exit")
    false))
