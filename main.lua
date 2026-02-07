local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService") 
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. CONFIGURATION
-- ==============================================================================
_G.WebhookURL = "https://discord.com/api/webhooks/1446663395980873830/XIzk9dyFM1FOnggrSjTevw_nGonsWlc3P9lrDVLsoLg-oE3U6jU5iEedFp2oU8D_sotR"
_G.DungeonMaster = true 
_G.AutoStart = true     
_G.GodMode = true       

-- Internal Variables
local visitedMobs = {} 
local lastMB1 = 0           
local MB1_COOLDOWN = 0.25 
local lastMoveTime = tick()
local lastPosition = Vector3.new(0,0,0)
local currentTargetName = ""
local targetStartTime = 0
local ClickRemote = ReplicatedStorage:WaitForChild("Click")

-- ==============================================================================
-- 1. WEBHOOK SYSTEM (BUFFERED)
-- ==============================================================================
local lootBuffer = {}
local isSendingWebhook = false

local function sendBufferedWebhook()
    if _G.WebhookURL == "" or #lootBuffer == 0 then 
        isSendingWebhook = false
        return 
    end
    
    local descString = "Items Obtained this run:\n"
    for _, item in ipairs(lootBuffer) do
        descString = descString .. "• **" .. tostring(item) .. "**\n"
    end
    
    local data = {
        ["content"] = " ", 
        ["embeds"] = {{
            ["title"] = "💎 Dungeon Loot Summary",
            ["description"] = descString,
            ["color"] = 65280,
            ["footer"] = {
                ["text"] = "Sanji's Script | " .. os.date("%X")
            }
        }}
    }
    
    local requestFunc = (http and http.request) or http_request or (syn and syn.request) or request or HttpPost
    if requestFunc then
        pcall(function()
            requestFunc({
                Url = _G.WebhookURL, 
                Body = HttpService:JSONEncode(data), 
                Method = "POST", 
                Headers = {["Content-Type"] = "application/json"}
            })
        end)
    end
    
    lootBuffer = {}
    isSendingWebhook = false
end

local function onChildAdded(child)
    if child:IsA("Tool") then
        table.insert(lootBuffer, child.Name)
        if not isSendingWebhook then
            isSendingWebhook = true
            task.delay(6, sendBufferedWebhook)
        end
    end
end

player.Backpack.ChildAdded:Connect(onChildAdded)

-- ==============================================================================
-- 2. GOD MODE HOOK
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
-- 3. UI SETUP (GHOST MODE)
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiScript") then player.PlayerGui.SanjiScript:Destroy() end
local screenGui = Instance.new("ScreenGui"); screenGui.Name = "SanjiScript"; screenGui.Parent = player.PlayerGui

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = guiObject.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart; guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
end

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(15,15,20); mainFrame.Position=UDim2.new(0.7,0,0.25,0); mainFrame.Size=UDim2.new(0,170,0,180); makeDraggable(mainFrame)
mainFrame.Visible = false 

local houseBtn = Instance.new("ImageButton", screenGui); houseBtn.Name="HomeBtn"; houseBtn.BackgroundColor3=Color3.fromRGB(20,20,20); houseBtn.Position=UDim2.new(0.9,0,0.15,0); houseBtn.Size=UDim2.new(0,45,0,45); houseBtn.Image="rbxassetid://3926305904"; houseBtn.ImageColor3=Color3.fromRGB(0,255,255)
Instance.new("UICorner", houseBtn).CornerRadius = UDim.new(0, 12); local houseStroke = Instance.new("UIStroke", houseBtn); houseStroke.Color = Color3.fromRGB(0,255,255); houseStroke.Thickness = 1.5; makeDraggable(houseBtn)
houseBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

