-- borrowed from Basalt: https://basalt.madefor.cc/install.lua
-- this file can download the project or other tools from github

local args = table.pack(...)
local installer = { printStatus = true }
installer.githubPath = "https://raw.githubusercontent.com/GabrielleAkers/cc-memdb/"

local projectContentStart =
[[
local project = {}
local packaged = true
local baseRequire = require
local require = function(path)
    for k,v in pairs(project)do
        if(type(v)=="table")then
            for name,b in pairs(v)do
                if(name==path)then
                    return b()
                end
            end
        else
            if(k==path)then
                return v()
            end
        end
    end
    return baseRequire(path);
end
local getProject = function(subDir)
    if(subDir~=nil)then
        return project[subDir]
    end
    return project
end
]]

local projectContentEnd = '\nreturn project["main"]()'

local function split(s, delimiter)
    local result = {}
    if (s ~= nil) then
        for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
            table.insert(result, match)
        end
    end
    return result
end

local function isInIgnoreList(file, ignList)
    if (ignList ~= nil) then
        local filePathParts = split(file, "/")
        for k, v in pairs(ignList) do
            if (v == filePathParts[1]) then
                return true
            end
        end
    end
    return false
end

local function printStatus(...)
    if (type(installer.printStatus) == "function") then
        installer.printStatus(...)
    elseif (installer.printStatus) then
        print(...)
    end
end

function installer.get(url)
    local httpReq = http.get(url, _G._GIT_API_KEY and { Authorization = "token " .. _G._GIT_API_KEY })
    printStatus("Downloading " .. url)
    if (httpReq ~= nil) then
        local content = httpReq.readAll()
        if not content then
            error("Could not connect to website")
        end
        return content
    end
end

-- Creates a filetree based on my github project, ofc you can use this in your projects if you'd like to
function installer.createTree(page, branch, dirName, ignList)
    ignList = ignList or {}
    dirName = dirName or ""
    printStatus("Receiving file tree for " .. (dirName ~= "" and "cc-memdb/" .. dirName or "cc-memdb"))
    local tree = {}
    local request = http.get(page, _G._GIT_API_KEY and { Authorization = "token " .. _G._GIT_API_KEY })
    if not (page) then return end
    if (request == nil) then error("API rate limit exceeded. It will be available again in one hour.") end
    for _, v in pairs(textutils.unserialiseJSON(request.readAll()).tree) do
        if (v.type == "blob") then
            local filePath = fs.combine(dirName, v.path)
            if not isInIgnoreList(filePath, ignList) then
                table.insert(tree,
                    {
                        name = v.path,
                        path = filePath,
                        url = installer.githubPath .. branch .. "/cc-memdb/" .. filePath,
                        size =
                            v.size
                    })
            end
        elseif (v.type == "tree") then
            local dirPath = fs.combine(dirName, v.path)
            if not isInIgnoreList(dirPath, ignList) then
                tree[v.path] = installer.createTree(v.url, branch, dirPath)
            end
        end
    end
    return tree
end

function installer.createIgnoreList(str)
    local files = split(str, ":")
    local ignList = {}
    for k, v in pairs(files) do
        local a = split(v, "/")
        if (#a > 1) then
            if (ignList[a[1]] == nil) then ignList[a[1]] = {} end
            table.insert(ignList[a[1]], a[2])
        else
            table.insert(ignList, v)
        end
    end
end

function installer.getPackedProject(branch, ignoreList)
    if (ignoreList == nil) then
        ignoreList = { "init.lua" }
    else
        table.insert(ignoreList, "init.lua")
    end
    local projTree = installer.createTree("https://api.github.com/repos/GabrielleAkers/cc-memdb/git/trees/" ..
        branch .. ":cc-memdb", branch, "", ignoreList)
    local project = {}

    local fList = {}
    local delay = 0
    for k, v in pairs(projTree) do
        if (type(k) == "string") then
            for a, b in pairs(v) do
                table.insert(fList, function()
                    sleep(delay)
                    if (project[k] == nil) then project[k] = {} end
                    table.insert(project[k],
                        { content = installer.get(b.url), name = b.name, path = b.path, size = b.size, url = b.url })
                    delay = delay + 0.05
                end)
            end
        else
            table.insert(fList,
                function()
                    sleep(delay)
                    table.insert(project,
                        { content = installer.get(v.url), name = v.name, path = v.path, size = v.size, url = v.url })
                    delay = delay + 0.05
                end)
        end
    end

    parallel.waitForAll(table.unpack(fList))

    local projectContent = projectContentStart

    for k, v in pairs(project) do
        if (type(k) == "string") then
            local newSubDir = 'project["' .. k .. '"] = {}\n'
            projectContent = projectContent .. "\n" .. newSubDir
            for a, b in pairs(v) do
                local newFile = 'project["' ..
                    k .. '"]["' .. b.name:gsub(".lua", "") .. '"] = function(...)\n' .. b.content .. '\nend'
                projectContent = projectContent .. "\n" .. newFile
            end
        else
            local newFile = 'project["' .. v.name:gsub(".lua", "") .. '"] = function(...)\n' .. v.content .. '\nend'
            projectContent = projectContent .. "\n" .. newFile
        end
    end
    projectContent = projectContent .. projectContentEnd

    return projectContent
end

function installer.downloadPacked(filename, branch, ignoreList, minify)
    if (fs.exists(filename)) then error("A file called " .. filename .. " already exists!") end
    local projectContent = installer.getPackedProject(branch, ignoreList)
    if (minify) then
        local min
        if (fs.exists("packager.lua")) then
            local f = fs.open("packager.lua", "r")
            min = load(f.readAll())()
            f.close()
        else
            min = load(installer.get(
                "https://raw.githubusercontent.com/GabrielleAkers/cc-memdb/master/docs/packager.lua"))()
        end
        if (min ~= nil) then
            local success, data = min(projectContent)
            if (success) then
                projectContent = data
            else
                error(data)
            end
        end
    end
    local f = fs.open(filename, "w")
    f.write(projectContent)
    f.close()
    printStatus("Packed version successfully downloaded!")
end

installer.downloadPacked(args[1] or "memdb.lua", args[2] or "master",
    args[3] ~= nil and installer.createIgnoreList(args[3]) or nil, args[4] == "false" and false or true)

return installer
