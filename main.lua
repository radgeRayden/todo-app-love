local live = {
    ---@type string
    srcpath = nil,
    ---@type table
    module = nil,
    modtime = 0,
    last_error = "",
    error_since_reload = false,
}

local function live_callback(name, ...)
    if live.error_since_reload then return false end
    if live.module and live.module[name] then
        local success, result = pcall(live.module[name], ...)
        if not success and result ~= live.last_error then
            print(("error executing callback %s: %s"):format(name, result))
            live.last_error = result
            live.error_since_reload = true
            return false
        end
    end
    return true
end

local function reload_source()
    local f, err = loadfile(live.srcpath)
    if f then
        local success, result = pcall(f)
        if success and type(result) == "table" then
            live.module = result
        else
            if result ~= live.last_error then
                print(("could not load module: %s"):format(result))
                live.last_error = result
                live.error_since_reload = true
            end
            return
        end
    else
        if err ~= live.last_error then
            print(("error while loading: %s"):format(err))
            live.last_error = err
            live.error_since_reload = true
        end
        return
    end

    live.modtime = love.filesystem.getInfo(live.srcpath).modtime
    live.error_since_reload = false
    live_callback "load"
end

---@param str string
local function pattern_escape(str)
    return str:gsub("([%-%=%^%$%(%)%%%.%[%]%*%+%?])", "%%%1")
end

function love.load(args)
    for _, v in ipairs(args) do
        local match = string.match(v, ("^%s(.+)$"):format(pattern_escape "--live-reload-source="))
        if match then
            live.srcpath = match
            reload_source()
        end
    end
end

function love.update(dt)
    if live.srcpath then
        local info = love.filesystem.getInfo(live.srcpath)
        if info and info.modtime > live.modtime then
            reload_source()
        end
    end
    live_callback("update", dt)
end

function love.draw()
    if not live_callback("draw") then
        love.graphics.print(live.last_error)
    end
end

function love.keypressed(key, scancode, isRepeat)
    if key == "escape" then
        love.event.quit()
    end
    live_callback("keypressed", key, scancode, isRepeat)
end
