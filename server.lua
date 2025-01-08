local shared = require("shared")
local ecnet2 = require("ecnet2")
local c = require("commands")

shared.init_random()

ecnet2.open("top")

local id = ecnet2.Identity("/.ecnet2")

local memdb = id:Protocol {
    name = "memdb",
    serialize = textutils.serialize,
    deserialize = textutils.unserialize,
}

local listener = memdb:listen()

local connections = {}

local state = {}

local connection_timeout = 3600 -- seconds

local main = function()
    print("Listening on", id.address)
    while true do
        local event, id, p2, p3, ch, dist = os.pullEvent()
        if event == "ecnet2_request" and id == listener.id then
            local connection = listener:accept("memdb connection established", p2)
            connections[connection.id] = {
                conn = connection,
                last_msg_time = os.epoch("utc"),
            }
        elseif event == "ecnet2_message" and connections[id].conn then
            local parsed_for_id = string.gmatch(p3, "client_id=(%w+)")()
            if parsed_for_id then
                connections[id].client_id = parsed_for_id
                connections[id].conn:send("ok")
                if not state[parsed_for_id] then
                    state[parsed_for_id] = {
                        data = {},
                        lifetimes = {}
                    }
                    state[parsed_for_id].runner = c.new_command_runner(state[parsed_for_id].data,
                        state[parsed_for_id].lifetimes)
                end
            else
                print("got", "'" .. p3 .. "'", "on channel", ch, "from", dist, "blocks away")
                connections[id].last_msg_time = os.epoch("utc")
                local res = state[connections[id].client_id].runner(p3)
                connections[id].conn:send(textutils.serialize(res))
            end
        end
    end
end

local handle_cache_invalidation = function()
    while true do
        for _, client_state in pairs(state) do
            for path, lifetime in pairs(client_state.lifetimes) do
                -- never expire for 0 duration
                if lifetime.duration == 0 or not lifetime.duration then
                    goto continue
                end
                -- duration greater than a month is considered an epoch timestamp in seconds
                if lifetime.duration > 60 * 60 * 24 * 30 then
                    if os.epoch("utc") / 1000 >= lifetime.duration then
                        client_state.runner("del " .. path)
                        client_state.lifetimes[path] = nil
                    end
                elseif (os.epoch("utc") - lifetime.set_at) / 1000 >= lifetime.duration then
                    client_state.runner("del " .. path)
                    client_state.lifetimes[path] = nil
                end
                ::continue::
            end
        end
        os.sleep(1)
    end
end

local handle_connection_timeout = function()
    while true do
        for k, v in pairs(connections) do
            if (os.epoch("utc") - v.last_msg_time) / 1000 > connection_timeout then
                state[v.client_id] = nil
                connections[k] = nil
            end
        end
        os.sleep(1)
    end
end

local run_server = function()
    while true do
        parallel.waitForAny(main, ecnet2.daemon, handle_connection_timeout, handle_cache_invalidation)
    end
end

if pcall(debug.getlocal, 4, 1) then
    return {
        run_server = run_server
    }
else
    run_server()
end
