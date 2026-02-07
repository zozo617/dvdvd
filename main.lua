local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

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
local webhookUrl = "https://discord.com/api/webhooks/1469715145231044639/o8-1Y_7sWpRQmK-2MwQCAzozLtczyx70M5NTTS4uTx-s2dsXLrzQrsnDeMBSHha90aB8" 

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
        if input.UserInputType == Enum.UserInputType.MouseButton1 then 
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
        if input.UserInputType == Enum.UserInputType.MouseMovement then 
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

local statusStroke = Instance.new("UIStroke", statusFrame)
statusStroke.Color = Color3.fromRGB(255, 255, 255)
statusStroke.Thickness = 1
statusStroke.Transparency = 0.8

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

local function getBestExit()
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local gates = {}
    for _, v in pairs(Workspace:GetDescendants()) do 
        if v.Name == "Gate" or v.Name == "Portal" then 
            table.insert(gates, v) 
        end 
    end
    
    local bestGate, maxDist = nil, -1
    for _, gate in ipairs(gates) do 
        local dist = (gate.Position - root.Position).Magnitude
        if dist > maxDist then 
            maxDist = dist
            bestGate = gate 
        end 
    end
    return bestGate
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
    
    local useSkills = false
    if string.find(name, "Colossus") or string.find(name, "Snowman") or string.find(name, "Boss") or string.find(name, "Progenitor") or string.find(name, "Possessed") or string.find(name, "Elemental") or string.find(name, "Sorcerer") or string.find(name, "Spruced") then 
        useSkills = true
    else
        local bossNearby = false
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 then
                local n = v.Parent.Name
                if string.find(n, "Colossus") or string.find(n, "Snowman") or string.find(n, "Boss") or string.find(n, "Progenitor") then 
                    bossNearby = true
                    break 
                end
            end
        end
        if not bossNearby then useSkills = true end
    end
    
    if useSkills then 
        for _, key in ipairs({"Q", "E", "R", "F"}) do 
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game) 
            task.wait() 
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game) 
        end 
    end
end

-- ==============================================================================
-- 4. TARGETING
-- ==============================================================================
local function getNextTarget()
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    
    local progenitors, bosses, glacials, runners = {}, {}, {}, {}
    
    for mob, _ in pairs(visitedMobs) do 
        if not mob or not mob.Parent or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0) then 
            visitedMobs[mob] = nil 
        end 
    end
    
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= player.Character and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then
            local mob = v.Parent
            local name = mob.Name
            if not string.find(name, "Frostwoven") and not string.find(name, "Gate") then 
                if string.find(name, "Progenitor") then 
                    table.insert(progenitors, mob)
                elseif string.find(name, "Snowman") or string.find(name, "Colossus") or string.find(name, "Boss") or string.find(name, "Possessed") or string.find(name, "Elemental") or string.find(name, "Sorcerer") then 
                    table.insert(bosses, mob)
                elseif string.find(name, "Glacial") then 
                    table.insert(glacials, mob)
                else 
                    table.insert(runners, mob) 
                end
            end
        end
    end
    
    local function distSort(a,b) 
        return (char.HumanoidRootPart.Position - a.HumanoidRootPart.Position).Magnitude < (char.HumanoidRootPart.Position - b.HumanoidRootPart.Position).Magnitude 
    end
    
    table.sort(progenitors, distSort)
    table.sort(bosses, distSort)
    table.sort(glacials, distSort)
    table.sort(runners, distSort)
    
    if #progenitors > 0 then return progenitors[1], "KILL" end
    
    local possessedSnowman = nil
    for _, boss in ipairs(bosses) do 
        if string.find(boss.Name, "Possessed") then 
            possessedSnowman = boss 
            break 
        end 
    end
    
    if possessedSnowman then
        for _, runner in ipairs(runners) do 
            if not visitedMobs[runner] and (runner.HumanoidRootPart.Position - possessedSnowman.HumanoidRootPart.Position).Magnitude < 150 then 
                return runner, "AGGRO" 
            end 
        end
        return possessedSnowman, "KILL"
    end
    
    if #bosses > 0 then return bosses[1], "KILL" end
    
    if #glacials > 0 then
        local targetGlacial = glacials[1]
        for _, runner in ipairs(runners) do 
            if string.find(runner.Name, "Spruced") and not visitedMobs[runner] then 
                if (runner.HumanoidRootPart.Position - targetGlacial.HumanoidRootPart.Position).Magnitude < 50 then 
                    return runner, "AGGRO" 
                end 
            end 
        end
        return glacials[1], "KILL"
    end
    
    for _, r in ipairs(runners) do 
        if not visitedMobs[r] then 
            return r, "AGGRO" 
        end 
    end
    
    if #runners > 0 then return runners[1], "KILL" end
    return nil, "CLEAR"
