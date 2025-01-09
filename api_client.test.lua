local field = require("cc.expect").field

local state = {
    data = {},
    lifetimes = {}
}

local p = shell.resolve("./.memdb.clienttest.config")
if not fs.exists(p) then
    error("Cant find config file. Create ./.memdb.clienttest.config with server and client_id fields")
end
local f = fs.open(p, "r")
local config = textutils.unserialize(f.readAll())
f.close()

field(config, "server", "string")
field(config, "client_id", "string")

local client = require("api_client").new_client(config.server, config.client_id, 10)

local tests = {
    client_setget = (function()
        local r1 = client.set("a", 1).data
        local r2 = client.get("a").data == 1
        return r1 and r2
    end)(),
    client_listcmd = (function()
        local r1 = client.list_cmd().data
        return type(r1) == "table" and #r1 > 0
    end)(),
    client_help_get = (function()
        return client.help("get").data == "get <key|path>"
    end)(),
    client_appendlist = (function()
        client.set("mylist", { 1 })
        local r1 = client.append("mylist", 2).data
        local v = client.get("mylist").data
        local r2 = (v[1] == 1 and v[2] == 2)
        return r1 and r2
    end)(),
    client_appendstr = (function()
        client.set("mystr", "'hello'")
        local r1 = client.get("mystr").data == "hello"
        client.append("mystr", "' world'")
        local r2 = client.get("mystr").data == "hello world"
        return r1 and r2
    end)(),
    client_prependstr = (function()
        client.set("myprepstr", "' world'")
        local r1 = client.get("myprepstr").data == " world"
        client.prepend("myprepstr", "'hello'")
        local r2 = client.get("myprepstr").data == "hello world"
        return r1 and r2
    end)(),
    client_prependlist = (function()
        client.set("mylist1", { 1 })
        local r1 = client.prepend("mylist1", 2).data
        local v = client.get("mylist1").data
        local r2 = (v[1] == 2 and v[2] == 1)
        return r1 and r2
    end)(),
    client_incr = (function()
        client.set("mynum", 0)
        local r1 = client.get("mynum").data == 0
        client.incr("mynum", 1.2)
        local r2 = client.get("mynum").data == 1.2
        return r1 and r2
    end)(),
    client_decr = (function()
        client.set("mynum", 0)
        local r1 = client.get("mynum").data == 0
        client.decr("mynum", 1.2)
        local r2 = client.get("mynum").data == -1.2
        return r1 and r2
    end)(),
    client_del = (function()
        client.set("todelete", "'my value'")
        local r1 = client.get("todelete").data == "my value"
        client.del("todelete")
        local r2 = client.get("todelete").error ~= nil
        return r1 and r2
    end)(),
    client_safeset = (function()
        client.set("k", 1)
        local id = client.get_id("k").data
        client.set("k", 2)
        client.safe_set("k", 3, id)
        return client.get("k").data == 2
    end)()
}

local res = {}
for k, w in pairs(tests) do
    local f = function()
        return assert(w)
    end
    local r, e = pcall(f)
    if not r then
        res[k] = e
    end
end

local err_count = 0
for _, _ in pairs(res) do
    err_count = err_count + 1
end
if err_count == 0 then
    print("tests ran without error")
    return 0
else
    print("tests ran with errors")
    print("---------------------")
    print(textutils.serialise(res))
    return 1
end
