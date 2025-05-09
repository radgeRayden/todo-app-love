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
     :v-align :top
     :font (love.graphics.newFont 13)
     :color [0 0 0 1] })

(λ text-settings [data] (setmetatable data {:__index _text-settings}))

(class element)
(λ element.new [self constraint ?id]
   (set self.elements [])
   (set self.constraint constraint)
   (set self.id (or ?id (gen-id)))
   (set self.important? false))

(λ element.push [self element]
   (table.insert self.elements element))

(λ make-forwarding-callback [method]
   (fn [self ...]
     (each [_ v (ipairs self.elements)]
       (: v method ...))))

(local callbacks [:draw :mousepressed :mousereleased :update])
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
  (set self.text-batch (love.graphics.newTextBatch self.settings.font))
  (set self.v-center-constraint
    (nlay.line constraint :vertical :percent 0.5)))

(λ label.draw [self]
   (love.graphics.setColor self.settings.color)
   (let [batch self.text-batch
         v-align self.settings.v-align
         (x y w h) (self.constraint:get)
         (_ cy) (self.v-center-constraint:get)]
     (batch:setf self.text w self.settings.h-align)
     (love.graphics.draw batch x 
       (case v-align 
         :top y
         :center (- cy (/ (batch:getHeight) 2))
         :bottom (- (+ y h) (batch:getHeight))))))

(class button element)
(λ button.new [self constraint text on-click]
   (self:super constraint)
   (set self.label-constraint 
     (-> (into constraint)
       (: :bias 0.5 0.5)
       (: :size 0.9 0.5 :percent :percent)))
   (self:push (label self.label-constraint text
               (text-settings 
                 { :color [ 1 1 1 1 ]
                   :h-align :center
                   :v-align :center })))
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
   (element.draw self))

(λ button.mousereleased [self mx my btn]
   (let [(x y w h) (self.constraint:get)]
      (if (and (>= mx x) (>= my y) (<= mx (+ x w)) (<= my (+ y h)))
          (self:on-click))))

(class view element)
(λ view.new [self parent-constraint ?id]
   (self:super (nlay.floating 0 0 0 0))
   (set self.parent-constraint parent-constraint)
   (set self.important? false))

(λ view.update [self dt]
  (self.constraint:update (self.parent-constraint:get))
  (element.update self dt))

{
  : element
  : view
  : into
  : text-settings
  : panel
  : label
  : button
}
