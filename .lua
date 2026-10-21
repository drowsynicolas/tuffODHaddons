-- Gun Features
-- Controller+
-- Water Proof
-- Disable Trade
-- Client Sided Message
-- Estimated Server Pos
-- Auto Perk
-- Tool Tint
-- Custom Chat
-- Emotes
-- Coin Misc
-- Event
-- Personal

local table_insert = table.insert
local nicolas = {}
nicolas.__index = nicolas
function nicolas.new()
    return setmetatable({_tasks = {}, _destroyed = false}, nicolas)
end
function nicolas:GiveTask(task)
    if self._destroyed then
        self:_cleanupTask(task)
        return
    end
    table_insert(self._tasks, task)
    return task
end
function nicolas:GiveTasks(...)
    for _, task in ipairs({...}) do
        self:GiveTask(task)
    end
end
function nicolas:_cleanupTask(task)
    local taskType = typeof(task)
    if taskType == "RBXScriptConnection" then
        task:Disconnect()
    elseif taskType == "Instance" then
        task:Destroy()
    elseif taskType == "function" then
        task()
    elseif taskType == "table" and type(task.Destroy) == "function" then
        task:Destroy()
    end
end
function nicolas:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, task in ipairs(self._tasks) do
        self:_cleanupTask(task)
    end
    self._tasks = {}
end
function nicolas:Destroy()
    self:DoCleaning()
end

local RootNicolas = nicolas.new()
local shared = odh_shared_plugins

local myTab = shared.CreateTab("tuff stuff", "/drowsynicolas/drowsynicolas-ODH-icon/refs/heads/main/image")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
local SpectateService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SpectateService"))

local BLOCKED = {
    ["123606547020560"] = true,
    ["134826825394657"] = true,
    ["124281955370937"] = true,
    ["127786188145385"] = true,
}
local SOUND_ID = "rbxassetid://7158356564"
local START_OFFSET = 0.3

local gunFeatures = {
    blockAnims = false,
    equipSound = false,
    forceField = false,
    fireColor = false,
}
local charData = {}
local currentSounds = {}

local forceFieldConnection = nil
local forceFieldColor = Color3.fromRGB(0, 100, 255)
local forceFieldSize = 3.5
local forceFieldTransparency = 0.3
local FORCE_FIELD_NAME = "\u{200B}\u{200B}\u{200B}"

local fireColorConnection = nil
local customFireColor = Color3.fromRGB(0, 100, 255)
local DEFAULT_FIRE_COLOR = Color3.fromRGB(1, 76, 0)
local DEFAULT_FIRE_SECONDARY = Color3.fromRGB(0, 0, 0)

local function cleanCharacter(character)
    local data = charData[character]
    if data then
        if data.animNicolas then
            data.animNicolas:DoCleaning()
            data.animNicolas = nicolas.new()
        end
        if data.equipNicolas then
            data.equipNicolas:DoCleaning()
            data.equipNicolas = nicolas.new()
        end
        charData[character] = nil
    end
    local sound = currentSounds[character]
    if sound then
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
end

local function playSound(character, soundId)
    local existing = currentSounds[character]
    if existing then
        existing:Stop()
        existing:Destroy()
        currentSounds[character] = nil
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 1
    sound.Parent = hrp
    sound.TimePosition = START_OFFSET
    sound:Play()
    currentSounds[character] = sound
    sound.Ended:Once(function()
        if currentSounds[character] == sound then
            currentSounds[character] = nil
        end
        sound:Destroy()
    end)
end

local function hookTool(tool, character, nicolasObj)
    if tool.Name ~= "Gun" then return end
    local equipConn = tool.Equipped:Connect(function()
        if gunFeatures.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(equipConn)
    local unequipConn = tool.Unequipped:Connect(function()
        if gunFeatures.equipSound then
            playSound(character, SOUND_ID)
        end
    end)
    nicolasObj:GiveTask(unequipConn)
    return equipConn, unequipConn
end

local function applyGunFeatures(character)
    local data = charData[character]
    if not data then
        data = {
            animNicolas = nicolas.new(),
            equipNicolas = nicolas.new(),
        }
        charData[character] = data
        data.animNicolas:GiveTask(character.AncestryChanged:Connect(function()
            if not character.Parent then
                cleanCharacter(character)
            end
        end))
    end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    if gunFeatures.blockAnims then
        data.animNicolas:GiveTask(RunService.RenderStepped:Connect(function()
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                local anim = track.Animation
                if anim then
                    local id = anim.AnimationId:match("%d+")
                    if BLOCKED[id] then
                        track:Stop(0)
                    end
                end
            end
        end))
    end
    if gunFeatures.equipSound then
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") then
                hookTool(child, character, data.equipNicolas)
            end
        end
        data.equipNicolas:GiveTask(character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                hookTool(child, character, data.equipNicolas)
            end
        end))
    end
end

local function onCharacterAdded(character)
    character:WaitForChild("Humanoid")
    if gunFeatures.blockAnims or gunFeatures.equipSound then
        applyGunFeatures(character)
    end
end

local animBlockGlobalNicolas = nicolas.new()
local equipSoundGlobalNicolas = nicolas.new()

local function enableBlockAnims()
    animBlockGlobalNicolas:DoCleaning()
    animBlockGlobalNicolas = nicolas.new()
    if LocalPlayer.Character then
        applyGunFeatures(LocalPlayer.Character)
    end
    animBlockGlobalNicolas:GiveTask(LocalPlayer.CharacterAdded:Connect(function(character)
        onCharacterAdded(character)
    end))
end

local function disableBlockAnims()
    animBlockGlobalNicolas:DoCleaning()
    for _, data in pairs(charData) do
        if data.animNicolas then
            data.animNicolas:DoCleaning()
            data.animNicolas = nicolas.new()
        end
    end
end

local function enableEquipSound()
    equipSoundGlobalNicolas:DoCleaning()
    equipSoundGlobalNicolas = nicolas.new()
    if LocalPlayer.Character then
        applyGunFeatures(LocalPlayer.Character)
    end
    equipSoundGlobalNicolas:GiveTask(LocalPlayer.CharacterAdded:Connect(function(character)
        onCharacterAdded(character)
    end))
end

local function disableEquipSound()
    equipSoundGlobalNicolas:DoCleaning()
    for _, data in pairs(charData) do
        if data.equipNicolas then
            data.equipNicolas:DoCleaning()
            data.equipNicolas = nicolas.new()
        end
    end
    for character, sound in pairs(currentSounds) do
        sound:Stop()
        sound:Destroy()
        currentSounds[character] = nil
    end
end

local function applyForceField(gunDrop)
    if not gunDrop or gunDrop.Name ~= "GunDrop" then return end
    if gunDrop:FindFirstChild(FORCE_FIELD_NAME) then return end

    local sphere = Instance.new("Part")
    sphere.Name = FORCE_FIELD_NAME
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(forceFieldSize, forceFieldSize, forceFieldSize)
    sphere.Color = forceFieldColor
    sphere.Material = Enum.Material.ForceField
    sphere.Transparency = forceFieldTransparency
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.CanTouch = false
    sphere.CanQuery = false
    sphere.CastShadow = false
    sphere.Massless = true
    sphere.CFrame = gunDrop.CFrame
    sphere.Parent = gunDrop
end

local function enableForceField()
    if forceFieldConnection then
        forceFieldConnection:Disconnect()
        forceFieldConnection = nil
    end

    forceFieldConnection = workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            task.wait()
            applyForceField(obj)
        end
    end)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            applyForceField(obj)
        end
    end
end

local function disableForceField()
    if forceFieldConnection then
        forceFieldConnection:Disconnect()
        forceFieldConnection = nil
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            local sphere = obj:FindFirstChild(FORCE_FIELD_NAME)
            if sphere then
                sphere:Destroy()
            end
        end
    end
end

