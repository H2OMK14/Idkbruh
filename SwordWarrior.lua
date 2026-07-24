-- Sword Warrior Cheat Script
-- UI: Rayfield | Features: Kill Aura, TP Aura, Auto Rebirth, Safe Farm, Speed Hack

-- ─── Load Rayfield ────────────────────────────────────────────────────────────
local Rayfield
local rayfieldUrls = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}
for _, url in ipairs(rayfieldUrls) do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if ok and result then Rayfield = result break end
    task.wait(0.5)
end
if not Rayfield then
    warn("[SwordWarrior] Could not load Rayfield UI.")
    return
end

-- ─── Services ─────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character   = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local RootPart    = Character:WaitForChild("HumanoidRootPart")
local Humanoid    = Character:WaitForChild("Humanoid")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    RootPart  = char:WaitForChild("HumanoidRootPart")
    Humanoid  = char:WaitForChild("Humanoid")
end)

-- ─── State ────────────────────────────────────────────────────────────────────
local Settings = {
    KillAura          = false,
    KillAuraRange     = 15,

    TpAura            = false,
    TpAuraRange       = 40,
    TpAuraDelay       = 0.5,

    AutoRebirth       = false,

    SafeFarm          = false,
    SafeFarmMode      = "Distance",
    SafeFarmDist      = 60,
    SafeFarmSearchRange = 100,   -- only target enemies within this range of player

    SpeedHack         = false,
    SpeedValue        = 32,
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function getEnemies(searchRange)
    local enemies   = {}
    local playerSet = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then playerSet[p.Character] = true end
    end
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and not playerSet[model] and model ~= Character then
            local hum  = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")
                      or model:FindFirstChild("Root")
            if hum and hum.Health > 0 and root then
                local dist = RootPart and (RootPart.Position - root.Position).Magnitude or math.huge
                if not searchRange or dist <= searchRange then
                    table.insert(enemies, { model = model, hum = hum, root = root })
                end
            end
        end
    end
    return enemies
end

local function distanceTo(otherRoot)
    if not RootPart or not otherRoot then return math.huge end
    return (RootPart.Position - otherRoot.Position).Magnitude
end

-- ─── Sword Swing (real damage) ────────────────────────────────────────────────
-- This game has its own HP system — TakeDamage does nothing.
-- We simulate a real sword swing by activating the equipped tool.
local swingCooldown = 0

local function swingSword()
    local tool = Character and Character:FindFirstChildOfClass("Tool")
    if not tool then return end

    -- Method 1: Activate the tool (triggers swing animation + hitbox)
    pcall(function() tool:Activate() end)

    -- Method 2: Fire common attack remotes as backup
    local remoteNames = {"Attack", "Swing", "Hit", "DamageEvent", "DamageRemote",
                         "SwordHit", "Slash", "RemoteEvent"}
    for _, name in ipairs(remoteNames) do
        local r = tool:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer() end)
            break
        end
    end
end

-- ─── Kill Aura ────────────────────────────────────────────────────────────────
-- Teleports next to each enemy within range, swings sword, returns.
-- (TakeDamage is skipped — game ignores it)
local killAuraCooldown = 0
local function doKillAura(dt)
    if not Settings.KillAura then return end
    killAuraCooldown = killAuraCooldown - dt
    if killAuraCooldown > 0 then return end
    killAuraCooldown = 0.3  -- swing every 300ms

    local saved = RootPart.CFrame
    local swung = false

    for _, e in ipairs(getEnemies()) do
        if distanceTo(e.root) <= Settings.KillAuraRange then
            -- Step in close, swing, step back
            RootPart.CFrame = e.root.CFrame * CFrame.new(0, 0, 2.5)
            task.wait(0.05)
            swingSword()
            task.wait(0.05)
            swung = true
        end
    end

    if swung then
        RootPart.CFrame = saved
    end
end

-- ─── TP Aura ──────────────────────────────────────────────────────────────────
local tpCooldown = 0
local function doTpAura(dt)
    if not Settings.TpAura then return end
    tpCooldown = tpCooldown - dt
    if tpCooldown > 0 then return end
    tpCooldown = Settings.TpAuraDelay

    local saved = RootPart.CFrame
    for _, e in ipairs(getEnemies()) do
        if distanceTo(e.root) <= Settings.TpAuraRange then
            RootPart.CFrame = e.root.CFrame * CFrame.new(0, 0, 2.5)
            task.wait(0.05)
            swingSword()
            task.wait(0.05)
        end
    end
    RootPart.CFrame = saved
end

