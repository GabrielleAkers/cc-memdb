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
        t[s] = {}
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
    help = "set <key|path> <data>  --  stores data overwriting existing, pass tables with no spaces"
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
            return make_error("safe_set requires and id")
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
    "safe_set <key|path> <data> <id>  --  stores data only if the existing data's id matches the id passed, pass tables with no spaces"
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
        if type(d) ~= "table" then
            return make_error("data at path " .. cmd.path .. " isnt a table")
        end
        d[#d + 1] = textutils.unserialise(cmd.data)
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
        if type(d) ~= "table" then
            return make_error("data at path " .. cmd.path .. " isnt a table")
        end
        table.insert(d, 1, textutils.unserialise(cmd.data))
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

local try_do_command = function(state, str)
    if type(str) ~= "string" then
        return make_error("pass commands as a string, do list_cmd to see available commands")
    end
    local cmd = {}
    local i = 1
    for w in string.gmatch(str, "%S+") do
        cmd[i] = w
        i = i + 1
    end
    if not cmd[1] then
        return make_error("do list_cmd to see available commands")
    end
    if not commands[cmd[1]] then
        return make_error("command not recognized. Do list_cmd to see available commands")
    end
    return commands[cmd[1]].cmd({ state = state, path = cmd[2], data = cmd[3], id = cmd[4] })
end

return {
    commands = commands.list_cmd.cmd().data,
    new_command_runner = function(state)
        return function(str)
            return try_do_command(state, str)
        end
    end
}