local function applyFireColor(gunDrop)
    if not gunDrop or gunDrop.Name ~= "GunDrop" then return end
    local fire = gunDrop:FindFirstChild("Fire")
    if fire and fire:IsA("Fire") then
        fire.Color = customFireColor
        fire.SecondaryColor = customFireColor
    end
end

local function resetFireColor(gunDrop)
    if not gunDrop or gunDrop.Name ~= "GunDrop" then return end
    local fire = gunDrop:FindFirstChild("Fire")
    if fire and fire:IsA("Fire") then
        fire.Color = DEFAULT_FIRE_COLOR
        fire.SecondaryColor = DEFAULT_FIRE_SECONDARY
    end
end

local function enableFireColor()
    if fireColorConnection then
        fireColorConnection:Disconnect()
        fireColorConnection = nil
    end

    fireColorConnection = workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            task.wait()
            applyFireColor(obj)
        end
    end)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            applyFireColor(obj)
        end
    end
end

local function disableFireColor()
    if fireColorConnection then
        fireColorConnection:Disconnect()
        fireColorConnection = nil
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            resetFireColor(obj)
        end
    end
end

if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

local gunFeaturesSection = myTab:AddSection("Gun Features", "Gun Stuff")
gunFeaturesSection:AddParagraph("Additional Info", "This plugin works for both MM2 and MMV\n\nCredits: @drowsynicolas")
gunFeaturesSection:AddToggle("Disable Gun Animations", function(bool)
    gunFeatures.blockAnims = bool
    if bool then
        enableBlockAnims()
    else
        disableBlockAnims()
    end
end)
gunFeaturesSection:AddToggle("Equip/Unequip Gun Sound", function(bool)
    gunFeatures.equipSound = bool
    if bool then
        enableEquipSound()
    else
        disableEquipSound()
    end
end)
gunFeaturesSection:AddToggle("Gun Force Field", function(bool)
    gunFeatures.forceField = bool
    if bool then
        enableForceField()
    else
        disableForceField()
    end
end)
gunFeaturesSection:AddToggle("Custom Dropped Gun Fire Color", function(bool)
    gunFeatures.fireColor = bool
    if bool then
        enableFireColor()
    else
        disableFireColor()
    end
end)
gunFeaturesSection:AddColorpicker("Force Field Color", Color3.fromRGB(0, 100, 255), function(color)
    forceFieldColor = color

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            local sphere = obj:FindFirstChild(FORCE_FIELD_NAME)
            if sphere then
                sphere.Color = color
            end
        end
    end
end)
gunFeaturesSection:AddColorpicker("Dropped Gun Fire Color", Color3.fromRGB(0, 100, 255), function(color)
    customFireColor = color

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("Part") then
            local fire = obj:FindFirstChild("Fire")
            if fire and fire:IsA("Fire") then
                fire.Color = color
                fire.SecondaryColor = color
            end
        end
    end
end)

local controllerFeatures = {
    fixScoreboard = false,
    perkEnabled = false,
    shiftLockEnabled = false,
    spectateKeybinds = false,
}
local scoreboardMaid = nil
local spectateMaid = nil

local function toggleShiftLock()
    local mouseLock = LocalPlayer.PlayerScripts:FindFirstChild("MouseLock")
    if not mouseLock then
        return
    end
    local enabled = mouseLock:GetAttribute("Enabled")
    mouseLock:Invoke(not enabled)
end

local function shiftLockKeybind()
    if controllerFeatures.shiftLockEnabled then
        toggleShiftLock()
    end
end

local function activatePerk()
    local character = LocalPlayer.Character
    if not character then return end
    local trap = character:FindFirstChild("Trap")
    if trap then
        local activate = trap:FindFirstChild("Activate")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if activate and hrp then
            activate:FireServer(hrp.CFrame)
            return
        end
    end
    for _, perk in ipairs(character:GetChildren()) do
        local activate = perk:FindFirstChild("Activate")
        if activate then
            activate:FireServer()
            break
        end
    end
end

local function perkKeybind()
    if controllerFeatures.perkEnabled then
        activatePerk()
    end
end

local function enableFixScoreboard()
    if scoreboardMaid then
        scoreboardMaid:DoCleaning()
        scoreboardMaid = nil
    end
    scoreboardMaid = nicolas.new()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local conn = pg.ChildAdded:Connect(function(child)
        if child.Name:lower():find("scoreboard") then
            task.wait()
            child:Destroy()
        end
    end)
    scoreboardMaid:GiveTask(conn)
    for _, v in pairs(pg:GetChildren()) do
        if v.Name:lower():find("scoreboard") then
            v:Destroy()
        end
    end
end

local function disableFixScoreboard()
    if scoreboardMaid then
        scoreboardMaid:DoCleaning()
        scoreboardMaid = nil
    end
end

local function setupSpectateUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local backpackUI = playerGui:FindFirstChild("BackpackUI")
    local backpackContext = playerGui:FindFirstChild("InputContext") and playerGui.InputContext:FindFirstChild("BackpackContext")
    return backpackUI, backpackContext
end

local function enableSpectateUI()
    if spectateMaid then
        spectateMaid:DoCleaning()
        spectateMaid = nil
    end
    spectateMaid = nicolas.new()
    local backpackUI, backpackContext = setupSpectateUI()
    local charConn = Players.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        local newUI, newContext = setupSpectateUI()
        backpackUI = newUI
        backpackContext = newContext
    end)
    spectateMaid:GiveTask(charConn)
    local renderConn = RunService.RenderStepped:Connect(function()
        local character = Players.LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root or not backpackUI or not backpackContext then
            return
        end
        local camera = workspace.CurrentCamera
        local distance = (camera.CFrame.Position - root.Position).Magnitude
        local disabled = distance >= 150
        backpackUI.Enabled = not disabled
        backpackContext.Enabled = not disabled
    end)
    spectateMaid:GiveTask(renderConn)
end

local function disableSpectateUI()
    if spectateMaid then
        spectateMaid:DoCleaning()
        spectateMaid = nil
    end
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local backpackUI = playerGui:FindFirstChild("BackpackUI")
        local backpackContext = playerGui:FindFirstChild("InputContext") and playerGui.InputContext:FindFirstChild("BackpackContext")
        if backpackUI then
            backpackUI.Enabled = true
        end
        if backpackContext then
            backpackContext.Enabled = true
        end
    end
end

local controllerSection = myTab:AddSection("Controller+", "Mobile Controller Support")
controllerSection:AddParagraph("Additional Info", "Gives you a better mobile controller experience.\n\nCredits: @drowsynicolas")
controllerSection:AddToggle("Fix Scoreboard Bug", function(bool)
    controllerFeatures.fixScoreboard = bool
    if bool then
        enableFixScoreboard()
    else
        disableFixScoreboard()
    end
end)
controllerSection:AddToggle("Enable Perk", function(bool)
    controllerFeatures.perkEnabled = bool
end)
controllerSection:AddToggle("Enable Shift Lock", function(bool)
    controllerFeatures.shiftLockEnabled = bool
end)
controllerSection:AddToggle("Enable Spectate Keybinds", function(bool)
    controllerFeatures.spectateKeybinds = bool
    if bool then
        enableSpectateUI()
    else
        disableSpectateUI()
    end
end)
controllerSection:AddKeybind("Perk Keybind", "ButtonX", function()
    perkKeybind()
end)
controllerSection:AddKeybind("Shift Lock", "ButtonL3", function()
    shiftLockKeybind()
end)
controllerSection:AddKeybind("Spectate Next", "ButtonR1", function()
    if controllerFeatures.spectateKeybinds then
        SpectateService:NavigateSpectate(1)
    end
end)
controllerSection:AddKeybind("Spectate Previous", "ButtonL1", function()
    if controllerFeatures.spectateKeybinds then
        SpectateService:NavigateSpectate(-1)
    end
end)
controllerSection:AddKeybind("Toggle Spectate", "ButtonR3", function()
    if controllerFeatures.spectateKeybinds then
        SpectateService:ToggleSpectate()
    end
end)

