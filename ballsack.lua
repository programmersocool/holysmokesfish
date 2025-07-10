if not game:IsLoaded() then game.Loaded:Wait() end

local SCRIPT_HUB_NAME = "cooliopoolio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "0.0.1" -- please use semver (https://semver.org/)
local SCRIPT_ID = SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME .. "/" .. SCRIPT_HUB_PLACE .. " v" .. SCRIPT_VERSION

local Services = {
	Lighting = game:GetService("Lighting"),
}

-- https://github.com/deividcomsono/Obsidian/blob/main/README.md

local Obsidian: typeof(require(script:WaitForChild("Obsidian"))) = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()

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

do
	local ogBrightness = Services.Lighting.Brightness
	local ogAmbient = Services.Lighting.Ambient

	Logic.Fullbright = function(enable: boolean)
		if enable then
			while true do
			Services.Lighting.Brightness = 5
			Services.Lighting.Ambient = Color3.fromRGB(255,255,255)
			task.wait(0.2)
			end
		else
			Services.Lighting.Brightness = ogBrightness
			Services.Lighting.Ambient = ogAmbient
		end
	end
end

print("initialized Logic")


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
	-- Set Center to true if you want the menu to appear in the center
	-- Set AutoShow to true if you want the menu to appear when it is created
	-- Set Resizable to true if you want to have in-game resizable Window
	-- Set MobileButtonsSide to "Left" or "Right" if you want the ui toggle & lock buttons to be on the left or right side of the window
	-- Set ShowCustomCursor to false if you don't want to use the Linoria cursor
	-- NotifySide = Changes the side of the notifications (Left, Right) (Default value = Left)
	-- Position and Size are also valid options here
	-- but you do not need to define them unless you are changing them :)

	Title = "cooliopoolio47 hub",
	Footer = SCRIPT_ID,
	--Icon = 95816097006870,
	NotifySide = "Right",
	ShowCustomCursor = true,
})

debugNotify("created Window")


-- Tabs
-- You do not have to set your tabs & groups up this way, just a prefrence.
-- You can find more icons in https://lucide.dev/
local Tabs = {
	Main = Window:AddTab("Main", "user"),
	Visual = Window:AddTab("Visual", "eye"),
	UI_Settings = Window:AddTab("UI Settings", "settings"),
}

debugNotify("created Tabs")


-- Tabs.Main
do
	local LeftGroupbox = Tabs.Main:AddLeftGroupbox("Anti-Entity", "[ icon here ]")
end

-- Tabs.Visual
do
	local LeftGroupbox = Tabs.Visual:AddLeftGroupbox("Lighting", "[ icon here ]")

	LeftGroupbox:AddToggle("Fullbright", {
		Text = "Fullbright",

		Default = false, -- Default value (true / false)
		Disabled = false, -- Will disable the toggle (true / false)
		Visible = true, -- Will make the toggle invisible (true / false)
		Risky = false, -- Makes the text red (the color can be changed using Obsidian.Scheme.Red) (Default value = false)

		Callback = function(value: boolean)
			print("fullbright callback")
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

-- Adds our MenuKeybind to the ignore list
-- (do you want each config to have a different menu key? probably not.)
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

SaveManager:SetFolder(SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME)
SaveManager:SetSubFolder(SCRIPT_HUB_PLACE)

SaveManager:BuildConfigSection(Tabs.UI_Settings)

SaveManager:LoadAutoloadConfig()

debugNotify("initialized SaveManager")


-- Done!
debugNotify("loading complete!")
