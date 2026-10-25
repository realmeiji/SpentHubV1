-- init
if not game:IsLoaded() then game.Loaded:Wait() end
if not syn or not protectgui then getgenv().protectgui = function() end end

-- ============ LOAD OBSIDIAN LIBRARY ============
local Obsidian
local obsidianUrls = {
    "https://raw.githubusercontent.com/Obsidian-Development/Obsidian/main/library.lua",
    "https://raw.githubusercontent.com/Obsidian-Development/Obsidian/main/src/library.lua",
    "https://raw.githubusercontent.com/ic3w0lf/Obsidian/main/source.lua",
}

for _, url in ipairs(obsidianUrls) do
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if success and result then
        Obsidian = result
        break
    end
end

if not Obsidian then
    error("Failed to load Obsidian library from all sources")
    return
end

-- ============ ROBLOX NOTIFICATION SYSTEM ============
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local function robloxNotify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

robloxNotify("SPENT HUB", "Loading...", 2)

-- ============ SETTINGS ============
local SilentAimSettings = {
    Enabled = false,
    ClassName = "Universal Silent Aim - Averiias, Stefanuk12, xaxa",
    ToggleKey = "RightAlt",
    TeamCheck = false,
    VisibleCheck = false,
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false,
    MouseHitPrediction = false,
    MouseHitPredictionAmount = 0.165,
    HitChance = 100,
    TargetCop = true,
    TargetInmate = true,
    TargetCriminal = true,
    ESP_Enabled = false,
    ESP_Team = false,
    ESP_Highlight = true,
    ESP_Name = true,
    ESP_Health = true,
    ESP_Trace = false,
    ESP_MaxDistance = 1500,
    ESP_HighlightColor = Color3.fromRGB(255, 182, 193),
    ESP_NameColor = Color3.fromRGB(255, 255, 255),
    ESP_HPColor = Color3.fromRGB(80, 255, 100),
    ESP_TraceColor = Color3.fromRGB(255, 255, 255),
}
getgenv().SilentAimSettings = SilentAimSettings

local TARGET_LOCK_COLOR = Color3.fromRGB(255, 182, 193)
local RING_IDLE_COLOR = Color3.fromRGB(255, 255, 255)

local MainFileName = "UniversalSilentAim"
local FileToSave = ""
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GetMouseLocation = UserInputService.GetMouseLocation
local resume = coroutine.resume
local create = coroutine.create
local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local mouse_box = Drawing.new("Square")
mouse_box.Visible = true
mouse_box.ZIndex = 999
mouse_box.Color = Color3.fromRGB(255, 182, 193)
mouse_box.Thickness = 2
mouse_box.Size = Vector2.new(20, 20)
mouse_box.Filled = false

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 130
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(255, 182, 193)

-- ============ UTILITY FUNCTIONS ============
local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = { ArgCountRequired = 3, Args = { "Instance", "Ray", "table", "boolean", "boolean" } },
    FindPartOnRayWithWhitelist = { ArgCountRequired = 3, Args = { "Instance", "Ray", "table", "boolean" } },
    FindPartOnRay = { ArgCountRequired = 2, Args = { "Instance", "Ray", "Instance", "boolean", "boolean" } },
    Raycast = { ArgCountRequired = 3, Args = { "Instance", "Vector3", "Vector3", "RaycastParams" } }
}

local lastRollTime = 0
local lastRollResult = false

function CalculateChance(Percentage)
    local now = tick()
    if now - lastRollTime < 0.15 then return lastRollResult end
    lastRollTime = now
    Percentage = math.floor(Percentage)
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100
    lastRollResult = chance <= Percentage / 100
    return lastRollResult
end

do
    if not isfolder(MainFileName) then makefolder(MainFileName) end
    if not isfolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId))) then
        makefolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId)))
    end
end

local function GetFiles()
    local Files = listfiles(string.format("%s/%s", "UniversalSilentAim", tostring(game.PlaceId)))
    local out = {}
    for i = 1, #Files do
        local file = Files[i]
        if file:sub(-4) == '.lua' then
            local pos = file:find('.lua', 1, true)
            local start = pos
            local char = file:sub(pos, pos)
            while char ~= '/' and char ~= '\\' and char ~= '' do
                pos = pos - 1
                char = file:sub(pos, pos)
            end
            if char == '/' or char == '\\' then
                table.insert(out, file:sub(pos + 1, start - 1))
            end
        end
    end
    return out
