(local live (require :live))
(local nlay (require :lib.nlay))
(local ui (require :src.ui))
(import-macros {: class } :src.macros)

(class task-view ui.view)

(λ setf [t field v] (set (. t field) v))

(λ task-view.new [self task parent]
   (self:super parent)
   (doto self
     (setf :layout {})
     (setf :task task))
   (doto self.layout
     (setf :button-complete
       (-> (nlay.constraint self.constraint self.constraint nil nil self.constraint)
           (: :size 50 30)
           (: :margin 20)))
     (setf :label
       (-> (nlay.constraint self.constraint self.constraint self.constraint nil self.layout.button-complete)
           (: :size 0 100)
           (: :margin [20 20])
           (: :bias 0))))
   (local push (partial self.push self))
   (push (ui.panel self.constraint [1 1 1 1]))
   (push (ui.label self.layout.label task.description))
   (push (ui.button self.layout.button-complete "YEAH" (fn [] (print "YEAH")))))

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

  (fn live.cb.mousepressed [x y btn]
    (view:mousepressed x y btn))

  (fn live.cb.mousereleased [x y btn]
    (view:mousereleased x y btn))

  (fn live.cb.resize [w h]))

{
  :task task-view
}
