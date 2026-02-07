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

local visitedMobs = {} 
local lastMB1 = 0           
local MB1_COOLDOWN = 0.25 
local lastMoveTime = tick()
local lastPosition = Vector3.new(0,0,0)
local lastUIInteraction = tick() 
local ClickEvent = ReplicatedStorage:WaitForChild("Click")

-- ==============================================================================
-- 1. EXACT UI RESTORATION
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiScript") then player.PlayerGui.SanjiScript:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiScript"

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; lastUIInteraction = tick()
            dragStart = input.Position; startPos = guiObject.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart; guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
end

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(15, 15, 20); mainFrame.Position=UDim2.new(0.5, -75, 0.4, 0); mainFrame.Size=UDim2.new(0,150,0,165); makeDraggable(mainFrame); mainFrame.Visible = false 

local houseBtn = Instance.new("ImageButton", screenGui); houseBtn.Name="HomeBtn"; houseBtn.BackgroundColor3=Color3.fromRGB(20, 20, 25); houseBtn.Position=UDim2.new(0.9,0,0.15,0); houseBtn.Size=UDim2.new(0,45,0,45); houseBtn.Image = "rbxassetid://138612143003295" 
Instance.new("UICorner", houseBtn).CornerRadius = UDim.new(0, 10); makeDraggable(houseBtn)
houseBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible; lastUIInteraction = tick() end)

local title = Instance.new("TextLabel", mainFrame); title.Size=UDim2.new(1,0,0,30); title.BackgroundTransparency=1; title.Text="Sanji's Script"; title.TextColor3=Color3.fromRGB(138, 43, 226); title.Font = Enum.Font.SourceSans; title.TextSize = 14
local statusLabel = Instance.new("TextLabel", mainFrame); statusLabel.Size=UDim2.new(1,0,0,25); statusLabel.Position=UDim2.new(0,0,1,-25); statusLabel.BackgroundTransparency=1; statusLabel.TextColor3=Color3.fromRGB(150, 150, 150); statusLabel.Text="Waiting..."; statusLabel.Font = Enum.Font.SourceSans; statusLabel.TextSize = 14
local function updateStatus(msg) statusLabel.Text = msg end

local function createButton(text, pos, color, callback)
    local btn = Instance.new("TextButton", mainFrame); btn.BackgroundColor3=color; btn.Position=UDim2.new(0.05,0,0,pos); btn.Size=UDim2.new(0.9,0,0,30); btn.Text=text; btn.TextColor3=Color3.new(1,1,1); btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 12; btn.BorderSizePixel = 0
    btn.MouseButton1Click:Connect(function() lastUIInteraction = tick(); callback(btn) end)
end

createButton("AUTO FARM: ON", 35, Color3.fromRGB(0, 160, 100), function(o) _G.DungeonMaster = not _G.DungeonMaster; o.Text = _G.DungeonMaster and "AUTO FARM: ON" or "AUTO FARM: OFF" end)
createButton("AUTO START: ON", 70, Color3.fromRGB(0, 120, 220), function(o) _G.AutoStart = not _G.AutoStart; o.Text = _G.AutoStart and "AUTO START: ON" or "AUTO START: OFF" end)
createButton("GOD MODE: ON", 105, Color3.fromRGB(150, 0, 255), function(o) _G.GodMode = not _G.GodMode; o.Text = _G.GodMode and "GOD MODE: ON" or "GOD MODE: OFF" end)

task.spawn(function() while true do task.wait(1) if mainFrame.Visible and tick() - lastUIInteraction > 30 then mainFrame.Visible = false end end end)

-- ==============================================================================
-- 2. BACKEND (NO DELAY SKILLS)
-- ==============================================================================
task.spawn(function() pcall(function() local dr = ReplicatedStorage:WaitForChild("Damage", 10); local h = hookmetamethod or getgenv().hookmetamethod; if h and dr then local o; o = h(game, "__namecall", newcclosure(function(s, ...) if _G.GodMode and (s == dr or (s.Name == "Damage" and s.Parent == ReplicatedStorage)) and getnamecallmethod() == "FireServer" then return nil end return o(s, ...) end)) end end) end)

