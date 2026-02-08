local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. CONFIGURATION
-- ==============================================================================
_G.DungeonMaster = true 
_G.AutoStart = true        
_G.GodMode = true      

-- Internal Variables
local visitedMobs = {} 
local lastMB1 = 0             
local MB1_COOLDOWN = 0.1 
local ClickEvent = ReplicatedStorage:WaitForChild("Click")
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
-- 2. UI SETUP
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiScript") then player.PlayerGui.SanjiScript:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiScript"

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = guiObject.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart; guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
end

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(15,15,20); mainFrame.Position=UDim2.new(0.7,0,0.25,0); mainFrame.Size=UDim2.new(0,170,0,160); makeDraggable(mainFrame); mainFrame.Visible = false 
local houseBtn = Instance.new("ImageButton", screenGui); houseBtn.Name="HomeBtn"; houseBtn.BackgroundColor3=Color3.fromRGB(20,20,20); houseBtn.Position=UDim2.new(0.9,0,0.15,0); houseBtn.Size=UDim2.new(0,55,0,55); houseBtn.Image = "rbxassetid://138612143003295" 
Instance.new("UICorner", houseBtn).CornerRadius = UDim.new(0, 12); local houseStroke = Instance.new("UIStroke", houseBtn); houseStroke.Color = Color3.fromRGB(150, 0, 255); houseStroke.Thickness = 1.5; makeDraggable(houseBtn); houseBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

local titleLabel = Instance.new("TextLabel", mainFrame); titleLabel.Size=UDim2.new(1,0,0,30); titleLabel.BackgroundTransparency=1; titleLabel.Text="Sanji's Script"; titleLabel.TextColor3=Color3.fromRGB(150, 0, 255); titleLabel.Font = Enum.Font.GothamBold
local statusFrame = Instance.new("Frame", screenGui); statusFrame.Size = UDim2.new(0, 400, 0, 35); statusFrame.Position = UDim2.new(0.5, 0, 0.35, 0); statusFrame.AnchorPoint = Vector2.new(0.5, 0); statusFrame.BackgroundColor3 = Color3.fromRGB(0,0,0); statusFrame.BackgroundTransparency = 0.3; Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 8)
local statusLabel = Instance.new("TextLabel", statusFrame); statusLabel.Size = UDim2.new(1, 0, 1, 0); statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255); statusLabel.TextSize = 18; statusLabel.Font = Enum.Font.GothamBold; statusLabel.Text = "Waiting..."
local function updateStatus(msg) statusLabel.Text = msg end

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,30); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.MouseButton1Click:Connect(function() callback(btn) end)
end

