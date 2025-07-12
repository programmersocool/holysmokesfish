if not game:IsLoaded() then game.Loaded:Wait() end

local SCRIPT_HUB_NAME = "cooliopoolio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "0.1.1" -- please use semver (https://semver.org/)
local SCRIPT_ID = SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME .. "/" .. SCRIPT_HUB_PLACE .. " v" .. SCRIPT_VERSION

-- Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Common Objects
local Common = {
	Rooms = workspace:WaitForChild("CurrentRooms"),
	Drops = workspace:WaitForChild("Drops"),
	RemotesFolder = ReplicatedStorage:WaitForChild("RemotesFolder"),
	GameData = ReplicatedStorage:WaitForChild("GameData")
}
-- helper function to get the current room model
function Common.GetCurrentRoom()
	local latestRoomName = tostring(Common.GameData.LatestRoom.Value)
	return Common.Rooms:FindFirstChild(latestRoomName)
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
	billboardGui.StudsOffset = options.StudsOffset or Vector3.new(0, 0, 0) -- default offset is now zero
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

	return billboardGui
end


-- Fullbright
do
	local ogBrightness = Lighting.Brightness
	local ogAmbient = Lighting.Ambient
	local originalRoomAmbients = {}
	local roomAddedConnection = nil

	local function setRoomFullbright(room)
		if room:IsA("Model") and not originalRoomAmbients[room] then
			originalRoomAmbients[room] = room:GetAttribute("Ambient")
			room:SetAttribute("Ambient", Color3.new(1, 1, 1))
		end
	end

	Logic.Fullbright = function(enable: boolean)
		if enable then
			Lighting.Brightness = 3
			Lighting.Ambient = Color3.new(1, 1, 1)
			for _, room in ipairs(Common.Rooms:GetChildren()) do
				setRoomFullbright(room)
			end
			roomAddedConnection = Common.Rooms.ChildAdded:Connect(setRoomFullbright)
		else
			Lighting.Brightness = ogBrightness
			Lighting.Ambient = ogAmbient
			if roomAddedConnection then
				roomAddedConnection:Disconnect()
				roomAddedConnection = nil
			end
			for room, originalAmbient in pairs(originalRoomAmbients) do
				if room and room.Parent and originalAmbient then
					room:SetAttribute("Ambient", originalAmbient)
				end
			end
			originalRoomAmbients = {}
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
		if sign and sign:FindFirstChild("Stinker") and sign.Stinker:IsA("TextLabel") then
			doorText = "Door: " .. sign.Stinker.Text
		end

		local billboardGui = CreateBillboardGui({ Parent = part, Adornee = part, Text = doorText, TextColor = Color3.fromRGB(0, 255, 0), StudsOffset = Vector3.new(0, 2.5, 0) })
		local connection = part:GetPropertyChangedSignal("CanCollide"):Connect(function() if not part.CanCollide then cleanupDoor(part) end end)
		doorData[part] = { highlight = highlight, billboard = billboardGui, connection = connection }
	end

	Logic.DoorESP = function(enable: boolean)
		if enable then
			for _, descendant in ipairs(Workspace:GetDescendants()) do if descendant.Name == "Door" and descendant:IsA("BasePart") then setupDoor(descendant) end end
			workspaceConnection = Workspace.DescendantAdded:Connect(function(descendant) if descendant.Name == "Door" and descendant:IsA("BasePart") then task.wait() setupDoor(descendant) end end)
		else
			if workspaceConnection then workspaceConnection:Disconnect() workspaceConnection = nil end
			local partsToClean = {}
			for part in pairs(doorData) do table.insert(partsToClean, part) end
			for _, part in ipairs(partsToClean) do cleanupDoor(part) end
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
	end

	Logic.MonsterESP = function(enable: boolean)
		if enable then
			for _, descendant in ipairs(Workspace:GetDescendants()) do if descendant.Name == "RushNew" and descendant:IsA("BasePart") then setupMonster(descendant) end end
			workspaceConnection = Workspace.DescendantAdded:Connect(function(descendant) if descendant.Name == "RushNew" and descendant:IsA("BasePart") then task.wait() setupMonster(descendant) end end)
		else
			if workspaceConnection then workspaceConnection:Disconnect() workspaceConnection = nil end
			local partsToClean = {}
			for part in pairs(monsterData) do table.insert(partsToClean, part) end
			for _, part in ipairs(partsToClean) do cleanupMonster(part) end
		end
	end
