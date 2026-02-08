local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. CONFIGURATION & STATE (UPDATED DEFAULTS)
-- ==============================================================================
_G.DungeonMaster = true  -- DEFAULT: ON
_G.VoidFarm = false      -- DEFAULT: OFF
_G.GodMode = true        -- DEFAULT: ON
_G.AutoStart = true      -- DEFAULT: ON
_G.AttackRange = 30      

-- Internal Variables
local ClickEvent = ReplicatedStorage:FindFirstChild("Click", true) 
local blacklist = {} 
local visitedMobs = {} 
local currentTarget = nil
local lastPos = Vector3.new(0,0,0)
local stuckTimer = 0
local lastMB1 = 0 
local MB1_COOLDOWN = 0.1 
local hasStarted = false

-- ==============================================================================
-- 1. GOD MODE HOOK
-- ==============================================================================
task.spawn(function()
    pcall(function()
        local DamageRemote = ReplicatedStorage:WaitForChild("Damage", 10)
        local h = hookmetamethod or getgenv().hookmetamethod
        if h and DamageRemote then
            local OldNameCall; OldNameCall = h(game, "__namecall", newcclosure(function(Self, ...)
                if _G.GodMode and (Self == DamageRemote or (Self.Name == "Damage" and Self.Parent == ReplicatedStorage)) and getnamecallmethod() == "FireServer" then
                    return nil 
                end
                return OldNameCall(Self, ...)
            end))
        end
    end)
end)

-- ==============================================================================
-- 2. UI SETUP (RESTORED BUTTONS)
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiUnified") then player.PlayerGui.SanjiUnified:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiUnified"

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(15,15,20); mainFrame.Position=UDim2.new(0.8,0,0.3,0); mainFrame.Size=UDim2.new(0,180,0,260); mainFrame.Visible = true

local titleLabel = Instance.new("TextLabel", mainFrame); titleLabel.Size=UDim2.new(1,0,0,30); titleLabel.BackgroundTransparency=1; titleLabel.Text="Sanji's Hub"; titleLabel.TextColor3=Color3.fromRGB(150, 0, 255); titleLabel.Font = Enum.Font.GothamBold

local statusLabel = Instance.new("TextLabel", mainFrame); statusLabel.Size = UDim2.new(1, 0, 0, 20); statusLabel.Position = UDim2.new(0,0,0.9,0); statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255); statusLabel.TextSize = 10; statusLabel.Font = Enum.Font.Gotham; statusLabel.Text = "Status: Idle"
local function updateStatus(msg) statusLabel.Text = msg end

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,35); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.MouseButton1Click:Connect(function() callback(btn) end)
    return btn
end

-- === BUTTONS ===

-- 1. DUNGEON MASTER (Default ON)
local dungeonBtn = createButton("DUNGEON: ON", 35, Color3.fromRGB(0,180,100), function(b)
    _G.DungeonMaster = not _G.DungeonMaster
    _G.VoidFarm = false 
    -- If we turn Dungeon ON, we usually want GodMode ON too
    if _G.DungeonMaster then _G.GodMode = true end
    
    b.BackgroundColor3 = _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60)
    b.Text = _G.DungeonMaster and "DUNGEON: ON" or "DUNGEON: OFF"
    updateStatus(_G.DungeonMaster and "Mode: Dungeon Master" or "Mode: Idle")
end)

-- 2. VOID FARM (Default OFF)
local voidBtn = createButton("VOID FARM: OFF", 80, Color3.fromRGB(200,60,60), function(b)
    _G.VoidFarm = not _G.VoidFarm
    _G.DungeonMaster = false 
    
    b.BackgroundColor3 = _G.VoidFarm and Color3.fromRGB(140,0,255) or Color3.fromRGB(200,60,60)
    b.Text = _G.VoidFarm and "VOID FARM: ON" or "VOID FARM: OFF"
    updateStatus(_G.VoidFarm and "Mode: Void Anti-Wall" or "Mode: Idle")
    
    if not _G.VoidFarm then blacklist = {}; currentTarget = nil end
end)

-- 3. GOD MODE (Default ON)
createButton("GOD MODE: ON", 125, Color3.fromRGB(255,170,0), function(b)
    _G.GodMode = not _G.GodMode
    b.BackgroundColor3 = _G.GodMode and Color3.fromRGB(255,170,0) or Color3.fromRGB(80,80,80)
    b.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF"
end)

-- 4. AUTO START (Default ON - Restored)
createButton("AUTO START: ON", 170, Color3.fromRGB(0,140,255), function(b)
    _G.AutoStart = not _G.AutoStart
    b.BackgroundColor3 = _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80)
    b.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF"
end)

-- ==============================================================================
-- 3. SHARED UTILITIES
-- ==============================================================================
local function enforceSpeed(hum) if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end end
local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then if ClickEvent then ClickEvent:FireServer(true) end lastMB1 = tick() end end

local function castSkills(target)
    autoClick() 
    if VirtualInputManager then
        for _, key in ipairs({"Q", "E", "R", "F"}) do 
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
        end
    end
end

