local JSONCompressor = { }
local require = require(game.ReplicatedStorage:WaitForChild('Infinity'))
local LibDeflate = require('$LibDeflate')
local httpService = game:GetService('HttpService')

---Converts a table to JSON and compresses it with LibDeflate.
---
---Returns nil if either LibDeflate or JSONEncode fail.
---@param content table Dictionary ***or*** array content to JSONify.
---@param level number? Optional compression level. (0 = no compression, 9 = maximum compression) **[default=5]**
---@meta
function JSONCompressor:Deflate(content: {}, level: number?): string|nil
    level = level or 5
    
    local json = httpService:JSONEncode(content)
    local result
    
    if json then
        result = LibDeflate:CompressDeflate(json, { level = level })
        result = LibDeflate:EncodeForPrint(result)
    end
    
    return result
end

---Decompresses a deflated JSON string and decodes it back to a table.
---
---Returns nil if either LibDeflate or JSONDencode fail.
---@param deflatedContent string The deflated JSON string.
---@meta
function JSONCompressor:Inflate(deflatedContent: string): string|nil
    local decoded = LibDeflate:DecodeForPrint(deflatedContent)
    local result
    
    if decoded then
        result = LibDeflate:DecompressDeflate(decoded)
        result = httpService:JSONDecode(result)
    end
    
    return result
end

return JSONCompressor