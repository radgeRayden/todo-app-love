(local tablex (require :lib.batteries.tablex))
(local uuid (rrequire :uuid))
(import-macros { : class } :src.macros)

(class task)

(λ task.new [self description ?project ?parent]
   (set self.description description)
   (set self.project ?project)
   (set self.parent ?parent)
   (set self.complete? false)
   (set self.creation-time (os.time))
   (set self.id (uuid)))

(λ task.unserialize [data]
   (tablex.overlay (task "") data))

task
