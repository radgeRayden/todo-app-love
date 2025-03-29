local live = require "live"

---@param str string
local function pattern_escape(str)
    return str:gsub("([%-%=%^%$%(%)%%%.%[%]%*%+%?])", "%%%1")
end

function love.load(args)
    love.window.setDisplaySleepEnabled(true)
    for _, v in ipairs(args) do
        local match = string.match(v, ("^%s(.+)$"):format(pattern_escape "--live-reload-source="))
        if match then
            live.setup(match, {
                callbacks = {
                    "keypressed",
                    "keyreleased",
                    "resize",
                    "mousepressed",
                    "mousereleased",
                },
            })
        end
    end
end