local titleLabel = Instance.new("TextLabel", mainFrame); titleLabel.Size=UDim2.new(1,0,0,30); titleLabel.BackgroundTransparency=1; titleLabel.Text="Sanji's Script"; titleLabel.TextColor3=Color3.fromRGB(0,255,255)
local statusLabel = Instance.new("TextLabel", mainFrame); statusLabel.Size=UDim2.new(1,0,0,20); statusLabel.Position=UDim2.new(0,0,1,-20); statusLabel.BackgroundTransparency=1; statusLabel.TextColor3=Color3.fromRGB(150,150,150); statusLabel.Text="Waiting..."
local function updateStatus(msg) statusLabel.Text = msg end

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,30); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.MouseButton1Click:Connect(function() callback(btn) end)
end
createButton("AUTO FARM: ON", 40, Color3.fromRGB(0,180,100), function(b) _G.DungeonMaster = not _G.DungeonMaster; b.BackgroundColor3 = _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60); b.Text = _G.DungeonMaster and "AUTO FARM: ON" or "AUTO FARM: OFF" end)
createButton("AUTO START: ON", 80, Color3.fromRGB(0,140,255), function(b) _G.AutoStart = not _G.AutoStart; b.BackgroundColor3 = _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80); b.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF" end)
createButton("GOD MODE: ON", 120, Color3.fromRGB(140,0,255), function(b) _G.GodMode = not _G.GodMode; b.BackgroundColor3 = _G.GodMode and Color3.fromRGB(140,0,255) or Color3.fromRGB(80,80,80); b.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF" end)

-- ==============================================================================
-- 4. UTILITY & COMBAT
-- ==============================================================================
local function enforceSpeed(hum) if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end end
local function getBestExit()
    local char = player.Character; if not char then return nil end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return nil end
    local gates = {}; for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Gate" or v.Name == "Portal" then table.insert(gates, v) end end
    local bestGate, maxDist = nil, -1; for _, gate in ipairs(gates) do local dist = (gate.Position - root.Position).Magnitude; if dist > maxDist then maxDist = dist; bestGate = gate end end; return bestGate
end

-- MOBILE FIX: Pure Remote Click (No screen tapping)
local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then ClickRemote:FireServer(true); lastMB1 = tick() end end

local function castSkills(targetModel)
    autoClick() 
    local char = player.Character; if not char then return end; local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart"); if not enemyRoot then return end
    if (root.Position - enemyRoot.Position).Magnitude > 18 then return end 
    
    local name = targetModel.Name; local useSkills = false
    if string.find(name, "Colossus") or string.find(name, "Snowman") or string.find(name, "Boss") or string.find(name, "Progenitor") or string.find(name, "Possessed") or string.find(name, "Elemental") or string.find(name, "Sorcerer") or string.find(name, "Wraith") or string.find(name, "Guardian") or string.find(name, "Frostwind") then useSkills = true
    else
        local bossNearby = false
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 then
                local n = v.Parent.Name
                if string.find(n, "Colossus") or string.find(n, "Snowman") or string.find(n, "Boss") or string.find(n, "Progenitor") then bossNearby = true; break end
            end
        end
        if not bossNearby then useSkills = true end
    end
    
    if useSkills then for _, key in ipairs({"Q", "E", "R", "F"}) do VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game); task.wait(); VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game) end end
end

-- ==============================================================================
-- 5. TARGETING (GLACIAL SYNC FIX)
-- ==============================================================================
local function getNextTarget()
    local char = player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
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
    local function distSort(a,b) if not a or not b then return false end; return (char.HumanoidRootPart.Position - a.HumanoidRootPart.Position).Magnitude < (char.HumanoidRootPart.Position - b.HumanoidRootPart.Position).Magnitude end
    table.sort(progenitors, distSort); table.sort(bosses, distSort); table.sort(glacials, distSort); table.sort(runners, distSort)

    -- GLACIAL ENTOURAGE CHECK (Room 5 Fix)
    if #glacials > 0 then
        local targetGlacial = glacials[1]
        for _, runner in ipairs(runners) do
            if string.find(runner.Name, "Spruced") and not visitedMobs[runner] then
                if (runner.HumanoidRootPart.Position - targetGlacial.HumanoidRootPart.Position).Magnitude < 50 then return runner, "AGGRO" end
            end
        end
    end

    if #runners > 0 then
        local closestRunner = runners[1]; if not visitedMobs[closestRunner] then
            local runnerDist = (char.HumanoidRootPart.Position - closestRunner.HumanoidRootPart.Position).Magnitude
            if runnerDist < 40 then
                local farBoss = false
                if #progenitors > 0 and (char.HumanoidRootPart.Position - progenitors[1].HumanoidRootPart.Position).Magnitude > 50 then farBoss = true end
                if #bosses > 0 and (char.HumanoidRootPart.Position - bosses[1].HumanoidRootPart.Position).Magnitude > 50 then farBoss = true end
                if farBoss then return closestRunner, "AGGRO" end
            end
        end
    end
    
    if #progenitors > 0 then return progenitors[1], "KILL" end; if #bosses > 0 then return bosses[1], "KILL" end; if #glacials > 0 then return glacials[1], "KILL" end
    for _, r in ipairs(runners) do if not visitedMobs[r] then return r, "AGGRO" end end; if #runners > 0 then return runners[1], "KILL" end; return nil, "CLEAR"