end

-- ==============================================================================
-- 5. NAVIGATION
-- ==============================================================================
local function runTo(targetModel, mode)
    local char = player.Character
    local root = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    
    if not enemyRoot then 
        root.Anchored = false
        return 
    end
    
    enforceSpeed(hum)
    local dist = (root.Position - enemyRoot.Position).Magnitude
    
    if mode == "KILL" and string.find(targetModel.Name, "Spruced") then
        if dist < 18 then
            root.Anchored = true
            root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
            castSkills(targetModel)
            updateStatus("ANCHORED: Melting " .. targetModel.Name)
            return
        else 
            root.Anchored = false
            updateStatus("CHASING: " .. targetModel.Name) 
        end
    else 
        root.Anchored = false
        if mode == "KILL" then 
            updateStatus("KILLING: " .. targetModel.Name) 
        end 
    end
    
    if (root.Position - lastPosition).Magnitude < 2 and not root.Anchored then 
        if tick() - lastMoveTime > 6 then 
            hum.Jump = true
            hum:MoveTo(root.Position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5)))
            lastMoveTime = tick()
            return 
        end 
    else 
        lastMoveTime = tick()
        lastPosition = root.Position 
    end
    
    local attackRange = 20
    if string.find(targetModel.Name, "Colossus") or string.find(targetModel.Name, "Possessed") then 
        attackRange = 40 
    end
    
    if mode == "KILL" and dist < attackRange then 
        hum:MoveTo(enemyRoot.Position)
        root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
        castSkills(targetModel)
        return 
    end
    
    if mode == "AGGRO" then 
        updateStatus("AGGRO: Tagging " .. targetModel.Name)
        if dist < 30 then 
            visitedMobs[targetModel] = true
            return 
        end 
    end
    
    if dist < attackRange then 
        hum:MoveTo(enemyRoot.Position) 
    else
        local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true})
        local success, _ = pcall(function() 
            path:ComputeAsync(root.Position, enemyRoot.Position) 
        end)
        
        if success and path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if not _G.DungeonMaster then break end
                enforceSpeed(hum)
                if wp.Position.Y > root.Position.Y + 4.5 then 
                    hum.Jump = true 
                end
                hum:MoveTo(wp.Position)
                autoClick()
                
                local stuckTimer = 0
                while (root.Position - wp.Position).Magnitude > 4 do 
                    RunService.Heartbeat:Wait()
                    enforceSpeed(hum)
                    stuckTimer = stuckTimer + 1
                    if stuckTimer > 60 then 
                        hum.Jump = true
                        return 
                    end 
                end
                
                if mode == "AGGRO" and (root.Position - enemyRoot.Position).Magnitude < 30 then 
                    visitedMobs[targetModel] = true
                    return 
                end
                
                if (root.Position - enemyRoot.Position).Magnitude < attackRange then 
                    break 
                end
            end
        else 
            hum:MoveTo(enemyRoot.Position) 
        end
    end
end

