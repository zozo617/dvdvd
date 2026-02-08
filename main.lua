local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. CONFIGURATION & STATE (STUDS REMOVED)
-- ==============================================================================
_G.DungeonMaster = true  
_G.VoidFarm = false      
_G.GodMode = true        
_G.AutoStart = true      

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
-- 2. UI SETUP (MOBILE STEALTH)
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

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(15,15,20); mainFrame.Position=UDim2.new(0.5, -90, 0.3, 0); mainFrame.Size=UDim2.new(0,180,0,260); mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
makeDraggable(mainFrame)

local statusFrame = Instance.new("Frame", screenGui); statusFrame.Name = "StatusFrame"
statusFrame.Size = UDim2.new(0, 200, 0, 30); statusFrame.AnchorPoint = Vector2.new(0.5, 0); statusFrame.Position = UDim2.new(0.5, 0, 0.75, 0); statusFrame.BackgroundColor3 = Color3.fromRGB(0,0,0); statusFrame.BackgroundTransparency = 0.5
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 6)
makeDraggable(statusFrame)

local statusLabel = Instance.new("TextLabel", statusFrame); statusLabel.Size = UDim2.new(1, 0, 1, 0); statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255); statusLabel.TextSize = 14; statusLabel.Font = Enum.Font.GothamBold; statusLabel.Text = "Status: Idle"
local function updateStatus(msg) statusLabel.Text = msg end

local hideBtn = Instance.new("TextButton", screenGui); hideBtn.Name = "HideBtn"; hideBtn.Position = UDim2.new(0.9, -50, 0.15, 0); hideBtn.Size = UDim2.new(0, 45, 0, 45); hideBtn.Text = "UI"; hideBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 255); hideBtn.TextColor3 = Color3.new(1,1,1); hideBtn.Font = Enum.Font.GothamBold; Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 8); makeDraggable(hideBtn)
hideBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,35); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.MouseButton1Click:Connect(function() callback(btn) end)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

createButton("DUNGEON: ON", 35, Color3.fromRGB(0,180,100), function(b) _G.DungeonMaster = not _G.DungeonMaster; _G.VoidFarm = false; b.BackgroundColor3 = _G.DungeonMaster and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60); b.Text = _G.DungeonMaster and "DUNGEON: ON" or "DUNGEON: OFF" end)
createButton("VOID FARM: OFF", 80, Color3.fromRGB(200,60,60), function(b) _G.VoidFarm = not _G.VoidFarm; _G.DungeonMaster = false; b.BackgroundColor3 = _G.VoidFarm and Color3.fromRGB(140,0,255) or Color3.fromRGB(200,60,60); b.Text = _G.VoidFarm and "VOID FARM: ON" or "VOID FARM: OFF" end)
createButton("GOD MODE: ON", 125, Color3.fromRGB(255,170,0), function(b) _G.GodMode = not _G.GodMode; b.BackgroundColor3 = _G.GodMode and Color3.fromRGB(255,170,0) or Color3.fromRGB(80,80,80); b.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF" end)
createButton("AUTO START: ON", 170, Color3.fromRGB(0,140,255), function(b) _G.AutoStart = not _G.AutoStart; b.BackgroundColor3 = _G.AutoStart and Color3.fromRGB(0,140,255) or Color3.fromRGB(80,80,80); b.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF" end)

-- ==============================================================================
-- 3. UTILITIES
-- ==============================================================================
local function enforceSpeed(hum) if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end end
local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then if ClickEvent then ClickEvent:FireServer(true) end lastMB1 = tick() end end

local function castSkills(target)
    autoClick() 
    if VirtualInputManager then
        for _, key in ipairs({"Q", "E", "R", "F"}) do 
            if not target or target.Humanoid.Health <= 0 then break end
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
        end
    end
end

-- ==============================================================================
-- 4. AGGRESSIVE TARGETING (NO STUDS)
-- ==============================================================================
local function getUnifiedTarget(isVoid)
    local char = player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPos = char.HumanoidRootPart.Position
    local allMobs = {}

    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Health > 0 and v.Parent and v.Parent:FindFirstChild("HumanoidRootPart") and v.Parent ~= char then
            if not blacklist[v.Parent] and not Players:GetPlayerFromCharacter(v.Parent) then
                local dist = (rootPos - v.Parent.HumanoidRootPart.Position).Magnitude
                table.insert(allMobs, {Mob = v.Parent, Dist = dist})
            end
        end
    end

    if #allMobs > 0 then
        -- If Void mode, priority to Strongbox
        if isVoid then
            for _, m in ipairs(allMobs) do
                if m.Mob.Name == "Abyssal Strongbox" then return m.Mob end
            end
        end
        table.sort(allMobs, function(a, b) return a.Dist < b.Dist end)
        return allMobs[1].Mob
    end
    return nil
end

local function aggressiveChase(target)
    local char = player.Character; local root = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChild("Humanoid"); local enemyRoot = target:FindFirstChild("HumanoidRootPart")
    if not root or not hum or not enemyRoot then return end
    
    enforceSpeed(hum)
    updateStatus("Attacking: " .. target.Name)
    local dist = (root.Position - enemyRoot.Position).Magnitude

    -- Stuck Check
    if (root.Position - lastPos).Magnitude < 0.5 then
        stuckTimer = stuckTimer + 1
        if stuckTimer > 20 then hum.Jump = true; stuckTimer = 0 end
    else stuckTimer = 0 end
    lastPos = root.Position

    -- Point Blank Combat
    root.Anchored = false
    hum:MoveTo(enemyRoot.Position)
    root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
    castSkills(target)

    -- Pathfinding for long distance walls
    if dist > 20 then
        local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true})
        pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)
        if path.Status == Enum.PathStatus.Success then
            for _, wp in ipairs(path:GetWaypoints()) do
                if not (_G.DungeonMaster or _G.VoidFarm) then break end
                if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
                hum:MoveTo(wp.Position)
                local t = 0; while (root.Position - wp.Position).Magnitude > 4 do RunService.Heartbeat:Wait(); t = t + 1; if t > 50 then break end end
            end
        end
    end
end

-- ==============================================================================
-- 5. MAIN LOOPS
-- ==============================================================================
task.spawn(function() 
    while true do 
        task.wait(1) 
        if _G.DungeonMaster and _G.AutoStart and not hasStarted then 
            local r = ReplicatedStorage:FindFirstChild("Start") 
            if r then pcall(function() r:FireServer() end) hasStarted = true end 
        end 
    end 
end)

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if _G.DungeonMaster or _G.VoidFarm then
            local t = getUnifiedTarget(_G.VoidFarm)
            if t then 
                aggressiveChase(t) 
            else 
                updateStatus("Scanning...")
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then player.Character.HumanoidRootPart.Anchored = false end
            end
        end
    end
end)

print("[Sanji] Unified Hub: Zero Studs Edition Loaded")
