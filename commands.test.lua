local state = {}

local try_do = require("commands").new_command_runner(state)

local tests = {
    unrecognized_cmd = try_do("fakecmd").error ~= nil,
    nil_cmd = try_do(nil).error ~= nil,
    get_no_key = try_do("get").error ~= nil,
    set_no_key = try_do("set").error ~= nil,
    set_no_val = try_do("set a").error ~= nil,
    set_val = try_do("set a 1").data ~= nil,
    get_val = try_do("get a").data == 1,
    get_id = try_do("get_id a").data ~= nil,
    safe_set_fakeid = not try_do("safe_set a 2 fake_id").data ~= nil,
    safe_set = try_do("safe_set a 2 " .. try_do("get_id a").data).data ~= nil,
    set_path = try_do("set b.c.d 4").data ~= nil,
    get_path = try_do("get b.c.d").data == 4,
    set_path_table = try_do("set b.c.d {e=false}").data ~= nil,
    get_path_table = type(try_do("get b.c.d").data) == "table",
    get_path_table_value = try_do("get b.c.d.e").data == false,
    del_path = try_do("del b.c.d").data == true,
    get_deleted_path_false = not try_do("get b.c.d").data ~= nil,
    del_path_not_exists = not try_do("del b.c.d").data ~= nil,
    append_no_key = try_do("append").error ~= nil,
    append_nil = try_do("append a").error ~= nil,
    append_not_table = (function()
        try_do("set a 2")
        return try_do("append a 3").error ~= nil
    end)(),
    append_val = (function()
        try_do("set a {}")
        local r1 = try_do("append a 1").data
        local r2 = try_do("append a 2").data
        return r1 and r2 and state.a[1] == 1 and state.a[2] == 2
    end)(),
    append_path_val = (function()
        try_do("set a.b {}")
        local r1 = try_do("append a.b 1")
        local r2 = try_do("append a.b 2")
        return r1.data and r2.data and state.a.b[1] == 1 and state.a.b[2] == 2
    end)(),
    prepend_no_key = try_do("prepend").error ~= nil,
    prepend_nil = try_do("prepend a").error ~= nil,
    prepend_not_table = (function()
        try_do("set a 2")
        return try_do("prepend a 3").error ~= nil
    end)(),
    prepend_val = (function()
        try_do("set a {}")
        local r1 = try_do("prepend a 1").data ~= nil
        local r2 = try_do("prepend a 2").data ~= nil
        return r1 and r2 and state.a[1] == 2 and state.a[2] == 1
    end)(),
    prepend_path_val = (function()
        try_do("set a.b {}")
        local r1 = try_do("prepend a.b 1")
        local r2 = try_do("prepend a.b 2")
        return r1.data ~= nil and r2.data ~= nil and state.a.b[1] == 2 and state.a.b[2] == 1
    end)(),
    incr_nil = try_do("incr").error ~= nil,
    incr_nonnumber = (function()
        try_do("set a {}")
        return try_do("incr a 1").error ~= nil
    end)(),
    incr_negative = (function()
        try_do("set a 1")
        return try_do("incr a -1").error ~= nil
    end)(),
    incr_val = (function()
        try_do("set a 1")
        try_do("incr a 1")
        return state.a == 2
    end)(),
    decr_nil = try_do("decr").error ~= nil,
    decr_nonnumber = (function()
        try_do("set a {}")
        return try_do("decr a 1").error ~= nil
    end)(),
    decr_negative = (function()
        try_do("set a 1")
        return try_do("decr a -1").error ~= nil
    end)(),
    decr_val = (function()
        try_do("set a 1")
        try_do("decr a 1")
        return state.a == 0
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
