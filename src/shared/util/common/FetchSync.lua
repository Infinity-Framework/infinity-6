--[[
    File: FetchSync.lua
    Author(s): FriendlyBiscuit
    Created: 09/12/2022 @ 19:34:50
--]]

local runService = game:GetService('RunService')

local function _warn(message: string, ...)
    warn(('[FetchSync] %s'):format(message:format(...)))
end

---Deep-searches descendants of an instance to fetch an object by name.
---Will wait indefinitely (or a specified amount of time) for the object to appear.
---@param root Instance The root instance to search.
---@param query string The name of the object you want to search for. Case sensitive.
---@param timeout number? Optional timeout. If specified, this function will return `nil` if the timeout is exceeded. **[default=infinite]**
---@meta
return function(root: Instance, query: string, timeout: number?): Instance|nil
    if timeout == 0 then
        _warn('You must specify a timeout that is greater than 0.')
        return nil
    end
    
    local descendants = root:GetDescendants()
    local warned = false
    local elapsed = 0
    local result
    
    while not result do
        for _, descendant in descendants do
            if descendant.Name == query then
                return descendant
            end
        end
        
        local _, delta = runService.Stepped:Wait()
        elapsed += delta
        
        if timeout then
            timeout -= delta
            
            if timeout <= 0 then
                _warn('Failed to fetch %q - timeout exceeded.', query)
                break
            end
        else
            if elapsed >= 5 and not warned then
                _warn('Infinite yield detected while fetching %q - is the object present?', query)
                warned = true
            end
        end
        
        descendants = root:GetDescendants()
    end
    
    return result
end