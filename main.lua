local fennel = require("lib.fennel").install { correlate = true, moduleName = "lib.fennel" }
local live = require "live"

local make_love_searcher = function(env)
    return function(module_name)
        local path = module_name:gsub("%.", "/") .. ".fnl"
        if love.filesystem.getInfo(path) then
            return function(...)
                local code = love.filesystem.read(path)
                return fennel.eval(code, { env = env }, ...)
            end,
                path
        end
    end
end

table.insert(package.loaders, make_love_searcher(_G))
table.insert(fennel["macro-searchers"], make_love_searcher "_COMPILER")
debug.traceback = fennel.traceback

-- require "src.main"
local function fennel_loadfile(path, _, env)
    return function ()
        return fennel.dofile(path, {filename = path, env = env})
    end
end


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
                loadfile = string.find(match, ".+%.fnl") and fennel_loadfile or loadfile,
                require_patterns = {"%s.lua", "%s.fnl"}
            })
        end
    end
end
