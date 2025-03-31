-- Enhanced Enemy AI System for Nightfall Chess
-- Provides sophisticated decision-making for enemy units

local class = require("lib.middleclass.middleclass")

local EnemyAI = class("EnemyAI")

function EnemyAI:initialize(game)
    self.game = game
    
    -- Configuration for different AI personalities
    self.aiTypes = {
        -- Aggressive AI focuses on attacking player units
        aggressive = {
            attackWeight = 0.8,
            defenseWeight = 0.2,
            supportWeight = 0.0,
            riskTolerance = 0.7,
            targetPriority = {"king", "queen", "rook", "bishop", "knight", "pawn"},
            fleeThreshold = 0.2,
            useAbilityChance = 0.7
        },
        
        -- Defensive AI focuses on protecting itself and allies
        defensive = {
            attackWeight = 0.3,
            defenseWeight = 0.6,
            supportWeight = 0.1,
            riskTolerance = 0.3,
            targetPriority = {"pawn", "knight", "bishop", "rook", "queen", "king"},
            fleeThreshold = 0.4,
            useAbilityChance = 0.5
        },
        
        -- Support AI focuses on buffing allies and debuffing enemies
        support = {
            attackWeight = 0.2,
            defenseWeight = 0.3,
            supportWeight = 0.5,
            riskTolerance = 0.4,
            targetPriority = {"bishop", "queen", "knight", "rook", "pawn", "king"},
            fleeThreshold = 0.3,
            useAbilityChance = 0.8
        },
        
        -- Balanced AI has no strong preferences
        balanced = {
            attackWeight = 0.4,
            defenseWeight = 0.4,
            supportWeight = 0.2,
            riskTolerance = 0.5,
            targetPriority = {"queen", "rook", "bishop", "knight", "pawn", "king"},
            fleeThreshold = 0.3,
            useAbilityChance = 0.6
        },
        
        -- Boss AI is highly strategic and dangerous
        boss = {
            attackWeight = 0.6,
            defenseWeight = 0.3,
            supportWeight = 0.1,
            riskTolerance = 0.6,
            targetPriority = {"king", "queen", "rook", "bishop", "knight", "pawn"},
            fleeThreshold = 0.1,
            useAbilityChance = 0.9
        }
    }
    
    -- AI personality assignment based on unit type
    self.unitTypeToAI = {
        pawn = "aggressive",
        knight = "aggressive",
        bishop = "support",
        rook = "defensive",
        queen = "balanced",
        king = "defensive"
    }
    
    -- Special ability preferences by unit type
    self.abilityPreferences = {
        pawn = {
            offensive = {"shield_bash", "advance"},
            defensive = {"promotion"},
            support = {}
        },
        knight = {
            offensive = {"knight's_charge", "feint"},
            defensive = {},
            support = {}
        },
        bishop = {
            offensive = {"arcane_bolt"},
            defensive = {"mystic_barrier"},
            support = {"healing_light"}
        },
        rook = {
            offensive = {"shockwave", "seismic_slam"},
            defensive = {"fortify", "stone_skin"},
            support = {}
        },
        queen = {
            offensive = {"sovereign's_wrath", "shadow_bolt"},
            defensive = {},
            support = {"royal_decree", "strategic_repositioning", "drain_energy"}
        },
        king = {
            offensive = {"royal_execution"},
            defensive = {"royal_guard"},
            support = {"inspiring_presence", "tactical_command", "summon_pawns", "darkness_descends"}
        }
    }
    
    -- Tactical patterns for coordinated multi-unit strategies
    self.tacticalPatterns = {
        -- Surround a target with multiple units
        surround = {
            requiredUnits = 3,
            unitTypes = {"any"},
            targetType = "player",
            formation = {{0,1}, {1,0}, {0,-1}, {-1,0}}
        },
        
        -- Protect a valuable unit with others
        protect = {
            requiredUnits = 3,
            unitTypes = {"king", "queen"},
            targetType = "ally",
            formation = {{0,1}, {1,0}, {0,-1}, {-1,0}}
        },
        
        -- Coordinate an attack with multiple units
        coordAttack = {
            requiredUnits = 2,
            unitTypes = {"any"},
            targetType = "player",
            formation = {{1,1}, {-1,1}}
        },
        
        -- Set up a bishop and queen attack line
        attackLine = {
            requiredUnits = 2,
            unitTypes = {"bishop", "queen"},
            targetType = "player",
            formation = {{1,1}, {2,2}}
        },
        
        -- Knight flanking maneuver
        knightFlank = {
            requiredUnits = 2,
            unitTypes = {"knight"},
            targetType = "player",
            formation = {{2,1}, {1,2}}
        }
    }
    
    -- Memory system for AI learning
    self.memory = {
        playerActions = {},
        successfulAttacks = {},
        failedAttacks = {},
        damageTaken = {},
        unitsLost = {}
    }
    
    -- Difficulty scaling
    self.difficulty = "normal" -- "easy", "normal", "hard"
    self.difficultyModifiers = {
        easy = {
            damageMultiplier = 0.8,
            healthMultiplier = 0.8,
            decisionQuality = 0.6, -- Makes suboptimal decisions sometimes
            coordinationLevel = 0.3 -- Less coordination between units
        },
        normal = {
            damageMultiplier = 1.0,
            healthMultiplier = 1.0,
            decisionQuality = 0.8,
            coordinationLevel = 0.6
        },
        hard = {
            damageMultiplier = 1.2,
            healthMultiplier = 1.2,
            decisionQuality = 1.0, -- Always makes optimal decisions
            coordinationLevel = 0.9 -- High coordination between units
        }
    }
    
    -- Current state tracking
    self.currentTurn = 0
    self.activeEnemies = {}
    self.playerUnits = {}
    self.tacticalPlans = {}
    self.threatMap = {}
    self.opportunityMap = {}
