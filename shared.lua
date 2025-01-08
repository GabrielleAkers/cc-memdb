package.path = package.path .. ";/memdb/?.lua;/disk/?.lua"

local commands = require("commands")
local random = require("ccryptolib.random")

local _port = 25678
local _ip = 123456

local set_port = function(port)
    _port = port
end

local set_ip = function(ip)
    _ip = ip
end

local init_random = function()
    local res = http.get("https://www.uuidgenerator.net/api/version4")
    local data = res.readAll()
    res.close()
    random.init(data)
end

return {
    port = _port,
    set_port = set_port,
    ip = _ip,
    set_ip = set_ip,
    init_random = init_random,
    commands = commands
}
