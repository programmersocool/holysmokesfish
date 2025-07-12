if not game:IsLoaded() then game.Loaded:Wait() end

local SCRIPT_HUB_NAME = "cooliopoolio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "0.2.1" -- please use semver (https://semver.org/)
local SCRIPT_ID = SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME .. "/" .. SCRIPT_HUB_PLACE .. " v" .. SCRIPT_VERSION

-- Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Custom Signal for events
local Signal = {}
Signal.__index = Signal
function Signal.new()
	local self = setmetatable({}, Signal)
	self.connections = {}
	return self
end
function Signal:Connect(func)
	local conn = { func = func }
	table.insert(self.connections, conn)
	return conn
end
function Signal:Disconnect(connToDisconnect)
	for i, conn in ipairs(self.connections) do
		if conn == connToDisconnect then
			table.remove(self.connections, i)
			break
		end
	end
end
function Signal:Fire(...)
	for _, conn in ipairs(self.connections) do
		task.spawn(conn.func, ...)
	end
end

-- Common Objects
local Common = {
	Rooms = workspace:WaitForChild("CurrentRooms"),
	Drops = workspace:WaitForChild("Drops"),
	RemotesFolder = ReplicatedStorage:WaitForChild("RemotesFolder"),
	GameData = ReplicatedStorage:WaitForChild("GameData"),
	CurrentRoom = 0,
	RoomChanged = Signal.new()
}
function Common.GetCurrentRoomModel()
	return Common.Rooms:FindFirstChild(tostring(Common.CurrentRoom))
end


-- https://github.com/deividcomsono/Obsidian/blob/main/README.md

type Obsidian = typeof(require(script:FindFirstChild("Obsidian")))
type SaveManager = typeof(require(script:FindFirstChild("SaveManager")))

local Obsidian: Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local SaveManager: SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()

local function debugNotify(text: string)
	print(SCRIPT_ID .. ": " .. text)
	Obsidian:Notify({
		Title = SCRIPT_HUB_NAME,
		Description = text,
		Time = 3,
	})
end

debugNotify("loaded libraries")


-----------------------------------
-------------- LOGIC --------------
-----------------------------------

local Logic = {}

-- fade-in effect for esp elements
local function fadeIn(instance)
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	if instance:IsA("Highlight") then
		instance.FillTransparency = 1
		instance.OutlineTransparency = 1
		TweenService:Create(instance, tweenInfo, { FillTransparency = 0, OutlineTransparency = 0 }):Play()
	elseif instance:IsA("BillboardGui") then
		local label = instance:FindFirstChildOfClass("TextLabel")
		if label then
			local stroke = label:FindFirstChildOfClass("UIStroke")
			label.TextTransparency = 1
			if stroke then stroke.Transparency = 1 end
			local tween = TweenService:Create(label, tweenInfo, { TextTransparency = 0 })
			tween:Play()
			if stroke then
				local strokeTween = TweenService:Create(stroke, tweenInfo, { Transparency = 0 })
				strokeTween:Play()
			end
		end
	end
end

-- a reusable function to create billboard guis for esp
local function CreateBillboardGui(options: {
	Parent: Instance,
	Adornee: BasePart,
	Text: string,
	TextColor: Color3,
	StudsOffset: Vector3?
})
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 200, 0, 50)
	billboardGui.AlwaysOnTop = true
	billboardGui.StudsOffset = options.StudsOffset or Vector3.new(0, 0, 0)
	billboardGui.Adornee = options.Adornee
	billboardGui.Parent = options.Parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = false
	textLabel.TextSize = 20
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Text = options.Text
	textLabel.TextColor3 = options.TextColor
	textLabel.Parent = billboardGui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = textLabel
	return billboardGui
end


