(local nlay (require :lib.nlay))
(local live (require :live))
(local ui (require :src.ui))
(local fennel (require :lib.fennel))

(import-macros {: class } :src.macros)
(λ setf [t field v] (set (. t field) v))

(class ring ui.element)

(λ ring.new [self constraint]
   (self:super constraint)
   (set self.progress 0)
   (set self.line-width 10))

(λ ring.draw [self]
  (love.graphics.push :all)
  (love.graphics.setColor 1 0 0 1)
  (love.graphics.setLineJoin :miter)
  (love.graphics.setLineWidth self.line-width)
  (love.graphics.setLineStyle :smooth)
  (let [(x y w h) (self.constraint:get)
         r (/ (math.min w h) 2)
         cx (+ x (/ w 2))
         cy (+ y (/ h 2))
         start-angle (/ math.pi -2)
         end-angle (+ start-angle (* math.pi 2 (- 1 self.progress)))]
    (love.graphics.print (string.format "\n%.2f %.2f" start-angle end-angle))
    (love.graphics.arc :line :open cx cy r start-angle end-angle 360)
    (if (< self.progress 1)
      (do
        (love.graphics.circle :fill 
          (+ cx (* r (math.cos start-angle)))
          (+ cy (* r (math.sin start-angle)))
          (/ self.line-width 2)
          15)
        (love.graphics.circle :fill 
          (+ cx (* r (math.cos end-angle)))
          (+ cy (* r (math.sin end-angle)))
          (/ self.line-width 2)
          15)
        (love.graphics.setLineWidth 1)
        (love.graphics.circle :line
          (+ cx (* r (math.cos start-angle)))
          (+ cy (* r (math.sin start-angle)))
          (/ (- self.line-width 1.5) 2)
          15)
        (love.graphics.circle :line 
          (+ cx (* r (math.cos end-angle)))
          (+ cy (* r (math.sin end-angle)))
          (/ (- self.line-width 1.5) 2)
          15))))
  (love.graphics.setColor 0 0 0 1)
  (love.graphics.print self.progress)
  (love.graphics.pop))

(class pomodoro ui.view)

(λ pomodoro.new [self constraint time]
  (self:super constraint)
  (set self.time time)
  (set self.start-time (love.timer.getTime))
  (set self.layout {})
  (doto self.layout
    (setf :ring
      (->
        (ui.into self.constraint)
        (: :margin 30)
        (: :size 0 0)))
    (setf :timer
      (-> 
        (ui.into self.layout.ring)
        (: :size 0 0))))
  (set self.ring (ring self.layout.ring))
  (set self.timer-label 
    (ui.label self.layout.timer "00:00" 
       (ui.text-settings 
         { :v-align :center
           :h-align :center
           :font (love.graphics.newFont 36)})))
  (local push (partial self.push self))
  (push (ui.panel self.constraint [1 1 1 1]))
  (push self.ring)
  (push self.timer-label))

(λ pomodoro.update [self dt]
     (let [current-time (love.timer.getTime)
           time-elapsed (- current-time self.start-time)
           time-left (- self.time time-elapsed)
           minutes (math.floor (/ time-left 60))
           seconds (% time-left 60)] 
       (set self.ring.progress (math.min 1 (/ time-elapsed self.time)))
       (set self.timer-label.text (string.format "%02d:%02d" minutes seconds)))
   (ui.view.update self dt))

(fn live.cb.load []
  (local root (nlay.constraint nlay nlay nlay nlay nlay))
  (local view (pomodoro root (* 25 60)))

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
