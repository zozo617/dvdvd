local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. CONFIGURATION & STATE
-- ==============================================================================
-- Default Values (Will be overwritten by LoadSettings)
_G.DungeonMaster = true  
_G.AutoStart = true      
_G.GodMode = true        
_G.AutoSell = true       

-- [AUTO SELL SETTINGS]
local SellSettings = {
    Types = {
        ["Weapon"]   = true,
        ["Leggings"] = true,
        ["Armor"]    = true,
        ["Helmet"]   = true,
        ["Emblem"]   = false, 
        ["Spell"]    = true
    },
    Rarities = {
        [1] = true,  -- Common
        [2] = true,  -- Uncommon
        [3] = true,  -- Rare
        [4] = true,  -- Epic
        [5] = false, -- Legendary
        [6] = false, -- Mythic
        [7] = false  -- Fabled 
    }
}

-- [SETTINGS SYSTEM]
local SettingsFileName = "SanjiHubSettings.json"

local function SaveSettings()
    local data = {
        DungeonMaster = _G.DungeonMaster,
        AutoStart = _G.AutoStart,
        GodMode = _G.GodMode,
        AutoSell = _G.AutoSell,
        SellConfig = SellSettings
    }
    pcall(function()
        writefile(SettingsFileName, HttpService:JSONEncode(data))
    end)
end

local function LoadSettings()
    if isfile and isfile(SettingsFileName) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(SettingsFileName))
        end)
        if success and result then
            if result.DungeonMaster ~= nil then _G.DungeonMaster = result.DungeonMaster end
            if result.AutoStart ~= nil then _G.AutoStart = result.AutoStart end
            if result.GodMode ~= nil then _G.GodMode = result.GodMode end
            if result.AutoSell ~= nil then _G.AutoSell = result.AutoSell end
            if result.SellConfig then 
                for k, v in pairs(result.SellConfig.Types or {}) do SellSettings.Types[k] = v end
                for k, v in pairs(result.SellConfig.Rarities or {}) do SellSettings.Rarities[tonumber(k)] = v end
            end
        end
    end
end

-- Load settings immediately
LoadSettings()

-- [WEBHOOK SETTINGS]
local webhookUrl = "https://discord.com/api/webhooks/1446663395980873830/XIzk9dyFM1FOnggrSjTevw_nGonsWlc3P9lrDVLsoLg-oE3U6jU5iEedFp2oU8D_sotR"

-- [PERSISTENT RUN TRACKER]
local RunFileName = "SanjiRuns.txt"
local totalRuns = 0

local success, err = pcall(function()
    if isfile and isfile(RunFileName) then
        totalRuns = tonumber(readfile(RunFileName)) or 0
    end
    totalRuns = totalRuns + 1
    if writefile then
        writefile(RunFileName, tostring(totalRuns))
    end
end)
if not success then warn("Failed to save runs: " .. tostring(err)) end

local visitedMobs = {} 
local lastMB1 = 0              
local MB1_COOLDOWN = 0.1 
local ClickEvent = ReplicatedStorage:WaitForChild("Click")
local hasStarted = false
local lastPos = Vector3.new(0,0,0) 
local stuckCount = 0

-- Wait for inventory to load
task.spawn(function()
    repeat task.wait() until workspace:FindFirstChild("Inventories")
    repeat task.wait() until workspace.Inventories:FindFirstChild(player.Name)
end)

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
-- 2. UI SETUP (MOBILE DRAGGABLE)
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiUnified") then player.PlayerGui.SanjiUnified:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiUnified"

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = guiObject.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local mainFrame = Instance.new("Frame", screenGui); mainFrame.BackgroundColor3=Color3.fromRGB(15,15,20); mainFrame.Position=UDim2.new(0.5, -90, 0.3, 0); mainFrame.Size=UDim2.new(0,180,0,260); mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10); makeDraggable(mainFrame)

local statusFrame = Instance.new("Frame", screenGui); statusFrame.Size = UDim2.new(0, 200, 0, 30); statusFrame.AnchorPoint = Vector2.new(0.5, 0); statusFrame.Position = UDim2.new(0.5, 0, 0.75, 0); statusFrame.BackgroundColor3 = Color3.fromRGB(0,0,0); statusFrame.BackgroundTransparency = 0.5
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 6); makeDraggable(statusFrame)

