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
local currentTargetName = ""
local targetStartTime = 0

local ClickEvent = ReplicatedStorage:WaitForChild("Click")

-- ==============================================================================
-- 1. PREMIUM TABBED UI
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiScript") then player.PlayerGui.SanjiScript:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiScript"

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = guiObject.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart; guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
end

-- MAIN FRAME
local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(10, 10, 12); mainFrame.BackgroundTransparency = 0.1; mainFrame.Position=UDim2.new(0.5, -100, 0.4, 0); mainFrame.Size=UDim2.new(0,200,0,240); makeDraggable(mainFrame); mainFrame.Visible = false 
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", mainFrame); mainStroke.Color = Color3.fromRGB(138, 43, 226); mainStroke.Thickness = 2

-- HOME BUTTON (Logo)
local houseBtn = Instance.new("ImageButton", screenGui); houseBtn.Name="HomeBtn"; houseBtn.BackgroundColor3=Color3.fromRGB(15, 15, 18); houseBtn.Position=UDim2.new(0.9,0,0.15,0); houseBtn.Size=UDim2.new(0,60,0,60); houseBtn.Image = "rbxassetid://138612143003295" 
Instance.new("UICorner", houseBtn).CornerRadius = UDim.new(0, 15); makeDraggable(houseBtn); houseBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)
local houseStroke = Instance.new("UIStroke", houseBtn); houseStroke.Color = Color3.fromRGB(138, 43, 226); houseStroke.Thickness = 2

-- TAB NAVIGATION
local tabHolder = Instance.new("Frame", mainFrame); tabHolder.Size = UDim2.new(1, 0, 0, 30); tabHolder.BackgroundTransparency = 1; tabHolder.Position = UDim2.new(0, 0, 0, 35)
local contentHolder = Instance.new("Frame", mainFrame); contentHolder.Size = UDim2.new(1, 0, 1, -70); contentHolder.Position = UDim2.new(0, 0, 0, 70); contentHolder.BackgroundTransparency = 1

local title = Instance.new("TextLabel", mainFrame); title.Size=UDim2.new(1,0,0,35); title.BackgroundTransparency=1; title.Text="SANJI PREMIUM"; title.TextColor3=Color3.fromRGB(180, 100, 255); title.Font = Enum.Font.GothamBold; title.TextSize = 14

local tabs = {}
local function createTab(name, order)
    local tabBtn = Instance.new("TextButton", tabHolder); tabBtn.Size = UDim2.new(0.5, 0, 1, 0); tabBtn.Position = UDim2.new((order-1)*0.5, 0, 0, 0); tabBtn.BackgroundTransparency = 1; tabBtn.Text = name; tabBtn.TextColor3 = Color3.fromRGB(150, 150, 150); tabBtn.Font = Enum.Font.GothamSemibold; tabBtn.TextSize = 11
    local underline = Instance.new("Frame", tabBtn); underline.Size = UDim2.new(0.8, 0, 0, 2); underline.Position = UDim2.new(0.1, 0, 1, -2); underline.BackgroundColor3 = Color3.fromRGB(138, 43, 226); underline.Visible = false
    local container = Instance.new("ScrollingFrame", contentHolder); container.Size = UDim2.new(1, 0, 1, 0); container.BackgroundTransparency = 1; container.Visible = false; container.CanvasSize = UDim2.new(0,0,0,0); container.ScrollBarThickness = 0
    
    tabBtn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabs) do t.btn.TextColor3 = Color3.fromRGB(150, 150, 150); t.line.Visible = false; t.view.Visible = false end
        tabBtn.TextColor3 = Color3.new(1, 1, 1); underline.Visible = true; container.Visible = true
    end)
    tabs[name] = {btn = tabBtn, line = underline, view = container}
    return container
end

local farmTab = createTab("FARMING", 1)
local charTab = createTab("SETTINGS", 2)
tabs["FARMING"].btn.TextColor3 = Color3.new(1, 1, 1); tabs["FARMING"].line.Visible = true; tabs["FARMING"].view.Visible = true

-- PREMIUM BUTTON CREATOR
local function addToggle(parent, text, y, default, callback)
    local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(0.9, 0, 0, 35); btn.Position = UDim2.new(0.05, 0, 0, y); btn.BackgroundColor3 = default and Color3.fromRGB(40, 20, 80) or Color3.fromRGB(25, 25, 30); btn.Text = text; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 11; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() local s = callback(); btn.BackgroundColor3 = s and Color3.fromRGB(70, 30, 150) or Color3.fromRGB(25, 25, 30) end)
end

