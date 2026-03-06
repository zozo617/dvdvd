local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. CONFIGURATION
-- ==============================================================================
_G.AutoFarm = true 
_G.AttackRange = 30 -- Strict 30 Studs Range

-- Internal Variables
local ClickEvent = ReplicatedStorage:FindFirstChild("Click", true) 
local blacklist = {} 
local currentTarget = nil
local lastPos = Vector3.new(0,0,0)
local stuckTimer = 0

-- ==============================================================================
-- 1. UI SETUP
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiVoid") then player.PlayerGui.SanjiVoid:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiVoid"

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(20,15,30); mainFrame.Position=UDim2.new(0.8,0,0.3,0); mainFrame.Size=UDim2.new(0,180,0,100); mainFrame.Visible = true
local titleLabel = Instance.new("TextLabel", mainFrame); titleLabel.Size=UDim2.new(1,0,0,30); titleLabel.BackgroundTransparency=1; titleLabel.Text="Sanji's Void Farm"; titleLabel.TextColor3=Color3.fromRGB(180, 50, 255); titleLabel.Font = Enum.Font.GothamBold

local statusLabel = Instance.new("TextLabel", mainFrame); statusLabel.Size = UDim2.new(1, 0, 0, 20); statusLabel.Position = UDim2.new(0,0,0.75,0); statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255); statusLabel.TextSize = 12; statusLabel.Font = Enum.Font.Gotham; statusLabel.Text = "Status: Idle"

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,35); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.MouseButton1Click:Connect(function() callback(btn) end)
end

createButton("AUTO FARM: ON", 35, Color3.fromRGB(0,180,100), function(b) 
    _G.AutoFarm = not _G.AutoFarm
    b.BackgroundColor3 = _G.AutoFarm and Color3.fromRGB(0,180,100) or Color3.fromRGB(200,60,60)
    b.Text = _G.AutoFarm and "AUTO FARM: ON" or "AUTO FARM: OFF" 
    if not _G.AutoFarm then 
        blacklist = {} 
        currentTarget = nil
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then char.Humanoid:MoveTo(char.HumanoidRootPart.Position) end 
    end
end)

-- ==============================================================================
-- 2. COMBAT BRAIN (Split-Brain Logic)
-- ==============================================================================
task.spawn(function()
    while true do
        task.wait() -- Spam Speed
        if _G.AutoFarm and currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("HumanoidRootPart") and currentTarget.Humanoid.Health > 0 then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                local enemyRoot = currentTarget.HumanoidRootPart
                local dist = (root.Position - enemyRoot.Position).Magnitude
                
                -- Check Range (and strict line of sight for normal mobs)
                if dist < _G.AttackRange then
                    -- Face Enemy
                    root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z))
                    
                    -- Spam Remote
                    if ClickEvent then ClickEvent:FireServer(true) end

                    -- Spam Skills
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
-- 3. TARGETING (STRONGBOX PRIORITY + BLACKLIST)
-- ==============================================================================
local function getVoidTarget()
    local char = player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPos = char.HumanoidRootPart.Position
    
    local strongboxes = {}
    local everythingElse = {}

    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Health > 0 and v.Parent and v.Parent:FindFirstChild("HumanoidRootPart") then
            local mob = v.Parent
            
            if not blacklist[mob] and not Players:GetPlayerFromCharacter(mob) then
                local dist = (rootPos - mob.HumanoidRootPart.Position).Magnitude
                
                if mob.Name == "Abyssal Strongbox" then
                    table.insert(strongboxes, {Mob = mob, Dist = dist})
                else
                    table.insert(everythingElse, {Mob = mob, Dist = dist})
                end
            end
        end
    end

    if #strongboxes > 0 then
        table.sort(strongboxes, function(a, b) return a.Dist < b.Dist end)
        return strongboxes[1].Mob
    end

    if #everythingElse > 0 then
        table.sort(everythingElse, function(a, b) return a.Dist < b.Dist end)
        return everythingElse[1].Mob
    end

    return nil
end

-- ==============================================================================
-- 4. MOVEMENT (STRICT WALL CHECK)
-- ==============================================================================
local function runTo(target)
    local char = player.Character
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    local enemyRoot = target:FindFirstChild("HumanoidRootPart")
    
    if not root or not hum or not enemyRoot then return end
    
    if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end
    statusLabel.Text = "Target: " .. target.Name
    
    local dist = (root.Position - enemyRoot.Position).Magnitude

    -- STUCK CHECK
    if (root.Position - lastPos).Magnitude < 0.5 then
        stuckTimer = stuckTimer + 1
        if stuckTimer > 15 then -- 1.5s stuck
            hum.Jump = true
            blacklist[target] = true -- Mark target unreachable
            currentTarget = nil
            stuckTimer = 0
            return
        end
    else
        stuckTimer = 0
    end
    lastPos = root.Position

    -- IF CLOSE -> STOP
    if dist < (_G.AttackRange - 5) then
        hum:MoveTo(root.Position) 
        return
    end

    -- IF FAR -> CALCULATE PATH
    root.Anchored = false
    local path = PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentCanJump = true,
        Costs = {
            Water = 20,
            Neon = 100 -- Assuming walls might be Neon/Plastic
        }
    })
    
    local success, _ = pcall(function() path:ComputeAsync(root.Position, enemyRoot.Position) end)

    if success and path.Status == Enum.PathStatus.Success then
        -- PATH FOUND: FOLLOW IT
        for _, wp in ipairs(path:GetWaypoints()) do
            if not _G.AutoFarm then break end
            if not target.Parent or target.Humanoid.Health <= 0 then break end

            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position)
            
            -- Wait Loop
            local timeout = 0
            while (root.Position - wp.Position).Magnitude > 4 do
                RunService.Heartbeat:Wait()
                timeout = timeout + 1
                if timeout > 120 then hum.Jump = true; break end
                
                -- Close Check
                if (root.Position - enemyRoot.Position).Magnitude < (_G.AttackRange - 5) then
                     hum:MoveTo(root.Position)
                     return
                end
            end
        end
    else
        -- PATH FAILED: BLACKLIST TARGET
        -- DO NOT WALK STRAIGHT. JUST GIVE UP ON THIS TARGET.
        blacklist[target] = true
        statusLabel.Text = "Skipping Wall: " .. target.Name
        currentTarget = nil
    end
end

-- ==============================================================================
-- 5. MAIN LOOP
-- ==============================================================================
task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if _G.AutoFarm then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                
                if currentTarget and (not currentTarget.Parent or not currentTarget:FindFirstChild("Humanoid") or currentTarget.Humanoid.Health <= 0) then
                    currentTarget = nil
                end

                if not currentTarget then
                    currentTarget = getVoidTarget()
                end

                if currentTarget then
                    runTo(currentTarget)
                else
                    statusLabel.Text = "Scanning..."
                end
            end
        end
    end
end)

print("[Sanji] Void Farm: Strict Anti-Wall Loaded")
