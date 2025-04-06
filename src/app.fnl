(local fennel (require "lib.fennel"))
(import-macros { : class } :src.class)

(class task)

(λ task.new [self description]
   (set self.description description))

(var tasks {})

(λ handle-taskfile-error [err]
   (print err))

(λ unserialize-tasks [data]
   (icollect [_ v (ipairs data)]
     (task v.description)))

(λ init! []
  (case (love.filesystem.read "tasks.tsk")
    (content _) (case (pcall fennel.eval content {:env {}})
                  (true data) (set tasks (unserialize-tasks data))
                  (false err) (handle-taskfile-error err))))

(λ save! []
  (love.filesystem.write "tasks.tsk" (fennel.view tasks)))

{
  : init!
  : save! 
}

