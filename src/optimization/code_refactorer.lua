-- Code Refactoring for Nightfall Chess
-- Improves code quality, readability, and maintainability

local class = require("lib.middleclass.middleclass")

local CodeRefactorer = class("CodeRefactorer")

function CodeRefactorer:initialize(game)
    self.game = game
    
    -- Refactoring statistics
    self.stats = {
        filesRefactored = 0,
        functionsRefactored = 0,
        duplicateCodeRemoved = 0,
        complexityReduced = 0
    }
    
    -- Refactoring settings
    self.settings = {
        extractCommonFunctions = true,
        improveNaming = true,
        reduceNesting = true,
        addDocumentation = true,
        standardizeFormatting = true
    }
    
    -- Common patterns to extract
    self.commonPatterns = {
        -- Grid position validation
        gridValidation = {
            pattern = "x >= 1 and x <= grid.width and y >= 1 and y <= grid.height",
            replacement = "grid:isValidPosition(x, y)"
        },
        
        -- Distance calculation
        distanceCalculation = {
            pattern = "math.sqrt((x2 - x1)^2 + (y2 - y1)^2)",
            replacement = "calculateDistance(x1, y1, x2, y2)"
        },
        
        -- Random range
        randomRange = {
            pattern = "math.random() * (max - min) + min",
            replacement = "randomInRange(min, max)"
        }
    }
    
    -- Function naming improvements
    self.namingImprovements = {
        -- Unclear function names
        ["doStuff"] = "processGameLogic",
        ["handle"] = "handleUserInput",
        ["process"] = "processEntityUpdate",
        ["update2"] = "updateSecondarySystem",
        ["checkIt"] = "validateEntityState",
        
        -- Inconsistent naming
        ["addNewUnit"] = "addUnit",
        ["removeExistingUnit"] = "removeUnit",
        ["createNewItem"] = "createItem",
        ["deleteOldItem"] = "deleteItem"
    }
    
    -- Documentation templates
    self.documentationTemplates = {
        functionHeader = [[
-- %s
-- %s
-- Parameters:
%s
-- Returns:
-- %s
]],
        parameterLine = "--   %s: %s",
        classHeader = [[
-- %s
-- %s
-- 
-- Methods:
%s
]],
        methodLine = "--   %s: %s"
    }
end

-- Refactor a specific file
function CodeRefactorer:refactorFile(filePath)
    print("Refactoring file: " .. filePath)
    
    -- Read file content
    local file = io.open(filePath, "r")
    if not file then
        print("Error: Could not open file " .. filePath)
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Apply refactorings
    local newContent = content
    
    if self.settings.extractCommonFunctions then
        newContent = self:extractCommonPatterns(newContent)
    end
    
    if self.settings.improveNaming then
        newContent = self:improveNaming(newContent)
    end
    
    if self.settings.reduceNesting then
        newContent = self:reduceNesting(newContent)
    end
    
    if self.settings.addDocumentation then
        newContent = self:addDocumentation(newContent, filePath)
    end
    
    if self.settings.standardizeFormatting then
        newContent = self:standardizeFormatting(newContent)
    end
    
    -- Write back if changed
    if newContent ~= content then
        file = io.open(filePath, "w")
        if not file then
            print("Error: Could not write to file " .. filePath)
            return false
        end
        
        file:write(newContent)
        file:close()
        
        self.stats.filesRefactored = self.stats.filesRefactored + 1
        print("File refactored successfully: " .. filePath)
        return true
    else
        print("No changes needed for file: " .. filePath)
        return false
    end
end