-- Fullbright
do
	local ogBrightness = Lighting.Brightness
	local ogAmbient = Lighting.Ambient
	local roomData = {}
	local roomAddedConnection = nil
	local fullbrightEnabled = false

	local function setRoomFullbright(room)
		if room:IsA("Model") and not roomData[room] then
			local conn = room:GetAttributeChangedSignal("Ambient"):Connect(function()
				if fullbrightEnabled and room:GetAttribute("Ambient") ~= Color3.new(1, 1, 1) then
					room:SetAttribute("Ambient", Color3.new(1, 1, 1))
				end
			end)
			roomData[room] = { original = room:GetAttribute("Ambient"), connection = conn }
			room:SetAttribute("Ambient", Color3.new(1, 1, 1))
		end
	end

	Logic.Fullbright = function(enable: boolean)
		fullbrightEnabled = enable
		if enable then
			Lighting.Brightness = 3
			Lighting.Ambient = Color3.new(1, 1, 1)
			for _, room in ipairs(Common.Rooms:GetChildren()) do setRoomFullbright(room) end
			roomAddedConnection = Common.Rooms.ChildAdded:Connect(setRoomFullbright)
		else
			Lighting.Brightness = ogBrightness
			Lighting.Ambient = ogAmbient
			if roomAddedConnection then roomAddedConnection:Disconnect() roomAddedConnection = nil end
			for room, data in pairs(roomData) do
				if room and room.Parent then
					data.connection:Disconnect()
					if data.original then room:SetAttribute("Ambient", data.original) end
				end
			end
			roomData = {}
		end
	end
end

-- Door ESP
do
	local doorData = {}
	local workspaceConnection = nil

	local function cleanupDoor(part)
		if doorData[part] then
			if doorData[part].highlight and doorData[part].highlight.Parent then doorData[part].highlight:Destroy() end
			if doorData[part].billboard and doorData[part].billboard.Parent then doorData[part].billboard:Destroy() end
			if doorData[part].connection then doorData[part].connection:Disconnect() end
			doorData[part] = nil
		end
	end

	local function setupDoor(part)
		if not part or not part.Parent or not part:IsA("BasePart") or doorData[part] or not part.CanCollide then return end
		local model = part.Parent
		if not (model:IsA("Model") and model.Name == "Door") then return end
		local highlight = Instance.new("Highlight")
		highlight.Parent = part
		highlight.FillColor = Color3.fromRGB(0, 255, 0)
		highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		local doorText = "Door"
		local sign = model:FindFirstChild("Sign")
		if sign and sign:FindFirstChild("Stinker") and sign.Stinker:IsA("TextLabel") then doorText = "Door: " .. sign.Stinker.Text end
		local billboardGui = CreateBillboardGui({ Parent = part, Adornee = part, Text = doorText, TextColor = Color3.fromRGB(0, 255, 0) })
		local connection = part:GetPropertyChangedSignal("CanCollide"):Connect(function() if not part.CanCollide then cleanupDoor(part) end end)
		doorData[part] = { highlight = highlight, billboard = billboardGui, connection = connection }
		fadeIn(highlight)
		fadeIn(billboardGui)
	end

	Logic.DoorESP = function(enable: boolean)
		if enable then
			for _, d in ipairs(Workspace:GetDescendants()) do if d.Name == "Door" and d:IsA("BasePart") then setupDoor(d) end end
			workspaceConnection = Workspace.DescendantAdded:Connect(function(d) if d.Name == "Door" and d:IsA("BasePart") then task.wait() setupDoor(d) end end)
		else
			if workspaceConnection then workspaceConnection:Disconnect() workspaceConnection = nil end
			local toClean = {}
			for p in pairs(doorData) do table.insert(toClean, p) end
			for _, p in ipairs(toClean) do cleanupDoor(p) end
		end
	end
end

