--[[
    File: InfinityExecutor.lua
    Author(s): FriendlyBiscuit
    Created: 07/21/2022 @ 14:29:33
    
    Description:
        Main Infinity Executor module.
--]]

--= Infinity Module Loader =--
local require = shared

--= Root =--
local InfinityExecutor = { }

--= Dependencies =--
local Promise = require('$Promise')
local flags = require(script:WaitForChild('Flags'))

--= Roblox Services =--
local runService = game:GetService('RunService')

--= Object References =--
local defaultMembers = script:WaitForChild('DefaultCallbacks')

--= Constants =--
local VERBOSE_OUTPUT = flags.EXEC_VERBOSE_OUTPUT
local EXECUTOR_VER = '6.0.1'
local PROMISE_TYPE = { NONE = 'None', YIELD = 'Yield', ASYNC = 'Async' }
local BEGIN_ERR_STR = '-------- BEGIN ERROR --------'
local END_ERR_STR = '--------- END ERROR ---------'
local ERROR_TEMPLATE = ('%s\n\n  [InfinityExecutor:%%s] %%s\n  %s'):format(BEGIN_ERR_STR, END_ERR_STR)
local STRIPPED_TOPICS = { 'Infinity.Promise', 'InfinityExecutor' }
local MESSAGES = {
    NOT_FAST_ENOUGH = '%s\'s ::Immediate() callback ran too slow.\n  This function should run instantly; check for yields.\n';
    JOB_ERROR = '%s\'s ::%s() callback errored during execution. Stack Trace:\n%s';
}

--= Variables =--
local preloadedMembers = { }

--= Functions =--
local function _getContextString(): string
    if runService:IsClient() then
        return 'Client'
    elseif runService:IsServer() then
        return 'Server'
    end
    
    return 'null'
end

local function _stripTopics(query: string): string
    local split = string.split(query, '\n')
    local result = ''
    
    for index, line in split do
        for _, topic in STRIPPED_TOPICS do
            if not line or line:find(topic) then
                split[index] = nil
            end
        end
    end
    
    for _, str in split do
        if str and str ~= '' then
            result ..= '  ' .. str .. '\n'
        end
    end
    
    return result
end

local function _out(template: string, ...: any)
    if VERBOSE_OUTPUT then
        print(('[InfinityExecutor:%s]'):format(_getContextString()), template:format(...))
    end
end

local function _warn(template: string, ...: any)
    warn(ERROR_TEMPLATE:format(_getContextString(), template:format(...)))
end

local function _preloadDefaultMembers()
    if #preloadedMembers > 0 then return end
    
    for _, memberModule in defaultMembers:GetChildren() do
        local memberData = require(memberModule)
        
        if memberData.Preload then
            memberData:Preload()
        end
        
        for _, alias in memberData.Aliases do
            table.insert(preloadedMembers, {
                TrueName = memberModule.Name,
                Alias = alias,
                ExecutionOrder = memberData.ExecutionOrder,
                PromiseType = memberData.PromiseType,
                Handle = memberData.Handle
            })
        end
        
        _out('Preloaded default member %q with %d aliases', memberModule.Name, #memberData.Aliases)
    end
    
    table.sort(preloadedMembers, function(a: {}, b: {})
        return a.ExecutionOrder < b.ExecutionOrder
    end)
end

local function _lazyLoadFolder(root: Instance): {table}
    local result = { }
    
    local function recurse(object: Instance)
        for _, child in object:GetChildren() do
            if child:IsA('ModuleScript') then
                local moduleData = require(child)
                moduleData.__jobname = child.Name
                moduleData.FLAGS = flags
                
                if moduleData.Enabled == false then continue end
                
                if not moduleData.Priority then
                    moduleData.Priority = #result + 1
                end
                
                if moduleData.Immediate then
                    _out('Spinning up %s:%s() (no priority)', child.Name, 'Immediate')
                    
                    local routine = coroutine.create(moduleData.Immediate)
                    
                    coroutine.resume(routine)
                    
                    if coroutine.status(routine) ~= 'dead' then
                        _warn(MESSAGES.NOT_FAST_ENOUGH, moduleData.__jobname)
                    end
                end
                
                table.insert(result, moduleData)
            else
                recurse(child)
            end
        end
    end
    
    recurse(root)
    
    return result
end

local function _loadJobsFolder(target: Folder, allowedMembers: {string}?)
    local jobModules = _lazyLoadFolder(target)
    
    table.sort(jobModules, function(a: {}, b: {})
        if a.Priority and b.Priority then
            if a.Priority == b.Priority then
                b.Priority += 1
            end
            
            return a.Priority < b.Priority
        end
        
        return false
    end)
    
    for _, member in ipairs(preloadedMembers) do
        if allowedMembers and not table.find(allowedMembers, member.TrueName) then
            continue
        end
        
        for _, job in ipairs(jobModules) do
            local targetCallback = job[member.Alias]
            
            if targetCallback then
                _out('Spinning up %s:%s() (priority: %d)', job.__jobname, member.Alias, job.Priority)
                
                if member.PromiseType and member.PromiseType ~= PROMISE_TYPE.NONE then
                    local handlePromise = Promise.promisify(function()
                        member.Handle(job, targetCallback)
                    end)
                    
                    if member.PromiseType == PROMISE_TYPE.ASYNC then
                        handlePromise():catch(function(promiseError: {})
                            _warn(MESSAGES.JOB_ERROR, job.__jobname, member.Alias, _stripTopics(promiseError.trace))
                        end)
                    else
                        handlePromise():catch(function(promiseError: {})
                            _warn(MESSAGES.JOB_ERROR, job.__jobname, member.Alias, _stripTopics(promiseError.trace))
                        end):await()
                    end
                else
                    member.Handle(job, targetCallback)
                end
            end
        end
    end
end

--= API =--

---Searches for jobs in the specified `target` folder and executes them.
---
---Optionally accepts a list of allowed members that are recognized. If nil, all members under
---DefaultCallbacks will be respected.
---@param target Folder The target folder you wish to query for execution.
---@param allowedMembers? table List of default members that are respected during execution.
---@meta
function InfinityExecutor:ExecuteFolder(target: Folder, allowedMembers: {string}?)
    _out('Beginning execution of %s.%s...', target.Parent.Name, target.Name)
    
    local startTime = tick()
    _loadJobsFolder(target, allowedMembers)
    
    _out('Finished executing %s.%s. Time taken: %ss', target.Parent.Name, target.Name, tostring(tick() - startTime):sub(1, 6))
end

--= Preload and Return =--
_out('You are using Infinity Executor %s. Current context: %s', EXECUTOR_VER, _getContextString())
_preloadDefaultMembers()
return InfinityExecutor