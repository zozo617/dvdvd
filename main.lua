if not game:IsLoaded() then game.Loaded:Wait() end

-- [SERVICES]
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- [UNIVERSAL REQUEST]
local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- ==============================================================================
-- 0. CONFIGURATION & STATE
-- ==============================================================================
_G.DungeonMaster = true  
_G.AutoStart = true      
_G.GodMode = true        
_G.AutoSell = true       

-- Webhook Settings (UPDATED)
_G.WebhookUrl = "https://discord.com/api/webhooks/1446663395980873830/XIzk9dyFM1FOnggrSjTevw_nGonsWlc3P9lrDVLsoLg-oE3U6jU5iEedFp2oU8D_sotR"
_G.WebhookEnabled = true
_G.PingLegendary = false
_G.PingMythic = false
_G.PingFabled = false

local SellSettings = {
    Types = { ["Weapon"] = true, ["Leggings"] = true, ["Armor"] = true, ["Helmet"] = true, ["Emblem"] = false, ["Spell"] = true },
    Rarities = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = false, [6] = false, [7] = false }
}

-- [SAVE SYSTEM - INSTANT]
local FolderName = "sanjigoat"
local SettingsFileName = FolderName .. "/SanjiHubSettings.json"
local RunFileName = FolderName .. "/SanjiRuns.txt"

-- Create folder immediately
if not isfolder(FolderName) then makefolder(FolderName) end

local function SaveSettings()
    local data = {
        DungeonMaster=_G.DungeonMaster, AutoStart=_G.AutoStart, GodMode=_G.GodMode, AutoSell=_G.AutoSell,
        SellConfig=SellSettings, WebhookEnabled=_G.WebhookEnabled, WebhookUrl=_G.WebhookUrl,
        PingL=_G.PingLegendary, PingM=_G.PingMythic, PingF=_G.PingFabled
    }
    pcall(function() writefile(SettingsFileName, HttpService:JSONEncode(data)) end)
end

local function LoadSettings()
    if isfile(SettingsFileName) then
        local s, r = pcall(function() return HttpService:JSONDecode(readfile(SettingsFileName)) end)
        if s and r then
            _G.DungeonMaster = r.DungeonMaster; _G.AutoStart = r.AutoStart; _G.GodMode = r.GodMode; _G.AutoSell = r.AutoSell
            if r.WebhookEnabled ~= nil then _G.WebhookEnabled = r.WebhookEnabled end
            if r.WebhookUrl ~= nil then _G.WebhookUrl = r.WebhookUrl end
            _G.PingLegendary = r.PingL; _G.PingMythic = r.PingM; _G.PingFabled = r.PingF
        end
    else SaveSettings() end
end
LoadSettings()

-- Runs Tracker
local totalRuns = 0
pcall(function()
    if isfile(RunFileName) then totalRuns = tonumber(readfile(RunFileName)) or 0 end
    totalRuns = totalRuns + 1
    writefile(RunFileName, tostring(totalRuns))
end)

-- Internal Vars
local visitedMobs = {} 
local lastMB1 = 0               
local MB1_COOLDOWN = 0.1 
local ClickEvent = ReplicatedStorage:WaitForChild("Click")
local lastPos = Vector3.new(0,0,0) 
local stuckCount = 0

-- Wait for inventory
task.spawn(function()
    repeat task.wait() until workspace:FindFirstChild("Inventories")
    repeat task.wait() until workspace.Inventories:FindFirstChild(Player.Name)
end)

