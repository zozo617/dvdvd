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

-- [UNIVERSAL WEBHOOK REQUEST]
local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- ==============================================================================
-- 0. CONFIGURATION & STATE
-- ==============================================================================
_G.DungeonMaster = true  
_G.AutoStart = true      
_G.GodMode = true        
_G.AutoSell = true       

-- Webhook Config (Set these via UI or here)
_G.WebhookUrl = "https://discord.com/api/webhooks/1446663395980873830/XIzk9dyFM1FOnggrSjTevw_nGonsWlc3P9lrDVLsoLg-oE3U6jU5iEedFp2oU8D_sotR"
_G.WebhookEnabled = true
_G.PingLegendary = false
_G.PingMythic = false
_G.PingFabled = false

local SellSettings = {
    Types = { ["Weapon"] = true, ["Leggings"] = true, ["Armor"] = true, ["Helmet"] = true, ["Emblem"] = false, ["Spell"] = true },
    Rarities = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = false, [6] = false, [7] = false }
}

-- ==============================================================================
-- 1. UTILITY FUNCTIONS
-- ==============================================================================
local function abbreviate(n)
    if n >= 1000000 then
        return string.format("%.2fm", n / 1000000):gsub("%.00m", "m"):gsub("%.(%d)0m", ".%1m")
    elseif n >= 1000 then
        return string.format("%.2fk", n / 1000):gsub("%.00k", "k"):gsub("%.(%d)0k", ".%1k")
    else
        return tostring(n)
    end
end

local function getRarityEmoji(rarity)
    local emojis = { ["legendary"] = "🟡", ["mythic"] = "🔴", ["fabled"] = "⚫", ["epic"] = "🟣", ["rare"] = "🔵", ["uncommon"] = "🟢", ["common"] = "⚪" }
    return emojis[string.lower(rarity)] or "❓"
end

-- ==============================================================================
-- 2. WEBHOOK SYSTEM (SNAPSHOT LOGIC)
-- ==============================================================================
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
            local fullName = string.format("%s (%s)", itemName, rarities[rarityId] or "Unknown")
            
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
        "👤 **%s**\n📊 Level: %d\n⭐ XP: %s\n💰 Gold: %s\n📦 Inventory: %d/%d\n🔄 Total Runs: %d",
        Player.Name, inv.Level.Value, xpStr, abbreviate(inv.Gold.Value), currentInv.totalCount, inv.MaxItems.Value, _G.TotalRuns or 0
    )

    local embed = {
        ["title"] = "📊 " .. title,
        ["description"] = description .. "\n\n" .. playerStats,
        ["fields"] = fields,
        ["color"] = 5814783,
        ["footer"] = {["text"] = "Sanji Goat Hub"},
        ["timestamp"] = DateTime.now():ToIsoDate()
    }

    request({
        Url = _G.WebhookUrl,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            ["content"] = ping and "@everyone" or "",
            ["embeds"] = {embed}
        })
    })
end

-- BACKGROUND MONITOR
task.spawn(function()
    local lastInventory = getCurrentInventory()
    while true do
        task.wait(5)
        if _G.WebhookEnabled and _G.WebhookUrl ~= "" then
            local current = getCurrentInventory()
            local newItems = {}
            local hasRare = false
            
            for name, count in pairs(current.itemData) do
                local oldCount = lastInventory.itemData[name] or 0
                if count > oldCount then
                    local diff = count - oldCount
                    table.insert(newItems, name .. (diff > 1 and " x"..diff or ""))
                    
                    if (_G.PingLegendary and name:find("Legendary")) or 
                       (_G.PingMythic and name:find("Mythic")) or 
                       (_G.PingFabled and name:find("Fabled")) then
                        hasRare = true
                    end
                end
            end
            
            if #newItems > 0 then
                sendStatsWebhook("Item Drops Found!", "✨ New items added to your inventory:", {
                    {["name"] = "📦 New Drops", ["value"] = table.concat(newItems, "\n"), ["inline"] = false}
                }, hasRare)
            end
            lastInventory = current
        end
    end
end)

-- ==============================================================================
-- 3. SETTINGS SYSTEM
-- ==============================================================================
local SettingsFileName = "SanjiHubSettings.json"

local function SaveSettings()
    local data = {
        DungeonMaster = _G.DungeonMaster, AutoStart = _G.AutoStart,
        GodMode = _G.GodMode, AutoSell = _G.AutoSell,
        WebhookEnabled = _G.WebhookEnabled, WebhookUrl = _G.WebhookUrl,
        PingL = _G.PingLegendary, PingM = _G.PingMythic, PingF = _G.PingFabled
    }
    pcall(function() writefile(SettingsFileName, HttpService:JSONEncode(data)) end)
