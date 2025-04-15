(import-macros {: class } :src.macros)
(local nlay (require :lib.nlay))

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
   (love.graphics.setColor 0.25 0.25 0.25 1)
   (love.graphics.rectangle :fill (self.constraint:get))
   (love.graphics.setColor 1 1 1 1)
   (let [(x y w h) (self.label-constraint:get)]
     (love.graphics.print self.text x y)))

(class view)

(λ view.new [self ?id]
   (set self.elements [])
   (set self.buttons [])
   (set self.id (or ?id (gen-id)))
   (set self.root (into nlay)))

(λ view.draw [self constraint]
  (love.graphics.push)
  (let [(x y w h) (constraint:get)]
    (self.root:size w h)
    (love.graphics.translate x y)
    (each [_ v (ipairs self.elements)]
      (v:draw)))
  (love.graphics.pop))

(λ view.add-element [self element]
   (table.insert self.elements element))

(λ view.add-button [self btn]
   (table.insert self.buttons btn))

(λ view.button [self ...]
  (let [btn (button ...)]
    (self:add-element btn)
    (self:add-button btn)))

(λ view.image [self constraint ?id ])

(λ view.panel [self constraint color ?id]
   (self:add-element (panel constraint color)))

(λ view.label [self constraint text ?id]
   (self:add-element (label constraint text)))

(λ view.text-field [self constraint ?id ])

(λ view.text-area [self constraint ?id ])

{
   : view
   : into
   : text-settings
}
