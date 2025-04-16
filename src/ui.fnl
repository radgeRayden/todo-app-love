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

(class element)
(λ element.new [self constraint ?id]
   (set self.elements [])
   (set self.constraint constraint)
   (set self.id (or ?id (gen-id)))
   (set self.important? false))

(λ make-forwarding-callback [method]
   (fn [self ...]
     (each [_ v (ipairs self.elements)]
       (: v method ...))))

(local callbacks [:mousepressed :mousereleased :update])
(each [_ v (ipairs callbacks)]
  (set (. element v) (make-forwarding-callback v)))

(class panel element)
(λ panel.new [self constraint color]
   (self:super constraint)
   (set self.color color))

(λ panel.draw [self]
   (love.graphics.push :all)
   (love.graphics.setColor self.color)
   (love.graphics.rectangle :fill (self.constraint:get))
   (love.graphics.pop))

(class label element)
(λ label.new [self constraint text ?settings]
  (self:super constraint)
  (set self.settings (or ?settings _text-settings))
  (set self.text text)
  (set self.text-batch (love.graphics.newTextBatch self.settings.font)))

(λ label.draw [self]
   (love.graphics.setColor 0 0 0 1)
   (let [(x y w h) (self.constraint:get)]
     (self.text-batch:setf self.text w self.settings.h-align)
     (love.graphics.draw self.text-batch x y)))

(class button element)
(λ button.new [self constraint text on-click]
   (self:super constraint)
   (set self.label-constraint 
     (-> (into constraint)
       (: :bias 0.5 0.5)
       (: :size 0.9 0.5 :percent :percent)))
   (set self.text text)
   (set self.on-click on-click))

(λ button.update [self dt]
  (let [(mx my) (love.mouse.getPosition)
        (x y w h) (self.constraint:get)]
          (set self.hovered?
            (and (>= mx x) (>= my y) (<= mx (+ x w)) (<= my (+ y h)))))
   (element.update self dt))

(λ button.draw [self]
   (if self.hovered?
      (love.graphics.setColor 0.75 0.75 0.75 1)
      (love.graphics.setColor 0.25 0.25 0.25 1))
   (love.graphics.rectangle :fill (self.constraint:get))
   (love.graphics.setColor 1 1 1 1)
   (let [(x y w h) (self.label-constraint:get)]
     (love.graphics.print self.text x y)))

(λ button.mousereleased [self mx my btn]
   (let [(x y w h) (self.constraint:get)]
      (if (and (>= mx x) (>= my y) (<= mx (+ x w)) (<= my (+ y h)))
          (self:on-click))))

(class view element)
(λ view.new [self parent-constraint ?id]
   (self:super (nlay.floating 0 0 0 0))
   (set self.parent-constraint parent-constraint)
   (set self.important? false))

(λ view.draw [self]
  (let [(x y w h) (self.parent-constraint:get)
        important []]
    (each [_ v (ipairs self.elements)]
      (if v.important?
          (table.insert important v)
          (v:draw)))
    (each [_ v (ipairs important)]
      (v:draw))))

(λ view.update [self dt]
  (self.constraint:update (self.parent-constraint:get))
  (element.update self dt))

(λ view.push [self element]
   (table.insert self.elements element))

{
  : view
  : into
  : text-settings
  : panel
  : label
  : button
}