end

local function UpdateFile(FileName)
    pcall(function()
        writefile(string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName), HttpService:JSONEncode(SilentAimSettings))
    end)
end

local function LoadFile(FileName)
    pcall(function()
        local File = string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName)
        local ConfigData = HttpService:JSONDecode(readfile(File))
        for Index, Value in next, ConfigData do SilentAimSettings[Index] = Value end
    end)
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then return false end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then Matches = Matches + 1 end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    if not (PlayerCharacter or LocalPlayerCharacter) then return end
    local PlayerRoot = FindFirstChild(PlayerCharacter, SilentAimSettings.TargetPart) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    if not PlayerRoot then return end
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    return ObscuringObjects == 0
end

local function getTeamColor(player)
    local ok, color = pcall(function()
        if player.Team and player.Team.TeamColor then
            return player.Team.TeamColor.Color
        end
        local char = player.Character
        if char then
            local bc = char:FindFirstChildOfClass("BodyColors")
            if bc then return bc.HeadColor3 end
        end
        return Color3.fromRGB(255, 182, 193)
    end)
    return (ok and color) or Color3.fromRGB(255, 182, 193)
end

local function matchesTeam(Player)
    if not Player.Team then return true end
    local teamName = Player.Team.Name
    if teamName == "Guards" and not SilentAimSettings.TargetCop then return false end
    if teamName == "Inmates" and not SilentAimSettings.TargetInmate then return false end
    if teamName == "Criminals" and not SilentAimSettings.TargetCriminal then return false end
    return true
end

