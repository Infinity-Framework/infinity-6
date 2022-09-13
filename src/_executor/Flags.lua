local runService = game:GetService('RunService')

return {
    IS_STUDIO = runService:IsStudio();
    DEVELOPER_MODE = false;
    
    -- InfinityExecutor Flags
    EXEC_VERBOSE_OUTPUT = false;
}