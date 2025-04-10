(local fennel (require "lib.fennel"))
(local task (rrequire :task))

(local state 
  { :tasks {} 
    :tasks-by-id {}
    :tasks-by-parent {}
    :preferences {
      :language "en-US"
    }
  })

(λ handle-taskfile-error [err]
   (print err))

(λ add-task [t]
  (assert (= t.__type "task"))
  (table.insert state.tasks t)
  (set (. state.tasks-by-id t.id) t)
  (let [ parents state.tasks-by-parent
         p-id t.parent ]
    (when p-id
      (if (not (. parents p-id)) (set (. parents p-id) {}))
      (table.insert (. parents p-id) t))))

(λ init! []
  (case (love.filesystem.read "tasks.tsk")
    (content _) (case (pcall fennel.eval content {:env {}})
                  (true data) (each [_ v (ipairs data)] (add-task (task.unserialize v)))
                  (false err) (handle-taskfile-error err))))

(λ save! []
  (love.filesystem.write "tasks.tsk" (fennel.view state.tasks)))

(λ get-tasks [] state.tasks)
(λ get-children [parent-id]
   (. state.tasks-by-parent parent-id))

{
  : init!
  : save! 
  : get-tasks
  : add-task
  : get-children
}