createButton("AUTO FARM: ON", 40, Color3.fromRGB(0,180,100), function(b) _G.DungeonMaster = not _G.DungeonMaster; b.BackgroundColor3 = _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60); b.Text = _G.DungeonMaster and "AUTO FARM: ON" or "AUTO FARM: OFF" end)
createButton("AUTO START: ON", 80, Color3.fromRGB(0,140,255), function(b) _G.AutoStart = not _G.AutoStart; b.BackgroundColor3 = _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80); b.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF" end)
createButton("GOD MODE: ON", 120, Color3.fromRGB(140,0,255), function(b) _G.GodMode = not _G.GodMode; b.BackgroundColor3 = _G.GodMode and Color3.fromRGB(140,0,255) or Color3.fromRGB(80,80,80); b.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF" end)

-- ==============================================================================
-- 3. UTILITY & COMBAT
-- ==============================================================================
local function enforceSpeed(hum) if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end end
local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then ClickEvent:FireServer(true); lastMB1 = tick() end end

local function castSkills(targetModel)
    autoClick() 
    for _, key in ipairs({"Q", "E", "R", "F"}) do 
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
    end
end

-- ==============================================================================
-- 4. TARGETING LOGIC (CHAIN REACTION)
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

    -- === SORT MOBS ===
    local blizzards, progenitors, glacials, possessed, colossuses, trash = {}, {}, {}, {}, {}, {}
    
    for _, mob in ipairs(allMobs) do
        local n = mob.Name
        if string.find(n, "Everwisp") or string.find(n, "Everwhisp") then -- IGNORE
        elseif string.find(n, "Blizzard Elemental") or string.find(n, "Everfrost Elemental") then table.insert(blizzards, mob)
        elseif string.find(n, "Frostwind Progenitor") or string.find(n, "Bonechill Progenitor") then table.insert(progenitors, mob)
        elseif string.find(n, "Glacial Elemental") then table.insert(glacials, mob)
        elseif string.find(n, "Possessed Snowman") then table.insert(possessed, mob)
        elseif string.find(n, "Hoarfrost Colossus") then table.insert(colossuses, mob)
        else
            table.insert(trash, mob) 
        end
    end

    -- === PRIORITY CHAIN ===

    -- 1. BLIZZARD ELEMENTAL (THE TRIGGER)
    if #blizzards > 0 then return blizzards[1], "KILL" end

    -- 2. PROGENITORS (AGGRO -> DRAG TO GLACIAL)
    if #progenitors > 0 then
        local unvisited = {}
        for _, mob in ipairs(progenitors) do
            if not visitedMobs[mob] then table.insert(unvisited, mob) end
        end
        
        -- AGGRO ALL FIRST
        if #unvisited > 0 then
            table.sort(unvisited, function(a, b) return dist(a) < dist(b) end)
            return unvisited[1], "AGGRO"
        end
        
        -- KILL PHASE: Drag to Glacial if exists
        if #glacials > 0 then
            return progenitors[1], "ANCHOR_TO_GLACIAL" 
        end
        
        table.sort(progenitors, function(a, b) return dist(a) < dist(b) end)
        return progenitors[1], "KILL"
    end

    -- 3. GLACIAL ELEMENTAL (THE ANCHOR)
    if #glacials > 0 then return glacials[1], "KILL_ANCHOR" end

    -- 4. POSSESSED SNOWMAN (CLOSEST FIRST)
    if #possessed > 0 then
        table.sort(possessed, function(a, b) return dist(a) < dist(b) end)
        return possessed[1], "KILL_ANCHOR" -- Standard Anchor
    end

    -- 5. FALLBACKS
    if #colossuses > 0 then return colossuses[1], "KILL_12" end
    if #trash > 0 then return trash[1], "KILL" end

    return nil, "CLEAR"
end

local function runTo(targetModel, mode)
    local char = player.Character; local root = char:WaitForChild("HumanoidRootPart"); local hum = char:WaitForChild("Humanoid"); local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then root.Anchored = false return end
    enforceSpeed(hum); local d = (root.Position - enemyRoot.Position).Magnitude
    
    -- === MOVEMENT MODES ===
    
    if mode == "ANCHOR_TO_GLACIAL" then
        local glacial = nil
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "Glacial Elemental" and v:FindFirstChild("HumanoidRootPart") then
                glacial = v
                break
            end
        end

        if glacial then
            local distToGlacial = (root.Position - glacial.HumanoidRootPart.Position).Magnitude

            -- PROXIMITY CHECK (20 studs)
            if distToGlacial < 20 then
                root.Anchored = true
                root.CFrame = CFrame.new(root.Position, glacial.HumanoidRootPart.Position) 
                
                castSkills(targetModel) 
                task.spawn(function() castSkills(glacial) end)
                
                updateStatus("ANCHORED @ GLACIAL: Melting Swarm")
                return
            else
                root.Anchored = false
                hum:MoveTo(glacial.HumanoidRootPart.Position)
                updateStatus("DRAGGING: Running to Glacial")
            end
            return
        else
            mode = "KILL" 
        end
    end

    if mode == "KILL_ANCHOR" then
        if d < 25 then 
            root.Anchored = true
            root.CFrame = CFrame.new(root.Position, enemyRoot.Position)
            castSkills(targetModel)
            updateStatus("ANCHORED: " .. targetModel.Name)
            return
        else 
            root.Anchored = false 
            updateStatus("CHASING: " .. targetModel.Name) 
        end
    
    elseif mode == "KILL_12" then 
        if d < 12 then
            root.Anchored = true; root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(targetModel); updateStatus("RANGE (12): " .. targetModel.Name); return
        elseif d > 14 then
             hum:MoveTo(enemyRoot.Position); root.Anchored = false; updateStatus("CHASING (12): " .. targetModel.Name)
        else
             hum:MoveTo(root.Position); root.Anchored = true; root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(targetModel); updateStatus("RANGE (12): " .. targetModel.Name); return
        end
        return

    elseif mode == "AGGRO" then
        root.Anchored = false; updateStatus("AGGRO: " .. targetModel.Name)
        if d < 25 then 
            visitedMobs[targetModel] = true 
            return 
        else
            hum:MoveTo(enemyRoot.Position)
        end
    else
        root.Anchored = false; updateStatus("KILLING: " .. targetModel.Name)
    end

    if d < 20 and mode ~= "AGGRO" and not string.find(mode, "KILL_") then 
        hum:MoveTo(enemyRoot.Position); root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(targetModel)
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

-- ==============================================================================
-- 5. LOOPS
-- ==============================================================================
task.spawn(function() while true do task.wait(1) if _G.AutoStart and not hasStarted then local r = ReplicatedStorage:FindFirstChild("Start") if r then pcall(function() r:FireServer() end) hasStarted = true; updateStatus("START TRIGGERED") end end end end)
task.spawn(function() while true do if _G.DungeonMaster then RunService.Heartbeat:Wait(); pcall(function() local t, m = getNextTarget(); if t then runTo(t, m) else 
    visitedMobs = {} -- Reset visited
    local gates = {}
    for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Gate" or v.Name == "Portal" then table.insert(gates, v) end end
    if #gates > 0 then updateStatus("EXITING"); runTo({HumanoidRootPart = gates[1], Name = "Gate"}, "KILL") else updateStatus("SCANNING...") end
end end) else task.wait(1) end end end)

print("[Script] Sanji's Final Clean Build Loaded")
