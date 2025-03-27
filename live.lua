local m = {
    ---@type string
    source_path = nil,
    modtime = 0,
    last_error = "",
    last_trace = "",
    error_since_reload = false,
    cb = {},
    persist = {},

    require_cache = {},
}

local function error_handler(err)
    return {
        err = err,
        trace = debug.traceback(err),
    }
end

function m.call_protected(f, ...)
    if not f then
        return
    end
    if m.error_since_reload then
        return false
    end
    local success, result = xpcall(f, error_handler, ...)
    if not success then
        m.error_since_reload = true
        if result.err ~= m.last_error then
            print(result.trace)
            print(result.err)
        end
        m.last_error = result.err
        m.last_trace = result.trace
        return false
    end
    return true
end

local _require = require
---@param mod string
local function hot_require(mod)
    local path = mod:gsub("%.", "/")
    local info = love.filesystem.getInfo(("%s.lua"):format(path))
    if info then
        if m.require_cache[mod] and info.modtime > m.require_cache[mod] then
            package.loaded[mod] = nil
        end
        m.require_cache[mod] = info.modtime
    end
    return _require(mod)
end

function m.reload_source()
    m.error_since_reload = false
    local f, err = loadfile(m.source_path, nil, setmetatable({ require = hot_require }, { __index = _G }))
    if f then
        m.call_protected(f)
    else
        if err ~= m.last_error then
            print(("error while loading: %s"):format(err))
            m.last_error = err
            m.last_trace = nil
            m.error_since_reload = true
        end
    end

    local info = love.filesystem.getInfo(m.source_path)
    if info then
        m.modtime = info.modtime
    end
end

local function error_screen()
    if m.last_trace then
        love.graphics.print(m.last_trace)
    else
        love.graphics.print(m.last_error)
    end
end

function m.setup(source_path, callbacks)
    assert(source_path)
    m.source_path = source_path

    function love.draw()
        if m.cb.draw then
            love.graphics.push "all"
            m.call_protected(m.cb.draw)
            while pcall(love.graphics.pop) do
            end
        end
        if m.error_since_reload then
            error_screen()
        end
    end

    function love.update(dt)
        local info = love.filesystem.getInfo(m.source_path)
        if info and info.modtime > m.modtime then
            -- clear all stale callbacks, because the module might have removed them
            m.cb = {}
            m.reload_source()
            m.call_protected(m.cb.load)
        end

        m.call_protected(m.cb.update, dt)
    end

    for _, v in ipairs(callbacks) do
        love[v] = function(...)
            m.call_protected(m.cb[v], ...)
        end
    end
end

return m
