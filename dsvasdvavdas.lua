if not game:IsLoaded() then
	game.Loaded:Wait()
end

local SCRIPT_HUB_NAME = "cooliopoolio47-hub"
local SCRIPT_HUB_GAME = "Doors"
local SCRIPT_HUB_PLACE = "Hotel"
local SCRIPT_VERSION = "6.7.6" -- please use semver (https://semver.org/)
local SCRIPT_ID = SCRIPT_HUB_NAME .. "/" .. SCRIPT_HUB_GAME .. "/" .. SCRIPT_HUB_PLACE .. " v" .. SCRIPT_VERSION

-- Services
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- thingyyyy
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
	RoomChanged = Signal.new(),
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
local ActiveESPs = {}
local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

-- fade-in/out effects for esp elements
local function tweenInstance(instance, out)
	local onComplete = out and function()
		instance:Destroy()
	end or nil
	if instance:IsA("Highlight") then
		local goal = { FillTransparency = out and 1 or 0.5, OutlineTransparency = out and 1 or 0 }
		if not out then
			instance.FillTransparency, instance.OutlineTransparency = 1, 1
		end
		local tween = TweenService:Create(instance, TWEEN_INFO, goal)
		if onComplete then
			tween.Completed:Connect(onComplete)
		end
		tween:Play()
	elseif instance:IsA("BillboardGui") then
		local labels, strokes = {}, {}
		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("TextLabel") then
				table.insert(labels, child)
				local stroke = child:FindFirstChildOfClass("UIStroke")
				if stroke then
					table.insert(strokes, stroke)
				end
			end
		end
		for i, label in ipairs(labels) do
			local textGoal = { TextTransparency = out and 1 or 0 }
			if not out then
				label.TextTransparency = 1
			end
			local textTween = TweenService:Create(label, TWEEN_INFO, textGoal)
			if out and i == #labels and onComplete then
				textTween.Completed:Connect(onComplete)
			end
			textTween:Play()
		end
		for _, stroke in ipairs(strokes) do
			local strokeGoal = { Transparency = out and 1 or 0 }
			if not out then
				stroke.Transparency = 1
			end
			TweenService:Create(stroke, TWEEN_INFO, strokeGoal):Play()
		end
	end
end

-- a reusable function to create billboard guis for esp
local function CreateBillboardGui(options: { Parent: Instance, Adornee: BasePart, Text: string, TextColor: Color3, StudsOffset: Vector3? })
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 200, 0, 70)
	billboardGui.AlwaysOnTop = true
	billboardGui.StudsOffset = options.StudsOffset or Vector3.new(0, 0, 0)
	billboardGui.Adornee = options.Adornee
	billboardGui.Parent = options.Parent
	local listLayout = Instance.new("UIListLayout")
	listLayout.Parent, listLayout.SortOrder, listLayout.HorizontalAlignment = billboardGui, Enum.SortOrder.LayoutOrder, Enum.HorizontalAlignment.Center
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size, nameLabel.BackgroundTransparency, nameLabel.TextScaled, nameLabel.Font, nameLabel.Text, nameLabel.TextColor3, nameLabel.Parent = UDim2.new(1, 0, 0, 30), 1, true, Enum.Font.SourceSansBold, options.Text, options.TextColor, billboardGui
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color, nameStroke.Thickness, nameStroke.Parent = Color3.new(0, 0, 0), 1, nameLabel
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Size, distanceLabel.BackgroundTransparency, distanceLabel.TextScaled, distanceLabel.Font, distanceLabel.Text, distanceLabel.TextColor3, distanceLabel.Parent = UDim2.new(1, 0, 0, 20), 1, true, Enum.Font.SourceSans, "[...]", options.TextColor, billboardGui
	local distStroke = Instance.new("UIStroke")
	distStroke.Color, distStroke.Thickness, distStroke.Parent = Color3.new(0, 0, 0), 1, distanceLabel
	return { gui = billboardGui, nameLabel = nameLabel, distanceLabel = distanceLabel }
end


