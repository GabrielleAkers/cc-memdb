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
                        data = {}
                    }
                    state[parsed_for_id].runner = c.new_command_runner(state[parsed_for_id].data)
                end
            else
                print("got", "'" .. p3 .. "'", "on channel", ch, "from", dist, "blocks away")
                local res = state[connections[id].client_id].runner(p3)
                connections[id].conn:send(textutils.serialize(res))
                connections[id].last_msg_time = os.epoch("utc")
            end
        end
    end
end

local handle_timeout = function()
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

parallel.waitForAny(main, ecnet2.daemon, handle_timeout)