local bombJumpParagraph = controllerSection:AddParagraph("Bomb Jump", "All credits goes to @lzzzx")

local bombJumpEnabled = false
local bombJumpDebounce = false
local autoGetBomb = false
local autoGetBombCharConn = nil

local BOMB_TYPES = {
    {name = "FakeBomb", cooldown = 22},
    {name = "GoldBomb", cooldown = 4},
}

local function giveBomb()
    local remote = ReplicatedStorage:FindFirstChild("Remotes")
        and ReplicatedStorage.Remotes:FindFirstChild("Extras")
        and ReplicatedStorage.Remotes.Extras:FindFirstChild("ReplicateToy")
    if remote then
        pcall(function()
            remote:InvokeServer("FakeBomb")
        end)
    end
end

local function startAutoGetBomb()
    if autoGetBombCharConn then return end
    autoGetBombCharConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if autoGetBomb then
            giveBomb()
        end
    end)
    if LocalPlayer.Character then
        giveBomb()
    end
end

local function stopAutoGetBomb()
    if autoGetBombCharConn then
        autoGetBombCharConn:Disconnect()
        autoGetBombCharConn = nil
    end
end

local bombCooldowns = {
    FakeBomb = 0,
    GoldBomb = 0,
}

LocalPlayer.CharacterAdded:Connect(function()
    bombCooldowns = {
        FakeBomb = 0,
        GoldBomb = 0,
    }
    bombJumpDebounce = false
end)

local function isBombReady(bombName)
    local readyAt = bombCooldowns[bombName]
    if not readyAt then return true end
    return tick() >= readyAt
end

local function getBombRemaining(bombName)
    local readyAt = bombCooldowns[bombName]
    if not readyAt then return 0 end
    return math.max(0, readyAt - tick())
end

local function getBestAvailableBomb()
    local char = LocalPlayer.Character
    if not char then return nil, nil end

    local backpack = LocalPlayer:FindFirstChild("Backpack")

    local candidates = {}
    for _, bombType in ipairs(BOMB_TYPES) do
        local found = char:FindFirstChild(bombType.name)
            or (backpack and backpack:FindFirstChild(bombType.name))
        if found and found:IsA("Tool") then
            table.insert(candidates, {tool = found, config = bombType})
        end
    end

    if #candidates == 0 then
        return nil, nil
    end

    local ready = {}
    for _, c in ipairs(candidates) do
        if isBombReady(c.config.name) then
            table.insert(ready, c)
        end
    end

    if #ready == 0 then
        table.sort(candidates, function(a, b)
            return getBombRemaining(a.config.name) < getBombRemaining(b.config.name)
        end)
        return nil, candidates[1].config
    end

    if #ready == 1 then
        return ready[1].tool, ready[1].config
    end

    table.sort(ready, function(a, b)
        return a.config.cooldown < b.config.cooldown
    end)
    return ready[1].tool, ready[1].config
end

local function bombJumpIsInAir()
    local char = LocalPlayer.Character
    if not char then return false end

    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return false end

    local state = humanoid:GetState()
    return state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Freefall
end

local function startBombJumpCooldown(bombName, duration)
    bombCooldowns[bombName] = tick() + duration
end

local function performBombJump()
    if not bombJumpEnabled then return end
    if bombJumpDebounce then return end
    if not bombJumpIsInAir() then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end

    local bomb, config = getBestAvailableBomb()
    if not bomb then
        return
    end

    local previousTool = char:FindFirstChildOfClass("Tool")

    local bombAlreadyEquipped = (bomb.Parent == char)
    if not bombAlreadyEquipped then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack and bomb.Parent == backpack then
            pcall(function()
                humanoid:EquipTool(bomb)
            end)
            task.wait(0.1)
        end
    end

    bombJumpDebounce = true

    local remote = bomb:FindFirstChild("Remote")
    if remote then
        pcall(function()
            remote:FireServer(CFrame.new(hrp.Position - Vector3.new(0, 4, 0)), 50)
        end)
    end

    task.wait(0.05)

    hrp.AssemblyLinearVelocity = Vector3.new(
        hrp.AssemblyLinearVelocity.X,
        58,
        hrp.AssemblyLinearVelocity.Z
    )

    pcall(function()
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)

    startBombJumpCooldown(config.name, config.cooldown)

    task.spawn(function()
        task.wait(0.15)
        if previousTool and previousTool.Parent then
            pcall(function()
                humanoid:EquipTool(previousTool)
            end)
        else
            pcall(function()
                humanoid:UnequipTools()
            end)
        end
    end)

    task.spawn(function()
        task.wait(0.5)
        bombJumpDebounce = false
    end)
end

controllerSection:AddToggle("Enable Bomb Jump Keybinds", function(bool)
    bombJumpEnabled = bool
end)

controllerSection:AddToggle("Auto Get Bomb", function(bool)
    autoGetBomb = bool
    if bool then
        startAutoGetBomb()
    else
        stopAutoGetBomb()
    end
end)

controllerSection:AddKeybind("Bomb Jump", "null", function()
    performBombJump()
end)

local waterFeatures = {
    waterImmunity = false,
}
local waterMaid = nil
local modifiedParts = {}
local waterPartConnections = {}

local function DisableWaterPart(part)
    if part and part:IsA("BasePart") then
        if not modifiedParts[part] then
            modifiedParts[part] = {
                CanTouch = part.CanTouch,
                CanCollide = part.CanCollide,
            }
        end
        part.CanTouch = false
        part.CanCollide = false
    end
end

local function RestoreAllParts()
    for part, originalStates in pairs(modifiedParts) do
        if part and part.Parent then
            part.CanTouch = originalStates.CanTouch
            part.CanCollide = originalStates.CanCollide
        end
    end
    modifiedParts = {}
end

local function GetWaterPart()
    local yacht = Workspace:FindFirstChild("Yacht")
    if yacht then
        local intereactive = yacht:FindFirstChild("Intereactive")
        if intereactive then
            local water = intereactive:FindFirstChild("Water")
            if water then
                return water:FindFirstChild("WaterPart")
            end
        end
    end
    local pier = Workspace:FindFirstChild("Pier")
    if pier then
        return pier:FindFirstChild("Respawn")
    end
    return nil
end

local function MonitorWaterPart(part)
    if not part or not waterFeatures.waterImmunity then return end
    DisableWaterPart(part)
    if not waterPartConnections[part] then
        waterPartConnections[part] = part.ChildAdded:Connect(function(child)
            if child:IsA("BasePart") then
                DisableWaterPart(child)
            end
        end)
        if waterMaid then
            waterMaid:GiveTask(waterPartConnections[part])
        end
    end
end

local function CheckWaterPart()
    if not waterFeatures.waterImmunity then return end
    local part = GetWaterPart()
    if part then
        MonitorWaterPart(part)
    end
end

local function enableWaterImmunity()
    if waterMaid then
        waterMaid:DoCleaning()
        waterMaid = nil
    end
    waterFeatures.waterImmunity = true
    waterMaid = nicolas.new()
    waterPartConnections = {}
    CheckWaterPart()
end

local function disableWaterImmunity()
    waterFeatures.waterImmunity = false
    if waterMaid then
        waterMaid:DoCleaning()
        waterMaid = nil
    end
    for _, conn in pairs(waterPartConnections) do
        conn:Disconnect()
    end
    waterPartConnections = {}
    RestoreAllParts()
end

local waterSection = myTab:AddSection("Water Proof", "Water Immunity")
waterSection:AddParagraph("Additional Info", "Makes you immune to water\n\nCredits: @drowsynicolas")
waterSection:AddToggle("Water Immunity", function(bool)
    if bool then
        enableWaterImmunity()
    else
        disableWaterImmunity()
    end
end)

local antiTradeMaid = nil

local function destroyTrade()
    local trade = ReplicatedStorage:FindFirstChild("Trade")
    if trade then
        trade:Destroy()
    end
end