addToggle(farmTab, "AUTO FARM", 10, _G.DungeonMaster, function() _G.DungeonMaster = not _G.DungeonMaster return _G.DungeonMaster end)
addToggle(farmTab, "AUTO START", 55, _G.AutoStart, function() _G.AutoStart = not _G.AutoStart return _G.AutoStart end)
addToggle(charTab, "GOD MODE", 10, _G.GodMode, function() _G.GodMode = not _G.GodMode return _G.GodMode end)

-- ==============================================================================
-- 2. BACKEND
-- ==============================================================================
task.spawn(function() pcall(function() local dr = ReplicatedStorage:WaitForChild("Damage", 10); local h = hookmetamethod or getgenv().hookmetamethod; if h and dr then local o; o = h(game, "__namecall", newcclosure(function(s, ...) if _G.GodMode and (s == dr or (s.Name == "Damage" and s.Parent == ReplicatedStorage)) and getnamecallmethod() == "FireServer" then return nil end return o(s, ...) end)) end end) end)
local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then ClickEvent:FireServer(true); lastMB1 = tick() end end
local function getNextTarget()
    local c = player.Character; if not c or not c:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    local p, b, g, r = {}, {}, {}, {}; for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("Humanoid") and v.Parent ~= c and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then local m = v.Parent; local n = m.Name; if not n:find("Frostwoven") and not n:find("Gate") then if n:find("Progenitor") then table.insert(p, m) elseif n:find("Boss") or n:find("Colossus") or n:find("Snowman") or n:find("Elemental") then table.insert(b, m) elseif n:find("Glacial") then table.insert(g, m) else table.insert(r, m) end end end end
    local function s(x, y) return (c.HumanoidRootPart.Position - x.HumanoidRootPart.Position).Magnitude < (c.HumanoidRootPart.Position - y.HumanoidRootPart.Position).Magnitude end
    table.sort(p, s); table.sort(b, s); table.sort(g, s); table.sort(r, s)
    if #g > 0 then local tg = g[1]; for _, run in ipairs(r) do if run.Name:find("Spruced") and not visitedMobs[run] and (run.HumanoidRootPart.Position - tg.HumanoidRootPart.Position).Magnitude < 50 then return run, "AGGRO" end end end
    if #p > 0 then return p[1], "KILL" end; if #b > 0 then return b[1], "KILL" end; if #g > 0 then return g[1], "KILL" end; for _, v in ipairs(r) do if not visitedMobs[v] then return v, "AGGRO" end end; return nil, "CLEAR"
end
local function runTo(target, mode)
    local c = player.Character; local root = c:WaitForChild("HumanoidRootPart"); local hum = c:WaitForChild("Humanoid"); local er = target:FindFirstChild("HumanoidRootPart"); if not er then return end
    if (root.Position - lastPosition).Magnitude < 2 then if tick() - lastMoveTime > 6 then hum.Jump = true; hum:MoveTo(root.Position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))); lastMoveTime = tick(); return end else lastMoveTime = tick(); lastPosition = root.Position end
    if mode == "KILL" and (root.Position - er.Position).Magnitude < 20 then hum:MoveTo(er.Position); root.CFrame = CFrame.new(root.Position, Vector3.new(er.Position.X, root.Position.Y, er.Position.Z)); autoClick(); return end
    if mode == "AGGRO" and (root.Position - er.Position).Magnitude < 30 then visitedMobs[target] = true; return end
    local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true}); pcall(function() path:ComputeAsync(root.Position, er.Position) end)
    if path.Status == Enum.PathStatus.Success then for _, wp in ipairs(path:GetWaypoints()) do if not _G.DungeonMaster then break end; if wp.Position.Y > root.Position.Y + 4.5 then hum.Jump = true end; hum:MoveTo(wp.Position); autoClick(); local t = 0; while (root.Position - wp.Position).Magnitude > 4 do RunService.Heartbeat:Wait(); t = t + 1; if t > 60 then hum.Jump = true; return end end end else hum:MoveTo(er.Position) end
end
task.spawn(function() while true do task.wait(2); if _G.AutoStart then local isF = false; local c = player.Character; if c then for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("Humanoid") and v.Parent ~= c and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") and (v.Parent.HumanoidRootPart.Position - c.PrimaryPart.Position).Magnitude < 100 then isF = true break end end end; if not isF then pcall(function() ReplicatedStorage:WaitForChild("Start", 1):FireServer() end) end end end end)
task.spawn(function() while true do if _G.DungeonMaster then RunService.Heartbeat:Wait(); pcall(function() local c = player.Character or player.CharacterAdded:Wait(); local t, m = getNextTarget(); if t then runTo(t, m) else visitedMobs = {}; local me = tick() + 4; while tick() < me and _G.DungeonMaster do c.Humanoid:MoveTo(c.HumanoidRootPart.Position + c.HumanoidRootPart.CFrame.LookVector * 20); RunService.Heartbeat:Wait() end end end) else task.wait(1) end end end)