local function getClosestPlayer()
    if not SilentAimSettings.TargetPart then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if SilentAimSettings.TeamCheck and Player.Team == LocalPlayer.Team then continue end
        if not matchesTeam(Player) then continue end
        local Character = Player.Character
        if not Character then continue end
        if SilentAimSettings.VisibleCheck and not IsPlayerVisible(Player) then continue end
        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid.Health <= 0 then continue end
        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end
        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or SilentAimSettings.FOVRadius or 2000) then
            Closest = ((SilentAimSettings.TargetPart == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[SilentAimSettings.TargetPart])
            DistanceToMouse = Distance
        end
    end
    return Closest
end

-- ============ ESP SYSTEM ============
local espCache = {}
local lastESPUpdate = 0
local lastHighlightUpdate = 0
local lastLockCheck = 0
local cachedLockedChar = nil

local function isLockedChar(char)
    local now = tick()
    if now - lastLockCheck >= 0.1 then
        lastLockCheck = now
        local cur = getClosestPlayer()
        cachedLockedChar = (cur and cur.Parent) or nil
    end
    return cachedLockedChar == char
end

local function newESP(player)
    return {
        name = Drawing.new("Text"),
        hpBack = Drawing.new("Line"),
        hpBar = Drawing.new("Line"),
        trace = Drawing.new("Line"),
    }
end

local function clearESP(player)
    local d = espCache[player]
    if d then
        for _, obj in pairs(d) do
            pcall(function() obj:Remove() end)
        end
        espCache[player] = nil
    end
end

Players.PlayerRemoving:Connect(function(player) clearESP(player) end)

local function updateESP()
    local now = tick()
    if now - lastESPUpdate < 0.033 then return end
    lastESPUpdate = now

    local canUpdateHighlight = (now - lastHighlightUpdate) >= 0.1
    if canUpdateHighlight then lastHighlightUpdate = now end

    local camPos = Camera.CFrame.Position

    for _, player in ipairs(GetPlayers(Players)) do
        if player == LocalPlayer then continue end

        local char = player.Character
        if not char then
            if espCache[player] then clearESP(player) end
            continue
        end

        local hrp = FindFirstChild(char, "HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            if espCache[player] then clearESP(player) end
            continue
        end

        if not SilentAimSettings.ESP_Enabled then
            if espCache[player] then clearESP(player) end
            continue
        end

        local dist = (camPos - hrp.Position).Magnitude
        if dist > SilentAimSettings.ESP_MaxDistance then
            if espCache[player] then clearESP(player) end
            continue
        end

        if not espCache[player] then
            espCache[player] = newESP(player)
        end

        local d = espCache[player]
        local head = FindFirstChild(char, "Head") or hrp
        local screenHead, onScreen = WorldToViewportPoint(Camera, head.Position + Vector3.new(0, 1.5, 0))

        if not onScreen then continue end

        if SilentAimSettings.ESP_Name then
            d.name.Visible = true
            d.name.Text = player.DisplayName
            d.name.Position = Vector2.new(screenHead.X, screenHead.Y - 20)
            d.name.Color = SilentAimSettings.ESP_NameColor
        else
            d.name.Visible = false
        end

        if SilentAimSettings.ESP_Health then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local topY = screenHead.Y - 32
            d.hpBack.Visible = true
            d.hpBar.Visible = true
            d.hpBack.From = Vector2.new(screenHead.X - 28, topY)
            d.hpBack.To = Vector2.new(screenHead.X + 28, topY)
            d.hpBar.From = Vector2.new(screenHead.X - 28, topY)
            d.hpBar.To = Vector2.new(screenHead.X - 28 + 56 * pct, topY)
            d.hpBar.Color = SilentAimSettings.ESP_HPColor
        else
            d.hpBack.Visible = false
            d.hpBar.Visible = false
        end

        if SilentAimSettings.ESP_Trace then
            d.trace.Visible = true
            d.trace.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            d.trace.To = Vector2.new(screenHead.X, screenHead.Y)
            d.trace.Color = SilentAimSettings.ESP_Team and getTeamColor(player) or SilentAimSettings.ESP_TraceColor
        else
            d.trace.Visible = false
        end

        if canUpdateHighlight and SilentAimSettings.ESP_Highlight then
            local hl = char:FindFirstChild("SpentHubHL")
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = "SpentHubHL"
                hl.Adornee = char
                hl.FillTransparency = 1
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = char
            end
            hl.OutlineColor = isLockedChar(char) and TARGET_LOCK_COLOR or (SilentAimSettings.ESP_Team and getTeamColor(player) or SilentAimSettings.ESP_HighlightColor)
        end
    end
end

-- ============ CREATE WINDOW ============
local Window = Obsidian:CreateWindow({
    Name = "SPENT HUB v15",
    LoadingTitle = "SPENT HUB",
    LoadingSubtitle = "Professional Silent Aim",
})

-- ============ MAIN TAB ============
local MainTab = Window:AddTab("Main")

MainTab:AddSection("SILENT AIM")
MainTab:AddToggle("MasterEnable", {
    Name = "Enabled",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.Enabled = Value
        mouse_box.Visible = Value
    end,
})

MainTab:AddDropdown("TargetPart", {
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Random"},
    CurrentOption = {"HumanoidRootPart"},
    Callback = function(Option)
        SilentAimSettings.TargetPart = Option[1]
    end,
})

MainTab:AddDropdown("Method", {
    Name = "Aiming Method",
    Options = {"Raycast", "FindPartOnRay", "FindPartOnRayWithWhitelist", "FindPartOnRayWithIgnoreList", "Mouse.Hit/Target"},
    CurrentOption = {"Raycast"},
    Callback = function(Option)
        SilentAimSettings.SilentAimMethod = Option[1]
    end,
})

MainTab:AddSlider("HitChance", {
    Name = "Hit Chance",
    Min = 0,
    Max = 100,
    Increment = 1,
    Suffix = "%",
    CurrentValue = 100,
    Callback = function(Value)
        SilentAimSettings.HitChance = Value
    end,
})

MainTab:AddSection("FILTERS")
MainTab:AddToggle("TeamCheck", {
    Name = "Team Check",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.TeamCheck = Value
    end,
})

MainTab:AddToggle("VisibleCheck", {
    Name = "Visible Check",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.VisibleCheck = Value
    end,
})

MainTab:AddSection("TARGET TEAMS")
MainTab:AddToggle("TargetCop", {
    Name = "Target Guards",
    CurrentValue = true,
    Callback = function(Value)
        SilentAimSettings.TargetCop = Value
    end,
})

MainTab:AddToggle("TargetInmate", {
    Name = "Target Inmates",
    CurrentValue = true,
    Callback = function(Value)
        SilentAimSettings.TargetInmate = Value
    end,
})

MainTab:AddToggle("TargetCriminal", {
    Name = "Target Criminals",
    CurrentValue = true,
    Callback = function(Value)
        SilentAimSettings.TargetCriminal = Value
    end,
})

-- ============ ADVANCED TAB ============
local AdvTab = Window:AddTab("Advanced")

AdvTab:AddSection("PREDICTION")
AdvTab:AddToggle("Prediction", {
    Name = "Enable Prediction",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.MouseHitPrediction = Value
    end,
})

AdvTab:AddSlider("PredictionAmount", {
    Name = "Prediction Amount",
    Min = 50,
    Max = 500,
    Increment = 1,
    Suffix = "x1000",
    CurrentValue = 165,
    Callback = function(Value)
        SilentAimSettings.MouseHitPredictionAmount = Value / 1000
        PredictionAmount = Value / 1000
    end,
})

-- ============ ESP TAB ============
local ESPTab = Window:AddTab("ESP")

ESPTab:AddSection("ESP CORE")
ESPTab:AddToggle("EnableESP", {
    Name = "Enable ESP",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.ESP_Enabled = Value
    end,
})

ESPTab:AddToggle("TeamColors", {
    Name = "Team Colors",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.ESP_Team = Value
    end,
})

ESPTab:AddSection("ELEMENTS")
ESPTab:AddToggle("Highlight", {
    Name = "Highlight",
    CurrentValue = true,
    Callback = function(Value)
        SilentAimSettings.ESP_Highlight = Value
    end,
})

ESPTab:AddToggle("Names", {
    Name = "Names",
    CurrentValue = true,
    Callback = function(Value)
        SilentAimSettings.ESP_Name = Value
    end,
})

ESPTab:AddToggle("HealthBars", {
    Name = "Health Bars",
    CurrentValue = true,
    Callback = function(Value)
        SilentAimSettings.ESP_Health = Value
    end,
})

ESPTab:AddToggle("Tracers", {
    Name = "Tracers",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.ESP_Trace = Value
    end,
})

ESPTab:AddSection("RANGE")
ESPTab:AddSlider("MaxDistance", {
    Name = "Max Distance",
    Min = 100,
    Max = 3000,
    Increment = 50,
    Suffix = "studs",
    CurrentValue = 1500,
    Callback = function(Value)
        SilentAimSettings.ESP_MaxDistance = Value
    end,
})

-- ============ VISUALS TAB ============
local VisualsTab = Window:AddTab("Visuals")

VisualsTab:AddSection("FOV CIRCLE")
VisualsTab:AddToggle("FOVCircle", {
    Name = "Show FOV",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.FOVVisible = Value
        fov_circle.Visible = Value
    end,
})

VisualsTab:AddSlider("FOVRadius", {
    Name = "FOV Radius",
    Min = 0,
    Max = 400,
    Increment = 10,
    Suffix = "px",
    CurrentValue = 130,
    Callback = function(Value)
        SilentAimSettings.FOVRadius = Value
        fov_circle.Radius = Value
    end,
})

VisualsTab:AddToggle("TargetBox", {
    Name = "Target Box",
    CurrentValue = false,
    Callback = function(Value)
        SilentAimSettings.ShowSilentAimTarget = Value
    end,
})

VisualsTab:AddSection("THEME")
VisualsTab:AddButton("Pink", function()
    mouse_box.Color = Color3.fromRGB(255, 182, 193)
    fov_circle.Color = Color3.fromRGB(255, 182, 193)
end)

VisualsTab:AddButton("Blue", function()
    mouse_box.Color = Color3.fromRGB(140, 180, 255)
    fov_circle.Color = Color3.fromRGB(140, 180, 255)
end)

VisualsTab:AddButton("Green", function()
    mouse_box.Color = Color3.fromRGB(140, 255, 180)
    fov_circle.Color = Color3.fromRGB(140, 255, 180)
end)

VisualsTab:AddButton("Purple", function()
    mouse_box.Color = Color3.fromRGB(200, 140, 255)
    fov_circle.Color = Color3.fromRGB(200, 140, 255)
end)

VisualsTab:AddButton("White", function()
    mouse_box.Color = Color3.fromRGB(255, 255, 255)
    fov_circle.Color = Color3.fromRGB(255, 255, 255)
end)

-- ============ SETTINGS TAB ============
local SettingsTab = Window:AddTab("Settings")

SettingsTab:AddSection("SAVE/LOAD")
SettingsTab:AddInput("ConfigName", {
    Name = "Config Name",
    CurrentValue = "",
    PlaceHolder = "Enter name",
    RemoveTextAfterFocusLost = false,
    Callback = function(Value)
        FileToSave = Value
    end,
})

SettingsTab:AddButton("Save Config", function()
    if FileToSave and FileToSave ~= "" then
        UpdateFile(FileToSave)
        robloxNotify("SPENT HUB", "Saved: " .. FileToSave, 2)
    else
        robloxNotify("SPENT HUB", "Enter name", 1)
    end
end)

SettingsTab:AddSection("LOAD")
local files = GetFiles()
if #files > 0 then
    for _, name in ipairs(files) do
        SettingsTab:AddButton("Load: " .. name, function()
            LoadFile(name)
            robloxNotify("SPENT HUB", "Loaded: " .. name, 2)
        end)
    end
end

SettingsTab:AddSection("INFO")
SettingsTab:AddParagraph("SPENT HUB v15", "Professional Silent Aim Suite")
SettingsTab:AddParagraph("Keybinds", "RAlt: Toggle\nRShift: GUI\nEND: Unload")

-- ============ HOOKS ============
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]
    local chance = CalculateChance(SilentAimSettings.HitChance)
    if SilentAimSettings.Enabled and self == workspace and not checkcaller() and chance == true then
        if Method == "FindPartOnRayWithIgnoreList" and SilentAimSettings.SilentAimMethod == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                local A_Ray = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[2] = Ray.new(A_Ray.Origin, getDirection(A_Ray.Origin, HitPart.Position))
                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "FindPartOnRayWithWhitelist" and SilentAimSettings.SilentAimMethod == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                local A_Ray = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[2] = Ray.new(A_Ray.Origin, getDirection(A_Ray.Origin, HitPart.Position))
                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and SilentAimSettings.SilentAimMethod:lower() == Method:lower() then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                local A_Ray = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[2] = Ray.new(A_Ray.Origin, getDirection(A_Ray.Origin, HitPart.Position))
                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "Raycast" and SilentAimSettings.SilentAimMethod == Method then
            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                local A_Origin = Arguments[2]
                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[3] = getDirection(A_Origin, HitPart.Position)
                    return oldNamecall(unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(...)
end))

