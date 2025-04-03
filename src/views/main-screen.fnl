(local live (require "live"))

(fn live.cb.load []
  (print "hello world"))

(fn live.cb.draw []
  (love.graphics.print "hello world"))
{}