local function enableAntiTrade()
    if antiTradeMaid then
        antiTradeMaid:DoCleaning()
        antiTradeMaid = nil
    end
    antiTradeMaid = nicolas.new()
    destroyTrade()
    antiTradeMaid:GiveTask(ReplicatedStorage.ChildAdded:Connect(function(child)
        if child.Name == "Trade" then
            child:Destroy()
        end
    end))
    antiTradeMaid:GiveTask(RunService.Heartbeat:Connect(function()
        destroyTrade()
    end))
end

local function disableAntiTrade()
    if antiTradeMaid then
        antiTradeMaid:DoCleaning()
        antiTradeMaid = nil
    end
end

local tradeSection = myTab:AddSection("Disable Trade", "fucks the trade system")
tradeSection:AddParagraph("Additional Info", "Destroys the system trade relies on\n\nCredits: @drowsynicolas")
tradeSection:AddToggle("Disable Trade", function(bool)
    if bool then
        enableAntiTrade()
    else
        disableAntiTrade()
    end
end)

local messageSection = myTab:AddSection("Client Sided Message", "just for fun")
messageSection:AddParagraph("Additional Info", "sends a message client sided, u can say anything it'll go through\n\nCredits: @drowsynicolas")
local messageText = ""
messageSection:AddTextBox("Your message", function(text)
    messageText = text
end)
messageSection:AddButton("Send Message", function()
    if messageText == "" then return end
    local character = LocalPlayer.Character
    if not character then return end
    game:GetService("Chat"):Chat(character, messageText, Enum.ChatColor.White)
end)

local serverPosSection = myTab:AddSection("Estimated Server Pos", "shows your server pos")
serverPosSection:AddParagraph("Additional Info", "creates a marker where the server thinks you are based on your ping\n\nCredits: @drowsynicolas")

local serverPosEnabled = false
local serverPosMarker = nil
local serverPosRoot = nil
local serverPosHumanoid = nil
local serverPosConnection = nil
local serverPosHealthConnection = nil
local serverPosCharAddedConn = nil
local serverPosHistory = {}
local serverPosColor = Color3.new(1, 1, 1)
local serverPosTransparency = 0.5
local serverPosHideInFirstPerson = false

local function destroyServerPosMarker()
    if serverPosConnection then
        serverPosConnection:Disconnect()
        serverPosConnection = nil
    end
    if serverPosHealthConnection then
        serverPosHealthConnection:Disconnect()
        serverPosHealthConnection = nil
    end
    if serverPosMarker then
        serverPosMarker:Destroy()
        serverPosMarker = nil
    end
    serverPosHistory = {}
end

local function getServerPosPing()
    local success, value = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and math.clamp(value, 10, 1000) or 10
end

