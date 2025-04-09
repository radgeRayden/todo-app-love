(local app (rrequire :app))
(local task (rrequire :task))

{
  : rrequire
  : task
  :add-task app.add-task
  :get-tasks app.get-tasks
}