end

local function LoadSettings()
    if isfile(SettingsFileName) then
        local success, result = pcall(function() return HttpService:JSONDecode(readfile(SettingsFileName)) end)
        if success and result then
            _G.DungeonMaster = result.DungeonMaster; _G.AutoStart = result.AutoStart
            _G.GodMode = result.GodMode; _G.AutoSell = result.AutoSell
            _G.WebhookEnabled = result.WebhookEnabled; _G.WebhookUrl = result.WebhookUrl
            _G.PingLegendary = result.PingL; _G.PingMythic = result.PingM; _G.PingFabled = result.PingF
        end
    end
end
LoadSettings()

-- ==============================================================================
-- 4. COMBAT & FARMING LOGIC (STAYED SAME)
-- ==============================================================================
local visitedMobs = {} 
local lastMB1 = 0               
local MB1_COOLDOWN = 0.1 
local ClickEvent = ReplicatedStorage:WaitForChild("Click")
local lastPos = Vector3.new(0,0,0) 
local stuckCount = 0

local function autoClick() if tick() - lastMB1 > MB1_COOLDOWN then ClickEvent:FireServer(true); lastMB1 = tick() end end
local function castSkills()
    autoClick() 
    for _, key in ipairs({"Q", "E", "R", "F"}) do 
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
    end
end

-- (Navigation and Targeting functions remain from your source...)
local function getNextTarget()
    local char = Player.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return nil, "CLEAR" end
    local rootPos = char.HumanoidRootPart.Position
    local arcticColossus, otherBoss, bonechill, unvisitedFrostwinds, elites, normals = nil, nil, nil, {}, {}, {}

    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Humanoid") and v.Parent ~= char and v.Health > 0 and v.Parent:FindFirstChild("HumanoidRootPart") then
            local mob = v.Parent; local n = mob.Name
            if not Players:GetPlayerFromCharacter(mob) then
                if string.find(n, "Arctic Colossus") then arcticColossus = mob 
                elseif string.find(n, "Blizzard") or string.find(n, "Everfrost") then otherBoss = mob
                elseif string.find(n, "Bonechill Progenitor") then bonechill = mob 
                elseif string.find(n, "Frostwind Progenitor") then if not visitedMobs[mob] then table.insert(unvisitedFrostwinds, mob) end
                elseif string.find(n, "Possessed Snowman") or string.find(n, "Glacial Elemental") then table.insert(elites, mob)
                else table.insert(normals, mob) end
            end
        end
    end
    if arcticColossus then return arcticColossus, "KILL" end
    if otherBoss then return otherBoss, "KILL" end
    if bonechill then return bonechill, "KILL_ANCHOR" end
    if #elites > 0 then table.sort(elites, function(a, b) return (rootPos - a.HumanoidRootPart.Position).Magnitude < (rootPos - b.HumanoidRootPart.Position).Magnitude end) return elites[1], "KILL" end
    if #normals > 0 then table.sort(normals, function(a, b) return (rootPos - a.HumanoidRootPart.Position).Magnitude < (rootPos - b.HumanoidRootPart.Position).Magnitude end) return normals[1], "KILL" end
    return nil, "CLEAR"
end

local function runTo(targetModel, mode)
    local char = Player.Character; local root = char.HumanoidRootPart; local hum = char.Humanoid; local enemyRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then return end
    local d = (root.Position - enemyRoot.Position).Magnitude
    local isColossus = string.find(targetModel.Name, "Arctic Colossus")
    local stopRange = isColossus and 30 or 12

    if d <= stopRange then
        root.Anchored = true; root.CFrame = CFrame.new(root.Position, Vector3.new(enemyRoot.Position.X, root.Position.Y, enemyRoot.Position.Z)); castSkills(); return 
    end
    root.Anchored = false
    hum:MoveTo(enemyRoot.Position)
    if isColossus and d < 60 then castSkills() end
end

-- ==============================================================================
-- 5. MAIN LOOPS
-- ==============================================================================
task.spawn(function() while true do task.wait(1) if _G.AutoStart then local r = ReplicatedStorage:FindFirstChild("Start") if r then r:FireServer() end end end end)

task.spawn(function()
    while true do
        if _G.DungeonMaster then
            pcall(function()
                local t, m = getNextTarget()
                if t then runTo(t, m)
                else
                    local gate = nil
                    for _, v in pairs(Workspace:GetDescendants()) do if v.Name == "Gate" or v.Name == "Portal" then gate = v break end end
                    if gate then runTo({HumanoidRootPart = gate, Name = "Gate"}, "KILL") end
                end
            end)
        end
        RunService.Heartbeat:Wait()
    end
end)

print("[Script] Sanji Master Hub with Stats Webhook Loaded")
