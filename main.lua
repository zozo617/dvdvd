local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==============================================================================
-- 0. MULTI-KEY CONFIGURATION
-- ==============================================================================
local ValidKeys = {
    "SanjiGoated",
    "VIP_Access_Sanji",
    "Product_Key_123",
    "Beta_Tester_SN"
}
local KeyAccepted = false

-- ==============================================================================
-- 1. KEY UI OVERLAY
-- ==============================================================================
if player.PlayerGui:FindFirstChild("SanjiKeySystem") then player.PlayerGui.SanjiKeySystem:Destroy() end
local keyGui = Instance.new("ScreenGui", player.PlayerGui); keyGui.Name = "SanjiKeySystem"

local keyFrame = Instance.new("Frame", keyGui); keyFrame.Size = UDim2.new(0, 250, 0, 150); keyFrame.Position = UDim2.new(0.5, -125, 0.4, 0); keyFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); keyFrame.BorderSizePixel = 0
Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 12)
local keyStroke = Instance.new("UIStroke", keyFrame); keyStroke.Color = Color3.fromRGB(138, 43, 226); keyStroke.Thickness = 2

local keyTitle = Instance.new("TextLabel", keyFrame); keyTitle.Size = UDim2.new(1, 0, 0, 40); keyTitle.BackgroundTransparency = 1; keyTitle.Text = "ENTER PRODUCT KEY"; keyTitle.TextColor3 = Color3.fromRGB(180, 100, 255); keyTitle.Font = Enum.Font.GothamBold; keyTitle.TextSize = 14

local keyInput = Instance.new("TextBox", keyFrame); keyInput.Size = UDim2.new(0.8, 0, 0, 35); keyInput.Position = UDim2.new(0.1, 0, 0.4, 0); keyInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30); keyInput.PlaceholderText = "Input Key..."; keyInput.Text = ""; keyInput.TextColor3 = Color3.new(1, 1, 1); keyInput.Font = Enum.Font.Gotham; keyInput.TextSize = 12
Instance.new("UICorner", keyInput).CornerRadius = UDim.new(0, 6)

local submitBtn = Instance.new("TextButton", keyFrame); submitBtn.Size = UDim2.new(0.8, 0, 0, 35); submitBtn.Position = UDim2.new(0.1, 0, 0.7, 0); submitBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 150); submitBtn.Text = "SUBMIT"; submitBtn.TextColor3 = Color3.new(1, 1, 1); submitBtn.Font = Enum.Font.GothamBold; submitBtn.TextSize = 12
Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0, 6)

-- Multi-Key Validation Logic
submitBtn.MouseButton1Click:Connect(function()
    local input = keyInput.Text
    local found = false
    
    for _, key in ipairs(ValidKeys) do
        if input == key then
            found = true
            break
        end
    end
    
    if found then
        submitBtn.Text = "ACCESS GRANTED"; submitBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        task.wait(1)
        keyGui:Destroy()
        KeyAccepted = true
    else
        submitBtn.Text = "INVALID KEY"; submitBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        task.wait(1)
        submitBtn.Text = "SUBMIT"; submitBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 150)
    end
end)

repeat task.wait() until KeyAccepted

-- ==============================================================================
-- 2. MAIN SCRIPT START (PREMIUM TABBED UI)
-- ==============================================================================
_G.DungeonMaster = true 
_G.AutoStart = true     
_G.GodMode = true       

local visitedMobs = {} 
local lastMB1 = 0           
local MB1_COOLDOWN = 0.25 
local lastMoveTime = tick()
local lastPosition = Vector3.new(0,0,0)
local ClickEvent = ReplicatedStorage:WaitForChild("Click")

if player.PlayerGui:FindFirstChild("SanjiScript") then player.PlayerGui.SanjiScript:Destroy() end
local screenGui = Instance.new("ScreenGui", player.PlayerGui); screenGui.Name = "SanjiScript"

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = guiObject.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end end)
    guiObject.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then local delta = input.Position - dragStart; guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
end

local mainFrame = Instance.new("Frame", screenGui); mainFrame.Name="MainFrame"; mainFrame.BackgroundColor3=Color3.fromRGB(10, 10, 12); mainFrame.BackgroundTransparency = 0.1; mainFrame.Position=UDim2.new(0.5, -100, 0.4, 0); mainFrame.Size=UDim2.new(0,200,0,240); makeDraggable(mainFrame); mainFrame.Visible = false 
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", mainFrame); mainStroke.Color = Color3.fromRGB(138, 43, 226); mainStroke.Thickness = 2

local houseBtn = Instance.new("ImageButton", screenGui); houseBtn.Name="HomeBtn"; houseBtn.BackgroundColor3=Color3.fromRGB(15, 15, 18); houseBtn.Position=UDim2.new(0.9,0,0.15,0); houseBtn.Size=UDim2.new(0,60,0,60); houseBtn.Image = "rbxassetid://138612143003295" 
Instance.new("UICorner", houseBtn).CornerRadius = UDim.new(0, 15); makeDraggable(houseBtn); houseBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)
local houseStroke = Instance.new("UIStroke", houseBtn); houseStroke.Color = Color3.fromRGB(138, 43, 226); houseStroke.Thickness = 2

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

local function addToggle(parent, text, y, default, callback)
    local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(0.9, 0, 0, 35); btn.Position = UDim2.new(0.05, 0, 0, y); btn.BackgroundColor3 = default and Color3.fromRGB(40, 20, 80) or Color3.fromRGB(25, 25, 30); btn.Text = text; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 11; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() local s = callback(); btn.BackgroundColor3 = s and Color3.fromRGB(70, 30, 150) or Color3.fromRGB(25, 25, 30) end)
end

addToggle(farmTab, "AUTO FARM", 10, _G.DungeonMaster, function() _G.DungeonMaster = not _G.DungeonMaster return _G.DungeonMaster end)
addToggle(farmTab, "AUTO START", 55, _G.AutoStart, function() _G.AutoStart = not _G.AutoStart return _G.AutoStart end)
addToggle(charTab, "GOD MODE", 10, _G.GodMode, function() _G.GodMode = not _G.GodMode return _G.GodMode end)

-- [Rest of the Combat & Navigation Logic continues...]
