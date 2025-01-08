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
                last_msg_time = os.epoch("utc")
            }
            state[connection.id] = {
                data = {}
            }
            state[connection.id].runner = c.new_command_runner(state[connection.id].data)
        elseif event == "ecnet2_message" and connections[id].conn then
            print("got", p3, "on channel", ch, "from", dist, "blocks away")
            local res = state[id].runner(p3)
            connections[id].conn:send(textutils.serialize(res))
            connections[id].last_msg_time = os.epoch("utc")
        end
    end
end

local handle_timeout = function()
    while true do
        for k, v in pairs(connections) do
            if (os.epoch("utc") - v.last_msg_time) / 1000 > connection_timeout then
                connections[k] = nil
                state[k] = nil
            end
        end
        os.sleep(1)
    end
end

parallel.waitForAny(main, ecnet2.daemon, handle_timeout)