local oldIndex = nil
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if self == Mouse and not checkcaller() and SilentAimSettings.Enabled and SilentAimSettings.SilentAimMethod == "Mouse.Hit/Target" and getClosestPlayer() then
        local HitPart = getClosestPlayer()
        if Index == "Target" or Index == "target" then
            return HitPart
        elseif Index == "Hit" or Index == "hit" then
            return ((SilentAimSettings.MouseHitPrediction and (HitPart.CFrame + (HitPart.Velocity * PredictionAmount))) or (not SilentAimSettings.MouseHitPrediction and HitPart.CFrame))
        elseif Index == "X" or Index == "x" then
            return self.X
        elseif Index == "Y" or Index == "y" then
            return self.Y
        elseif Index == "UnitRay" then
            return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
        end
    end
    return oldIndex(self, Index)
end))

-- ============ MAIN LOOP ============
resume(create(function()
    RenderStepped:Connect(function()
        local lockedTarget = getClosestPlayer()

        if SilentAimSettings.ShowSilentAimTarget and SilentAimSettings.Enabled then
            if lockedTarget then
                local Root = lockedTarget.Parent and lockedTarget.Parent.PrimaryPart or lockedTarget
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position)
                mouse_box.Visible = IsOnScreen
                mouse_box.Position = Vector2.new(RootToViewportPoint.X, RootToViewportPoint.Y)
            else
                mouse_box.Visible = false
            end
        end

        if SilentAimSettings.FOVVisible then
            fov_circle.Visible = true
            fov_circle.Position = getMousePosition()
            fov_circle.Color = lockedTarget and TARGET_LOCK_COLOR or RING_IDLE_COLOR
        else
            fov_circle.Visible = false
        end

        updateESP()
    end)
end))

-- ============ KEYBINDS ============
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightAlt then
        SilentAimSettings.Enabled = not SilentAimSettings.Enabled
        robloxNotify("SPENT HUB", SilentAimSettings.Enabled and "Enabled" or "Disabled", 1)
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Window:Toggle()
    end
    if input.KeyCode == Enum.KeyCode.End then
        Window:Destroy()
        pcall(function() fov_circle:Remove() end)
        pcall(function() mouse_box:Remove() end)
        for _, p in ipairs(GetPlayers(Players)) do clearESP(p) end
        robloxNotify("SPENT HUB", "Unloaded", 1)
    end
end)

robloxNotify("SPENT HUB v15", "Loaded successfully", 2)
