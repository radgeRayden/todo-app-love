(import-macros {: class } :src.macros)
(local nlay (require :lib.nlay))

(λ setf [t field v] (set (. t field) v))

(λ into [parent]
   (nlay.constraint parent parent parent parent parent))

(var id-count 0)
(λ gen-id []
   (let [idx id-count]
     (set id-count (+ id-count 1))
     (.. :__generated-id# (tostring idx))))

(local _text-settings
   { :h-align :left
     :v-align :center
     :font (love.graphics.newFont 13) })

(λ text-settings [data] (setmetatable data {:__index _text-settings}))

(class panel)
(λ panel.new [self constraint color]
   (set self.color color)
   (set self.constraint constraint))

(λ panel.draw [self]
   (love.graphics.push :all)
   (love.graphics.setColor self.color)
   (love.graphics.rectangle :fill (self.constraint:get))
   (love.graphics.pop))

(class label)
(λ label.new [self constraint text ?settings]
  (set self.constraint constraint)
  (set self.settings (or ?settings _text-settings))
  (set self.text text)
  (set self.text-batch (love.graphics.newTextBatch self.settings.font)))

(λ label.draw [self]
   (love.graphics.setColor 0 0 0 1)
   (let [(x y w h) (self.constraint:get)]
     (self.text-batch:setf self.text w self.settings.h-align)
     (love.graphics.draw self.text-batch x y)))

(class button)
(λ button.new [self constraint text on-click]
   (set self.constraint constraint)
   (set self.label-constraint 
     (-> (into constraint)
       (: :bias 0.5 0.5)
       (: :size 0.9 0.5 :percent :percent)))
   (set self.text text)
   (set self.on-click on-click))

(λ button.draw [self]
   (if self.hovered?
      (love.graphics.setColor 0.75 0.75 0.75 1)
      (love.graphics.setColor 0.25 0.25 0.25 1))
   (love.graphics.rectangle :fill (self.constraint:get))
   (love.graphics.setColor 1 1 1 1)
   (let [(x y w h) (self.label-constraint:get)]
     (love.graphics.print self.text x y)))

(class view)

(λ view.new [self parent-constraint ?id]
   (set self.elements [])
   (set self.buttons [])
   (set self.id (or ?id (gen-id)))
   (set self.parent-constraint parent-constraint)
   (set self.root (nlay.floating 0 0 0 0)))

(λ view.draw [self]
  (let [(x y w h) (self.parent-constraint:get)]
    (each [_ v (ipairs self.elements)]
      (v:draw))))

(λ view.update [self dt]
  (self.root:update (self.parent-constraint:get))
  (let [(mx my) (love.mouse.getPosition)]
    (each [_ b (ipairs self.buttons)]
      (let [(x y w h) (b.constraint:get)]
        (set b.hovered? (and (>= mx x) (>= my y) (<= mx (+ x w)) (<= my (+ y h))))))))

(λ view.push [self element]
   (if (element:is button) (self:add-button element))
   (table.insert self.elements element))

(λ view.add-button [self btn]
   (table.insert self.buttons btn))

{
  : view
  : into
  : text-settings
  : panel
  : label
  : button
}