-- Monster ESP
do
	local monsterData = {}
	local workspaceConnection = nil

	local function cleanupMonster(part)
		if monsterData[part] then
			if part and part.Parent then part.Transparency = 1 end
			if monsterData[part].highlight then monsterData[part].highlight:Destroy() end
			if monsterData[part].billboard then monsterData[part].billboard:Destroy() end
			if monsterData[part].connection then monsterData[part].connection:Disconnect() end
			monsterData[part] = nil
		end
	end

	local function setupMonster(part)
		if not part or not part.Parent or not part:IsA("BasePart") or monsterData[part] then return end
		part.Transparency = 0
		local monsterText = "I dont know dude"
		if part.Parent.Name == "AmbushMoving" then monsterText = "Ambush" elseif part.Parent.Name == "RushMoving" then monsterText = "Rush" end
		local highlight = Instance.new("Highlight")
		highlight.Parent = part
		highlight.FillColor = Color3.fromRGB(255, 0, 0)
		highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		local billboardGui = CreateBillboardGui({ Parent = part, Adornee = part, Text = monsterText, TextColor = Color3.fromRGB(255, 0, 0) })
		local connection = part.AncestryChanged:Connect(function(_, parent) if parent == nil then cleanupMonster(part) end end)
		monsterData[part] = { highlight = highlight, billboard = billboardGui, connection = connection }
		fadeIn(highlight)
		fadeIn(billboardGui)
	end

	Logic.MonsterESP = function(enable: boolean)
		if enable then
			for _, d in ipairs(Workspace:GetDescendants()) do if d.Name == "RushNew" and d:IsA("BasePart") then setupMonster(d) end end
			workspaceConnection = Workspace.DescendantAdded:Connect(function(d) if d.Name == "RushNew" and d:IsA("BasePart") then task.wait() setupMonster(d) end end)
		else
			if workspaceConnection then workspaceConnection:Disconnect() workspaceConnection = nil end
			local toClean = {}
			for p in pairs(monsterData) do table.insert(toClean, p) end
			for _, p in ipairs(toClean) do cleanupMonster(p) end
		end
	end
end

