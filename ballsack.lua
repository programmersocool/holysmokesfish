if not game:IsLoaded() then game.Loaded:Wait() end

local SCRIPT_HUB_NAME = "cooliopoolio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "0.0.5" -- please use semver (https://semver.org/)
local SCRIPT_ID = SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME .. "/" .. SCRIPT_HUB_PLACE .. " v" .. SCRIPT_VERSION

-- Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Common Objects
local Common = {
	Rooms = workspace:WaitForChild("CurrentRooms")
}


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
	billboardGui.StudsOffset = options.StudsOffset or Vector3.new(0, 2.5, 0) -- default offset
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
	Logic.Fullbright = function(enable: boolean)
		if enable then
			Lighting.Brightness = 3
			Lighting.Ambient = Color3.new(1,1,1)
		else
			Lighting.Brightness = ogBrightness
			Lighting.Ambient = ogAmbient
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

		-- door esp highlight
		local highlight = Instance.new("Highlight")
		highlight.Parent = part
		highlight.FillColor = Color3.fromRGB(0, 255, 0)
		highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		-- determine door text
		local doorText = "Door"
		local sign = model:FindFirstChild("Sign")
		if sign and sign:FindFirstChild("Stinker") and sign.Stinker:IsA("TextLabel") then
			doorText = "Door: " .. sign.Stinker.Text
		end

		-- door esp billboard gui using the new function
		local billboardGui = CreateBillboardGui({
			Parent = part,
			Adornee = part,
			Text = doorText,
			TextColor = Color3.fromRGB(0, 255, 0)
		})

		local connection = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if not part.CanCollide then
				cleanupDoor(part)
			end
		end)
		doorData[part] = {
			highlight = highlight,
			billboard = billboardGui,
			connection = connection
		}
	end

	Logic.DoorESP = function(enable: boolean)
		if enable then
			for _, descendant in ipairs(Workspace:GetDescendants()) do
				if descendant.Name == "Door" and descendant:IsA("BasePart") then
					setupDoor(descendant)
				end
			end

			workspaceConnection = Workspace.DescendantAdded:Connect(function(descendant)
				if descendant.Name == "Door" and descendant:IsA("BasePart") then
					task.wait()
					setupDoor(descendant)
				end
			end)
		else
			if workspaceConnection then
				workspaceConnection:Disconnect()
				workspaceConnection = nil
			end

			local partsToClean = {}
			for part in pairs(doorData) do
				table.insert(partsToClean, part)
			end
			for _, part in ipairs(partsToClean) do
				cleanupDoor(part)
			end
		end
	end
end

-- Monster ESP
do
	local monsterData = {}
	local workspaceConnection = nil

	local function cleanupMonster(part)
		if monsterData[part] then
			if part and part.Parent then
				part.Transparency = 1 -- restore transparency
			end
			if monsterData[part].highlight then monsterData[part].highlight:Destroy() end
			if monsterData[part].billboard then monsterData[part].billboard:Destroy() end
			if monsterData[part].connection then monsterData[part].connection:Disconnect() end
			monsterData[part] = nil
		end
	end

	local function setupMonster(part)
		if not part or not part.Parent or not part:IsA("BasePart") or monsterData[part] then return end

		part.Transparency = 0 -- set transparency

		-- determine monster text based on parent name
		local monsterText = "I dont know dude"
		if part.Parent.Name == "AmbushMoving" then
			monsterText = "Ambush"
		elseif part.Parent.Name == "RushMoving" then
			monsterText = "Rush"
		end

		-- monster esp highlight
		local highlight = Instance.new("Highlight")
		highlight.Parent = part
		highlight.FillColor = Color3.fromRGB(255, 0, 0)
		highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		-- monster esp billboard gui
		local billboardGui = CreateBillboardGui({
			Parent = part,
			Adornee = part,
			Text = monsterText,
			TextColor = Color3.fromRGB(255, 0, 0),
			StudsOffset = Vector3.new(0, 0, 0) -- no height offset
		})

		-- connection to clean up when monster is removed
		local connection = part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				cleanupMonster(part)
			end
		end)

		monsterData[part] = {
			highlight = highlight,
			billboard = billboardGui,
			connection = connection
		}
	end

	Logic.MonsterESP = function(enable: boolean)
		if enable then
			for _, descendant in ipairs(Workspace:GetDescendants()) do
				if descendant.Name == "RushNew" and descendant:IsA("BasePart") then
					setupMonster(descendant)
				end
			end

			workspaceConnection = Workspace.DescendantAdded:Connect(function(descendant)
				if descendant.Name == "RushNew" and descendant:IsA("BasePart") then
					task.wait() -- wait a frame to ensure it's fully initialized
					setupMonster(descendant)
				end
			end)
		else
			if workspaceConnection then
				workspaceConnection:Disconnect()
				workspaceConnection = nil
			end

			local partsToClean = {}
			for part in pairs(monsterData) do
				table.insert(partsToClean, part)
			end
			for _, part in ipairs(partsToClean) do
				cleanupMonster(part)
			end
		end
	end
end

