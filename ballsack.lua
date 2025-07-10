if not game:IsLoaded() then game.Loaded:Wait() end

local SCRIPT_HUB_NAME = "bsdabsdbadspoolVDSADVASio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "0.0.1" -- please use semver (https://semver.org/)
local SCRIPT_ID = SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME .. "/" .. SCRIPT_HUB_PLACE .. " v" .. SCRIPT_VERSION

-- Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Common Objects
local Common = {
	Rooms = workspace:WaitForChild("CurrentRooms"),
	Remotes = ReplicatedStorage:WaitForChild("RemotesFolder"),
	GameData = ReplicatedStorage:WaitForChild("GameData"),
	Current_Room_Name = ReplicatedStorage:WaitForChild("GameData").LatestRoom.Value,
	Current_Room = nil
}

local function updatecurrentroom(newRoomName)
	if not newRoomName or newRoomName == "" then
		Common.Current_Room = nil
		return
	end
	local foundRoom = Common.Rooms:FindFirstChild(newRoomName)
	Common.Current_Room = foundRoom
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

-- Fullbright
do
	local fullbrightEnabled = false
	local originalLighting = {
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
		Technology = Lighting.Technology
	}

	local function updateRoomLighting(room)
		if not room or not fullbrightEnabled then return end

		-- Set attributes used by Doors for room ambient light
		room:SetAttribute("Ambient", Color3.fromRGB(255, 255, 255))
		room:SetAttribute("ColorShift_Top", Color3.fromRGB(255, 255, 255))

		-- Override lighting objects inside the room model
		for _, v in pairs(room:GetDescendants()) do
			if v:IsA("Lighting") then
				v.Ambient = Color3.new(1, 1, 1)
				v.Brightness = 3
			elseif v:IsA("Atmosphere") then
				v.Haze = 0
				v.Density = 0
			elseif v:IsA("ColorCorrectionEffect") then
				v.Enabled = false
			elseif v:IsA("Sky") then
				v.SkyboxBk = ""
				v.SkyboxDn = ""
				v.SkyboxFt = ""
				v.SkyboxLf = ""
				v.SkyboxRt = ""
				v.SkyboxUp = ""
			end
		end
	end

	Logic.Fullbright = function(enable: boolean)
		fullbrightEnabled = enable
		if enable then
			-- Apply global lighting changes
			Lighting.Brightness = 2
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
			Lighting.ColorShift_Top = Color3.new(1, 1, 1)
			
			-- Apply to all existing rooms
			for _, room in pairs(Common.Rooms:GetChildren()) do
				updateRoomLighting(room)
			end
		else
			-- Restore original global lighting
			Lighting.Brightness = originalLighting.Brightness
			Lighting.Ambient = originalLighting.Ambient
			Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
			Lighting.ColorShift_Top = originalLighting.ColorShift_Top
			-- Note: Re-enabling fullbright may be needed after moving to a new room to fully restore visuals,
			-- as the game's scripts will re-apply their own lighting.
		end
	end

	-- Connect to new rooms being added to apply fullbright automatically
	Common.Rooms.ChildAdded:Connect(updateRoomLighting)
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
	Title = "bsdabsdbadspoolio47 hub",
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

	BackdoorGroupbox:AddToggle("DisableHaste", {
		Text = "Disable Haste",
		Default = false,
		Disabled = true, -- Disabled until function is implemented
		
		Callback = function(value: boolean)
			-- Logic.DisableHaste(value) -- This function was not defined in your original script
		end,
	})
end

debugNotify("created Tabs.Floor")


-- Tabs.Visual
do
	local LightingGroupbox = Tabs.Visual:AddLeftGroupbox("Lighting", "circle-question-mark")

	LightingGroupbox:AddToggle("Fullbright", {
		Text = "Fullbright",
		Default = false,
		Callback = function(value: boolean)
			Logic.Fullbright(value)
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

Common.Current_Room_Name.Changed:Connect(updatecurrentroom)
updatecurrentroom(Common.Current_Room_Name.Value)

debugNotify("loading complete!")
