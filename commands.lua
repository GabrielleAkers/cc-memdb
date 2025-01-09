local blake3 = require("ccryptolib.blake3")
local to_hex = require("ccryptolib.util").toHex

local make_error = function(error)
    return {
        error = error
    }
end

local make_response = function(obj)
    return {
        data = obj
    }
end

local commands = {}

commands.help = {
    cmd = function(cmd)
        if not commands[cmd.path] then
            return make_response(commands.help.help)
        end
        return make_response(commands[cmd.path].help)
    end,
    help = "help <command>  --  do list_cmd to see available commands"
}

commands.list_cmd = {
    cmd = function(cmd)
        local cmds = {}
        for k, _ in pairs(commands) do
            table.insert(cmds, k)
        end
        return make_response(cmds)
    end,
    help = "lists available commands"
}

local _get_by_path = function(t, path)
    for s in string.gmatch(path, "[^%.]+") do
        if not t then
            return nil
        end
        t = t[s]
    end
    return t
end

commands.get = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("get requires a path")
        end
        local res = _get_by_path(cmd.state, cmd.path)
        if res == nil then
            return make_error("path does not exist")
        end
        return make_response(res)
    end,
    help = "get <key|path>"
}

commands.get_id = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("get_id requires a path")
        end
        local res = _get_by_path(cmd.state, cmd.path)
        if res == nil then
            return make_error("path does not exist")
        end
        return make_response(to_hex(blake3.digest(cmd.path .. textutils.serialise(res))))
    end,
    help = "get_id <key|path>  --  gets a unique id for the path that can be passed to safe_set"
}

local _set_by_path = function(t, path, val)
    local p, k
    for s in string.gmatch(path, "[^%.]+") do
        if type(t) ~= "table" then
            t = {
                [s] = {}
            }
        end
        if not t[s] then
            t[s] = {}
        end
        k, p, t = s, t, t[s]
    end
    if type(val) == "string" then
        p[k] = textutils.unserialise(val)
    else
        p[k] = val
    end
end

commands.set = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("set requires a path")
        end
        if cmd.data == nil or cmd.data == "nil" then
            return make_error("cant set nil value")
        end
        _set_by_path(cmd.state, cmd.path, cmd.data)
        return make_response(true)
    end,
    help =
    "set <key|path> <data> [lifetime]  --  stores data overwriting existing, pass tables with no spaces and strings wrapped in single quotes"
}

commands.safe_set = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("safe_set requires a path")
        end
        if cmd.data == nil or cmd.data == "nil" then
            return make_error("cant safe_set nil value")
        end
        if not cmd.id then
            return make_error("safe_set requires an id")
        end
        local id = commands.get_id.cmd(cmd)
        if id.error then
            return id
        end
        if id.data == cmd.id then
            _set_by_path(cmd.state, cmd.path, cmd.data)
            return make_response(true)
        else
            return make_response(false)
        end
    end,
    help =
    "safe_set <key|path> <data> <id> [lifetime]  --  stores data only if the existing data's id matches the id passed, pass tables with no spaces and strings wrapped in single quotes"
}

commands.del = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("del requires a path")
        end
        if not _get_by_path(cmd.state, cmd.path) then
            return make_response(false)
        end
        _set_by_path(cmd.state, cmd.path, nil)
        return make_response(true)
    end,
    help = "del <key|path>  --  delete the given path, returns false if the path doesnt exist"
}

commands.append = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("append requires a path")
        end
        if cmd.data == nil or cmd.data == "nil" then
            return make_error("cannot append nil")
        end
        local d = _get_by_path(cmd.state, cmd.path)
        if type(d) ~= "table" and type(d) ~= "string" then
            return make_error("can only append to string or table")
        end
        if type(d) == "table" then
            d[#d + 1] = textutils.unserialise(cmd.data)
        elseif type(d) == "string" then
            local a = textutils.unserialise(cmd.data)
            if type(a) ~= "string" and type(a) ~= "number" then
                return make_error("can only append strings and number to strings, wrap strings in quotes")
            end
            d = "'" .. d .. a .. "'"
        end
        _set_by_path(cmd.state, cmd.path, d)
        return make_response(true)
    end,
    help = "append <key|path> <data>  --  append to given path if the data at that path is a table"
}