end

-- ==============================================================================
-- 6. NAVIGATION (STAIRS FIX)
-- ==============================================================================
local function runTo(targetModel, mode)
    local char = player.Character; local root = char:WaitForChild("HumanoidRootPart"); local hum = char:WaitForChild("Humanoid"); local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart"); if not enemyRoot then return end
    enforceSpeed(hum)
    if targetModel.Name == currentTargetName then if tick() - targetStartTime > 4 then mode = "KILL" end else currentTargetName = targetModel.Name; targetStartTime = tick() end
    if (root.Position - lastPosition).Magnitude < 2 then if tick() - lastMoveTime > 6 then hum.Jump = true; hum:MoveTo(root.Position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))); lastMoveTime = tick(); return end else lastMoveTime = tick(); lastPosition = root.Position end
    
    if mode == "KILL" and (root.Position - enemyRoot.Position).Magnitude < 20 then
        if string.find(targetModel.Name, "Glacial") then hum:MoveTo(enemyRoot.Position + ((root.Position - enemyRoot.Position).Unit * 10)); root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
        else hum:MoveTo(enemyRoot.Position); root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)) end
        castSkills(targetModel); return
    end

    local dist = (root.Position - enemyRoot.Position).Magnitude
    if mode == "AGGRO" and dist < 30 then visitedMobs[targetModel] = true; return end
    if dist < 20 then hum:MoveTo(enemyRoot.Position) else
        local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true}); local success, _ = pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)
        if success and path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if not _G.DungeonMaster then break end; enforceSpeed(hum)
                -- STAIRS FIX: Only jump if waypoint is > 4 studs higher
                if wp.Position.Y > root.Position.Y + 4 then hum.Jump = true end
                hum:MoveTo(wp.Position); autoClick()
                local stuckTimer = 0
                while (root.Position - wp.Position).Magnitude > 4 do RunService.Heartbeat:Wait(); enforceSpeed(hum); stuckTimer = stuckTimer + 1; if stuckTimer > 60 then hum.Jump = true; return end end
                if mode == "AGGRO" and (root.Position - enemyRoot.Position).Magnitude < 30 then visitedMobs[targetModel] = true; return end
            end
        else hum:MoveTo(enemyRoot.Position) end
    end
end

-- ==============================================================================
-- 7. LOOPS (SAFETY LOCK)
-- ==============================================================================
task.spawn(function() 
    while true do 
        task.wait(2)
        if _G.AutoStart then 
            local isFighting = false; local c = player.Character
            if c then for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("Humanoid") and v.Parent ~= c and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") and (v.Parent.HumanoidRootPart.Position - c.PrimaryPart.Position).Magnitude < 100 then isFighting = true break end end end
            if not isFighting then
                pcall(function() ReplicatedStorage:WaitForChild("Start", 1):FireServer() end)
                local gui = player.PlayerGui; for _, v in pairs(gui:GetDescendants()) do if (v:IsA("TextButton") or v:IsA("ImageButton")) and v.Visible then for _, name in ipairs({"Start", "Replay", "Retry", "Play"}) do if string.find(v.Name, name) or (v:IsA("TextButton") and string.find(v.Text, name)) then VirtualInputManager:SendMouseButtonEvent(v.AbsolutePosition.X + v.AbsoluteSize.X/2, v.AbsolutePosition.Y + v.AbsoluteSize.Y/2, 0, true, game, 0); task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(v.AbsolutePosition.X + v.AbsoluteSize.X/2, v.AbsolutePosition.Y + v.AbsoluteSize.Y/2, 0, false, game, 0) end end end end
            end 
        end 
    end 
end)

task.spawn(function() 
    while true do 
        if _G.DungeonMaster then RunService.Heartbeat:Wait(); pcall(function() local char = player.Character or player.CharacterAdded:Wait(); local root = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChild("Humanoid"); if not root or not hum then return end; enforceSpeed(hum); local target, mode = getNextTarget(); if target then runTo(target, mode) else visitedMobs = {}; local gate = getBestExit(); if gate then runTo({HumanoidRootPart = gate, Name = "Gate"}, "KITE_TO_EXIT") else local me = tick() + 4; while tick() < me and _G.DungeonMaster do char.Humanoid:MoveTo(root.Position + root.CFrame.LookVector * 20); if root.Velocity.Magnitude < 0.5 then char.Humanoid.Jump = true end; RunService.Heartbeat:Wait() end end end end) 
        else task.wait(1) end 
    end 
end)