-- Fullbright
do
	local ogBrightness, ogAmbient, roomData, roomAddedConnection, fullbrightEnabled = Lighting.Brightness, Lighting.Ambient, {}, nil, false
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
			Lighting.Brightness, Lighting.Ambient = 3, Color3.new(1, 1, 1)
			for _, room in ipairs(Common.Rooms:GetChildren()) do
				setRoomFullbright(room)
			end
			roomAddedConnection = Common.Rooms.ChildAdded:Connect(setRoomFullbright)
		else
			Lighting.Brightness, Lighting.Ambient = ogBrightness, ogAmbient
			if roomAddedConnection then
				roomAddedConnection:Disconnect()
				roomAddedConnection = nil
			end
			for room, data in pairs(roomData) do
				if room and room.Parent then
					data.connection:Disconnect()
					if data.original then
						room:SetAttribute("Ambient", data.original)
					end
				end
			end
			roomData = {}
		end
	end
end

-- Door ESP
do
	local doorData, roomConn = {}, nil
	local function cleanupDoor(part)
		if doorData[part] then
			tweenInstance(doorData[part].highlight, true)
			tweenInstance(doorData[part].billboard, true)
			ActiveESPs[part] = nil
			doorData[part] = nil
		end
	end
	local function setupDoor(part)
		if not part or not part.Parent or not part:IsA("BasePart") or doorData[part] or not part.CanCollide then
			return
		end
		local model = part.Parent
		if not (model:IsA("Model") and model.Name == "Door") then
			return
		end
		local highlight = Instance.new("Highlight")
		highlight.Parent, highlight.FillColor, highlight.OutlineColor, highlight.DepthMode, highlight.FillTransparency = part, Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 255, 0), Enum.HighlightDepthMode.AlwaysOnTop, 0.5
		local doorText = "Door"
		local sign = model:FindFirstChild("Sign")
		if sign and sign:FindFirstChild("Stinker") and sign.Stinker:IsA("TextLabel") then
			doorText = "Door: " .. sign.Stinker.Text
		end
		local guiElements = CreateBillboardGui({ Parent = part, Adornee = part, Text = doorText, TextColor = Color3.fromRGB(0, 255, 0) })
		doorData[part] = { highlight = highlight, billboard = guiElements.gui }
		ActiveESPs[part] = { adornee = part, distanceLabel = guiElements.distanceLabel }
		tweenInstance(highlight, false)
		tweenInstance(guiElements.gui, false)
	end
	local function updateDoors()
		for part, _ in pairs(doorData) do
			cleanupDoor(part)
		end
		for _, d in ipairs(Common.Rooms:GetDescendants()) do -- more performant search
			if d.Name == "Door" and d:IsA("BasePart") then
				local sign = d.Parent and d.Parent:FindFirstChild("Sign")
				if sign and sign:FindFirstChild("Stinker") and sign.Stinker:IsA("TextLabel") then
					local num = tonumber(sign.Stinker.Text)
					if num and (num == Common.CurrentRoom or num == Common.CurrentRoom + 1) then
						setupDoor(d)
					end
				end
			end
		end
	end
	Logic.DoorESP = function(enable: boolean)
		if enable then
			roomConn = Common.RoomChanged:Connect(updateDoors)
			updateDoors()
		else
			if roomConn then
				Common.RoomChanged:Disconnect(roomConn)
				roomConn = nil
			end
			for p, _ in pairs(doorData) do
				cleanupDoor(p)
			end
		end
	end
end