-- Item ESP
do
	-- easy to add new items here
	local itemsToTrack = {
		["Key"] = { Color = Color3.fromRGB(255, 255, 0) },
	}

	local itemData = {}
	local workspaceConnection = nil

	local function cleanupItem(part)
		if itemData[part] then
			if itemData[part].highlight then itemData[part].highlight:Destroy() end
			if itemData[part].billboard then itemData[part].billboard:Destroy() end
			if itemData[part].connection then itemData[part].connection:Disconnect() end
			itemData[part] = nil
		end
	end

	local function setupItem(part)
		if not part or not part:IsA("BasePart") or itemData[part] then return end

		local itemConfig = itemsToTrack[part.Name]
		if not itemConfig then return end

		local highlight = Instance.new("Highlight")
		highlight.Parent = part
		highlight.FillColor = itemConfig.Color
		highlight.OutlineColor = itemConfig.Color
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

		local billboardGui = CreateBillboardGui({
			Parent = part,
			Adornee = part,
			Text = part.Name,
			TextColor = itemConfig.Color
		})

		local connection = part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				cleanupItem(part)
			end
		end)

		itemData[part] = {
			highlight = highlight,
			billboard = billboardGui,
			connection = connection
		}
	end

	Logic.ItemESP = function(enable: boolean)
		if enable then
			for _, descendant in ipairs(Workspace:GetDescendants()) do
				if itemsToTrack[descendant.Name] and descendant:IsA("BasePart") then
					setupItem(descendant)
				end
			end

			workspaceConnection = Workspace.DescendantAdded:Connect(function(descendant)
				if itemsToTrack[descendant.Name] and descendant:IsA("BasePart") then
					task.wait()
					setupItem(descendant)
				end
			end)
		else
			if workspaceConnection then
				workspaceConnection:Disconnect()
				workspaceConnection = nil
			end

			local partsToClean = {}
			for part in pairs(itemData) do
				table.insert(partsToClean, part)
			end
			for _, part in ipairs(partsToClean) do
				cleanupItem(part)
			end
		end
	end
end

debugNotify("initialized Logic")


----------------------------------
--------------- UI ---------------
----------------------------------

-- Configure Obsidian
Obsidian.NotifyOnError = true
Obsidian.ForceCheckbox = false -- Forces AddToggle to AddCheckbox
Obsidian.ShowToggleFrameInKeybinds = true -- Make toggle keybinds work inside the keybinds UI (aka adds a toggle to the UI). Good for mobile users (Default value = true)
Obsidian:OnUnload(function()
	print(SCRIPT_ID .. ": Unloaded!")
end)

debugNotify("configured Obsidian")


-- Window
local Window = Obsidian:CreateWindow({
	Title = "cooliopoolio47 hub",
	Footer = SCRIPT_ID,
	NotifySide = "Right",
	ShowCustomCursor = true,
	Center = true,
	AutoShow = true,
	ToggleKeybind = Enum.KeyCode.RightAlt,
})

debugNotify("created Window")


-- Tabs
local Tabs = {
	Main = Window:AddTab("Main", "user"),
	Visual = Window:AddTab("Visual", "eye"),
	Floor = Window:AddTab("Floor", "circle-question-mark"),
	UI_Settings = Window:AddTab("UI Settings", "settings"),
}

debugNotify("created Tabs")


-- Tabs.Main
do
	local AntiEntityGroupbox = Tabs.Main:AddLeftGroupbox("Anti-Entity", "eye")
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

	LightingGroupbox:AddToggle("Fullbright", {
		Text = "Fullbright",
		Default = false,
		Callback = function(value: boolean)
			Logic.Fullbright(value)
		end,
	})

	local ESPGroupbox = Tabs.Visual:AddLeftGroupbox("ESP", "eye")
	ESPGroupbox:AddToggle("DoorESP", {
		Text = "Door ESP",
		Default = false,
		Callback = function(value: boolean)
			Logic.DoorESP(value)
		end,
	})

	ESPGroupbox:AddToggle("MonsterESP", {
		Text = "Monster ESP",
		Default = false,
		Callback = function(value: boolean)
			Logic.MonsterESP(value)
		end,
	})

	ESPGroupbox:AddToggle("ItemESP", {
		Text = "Item ESP",
		Default = false,
		Callback = function(value: boolean)
			Logic.ItemESP(value)
		end,
	})
end

debugNotify("created Tabs.Visual")


-- Tabs.UI_Settings
do
	local MenuGroup = Tabs.UI_Settings:AddLeftGroupbox("Menu", "wrench")

	MenuGroup:AddToggle("KeybindMenuOpen", {
		Default = Obsidian.KeybindFrame.Visible,
		Text = "Open Keybind Menu",
		Callback = function(value: boolean)
			Obsidian.KeybindFrame.Visible = value
		end,
	})

	MenuGroup:AddToggle("ShowCustomCursor", {
		Text = "Custom Cursor",
		Default = true,
		Callback = function(value: boolean)
			Obsidian.ShowCustomCursor = value
		end,
	})

	MenuGroup:AddDropdown("NotificationSide", {
		Values = { "Left", "Right" },
		Default = "Right",

		Text = "Notification Side",

		Callback = function(value: string)
			Obsidian:SetNotifySide(value)
		end,
	})

	MenuGroup:AddDropdown("DPIDropdown", {
		Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
		Default = "100%",

		Text = "DPI Scale",

		Callback = function(value: string)
			value = value:gsub("%%", "")
			local DPI: number = tonumber(value)

			Obsidian:SetDPIScale(DPI)
		end,
	})

	MenuGroup:AddDivider()

	MenuGroup:AddLabel("Menu bind")
		:AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
	Obsidian.ToggleKeybind = Obsidian.Options.MenuKeybind

	MenuGroup:AddButton("Unload", function()
		Obsidian:Unload()
	end)
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
