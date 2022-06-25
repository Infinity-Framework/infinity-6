--[[
    File: Infinity.lua
    Author(s): doctr_oof and mada-r
    Created: 06/25/2022 @ 15:05:22
    
    Description:
        Main Infinity 6.0+ module loader.
--]]

--= Dependencies =--
local Promise           = require(script:WaitForChild('Promise'))

--= Roblox Services =--
local runService        = game:GetService('RunService')
local starterService    = game:GetService('StarterPlayer')
local playerService     = game:GetService('Players')
local serverService     = game:GetService('ServerScriptService')

--= Constants =--
local LOADER_VER        = '6.0.0alpha'
local FETCH_TIMEOUT     = 0.25
local ERROR_TEMPLATE    = ('$REP\n  [InfinityLoader] %s\n  $REP'):gsub('%$REP', string.rep('-', 40))
local PREFIX_PATHS      = {
    ['%$'] = game.ReplicatedStorage:WaitForChild('InfinityShared')
}
local MESSAGES          = {
    REQUIRE_ERROR = 'Failed to require %q - the target module errored. See above for error details.',
    PATH_NODE_NOT_FOUND = 'Failed to require path %q - node %q not found.',
    PATH_NOT_A_MODULE = 'Failed to require path %q - final node %q is not a ModuleScript.',
    NOPATH_NOT_A_MODULE = 'Failed to no-path require %q - %q is not a ModuleScript.',
    NOPATH_NOT_FOUND = 'Failed to no-path require %q - no module with that name found in the specified context.'
}

--= Variables =--
local moduleCache       = { }

--= Functions =--
local function _warn(template: string, ...: any)
    warn(ERROR_TEMPLATE:format(template:format(...)))
end

local function _splitPathIntoNodes(path: string): {string}
    local result = { }
    
    for match in path:gmatch('([^/]+)') do
        table.insert(result, match)
    end
    
    return result
end

local function _getContext(firstNode: string): (Instance|nil, number)
    local fixLength = 0
    local context
    
    for prefix, target in (PREFIX_PATHS) do
        if firstNode:find(prefix) == 1 then
            context = target
            fixLength = #prefix
        end
    end
    
    if not context then
        if not runService:IsRunning() then
            context = starterService.StarterPlayerScripts
        elseif runService:IsClient() then
            context = playerService.LocalPlayer:WaitForChild('PlayerScripts'):WaitForChild('InfinityClient')
        else
            context = serverService:WaitForChild('InfinityServer')
        end
    end
    
    return context, fixLength
end

local function _getDescendant(root: Instance, query: string): Instance|nil
    for _, descendant in (root:GetDescendants()) do
        if not descendant:IsA('Folder') and descendant.Name == query then
            return descendant
        end
    end
    
    return nil
end

local function _fetchDescendantTimeout(root: Instance, query: string): Instance|nil
    local result = _getDescendant(root, query)
    
    if not result then
        local startTime = tick()
        
        while not result do
            result = _getDescendant(root, query)
            if result or (tick() - startTime >= FETCH_TIMEOUT) then break end
            task.wait()
        end
    end
    
    return result
end

local function _promiseRequire(targetModule: ModuleScript): any
    local result
    
    Promise.new(function(resolve: (any) -> ())
        local data = require(targetModule)
        
        if data then
            resolve(data)
        end
    end):andThen(function(moduleData: any)
        result = moduleData
    end):catch(function()
        _warn(MESSAGES.REQUIRE_ERROR, targetModule.Name)
    end):await()
    
    return result
end

--= Main Loader Function =--
return function (query: string|ModuleScript): any
    if type(query) == 'string' then
        if moduleCache[query] ~= nil then
            return moduleCache[query]
        end
        
        local nodes = _splitPathIntoNodes(query)
        local root, fixLength = _getContext(nodes[1])
        local targetModule
        local result
        
        if fixLength > 0 then
            nodes[1] = nodes[1]:sub(fixLength)
        end
        
        if #nodes > 1 then
            for index = 1, #nodes do
                local node = nodes[index]
                
                if not targetModule then
                    targetModule = root:WaitForChild(node, FETCH_TIMEOUT)
                else
                    targetModule = targetModule:WaitForChild(node, FETCH_TIMEOUT)
                end
                
                if not targetModule then
                    _warn(MESSAGES.PATH_NODE_NOT_FOUND, query, node)
                    return nil
                end
            end
            
            if targetModule:IsA('ModuleScript') then
                result = _promiseRequire(targetModule)
            else
                _warn(MESSAGES.PATH_NOT_A_MODULE, query, nodes[#nodes])
            end
        else
            targetModule = _fetchDescendantTimeout(root, nodes[1])
            
            if targetModule then
                if targetModule:IsA('ModuleScript') then
                    result = _promiseRequire(targetModule)
                else
                    _warn(MESSAGES.NOPATH_NOT_A_MODULE, query, nodes[#nodes])
                end
            else
                _warn(MESSAGES.NOPATH_NOT_FOUND, query)
            end
        end
        
        if result ~= nil then
            moduleCache[query] = result
        end
        
        return result
    else
        return require(query)
    end
end