-- Monster ESP & Alerts
do
	local monsterData, workspaceConnection = {}, nil
	local alertEnabled = false
	local selectedEntities = { Rush = true, Ambush = true, Eyes = true }

	Logic.SetMonsterAlert = function(enable)
		alertEnabled = enable
	end
	Logic.SetAlertEntities = function(entities)
		selectedEntities = {}
		for _, entity in ipairs(entities) do
			selectedEntities[entity] = true
		end
	end

	local function cleanupMonster(entity)
		if monsterData[entity] then
			if entity:IsA("BasePart") then entity.Transparency = 1 end
			tweenInstance(monsterData[entity].highlight, true)
			tweenInstance(monsterData[entity].billboard, true)
			if monsterData[entity].connection then monsterData[entity].connection:Disconnect() end
			ActiveESPs[entity] = nil
			monsterData[entity] = nil
		end
	end

	local function setupMonster(entity)
		if not entity or not entity.Parent or monsterData[entity] then return end

		local monsterText, highlightPart, adorneePart
		if entity:IsA("BasePart") and entity.Name == "RushNew" then
			highlightPart = entity
			adorneePart = entity
			if entity.Parent.Name == "AmbushMoving" then
				monsterText = "Ambush"
			elseif entity.Parent.Name == "RushMoving" then
				monsterText = "Rush"
			end
			highlightPart.Transparency = 0
		elseif entity:IsA("Model") and entity.Name == "Eyes" then
			highlightPart = entity.Core
			adorneePart = entity.Core
			monsterText = "Eyes"
		end

		if not (monsterText and highlightPart and adorneePart) then return end

		if alertEnabled and selectedEntities[monsterText] then
			debugNotify("ALERT: " .. monsterText .. " is active!")
		end

		local highlight = Instance.new("Highlight")
		highlight.Parent, highlight.FillColor, highlight.OutlineColor, highlight.DepthMode, highlight.FillTransparency = highlightPart, Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 0, 0), Enum.HighlightDepthMode.AlwaysOnTop, 0.5
		local guiElements = CreateBillboardGui({ Parent = adorneePart, Adornee = adorneePart, Text = monsterText, TextColor = Color3.fromRGB(255, 0, 0) })
		local connection = entity.AncestryChanged:Connect(function(_, parent)
			if parent == nil then cleanupMonster(entity) end
		end)
		monsterData[entity] = { highlight = highlight, billboard = guiElements.gui, connection = connection }
		ActiveESPs[entity] = { adornee = highlightPart, distanceLabel = guiElements.distanceLabel }
		tweenInstance(highlight, false)
		tweenInstance(guiElements.gui, false)
	end

	Logic.MonsterESP = function(enable: boolean)
		if enable then
			for _, d in ipairs(Workspace:GetDescendants()) do
				if (d:IsA("BasePart") and d.Name == "RushNew") or (d:IsA("Model") and d.Name == "Eyes") then
					setupMonster(d)
				end
			end
			workspaceConnection = Workspace.DescendantAdded:Connect(function(d)
				if (d:IsA("BasePart") and d.Name == "RushNew") or (d:IsA("Model") and d.Name == "Eyes") then
					task.wait()
					setupMonster(d)
				end
			end)
		else
			if workspaceConnection then
				workspaceConnection:Disconnect()
				workspaceConnection = nil
			end
			for p, _ in pairs(monsterData) do cleanupMonster(p) end
		end
	end
end