end

-- Set AI difficulty
function EnemyAI:setDifficulty(difficulty)
    if self.difficultyModifiers[difficulty] then
        self.difficulty = difficulty
        return true
    end
    return false
end

-- Process turn for all enemy units
function EnemyAI:processTurn(enemyUnits, playerUnits, grid)
    -- *** DEBUGGING START (Corrected) ***
    print("--- EnemyAI:processTurn ---")
    print("  Received grid parameter:")
    print("  Type:", type(grid))       -- Correct: Use the parameter 'grid'
    print("  Value:", tostring(grid))   -- Correct: Use the parameter 'grid'
    if grid then
         print("  Grid Width:", tostring(grid.width))   -- Correct: Use the parameter 'grid'
         print("  Grid Height:", tostring(grid.height))  -- Correct: Use the parameter 'grid'
         print("  Grid TileSize:", tostring(grid.tileSize))-- Correct: Use the parameter 'grid'
    else
         print("  ERROR: Received grid parameter is nil!") -- Correct check on the parameter
    end
    print("---------------------------")
    -- *** DEBUGGING END ***

    self.currentTurn = self.currentTurn + 1
    self.activeEnemies = enemyUnits
    self.playerUnits = playerUnits
    
    print("  Calling updateThreatMap, passing grid object:", tostring(grid))
    -- *** END DEBUG ***

    -- Update tactical information
    self:updateThreatMap(grid)
    self:updateOpportunityMap(grid)
    self:generateTacticalPlans()
    
    -- Process each enemy unit
    local actions = {}
    
    -- Sort units by priority (usually based on initiative)
    table.sort(enemyUnits, function(a, b)
        return a.stats.initiative > b.stats.initiative
    end)
    
    for _, unit in ipairs(enemyUnits) do
        -- Skip units with no action points
        if unit.stats.actionPoints <= 0 then
            goto continue
        end
        
        -- Determine AI type for this unit
        local aiType = self:getAITypeForUnit(unit)
        
        -- Check if unit is part of a tactical plan
        local hasTacticalPlan, tacticalAction = self:checkTacticalPlan(unit)
        
        if hasTacticalPlan then
            -- Execute tactical plan action
            table.insert(actions, tacticalAction)
        else
            -- Make individual decision
            local action = self:makeDecision(unit, aiType, grid)
            table.insert(actions, action)
        end
        
        ::continue::
    end
    
    -- Update memory with this turn's information
    self:updateMemory()
    
    return actions
end

-- Get the appropriate AI type for a unit
function EnemyAI:getAITypeForUnit(unit)
    -- Boss units always use boss AI
    if unit.isBoss then
        return self.aiTypes.boss
    end
    
    -- Get base AI type from unit type
    local aiTypeName = self.unitTypeToAI[unit.unitType] or "balanced"
    
    -- Adjust based on unit's health
    local healthPercentage = unit.stats.health / unit.stats.maxHealth
    if healthPercentage < 0.3 and aiTypeName ~= "aggressive" then
        -- Severely damaged units tend to become more defensive
        aiTypeName = "defensive"
    elseif healthPercentage > 0.8 and unit.unitType == "pawn" then
        -- Healthy pawns tend to be more aggressive
        aiTypeName = "aggressive"
    end
    
    -- Special case for units with healing abilities
    if self:hasHealingAbility(unit) and self:getAlliesNeedingHealing() then
        aiTypeName = "support"
    end
    
    return self.aiTypes[aiTypeName]
