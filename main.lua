-- ==============================================================================
-- UPDATED TARGETING LOGIC (SECTION 4)
-- ==============================================================================
local function getNextTarget()
    local char = player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    
    local allMobs = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then
            table.insert(allMobs, v.Parent)
        end
    end

    local function dist(m) return (char.HumanoidRootPart.Position - m.HumanoidRootPart.Position).Magnitude end

    local blizzards, progenitors, glacials, possessed, colossuses, trash = {}, {}, {}, {}, {}, {}
    
    for _, mob in ipairs(allMobs) do
        local n = mob.Name
        if string.find(n, "Everwisp") or string.find(n, "Everwhisp") then 
            -- IGNORE
        elseif string.find(n, "Blizzard Elemental") or string.find(n, "Everfrost Elemental") then table.insert(blizzards, mob)
        elseif string.find(n, "Frostwind Progenitor") or string.find(n, "Bonechill Progenitor") then table.insert(progenitors, mob)
        elseif string.find(n, "Glacial Elemental") then table.insert(glacials, mob)
        elseif string.find(n, "Possessed Snowman") then table.insert(possessed, mob)
        elseif string.find(n, "Colossus") or string.find(n, "Artic") then table.insert(colossuses, mob) -- ADDED ARTIC/COLOSSUS CHECK
        else
            table.insert(trash, mob) 
        end
    end

    -- PRIORITY CHAIN
    if #blizzards > 0 then return blizzards[1], "KILL" end
    if #progenitors > 0 then
        -- (Existing Aggro Logic...)
        local unvisited = {}
        for _, mob in ipairs(progenitors) do if not visitedMobs[mob] then table.insert(unvisited, mob) end end
        if #unvisited > 0 then table.sort(unvisited, function(a, b) return dist(a) < dist(b) end) return unvisited[1], "AGGRO" end
        if #glacials > 0 then return progenitors[1], "ANCHOR_TO_GLACIAL" end
        table.sort(progenitors, function(a, b) return dist(a) < dist(b) end) return progenitors[1], "KILL"
    end
    if #glacials > 0 then return glacials[1], "KILL_ANCHOR" end
    if #possessed > 0 then table.sort(possessed, function(a, b) return dist(a) < dist(b) end) return possessed[1], "KILL_ANCHOR" end

    -- 5. ARTIC COLOSSUS SPECIAL DISTANCE
    if #colossuses > 0 then return colossuses[1], "KILL_30" end -- UPDATED MODE HERE

    if #trash > 0 then return trash[1], "KILL" end
    return nil, "CLEAR"
end

-- ==============================================================================
-- UPDATED MOVEMENT LOGIC (SECTION 4 - runTo)
-- ==============================================================================
local function runTo(targetModel, mode)
    local char = player.Character; local root = char:WaitForChild("HumanoidRootPart"); local hum = char:WaitForChild("Humanoid"); local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then root.Anchored = false return end
    enforceSpeed(hum); local d = (root.Position - enemyRoot.Position).Magnitude
    
    -- NEW: KILL_30 MODE FOR ARTIC COLOSSUS
    if mode == "KILL_30" then
        if d < 30 then
            root.Anchored = true
            root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
            castSkills(targetModel)
            updateStatus("KEEPING DISTANCE (30): " .. targetModel.Name)
            return
        elseif d > 35 then
            root.Anchored = false
            hum:MoveTo(enemyRoot.Position)
            updateStatus("CHASING (30): " .. targetModel.Name)
        else
            -- Standing still in the 30-35 range
            root.Anchored = true
            root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
            castSkills(targetModel)
            updateStatus("RANGE (30): " .. targetModel.Name)
            return
        end
        return
    end

    -- (Keep all your other existing modes below: ANCHOR_TO_GLACIAL, KILL_ANCHOR, KILL_12, etc.)
    -- ...
end