local statusLabel = Instance.new("TextLabel", statusFrame); statusLabel.Size = UDim2.new(1, 0, 1, 0); statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255); statusLabel.TextSize = 14; statusLabel.Font = Enum.Font.GothamBold; statusLabel.Text = "Status: Idle"
local function updateStatus(msg) statusLabel.Text = msg end

local hideBtn = Instance.new("TextButton", screenGui); hideBtn.Position = UDim2.new(0.9, -50, 0.15, 0); hideBtn.Size = UDim2.new(0, 45, 0, 45); hideBtn.Text = "UI"; hideBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 255); hideBtn.TextColor3 = Color3.new(1,1,1); hideBtn.Font = Enum.Font.GothamBold; Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 8); makeDraggable(hideBtn)
hideBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,35); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.MouseButton1Click:Connect(function() callback(btn) end)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

-- Create buttons with Initial State Check
createButton(
    _G.DungeonMaster and "AUTO FARM: ON" or "AUTO FARM: OFF", 
    35, 
    _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60), 
    function(b) 
        _G.DungeonMaster = not _G.DungeonMaster
        b.BackgroundColor3 = _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60)
        b.Text = _G.DungeonMaster and "AUTO FARM: ON" or "AUTO FARM: OFF"
        SaveSettings()
    end
)

createButton(
    _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF", 
    80, 
    _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80), 
    function(b) 
        _G.AutoStart = not _G.AutoStart
        b.BackgroundColor3 = _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80)
        b.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF"
        SaveSettings()
    end
)

createButton(
    _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF", 
    125, 
    _G.GodMode and Color3.fromRGB(140,0,255) or Color3.fromRGB(80,80,80), 
    function(b) 
        _G.GodMode = not _G.GodMode
        b.BackgroundColor3 = _G.GodMode and Color3.fromRGB(140,0,255) or Color3.fromRGB(80,80,80)
        b.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF"
        SaveSettings()
    end
)

createButton(
    _G.AutoSell and "AUTO SELL: ON" or "AUTO SELL: OFF", 
    170, 
    _G.AutoSell and Color3.fromRGB(255,100,0) or Color3.fromRGB(80,80,80), 
    function(b) 
        _G.AutoSell = not _G.AutoSell
        b.BackgroundColor3 = _G.AutoSell and Color3.fromRGB(255,100,0) or Color3.fromRGB(80,80,80)
        b.Text = _G.AutoSell and "AUTO SELL: ON" or "AUTO SELL: OFF"
        SaveSettings()
    end
)

-- ==============================================================================
-- 3. COMBAT & NAVIGATION UTILITY
-- ==============================================================================
local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then ClickEvent:FireServer(true); lastMB1 = tick() end end
local function castSkills()
    autoClick() 
    for _, key in ipairs({"Q", "E", "R", "F"}) do 
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
    end
end

-- WALL JUMP (For Stairs)
local function checkWallAndJump()
    local char = player.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local params = RaycastParams.new(); params.FilterDescendantsInstances = {char}
    local forward = root.CFrame.LookVector
    local legRay = workspace:Raycast(root.Position - Vector3.new(0, 2, 0), forward * 3, params)
    local headRay = workspace:Raycast(root.Position + Vector3.new(0, 1, 0), forward * 3, params)

    if legRay and not headRay then char.Humanoid.Jump = true end
end

-- HELPER: Abbreviate Numbers
local function abbreviateNumber(n)
    if n >= 1000000 then
        local val = n / 1000000
        return string.format("%.2fm", val):gsub("%.00m", "m"):gsub("%.(%d)0m", ".%1m")
    elseif n >= 1000 then
        local val = n / 1000
        return string.format("%.2fk", val):gsub("%.00k", "k"):gsub("%.(%d)0k", ".%1k")
    else
        return tostring(n)
    end
end

