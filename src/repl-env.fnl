(local tablex (require :lib.batteries.tablex))
(local app (rrequire :app))
(local task (rrequire :task))

(tablex.overlay app 
  { : rrequire
    : task })