-- ESP Factories
do
	local function CreateESPLogic(scanFolder: Instance, itemsToTrack: table, isRoomSpecific: boolean)
		local masterList, visibleList, roomConn, descConn = {}, {}, nil, nil
		local function cleanup(model)
			if visibleList[model] then
				tweenInstance(visibleList[model].highlight, true)
				tweenInstance(visibleList[model].billboard, true)
				ActiveESPs[model] = nil
				visibleList[model] = nil
			end
		end
		local function setup(model)
			if visibleList[model] then
				return
			end
			local itemConfig = itemsToTrack[model.Name]
			if not itemConfig then
				return
			end
			local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
			if not firstPart then
				return
			end
			local highlight = Instance.new("Highlight")
			highlight.Parent, highlight.FillColor, highlight.OutlineColor, highlight.DepthMode, highlight.FillTransparency = model, itemConfig.Color, itemConfig.Color, Enum.HighlightDepthMode.AlwaysOnTop, 0.5
			local adornee = model.PrimaryPart or firstPart
			local espText
			if itemConfig.TextGenerator then
				espText = itemConfig.TextGenerator(model)
			else
				espText = itemConfig.Text or model.Name
			end
			local guiElements = CreateBillboardGui({ Parent = adornee, Adornee = adornee, Text = espText, TextColor = itemConfig.Color })
			visibleList[model] = { highlight = highlight, billboard = guiElements.gui }
			ActiveESPs[model] = { adornee = adornee, distanceLabel = guiElements.distanceLabel }
			tweenInstance(highlight, false)
			tweenInstance(guiElements.gui, false)
		end
		local function updateVisibility()
			local currentRoomModel = Common.GetCurrentRoomModel()
			for model, _ in pairs(masterList) do
				if model and model.Parent and currentRoomModel and model:IsDescendantOf(currentRoomModel) then
					setup(model)
				else
					cleanup(model)
				end
			end
		end
		return function(enable: boolean)
			if enable then
				for _, d in ipairs(scanFolder:GetDescendants()) do
					if itemsToTrack[d.Name] and d:IsA("Model") then
						if isRoomSpecific then
							masterList[d] = true
						else
							setup(d)
						end
					end
				end
				descConn = scanFolder.DescendantAdded:Connect(function(d)
					if itemsToTrack[d.Name] and d:IsA("Model") then
						if isRoomSpecific then
							masterList[d] = true
							updateVisibility()
						else
							setup(d)
						end
					end
				end)
				if isRoomSpecific then
					roomConn = Common.RoomChanged:Connect(updateVisibility)
					updateVisibility()
				end
			else
				if roomConn then
					Common.RoomChanged:Disconnect(roomConn)
					roomConn = nil
				end
				if descConn then
					descConn:Disconnect()
					descConn = nil
				end
				for model, _ in pairs(visibleList) do
					cleanup(model)
				end
				masterList, visibleList = {}, {}
			end
		end
	end
	local items = { ["KeyObtain"] = { Color = Color3.fromRGB(255, 255, 0) }, ["Lighter"] = { Color = Color3.fromRGB(255, 165, 0) }, ["Flashlight"] = { Color = Color3.fromRGB(200, 200, 200) }, ["Vitamins"] = { Color = Color3.fromRGB(255, 105, 180) }, ["Bandage"] = { Color = Color3.fromRGB(255, 255, 255) }, ["Lockpicks"] = { Color = Color3.fromRGB(100, 100, 100) }, ["Candle"] = { Color = Color3.fromRGB(255, 250, 205) }, ["Battery"] = { Color = Color3.fromRGB(50, 205, 50) }, ["SkeletonKey"] = { Color = Color3.fromRGB(255, 255, 255), Text = "Skeleton Key" }, ["Crucifix"] = { Color = Color3.fromRGB(255, 165, 0), Text = "CRUCIFIX!!!!!" }, ["Smoothie"] = { Color = Color3.fromRGB(255, 250, 205) } }
	local hidingSpots = { ["Wardrobe"] = { Color = Color3.fromRGB(0, 150, 255) }, ["Locker"] = { Color = Color3.fromRGB(0, 150, 255) } }
	local objectives = { ["LiveHintBook"] = { Color = Color3.fromRGB(148, 0, 211), Text = "Book" }, ["LiveBreakerPolePickup"] = { Color = Color3.fromRGB(150, 150, 150), Text = "Breaker" } }
	local levers = { ["LeverForGate"] = { Color = Color3.fromRGB(128, 128, 128), Text = "Lever" } }
	local goldItems = { ["GoldPile"] = { Color = Color3.fromRGB(255, 255, 0), TextGenerator = function(model)
		return "Gold: " .. tostring(model:GetAttribute("GoldValue") or 0)
	end } }
	Logic.ItemESP = CreateESPLogic(Common.Rooms, items, false)
	Logic.DropsESP = CreateESPLogic(Common.Drops, items, false)
	Logic.ObjectivesESP = CreateESPLogic(Common.Rooms, objectives, true)
	Logic.HidingESP = CreateESPLogic(Common.Rooms, hidingSpots, true)
	Logic.LeverESP = CreateESPLogic(Common.Rooms, levers, true)
	Logic.GoldESP = CreateESPLogic(Common.Rooms, goldItems, false)
end

