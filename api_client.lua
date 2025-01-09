-- for programatic interaction with the api
local shared = require("shared")

local ecnet2 = require("ecnet2")

--- @class memdbclient
--- @field list_cmd fun(): {data: string} get a list of available commands
--- @field help fun(command: "list_cmd"|"help"|"get"|"set"|"get_id"|"safe_set"|"append"|"prepend"|"incr"|"decr"|"del"): {data: string} get help with a specific function
--- @field get fun(path: string): {data: any}|{error: string} get a stored value
--- @field set fun(path: string, val: any, lifetime?: number): {data: boolean}|{error: string} set a stored value, creating it if it doesnt exist
--- @field get_id fun(path: string): {data: string}|{error: string} get a unique id for the value stored at that path, used with safe_set
--- @field safe_set fun(path: string, val: any, id: string, lifetime?: number): {data: boolean}|{error: string} set a stored value, pass an id from get_id to prevent overwriting the value if it was changed since you fetched the id
--- @field append fun(path: string, val: any, lifetime?: number): {data: boolean}|{error: string} appends to a stored list or string
--- @field prepend fun(path: string, val: any, lifetime?: number): {data: boolean}|{error: string} prepends to a stored list or string
--- @field incr fun(path: string, val: any, lifetime?: number): {data: boolean}|{error: string} increments a stored number
--- @field decr fun(path: string, val: any, lifetime?: number): {data: boolean}|{error: string} decrements a stored number
--- @field del fun(path: string): {data: boolean}|{error: string} delete a stored value

--- create a new memdb client
--- @param server string the address of the server to communicate with
--- @param client_id string an id for this client, this should be kept secret and not easily guessable -- clients with the same id share state
--- @param request_timeout number the amount of time in seconds to wait before timing out when receiving a server response
--- @return memdbclient client configured memdb client
local new_client = function(server, client_id, request_timeout)
    local client = {
        _server = server,
        _client_id = client_id,
        _connection = nil,
        _timeout = request_timeout
    }

    client._do_network_action = function(action)
        local collected_result = nil
        local time_start = os.epoch("utc")
        local main = function()
            shared.init_random()

            ecnet2.open("top")

            local id = ecnet2.Identity("/.ecnet2")

            local memdb = id:Protocol {
                name = "memdb",
                serialize = textutils.serialize,
                deserialize = textutils.unserialize,
            }

            client._connection = memdb:connect(server, "top")
            client._connection:receive(client._timeout) -- yield to let the daemon process

            client._connection:send("client_id=" .. client_id)
            client._connection:receive(client._timeout) -- yield to let the daemon process and to clear the queue

            collected_result = action()
        end

        while not collected_result and (os.epoch("utc") - time_start) / 1000 < client._timeout do
            parallel.waitForAny(main, ecnet2.daemon)
        end
        if not collected_result then
            error("request timed out")
        end
        return collected_result
    end

    local _build_command_str = function(cmd)
        if cmd.id then -- special handling for safe_set
            return (cmd.cmd or "") ..
                " " ..
                (cmd.path or "") ..
                (cmd.val and (" " .. (cmd.val .. " " .. cmd.id .. " " .. (cmd.lifetime or ""))))
        end
        return (cmd.cmd or "") ..
            " " ..
            (cmd.path or "") ..
            (cmd.val and ((" " .. cmd.val .. (cmd.lifetime and " " .. cmd.lifetime or ""))) or "")
    end

    client._send_memdb_cmd = function(cmd, path, val, lifetime, id)
        return client._do_network_action(function()
            if not client._connection then
                error("client not connected")
            end
            client._connection:send(_build_command_str({
                cmd = cmd,
                path = path,
                val = val,
                lifetime = lifetime,
                id = id
            }))
            return textutils.unserialize(select(2, client._connection:receive(client._timeout)))
        end)
    end

    client.list_cmd = function()
        return client._send_memdb_cmd("list_cmd")
    end

    client.help = function(command)
        return client._send_memdb_cmd("help", command)
    end

    client.get = function(path)
        return client._send_memdb_cmd("get", path)
    end

    local _setter = function(cmd)
        return function(path, val, lifetime, id)
            local is_table = (type(val) == "table")
            return client._send_memdb_cmd(cmd, path, textutils.serialize(val, { compact = is_table }), lifetime, id)
        end
    end

    client.set = _setter("set")

    client.get_id = function(path)
        return client._send_memdb_cmd("get_id", path)
    end

    client.safe_set = _setter("safe_set")

    client.append = _setter("append")

    client.prepend = _setter("prepend")

    client.incr = _setter("incr")

    client.decr = _setter("decr")

    client.del = function(path)
        return client._send_memdb_cmd("del", path)
    end

    return client
end

return {
    new_client = new_client
}
