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
    local proto_path = mod:gsub("%.", "/")
    for _,pattern in ipairs(require_patterns) do
        local path = pattern:format(proto_path)
        local info = love.filesystem.getInfo(path)
        if info then
            if require_cache[path] and info.modtime > require_cache[path] then
                package.loaded[mod] = nil
            end
            require_cache[path] = info.modtime
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

local function check_updated(path, modtime)
    local info = love.filesystem.getInfo(path)
    if not info then
        return false
    end
    return info.modtime > modtime
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

        do
            local err
            local are_files_stale = false
            for k,v in pairs(require_cache) do
                local is_stale = check_updated(k, v)
                if is_stale == nil then
                    err = true
                    break
                end
                are_files_stale = are_files_stale or is_stale
            end
            local is_main_file_stale = check_updated(source_path, modtime)
            if is_main_file_stale == nil then
                err = true
            end
            are_files_stale = are_files_stale or is_main_file_stale

            if err then
                local msg = ("file not found: %s"):format(path)
                print(msg)
                error_since_reload = true
                last_error = msg
                last_trace = nil
                return
            end

            if are_files_stale then
                -- clear all stale callbacks, because the module might have removed them
                m.cb = {}
                m.reload_source()
                m.call_protected(m.cb.load)
            end
        end

        m.call_protected(m.cb.update, dt)
    end

    for _, v in ipairs(settings.callbacks) do
        love[v] = function(...)
            m.call_protected(m.cb[v], ...)
        end
    end

    m.reload_source()
    m.call_protected(m.cb.load)
end

return m
