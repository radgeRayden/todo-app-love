(local uuid (require :lib.uuid))

(uuid.set_rng 
  (fn [n]
    (let [buffer (require :string.buffer)
          bytes (buffer.new n)
          (ptr _) (bytes:reserve n)]
      (for [i 0 (- n 1)] (set (. ptr i) (love.math.random 0 255)))
      (bytes:commit n)
      (bytes:tostring))))

uuid