-- ─── Safe Farm ────────────────────────────────────────────────────────────────
-- Only considers enemies within SafeFarmSearchRange of the player
local function doSafeFarm()
    if not Settings.SafeFarm then return end

    -- Find nearest enemy within search range
    local nearestRoot, nearestDist = nil, math.huge
    for _, e in ipairs(getEnemies(Settings.SafeFarmSearchRange)) do
        local d = distanceTo(e.root)
        if d < nearestDist then
            nearestRoot = e.root
            nearestDist = d
        end
    end
    if not nearestRoot then return end  -- no enemies nearby, stay put

    local mode = Settings.SafeFarmMode

    if mode == "Underground" then
        -- Sink below map near enemy (enemies usually can't reach underground)
        RootPart.CFrame = CFrame.new(nearestRoot.Position + Vector3.new(0, -20, 0))

    elseif mode == "Above" then
        -- Hover above enemy
        RootPart.CFrame = CFrame.new(nearestRoot.Position + Vector3.new(0, 30, 0))

    elseif mode == "Distance" then
        -- Stay at safe distance: enemy can't melee us but we can still hit them
        if nearestDist < Settings.SafeFarmDist then
            local dir = (RootPart.Position - nearestRoot.Position)
            local unit = dir.Magnitude > 0 and dir.Unit or Vector3.new(1, 0, 0)
            RootPart.CFrame = CFrame.new(nearestRoot.Position + unit * Settings.SafeFarmDist)
        end
    end
end

-- ─── Auto Rebirth ─────────────────────────────────────────────────────────────
local rebirthCooldown = 0
local function doAutoRebirth(dt)
    if not Settings.AutoRebirth then return end
    rebirthCooldown = rebirthCooldown - dt
    if rebirthCooldown > 0 then return end
    rebirthCooldown = 5

    for _, name in ipairs({"Rebirth", "rebirth", "RebirthEvent", "DoRebirth"}) do
        local r = ReplicatedStorage:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then
            pcall(function() r:FireServer() end)
            return
        end
    end
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if gui then
        for _, obj in ipairs(gui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
               and obj.Name:lower():find("rebirth") and obj.Visible then
                pcall(function() obj.MouseButton1Click:Fire() end)
                return
            end
        end
    end
end

-- ─── Speed Hack ───────────────────────────────────────────────────────────────
local BASE_SPEED = 16
local function applySpeed()
    if not Humanoid then return end
    Humanoid.WalkSpeed = Settings.SpeedHack and Settings.SpeedValue or BASE_SPEED
end
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    if Settings.SpeedHack then hum.WalkSpeed = Settings.SpeedValue end
end)

-- ─── Noclip ───────────────────────────────────────────────────────────────────
local noclipConn
local function setNoclip(state)
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            if Character then
                for _, p in ipairs(Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end
end

-- ─── Main Loop ────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
    pcall(doKillAura, dt)
    pcall(doTpAura, dt)
    pcall(doSafeFarm)
    pcall(doAutoRebirth, dt)
    pcall(applySpeed)
end)

-- ─── Rayfield Window ──────────────────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name             = "Sword Warrior Cheat",
    LoadingTitle     = "Loading Script...",
    LoadingSubtitle  = "Sword Warrior | All Features",
    Theme            = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SWCheats",
        FileName   = "Config",
    },
    KeySystem = false,
})

-- ── Combat Tab ────────────────────────────────────────────────────────────────
local CombatTab = Window:CreateTab("Combat", nil)
CombatTab:CreateSection("Kill Aura")

CombatTab:CreateToggle({
    Name         = "Enable Kill Aura",
    CurrentValue = false,
    Flag         = "KillAura",
    Callback     = function(v) Settings.KillAura = v end,
})

CombatTab:CreateSlider({
    Name         = "Kill Aura Range",
    Range        = {5, 100},
    Increment    = 1,
    Suffix       = " studs",
    CurrentValue = 15,
    Flag         = "KillAuraRange",
    Callback     = function(v) Settings.KillAuraRange = v end,
})

CombatTab:CreateSection("TP Aura")

CombatTab:CreateToggle({
    Name         = "Enable TP Aura",
    CurrentValue = false,
    Flag         = "TpAura",
    Callback     = function(v) Settings.TpAura = v end,
})

CombatTab:CreateSlider({
    Name         = "TP Aura Range",
    Range        = {10, 200},
    Increment    = 5,
    Suffix       = " studs",
    CurrentValue = 40,
    Flag         = "TpAuraRange",
    Callback     = function(v) Settings.TpAuraRange = v end,
})

CombatTab:CreateSlider({
    Name         = "TP Aura Delay (x100ms)",
    Range        = {1, 20},
    Increment    = 1,
    Suffix       = "00ms",
    CurrentValue = 5,
    Flag         = "TpAuraDelay",
    Callback     = function(v) Settings.TpAuraDelay = v / 10 end,
})

