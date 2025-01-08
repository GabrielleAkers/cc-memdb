local shared = require("shared")
local commands = shared.commands

local ecnet2 = require("ecnet2")

shared.init_random()

ecnet2.open("top")

local id = ecnet2.Identity("/.ecnet2")

local memdb = id:Protocol {
    name = "memdb",
    serialize = textutils.serialize,
    deserialize = textutils.unserialize,
}

local server = "tOAiD4vaW0MwpOxYnriAUcoW7lEhGgt7P7cUo9QgUSs="

local main = function()
    local connection = memdb:connect(server, "top")

    print(select(2, connection:receive()))

    while true do
        connection:send(read())
        local r = textutils.unserialize(select(2, connection:receive()))
        if r.error then
            print("ERROR", r.error)
        elseif r.data and type(r.data) ~= "boolean" then
            print("VALUE", textutils.serialize(r.data))
        end
    end
end

parallel.waitForAny(main, ecnet2.daemon)
