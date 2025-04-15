(local live (require :live))
(local nlay (require :lib.nlay))
(local ui (require :src.ui))
(import-macros {: class } :src.macros)

(class task-view ui.view)

(λ setf [t field v] (set (. t field) v))

(λ task-view.new [self task constraint]
   (self:super constraint)
   (doto self
     (setf :layout {})
     (setf :task task))
   (doto self.layout
     (setf :button-complete
       (-> (nlay.constraint self.root self.root nil nil self.root)
           (: :size 50 30)
           (: :margin 20)))
     (setf :label
       (-> (nlay.constraint self.root self.root self.root nil self.layout.button-complete)
           (: :size 0 100)
           (: :margin [20 20])
           (: :bias 0))))
   (self:panel self.root [1 1 1 1])
   (self:label self.layout.label task.description)
   (self:button self.layout.button-complete "YEAH" (fn [] (print "YEAH"))))

(fn live.cb.load []
  (local root (nlay.constraint nlay nlay nlay nlay nlay))
  (-> root
      (: :size 0 200)
      (: :margin [30 20 30 20]))
  (local task (require :src.task))
  (local view (task-view (task "placeholder description") root))

  (fn live.cb.draw []
    (view:draw))

  (fn live.cb.update [dt]
    (nlay.update (love.window.getSafeArea))
    (view:update dt))
  (fn live.cb.resize [w h]
    ))
{
  :task task-view
}
