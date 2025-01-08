-- borrowed from Basalt https://basalt.madefor.cc/install.lua
-- this file can download the project or other tools from github

local installer = { printStatus = true }
installer.githubPath = "https://raw.githubusercontent.com/GabrielleAkers/cc-memdb/"

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
                        url = installer.githubPath .. branch .. "/" .. filePath,
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

function installer.getProjectFiles(branch, ignoreList)
    local projTree = installer.createTree("https://api.github.com/repos/GabrielleAkers/cc-memdb/git/trees/" ..
        branch, branch, "", ignoreList)
    local project = {}

    local function downloadFile(url, path)
        if not url then
            return
        end
        project[path] = installer.get(url)
    end

    local fList = {}
    local delay = 0
    for k, v in pairs(projTree) do
        if (type(k) == "string") then
            for a, b in pairs(v) do
                table.insert(fList, function()
                    sleep(delay)
                    downloadFile(b.url, b.path)
                end)
                delay = delay + 0.05
            end
        else
            table.insert(fList, function()
                sleep(delay)
                downloadFile(v.url, v.path)
            end)
            delay = delay + 0.05
        end
    end
    parallel.waitForAll(table.unpack(fList))

    return project
end

function installer.downloadProject(projectDir, branch, ignoreList)
    if (fs.exists(projectDir)) then error("A folder called " .. projectDir .. " already exists!") end
    projectDir = projectDir or "memdb"
    branch = branch or "master"
    local projectFiles = installer.getProjectFiles(branch, ignoreList)
    fs.makeDir(projectDir)
    for k, v in pairs(projectFiles) do
        local f = fs.open(fs.combine(projectDir, k), "w")
        f.write(v)
        f.close()
    end
    printStatus("Source version successfully downloaded!")
end

installer.downloadProject("memdb", "main", nil)

return installer