-- Anti-Screech, Speed, Prompts, FOV, Animation
do
	Logic.AntiScreech = function(enable: boolean)
		local r = Common.RemotesFolder:FindFirstChild(enable and "Screech" or "notscreech")
		if r then
			r.Name = enable and "notscreech" or "Screech"
		end
	end
	local player = Players.LocalPlayer
	local originalSpeed, speedEnabled, currentSpeed, speedConn = 16, false, 16, nil
	local twerkEnabled, twerkAnimTrack = false, nil
	local TWERK_ANIM_ID = "rbxassetid://12874447851"
	local autoInteractEnabled, autoInteractTarget, autoInteractConn = false, "Gold", nil

	local function stopTwerk()
		if twerkAnimTrack then
			twerkAnimTrack:Stop()
			twerkAnimTrack:Destroy()
			twerkAnimTrack = nil
		end
	end

	local function playTwerk()
		stopTwerk()
		local char = player.Character
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then return end
		local anim = Instance.new("Animation")
		anim.AnimationId = TWERK_ANIM_ID
		twerkAnimTrack = animator:LoadAnimation(anim)
		twerkAnimTrack.Looped = true
		twerkAnimTrack:Play()
		anim:Destroy()
	end

	local function updateSpeed()
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		hum.WalkSpeed = speedEnabled and currentSpeed or originalSpeed
	end

	local function onCharacter(char)
		local hum = char:WaitForChild("Humanoid")
		originalSpeed = hum.WalkSpeed
		if speedConn then speedConn:Disconnect() end
		speedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if speedEnabled and hum.WalkSpeed ~= currentSpeed then
				hum.WalkSpeed = currentSpeed
			end
		end)
		task.wait(0.1)
		updateSpeed()
		if twerkEnabled then
			playTwerk()
		end
	end

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(stopTwerk)
	if player.Character then onCharacter(player.Character) end

	Logic.SetSpeed = function(enable: boolean)
		speedEnabled = enable
		updateSpeed()
	end
	Logic.SetSpeedValue = function(value: number)
		currentSpeed = value
		if speedEnabled then updateSpeed() end
	end
	Logic.Twerk = function(enable: boolean)
		twerkEnabled = enable
		if enable then
			playTwerk()
		else
			stopTwerk()
		end
	end

	local promptData, promptConns = {}, {}
	local function cleanupPrompt(p)
		if promptData[p] and p and p.Parent then
			p.HoldDuration = promptData[p].originalDuration
			promptData[p] = nil
		end
	end
	local function setupPrompt(p)
		if not p or not p:IsA("ProximityPrompt") or promptData[p] then return end
		promptData[p] = { originalDuration = p.HoldDuration }
		p.HoldDuration = 0
	end
	Logic.InstantPrompts = function(enable: boolean)
		if enable then
			for _, container in ipairs({ Common.Rooms, Common.Drops }) do
				for _, d in ipairs(container:GetDescendants()) do
					if d:IsA("ProximityPrompt") then setupPrompt(d) end
				end
				local conn = container.DescendantAdded:Connect(function(d)
					if d:IsA("ProximityPrompt") then setupPrompt(d) end
				end)
				table.insert(promptConns, conn)
			end
		else
			for _, conn in ipairs(promptConns) do conn:Disconnect() end
			promptConns = {}
			local toClean = {}
			for p in pairs(promptData) do table.insert(toClean, p) end
			for _, p in ipairs(toClean) do cleanupPrompt(p) end
		end
	end

	local clipData, clipConns = {}, {}
	local function cleanupClip(p)
		if clipData[p] and p and p.Parent then
			p.RequiresLineOfSight = clipData[p].originalLineOfSight
			clipData[p] = nil
		end
	end
	local function setupClip(p)
		if not p or not p:IsA("ProximityPrompt") or clipData[p] then return end
		clipData[p] = { originalLineOfSight = p.RequiresLineOfSight }
		p.RequiresLineOfSight = false
	end
	Logic.ClipPrompts = function(enable: boolean)
		if enable then
			for _, container in ipairs({ Common.Rooms, Common.Drops }) do
				for _, d in ipairs(container:GetDescendants()) do
					if d:IsA("ProximityPrompt") then setupClip(d) end
				end
				local conn = container.DescendantAdded:Connect(function(d)
					if d:IsA("ProximityPrompt") then setupClip(d) end
				end)
				table.insert(clipConns, conn)
			end
		else
			for _, conn in ipairs(clipConns) do conn:Disconnect() end
			clipConns = {}
			local toClean = {}
			for p in pairs(clipData) do table.insert(toClean, p) end
			for _, p in ipairs(toClean) do cleanupClip(p) end
		end
	end

	local allItemNames = { ["KeyObtain"] = true, ["Lighter"] = true, ["Flashlight"] = true, ["Vitamins"] = true, ["Bandage"] = true, ["Lockpicks"] = true, ["Candle"] = true, ["Battery"] = true, ["SkeletonKey"] = true, ["Crucifix"] = true, ["Smoothie"] = true, ["GoldPile"] = true }
	local function onPromptShown(prompt)
		if not (prompt and prompt.Parent and prompt.Parent:IsA("Model")) then return end

		local modelName = prompt.Parent.Name
		local shouldTrigger = false

		if autoInteractTarget == "All Items" then
			if allItemNames[modelName] then shouldTrigger = true end
		elseif autoInteractTarget == "Keys" then
			if modelName == "KeyObtain" or modelName == "SkeletonKey" then shouldTrigger = true end
		elseif autoInteractTarget == "Gold" then
			if modelName == "GoldPile" then shouldTrigger = true end
		end

		if shouldTrigger then
			prompt:InputHoldBegin()
		end
	end
	Logic.SetAutoInteract = function(enable)
		autoInteractEnabled = enable
		if enable then
			if not autoInteractConn then
				autoInteractConn = ProximityPromptService.PromptShown:Connect(onPromptShown)
			end
		else
			if autoInteractConn then
				autoInteractConn:Disconnect()
				autoInteractConn = nil
			end
		end
	end
	Logic.SetAutoInteractTarget = function(target)
		autoInteractTarget = target
	end

	local originalFOV = workspace.CurrentCamera.FieldOfView
	Logic.SetFOV = function(v) workspace.CurrentCamera.FieldOfView = v end
	Obsidian:OnUnload(function() workspace.CurrentCamera.FieldOfView = originalFOV end)