-- ESP Factories
do
	-- for esp in a static folder (e.g. Drops)
	local function CreateStaticESPLogic(targetFolder: Instance, itemsToTrack: table)
		local trackedData = {}
		local connection = nil
		local function cleanup(model) if trackedData[model] then if trackedData[model].highlight and trackedData[model].highlight.Parent then trackedData[model].highlight:Destroy() end if trackedData[model].billboard and trackedData[model].billboard.Parent then trackedData[model].billboard:Destroy() end if trackedData[model].connection then trackedData[model].connection:Disconnect() end trackedData[model] = nil end end
		local function setup(model)
			if not model or not model:IsA("Model") or trackedData[model] or not model:IsDescendantOf(targetFolder) then return end
			local itemConfig = itemsToTrack[model.Name]
			if not itemConfig then return end
			local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
			if not firstPart then return end
			local highlight = Instance.new("Highlight")
			highlight.Parent, highlight.FillColor, highlight.OutlineColor, highlight.DepthMode = model, itemConfig.Color, itemConfig.Color, Enum.HighlightDepthMode.AlwaysOnTop
			local adornee = model.PrimaryPart or firstPart
			local espText = itemConfig.Text or model.Name
			local gui = CreateBillboardGui({ Parent = adornee, Adornee = adornee, Text = espText, TextColor = itemConfig.Color })
			local conn = model.AncestryChanged:Connect(function(_, p) if p == nil or not model:IsDescendantOf(targetFolder) then cleanup(model) end end)
			trackedData[model] = { highlight = highlight, billboard = gui, connection = conn }
			fadeIn(highlight)
			fadeIn(gui)
		end
		return function(enable: boolean)
			if enable then
				for _, d in ipairs(targetFolder:GetDescendants()) do if itemsToTrack[d.Name] and d:IsA("Model") then task.spawn(setup, d) end end
				connection = targetFolder.DescendantAdded:Connect(function(d) if itemsToTrack[d.Name] and d:IsA("Model") then task.wait() setup(d) end end)
			else
				if connection then connection:Disconnect() connection = nil end
				local toClean = {}
				for m in pairs(trackedData) do table.insert(toClean, m) end
				for _, m in ipairs(toClean) do cleanup(m) end
			end
		end
	end

	-- for esp that should only appear in the current room
	local function CreateCurrentRoomESPLogic(scanFolder: Instance, itemsToTrack: table)
		local masterList, visibleList = {}, {}
		local roomConn, descConn = nil, nil
		local function cleanup(model) if visibleList[model] then if visibleList[model].highlight and visibleList[model].highlight.Parent then visibleList[model].highlight:Destroy() end if visibleList[model].billboard and visibleList[model].billboard.Parent then visibleList[model].billboard:Destroy() end visibleList[model] = nil end end
		local function setup(model)
			if visibleList[model] then return end
			local itemConfig = itemsToTrack[model.Name]
			if not itemConfig then return end
			local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
			if not firstPart then return end
			local highlight = Instance.new("Highlight")
			highlight.Parent, highlight.FillColor, highlight.OutlineColor, highlight.DepthMode = model, itemConfig.Color, itemConfig.Color, Enum.HighlightDepthMode.AlwaysOnTop
			local adornee = model.PrimaryPart or firstPart
			local espText = itemConfig.Text or model.Name
			local gui = CreateBillboardGui({ Parent = adornee, Adornee = adornee, Text = espText, TextColor = itemConfig.Color })
			visibleList[model] = { highlight = highlight, billboard = gui }
			fadeIn(highlight)
			fadeIn(gui)
		end
		local function updateVisibility()
			local currentRoomModel = Common.GetCurrentRoomModel()
			for model, _ in pairs(masterList) do
				if model and model.Parent and currentRoomModel and model:IsDescendantOf(currentRoomModel) then setup(model) else cleanup(model) end
			end
		end
		return function(enable: boolean)
			if enable then
				for _, d in ipairs(scanFolder:GetDescendants()) do if itemsToTrack[d.Name] and d:IsA("Model") then masterList[d] = true end end
				descConn = scanFolder.DescendantAdded:Connect(function(d) if itemsToTrack[d.Name] and d:IsA("Model") then masterList[d] = true updateVisibility() end end)
				roomConn = Common.RoomChanged:Connect(updateVisibility)
				updateVisibility()
			else
				if roomConn then Common.RoomChanged:Disconnect(roomConn) roomConn = nil end
				if descConn then descConn:Disconnect() descConn = nil end
				for model, _ in pairs(visibleList) do cleanup(model) end
				masterList, visibleList = {}, {}
			end
		end
	end

	local items = { ["KeyObtain"] = { Color = Color3.fromRGB(255, 255, 0) }, ["Lighter"] = { Color = Color3.fromRGB(255, 165, 0) }, ["Flashlight"] = { Color = Color3.fromRGB(200, 200, 200) }, ["Vitamins"] = { Color = Color3.fromRGB(255, 105, 180) }, ["Bandage"] = { Color = Color3.fromRGB(255, 255, 255) }, ["Lockpicks"] = { Color = Color3.fromRGB(100, 100, 100) }, ["Candle"] = { Color = Color3.fromRGB(255, 250, 205) }, ["Battery"] = { Color = Color3.fromRGB(50, 205, 50) }, ["SkeletonKey"] = { Color = Color3.fromRGB(255, 255, 255), Text = "Skeleton Key" }, ["Crucifix"] = { Color = Color3.fromRGB(255, 165, 0), Text = "CRUCIFIX!!!!!" }, ["Smoothie"] = { Color = Color3.fromRGB(255, 250, 205) } }
	local hidingSpots = { ["Wardrobe"] = { Color = Color3.fromRGB(0, 150, 255) }, ["Locker"] = { Color = Color3.fromRGB(0, 150, 255) } }
	local books = { ["LiveHintBook"] = { Color = Color3.fromRGB(148, 0, 211), Text = "Book" } }
	local levers = { ["LeverForGate"] = { Color = Color3.fromRGB(128, 128, 128), Text = "Lever" } }

	Logic.ItemESP = CreateCurrentRoomESPLogic(Common.Rooms, items)
	Logic.DropsESP = CreateStaticESPLogic(Common.Drops, items)
	Logic.BookESP = CreateCurrentRoomESPLogic(Common.Rooms, books)
	Logic.HidingESP = CreateCurrentRoomESPLogic(Common.Rooms, hidingSpots)
	Logic.LeverESP = CreateCurrentRoomESPLogic(Common.Rooms, levers)
end

-- Anti-Screech
do
	Logic.AntiScreech = function(enable: boolean)
		local remote = Common.RemotesFolder:FindFirstChild(enable and "Screech" or "notscreech")
		if remote then remote.Name = enable and "notscreech" or "Screech" end
	end
end