-- ==============================================================================
-- 1. WEBHOOK SYSTEM (ADVANCED)
-- ==============================================================================
local function abbreviate(n)
    if n >= 1e12 then return string.format("%.2ft", n/1e12)
    elseif n >= 1e9 then return string.format("%.2fb", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fm", n/1e6)
    elseif n >= 1e3 then return string.format("%.2fk", n/1e3)
    else return tostring(n) end
end

local function getRarityEmoji(rarity)
    local emojis = { ["legendary"]="🟡", ["mythic"]="🔴", ["fabled"]="⚫", ["epic"]="🟣", ["rare"]="🔵", ["uncommon"]="🟢", ["common"]="⚪" }
    return emojis[string.lower(rarity)] or "❓"
end

local function getCurrentInventory()
    local inventory = {totalCount = 0, itemData = {}}
    local invFolder = Workspace.Inventories:FindFirstChild(Player.Name)
    if not invFolder or not invFolder:FindFirstChild("Items") then return inventory end
    
    for _, item in pairs(invFolder.Items:GetChildren()) do
        if item:IsA("StringValue") then
            local data = item.Value:split(",")
            local itemName = data[1]:match("%d+_(.+)") or data[1]
            local rarityId = tonumber(data[2])
            local rarities = {[1]="Common", [2]="Uncommon", [3]="Rare", [4]="Epic", [5]="Legendary", [6]="Mythic", [7]="Fabled"}
            local rName = rarities[rarityId] or "Unknown"
            local fullName = string.format("%s (%s)", itemName, rName)
            
            inventory.totalCount = inventory.totalCount + 1
            inventory.itemData[fullName] = (inventory.itemData[fullName] or 0) + 1
        end
    end
    return inventory
end

local function sendStatsWebhook(title, description, fields, ping)
    if not _G.WebhookEnabled or _G.WebhookUrl == "" then return end
    
    local inv = Workspace.Inventories:FindFirstChild(Player.Name)
    if not inv then return end
    
    local xpStr = abbreviate(inv.Experience.Value) .. "/" .. abbreviate(inv.ExperienceNeeded.Value)
    local currentInv = getCurrentInventory()
    
    local playerStats = string.format(
        "👤 **%s**\n💰 Gold: %s\n📊 Level: %d\n⭐ XP: %s\n📦 Inventory: %d/%d\n🔄 Runs: %d",
        Player.Name, abbreviate(inv.Gold.Value), inv.Level.Value, xpStr, currentInv.totalCount, inv.MaxItems.Value, totalRuns
    )

    local embed = {
        title = "📊 " .. title,
        description = description .. "\n\n" .. playerStats,
        fields = fields,
        color = 5814783,
        footer = {text="Sanji Goat Hub"},
        timestamp = DateTime.now():ToIsoDate()
    }

    request({
        Url = _G.WebhookUrl,
        Method = "POST",
        Headers = {["Content-Type"]="application/json"},
        Body = HttpService:JSONEncode({content = ping and "@everyone" or "", embeds = {embed}})
    })
end

-- Webhook Background Loop
task.spawn(function()
    local lastInventory = getCurrentInventory()
    -- Send Initial
    sendStatsWebhook("Script Started", "Monitoring active.", {}, false)
    
    while true do
        task.wait(5)
        if _G.WebhookEnabled and _G.WebhookUrl ~= "" then
            local current = getCurrentInventory()
            local newItems = {}
            local hasRare = false
            
            for name, count in pairs(current.itemData) do
                local old = lastInventory.itemData[name] or 0
                if count > old then
                    local diff = count - old
                    local rarity = name:match("%((.+)%)") or "Common"
                    table.insert(newItems, string.format("%s %s x%d", getRarityEmoji(rarity), name, diff))
                    
                    if (_G.PingLegendary and name:find("Legendary")) or 
                       (_G.PingMythic and name:find("Mythic")) or 
                       (_G.PingFabled and name:find("Fabled")) then
                        hasRare = true
                    end
                end
            end
            
            if #newItems > 0 then
                sendStatsWebhook("Items Found", "", {{name="📦 Drops", value=table.concat(newItems, "\n"), inline=false}}, hasRare)
            end
            lastInventory = current
        end
    end
end)

-- ==============================================================================
-- 2. COMBAT LOGIC
-- ==============================================================================
task.spawn(function()
    pcall(function()
        local DamageRemote = ReplicatedStorage:WaitForChild("Damage", 10)
        local h = hookmetamethod or getgenv().hookmetamethod
        if h and DamageRemote then
            local OldNameCall; OldNameCall = h(game, "__namecall", newcclosure(function(Self, ...)
                if _G.GodMode and (Self == DamageRemote or (Self.Name == "Damage" and Self.Parent == ReplicatedStorage)) and getnamecallmethod() == "FireServer" then return nil end
                return OldNameCall(Self, ...)
            end))
        end
    end)
end)

local function autoClick() if tick()-lastMB1 > MB1_COOLDOWN then ClickEvent:FireServer(true); lastMB1=tick() end end
local function castSkills()
    autoClick() 
    for _, k in ipairs({"Q","E","R","F"}) do 
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[k], false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[k], false, game)
    end