end

-- room and ESP distance tracker
task.spawn(function()
	local trackedDoors = {}
	local function cleanupTrackerDoor(part)
		if trackedDoors[part] then
			trackedDoors[part].ancestryConn:Disconnect()
			trackedDoors[part].collideConn:Disconnect()
			trackedDoors[part] = nil
		end
	end
	local function setupTrackerDoor(part)
		if not (part.Name == "Door" and part:IsA("BasePart")) or trackedDoors[part] then
			return
		end
		local collideConn = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
			if not part.CanCollide then
				local sign = part.Parent and part.Parent:FindFirstChild("Sign")
				local stinker = sign and sign:FindFirstChild("Stinker")
				if stinker and stinker:IsA("TextLabel") then
					local roomNum = tonumber(stinker.Text)
					if roomNum and roomNum > Common.CurrentRoom then
						Common.CurrentRoom = roomNum
						print(SCRIPT_ID .. ": freaking entered room " .. roomNum)
						Common.RoomChanged:Fire()
					end
				end
			end
		end)
		local ancestryConn = part.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				cleanupTrackerDoor(part)
			end
		end)
		trackedDoors[part] = { collideConn = collideConn, ancestryConn = ancestryConn }
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		setupTrackerDoor(d)
	end
	Workspace.DescendantAdded:Connect(setupTrackerDoor)
	RunService.RenderStepped:Connect(function()
		local playerChar = Players.LocalPlayer.Character
		if not playerChar or not playerChar.PrimaryPart then return end
		local playerPos = playerChar.PrimaryPart.Position
		for espKey, esp in pairs(ActiveESPs) do
			if esp.adornee and esp.adornee.Parent then
				local adorneePos
				if esp.adornee:IsA("BasePart") then
					adorneePos = esp.adornee.Position
				elseif esp.adornee:IsA("Model") then
					adorneePos = esp.adornee:GetPivot().Position
				end

				if adorneePos then
					local dist = math.round((playerPos - adorneePos).Magnitude)
					esp.distanceLabel.Text = "[" .. dist .. " studs]"
				end
			end
		end
	end)
end)

debugNotify("initialized Logic")


----------------------------------
--------------- UI ---------------
----------------------------------

