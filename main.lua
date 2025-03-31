local fennel = require("lib.fennel").install { correlate = true, moduleName = "lib.fennel" }

local make_love_searcher = function(env)
    return function(module_name)
        local path = module_name:gsub("%.", "/") .. ".fnl"
        if love.filesystem.getInfo(path) then
            return function(...)
                local code = love.filesystem.read(path)
                return fennel.eval(code, { env = env }, ...)
            end, path
        end
    end
end

local utils = require "utils"
for k,v in pairs(utils) do
    _G[k] = v
end

table.insert(package.loaders, make_love_searcher(_G))
table.insert(fennel["macro-searchers"], make_love_searcher "_COMPILER")
debug.traceback = fennel.traceback

require "src.main"