end

-- ==============================================================================
-- 3. UI SETUP
-- ==============================================================================
if Player.PlayerGui:FindFirstChild("SanjiUnified") then Player.PlayerGui.SanjiUnified:Destroy() end
local ScreenGui = Instance.new("ScreenGui", Player.PlayerGui); ScreenGui.Name="SanjiUnified"

local MainFrame = Instance.new("Frame", ScreenGui); MainFrame.Size=UDim2.new(0,180,0,320); MainFrame.Position=UDim2.new(0.5,-90,0.2,0)
MainFrame.BackgroundColor3=Color3.fromRGB(20,20,20); Instance.new("UICorner",MainFrame).CornerRadius=UDim.new(0,10)

-- Dragging
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=input.Position; startPos=MainFrame.Position end end)
MainFrame.InputChanged:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseMovement then dragInput=input end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input==dragInput then local delta=input.Position-dragStart; MainFrame.Position=UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y) end end)
MainFrame.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

local function createBtn(txt, pos, state, callback)
    local b = Instance.new("TextButton", MainFrame); b.Size=UDim2.new(0.9,0,0,30); b.Position=pos
    b.BackgroundColor3 = state and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50)
    b.Text = txt .. (state and " [ON]" or " [OFF]")
    b.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", b).CornerRadius=UDim.new(0,6)
    b.MouseButton1Click:Connect(function() callback(b) end)
    return b
end

-- Buttons
createBtn("Auto Farm", UDim2.new(0.05,0,0.05,0), _G.DungeonMaster, function(b) _G.DungeonMaster=not _G.DungeonMaster; b.BackgroundColor3=_G.DungeonMaster and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="Auto Farm"..(_G.DungeonMaster and " [ON]" or " [OFF]"); SaveSettings() end)
createBtn("Auto Start", UDim2.new(0.05,0,0.18,0), _G.AutoStart, function(b) _G.AutoStart=not _G.AutoStart; b.BackgroundColor3=_G.AutoStart and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="Auto Start"..(_G.AutoStart and " [ON]" or " [OFF]"); SaveSettings() end)
createBtn("God Mode", UDim2.new(0.05,0,0.31,0), _G.GodMode, function(b) _G.GodMode=not _G.GodMode; b.BackgroundColor3=_G.GodMode and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="God Mode"..(_G.GodMode and " [ON]" or " [OFF]"); SaveSettings() end)
createBtn("Auto Sell", UDim2.new(0.05,0,0.44,0), _G.AutoSell, function(b) _G.AutoSell=not _G.AutoSell; b.BackgroundColor3=_G.AutoSell and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="Auto Sell"..(_G.AutoSell and " [ON]" or " [OFF]"); SaveSettings() end)

-- WEBHOOK MENU UI
local WebFrame = Instance.new("Frame", MainFrame); WebFrame.Size=UDim2.new(1.1,0,0.7,0); WebFrame.Position=UDim2.new(1.05,0,0,0)
WebFrame.BackgroundColor3=Color3.fromRGB(30,30,30); WebFrame.Visible=false; Instance.new("UICorner",WebFrame).CornerRadius=UDim.new(0,8)

local WInput = Instance.new("TextBox", WebFrame); WInput.Size=UDim2.new(0.9,0,0.2,0); WInput.Position=UDim2.new(0.05,0,0.05,0)
WInput.Text=_G.WebhookUrl; WInput.PlaceholderText="Webhook URL"; WInput.TextColor3=Color3.new(1,1,1); WInput.BackgroundColor3=Color3.fromRGB(50,50,50); WInput.TextWrapped=true
WInput.FocusLost:Connect(function() _G.WebhookUrl=WInput.Text; SaveSettings() end)

local function createWBtn(txt, pos, state, callback)
    local b = Instance.new("TextButton", WebFrame); b.Size=UDim2.new(0.9,0,0.15,0); b.Position=pos
    b.BackgroundColor3 = state and Color3.fromRGB(100,50,50) or Color3.fromRGB(100,50,50)
    if state then b.BackgroundColor3 = Color3.fromRGB(0,255,100) end
    b.Text=txt .. (state and " [ON]" or " [OFF]"); b.TextColor3=Color3.new(1,1,1); b.MouseButton1Click:Connect(function() callback(b) end); Instance.new("UICorner", b)