-- ==============================================================================
-- 4. AUTO SELL LOGIC
-- ==============================================================================
local function getEquippedAndPinnedItems()
    local equipped = {}
    local playerInventory = Workspace.Inventories:FindFirstChild(player.Name)
    if not playerInventory then return {} end
    
    local slots = {"Weapon", "Leggings", "Armor", "Helmet", "Emblem", "Spell1", "Spell2"}
    
    for _, slot in ipairs(slots) do
        local equippedItem = playerInventory:FindFirstChild(slot)
        if equippedItem and equippedItem:IsA("StringValue") then
            equipped[equippedItem.Value] = true
        end
    end
    
    if playerInventory:FindFirstChild("Items") then
        for _, item in pairs(playerInventory.Items:GetChildren()) do
            if item:IsA("StringValue") then
                local values = item.Value:split(",")
                if values[#values] == "1" then
                    equipped[item.Name] = true
                end
            end
        end
    end
    return equipped
end

local function runAutoSell()
    local playerInv = Workspace.Inventories:FindFirstChild(player.Name)
    if not playerInv or not playerInv:FindFirstChild("Items") then return end
    
    local itemsFolder = playerInv.Items
    local equippedItems = getEquippedAndPinnedItems()
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item:IsA("StringValue") then
            local itemData = item.Value:split(",")
            local itemName = itemData[1]
            local itemRarity = tonumber(itemData[2])
            
            if not equippedItems[item.Name] and SellSettings.Rarities[itemRarity] then
                local itemInfo = Workspace.Items:FindFirstChild(itemName)
                if itemInfo and itemInfo:FindFirstChild("Info") then
                    local itemType = itemInfo.Info.Value:split(",")[1]
                    
                    if SellSettings.Types[itemType] then
                        local args = { [1] = { [1] = item.Name } }
                        local sellRemote = ReplicatedStorage:FindFirstChild("SellItem")
                        if sellRemote then
                            sellRemote:FireServer(unpack(args))
                            task.wait(0.1) 
                        end
                    end
                end
            end
        end
    end
end

-- ==============================================================================
-- 5. TARGETING (ABSOLUTE COLOSSUS PRIORITY + CLEANUP)
-- ==============================================================================
local function getNextTarget()
    local char = player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    local rootPos = char.HumanoidRootPart.Position
    local elites = {}
    local normals = {} 
    local priorityBoss = nil
    local unvisitedFrostwinds = {}
    local bonechill = nil

    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then
            local mob = v.Parent
            local n = mob.Name
            
            if not Players:GetPlayerFromCharacter(mob) then
                -- LEVEL 0: ABSOLUTE PRIORITY (Ignores EVERYTHING else instantly)
                if string.find(n, "Arctic Colossus") then
                    return mob, "KILL" 
                
                -- LEVEL 1: OTHER BOSSES
                elseif string.find(n, "Blizzard") or string.find(n, "Everfrost") then
                    priorityBoss = mob
                    
                -- LEVEL 2: BONECHILL
                elseif string.find(n, "Bonechill Progenitor") then 
                    bonechill = mob 
                    
                -- LEVEL 3: FROSTWIND
                elseif string.find(n, "Frostwind Progenitor") then
                    if not visitedMobs[mob] then table.insert(unvisitedFrostwinds, mob) end
                    
                -- LEVEL 4: ELITES
                elseif string.find(n, "Possessed Snowman") or string.find(n, "Glacial Elemental") then
                    table.insert(elites, mob)
                    
                -- LEVEL 5: NORMAL MOBS (Cleanup)
                else
                    table.insert(normals, mob)
                end
            end
        end
    end
    
    if priorityBoss then return priorityBoss, "KILL" end
    if bonechill then return bonechill, "KILL_ANCHOR" end
    
    if #unvisitedFrostwinds > 0 then
        local function d(m) return (rootPos - m.HumanoidRootPart.Position).Magnitude end
        table.sort(unvisitedFrostwinds, function(a, b) return d(a) < d(b) end)
        return unvisitedFrostwinds[1], "AGGRO_COMBO"
    end

    if #elites > 0 then
        local function d(m) return (rootPos - m.HumanoidRootPart.Position).Magnitude end
        table.sort(elites, function(a, b) return d(a) < d(b) end)
        return elites[1], "KILL"
    end

    if #normals > 0 then
        local function d(m) return (rootPos - m.HumanoidRootPart.Position).Magnitude end
        table.sort(normals, function(a, b) return d(a) < d(b) end)
        return normals[1], "KILL"
    end
    
    return nil, "CLEAR"
end

-- ==============================================================================
-- 6. NAVIGATION
-- ==============================================================================
local function runTo(targetModel, mode)
    local char = player.Character; local root = char.HumanoidRootPart; local hum = char.Humanoid; local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then return end
    local d = (root.Position - enemyRoot.Position).Magnitude

    if (root.Position - lastPos).Magnitude < 0.5 then
        stuckCount = stuckCount + 1
        if stuckCount > 20 then hum.Jump = true; stuckCount = 0 end 
    else stuckCount = 0 end
    lastPos = root.Position
    checkWallAndJump()

    local isColossus = string.find(targetModel.Name, "Arctic Colossus")
    local stopRange = isColossus and 30 or 12

    if isColossus then updateStatus("BOSS: Colossus (30 Studs)") end

    if d <= stopRange then
        root.Anchored = true
        root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
        castSkills()
        return 
    end

    if mode == "AGGRO_COMBO" then
        updateStatus("AGGRO SWEEP: " .. targetModel.Name)
        if d < 25 then visitedMobs[targetModel] = true; return end
    elseif targetModel.Name == "Glacial Elemental" or mode == "KILL_ANCHOR" then
        updateStatus("ANCHORED @ " .. targetModel.Name)
        if d < 20 then
            root.Anchored = true; root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(); return
        end
    end

    root.Anchored = false
    updateStatus("CHASING: " .. targetModel.Name)

    if d < 12 then 
        hum:MoveTo(enemyRoot.Position); root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills()
    else
        local path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 6, AgentCanJump = true, AgentMaxSlope = 60, WaypointSpacing = 3 })
        pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)
        if path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if not _G.DungeonMaster then break end
                
                local distNow = (root.Position - enemyRoot.Position).Magnitude
                if distNow <= stopRange then
                    hum:MoveTo(root.Position) 
                    return 
                end

                if wp.Position.Y > root.Position.Y + 1.5 then hum.Jump = true end
                hum:MoveTo(wp.Position); autoClick(); checkWallAndJump()
                
                local t = 0; while (root.Position - wp.Position).Magnitude > 4 do 
                    RunService.Heartbeat:Wait(); t = t + 1; 
                    if t > 30 then hum.Jump = true; break end 
                end
                
                if mode == "AGGRO_COMBO" and (root.Position - enemyRoot.Position).Magnitude < 25 then visitedMobs[targetModel] = true; return end
            end
        else hum:MoveTo(enemyRoot.Position) end
    end
