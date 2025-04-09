(local fennel (require "lib.fennel"))
(local task (rrequire :task))

(local state 
  { :tasks {} 
    :preferences {
      :language "en-US"
    }
  })

(λ handle-taskfile-error [err]
   (print err))

(λ unserialize-tasks [data]
   (icollect [_ v (ipairs data)]
     (setmetatable v task)))

(λ init! []
  (case (love.filesystem.read "tasks.tsk")
    (content _) (case (pcall fennel.eval content {:env {}})
                  (true data) (set state.tasks (unserialize-tasks data))
                  (false err) (handle-taskfile-error err))))

(λ save! []
  (love.filesystem.write "tasks.tsk" (fennel.view state.tasks)))

(λ get-tasks [] state.tasks)

(λ add-task [task]
   (table.insert state.tasks task))

{
  : init!
  : save! 
  : get-tasks
  : add-task
}

