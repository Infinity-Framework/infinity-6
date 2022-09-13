--[[
    File: EasyGet.lua
    Author(s): FriendlyBiscuit
    Created: 09/12/2022 @ 19:26:41
--]]

---Deep-searches descendants of an instance to fetch an object by name.
---Returns `nil` if no instance of that name is immediately found.
---@param root Instance The root instance to search.
---@param query string The name of the object you want to search for. Case sensitive.
---@meta
return function(root: Instance, query: string): Instance|nil
    for _, descendant in root:GetDescendants() do
        if descendant.Name == query then
            return descendant
        end
    end
    
    return nil
end