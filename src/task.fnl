(local uuid (rrequire :uuid))
(import-macros { : class } :src.macros)

(class task)

(λ task.new [self description ?project ?parent]
   (set self.description description)
   (set self.project ?project)
   (set self.parent ?parent)
   (set self.id (uuid)))

task
