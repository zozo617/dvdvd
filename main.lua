local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- Universal Request Detection for Mobile Executors
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- Wait for inventory to load
repeat task.wait() until workspace:FindFirstChild("Inventories")
repeat task.wait() until workspace.Inventories:FindFirstChild(player.Name)
local Inventory = workspace.Inventories[player.Name]

-- ==============================================================================
-- 0. CONFIGURATION
-- ==============================================================================
_G.DungeonMaster = true 
_G.AutoStart = true        
_G.GodMode = true      
local webhookUrl = "https://discord.com/api/webhooks/1446663395980873830/XIzk9dyFM1FOnggrSjTevw_nGonsWlc3P9lrDVLsoLg-oE3U6jU5iEedFp2oU8D_sotR" 

-- Internal Variables
local visitedMobs = {} 
local lastMB1 = 0             
local MB1_COOLDOWN = 0.25 
local lastMoveTime = tick()
local lastPosition = Vector3.new(0,0,0)
local hasStarted = false

-- THE CLICK REMOTE
local ClickEvent = ReplicatedStorage:WaitForChild("Click")

-- ==============================================================================
-- 1. GOD MODE HOOK
-- ==============================================================================
task.spawn(function()
    pcall(function()
        local DamageRemote = ReplicatedStorage:WaitForChild("Damage", 10)
        local hookmetamethod = hookmetamethod or getgenv().hookmetamethod
        if hookmetamethod and DamageRemote then
            local OldNameCall
            OldNameCall = hookmetamethod(game, "__namecall", newcclosure(function(Self, ...)
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
if player.PlayerGui:FindFirstChild("SanjiScript") then 
    player.PlayerGui.SanjiScript:Destroy() 
end
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SanjiScript"
screenGui.Parent = player.PlayerGui

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then 
                    dragging = false 
                end 
            end) 
        end 
    end)
    guiObject.InputChanged:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then 
            dragInput = input 
        end 
    end)
    UserInputService.InputChanged:Connect(function(input) 
        if input == dragInput and dragging then 
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
        end 
    end)
end

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Name = "MainFrame"
mainFrame.BackgroundColor3 = Color3.fromRGB(15,15,20)
mainFrame.Position = UDim2.new(0.7,0,0.25,0)
mainFrame.Size = UDim2.new(0,170,0,160)
makeDraggable(mainFrame)
mainFrame.Visible = false 

local houseBtn = Instance.new("ImageButton", screenGui)
houseBtn.Name = "HomeBtn"
houseBtn.BackgroundColor3 = Color3.fromRGB(20,20,20)
houseBtn.Position = UDim2.new(0.9,0,0.15,0)
houseBtn.Size = UDim2.new(0,55,0,55)
houseBtn.Image = "rbxassetid://138612143003295" 
Instance.new("UICorner", houseBtn).CornerRadius = UDim.new(0, 12)
local houseStroke = Instance.new("UIStroke", houseBtn)
houseStroke.Color = Color3.fromRGB(150, 0, 255)
houseStroke.Thickness = 1.5
makeDraggable(houseBtn)
houseBtn.MouseButton1Click:Connect(function() 
    mainFrame.Visible = not mainFrame.Visible 
end)

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1,0,0,30)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Sanji's Script"
titleLabel.TextColor3 = Color3.fromRGB(150, 0, 255)
titleLabel.Font = Enum.Font.GothamBold

local statusFrame = Instance.new("Frame", screenGui)
statusFrame.Name = "StatusCenter"
statusFrame.Size = UDim2.new(0, 400, 0, 35)
statusFrame.Position = UDim2.new(0.5, 0, 0.35, 0) 
statusFrame.AnchorPoint = Vector2.new(0.5, 0)
statusFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
statusFrame.BackgroundTransparency = 0.3
statusFrame.BorderSizePixel = 0
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 8)

local statusLabel = Instance.new("TextLabel", statusFrame)
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextSize = 18
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = "Waiting..."

local function updateStatus(msg) 
    statusLabel.Text = msg 
end

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame)
    btn.BackgroundColor3 = color
    btn.Position = UDim2.new(0.05,0,0,pos)
    btn.Size = UDim2.new(0.9,0,0,30)
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.MouseButton1Click:Connect(function() 
        callback(btn) 
    end)
end

createButton("AUTO FARM: ON", 40, Color3.fromRGB(0,180,100), function(b) 
    _G.DungeonMaster = not _G.DungeonMaster
    b.BackgroundColor3 = _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60)
    b.Text = _G.DungeonMaster and "AUTO FARM: ON" or "AUTO FARM: OFF" 
end)

createButton("AUTO START: ON", 80, Color3.fromRGB(0,140,255), function(b) 
    _G.AutoStart = not _G.AutoStart
    b.BackgroundColor3 = _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80)
    b.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF" 
end)

createButton("GOD MODE: ON", 120, Color3.fromRGB(140,0,255), function(b) 
    _G.GodMode = not _G.GodMode
    b.BackgroundColor3 = _G.GodMode and Color3.fromRGB(140,0,255) or Color3.fromRGB(80,80,80)
    b.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF" 
end)

-- ==============================================================================
-- 3. UTILITY & COMBAT
-- ==============================================================================
local function enforceSpeed(hum) 
    if hum.WalkSpeed < 26 then 
        hum.WalkSpeed = 26 
    end 
end

local function autoClick() 
    if tick() - lastMB1 > MB1_COOLDOWN then 
        ClickEvent:FireServer(true) 
        lastMB1 = tick() 
    end 
end