local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then ClickEvent:FireServer(true); lastMB1 = tick() end end
local function enforceSpeed(hum) if hum.WalkSpeed < 26 then hum.WalkSpeed = 26 end end

-- FAST AUTO-SKILLS (NO DELAY)
local function castSkills(target)
    autoClick() 
    local char = player.Character; if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local er = target:FindFirstChild("HumanoidRootPart")
    if not er or (root.Position - er.Position).Magnitude > 22 then return end 

    for _, key in ipairs({"Q", "E", "R", "F"}) do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
    end
end

local function getNextTarget()
    local c = player.Character; if not c or not c:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    local p, b, g, r = {}, {}, {}, {}; for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("Humanoid") and v.Parent ~= c and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then local m = v.Parent; local n = m.Name; if not n:find("Frostwoven") and not n:find("Gate") then if n:find("Progenitor") then table.insert(p, m) elseif n:find("Boss") or n:find("Colossus") or n:find("Snowman") or n:find("Elemental") then table.insert(b, m) elseif n:find("Glacial") then table.insert(g, m) else table.insert(r, m) end end end end
    local function s(x, y) return (c.HumanoidRootPart.Position - x.HumanoidRootPart.Position).Magnitude < (c.HumanoidRootPart.Position - y.HumanoidRootPart.Position).Magnitude end
    table.sort(p, s); table.sort(b, s); table.sort(g, s); table.sort(r, s)
    if #g > 0 then local tg = g[1]; for _, run in ipairs(r) do if run.Name:find("Spruced") and (run.HumanoidRootPart.Position - tg.HumanoidRootPart.Position).Magnitude < 50 then return run, "AGGRO" end end end
    if #p > 0 then return p[1], "KILL" end; if #b > 0 then return b[1], "KILL" end; if #g > 0 then return g[1], "KILL" end; for _, v in ipairs(r) do if not visitedMobs[v] then return v, "AGGRO" end end; return nil, "CLEAR"
end

local function runTo(target, mode)
    local c = player.Character; local root = c:WaitForChild("HumanoidRootPart"); local hum = c:WaitForChild("Humanoid"); local er = target:FindFirstChild("HumanoidRootPart"); if not er then return end
    enforceSpeed(hum)
    if mode == "KILL" and (root.Position - er.Position).Magnitude < 20 then hum:MoveTo(er.Position); root.CFrame = CFrame.new(root.Position, Vector3.new(er.Position.X, root.Position.Y, er.Position.Z)); castSkills(target); return end
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true}); pcall(function() path:ComputeAsync(root.Position, er.Position) end)
    if path.Status == Enum.PathStatus.Success then for _, wp in ipairs(path:GetWaypoints()) do if not _G.DungeonMaster then break end; if wp.Position.Y > root.Position.Y + 4.5 then hum.Jump = true end; hum:MoveTo(wp.Position); autoClick(); local t = 0; while (root.Position - wp.Position).Magnitude > 4 do RunService.Heartbeat:Wait(); t = t + 1; if t > 60 then hum.Jump = true; return end end end else hum:MoveTo(er.Position) end
end

task.spawn(function() while true do task.wait(2); if _G.AutoStart then local isF = false; local c = player.Character; if c then for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("Humanoid") and v.Parent ~= c and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") and (v.Parent.HumanoidRootPart.Position - c.PrimaryPart.Position).Magnitude < 100 then isF = true break end end end; if not isF then pcall(function() ReplicatedStorage:WaitForChild("Start", 1):FireServer() end) end end end end)
task.spawn(function() while true do if _G.DungeonMaster then RunService.Heartbeat:Wait(); pcall(function() local c = player.Character or player.CharacterAdded:Wait(); local t, m = getNextTarget(); if t then updateStatus("Fighting: " .. t.Name); runTo(t, m) else visitedMobs = {}; local me = tick() + 4; while tick() < me and _G.DungeonMaster do c.Humanoid:MoveTo(c.HumanoidRootPart.Position + c.HumanoidRootPart.CFrame.LookVector * 20); RunService.Heartbeat:Wait() end end end) else updateStatus("Paused"); task.wait(1) end end end)