end

-- Check if unit has a healing ability
function EnemyAI:hasHealingAbility(unit)
    for _, ability in ipairs(unit.abilities or {}) do
        if ability == "healing_light" or ability == "dark_ritual" then
            return true
        end
    end
    return false
end

-- Get allies that need healing
function EnemyAI:getAlliesNeedingHealing()
    local needHealing = {}
    for _, unit in ipairs(self.activeEnemies) do
        if unit.stats.health < unit.stats.maxHealth * 0.5 then
            table.insert(needHealing, unit)
        end
    end
    return #needHealing > 0 and needHealing or nil
end

-- Update threat map (where player units can attack)
function EnemyAI:updateThreatMap(grid)
    self.threatMap = {}

    -- *** DEBUGGING START ***
    print("--- AI: updateThreatMap ---")
    print("  Inspecting grid before loops:")
    print("  Type of grid var:", type(grid))
    print("  Value of grid var:", tostring(grid))
    if grid then
        print("  grid.width:", type(grid.width), tostring(grid.width))
        print("  grid.height:", type(grid.height), tostring(grid.height)) -- This is the critical one!
        print("  grid.tileSize:", type(grid.tileSize), tostring(grid.tileSize))
        -- You could add checks for other expected grid properties too
        -- print("  grid:getTile exists?", tostring(grid.getTile))
    else
        print("  ERROR: The 'grid' variable is nil!")
    end
    print("---------------------------")
    -- *** DEBUGGING END ***
    
    -- Initialize threat map
    for y = 1, grid.height do
        self.threatMap[y] = {}
        for x = 1, grid.width do
            self.threatMap[y][x] = {
                threatLevel = 0,
                threateningUnits = {}
            }
        end
    end
    
    -- Calculate threat from each player unit
    for _, unit in ipairs(self.playerUnits) do
        local attackRange = unit.stats.attackRange or 1
        local moveRange = unit.stats.moveRange or 1
        local totalRange = attackRange + moveRange
        
        -- Calculate potential attack positions
        for y = math.max(1, unit.y - totalRange), math.min(grid.height, unit.y + totalRange) do
            for x = math.max(1, unit.x - totalRange), math.min(grid.width, unit.x + totalRange) do
                -- Check if position is within combined move and attack range
                local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                if distance <= totalRange then
                    -- Calculate threat level based on unit's attack and distance
                    local threatValue = unit.stats.attack * (1 - distance / (totalRange + 1))
                    
                    -- Add to threat map
                    self.threatMap[y][x].threatLevel = self.threatMap[y][x].threatLevel + threatValue
                    table.insert(self.threatMap[y][x].threateningUnits, unit)
                end
            end
        end
    end
end

-- Update opportunity map (good positions for enemy units)
function EnemyAI:updateOpportunityMap(grid)
    self.opportunityMap = {}
    
    -- Initialize opportunity map
    for y = 1, grid.height do
        self.opportunityMap[y] = {}
        for x = 1, grid.width do
            self.opportunityMap[y][x] = {
                attackValue = 0,
                defenseValue = 0,
                supportValue = 0,
                totalValue = 0
            }
        end
    end
    
    -- Calculate values for each position
    for y = 1, grid.height do
        for x = 1, grid.width do
            -- Skip unwalkable cells
            if not grid.tiles[y][x].walkable then
                goto continue
            end
            
            -- Attack value - positions that can attack player units
            local attackValue = 0
            for _, playerUnit in ipairs(self.playerUnits) do
                local distance = math.abs(playerUnit.x - x) + math.abs(playerUnit.y - y)
                if distance <= 2 then -- Within attack range
                    attackValue = attackValue + (3 - distance) * 10 -- Closer is better
                end
            end
            
            -- Defense value - positions away from threats
            local defenseValue = 100 - (self.threatMap[y][x].threatLevel * 10)
            defenseValue = math.max(0, defenseValue)
            
            -- Support value - positions near allied units
            local supportValue = 0
            for _, allyUnit in ipairs(self.activeEnemies) do
                local distance = math.abs(allyUnit.x - x) + math.abs(allyUnit.y - y)
                if distance <= 2 and distance > 0 then -- Near but not on top of allies
                    supportValue = supportValue + (3 - distance) * 5
                    
                    -- Extra value for supporting damaged allies
                    if allyUnit.stats.health < allyUnit.stats.maxHealth * 0.5 then
                        supportValue = supportValue + 15
                    end
                end
            end
            
            -- Store values
            self.opportunityMap[y][x].attackValue = attackValue
            self.opportunityMap[y][x].defenseValue = defenseValue
            self.opportunityMap[y][x].supportValue = supportValue
            
            ::continue::
        end
    end