-- ── Farm Tab ──────────────────────────────────────────────────────────────────
local FarmTab = Window:CreateTab("Farm", nil)
FarmTab:CreateSection("Safe Farm")

FarmTab:CreateToggle({
    Name         = "Enable Safe Farm",
    CurrentValue = false,
    Flag         = "SafeFarm",
    Callback     = function(v) Settings.SafeFarm = v end,
})

FarmTab:CreateDropdown({
    Name          = "Farm Mode",
    Options       = {"Distance", "Underground", "Above"},
    CurrentOption = {"Distance"},
    Flag          = "SafeFarmMode",
    Callback      = function(opts)
        Settings.SafeFarmMode = type(opts) == "table" and opts[1] or opts
    end,
})

FarmTab:CreateSlider({
    Name         = "Safe Distance (Distance mode)",
    Range        = {20, 200},
    Increment    = 5,
    Suffix       = " studs",
    CurrentValue = 60,
    Flag         = "SafeFarmDist",
    Callback     = function(v) Settings.SafeFarmDist = v end,
})

FarmTab:CreateSlider({
    Name         = "Enemy Search Range",
    Range        = {20, 500},
    Increment    = 10,
    Suffix       = " studs",
    CurrentValue = 100,
    Flag         = "SafeFarmSearchRange",
    Callback     = function(v) Settings.SafeFarmSearchRange = v end,
})

FarmTab:CreateSection("Auto Rebirth")

FarmTab:CreateToggle({
    Name         = "Enable Auto Rebirth",
    CurrentValue = false,
    Flag         = "AutoRebirth",
    Callback     = function(v) Settings.AutoRebirth = v end,
})

FarmTab:CreateButton({
    Name     = "Manual Rebirth Now",
    Callback = function()
        local fired = false
        for _, name in ipairs({"Rebirth", "rebirth", "RebirthEvent", "DoRebirth"}) do
            local r = ReplicatedStorage:FindFirstChild(name, true)
            if r and r:IsA("RemoteEvent") then
                pcall(function() r:FireServer() end)
                fired = true break
            end
        end
        if not fired then
            local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if gui then
                for _, obj in ipairs(gui:GetDescendants()) do
                    if (obj:IsA("TextButton") or obj:IsA("ImageButton"))
                       and obj.Name:lower():find("rebirth") then
                        pcall(function() obj.MouseButton1Click:Fire() end)
                        fired = true break
                    end
                end
            end
        end
        Rayfield:Notify({
            Title   = "Rebirth",
            Content = fired and "Rebirth triggered!" or "No rebirth remote found.",
            Duration = 3,
        })
    end,
})

-- ── Player Tab ────────────────────────────────────────────────────────────────
local PlayerTab = Window:CreateTab("Player", nil)
PlayerTab:CreateSection("Speed")

PlayerTab:CreateToggle({
    Name         = "Speed Hack",
    CurrentValue = false,
    Flag         = "SpeedHack",
    Callback     = function(v) Settings.SpeedHack = v applySpeed() end,
})

PlayerTab:CreateSlider({
    Name         = "Walk Speed",
    Range        = {16, 500},
    Increment    = 2,
    Suffix       = "",
    CurrentValue = 32,
    Flag         = "SpeedValue",
    Callback     = function(v)
        Settings.SpeedValue = v
        if Settings.SpeedHack then applySpeed() end
    end,
})

PlayerTab:CreateSection("Movement")

PlayerTab:CreateToggle({
    Name         = "Noclip",
    CurrentValue = false,
    Flag         = "Noclip",
    Callback     = function(v) setNoclip(v) end,
})

PlayerTab:CreateButton({
    Name     = "Teleport to Nearest Enemy",
    Callback = function()
        local nearestRoot, nearestDist = nil, math.huge
        for _, e in ipairs(getEnemies()) do
            local d = distanceTo(e.root)
            if d < nearestDist then nearestRoot = e.root nearestDist = d end
        end
        if nearestRoot then
            RootPart.CFrame = nearestRoot.CFrame * CFrame.new(0, 0, 3)
            Rayfield:Notify({ Title = "Teleport", Content = "Moved to nearest enemy.", Duration = 2 })
        else
            Rayfield:Notify({ Title = "Teleport", Content = "No enemies found.", Duration = 2 })
        end
    end,
})

-- ─── Load config & notify ─────────────────────────────────────────────────────
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title    = "Sword Warrior Script",
    Content  = "Loaded! Toggle features in the menu.",
    Duration = 5,
})
