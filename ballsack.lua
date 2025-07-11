if not game:IsLoaded() then game.Loaded:Wait() end

local SCRIPT_HUB_NAME = "cooliopoolio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "0.0.1" -- please use semver (https://semver.org/)
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

do
	local connections = {}
	local highlights = {}
	local billboards = {}

	local function updateDoors()
		-- Clear previous billboards and highlights
		for _, billboard in pairs(billboards) do
			billboard:Destroy()
		end
		table.clear(billboards)

		for _, highlight in pairs(highlights) do
			highlight:Destroy()
		end
		table.clear(highlights)

		-- Find all doors and add new billboards and highlights
		for _, model in ipairs(Workspace:GetDescendants()) do
			if model:IsA("Model") and model.Name == "Door" then
				for _, part in ipairs(model:GetChildren()) do
					if part:IsA("BasePart") and part.Name == "Door" then
						-- Add Highlight
						local highlight = Instance.new("Highlight")
						highlight.Parent = part
						highlight.FillColor = Color3.fromRGB(0, 255, 0)
						highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
						table.insert(highlights, highlight)

						-- Add BillboardGui
						local billboardGui = Instance.new("BillboardGui")
						billboardGui.Parent = part
						billboardGui.Size = UDim2.new(0, 200, 0, 50)
						billboardGui.AlwaysOnTop = true
						billboardGui.Adornee = part

						local textLabel = Instance.new("TextLabel")
						textLabel.Parent = billboardGui
						textLabel.Size = UDim2.new(1, 0, 1, 0)
						textLabel.BackgroundTransparency = 1
						textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
						textLabel.TextScaled = true

						local sign = model:FindFirstChild("Sign")
						if sign and sign:FindFirstChild("Stinker") then
							textLabel.Text = "Door: " .. sign.Stinker.Text
						else
							textLabel.Text = "Door"
						end
						table.insert(billboards, billboardGui)
					end
				end
			end
		end
	end

	Logic.DoorESP = function(enable: boolean)
		if enable then
			if not game:IsLoaded() then
				game.Loaded:Wait()
			end
			-- Initial run
			updateDoors()

			-- Connect to update when new rooms are added
			local connection = Common.Rooms.ChildAdded:Connect(function()
				task.wait(1) -- Wait for the new room to fully load
				updateDoors()
			end)
			table.insert(connections, connection)
		else
			-- Disconnect all events
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			table.clear(connections)

			-- Clear billboards and highlights
			for _, billboard in pairs(billboards) do
				billboard:Destroy()
			end
			table.clear(billboards)

			for _, highlight in pairs(highlights) do
				highlight:Destroy()
			end
			table.clear(highlights)
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