end

-- Generic Model ESP Factory (for Items, Drops, Hiding)
do
	local function CreateModelESPLogic(targetFolder: Instance, itemsToTrack: table)
		local trackedData = {}
		local connection = nil

		local function cleanup(model)
			if trackedData[model] then
				for _, h in ipairs(trackedData[model].highlights) do if h and h.Parent then h:Destroy() end end
				if trackedData[model].billboard and trackedData[model].billboard.Parent then trackedData[model].billboard:Destroy() end
				if trackedData[model].connection then trackedData[model].connection:Disconnect() end
				trackedData[model] = nil
			end
		end

		local function setup(model)
			if not model or not model:IsA("Model") or trackedData[model] then return end
			if not model:IsDescendantOf(targetFolder) then return end
			local itemConfig = itemsToTrack[model.Name]
			if not itemConfig then return end

			local highlights, firstPart = {}, nil
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					if not firstPart then firstPart = d end
					local h = Instance.new("Highlight")
					h.Parent, h.FillColor, h.OutlineColor, h.DepthMode = d, itemConfig.Color, itemConfig.Color, Enum.HighlightDepthMode.AlwaysOnTop
					table.insert(highlights, h)
				end
			end

			if #highlights == 0 then return end
			local adornee = model.PrimaryPart or firstPart
			local gui = CreateBillboardGui({ Parent = adornee, Adornee = adornee, Text = model.Name, TextColor = itemConfig.Color })
			local conn = model.AncestryChanged:Connect(function(_, p) if p == nil or not model:IsDescendantOf(targetFolder) then cleanup(model) end end)
			trackedData[model] = { highlights = highlights, billboard = gui, connection = conn }
		end

		return function(enable: boolean)
			if enable then
				for _, d in ipairs(targetFolder:GetDescendants()) do if itemsToTrack[d.Name] and d:IsA("Model") then setup(d) end end
				connection = targetFolder.DescendantAdded:Connect(function(d) if itemsToTrack[d.Name] and d:IsA("Model") then task.wait() setup(d) end end)
			else
				if connection then connection:Disconnect() connection = nil end
				local toClean = {}
				for m in pairs(trackedData) do table.insert(toClean, m) end
				for _, m in ipairs(toClean) do cleanup(m) end
			end
		end
	end

	local items = {
		["KeyObtain"] = { Color = Color3.fromRGB(255, 255, 0) },
		["Lighter"] = { Color = Color3.fromRGB(255, 165, 0) },
		["Flashlight"] = { Color = Color3.fromRGB(200, 200, 200) },
		["Vitamins"] = { Color = Color3.fromRGB(255, 105, 180) },
		["Bandage"] = { Color = Color3.fromRGB(255, 255, 255) },
	}
	local hidingSpots = {
		["Wardrobe"] = { Color = Color3.fromRGB(0, 150, 255) },
		["Locker"] = { Color = Color3.fromRGB(0, 150, 255) },
	}

	Logic.ItemESP = CreateModelESPLogic(Common.Rooms, items)
	Logic.DropsESP = CreateModelESPLogic(Common.Drops, items)
	Logic.HidingESP = CreateModelESPLogic(Workspace, hidingSpots)
end

-- Anti-Screech
do
	Logic.AntiScreech = function(enable: boolean)
		if enable then
			local remote = Common.RemotesFolder:FindFirstChild("Screech")
			if remote then remote.Name = "notscreech" end
		else
			local remote = Common.RemotesFolder:FindFirstChild("notscreech")
			if remote then remote.Name = "Screech" end
		end
	end
end

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