commands.prepend = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("prepend requires a path")
        end
        if cmd.data == nil or cmd.data == "nil" then
            return make_error("cannot prepend nil")
        end
        local d = _get_by_path(cmd.state, cmd.path)
        if type(d) ~= "table" and type(d) ~= "string" then
            return make_error("can only prepend to string or table")
        end
        if type(d) == "table" then
            table.insert(d, 1, textutils.unserialise(cmd.data))
        elseif type(d) == "string" then
            local a = textutils.unserialise(cmd.data)
            if type(a) ~= "string" and type(a) ~= "number" then
                return make_error("can only prepend strings and number to strings, wrap strings in quotes")
            end
            d = "'" .. a .. d .. "'"
        end
        _set_by_path(cmd.state, cmd.path, d)
        return make_response(true)
    end,
    help = "prepend <key|path> <data>  --  prepend to given path if the data at that path is a table"
}

commands.incr = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("prepend requires a path")
        end
        if cmd.data == nil or cmd.data == "nil" then
            return make_error("cannot incr nil")
        end
        local d = textutils.unserialise(cmd.data)
        if type(d) ~= "number" then
            return make_error("value must be a number")
        end
        if d < 0 then
            return make_error("cant incr by negative number, use decr instead")
        end
        local existing_d = _get_by_path(cmd.state, cmd.path)
        if type(existing_d) ~= "number" then
            return make_error("value at path " .. cmd.path .. " is not a number")
        end
        existing_d = existing_d + d
        _set_by_path(cmd.state, cmd.path, existing_d)
        return make_response(true)
    end,
    help =
    "incr <key|path> <val>  --  increment the value at the path by incr if the value is a number, val must be positive"
}

commands.decr = {
    cmd = function(cmd)
        if not cmd.path then
            return make_error("prepend requires a path")
        end
        if cmd.data == nil or cmd.data == "nil" then
            return make_error("cannot decr nil")
        end
        local d = textutils.unserialise(cmd.data)
        if type(d) ~= "number" then
            return make_error("value must be a number")
        end
        if d < 0 then
            return make_error("cant decr by negative number, use incr instead")
        end
        local existing_d = _get_by_path(cmd.state, cmd.path)
        if type(existing_d) ~= "number" then
            return make_error("value at path " .. cmd.path .. " is not a number")
        end
        existing_d = existing_d - d
        _set_by_path(cmd.state, cmd.path, existing_d)
        return make_response(true)
    end,
    help =
    "decr <key|path> <val>  --  decrement the value at the path by decr if the value is a number, val must be positive"
}

local _split_on_space_with_quotes = function(str)
    local quoted_values = {}
    local i = 1
    for substr in string.gmatch(str, "%b''") do
        quoted_values["@" .. tostring(i)] = substr
        str = string.gsub(str, substr, "@" .. tostring(i))
        i = i + 1
    end
    local substrs = {}
    i = 1
    for substr in string.gmatch(str, "%S+") do
        substrs[i] = substr
        i = i + 1
    end
    for j, v in ipairs(substrs) do
        local tag = string.gmatch(v, "(@[0-9]+)")()
        if tag then
            if quoted_values[tag] then
                substrs[j] = quoted_values[tag]
            else
                substrs[j] = ""
            end
        end
    end
    return substrs
end

local try_do_command = function(state, str, lifetimes)
    if type(str) ~= "string" then
        return make_error("pass commands as a string, do list_cmd to see available commands")
    end
    local cmd = _split_on_space_with_quotes(str)
    if not cmd[1] then
        return make_error("do list_cmd to see available commands")
    end
    if not commands[cmd[1]] then
        return make_error("command not recognized. Do list_cmd to see available commands")
    end
    local cmd_res = commands[cmd[1]].cmd({ state = state, path = cmd[2], data = cmd[3], id = cmd[4] })
    if (cmd[1] == "set" or cmd[1] == "safe_set" or cmd[1] == "append" or cmd[1] == "prepend" or cmd[1] == "incr" or cmd[1] == "decr") and cmd[2] then
        local duration
        if cmd[1] == "safe_set" then
            duration = tonumber(cmd[5])
        else
            duration = tonumber(cmd[4])
        end
        if not lifetimes[cmd[2]] then
            lifetimes[cmd[2]] = {}
        end
        lifetimes[cmd[2]].set_at = os.epoch("utc")
        lifetimes[cmd[2]].duration = (type(duration) == "number" and duration >= 0) and duration or 0
    end
    return cmd_res
end

return {
    commands = commands.list_cmd.cmd().data,
    new_command_runner = function(state, lifetimes)
        return function(str)
            return try_do_command(state, str, lifetimes)
        end
    end
}