end

-- Generate tactical plans for coordinated actions
function EnemyAI:generateTacticalPlans()
    self.tacticalPlans = {}
    
    -- Skip tactical planning on easy difficulty
    if self.difficulty == "easy" then
        return
    end
    
    -- Check each tactical pattern
    for patternName, pattern in pairs(self.tacticalPatterns) do
        -- Find suitable units for this pattern
        local suitableUnits = {}
        
        for _, unit in ipairs(self.activeEnemies) do
            -- Check if unit type matches pattern requirements
            local typeMatches = false
            for _, requiredType in ipairs(pattern.unitTypes) do
                if requiredType == "any" or requiredType == unit.unitType then
                    typeMatches = true
                    break
                end
            end
            
            if typeMatches then -- and unit.stats.actionPoints > 0 then
                table.insert(suitableUnits, unit)
            end
        end
        
        -- Check if we have enough units for this pattern
        if #suitableUnits >= pattern.requiredUnits then
            -- Find suitable targets
            local targets = {}
            
            if pattern.targetType == "player" then
                targets = self.playerUnits
            elseif pattern.targetType == "ally" then
                -- Find valuable allies to protect
                for _, unit in ipairs(self.activeEnemies) do
                    if unit.unitType == "king" or unit.unitType == "queen" then
                        table.insert(targets, unit)
                    end
                end
            end
            
            -- For each potential target, try to form the pattern
            for _, target in ipairs(targets) do
                -- *** NEW TARGET LOGGING - ADD THIS ***
                print(string.format("--- generateTacticalPlans: Evaluating Target ---"))
                print(string.format("  Pattern: %s", patternName))
                if target then
                    print(string.format("  Target ID: %s, Type: %s, Faction: %s",
                          target.id or "N/A", target.unitType or "N/A", target.faction or "N/A"))
                    print(string.format("  Target Coords: (%s, %s)", tostring(target.x), tostring(target.y)))
                    -- Check explicitly for nil coordinates on the target
                    if target.x == nil or target.y == nil then
                        print("  ----> CRITICAL: TARGET UNIT HAS NIL COORDINATES! <----")
                    end
                else
                    print("  ----> ERROR: Target object itself is nil! <----")
                end
                print(string.format("------------------------------------------------"))
                -- *** END NEW TARGET LOGGING ***

                -- Existing logging (keep this too)
                -- print(string.format("Generating plan for target '%s' (%s) at (%s, %s)", ...))

                local plan = {
                    pattern = patternName,
                    target = target,
                    units = {},
                    positions = {}
                }

                -- Calculate positions for the formation
                for _, offset in ipairs(pattern.formation) do
                    -- *** Check target coords AGAIN just before use - ADD THIS ***
                    if not target or target.x == nil or target.y == nil then
                         print(string.format("  ----> ERROR: Cannot calculate position offset, target coords are nil for ID %s!", target and target.id or "N/A"))
                         goto skip_offset -- Skip this offset calculation if target coords are bad
                    end
                    -- *** END Check ***

                    local posX = target.x + offset[1]
                    local posY = target.y + offset[2]

                    -- *** Log Calculated Position - ADD THIS ***
                    print(string.format("    Calculating plan position: Target (%s,%s) + Offset (%s,%s) -> Pos (%s,%s)",
                          tostring(target.x), tostring(target.y),
                          tostring(offset[1]), tostring(offset[2]),
                          tostring(posX), tostring(posY)))
                    -- *** END Log ***

                    -- Check if position is valid
                    -- Add check for grid dimensions being valid
                    if not self.game or not self.game.grid or not self.game.grid.width or not self.game.grid.height then
                         print("    ----> ERROR: Grid dimensions invalid, cannot check position validity.")
                         goto skip_offset
                    end
                    if posX >= 1 and posX <= self.game.grid.width and
                       posY >= 1 and posY <= self.game.grid.height then
                        -- Add check for grid.tiles structure being valid
                        if not self.game.grid.tiles or not self.game.grid.tiles[posY] or not self.game.grid.tiles[posY][posX] then
                             print(string.format("    ----> ERROR: Grid tiles structure invalid for position (%s, %s), cannot check walkability.", tostring(posX), tostring(posY)))
                             goto skip_offset
                        end
                        if self.game.grid.tiles[posY][posX].walkable then
                            print(string.format("      Position (%s, %s) is valid and walkable. Adding to plan.", posX, posY))
                            table.insert(plan.positions, {x = posX, y = posY})
                        else
                             print(string.format("      Position (%s, %s) is not walkable.", posX, posY))
                        end
                    else
                        print(string.format("      Position (%s, %s) is out of bounds.", posX, posY))
                    end
                    ::skip_offset:: -- Label for goto
                end

                -- If we have enough valid positions, assign units
                if #plan.positions >= pattern.requiredUnits then
                    -- Sort units by distance to their potential positions
                    local assignments = {}

                    for i, unit in ipairs(suitableUnits) do
                        -- *** Make sure the logging here is present and correct ***
                        if i <= #plan.positions then
                            local pos = plan.positions[i]

                            print(string.format("    Assigning Unit: Checking unit '%s' at (%s, %s) against plan pos (%s, %s)",
                                unit.id or "N/A", tostring(unit.x), tostring(unit.y),
                                tostring(pos.x), tostring(pos.y)))
                            if unit.x == nil or unit.y == nil or pos.x == nil or pos.y == nil then
                                print("      ----> ERROR: NIL COORDINATE DETECTED during assignment calculation! <----")
                                -- Skip this assignment if coordinates are nil
                                goto skip_assignment
                            end

                            local distance = math.abs(unit.x - pos.x) + math.abs(unit.y - pos.y)
                            print(string.format("      Calculated distance: %s", tostring(distance)))

                            table.insert(assignments, {
                                unit = unit,
                                position = pos,
                                distance = distance
                            })
                            ::skip_assignment:: -- Label for goto
                        end
                    end

                    -- Sort by distance
                    if #assignments > 0 then
                        print(string.format("    Sorting %d assignments by distance...", #assignments))
                        -- Add check before sorting
                        for idx, assign_data in ipairs(assignments) do
                             if type(assign_data.distance) ~= "number" then
                                  print(string.format("      ----> ERROR: Assignment %d for unit %s has nil distance BEFORE sort!", idx, assign_data.unit.id or "N/A"))
                             end
                        end
                        -- The sort itself
                        table.sort(assignments, function(a, b)
                            -- Add check inside sort comparison function
                            if type(a.distance) ~= "number" or type(b.distance) ~= "number" then
                                print(string.format("      ----> ERROR: Comparing nil distance during sort! a.dist=%s, b.dist=%s", tostring(a.distance), tostring(b.distance)))
                                -- Handle error case: maybe return false or true consistently? Or error out?
                                -- Returning false might avoid the crash but hide the issue. Let's keep the potential crash for now.
                            end
                            return a.distance < b.distance -- This is line ~429 where the error occurs
                        end)
                        print("    Sorting complete.")
                    else
                         print("    No valid assignments to sort.")
                    end
                    
                    -- Take the first N assignments
                    for i = 1, pattern.requiredUnits do
                        if i <= #assignments then
                            plan.units[assignments[i].unit.id] = {
                                unit = assignments[i].unit,
                                targetPosition = assignments[i].position
                            }
                        end
                    end
                    
                    -- If we have enough units assigned, add the plan
                    if #plan.units >= pattern.requiredUnits then
                        table.insert(self.tacticalPlans, plan)
                    end
                end
            end
        end
    end
    
    -- Sort plans by priority (currently just using the order they were created)
    -- Could be enhanced to prioritize certain patterns or targets
end

-- Check if a unit is part of a tactical plan
function EnemyAI:checkTacticalPlan(unit)
    for _, plan in ipairs(self.tacticalPlans) do
        if plan.units[unit.id] then
            local targetPos = plan.units[unit.id].targetPosition
            
            -- Create action to move to position
            local action = {
                type = "move",
                unit = unit,
                targetX = targetPos.x,
                targetY = targetPos.y,
                isTactical = true,
                planName = plan.pattern
            }
            
            -- Remove unit from plan after assigning action
            plan.units[unit.id] = nil
            
            return true, action
        end
    end
    
    return false, nil
end

-- Make a decision for an individual unit
function EnemyAI:makeDecision(unit, aiType, grid)
    -- Apply decision quality based on difficulty
    local decisionQuality = self.difficultyModifiers[self.difficulty].decisionQuality
    
    -- Occasionally make suboptimal decisions on lower difficulties
    if math.random() > decisionQuality then
        return self:makeRandomDecision(unit, grid)
    end
    
    -- Check if unit should use an ability
    if math.random() < aiType.useAbilityChance and self:canUseAbility(unit) then
        local abilityAction = self:chooseAbility(unit, aiType)
        if abilityAction then
            return abilityAction
        end
    end
    
    -- Calculate position values based on AI type
    for y = 1, grid.height do
        for x = 1, grid.width do
            local values = self.opportunityMap[y][x]
            values.totalValue = (values.attackValue * aiType.attackWeight) +
                               (values.defenseValue * aiType.defenseWeight) +
                               (values.supportValue * aiType.supportWeight)
        end
    end
    
    -- Find best move position
    local bestPos = self:findBestPosition(unit, grid)
    
    -- Determine action based on position
    if bestPos.x == unit.x and bestPos.y == unit.y then
        -- Already in optimal position, check for attack
        local target = self:findBestAttackTarget(unit, aiType)
        if target then
            return {
                type = "attack",
                unit = unit,
                target = target
            }
        else
            -- No good attack, just end turn
            return {
                type = "wait",
                unit = unit
            }
        end
    else
        -- Move to better position
        return {
            type = "move",
            unit = unit,
            targetX = bestPos.x,
            targetY = bestPos.y
        }
    end
end

-- Make a random (suboptimal) decision for easier difficulties
function EnemyAI:makeRandomDecision(unit, grid)
    -- 50% chance to just wait
    if math.random() < 0.5 then
        return {
            type = "wait",
            unit = unit
        }
    end
    
    -- 30% chance to move randomly
    if math.random() < 0.3 then
        local moveRange = unit.stats.moveRange or 1
        local possibleMoves = {}
        
        for y = math.max(1, unit.y - moveRange), math.min(grid.height, unit.y + moveRange) do
            for x = math.max(1, unit.x - moveRange), math.min(grid.width, unit.x + moveRange) do
                if grid.tiles[y][x].walkable and not grid.tiles[y][x].entity then
                    table.insert(possibleMoves, {x = x, y = y})
                end
            end
        end
        
        if #possibleMoves > 0 then
            local randomMove = possibleMoves[math.random(#possibleMoves)]
            return {
                type = "move",
                unit = unit,
                targetX = randomMove.x,
                targetY = randomMove.y
            }
        end
    end
    
    -- Otherwise try to attack a random target
    local attackRange = unit.stats.attackRange or 1
    local possibleTargets = {}
    
    for _, playerUnit in ipairs(self.playerUnits) do
        local distance = math.abs(unit.x - playerUnit.x) + math.abs(unit.y - playerUnit.y)
        if distance <= attackRange then
            table.insert(possibleTargets, playerUnit)
        end
    end
    
    if #possibleTargets > 0 then
        local randomTarget = possibleTargets[math.random(#possibleTargets)]
        return {
            type = "attack",
            unit = unit,
            target = randomTarget
        }
    end
    
    -- Default to waiting
    return {
        type = "wait",
        unit = unit
    }
end

-- Find the best position for a unit to move to
function EnemyAI:findBestPosition(unit, grid)
    local moveRange = unit.stats.moveRange or 1
    local bestPos = {x = unit.x, y = unit.y}
    local bestValue = self.opportunityMap[unit.y][unit.x].totalValue
    
    -- Check all positions within move range
    for y = math.max(1, unit.y - moveRange), math.min(grid.height, unit.y + moveRange) do
        for x = math.max(1, unit.x - moveRange), math.min(grid.width, unit.x + moveRange) do
            -- Check if position is walkable and not occupied
            if grid.tiles[y][x].walkable and not grid.tiles[y][x].entity then
                local distance = math.abs(unit.x - x) + math.abs(unit.y - y)
                
                -- Check if within move range
                if distance <= moveRange then
                    local value = self.opportunityMap[y][x].totalValue
                    
                    -- Prefer positions that allow attacking
                    local canAttackFromHere = false
                    for _, playerUnit in ipairs(self.playerUnits) do
                        local attackDistance = math.abs(x - playerUnit.x) + math.abs(y - playerUnit.y)
                        if attackDistance <= (unit.stats.attackRange or 1) then
                            canAttackFromHere = true
                            value = value + 20 -- Significant bonus for attack positions
                            break
                        end
                    end
                    
                    if value > bestValue then
                        bestValue = value
                        bestPos = {x = x, y = y}
                    end
                end
            end
        end
    end
    
    return bestPos
end

-- Find the best target to attack
function EnemyAI:findBestAttackTarget(unit, aiType)
    local attackRange = unit.stats.attackRange or 1
    local possibleTargets = {}
    
    -- Find all targets in range
    for _, playerUnit in ipairs(self.playerUnits) do
        local distance = math.abs(unit.x - playerUnit.x) + math.abs(unit.y - playerUnit.y)
        if distance <= attackRange then
            table.insert(possibleTargets, playerUnit)
        end
    end
    
    -- If no targets in range, return nil
    if #possibleTargets == 0 then
        return nil
    end
    
    -- Score each target based on AI type's priorities
    local scoredTargets = {}
    
    for _, target in ipairs(possibleTargets) do
        local score = 0
        
        -- Base score on target's health percentage (prefer damaged targets)
        local healthPercentage = target.stats.health / target.stats.maxHealth
        score = score + (1 - healthPercentage) * 50
        
        -- Adjust score based on target type priority
        for i, targetType in ipairs(aiType.targetPriority) do
            if target.unitType == targetType then
                score = score + (7 - i) * 10 -- Higher priority types get higher scores
                break
            end
        end
        
        -- Adjust score based on target's threat level
        score = score + target.stats.attack * 2
        
        -- Adjust score based on whether we can defeat the target
        local estimatedDamage = self:estimateDamage(unit, target)
        if estimatedDamage >= target.stats.health then
            score = score + 100 -- Big bonus for potential kills
        end
        
        table.insert(scoredTargets, {
            target = target,
            score = score
        })
    end
    
    -- Sort targets by score
    table.sort(scoredTargets, function(a, b)
        return a.score > b.score
    end)
    
    -- Return the highest scoring target
    if #scoredTargets > 0 then
        return scoredTargets[1].target
    end
    
    return nil
end

-- Estimate damage that would be dealt to a target
function EnemyAI:estimateDamage(attacker, defender)
    -- Basic damage calculation
    local baseDamage = attacker.stats.attack - defender.stats.defense
    baseDamage = math.max(1, baseDamage) -- Minimum 1 damage
    
    -- Apply difficulty modifier
    baseDamage = baseDamage * self.difficultyModifiers[self.difficulty].damageMultiplier
    
    -- Check for critical hit (simplified)
    local critChance = attacker.stats.critChance or 0.1
    if math.random() < critChance then
        baseDamage = baseDamage * 1.5
    end
    
    return math.floor(baseDamage)
end

-- Check if unit can use an ability
function EnemyAI:canUseAbility(unit)
    -- Check if unit has any abilities
    if not unit.abilities or #unit.abilities == 0 then
        return false
    end
    
    -- Check if unit has enough energy
    if unit.stats.energy < 3 then -- Minimum energy cost
        return false
    end
    
    -- Check if unit has action points
    if unit.stats.actionPoints < 1 then
        return false
    end
    
    return true
end

-- Choose the best ability to use
function EnemyAI:chooseAbility(unit, aiType)
    local abilities = unit.abilities or {}
    if #abilities == 0 then
        return nil
    end
    
    -- Get ability preferences for this unit type
    local preferences = self.abilityPreferences[unit.unitType]
    if not preferences then
        return nil
    end
    
    -- Determine which category to prioritize based on AI type
    local categoryPriority = {}
    
    if aiType.attackWeight >= 0.5 then
        table.insert(categoryPriority, "offensive")
        table.insert(categoryPriority, "support")
        table.insert(categoryPriority, "defensive")
    elseif aiType.defenseWeight >= 0.5 then
        table.insert(categoryPriority, "defensive")
        table.insert(categoryPriority, "support")
        table.insert(categoryPriority, "offensive")
    else
        table.insert(categoryPriority, "support")
        table.insert(categoryPriority, "defensive")
        table.insert(categoryPriority, "offensive")
    end
    
    -- Check each category in priority order
    for _, category in ipairs(categoryPriority) do
        local categoryAbilities = preferences[category] or {}
        
        -- Find abilities that are both preferred and available
        local availableAbilities = {}
        
        for _, abilityName in ipairs(categoryAbilities) do
            for _, unitAbility in ipairs(abilities) do
                if unitAbility == abilityName and not unit.abilityCooldowns[unitAbility] then
                    table.insert(availableAbilities, unitAbility)
                end
            end
        end
        
        -- If we have available abilities in this category, choose one
        if #availableAbilities > 0 then
            local chosenAbility = availableAbilities[math.random(#availableAbilities)]
            
            -- Find appropriate target for ability
            local target = self:findAbilityTarget(unit, chosenAbility, category)
            
            if target then
                return {
                    type = "ability",
                    unit = unit,
                    ability = chosenAbility,
                    target = target
                }
            end
        end
    end
    
    return nil
end

-- Find an appropriate target for an ability
function EnemyAI:findAbilityTarget(unit, abilityName, category)
    -- Different targeting logic based on ability category
    if category == "offensive" then
        -- Target player units
        return self:findBestAttackTarget(unit, self:getAITypeForUnit(unit))
    elseif category == "defensive" then
        -- Target self or nearby allies
        if abilityName == "fortify" or abilityName == "stone_skin" then
            return unit -- Self-targeting
        else
            -- Find nearby ally with lowest health
            local lowestHealthAlly = nil
            local lowestHealth = 999999
            
            for _, ally in ipairs(self.activeEnemies) do
                local distance = math.abs(unit.x - ally.x) + math.abs(unit.y - ally.y)
                if distance <= 2 and ally.stats.health < lowestHealth then
                    lowestHealthAlly = ally
                    lowestHealth = ally.stats.health
                end
            end
            
            return lowestHealthAlly or unit
        end
    elseif category == "support" then
        -- Different targeting based on specific ability
        if abilityName == "healing_light" then
            -- Find ally with lowest health
            local lowestHealthAlly = nil
            local lowestHealth = 999999
            
            for _, ally in ipairs(self.activeEnemies) do
                if ally.stats.health < ally.stats.maxHealth and ally.stats.health < lowestHealth then
                    lowestHealthAlly = ally
                    lowestHealth = ally.stats.health
                end
            end
            
            return lowestHealthAlly
        elseif abilityName == "royal_decree" or abilityName == "inspiring_presence" then
            -- These affect all allies, target self
            return unit
        elseif abilityName == "tactical_command" or abilityName == "strategic_repositioning" then
            -- Find ally with highest attack
            local bestAlly = nil
            local highestAttack = 0
            
            for _, ally in ipairs(self.activeEnemies) do
                if ally.id ~= unit.id and ally.stats.attack > highestAttack then
                    bestAlly = ally
                    highestAttack = ally.stats.attack
                end
            end
            
            return bestAlly
        elseif abilityName == "drain_energy" then
            -- Target player unit with highest energy
            local bestTarget = nil
            local highestEnergy = 0
            
            for _, playerUnit in ipairs(self.playerUnits) do
                if playerUnit.stats.energy > highestEnergy then
                    bestTarget = playerUnit
                    highestEnergy = playerUnit.stats.energy
                end
            end
            
            return bestTarget
        end
    end
    
    -- Default to targeting a random player unit
    if #self.playerUnits > 0 then
        return self.playerUnits[math.random(#self.playerUnits)]
    end
    
    return nil
end

-- Update AI memory with this turn's information
function EnemyAI:updateMemory()
    -- Limit memory size
    if #self.memory.playerActions > 10 then
        table.remove(self.memory.playerActions, 1)
    end
    
    -- Other memory updates would happen here based on game events
end

-- Analyze player behavior patterns
function EnemyAI:analyzePlayerBehavior()
    -- This would analyze stored player actions to predict future behavior
    -- For now, just return a simple assessment
    
    local aggressiveCount = 0
    local defensiveCount = 0
    
    for _, action in ipairs(self.memory.playerActions) do
        if action.type == "attack" then
            aggressiveCount = aggressiveCount + 1
        elseif action.type == "move" and action.isRetreat then
            defensiveCount = defensiveCount + 1
        end
    end
    
    if aggressiveCount > defensiveCount then
        return "aggressive"
    else
        return "defensive"
    end
end

-- Record a player action in memory
function EnemyAI:recordPlayerAction(action)
    table.insert(self.memory.playerActions, action)
end

-- Record a successful attack
function EnemyAI:recordSuccessfulAttack(attacker, defender, damage)
    table.insert(self.memory.successfulAttacks, {
        attackerId = attacker.id,
        defenderId = defender.id,
        damage = damage,
        turn = self.currentTurn
    })
end

-- Record a failed attack
function EnemyAI:recordFailedAttack(attacker, defender)
    table.insert(self.memory.failedAttacks, {
        attackerId = attacker.id,
        defenderId = defender.id,
        turn = self.currentTurn
    })
end

-- Record damage taken
function EnemyAI:recordDamageTaken(unit, damage, source)
    table.insert(self.memory.damageTaken, {
        unitId = unit.id,
        damage = damage,
        source = source,
        turn = self.currentTurn
    })
end

-- Record unit lost
function EnemyAI:recordUnitLost(unit, killedBy)
    table.insert(self.memory.unitsLost, {
        unitId = unit.id,
        unitType = unit.unitType,
        killedBy = killedBy,
        turn = self.currentTurn
    })
end

-- Get debug information about AI state
function EnemyAI:getDebugInfo()
    return {
        currentTurn = self.currentTurn,
        activeEnemies = #self.activeEnemies,
        playerUnits = #self.playerUnits,
        tacticalPlans = #self.tacticalPlans,
        difficulty = self.difficulty,
        memory = {
            playerActions = #self.memory.playerActions,
            successfulAttacks = #self.memory.successfulAttacks,
            failedAttacks = #self.memory.failedAttacks,
            damageTaken = #self.memory.damageTaken,
            unitsLost = #self.memory.unitsLost
        }
    }
end

return EnemyAI