-- Speed
do
	local player = Players.LocalPlayer
	local originalSpeed, speedEnabled, currentSpeed, speedConnection = 16, false, 16, nil
	local function updateSpeed() local char = player.Character if not char then return end local hum = char:FindFirstChildOfClass("Humanoid") if not hum then return end hum.WalkSpeed = speedEnabled and currentSpeed or originalSpeed end
	local function onCharacter(char)
		local hum = char:WaitForChild("Humanoid")
		originalSpeed = hum.WalkSpeed
		if speedConnection then speedConnection:Disconnect() end
		speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if speedEnabled and hum.WalkSpeed ~= currentSpeed then hum.WalkSpeed = currentSpeed end end)
		task.wait(0.1)
		updateSpeed()
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
	Logic.SetSpeed = function(enable: boolean) speedEnabled = enable updateSpeed() end
	Logic.SetSpeedValue = function(value: number) currentSpeed = value if speedEnabled then updateSpeed() end end
end

-- Instant Proximity Prompts
do
	local promptData, workspaceConnection = {}, nil
	local function cleanupPrompt(prompt) if promptData[prompt] and prompt and prompt.Parent then prompt.HoldDuration = promptData[prompt].originalDuration promptData[prompt] = nil end end
	local function setupPrompt(prompt) if not prompt or not prompt:IsA("ProximityPrompt") or promptData[prompt] then return end promptData[prompt] = { originalDuration = prompt.HoldDuration } prompt.HoldDuration = 0 end
	Logic.InstantPrompts = function(enable: boolean)
		if enable then
			for _, d in ipairs(Workspace:GetDescendants()) do if d:IsA("ProximityPrompt") then setupPrompt(d) end end
			workspaceConnection = Workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then setupPrompt(d) end end)
		else
			if workspaceConnection then workspaceConnection:Disconnect() workspaceConnection = nil end
			local toClean = {}
			for p in pairs(promptData) do table.insert(toClean, p) end
			for _, p in ipairs(toClean) do cleanupPrompt(p) end
		end
	end
end

-- Room Tracker
task.spawn(function()
	local trackedDoors = {}
	local function cleanupTrackerDoor(part) if trackedDoors[part] then trackedDoors[part].ancestryConn:Disconnect() trackedDoors[part].collideConn:Disconnect() trackedDoors[part] = nil end end
	local function setupTrackerDoor(part)
		if not (part.Name == "Door" and part:IsA("BasePart")) or trackedDoors[part] then return end
		local collideConn = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if not part.CanCollide then
				local sign = part.Parent and part.Parent:FindFirstChild("Sign")
				local stinker = sign and sign:FindFirstChild("Stinker")
				if stinker and stinker:IsA("TextLabel") then
					local roomNum = tonumber(stinker.Text)
					if roomNum and roomNum > Common.CurrentRoom then
						Common.CurrentRoom = roomNum
						print(SCRIPT_ID .. ": Entered room " .. roomNum)
						Common.RoomChanged:Fire()
					end
				end
			end
		end)
		local ancestryConn = part.AncestryChanged:Connect(function(_, parent) if parent == nil then cleanupTrackerDoor(part) end end)
		trackedDoors[part] = { collideConn = collideConn, ancestryConn = ancestryConn }
	end
	for _, d in ipairs(Workspace:GetDescendants()) do setupTrackerDoor(d) end
	Workspace.DescendantAdded:Connect(setupTrackerDoor)
end)

debugNotify("initialized Logic")


----------------------------------
--------------- UI ---------------
----------------------------------

-- Configure Obsidian
Obsidian.NotifyOnError = true
Obsidian.ForceCheckbox = false
Obsidian.ShowToggleFrameInKeybinds = true
Obsidian:OnUnload(function() print(SCRIPT_ID .. ": Unloaded!") end)
debugNotify("configured Obsidian")


-- Window
local Window = Obsidian:CreateWindow({ Title = "cooliopoolio47 hub", Footer = SCRIPT_ID, NotifySide = "Right", ShowCustomCursor = true, Center = true, AutoShow = true, ToggleKeybind = Enum.KeyCode.RightAlt })
debugNotify("created Window")


-- Tabs
local Tabs = { Main = Window:AddTab("Main", "user"), Visual = Window:AddTab("Visual", "eye"), Floor = Window:AddTab("Floor", "circle-question-mark"), UI_Settings = Window:AddTab("UI Settings", "settings") }
debugNotify("created Tabs")