-- Configure Obsidian
Obsidian.NotifyOnError = true
Obsidian.ForceCheckbox = false
Obsidian.ShowToggleFrameInKeybinds = true
Obsidian:OnUnload(function()
	print(SCRIPT_ID .. ": Unloaded!")
end)
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
	AntiEntityGroupbox:AddToggle("AntiScreech", { Text = "Anti-Screech", Default = false, Callback = function(v)
		Logic.AntiScreech(v)
	end })
	AntiEntityGroupbox:AddToggle("MonsterAlert", { Text = "Monster Alert", Default = false, Callback = function(v)
		Logic.SetMonsterAlert(v)
	end })
	AntiEntityGroupbox:AddDropdown("AlertEntities", {
		Text = "Alert Entities",
		Values = { "Rush", "Ambush", "Eyes" },
		Default = { "Rush", "Ambush", "Eyes" },
		Multi = true,
		Callback = function(v)
			Logic.SetAlertEntities(v)
		end,
	})

	local PlayerGroupbox = Tabs.Main:AddLeftGroupbox("Player", "user")
	PlayerGroupbox:AddToggle("EnableSpeed", { Text = "Enable Speed", Default = false, Callback = function(v)
		Logic.SetSpeed(v)
	end })
	PlayerGroupbox:AddSlider("SpeedValue", { Text = "WalkSpeed", Default = 16, Min = 2, Max = 25, Rounding = 0, Callback = function(v)
		Logic.SetSpeedValue(v)
	end })
	PlayerGroupbox:AddToggle("InstantPrompts", { Text = "Instant Prompts", Default = false, Callback = function(v)
		Logic.InstantPrompts(v)
	end })
	PlayerGroupbox:AddToggle("ClipPrompts", { Text = "Clip Prompts", Default = false, Callback = function(v)
		Logic.ClipPrompts(v)
	end })
	PlayerGroupbox:AddToggle("Twerk", { Text = "Twerk", Default = false, Callback = function(v)
		Logic.Twerk(v)
	end })
	PlayerGroupbox:AddToggle("AutoInteract", { Text = "Auto Interact", Default = false, Callback = function(v)
		Logic.SetAutoInteract(v)
	end })
	PlayerGroupbox:AddDropdown("AutoInteractTarget", { Values = { "Gold", "Keys", "All Items" }, Default = "Gold", Text = "Interact Target", Callback = function(v)
		Logic.SetAutoInteractTarget(v)
	end })
	PlayerGroupbox:AddSlider("FOVValue", { Text = "Field of View", Default = 70, Min = 30, Max = 120, Rounding = 0, Callback = function(v)
		Logic.SetFOV(v)
	end })
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
	LightingGroupbox:AddToggle("Fullbright", { Text = "Fullbright", Default = false, Callback = function(v)
		Logic.Fullbright(v)
	end })
	local ESPGroupbox = Tabs.Visual:AddLeftGroupbox("ESP", "eye")
	ESPGroupbox:AddToggle("DoorESP", { Text = "Door ESP", Default = false, Callback = function(v)
		Logic.DoorESP(v)
	end })
	ESPGroupbox:AddToggle("MonsterESP", { Text = "Monster ESP", Default = false, Callback = function(v)
		Logic.MonsterESP(v)
	end })
	ESPGroupbox:AddToggle("ItemESP", { Text = "Item ESP", Default = false, Callback = function(v)
		Logic.ItemESP(v)
	end })
	ESPGroupbox:AddToggle("DropsESP", { Text = "Drops ESP", Default = false, Callback = function(v)
		Logic.DropsESP(v)
	end })
	ESPGroupbox:AddToggle("GoldESP", { Text = "Gold ESP", Default = false, Callback = function(v)
		Logic.GoldESP(v)
	end })
	ESPGroupbox:AddToggle("HidingESP", { Text = "Hiding Spot ESP", Default = false, Callback = function(v)
		Logic.HidingESP(v)
	end })
	ESPGroupbox:AddToggle("ObjectivesESP", { Text = "Objective ESP", Default = false, Callback = function(v)
		Logic.ObjectivesESP(v)
	end })
	ESPGroupbox:AddToggle("LeverESP", { Text = "Lever ESP", Default = false, Callback = function(v)
		Logic.LeverESP(v)
	end })
end
debugNotify("created Tabs.Visual")


-- Tabs.UI_Settings
do
	local MenuGroup = Tabs.UI_Settings:AddLeftGroupbox("Menu", "wrench")
	MenuGroup:AddToggle("KeybindMenuOpen", { Default = Obsidian.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v)
		Obsidian.KeybindFrame.Visible = v
	end })
	MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Default = true, Callback = function(v)
		Obsidian.ShowCustomCursor = v
	end })
	MenuGroup:AddDropdown("NotificationSide", { Values = { "Left", "Right" }, Default = "Right", Text = "Notification Side", Callback = function(v)
		Obsidian:SetNotifySide(v)
	end })
	MenuGroup:AddDropdown("DPIDropdown", { Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" }, Default = "100%", Text = "DPI Scale", Callback = function(v)
		v = v:gsub("%%", "")
		Obsidian:SetDPIScale(tonumber(v))
	end })
	MenuGroup:AddDivider()
	MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
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

task.wait(10)
print("freakbob is going to get you")
