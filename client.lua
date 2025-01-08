local shared = require("shared")
local field = require("cc.expect").field

local ecnet2 = require("ecnet2")

shared.init_random()

ecnet2.open("top")

local id = ecnet2.Identity("/.ecnet2")

local memdb = id:Protocol {
    name = "memdb",
    serialize = textutils.serialize,
    deserialize = textutils.unserialize,
}

local p = shell.resolve("./.memdb.client.config")
if not fs.exists(p) then
    error("Cant find config file. Create ./.memdb.client.config with server and client_id fields")
end
local f = fs.open(p, "r")
local config = textutils.unserialize(f.readAll())
f.close()

field(config, "server", "string")
field(config, "client_id", "string")

local server = config.server
local client_id = config.client_id

local main = function()
    local connection = memdb:connect(server, "top")

    print(select(2, connection:receive()))

    connection:send("client_id=" .. client_id)

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