-- Extract common patterns into functions
function CodeRefactorer:extractCommonPatterns(content)
    local newContent = content
    
    for name, pattern in pairs(self.commonPatterns) do
        -- Count occurrences
        local count = 0
        for _ in string.gmatch(newContent, pattern.pattern:gsub("([^%w])", "%%%1")) do
            count = count + 1
        end
        
        -- If pattern appears multiple times, extract it
        if count > 1 then
            -- Replace occurrences
            newContent = newContent:gsub(pattern.pattern:gsub("([^%w])", "%%%1"), pattern.replacement)
            
            -- Add function definition if not already present
            if not newContent:find("function " .. pattern.replacement:match("^([^(]+)")) then
                local functionDef
                
                if name == "gridValidation" then
                    functionDef = [[
function Grid:isValidPosition(x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end
]]
                elseif name == "distanceCalculation" then
                    functionDef = [[
function calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end
]]
                elseif name == "randomRange" then
                    functionDef = [[
function randomInRange(min, max)
    return math.random() * (max - min) + min
end
]]
                end
                
                if functionDef then
                    -- Find a good place to insert the function
                    local insertPos = newContent:find("return [%w_]+$")
                    if insertPos then
                        newContent = newContent:sub(1, insertPos - 1) .. functionDef .. "\n" .. newContent:sub(insertPos)
                    else
                        newContent = newContent .. "\n" .. functionDef
                    end
                    
                    self.stats.functionsRefactored = self.stats.functionsRefactored + 1
                    self.stats.duplicateCodeRemoved = self.stats.duplicateCodeRemoved + count - 1
                end
            end
        end
    end
    
    return newContent
end

-- Improve function and variable naming
function CodeRefactorer:improveNaming(content)
    local newContent = content
    
    -- Replace unclear function names
    for oldName, newName in pairs(self.namingImprovements) do
        local pattern = "function [%w_:.]+" .. oldName .. "%(.-%)%s"
        newContent = newContent:gsub(pattern, function(match)
            local prefix = match:match("function ([%w_:.]+)" .. oldName)
            return "function " .. prefix .. newName .. match:match(oldName .. "(%(.-%)%s)")
        end)
        
        -- Also replace function calls
        local callPattern = "([^%w_])" .. oldName .. "%(.-%)([^%w_])"
        newContent = newContent:gsub(callPattern, function(prefix, suffix)
            return prefix .. newName .. suffix
        end)
    end
    
    -- Improve variable naming
    newContent = newContent:gsub("local (%w) = ", function(var)
        if var == "i" or var == "j" or var == "k" then
            -- Keep loop variables
            return "local " .. var .. " = "
        else
            -- Suggest better names for single-letter variables
            local suggestions = {
                x = "posX",
                y = "posY",
                t = "time",
                v = "value",
                s = "string",
                n = "count",
                p = "player",
                e = "entity",
                g = "game"
            }
            
            if suggestions[var] then
                return "local " .. suggestions[var] .. " = "
            else
                return "local " .. var .. " = "
            end
        end
    end)
    
    return newContent
end

-- Reduce nesting levels
function CodeRefactorer:reduceNesting(content)
    local newContent = content
    
    -- Replace deeply nested if statements with early returns
    newContent = newContent:gsub("if%s+(.-)%s+then%s+(.-)%s+else%s+return%s+(.-)%s+end", function(condition, code, returnValue)
        return "if not (" .. condition .. ") then return " .. returnValue .. " end\n" .. code
    end)
    
    -- Replace nested if statements with combined conditions
    newContent = newContent:gsub("if%s+(.-)%s+then%s+if%s+(.-)%s+then", function(condition1, condition2)
        return "if " .. condition1 .. " and " .. condition2 .. " then"
    end)
    
    -- Track complexity reduction
    local originalNestingLevel = 0
    local newNestingLevel = 0
    
    for _ in content:gmatch("if%s+.-%s+then") do
        originalNestingLevel = originalNestingLevel + 1
    end
    
    for _ in newContent:gmatch("if%s+.-%s+then") do
        newNestingLevel = newNestingLevel + 1
    end
    
    self.stats.complexityReduced = self.stats.complexityReduced + (originalNestingLevel - newNestingLevel)
    
    return newContent
end

-- Add documentation to functions and classes
function CodeRefactorer:addDocumentation(content, filePath)
    local newContent = content
    
    -- Extract class name from file path
    local className = filePath:match("([^/]+)%.lua$")
    if className then
        className = className:gsub("_", " "):gsub("^%l", string.upper)
    else
        className = "Unknown"
    end
    
    -- Add class documentation if not present
    if not newContent:match("^%-%- ") then
        local classDescription = "Handles " .. className:lower() .. " functionality for Nightfall Chess"
        local methods = ""
        
        -- Extract methods for documentation
        for methodName, methodBody in newContent:gmatch("function [%w_:]+:([%w_]+)%(.-%)(.-)end") do
            local description = "Handles " .. methodName:gsub("([A-Z])", " %1"):lower()
            methods = methods .. string.format(self.documentationTemplates.methodLine, methodName, description) .. "\n"
        end
        
        local classDoc = string.format(self.documentationTemplates.classHeader, className, classDescription, methods)
        newContent = classDoc .. "\n" .. newContent
    end
    
    -- Add function documentation
    newContent = newContent:gsub("(function [%w_:]+:[%w_]+%(.-%))", function(funcDecl)
        -- Skip if already documented
        local prevLine = newContent:match(".-" .. funcDecl:gsub("([^%w])", "%%%1") .. ".-")
        if prevLine and prevLine:match("%-%-") then
            return funcDecl
        end
        
        -- Extract function name and parameters
        local funcName = funcDecl:match("function [%w_:]+:([%w_]+)")
        if not funcName then
            return funcDecl
        end
        
        local params = {}
        for param in funcDecl:match("%((.-)%)"):gmatch("([%w_]+)") do
            if param ~= "self" then
                table.insert(params, param)
            end
        end
        
        -- Generate parameter documentation
        local paramDocs = ""
        for _, param in ipairs(params) do
            local paramDesc = "The " .. param:gsub("([A-Z])", " %1"):lower()
            paramDocs = paramDocs .. string.format(self.documentationTemplates.parameterLine, param, paramDesc) .. "\n"
        end
        
        -- Generate function description
        local funcDesc = "Handles " .. funcName:gsub("([A-Z])", " %1"):lower()
        
        -- Generate return description
        local returnDesc = "None"
        
        -- Check function body for returns
        local funcBody = newContent:match(funcDecl .. "(.-end)")
        if funcBody and funcBody:match("return") then
            returnDesc = "Result of the operation"
        end
        
        -- Generate complete documentation
        local funcDoc = string.format(self.documentationTemplates.functionHeader, 
            funcName, funcDesc, paramDocs, returnDesc)
        
        return funcDoc .. funcDecl
    end)
    
    return newContent
end

-- Standardize code formatting
function CodeRefactorer:standardizeFormatting(content)
    local newContent = content
    
    -- Standardize indentation (use 4 spaces)
    newContent = newContent:gsub("\t", "    ")
    
    -- Standardize spacing around operators
    newContent = newContent:gsub("([%w%)%\"'])([%+%-%*/%^%%=~><])([%w%(\'%\"])", "%1 %2 %3")
    
    -- Standardize spacing after commas
    newContent = newContent:gsub("([,%:])([%w%\"%'])", "%1 %2")
    
    -- Standardize spacing in function calls
    newContent = newContent:gsub("([%w_]+)%s*%(", "%1(")
    
    -- Standardize spacing in function declarations
    newContent = newContent:gsub("function%s+([%w_:]+)%s*%(", "function %1(")
    
    -- Standardize empty lines (max 1 empty line)
    newContent = newContent:gsub("\n\n\n+", "\n\n")
    
    return newContent
end

-- Refactor all Lua files in a directory
function CodeRefactorer:refactorDirectory(dirPath, recursive)
    print("Refactoring directory: " .. dirPath)
    
    local files = {}
    local dirs = {}
    
    -- List files in directory
    local p = io.popen('find "' .. dirPath .. '" -type f -name "*.lua" ' .. (recursive and "" or "-maxdepth 1"))
    for file in p:lines() do
        table.insert(files, file)
    end
    p:close()
    
    -- Refactor each file
    for _, file in ipairs(files) do
        self:refactorFile(file)
    end
    
    -- Refactor subdirectories if recursive
    if recursive then
        local p = io.popen('find "' .. dirPath .. '" -type d -mindepth 1 -maxdepth 1')
        for dir in p:lines() do
            table.insert(dirs, dir)
        end
        p:close()
        
        for _, dir in ipairs(dirs) do
            self:refactorDirectory(dir, recursive)
        end
    end
    
    return self.stats
end

-- Generate refactoring report
function CodeRefactorer:generateReport()
    local report = "Code Refactoring Report\n"
    report = report .. "======================\n\n"
    
    report = report .. "Files Refactored: " .. self.stats.filesRefactored .. "\n"
    report = report .. "Functions Refactored: " .. self.stats.functionsRefactored .. "\n"
    report = report .. "Duplicate Code Removed: " .. self.stats.duplicateCodeRemoved .. " instances\n"
    report = report .. "Complexity Reduced: " .. self.stats.complexityReduced .. " nesting levels\n\n"
    
    report = report .. "Refactoring Settings:\n"
    for setting, enabled in pairs(self.settings) do
        report = report .. "  - " .. setting:gsub("([A-Z])", " %1"):gsub("^%l", string.upper) .. ": " .. (enabled and "Enabled" or "Disabled") .. "\n"
    end
    
    return report
end

-- Refactor the entire game codebase
function CodeRefactorer:refactorGame()
    print("Starting game code refactoring")
    
    -- Reset statistics
    self.stats = {
        filesRefactored = 0,
        functionsRefactored = 0,
        duplicateCodeRemoved = 0,
        complexityReduced = 0
    }
    
    -- Refactor source directories
    self:refactorDirectory("/home/ubuntu/nightfall/src", true)
    
    -- Generate report
    local report = self:generateReport()
    print(report)
    
    -- Save report to file
    local file = io.open("/home/ubuntu/nightfall/refactoring_report.txt", "w")
    if file then
        file:write(report)
        file:close()
        print("Refactoring report saved to refactoring_report.txt")
    end
    
    return report
end

-- Enable or disable refactoring setting
function CodeRefactorer:setSetting(name, enabled)
    if self.settings[name] ~= nil then
        self.settings[name] = enabled
        print(string.format("Refactoring setting '%s' %s", name, enabled and "enabled" or "disabled"))
        return true
    end
    
    return false
end

return CodeRefactorer