end

createWBtn("Ping Legendary", UDim2.new(0.05,0,0.3,0), _G.PingLegendary, function(b) _G.PingLegendary=not _G.PingLegendary; b.BackgroundColor3=_G.PingLegendary and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="Ping Legendary"..(_G.PingLegendary and " [ON]" or " [OFF]"); SaveSettings() end)
createWBtn("Ping Mythic", UDim2.new(0.05,0,0.5,0), _G.PingMythic, function(b) _G.PingMythic=not _G.PingMythic; b.BackgroundColor3=_G.PingMythic and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="Ping Mythic"..(_G.PingMythic and " [ON]" or " [OFF]"); SaveSettings() end)
createWBtn("Start Webhook", UDim2.new(0.05,0,0.7,0), _G.WebhookEnabled, function(b) _G.WebhookEnabled=not _G.WebhookEnabled; b.BackgroundColor3=_G.WebhookEnabled and Color3.fromRGB(0,255,100) or Color3.fromRGB(100,50,50); b.Text="Start Webhook"..(_G.WebhookEnabled and " [ON]" or " [OFF]"); SaveSettings() end)

createBtn("Webhook Menu", UDim2.new(0.05,0,0.6,0), false, function() WebFrame.Visible=not WebFrame.Visible end)

-- ==============================================================================
-- 4. LOGIC
-- ==============================================================================
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

local function runAutoSell()
    local playerInv = Workspace.Inventories:FindFirstChild(player.Name)
    if not playerInv or not playerInv:FindFirstChild("Items") then return end
    local equipped = {}
    for _, s in pairs({"Weapon", "Leggings", "Armor", "Helmet", "Emblem", "Spell1", "Spell2"}) do
        if playerInv:FindFirstChild(s) and playerInv[s]:IsA("StringValue") then equipped[playerInv[s].Value] = true end
    end
    for _, item in pairs(playerInv.Items:GetChildren()) do
        if item:IsA("StringValue") then
            local d = item.Value:split(","); local r = tonumber(d[2])
            if SellSettings.Rarities[r] and not equipped[item.Name] then
                local info = Workspace.Items:FindFirstChild(d[1])
                if info and info:FindFirstChild("Info") then
                    local type = info.Info.Value:split(",")[1]
                    if SellSettings.Types[type] then ReplicatedStorage.SellItem:FireServer({[1]={[1]=item.Name}}) task.wait(0.1) end
                end
            end
        end
    end
end

local function getNextTarget()
    local char = Player.Character; if not char then return nil end
    local colossus, boss, elite, mob = nil, nil, nil, nil
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then
            local m = v.Parent
            if not Players:GetPlayerFromCharacter(m) then
                local n = m.Name:lower()
                if n:find("arctic colossus") then colossus = m
                elseif n:find("blizzard") or n:find("everfrost") then boss = m
                elseif n:find("bonechill") or n:find("frostwind") or n:find("snowman") then elite = m
                else mob = m end
            end
        end
    end
    return colossus or boss or elite or mob
end

task.spawn(function() while true do task.wait(1) if _G.AutoStart then local r = ReplicatedStorage:FindFirstChild("Start") if r then r:FireServer() end end end end)
task.spawn(function() while true do task.wait(5) if _G.AutoSell then pcall(runAutoSell) end end end)

task.spawn(function()
    while true do
        if _G.DungeonMaster then
            pcall(function()
                local t = getNextTarget()
                if t then
                    local char = Player.Character
                    local dist = (char.HumanoidRootPart.Position - t.HumanoidRootPart.Position).Magnitude
                    castSkills()
                    if dist > 20 then
                        char.Humanoid:MoveTo(t.HumanoidRootPart.Position)
                        checkWallAndJump()
                    end
                else
                    local gate = nil
                    for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Gate" or v.Name == "Portal" then gate = v break end end
                    if gate then
                        Player.Character.Humanoid:MoveTo(gate.Position)
                        if (Player.Character.HumanoidRootPart.Position - gate.Position).Magnitude < 10 then totalRuns=totalRuns+1; SaveSettings(); task.wait(2) end
                    end
                end
            end)
        end
        RunService.Heartbeat:Wait()
    end
end)

print("[Script] Sanji's Master Hub Loaded")