-- ==============================================================================
-- 4. MASTER SCRIPT LOGIC (Dungeon)
-- ==============================================================================
local function getDungeonTarget()
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
        if string.find(n, "Everwisp") or string.find(n, "Everwhisp") then -- IGNORE
        elseif string.find(n, "Blizzard Elemental") or string.find(n, "Everfrost Elemental") then table.insert(blizzards, mob)
        elseif string.find(n, "Frostwind Progenitor") or string.find(n, "Bonechill Progenitor") then table.insert(progenitors, mob)
        elseif string.find(n, "Glacial Elemental") then table.insert(glacials, mob)
        elseif string.find(n, "Possessed Snowman") then table.insert(possessed, mob)
        elseif string.find(n, "Hoarfrost Colossus") then table.insert(colossuses, mob)
        else table.insert(trash, mob) end
    end

    if #blizzards > 0 then return blizzards[1], "KILL" end
    if #progenitors > 0 then
        local unvisited = {}
        for _, mob in ipairs(progenitors) do if not visitedMobs[mob] then table.insert(unvisited, mob) end end
        if #unvisited > 0 then
            table.sort(unvisited, function(a, b) return dist(a) < dist(b) end)
            return unvisited[1], "AGGRO"
        end
        if #glacials > 0 then return progenitors[1], "ANCHOR_TO_GLACIAL" end
        table.sort(progenitors, function(a, b) return dist(a) < dist(b) end)
        return progenitors[1], "KILL"
    end
    if #glacials > 0 then return glacials[1], "KILL_ANCHOR" end
    if #possessed > 0 then table.sort(possessed, function(a, b) return dist(a) < dist(b) end); return possessed[1], "KILL_ANCHOR" end
    if #colossuses > 0 then return colossuses[1], "KILL_12" end
    if #trash > 0 then return trash[1], "KILL" end
    return nil, "CLEAR"
end

local function runToDungeon(targetModel, mode)
    local char = player.Character; local root = char:WaitForChild("HumanoidRootPart"); local hum = char:WaitForChild("Humanoid"); local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then root.Anchored = false return end
    enforceSpeed(hum); local d = (root.Position - enemyRoot.Position).Magnitude
    
    if mode == "ANCHOR_TO_GLACIAL" then
        local glacial = nil
        for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Glacial Elemental" and v:FindFirstChild("HumanoidRootPart") then glacial = v; break end end
        if glacial then
            if (root.Position - glacial.HumanoidRootPart.Position).Magnitude < 20 then
                root.Anchored = true; root.CFrame = CFrame.new(root.Position, glacial.HumanoidRootPart.Position) 
                castSkills(targetModel); task.spawn(function() castSkills(glacial) end)
                updateStatus("ANCHORED @ GLACIAL")
            else
                root.Anchored = false; hum:MoveTo(glacial.HumanoidRootPart.Position); updateStatus("DRAGGING TO GLACIAL")
            end
            return
        else mode = "KILL" end
    end

    if mode == "KILL_ANCHOR" then
        if d < 25 then root.Anchored = true; root.CFrame = CFrame.new(root.Position, enemyRoot.Position); castSkills(targetModel); updateStatus("ANCHORED KILL"); return
        else root.Anchored = false; hum:MoveTo(enemyRoot.Position) end
    elseif mode == "KILL_12" then 
        if d < 12 then root.Anchored = true; root.CFrame = CFrame.new(root.Position, enemyRoot.Position); castSkills(targetModel); return
        elseif d > 14 then hum:MoveTo(enemyRoot.Position); root.Anchored = false
        else hum:MoveTo(root.Position); root.Anchored = true; root.CFrame = CFrame.new(root.Position, enemyRoot.Position); castSkills(targetModel); return end
    elseif mode == "AGGRO" then
        root.Anchored = false; updateStatus("AGGRO")
        if d < 25 then visitedMobs[targetModel] = true; return else hum:MoveTo(enemyRoot.Position) end
    else
        root.Anchored = false; updateStatus("KILLING")
        if d < 20 then hum:MoveTo(enemyRoot.Position); root.CFrame = CFrame.new(root.Position, enemyRoot.Position); castSkills(targetModel)
        else
            local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true}); pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)
            if path.Status == Enum.PathStatus.Success then
                for _, wp in ipairs(path:GetWaypoints()) do
                    if not _G.DungeonMaster then break end
                    if wp.Position.Y > root.Position.Y + 4.5 then hum.Jump = true end
                    hum:MoveTo(wp.Position); autoClick()
                    local stuck = 0; while (root.Position - wp.Position).Magnitude > 4 do RunService.Heartbeat:Wait(); stuck = stuck + 1; if stuck > 60 then hum.Jump = true return end end
                    if mode == "AGGRO" and (root.Position - enemyRoot.Position).Magnitude < 30 then visitedMobs[targetModel] = true; return end
                end
            else hum:MoveTo(enemyRoot.Position) end
        end
    end
end