-- ==============================================================================
-- 6. ONE-SHOT START LOOP
-- ==============================================================================
task.spawn(function() 
    while true do 
        task.wait(1)
        if _G.AutoStart and not hasStarted then 
            local startRemote = ReplicatedStorage:FindFirstChild("Start")
            if startRemote then 
                pcall(function() 
                    startRemote:FireServer() 
                end)
                hasStarted = true
                updateStatus("START TRIGGERED")
            end 
        end 
    end 
end)

task.spawn(function() 
    while true do 
        if _G.DungeonMaster then 
            RunService.Heartbeat:Wait()
            pcall(function() 
                local char = player.Character or player.CharacterAdded:Wait()
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                
                if not root or not hum then return end
                
                enforceSpeed(hum)
                local target, mode = getNextTarget()
                
                if target then 
                    runTo(target, mode) 
                else 
                    root.Anchored = false 
                    visitedMobs = {}
                    local gate = getBestExit()
                    
                    if gate then 
                        updateStatus("EXITING: Gate Path")
                        runTo({HumanoidRootPart = gate, Name = "Gate"}, "KITE_TO_EXIT") 
                    else 
                        updateStatus("SEARCHING: Movement Required")
                        local me = tick() + 4
                        while tick() < me and _G.DungeonMaster do 
                            char.Humanoid:MoveTo(root.Position + root.CFrame.LookVector * 20)
                            if root.Velocity.Magnitude < 0.5 then 
                                char.Humanoid.Jump = true 
                            end
                            RunService.Heartbeat:Wait() 
                        end 
                    end 
                end 
            end) 
        else 
            updateStatus("PAUSED")
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then 
                player.Character.HumanoidRootPart.Anchored = false 
            end
            task.wait(1) 
        end 
    end 
end)

local function sendInventoryUpdate()
    local success, err = pcall(function()
        if not Inventory or not Inventory.Parent then
            warn("[Webhook] Inventory not found")
            return
        end
        
        local levelInfo = string.format("Level: %d\nXP: %d/%d\n", 
            Inventory.Level.Value, 
            Inventory.Experience.Value, 
            Inventory.ExperienceNeeded.Value)

        local itemCounts = {}

        if Inventory.Items then
            for _, item in pairs(Inventory.Items:GetChildren()) do
                if item:IsA("StringValue") then
                    local itemData = string.split(item.Value, ",")
                    local itemId = itemData[1]

                    local itemFolder = workspace.Items:FindFirstChild(itemId)
                    if itemFolder and itemFolder:FindFirstChild("Info") then
                        local itemInfo = string.split(itemFolder.Info.Value, ",")
                        local itemType = itemInfo[1]
                        local itemName = string.match(itemId, "(.+)") or itemId

                        if not itemCounts[itemName] then
                            itemCounts[itemName] = {count = 0, type = itemType}
                        end
                        itemCounts[itemName].count = itemCounts[itemName].count + 1
                    end
                end
            end
        end

        local inventoryList = "\n=== INVENTORY ===\n"
        for itemName, data in pairs(itemCounts) do
            inventoryList = inventoryList .. string.format("%dx %s (%s)\n", data.count, itemName, data.type)
        end

        local currentItems = #Inventory.Items:GetChildren()
        local maxItems = Inventory.MaxItems.Value

        inventoryList = inventoryList .. string.format("\nInventory Amount: %d/%d", currentItems, maxItems)
        inventoryList = inventoryList .. "\n================="

        local data = {
            ["content"] = levelInfo .. inventoryList
        }

        local webhookSuccess, webhookResponse = pcall(function()
            return request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
        end)
        
        if webhookSuccess then
            print("[Webhook] Inventory update sent successfully")
        else
            warn("[Webhook] Failed to send:", webhookResponse)
        end
    end)
    
    if not success then
        warn("[Webhook] Error in sendInventoryUpdate:", err)
    end
end

task.wait(5) 
sendInventoryUpdate()


task.spawn(function()
    while true do
        task.wait(300)
        sendInventoryUpdate()
    end
end)

print("[Script] Loaded successfully!")