-- Tabs.Main
do
	local AntiEntityGroupbox = Tabs.Main:AddLeftGroupbox("Anti-Entity", "eye")
	AntiEntityGroupbox:AddToggle("AntiScreech", { Text = "Anti-Screech", Default = false, Callback = function(v) Logic.AntiScreech(v) end })
	local PlayerGroupbox = Tabs.Main:AddLeftGroupbox("Player", "user")
	PlayerGroupbox:AddToggle("EnableSpeed", { Text = "Enable Speed", Default = false, Callback = function(v) Logic.SetSpeed(v) end })
	PlayerGroupbox:AddSlider("SpeedValue", { Text = "WalkSpeed", Default = 16, Min = 2, Max = 25, Rounding = 0, Callback = function(v) Logic.SetSpeedValue(v) end })
	PlayerGroupbox:AddToggle("InstantPrompts", { Text = "Instant Prompts", Default = false, Callback = function(v) Logic.InstantPrompts(v) end })
end
debugNotify("created Tabs.Main")


-- Tabs.Floor
do
	local BackdoorGroupbox = Tabs.Floor:AddLeftGroupbox("Backdoor", "circle-question-mark")
end
debugNotify("created Tabs.Floor")


-- Tabs.Visual
do
	local LightingGroupbox = Tabs.Visual:AddLeftGroupbox("Lighting", "zap")
	LightingGroupbox:AddToggle("Fullbright", { Text = "Fullbright", Default = false, Callback = function(v) Logic.Fullbright(v) end })
	local ESPGroupbox = Tabs.Visual:AddLeftGroupbox("ESP", "eye")
	ESPGroupbox:AddToggle("DoorESP", { Text = "Door ESP", Default = false, Callback = function(v) Logic.DoorESP(v) end })
	ESPGroupbox:AddToggle("MonsterESP", { Text = "Monster ESP", Default = false, Callback = function(v) Logic.MonsterESP(v) end })
	ESPGroupbox:AddToggle("ItemESP", { Text = "Item ESP", Default = false, Callback = function(v) Logic.ItemESP(v) end })
	ESPGroupbox:AddToggle("DropsESP", { Text = "Drops ESP", Default = false, Callback = function(v) Logic.DropsESP(v) end })
	ESPGroupbox:AddToggle("HidingESP", { Text = "Hiding Spot ESP", Default = false, Callback = function(v) Logic.HidingESP(v) end })
	ESPGroupbox:AddToggle("BookESP", { Text = "Book ESP", Default = false, Callback = function(v) Logic.BookESP(v) end })
	ESPGroupbox:AddToggle("LeverESP", { Text = "Lever ESP", Default = false, Callback = function(v) Logic.LeverESP(v) end })
end
debugNotify("created Tabs.Visual")


-- Tabs.UI_Settings
do
	local MenuGroup = Tabs.UI_Settings:AddLeftGroupbox("Menu", "wrench")
	MenuGroup:AddToggle("KeybindMenuOpen", { Default = Obsidian.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) Obsidian.KeybindFrame.Visible = v end })
	MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Default = true, Callback = function(v) Obsidian.ShowCustomCursor = v end })
	MenuGroup:AddDropdown("NotificationSide", { Values = { "Left", "Right" }, Default = "Right", Text = "Notification Side", Callback = function(v) Obsidian:SetNotifySide(v) end })
	MenuGroup:AddDropdown("DPIDropdown", { Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" }, Default = "100%", Text = "DPI Scale", Callback = function(v) v = v:gsub("%%", "") Obsidian:SetDPIScale(tonumber(v)) end })
	MenuGroup:AddDivider()
	MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
	Obsidian.ToggleKeybind = Obsidian.Options.MenuKeybind
	MenuGroup:AddButton("Unload", function() Obsidian:Unload() end)
end
debugNotify("created Tabs.UI_Settings")


-- SaveManager
SaveManager:SetLibrary(Obsidian)
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder(SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME)
SaveManager:SetSubFolder(SCRIPT_HUB_PLACE)
SaveManager:BuildConfigSection(Tabs.UI_Settings)
SaveManager:LoadAutoloadConfig()
debugNotify("initialized SaveManager")


-- Done!
debugNotify("loading complete!")