-- ==============================================================================
-- 5. VOID SCRIPT LOGIC (Strict Anti-Wall)
-- ==============================================================================
local function getVoidTarget()
    local char = player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPos = char.HumanoidRootPart.Position
    local strongboxes = {}; local everythingElse = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Health > 0 and v.Parent and v.Parent:FindFirstChild("HumanoidRootPart") then
            local mob = v.Parent
            if not blacklist[mob] and not Players:GetPlayerFromCharacter(mob) then
                local dist = (rootPos - mob.HumanoidRootPart.Position).Magnitude
                if mob.Name == "Abyssal Strongbox" then table.insert(strongboxes, {Mob = mob, Dist = dist})
                else table.insert(everythingElse, {Mob = mob, Dist = dist}) end
            end
        end
    end
    if #strongboxes > 0 then table.sort(strongboxes, function(a, b) return a.Dist < b.Dist end); return strongboxes[1].Mob end
    if #everythingElse > 0 then table.sort(everythingElse, function(a, b) return a.Dist < b.Dist end); return everythingElse[1].Mob end
    return nil
end

local function runToVoid(target)
    local char = player.Character; local root = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChild("Humanoid"); local enemyRoot = target:FindFirstChild("HumanoidRootPart")
    if not root or not hum or not enemyRoot then return end
    if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end
    updateStatus("Void Target: " .. target.Name)
    local dist = (root.Position - enemyRoot.Position).Magnitude

    if (root.Position - lastPos).Magnitude < 0.5 then
        stuckTimer = stuckTimer + 1
        if stuckTimer > 15 then hum.Jump = true; blacklist[target] = true; currentTarget = nil; stuckTimer = 0; return end
    else stuckTimer = 0 end
    lastPos = root.Position

    if dist < (_G.AttackRange - 5) then hum:MoveTo(root.Position); return end 

    root.Anchored = false
    local path = PathfindingService:CreatePath({AgentRadius = 4, AgentCanJump = true}) 
    local success, _ = pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)

    if success and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not _G.VoidFarm then break end
            if not target.Parent or target.Humanoid.Health <= 0 then break end
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position)
            local timeout = 0
            while (root.Position - wp.Position).Magnitude > 4 do
                RunService.Heartbeat:Wait(); timeout = timeout + 1; if timeout > 120 then hum.Jump = true; break end
                local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {char}
                local forwardRay = workspace:Raycast(root.Position, root.CFrame.LookVector * 2, rayParams)
                if forwardRay then hum.Jump = true end
                if (root.Position - enemyRoot.Position).Magnitude < (_G.AttackRange - 5) then hum:MoveTo(root.Position); return end
            end
        end
    else
        blacklist[target] = true; updateStatus("Wall/Unreachable: " .. target.Name); currentTarget = nil
    end
end

-- ==============================================================================
-- 6. SPLIT-BRAIN COMBAT (For Void Mode)
-- ==============================================================================
task.spawn(function()
    while true do
        task.wait()
        if _G.VoidFarm and currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("HumanoidRootPart") and currentTarget.Humanoid.Health > 0 then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                local enemyRoot = currentTarget.HumanoidRootPart
                local dist = (root.Position - enemyRoot.Position).Magnitude
                if dist < _G.AttackRange then
                    root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
                    if ClickEvent then ClickEvent:FireServer(true) end
                    if VirtualInputManager then
                        for _, key in ipairs({"Q", "E", "R", "F"}) do 
                            if not currentTarget or currentTarget.Humanoid.Health <= 0 then break end
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
                        end
                    end
                end
            end
        else
            task.wait(0.1)
        end
    end
end)

-- ==============================================================================
-- 7. MAIN EXECUTION LOOPS
-- ==============================================================================

-- Dungeon Auto Start
task.spawn(function() 
    while true do 
        task.wait(1) 
        if _G.DungeonMaster and _G.AutoStart and not hasStarted then 
            local r = ReplicatedStorage:FindFirstChild("Start") 
            if r then pcall(function() r:FireServer() end) hasStarted = true end 
        end 
    end 
end)

-- Main Logic Router
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        
        -- MODE 1: DUNGEON MASTER
        if _G.DungeonMaster then
            pcall(function()
                local t, m = getDungeonTarget()
                if t then 
                    runToDungeon(t, m) 
                else 
                    visitedMobs = {}
                    local gates = {}
                    for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Gate" or v.Name == "Portal" then table.insert(gates, v) end end
                    if #gates > 0 then updateStatus("EXITING DUNGEON"); runToDungeon({HumanoidRootPart = gates[1], Name = "Gate"}, "KILL") else updateStatus("DUNGEON SCANNING...") end
                end
            end)
            
        -- MODE 2: VOID FARM
        elseif _G.VoidFarm then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                if currentTarget and (not currentTarget.Parent or not currentTarget:FindFirstChild("Humanoid") or currentTarget.Humanoid.Health <= 0) then currentTarget = nil end
                if not currentTarget then currentTarget = getVoidTarget() end
                if currentTarget then runToVoid(currentTarget) else updateStatus("VOID SCANNING...") end
            end
        end
    end
end)

print("[Sanji] Unified Hub: Final Default Build Loaded")