local function castSkills(targetModel)
    autoClick() 
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then return end
    
    local dist = (root.Position - enemyRoot.Position).Magnitude
    local name = targetModel.Name
    local requiredDist = (string.find(name, "Colossus") or string.find(name, "Boss") or string.find(name, "Snowman")) and 50 or 18
    if dist > requiredDist then return end 
    
    if string.find(name, "Colossus") or string.find(name, "Snowman") or string.find(name, "Boss") or string.find(name, "Progenitor") or string.find(name, "Possessed") or string.find(name, "Elemental") or string.find(name, "Sorcerer") or string.find(name, "Spruced") then 
        for _, key in ipairs({"Q", "E", "R", "F"}) do 
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game) 
            task.wait() 
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game) 
        end 
    end
end

-- ==============================================================================
-- 4. TARGETING & NAVIGATION
-- ==============================================================================
local function getNextTarget()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    local progenitors, bosses, glacials, runners = {}, {}, {}, {}
    for mob, _ in pairs(visitedMobs) do if not mob or not mob.Parent or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0) then visitedMobs[mob] = nil end end
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= player.Character and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then
            local mob = v.Parent; local name = mob.Name
            if not string.find(name, "Frostwoven") and not string.find(name, "Gate") then 
                if string.find(name, "Progenitor") then table.insert(progenitors, mob)
                elseif string.find(name, "Snowman") or string.find(name, "Colossus") or string.find(name, "Boss") or string.find(name, "Possessed") or string.find(name, "Elemental") or string.find(name, "Sorcerer") then table.insert(bosses, mob)
                elseif string.find(name, "Glacial") then table.insert(glacials, mob)
                else table.insert(runners, mob) end
            end
        end
    end
    table.sort(progenitors, function(a,b) return (char.HumanoidRootPart.Position - a.HumanoidRootPart.Position).Magnitude < (char.HumanoidRootPart.Position - b.HumanoidRootPart.Position).Magnitude end)
    if #progenitors > 0 then return progenitors[1], "KILL" end
    local possessedSnowman = nil
    for _, boss in ipairs(bosses) do if string.find(boss.Name, "Possessed") then possessedSnowman = boss break end end
    if possessedSnowman then
        for _, runner in ipairs(runners) do if not visitedMobs[runner] and (runner.HumanoidRootPart.Position - possessedSnowman.HumanoidRootPart.Position).Magnitude < 150 then return runner, "AGGRO" end end
        return possessedSnowman, "KILL"
    end
    if #bosses > 0 then return bosses[1], "KILL" end
    for _, r in ipairs(runners) do if not visitedMobs[r] then return r, "AGGRO" end end
    return nil, "CLEAR"
end

local function runTo(targetModel, mode)
    local char = player.Character; local root = char:WaitForChild("HumanoidRootPart"); local hum = char:WaitForChild("Humanoid"); local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then root.Anchored = false return end
    enforceSpeed(hum); local dist = (root.Position - enemyRoot.Position).Magnitude
    if mode == "KILL" and string.find(targetModel.Name, "Spruced") and dist < 18 then
        root.Anchored = true; root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(targetModel); updateStatus("ANCHORED: Melting " .. targetModel.Name); return
    else root.Anchored = false end
    if dist < 20 then hum:MoveTo(enemyRoot.Position); root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(targetModel) else
        local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true}); pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)
        if path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if not _G.DungeonMaster then break end
                if wp.Position.Y > root.Position.Y + 4.5 then hum.Jump = true end
                hum:MoveTo(wp.Position); autoClick()
                local stuck = 0; while (root.Position - wp.Position).Magnitude > 4 do RunService.Heartbeat:Wait(); stuck = stuck + 1; if stuck > 60 then hum.Jump = true return end end
            end
        else hum:MoveTo(enemyRoot.Position) end
    end
end

-- ==============================================================================
-- 5. WEBHOOK SYSTEM (DELTA OPTIMIZED)
-- ==============================================================================
local function sendInventoryUpdate()
    local success, err = pcall(function()
        if not Inventory or not Inventory.Parent then return end
        if not httpRequest then warn("[Webhook] Executor does not support HTTP requests") return end
        
        local levelInfo = string.format("Level: %d\nXP: %d/%d\n", Inventory.Level.Value, Inventory.Experience.Value, Inventory.ExperienceNeeded.Value)
        local itemCounts = {}
        if Inventory.Items then
            for _, item in pairs(Inventory.Items:GetChildren()) do
                if item:IsA("StringValue") then
                    local itemId = string.split(item.Value, ",")[1]
                    itemCounts[itemId] = (itemCounts[itemId] or 0) + 1
                end
            end
        end

        local inventoryList = "\n=== INVENTORY ===\n"
        for name, count in pairs(itemCounts) do inventoryList = inventoryList .. string.format("%dx %s\n", count, name) end
        
        local data = { ["content"] = levelInfo .. inventoryList }
        return httpRequest({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- ==============================================================================
-- 6. LOOPS
-- ==============================================================================
task.spawn(function() 
    while true do 
        task.wait(1)
        if _G.AutoStart and not hasStarted then 
            local startRemote = ReplicatedStorage:FindFirstChild("Start")
            if startRemote then 
                pcall(function() startRemote:FireServer() end)
                hasStarted = true; updateStatus("START TRIGGERED")
            end 
        end 
    end 
end)

task.spawn(function() 
    while true do 
        if _G.DungeonMaster then 
            RunService.Heartbeat:Wait()
            pcall(function() 
                local target, mode = getNextTarget()
                if target then runTo(target, mode) end 
            end) 
        else task.wait(1) end 
    end 
end)

task.spawn(function() 
    task.wait(5); sendInventoryUpdate()
    while true do task.wait(300); sendInventoryUpdate() end 
end)

print("[Script] Loaded successfully!")
