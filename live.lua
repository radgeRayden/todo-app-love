local error_since_reload = false
---@type string?
local last_error = ""
---@type string?
local last_trace = ""
local modtime = 0
local require_cache = {}
---@type string
local source_path = nil

---@type string[]
local require_patterns = {}
local loadfile_f

local m = {
    ---@type function[]
    cb = {},
    persist = {},
}

local function error_handler(err)
    return {
        err = err,
        trace = debug.traceback(err),
    }
end

---@param f function?
function m.call_protected(f, ...)
    if not f then
        return
    end
    if error_since_reload then
        return false
    end
    local success, result = xpcall(f, error_handler, ...)
    if not success then
        error_since_reload = true
        if result.err ~= last_error then
            print(result.trace)
            print(result.err)
        end
        last_error = result.err
        last_trace = result.trace
        return false
    end
    return true
end

local _require = require
---@param mod string
local function hot_require(mod)
    local path = mod:gsub("%.", "/")
    for _,pattern in ipairs(require_patterns) do
        local info = love.filesystem.getInfo(pattern:format(path))
        if info then
            if require_cache[mod] and info.modtime > require_cache[mod] then
                package.loaded[mod] = nil
            end
            require_cache[mod] = info.modtime
            break
        end
    end
    return _require(mod)
end

function m.reload_source()
    error_since_reload = false
    local f, err = loadfile_f(source_path, nil, setmetatable({ require = hot_require }, { __index = _G }))
    if f then
        m.call_protected(f)
    else
        if err ~= last_error then
            print(("error while loading: %s"):format(err))
            last_error = err
            last_trace = nil
            error_since_reload = true
        end
    end

    local info = love.filesystem.getInfo(source_path)
    if info then
        modtime = info.modtime
    end
end

local function error_screen()
    if last_trace then
        love.graphics.print(last_trace or "")
    else
        love.graphics.print(last_error or "")
    end
end

function m.setup(path, settings)
    assert(path)
    settings = settings or {}
    settings.callbacks = settings.callbacks or {}
    settings.loadfile = settings.loadfile or loadfile
    settings.require_patterns = settings.require_patterns or { "%s.lua" }

    source_path = path
    loadfile_f = settings.loadfile
    require_patterns = settings.require_patterns

    function love.draw()
        if m.cb.draw then
            love.graphics.push "all"
            m.call_protected(m.cb.draw)
            while pcall(love.graphics.pop) do
            end
        end
        love.graphics.reset()
        if error_since_reload then
            error_screen()
        end
    end

    local pre_update = settings.pre_update
    function love.update(dt)
        if pre_update then pre_update(dt) end

        local info = love.filesystem.getInfo(source_path)
        if not info and not error_since_reload then
            print(("file not found: %s"):format(source_path))
            error_since_reload = true
        end
        if info and info.modtime > modtime then
            -- clear all stale callbacks, because the module might have removed them
            m.cb = {}
            m.reload_source()
            m.call_protected(m.cb.load)
        end

        m.call_protected(m.cb.update, dt)
    end

    for _, v in ipairs(settings.callbacks) do
        love[v] = function(...)
            m.call_protected(m.cb[v], ...)
        end
    end
end

return m
