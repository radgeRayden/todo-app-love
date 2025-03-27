local m = {
    ---@type string
    source_path = nil,
    modtime = 0,
    last_error = "",
    last_trace = "",
    error_since_reload = false,
    cb = {},
    persist = {},
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

function m.reload_source()
    m.error_since_reload = false
    local f, err = loadfile(m.source_path)
    if f then
        m.call_protected(f)
    else
        if err ~= m.last_error then
            print(("error while loading: %s"):format(err))
            m.last_error = err
            m.error_since_reload = true
        end
        return
    end

    m.modtime = love.filesystem.getInfo(m.source_path).modtime
end

local function error_screen()
    love.graphics.print(m.last_trace)
    love.graphics.print(m.last_error)
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
            for k,v in pairs(m.cb) do
                m.cb[k] = nil
            end
            m.reload_source()
            m.call_protected(m.cb.load)
        end

        m.call_protected(m.cb.update, dt)
    end

    for _,v in ipairs(callbacks) do
        love[v] = function (...)
            m.call_protected(m.cb[v], ...)
        end
    end
end

return m