local function createServerPosMarker(character)
    destroyServerPosMarker()

    serverPosRoot = character:WaitForChild("HumanoidRootPart")
    serverPosHumanoid = character:WaitForChild("Humanoid")

    serverPosMarker = Instance.new("Part")
    serverPosMarker.Name = "ServerPosition"
    serverPosMarker.Size = Vector3.new(2, 2, 1)
    serverPosMarker.Color = serverPosColor
    serverPosMarker.Material = Enum.Material.Plastic
    serverPosMarker.Transparency = serverPosTransparency
    serverPosMarker.Anchored = true
    serverPosMarker.CanCollide = false
    serverPosMarker.CanTouch = false
    serverPosMarker.CanQuery = false
    serverPosMarker.CastShadow = false
    serverPosMarker.Parent = workspace

    serverPosHealthConnection = serverPosHumanoid.HealthChanged:Connect(function(health)
        if health <= 0 then
            destroyServerPosMarker()
        end
    end)

    serverPosConnection = RunService.Heartbeat:Connect(function()
        if not serverPosMarker or not serverPosMarker.Parent then return end
        if not serverPosRoot or not serverPosRoot.Parent then return end

        table.insert(serverPosHistory, {
            position = serverPosRoot.Position,
            rotation = serverPosRoot.CFrame - serverPosRoot.Position,
            time = tick()
        })

        while #serverPosHistory > 120 do
            table.remove(serverPosHistory, 1)
        end

        local target = tick() - getServerPosPing() / 1000
        local closest = serverPosHistory[1]

        for _, entry in ipairs(serverPosHistory) do
            if math.abs(entry.time - target) < math.abs(closest.time - target) then
                closest = entry
            end
        end

        serverPosMarker.CFrame = CFrame.new(closest.position) * closest.rotation

        if serverPosHideInFirstPerson then
            local head = serverPosRoot.Parent and serverPosRoot.Parent:FindFirstChild("Head")
            if head then
                local camDist = (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude
                serverPosMarker.Transparency = camDist < 1 and 1 or serverPosTransparency
            else
                serverPosMarker.Transparency = serverPosTransparency
            end
        else
            serverPosMarker.Transparency = serverPosTransparency
        end
    end)
end

local function enableServerPos()
    serverPosEnabled = true
    if not serverPosCharAddedConn then
        serverPosCharAddedConn = LocalPlayer.CharacterAdded:Connect(function(character)
            task.wait()
            if serverPosEnabled then
                createServerPosMarker(character)
            end
        end)
    end
    if LocalPlayer.Character then
        createServerPosMarker(LocalPlayer.Character)
    end
end

local function disableServerPos()
    serverPosEnabled = false
    if serverPosCharAddedConn then
        serverPosCharAddedConn:Disconnect()
        serverPosCharAddedConn = nil
    end
    destroyServerPosMarker()
end

serverPosSection:AddToggle("Show Server Pos", function(bool)
    if bool then
        enableServerPos()
    else
        disableServerPos()
    end
end)

serverPosSection:AddToggle("Hide In First Person", function(bool)
    serverPosHideInFirstPerson = bool
    if not bool and serverPosMarker then
        serverPosMarker.Transparency = serverPosTransparency
    end
end)

serverPosSection:AddSlider("Marker Transparency", 1, 10, 5, function(value)
    serverPosTransparency = value / 10
    if serverPosMarker and not serverPosHideInFirstPerson then
        serverPosMarker.Transparency = serverPosTransparency
    end
end)

serverPosSection:AddColorpicker("Marker Color", Color3.fromRGB(255, 255, 255), function(color)
    serverPosColor = color
    if serverPosMarker then
        serverPosMarker.Color = color
    end
end)

local autoPerkSection = myTab:AddSection("Auto Perk", "automatically equips perks")
autoPerkSection:AddParagraph("Additional Info", "equips the perk you picked for the current map when the map loads\n\nthe UI for the equipped perk doesn't change with this but this plugin works\n\nCredits: @drowsynicolas")

local autoPerkEnabled = false
local autoPerkMapConn = nil

local VALID_PERKS = {
    "Footsteps",
    "Xray",
    "Trap",
    "Sprint",
    "Sleight",
    "Ninja",
    "Haste",
    "Ghost",
    "FakeGun",
    "Decoy",
}

local MAP_LIST = {
    {name = "House 2", keyword = "House2"},
    {name = "Factory", keyword = "Factory"},
    {name = "Milbase", keyword = "MilBase"},
    {name = "Workplace", keyword = "Workplace"},
    {name = "Mansion 2", keyword = "Mansion2"},
    {name = "Research Facility", keyword = "ResearchFacility"},
    {name = "Police Station", keyword = "PoliceStation"},
    {name = "Bio Lab", keyword = "BioLab"},
    {name = "Bank 2", keyword = "Bank2"},
    {name = "Office 2014", keyword = "Office2014"},
    {name = "Hospital 2014", keyword = "Hospital2014"},
    {name = "Hotel 2014", keyword = "Hotel2014"},
}

local autoPerkChoices = {}

local function normalizePerk(text)
    if not text or text == "" then return nil end
    local cleaned = text:gsub("%s+", ""):lower()
    for _, perk in ipairs(VALID_PERKS) do
        if perk:lower() == cleaned then
            return perk
        end
    end
    return nil
end

local function getPerkEquipRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    local inventory = remotes:FindFirstChild("Inventory")
    if not inventory then return nil end
    return inventory:FindFirstChild("Equip")
end

local function equipPerk(perkName)
    if not perkName then return end
    if LocalPlayer:GetAttribute("EquippedPerk") == perkName then return end
    local remote = getPerkEquipRemote()
    if remote then
        remote:FireServer(perkName, "Perks")
    end
end

local function getCurrentMap()
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            for _, entry in ipairs(MAP_LIST) do
                if child.Name == entry.keyword then
                    return entry.keyword
                end
            end
        end
    end
    return nil
end

local function isMapName(name)
    for _, entry in ipairs(MAP_LIST) do
        if entry.keyword == name then
            return true
        end
    end
    return false
end

local function tryAutoEquip()
    if not autoPerkEnabled then return end
    local mapKeyword = getCurrentMap()
    if not mapKeyword then return end
    local perk = autoPerkChoices[mapKeyword]
    if not perk then return end
    equipPerk(perk)
end

local function startAutoPerk()
    if autoPerkMapConn then
        autoPerkMapConn:Disconnect()
        autoPerkMapConn = nil
    end

    autoPerkMapConn = workspace.ChildAdded:Connect(function(child)
        if not child:IsA("Model") and not child:IsA("Folder") then return end
        if not isMapName(child.Name) then return end
        task.wait(0.5)
        tryAutoEquip()
    end)

    task.spawn(function()
        tryAutoEquip()
    end)
end

local function stopAutoPerk()
    if autoPerkMapConn then
        autoPerkMapConn:Disconnect()
        autoPerkMapConn = nil
    end
end

autoPerkSection:AddToggle("Auto Perk", function(bool)
    autoPerkEnabled = bool
    if bool then
        startAutoPerk()
    else
        stopAutoPerk()
    end
end)

autoPerkSection:AddParagraph("Valid Perks", "Type the perk name for each map. Valid inputs: Footsteps, Xray, Trap, Sprint, Sleight, Ninja, Haste, Ghost, FakeGun, Decoy")

for _, mapEntry in ipairs(MAP_LIST) do
    autoPerkSection:AddTextBox(mapEntry.name, function(text)
        if text == "" then return end
        local perk = normalizePerk(text)
        if perk then
            autoPerkChoices[mapEntry.keyword] = perk
            shared.Notify("Auto Perk: \"" .. perk .. "\" selected for " .. mapEntry.name, 3)
            if autoPerkEnabled then
                tryAutoEquip()
            end
        else
            autoPerkChoices[mapEntry.keyword] = "Footsteps"
            shared.Notify("Auto Perk: invalid input, fallback to Footsteps", 3)
            if autoPerkEnabled then
                tryAutoEquip()
            end
        end
    end)
end

local itemTintSection = myTab:AddSection("Tool Tint", "cosmetic")
itemTintSection:AddParagraph("Additional Info", "tints any tool you hold\n\nCredits: @drowsynicolas")

local toolTintEnabled = false
local toolTintColor = Color3.fromRGB(255, 255, 255)
local toolTintTransparency = 0.5
local toolTintCharacterConnection = nil
local toolTintChildConnection = nil

local function applyToolTint(tool)
    if not tool:IsA("Tool") then return end
    local handle = tool:FindFirstChild("Handle")
    if not handle then return end

    local didVertexColor = false
    for _, mesh in ipairs(handle:GetChildren()) do
        if mesh:IsA("SpecialMesh") or mesh:IsA("BlockMesh") or mesh:IsA("CylinderMesh") or mesh:IsA("FileMesh") then
            if not mesh.TextureId or mesh.TextureId == "" then
                mesh.VertexColor = Vector3.new(toolTintColor.R, toolTintColor.G, toolTintColor.B)
                didVertexColor = true
            end
        end
    end

    local highlight = tool:FindFirstChild("ToolTint")
    if didVertexColor then
        if highlight then
            highlight:Destroy()
        end
    else
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "ToolTint"
            highlight.OutlineTransparency = 1
            highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            highlight.Adornee = tool
            highlight.Parent = tool
        end
        highlight.FillColor = toolTintColor
        highlight.FillTransparency = toolTintTransparency
    end
end

local function removeToolTint(tool)
    if not tool:IsA("Tool") then return end
    local handle = tool:FindFirstChild("Handle")
    if handle then
        for _, mesh in ipairs(handle:GetChildren()) do
            if mesh:IsA("SpecialMesh") or mesh:IsA("BlockMesh") or mesh:IsA("CylinderMesh") or mesh:IsA("FileMesh") then
                mesh.VertexColor = Vector3.new(1, 1, 1)
            end
        end
    end
    local highlight = tool:FindFirstChild("ToolTint")
    if highlight then
        highlight:Destroy()
    end
end

local function monitorToolTintCharacter(character)
    for _, object in ipairs(character:GetChildren()) do
        applyToolTint(object)
    end

    if toolTintChildConnection then
        toolTintChildConnection:Disconnect()
    end

    toolTintChildConnection = character.ChildAdded:Connect(function(object)
        if toolTintEnabled then
            applyToolTint(object)
        end
    end)
end

local function clearAllToolTints()
    local char = LocalPlayer.Character
    if char then
        for _, object in ipairs(char:GetChildren()) do
            removeToolTint(object)
        end
    end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, object in ipairs(backpack:GetChildren()) do
            removeToolTint(object)
        end
    end
end

local function enableToolTint()
    toolTintEnabled = true

    if toolTintCharacterConnection then
        toolTintCharacterConnection:Disconnect()
    end

    toolTintCharacterConnection = LocalPlayer.CharacterAdded:Connect(monitorToolTintCharacter)

    if LocalPlayer.Character then
        monitorToolTintCharacter(LocalPlayer.Character)
    end
end

local function disableToolTint()
    toolTintEnabled = false

    if toolTintCharacterConnection then
        toolTintCharacterConnection:Disconnect()
        toolTintCharacterConnection = nil
    end
    if toolTintChildConnection then
        toolTintChildConnection:Disconnect()
        toolTintChildConnection = nil
    end

    clearAllToolTints()
end

itemTintSection:AddToggle("Tool Tint", function(bool)
    if bool then
        enableToolTint()
    else
        disableToolTint()
    end
end)

itemTintSection:AddSlider("Tint Transparency", 1, 10, 5, function(value)
    toolTintTransparency = value / 10

    local char = LocalPlayer.Character
    if char then
        for _, object in ipairs(char:GetChildren()) do
            if object:IsA("Tool") then
                local highlight = object:FindFirstChild("ToolTint")
                if highlight then
                    highlight.FillTransparency = toolTintTransparency
                end
            end
        end
    end
end)

itemTintSection:AddColorpicker("Tool Tint Color", Color3.fromRGB(255, 255, 255), function(color)
    toolTintColor = color

    local char = LocalPlayer.Character
    if char then
        for _, object in ipairs(char:GetChildren()) do
            if object:IsA("Tool") then
                applyToolTint(object)
            end
        end
    end
end)

local chatSection = myTab:AddSection("Custom Chat", "Customize your chat!")
chatSection:AddParagraph("Additional Info", "custom chat sound requires the sound to be from github\n\nexample: /nonchalantnicolas/yoshi-lick/main/copy_588622E8-9E6A-4DD1-9673-1858746082F1.mp3\n\nCredits: @drowsynicolas")

local chatColorEnabled = false
local chatSoundEnabled = false
local muteOthersChatSound = false
local chatBubbleColor = Color3.fromRGB(255, 255, 255)
local chatTextColor = Color3.fromRGB(0, 0, 0)
local originalBubbleColor = nil
local originalTextColor = nil
local currentSoundId = nil
local chattedConnections = {}
local playerAddedConn = nil

local function getBubbleConfig()
    return TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
end

local function applyChatColors()
    local config = getBubbleConfig()
    if not config then return end
    if originalBubbleColor == nil then
        originalBubbleColor = config.BackgroundColor3
        originalTextColor = config.TextColor3
    end
    config.BackgroundColor3 = chatBubbleColor
    config.TextColor3 = chatTextColor
end

local function restoreChatColors()
    local config = getBubbleConfig()
    if not config then return end
    if originalBubbleColor then
        config.BackgroundColor3 = originalBubbleColor
        config.TextColor3 = originalTextColor
    end
end

local function hashURL(url)
    local hash = 5381
    for i = 1, #url do
        hash = ((hash * 33) + string.byte(url, i)) % 4294967296
    end
    return string.format("%x", hash)
end

local function getFilename(url)
    local ext = url:match("%.([%w]+)$") or "mp3"
    return "chatSound_" .. hashURL(url) .. "." .. ext
end

local function buildURL(input)
    local path = input:gsub("^https://raw%.githubusercontent%.com", "")
    if path:sub(1, 1) ~= "/" then
        path = "/" .. path
    end
    return "https://raw.githubusercontent.com" .. path
end

local function loadChatSound(input)
    if type(input) ~= "string" then return end
    input = input:gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then return end

    if not isfile or not writefile or not game.HttpGet then
        shared.Notify("Custom Chat: executor doesn't support file downloads", 3)
        return
    end

    local getasset = getcustomasset or getsynasset
    if not getasset then
        shared.Notify("Custom Chat: executor doesn't support custom assets", 3)
        return
    end

    local fullURL = buildURL(input)
    local fileName = getFilename(fullURL)

    if not isfile(fileName) then
        shared.Notify("Custom Chat: downloading...", 2)
        local success = pcall(function()
            writefile(fileName, game:HttpGet(fullURL))
        end)
        if not success then
            shared.Notify("Custom Chat: download failed", 3)
            return
        end
    end

    local success, soundId = pcall(getasset, fileName)
    if success and soundId then
        currentSoundId = soundId
        shared.Notify("Custom Chat: sound loaded", 2)
    else
        shared.Notify("Custom Chat: failed to load sound", 3)
    end
end

local function playChatSound(player)
    if not currentSoundId then return end
    if muteOthersChatSound and player ~= LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local sound = Instance.new("Sound")
    sound.SoundId = currentSoundId
    sound.Volume = 0.5
    sound.Parent = hrp
    sound:Play()

    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

local function hookPlayer(player)
    if chattedConnections[player] then return end
    chattedConnections[player] = player.Chatted:Connect(function()
        if chatSoundEnabled then
            playChatSound(player)
        end
    end)
end

local function enableChatSound()
    chatSoundEnabled = true
    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(player)
    end
    if not playerAddedConn then
        playerAddedConn = Players.PlayerAdded:Connect(hookPlayer)
    end
end

local function disableChatSound()
    chatSoundEnabled = false
    for player, conn in pairs(chattedConnections) do
        conn:Disconnect()
    end
    chattedConnections = {}
    if playerAddedConn then
        playerAddedConn:Disconnect()
        playerAddedConn = nil
    end
end

Players.PlayerRemoving:Connect(function(player)
    local conn = chattedConnections[player]
    if conn then
        conn:Disconnect()
        chattedConnections[player] = nil
    end
end)

chatSection:AddToggle("Custom Chat Color", function(bool)
    chatColorEnabled = bool
    if bool then
        applyChatColors()
    else
        restoreChatColors()
    end
end)

chatSection:AddToggle("Custom Chat Sound", function(bool)
    if bool then
        enableChatSound()
    else
        disableChatSound()
    end
end)

chatSection:AddToggle("Mute Others Chat Sound", function(bool)
    muteOthersChatSound = bool
end)

chatSection:AddTextBox("Sound URL", function(text)
    if text == "" then return end
    loadChatSound(text)
end)

chatSection:AddColorpicker("Chat Bubble Color", Color3.fromRGB(255, 255, 255), function(color)
    chatBubbleColor = color
    if chatColorEnabled then
        applyChatColors()
    end
end)

chatSection:AddColorpicker("Chat Text Color", Color3.fromRGB(0, 0, 0), function(color)
    chatTextColor = color
    if chatColorEnabled then
        applyChatColors()
    end
end)

local emotesSection = myTab:AddSection("Emotes", "play any emote")
emotesSection:AddParagraph("Additional Info", "play any emote with a keybind\n\nCredits: @drowsynicolas")

local emoteKeybindsEnabled = false

local function playEmote(emoteName)
    if not emoteKeybindsEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if not animate then return end
    local remote = animate:FindFirstChild("PlayEmote")
    if not remote then return end
    pcall(function()
        remote:Invoke(emoteName)
    end)
end

emotesSection:AddToggle("Emote keybinds", function(bool)
    emoteKeybindsEnabled = bool
end)

emotesSection:AddKeybind("Sit", "null", function()
    playEmote("sit2")
end)

emotesSection:AddKeybind("Dab", "null", function()
    playEmote("dab")
end)

emotesSection:AddKeybind("Ninja's Rest", "null", function()
    playEmote("ninja")
end)

emotesSection:AddKeybind("Zen", "null", function()
    playEmote("zen")
end)

emotesSection:AddKeybind("Zombie", "null", function()
    playEmote("zombie")
end)

emotesSection:AddKeybind("Headless", "null", function()
    playEmote("headless")
end)

local coinSection = myTab:AddSection("Coin Misc", "random coin scripts")
coinSection:AddParagraph("Additional Info", "just coin stuff idk ;-;\n\nCredits: @drowsynicolas")

local coinFeatures = { master = false, allCoins = false, nearestOnly = false, customColor = false }
local COIN_SCAN_INTERVAL = 1
local COIN_REFRESH_INTERVAL = 0.5

local coinContainers = {}
local coinLastContainerScan = -math.huge
local coinHighlights = {}
local coinOriginalColors = {}
local coinCustomColor = Color3.fromRGB(255, 255, 255)
local coinLoopThread = nil
local coinDescAddedConn = nil

local function coinIsCoin(part) return part.Name == "Coin_Server" and part:IsA("BasePart") end

local function coinScanContainers()
    if tick() - coinLastContainerScan < COIN_SCAN_INTERVAL then return end
    coinLastContainerScan = tick()
    local newList = {}
    for _, top in ipairs(workspace:GetChildren()) do
        local container = top:FindFirstChild("CoinContainer")
        if container then table.insert(newList, container) else
            for _, child in ipairs(top:GetChildren()) do
                local c2 = child:FindFirstChild("CoinContainer")
                if c2 then table.insert(newList, c2) end
            end
        end
    end
    coinContainers = newList
end

local function coinGetVisual(coin)
    local visual = coin:FindFirstChild("CoinVisual")
    if visual and visual:IsA("MeshPart") then return visual end
    return nil
end

local function coinApplyColor(coin)
    local visual = coinGetVisual(coin)
    if not visual then return end
    if coinOriginalColors[coin] == nil then coinOriginalColors[coin] = visual.Color end
    if visual.Color ~= coinCustomColor then visual.Color = coinCustomColor end

    local hl = coinHighlights[coin]
    if hl and hl.Parent then
        hl.FillColor = coinCustomColor
        hl.OutlineColor = Color3.new(math.max(coinCustomColor.R - 0.25, 0), math.max(coinCustomColor.G - 0.25, 0), math.max(coinCustomColor.B - 0.25, 0))
    end
end

local function coinRestoreColor(coin)
    local original = coinOriginalColors[coin]
    if original == nil then return end
    local visual = coinGetVisual(coin)
    if visual and visual.Color ~= original then visual.Color = original end
    
    local hl = coinHighlights[coin]
    if hl and hl.Parent then
        hl.FillColor = original
        hl.OutlineColor = Color3.new(math.max(original.R - 0.25, 0), math.max(original.G - 0.25, 0), math.max(original.B - 0.25, 0))
    end
    coinOriginalColors[coin] = nil
end

local function coinAddHighlight(coin)
    if coinHighlights[coin] then return end
    local visual = coinGetVisual(coin) or coin
    local fillColor = visual.Color
    local outlineColor = Color3.new(math.max(fillColor.R - 0.25, 0), math.max(fillColor.G - 0.25, 0), math.max(fillColor.B - 0.25, 0))

    local hl = Instance.new("Highlight")
    hl.Name = "CoinESP"
    hl.Adornee = visual
    hl.FillColor = fillColor
    hl.FillTransparency = 0.4
    hl.OutlineColor = outlineColor
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = visual
    coinHighlights[coin] = hl
end

local function coinRemoveHighlight(coin)
    local hl = coinHighlights[coin]
    if hl then if hl.Parent then hl:Destroy() end coinHighlights[coin] = nil end
end

local function coinClearHighlights()
    for _, hl in pairs(coinHighlights) do if hl.Parent then hl:Destroy() end end
    table.clear(coinHighlights)
end

local function coinFindNearest(liveCoins)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local pos = hrp.Position
    local nearest = nil
    local nearestDist = math.huge
    for coin in pairs(liveCoins) do
        local d = (coin.Position - pos).Magnitude
        if d < nearestDist then nearestDist = d; nearest = coin end
    end
    return nearest
end

local function coinEspTick()
    coinScanContainers()
    local liveCoins = {}
    for _, container in ipairs(coinContainers) do
        for _, child in ipairs(container:GetChildren()) do
            if coinIsCoin(child) and child.Parent then liveCoins[child] = true end
        end
    end

    local targetCoins = {}
    if coinFeatures.allCoins then targetCoins = liveCoins elseif coinFeatures.nearestOnly then
        local nearest = coinFindNearest(liveCoins)
        if nearest then targetCoins[nearest] = true end
    end

    for coin in pairs(targetCoins) do if not coinHighlights[coin] then coinAddHighlight(coin) end end
    for coin in pairs(coinHighlights) do if not targetCoins[coin] then coinRemoveHighlight(coin) end end
    if coinFeatures.customColor then for coin in pairs(liveCoins) do coinApplyColor(coin) end end
end

local function coinStartLoop()
    if coinLoopThread then return end
    coinLoopThread = task.spawn(function()
        while coinFeatures.master do
            coinEspTick()
            task.wait(COIN_REFRESH_INTERVAL)
        end
        coinLoopThread = nil
    end)
end

local function coinStopLoop() coinClearHighlights() end

local function coinApplyColorToAll()
    coinScanContainers()
    for _, container in ipairs(coinContainers) do
        for _, child in ipairs(container:GetChildren()) do
            if coinIsCoin(child) then coinApplyColor(child) end
        end
    end
end

local function coinRestoreAllColors()
    for coin in pairs(coinOriginalColors) do
        if coin.Parent then coinRestoreColor(coin) else coinOriginalColors[coin] = nil end
    end
end

local function coinOnDescendantAdded(desc)
    if coinFeatures.customColor and coinIsCoin(desc) then
        task.spawn(function()
            local visual = desc:FindFirstChild("CoinVisual") or desc:WaitForChild("CoinVisual", 5)
            if visual and coinFeatures.customColor and desc.Parent then coinApplyColor(desc) end
        end)
    end
end

local function coinStartDescHook()
    if coinDescAddedConn then return end
    coinDescAddedConn = workspace.DescendantAdded:Connect(coinOnDescendantAdded)
end

local function coinStopDescHook()
    if coinDescAddedConn then coinDescAddedConn:Disconnect() coinDescAddedConn = nil end
end

coinSection:AddToggle("Coin ESP", function(bool)
    coinFeatures.master = bool
    if bool then coinStartLoop() else coinStopLoop() end
end)

coinSection:AddToggle("ESP All Coins", function(bool) coinFeatures.allCoins = bool end)
coinSection:AddToggle("ESP Nearest Coin Only", function(bool) coinFeatures.nearestOnly = bool end)

coinSection:AddToggle("Custom Coin Color", function(bool)
    coinFeatures.customColor = bool
    if bool then coinStartDescHook(); coinApplyColorToAll() else coinStopDescHook(); coinRestoreAllColors() end
end)

coinSection:AddColorpicker("Coin Color", Color3.fromRGB(255, 255, 255), function(color)
    coinCustomColor = color
    if coinFeatures.customColor then coinApplyColorToAll() end
end)

coinSection:AddParagraph("Cap FPS", "you may be wondering \"why the hell is this in coin misc?\" well to answer your question it's for auto farming. capping your fps to like 30 prevents your device from overheating and exploding and causing a house fire. please note anything 20 and below makes flinging less efficient.")

local fpsCapperEnabled = false
local fpsCapValue = nil

local function fpsCapIsValid(n) return typeof(n) == "number" and n >= 1 and n <= 999 end
local function fpsCapApply(n)
    if not fpsCapIsValid(n) then return false end
    if not setfpscap then shared.Notify("FPS Capper: executor doesn't support setfpscap", 3) return false end
    local ok = pcall(setfpscap, n)
    if not ok then shared.Notify("FPS Capper: setfpscap failed", 3) return false end
    return true
end

local function fpsCapRestore()
    if not setfpscap then return end
    pcall(setfpscap, 999)
end

coinSection:AddToggle("FPS Capper", function(bool)
    fpsCapperEnabled = bool
    if bool then if fpsCapValue and fpsCapIsValid(fpsCapValue) then fpsCapApply(fpsCapValue) end
    else fpsCapRestore() end
end)

coinSection:AddTextBox("FPS Cap", function(text)
    local n = tonumber(text)
    if n then fpsCapValue = n else fpsCapValue = nil end
end)

coinSection:AddButton("Apply FPS", function()
    if not fpsCapperEnabled then return end
    if not fpsCapValue then shared.Notify("FPS Capper: enter a valid number first", 3) return end
    if not fpsCapIsValid(fpsCapValue) then shared.Notify("FPS Capper: value must be 1-999", 3) return end
    fpsCapApply(fpsCapValue)
end)

local eventSection = myTab:AddSection("Event", "For MM2 Events!")
eventSection:AddParagraph("Additional Info", "counter for your current event currency and how much you need until you get the final reward tier\n\nCredits: @drowsynicolas")

local eventFeatures = { showCurrent = false, showUntil = false }
local EVENT_TARGET = 100000

local eventGui = nil
local eventCurrentLabel = nil
local eventUntilLabel = nil
local eventCandyLabel = nil
local eventTextConn = nil
local eventLabelWaitThread = nil

local function eventFormatNumber(num)
    return tostring(math.floor(num)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function eventTryFindCandyLabel()
    local ok, res = pcall(function()
        return LocalPlayer.PlayerGui.CrossPlatform.Halloween2026.MainEvent.Main.BattlePass.Title.Tokens.Container.TextLabel
    end)
    if ok then return res end
    return nil
end

local function eventUpdateLabels()
    if not eventCurrentLabel or not eventUntilLabel then return end
    if not eventCandyLabel or not eventCandyLabel.Parent then
        eventCandyLabel = eventTryFindCandyLabel()
    end

    if eventCandyLabel then
        local raw = eventCandyLabel.Text
        eventCurrentLabel.Text = raw
        local digits = raw:gsub("[^%d]", "")
        local candy = tonumber(digits)
        if candy then
            local left = EVENT_TARGET - candy
            if left <= 0 then
                eventUntilLabel.Text = "Ready!"
            else
                eventUntilLabel.Text = eventFormatNumber(left)
            end
        else
            eventUntilLabel.Text = "?"
        end
    else
        eventCurrentLabel.Text = "?"
        eventUntilLabel.Text = "?"
    end
end

local function eventHookCandyLabel()
    if eventTextConn then eventTextConn:Disconnect() eventTextConn = nil end
    eventCandyLabel = eventTryFindCandyLabel()
    if eventCandyLabel then
        eventTextConn = eventCandyLabel:GetPropertyChangedSignal("Text"):Connect(eventUpdateLabels)
        eventUpdateLabels()
    else
        if eventCurrentLabel then eventCurrentLabel.Text = "?" end
        if eventUntilLabel then eventUntilLabel.Text = "?" end
    end
end

local function eventCreateGui()
    if eventGui then return end

    eventGui = Instance.new("ScreenGui")
    eventGui.Name = "gatito"
    eventGui.ResetOnSpawn = false
    eventGui.IgnoreGuiInset = true
    eventGui.DisplayOrder = 999
    eventGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    eventCurrentLabel = Instance.new("TextLabel")
    eventCurrentLabel.Size = UDim2.new(0, 185, 0, 30)
    eventCurrentLabel.Position = UDim2.new(0.5, 200, 0.5, -15)
    eventCurrentLabel.BackgroundTransparency = 1
    eventCurrentLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
    eventCurrentLabel.Font = Enum.Font.SciFi
    eventCurrentLabel.TextSize = 24
    eventCurrentLabel.Text = "?"
    eventCurrentLabel.Visible = false
    eventCurrentLabel.Parent = eventGui

    eventUntilLabel = Instance.new("TextLabel")
    eventUntilLabel.Size = UDim2.new(0, 185, 0, 30)
    eventUntilLabel.Position = UDim2.new(0.5, 200, 0.5, 5)
    eventUntilLabel.BackgroundTransparency = 1
    eventUntilLabel.TextColor3 = Color3.fromRGB(165, 60, 210)
    eventUntilLabel.Font = Enum.Font.SciFi
    eventUntilLabel.TextSize = 23
    eventUntilLabel.Text = "?"
    eventUntilLabel.Visible = false
    eventUntilLabel.Parent = eventGui
    
    eventHookCandyLabel()
end

local function eventDestroyGui()
    if eventTextConn then eventTextConn:Disconnect() eventTextConn = nil end
    if eventGui then eventGui:Destroy() eventGui = nil end
    eventCurrentLabel = nil
    eventUntilLabel = nil
    eventCandyLabel = nil
end

local function eventStartWatcher()
    if eventLabelWaitThread then return end
    eventLabelWaitThread = task.spawn(function()
        while (eventFeatures.showCurrent or eventFeatures.showUntil) do
            if not eventCandyLabel or not eventCandyLabel.Parent then eventHookCandyLabel() end
            task.wait(1)
        end
        eventLabelWaitThread = nil
    end)
end

local function eventRefreshVisibility()
    if not (eventFeatures.showCurrent or eventFeatures.showUntil) then
        eventDestroyGui()
        return
    end

    eventCreateGui()
    if eventCurrentLabel then
        eventCurrentLabel.Visible = eventFeatures.showCurrent
        eventCurrentLabel.Position = UDim2.new(0.5, 200, 0.5, -15)
    end
    if eventUntilLabel then
        eventUntilLabel.Visible = eventFeatures.showUntil
        if eventFeatures.showCurrent then
            eventUntilLabel.Position = UDim2.new(0.5, 200, 0.5, 5)
        else
            eventUntilLabel.Position = UDim2.new(0.5, 200, 0.5, -15)
        end
    end
    eventStartWatcher()
end

eventSection:AddToggle("Show Current Candies", function(bool)
    eventFeatures.showCurrent = bool
    eventRefreshVisibility()
end)

eventSection:AddToggle("Show Candies Until Emberbow", function(bool)
    eventFeatures.showUntil = bool
    eventRefreshVisibility()
end)

local personalSection = myTab:AddSection("Personal", "hi")
personalSection:AddParagraph("Additional Info", "code i'd rather put into my plugin than execute it individually\n\nall credits obviously go to me haha @drowsynicolas")

local personalFeatures = {
    infJump = false,
    autoBroom = false,
}

local infJumpBoost = 40
local infJumpFallMul = 1.0

local infJumpHeartbeatConn = nil
local infJumpRequestConn = nil
local infJumpHeld = false

local function infJumpHeartbeat()
    if not personalFeatures.infJump then return end
    local char = LocalPlayer.Character
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end

    local vel = root.AssemblyLinearVelocity

    if infJumpHeld then
        root.AssemblyLinearVelocity = Vector3.new(vel.X, infJumpBoost, vel.Z)
    end
    if vel.Y < 0 and infJumpFallMul ~= 1.0 then
        root.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y * infJumpFallMul, vel.Z)
    end
    if not humanoid.Jump then
        infJumpHeld = false
    end
end

local function infJumpStart()
    if infJumpHeartbeatConn then return end
    local uis = game:GetService("UserInputService")

    infJumpRequestConn = uis.JumpRequest:Connect(function()
        if personalFeatures.infJump then
            infJumpHeld = true
        end
    end)
    infJumpHeartbeatConn = RunService.Heartbeat:Connect(infJumpHeartbeat)
end

local function infJumpStop()
    if infJumpHeartbeatConn then infJumpHeartbeatConn:Disconnect() infJumpHeartbeatConn = nil end
    if infJumpRequestConn then infJumpRequestConn:Disconnect() infJumpRequestConn = nil end
    infJumpHeld = false
end

local autoBroomConn = nil
local function autoBroomOnCharacter(character)
    task.wait(2)
    if LocalPlayer.Character ~= character or not personalFeatures.autoBroom then return end

    local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Extras") and ReplicatedStorage.Remotes.Extras:FindFirstChild("ReplicateToy")
    if not remote then return end

    pcall(function() remote:InvokeServer("Broom26") end)

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local tool = character:FindFirstChild("Broom26") or (backpack and backpack:FindFirstChild("Broom26"))

    if tool and tool:IsA("Tool") then
        tool.Parent = character
        pcall(function() tool:Activate() end)
    end
end

local function autoBroomStart()
    if autoBroomConn then return end
    autoBroomConn = LocalPlayer.CharacterAdded:Connect(autoBroomOnCharacter)
    if LocalPlayer.Character then task.spawn(autoBroomOnCharacter, LocalPlayer.Character) end
end

local function autoBroomStop()
    if autoBroomConn then autoBroomConn:Disconnect() autoBroomConn = nil end
end

personalSection:AddToggle("Inf Jump", function(bool)
    personalFeatures.infJump = bool
    if bool then infJumpStart() else infJumpStop() end
end)

personalSection:AddSlider("Jump Boost", 10, 100, 40, function(value)
    infJumpBoost = value
end)

personalSection:AddSlider("Fall Multiplier", 1, 10, 10, function(value)
    infJumpFallMul = value / 10
end)

personalSection:AddToggle("Auto Broom", function(bool)
    personalFeatures.autoBroom = bool
    if bool then autoBroomStart() else autoBroomStop() end
end)

RootNicolas:GiveTask(function()
    gunFeatures.blockAnims = false
    gunFeatures.equipSound = false
    gunFeatures.forceField = false
    gunFeatures.fireColor = false
    disableBlockAnims()
    disableEquipSound()
    disableForceField()
    disableFireColor()
    for character, data in pairs(charData) do
        cleanCharacter(character)
    end
    charData = {}
    controllerFeatures.fixScoreboard = false
    controllerFeatures.perkEnabled = false
    controllerFeatures.shiftLockEnabled = false
    controllerFeatures.spectateKeybinds = false
    disableFixScoreboard()
    disableSpectateUI()
    waterFeatures.waterImmunity = false
    disableWaterImmunity()
    disableAntiTrade()
    disableServerPos()
    stopAutoPerk()
    disableToolTint()
    disableChatSound()
    restoreChatColors()
    emoteKeybindsEnabled = false
    stopAutoGetBomb()
    coinFeatures.master = false
    coinFeatures.customColor = false
    coinStopLoop()
    coinStopDescHook()
    coinRestoreAllColors()
    fpsCapperEnabled = false
    fpsCapRestore()
    eventFeatures.showCurrent = false
    eventFeatures.showUntil = false
    eventDestroyGui()
    personalFeatures.infJump = false
    infJumpStop()
    personalFeatures.autoBroom = false
    autoBroomStop()
end)