end

-- ==============================================================================
-- 7. WEBHOOK FUNCTIONALITY
-- ==============================================================================
local function sendInventoryUpdate()
    local success, err = pcall(function()
        local Inventory = workspace.Inventories:FindFirstChild(player.Name)
        if not Inventory then return end
        
        local currentRaw = Inventory.Experience.Value
        local neededRaw = Inventory.ExperienceNeeded.Value
        local currentXP = abbreviateNumber(currentRaw)
        local neededXP = abbreviateNumber(neededRaw)

        local levelInfo = string.format("Level: %d\nXP: %s/%s", 
            Inventory.Level.Value, currentXP, neededXP)

        local currentItems = #Inventory.Items:GetChildren()
        local maxItems = Inventory.MaxItems.Value
        local storageInfo = string.format("Inventory Space: %d/%d", currentItems, maxItems)
        
        local runsTotal = string.format("Total Runs: %d", totalRuns)

        local finalMessage = "=== PLAYER STATS ===\n" .. levelInfo .. "\n" .. storageInfo .. "\n" .. runsTotal .. "\n===================="

        local data = {["content"] = finalMessage}

        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- ==============================================================================
-- 8. MAIN LOOPS
-- ==============================================================================
-- Auto Start
task.spawn(function() while true do task.wait(1) if _G.AutoStart and not hasStarted then local r = ReplicatedStorage:FindFirstChild("Start") if r then pcall(function() r:FireServer() end) hasStarted = true; updateStatus("START TRIGGERED") end end end end)

-- Auto Sell Loop
task.spawn(function()
    while true do
        task.wait(5)
        if _G.AutoSell then
            pcall(runAutoSell)
        end
    end
end)

-- Dungeon Loop
task.spawn(function() while true do if _G.DungeonMaster then RunService.Heartbeat:Wait(); pcall(function() local t, m = getNextTarget(); if t then runTo(t, m) else visitedMobs = {}; local gates = {} for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Gate" or v.Name == "Portal" then table.insert(gates, v) end end if #gates > 0 then updateStatus("EXITING"); runTo({HumanoidRootPart = gates[1], Name = "Gate"}, "KILL") else updateStatus("SCANNING...") end end end) else task.wait(1) end end end)

-- Webhook Execute (Once)
task.spawn(function()
    task.wait(5)
    sendInventoryUpdate()
end)

print("[Script] Sanji's Master Hub (Colossus Absolute Priority Fix) Loaded")
