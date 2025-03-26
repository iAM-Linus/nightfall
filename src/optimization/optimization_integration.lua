-- Optimization Integration for Nightfall Chess
-- Integrates performance optimizer and code refactorer into the game

local PerformanceOptimizer = require("src.optimization.performance_optimizer")
local CodeRefactorer = require("src.optimization.code_refactorer")

-- Store the original Game:initialize function
local originalGameInitialize = Game.initialize

-- Override the initialize function to add optimization components
function Game:initialize()
    -- Call the original initialize function
    originalGameInitialize(self)
    
    -- Create performance optimizer
    self.performanceOptimizer = PerformanceOptimizer:new(self)
    
    -- Create code refactorer
    self.codeRefactorer = CodeRefactorer:new(self)
    
    -- Add debug menu option
    if self.debugMenu then
        self.debugMenu:addOption("Performance Monitor", function()
            if self.performanceOptimizer.isMonitoring then
                self.performanceOptimizer:stopMonitoring()
            else
                self.performanceOptimizer:startMonitoring()
            end
        end)
        
        self.debugMenu:addOption("Toggle Debug Info", function()
            return self.performanceOptimizer:toggleDebugInfo()
        end)
        
        self.debugMenu:addOption("Apply Optimizations", function()
            return self.performanceOptimizer:optimizeGame()
        end)
        
        self.debugMenu:addOption("Refactor Code", function()
            return self.codeRefactorer:refactorGame()
        end)
    end
    
    print("Optimization components initialized")
end

-- Apply optimizations on game start
local originalGameEnter = Game.enter

function Game:enter()
    -- Call the original enter function
    originalGameEnter(self)
    
    -- Apply performance optimizations
    if self.performanceOptimizer then
        self.performanceOptimizer:applyOptimizations()
    end
    
    print("Performance optimizations applied on game start")
end

print("Optimization integration loaded")
