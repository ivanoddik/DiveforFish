local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Assets = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
local EffectsFolder = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Effects")
local ModelSpawnDisplay = Assets:WaitForChild("ModelSpawnDisplay")
local ModelCollectDisplay = Assets:WaitForChild("ModelCollectDisplay")
local UpgradeBoardAsset = Assets:WaitForChild("UpgradeBoard")
local GoToBeamPrefab = Assets:WaitForChild("GoToBeam")

local Calibration = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Calibration"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpawnRemote = Remotes:WaitForChild("SpawnModel")
local DespawnRemote = Remotes:WaitForChild("DespawnModel")
local CashCollect = Remotes:WaitForChild("CashCollect")
local UpgradeModelRemote = Remotes:WaitForChild("UpgradeModel")
local UpdateTutorialRemote = Remotes:WaitForChild("UpdateTutorial")

local SoundFolder = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Sound")
local CashSound = SoundFolder:WaitForChild("Cash")
local UpgradeSound = SoundFolder:WaitForChild("Upgrade")
local CashVFXAsset = EffectsFolder:WaitForChild("CashVFX")

local Player = Players.LocalPlayer
local ACTIVE_VISUALS = {} 
local UPGRADE_BOARDS = {}
local PAD_MODELS = {} 

-- Tutorial Visual State
local tutorialBeam = nil
local tutorialAtt0 = nil
local tutorialAtt1 = nil
local currentTutorialStep = 0

-- Constants
local NORMAL_MUTATION = "Normal"
local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(95, 95, 95),
	["Uncommon"] = Color3.fromRGB(170, 255, 0),
	["Rare"] = Color3.fromRGB(85, 170, 255),
	["Epic"] = Color3.fromRGB(255, 170, 0),
	["Legendary"] = Color3.fromRGB(255, 85, 0),
	["Mythical"] = Color3.fromRGB(255, 0, 0),
	["Cosmic"] = Color3.fromRGB(170, 0, 255),
	["Secret"] = Color3.fromRGB(35, 35, 35),
}

-- Helpers
local function formatNumber(n)
	local suffixes = {
		{1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
		{1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}
	}
	for _, suffix in ipairs(suffixes) do
		if n >= suffix[1] then
			return string.format("%.2f%s", n / suffix[1], suffix[2])
		end
	end
	return tostring(math.floor(n))
end

local function formatTime(seconds)
	local clampedSeconds = math.max(0, seconds)
	local minutes = math.floor(clampedSeconds / 60)
	local secs = math.floor(clampedSeconds % 60)
	return string.format("%02d:%02d", minutes, secs)
end

local function parseColor(c)
	if typeof(c) == "Color3" then return c end
	if typeof(c) == "string" then
		local r, g, b = c:match("(%d+),%s*(%d+),%s*(%d+)")
		if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
	elseif typeof(c) == "table" then
		return Color3.fromRGB(c[1] or 255, c[2] or 255, c[3] or 255)
	end
	return Color3.new(1, 1, 1)
end

local function calculateUpgradePrice(earnings, level)
	local levelFactor = 1
	if level == 2 then
		levelFactor = 1.55
	elseif level > 2 then
		levelFactor = 1.55 * (1.2 ^ (level - 2))
	end
	return math.ceil(earnings * 19.5 * levelFactor)
end

local function applyMutationVisuals(model, mutationName)
	if mutationName == NORMAL_MUTATION then return nil, nil end
	
	local mutationsTable = Calibration.Get().Mutations
	if not mutationsTable then return nil, nil end
	
	local mData = mutationsTable[mutationName]
	if not mData then return nil, nil end
	
	local highlight = Instance.new("Highlight")
	highlight.FillColor = parseColor(mData.FillColor)
	highlight.OutlineColor = parseColor(mData.OutlineColor)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.65
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	
	local function applyGradientToLabels(instance)
		for _, child in instance:GetChildren() do
			if child:IsA("TextLabel") and (child.Name == "Mutation" or child.Name == "Mutations") then
				local gradient = Assets:FindFirstChild("Gradient" .. mutationName)
				if gradient then
					for _, g in child:GetChildren() do
						if g:IsA("UIGradient") then g:Destroy() end
					end
					gradient:Clone().Parent = child
				end
			end
			applyGradientToLabels(child)
		end
	end
	applyGradientToLabels(model)
	
	local effect = nil
	local effectSource = EffectsFolder:FindFirstChild(mutationName)
	if effectSource and effectSource:IsA("Attachment") then
		local root = model:FindFirstChild("Root") or (model:IsA("BasePart") and model) or model.PrimaryPart
		if root then
			effect = effectSource:Clone()
			effect.Parent = root
		end
	end
	
	return highlight, effect
end

local function setupDisplay(model, data)
	local sourceDisplay = if data.isPlaced then ModelCollectDisplay else ModelSpawnDisplay
	local display = sourceDisplay:Clone()
	
	display.Active = false
	display.StudsOffset = Vector3.new(0, 3.5, 0)
	
	local earningsLabel = display:FindFirstChild("Earnings", true)
	local nameLabel = display:FindFirstChild("Name", true) or display:FindFirstChild("NameLabel", true)
	local rarityLabel = display:FindFirstChild("Rarity", true)
	local mutationLabel = display:FindFirstChild("Mutations", true) or display:FindFirstChild("Mutation", true)
	
	if data.isPlaced then
		local timerLabel = display:FindFirstChild("Timer", true)
		if timerLabel then timerLabel:Destroy() end
	end
	
	if earningsLabel then earningsLabel.Text = "+$" .. formatNumber(data.earnings) .. "/s" end
	if nameLabel then nameLabel.Text = model:GetAttribute("SourceModelName") or model.Name end
	if rarityLabel then 
		rarityLabel.Text = data.rarity
		rarityLabel.TextColor3 = RARITY_COLORS[data.rarity] or Color3.new(1, 1, 1)
	end
	
	if mutationLabel then 
		mutationLabel.Text = data.mutation
		mutationLabel.Visible = true
		
		for _, child in mutationLabel:GetChildren() do
			if child:IsA("UIGradient") then child:Destroy() end
		end
		
		if data.mutation ~= NORMAL_MUTATION then
			local gradient = Assets:FindFirstChild("Gradient" .. data.mutation)
			if gradient then
				gradient:Clone().Parent = mutationLabel
			end
		end
	end
	
	display.Parent = model
	return display
end

local function removeVisuals(model)
	local visualData = ACTIVE_VISUALS[model]
	if not visualData then return end
	
	if visualData.connection then visualData.connection:Disconnect() end
	if visualData.tweens then
		for _, tween in visualData.tweens do
			tween:Cancel()
		end
	end
	
	if visualData.animateValue then visualData.animateValue:Destroy() end
	if visualData.display then visualData.display:Destroy() end
	if visualData.highlight then visualData.highlight:Destroy() end
	if visualData.effect then visualData.effect:Destroy() end
	
	ACTIVE_VISUALS[model] = nil
end

local function updateBoardVisuals(pad)
	local boardData = UPGRADE_BOARDS[pad]
	if not boardData then return end
	
	local gui = boardData.gui
	local button = gui:FindFirstChild("UpgradeBoard", true)
	local content = button and button:FindFirstChild("Content")
	if not content then return end
	
	local costLabel = content:FindFirstChild("Cost", true)
	local levelLabel = content:FindFirstChild("Level", true)
	local validGradient = content:FindFirstChild("Green") or content:FindFirstChild("ValidGradient")
	local invalidGradient = content:FindFirstChild("Grey") or content:FindFirstChild("InValidGradient")
	local studTexture = content:FindFirstChild("StudTexture")
	local studsValid = studTexture and (studTexture:FindFirstChild("Green") or studTexture:FindFirstChild("StudsValid"))
	local studsInvalid = studTexture and (studTexture:FindFirstChild("Grey") or studTexture:FindFirstChild("StudsInvalid"))
	
	local targetModel = PAD_MODELS[pad]
	if targetModel and targetModel.Parent then
		local level = targetModel:GetAttribute("Level") or 1
		local earnings = targetModel:GetAttribute("Earnings") or 0
		local price = calculateUpgradePrice(earnings, level)
		
		if costLabel then costLabel.Text = "$" .. formatNumber(price) end
		if levelLabel then levelLabel.Text = "Level " .. level .. " -> Level " .. (level + 1) end
		
		-- Update the Floating Earnings display too
		local visualData = ACTIVE_VISUALS[targetModel]
		if visualData and visualData.display then
			local earningsLabel = visualData.display:FindFirstChild("Earnings", true)
			if earningsLabel then
				earningsLabel.Text = "+$" .. formatNumber(earnings) .. "/s"
			end
		end
		
		local base = pad:FindFirstAncestorOfClass("Model")
		if not base then 
			gui.Enabled = false
			return 
		end
		
		local ownerId = base:GetAttribute("OwnerID") or (base:FindFirstChild("Owner") and base.Owner.Value)
		local ownerIsLocalPlayer = (ownerId == Player.UserId)
		
		local cash = Player:GetAttribute("Cash") or 0
		local canAfford = ownerIsLocalPlayer and (cash >= price)
		
		if validGradient then validGradient.Enabled = canAfford end
		if invalidGradient then invalidGradient.Enabled = not canAfford end
		if studsValid then studsValid.Enabled = canAfford end
		if studsInvalid then studsInvalid.Enabled = not canAfford end
		
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end

local function cleanupUpgradeBoard(pad)
	local data = UPGRADE_BOARDS[pad]
	if not data then return end
	
	for _, conn in pairs(data.connections) do
		conn:Disconnect()
	end
	if data.gui then data.gui:Destroy() end
	UPGRADE_BOARDS[pad] = nil
end

local function setupUpgradeBoard(pad)
	if UPGRADE_BOARDS[pad] then 
		updateBoardVisuals(pad)
		return 
	end
	
	local boardPart = pad:FindFirstChild("UpgradeBoard")
	if not boardPart then return end
	
	local gui = UpgradeBoardAsset:Clone()
	gui.Name = "UpgradeBoard"
	gui.Adornee = boardPart
	gui.Enabled = false
	gui.Parent = boardPart
	
	local connections = {}
	local button = gui:FindFirstChild("UpgradeBoard", true)
	if button and button:IsA("ImageButton") then
		table.insert(connections, button.Activated:Connect(function()
			local base = pad:FindFirstAncestorOfClass("Model")
			local ownerId = base and (base:GetAttribute("OwnerID") or (base:FindFirstChild("Owner") and base.Owner.Value))
			if Player.UserId ~= ownerId then return end
			
			local targetModel = PAD_MODELS[pad]
			if targetModel then
				local modelID = targetModel:GetAttribute("ModelID")
				if modelID then UpgradeModelRemote:FireServer(modelID) end
			end
		end))
	end
	
	local base = pad:FindFirstAncestorOfClass("Model")
	local liveModels = base and base:FindFirstChild("LiveModels")
	if liveModels then
		table.insert(connections, liveModels.ChildAdded:Connect(function(m)
			if m:GetAttribute("PadName") == pad.Name then
				PAD_MODELS[pad] = m
				updateBoardVisuals(pad)
			end
		end))
		table.insert(connections, liveModels.ChildRemoved:Connect(function(m)
			if PAD_MODELS[pad] == m then
				PAD_MODELS[pad] = nil
				updateBoardVisuals(pad)
			end
		end))
	end
    
    local ownerId = base and (base:GetAttribute("OwnerID") or (base:FindFirstChild("Owner") and base.Owner.Value))
    if ownerId == Player.UserId then
        table.insert(connections, Player:GetAttributeChangedSignal("Cash"):Connect(function()
            updateBoardVisuals(pad)
        end))
    end
	
	UPGRADE_BOARDS[pad] = {
		gui = gui,
		connections = connections
	}
	
	-- Initial cache check
	if liveModels then
		for _, m in ipairs(liveModels:GetChildren()) do
			if m:GetAttribute("PadName") == pad.Name then
				PAD_MODELS[pad] = m
				break
			end
		end
	end
	
	updateBoardVisuals(pad)
end

local function onModelSpawn(model, data)
	if not model:IsDescendantOf(workspace) then
		model:GetPropertyChangedSignal("Parent"):Wait()
	end
	
	removeVisuals(model)
	
	local display = setupDisplay(model, data)
	local highlight, effect = applyMutationVisuals(model, data.mutation)
	
	local pad = data.pad or (model:GetAttribute("PadName") and model.Parent and model.Parent.Parent and model.Parent.Parent:FindFirstChild("Pads") and model.Parent.Parent.Pads:FindFirstChild(model:GetAttribute("PadName")))
	if pad then
		PAD_MODELS[pad] = model
		setupUpgradeBoard(pad)
	end
	
	local animateValue = Instance.new("CFrameValue")
	animateValue.Value = model:GetPivot()
	
	local conn = animateValue.Changed:Connect(function(val)
		if model.Parent and not model.Parent:IsA("Tool") then
			model:PivotTo(val)
		end
	end)
	
	local tweens = {}
	local startCFrame = data.cframe or CFrame.new(data.position or Vector3.new(0,0,0))
	local spawnOffset = Vector3.new(0, 4, 0)
	
	model:PivotTo(startCFrame * CFrame.new(spawnOffset))
	animateValue.Value = startCFrame * CFrame.new(spawnOffset)
	
	local bounceInfo = TweenInfo.new(1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	local bounceTween = TweenService:Create(animateValue, bounceInfo, {Value = startCFrame})
	table.insert(tweens, bounceTween)
	bounceTween:Play()
	
	task.delay(1.5, function()
		if not ACTIVE_VISUALS[model] then return end
		local floatInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		local floatTween = TweenService:Create(animateValue, floatInfo, {Value = startCFrame * CFrame.new(0, 0.5, 0)})
		table.insert(tweens, floatTween)
		floatTween:Play()
	end)
	
	ACTIVE_VISUALS[model] = {
		display = display,
		highlight = highlight,
		effect = effect,
		animateValue = animateValue,
		tweens = tweens,
		timerValue = data.timer,
		connection = conn
	}
end

local function onCashCollect(collectPart)
	if not collectPart then return end
	CashSound:Play()
	local vfx = CashVFXAsset:Clone()
	vfx.Parent = collectPart
	task.delay(0.7, function() if vfx.Parent then vfx:Destroy() end end)
end

local function onUpgradeModel(model)
	if not model then return end
	UpgradeSound:Play()
	local padName = model:GetAttribute("PadName")
	local base = model:FindFirstAncestorOfClass("Model")
	local pads = base and base:FindFirstChild("Pads")
	local pad = pads and pads:FindFirstChild(padName)
	if pad then updateBoardVisuals(pad) end
end

local function onModelDespawn(model)
	if not model then return end
	local padName = model:GetAttribute("PadName")
	local base = model:FindFirstAncestorOfClass("Model")
	
	removeVisuals(model)
	
	if padName and base then
		local pads = base:FindFirstChild("Pads")
		local pad = pads and pads:FindFirstChild(padName)
		if pad then
			if PAD_MODELS[pad] == model then PAD_MODELS[pad] = nil end
			updateBoardVisuals(pad)
		end
	end
end

-- Tutorial Handling
local function clearTutorial()
	if tutorialBeam then tutorialBeam:Destroy(); tutorialBeam = nil end
	if tutorialAtt0 then tutorialAtt0:Destroy(); tutorialAtt0 = nil end
	if tutorialAtt1 then tutorialAtt1:Destroy(); tutorialAtt1 = nil end
	currentTutorialStep = 0
end

local function onUpdateTutorial(step, text)
	clearTutorial()
	currentTutorialStep = step
	
	if step > 4 then return end
	
	local character = Player.Character or Player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	
	tutorialBeam = GoToBeamPrefab:Clone()
	tutorialAtt1 = Instance.new("Attachment", hrp)
	tutorialAtt1.Name = "TutorialAtt1"
	
	tutorialAtt0 = Instance.new("Attachment")
	tutorialAtt0.Name = "TutorialAtt0"
	
	tutorialBeam.Attachment0 = tutorialAtt0
	tutorialBeam.Attachment1 = tutorialAtt1
	tutorialBeam.Enabled = false
	tutorialBeam.Parent = hrp
	
	if step == 1 then
		-- Step 1: Find closest SpawnModel
		task.spawn(function()
			while currentTutorialStep == 1 and Player.Parent do
				local liveModels = workspace:FindFirstChild("LiveModels")
				local closest = nil
				local minDist = math.huge
				
				if liveModels then
					for _, model in ipairs(liveModels:GetChildren()) do
						if CollectionService:HasTag(model, "SpawnModel") then
							local root = model:FindFirstChild("Root") or model.PrimaryPart
							if root then
								local dist = (hrp.Position - root.Position).Magnitude
								if dist < minDist then
									minDist = dist
									closest = root
								end
							end
						end
					end
				end
				
				if closest and tutorialAtt0 then
					tutorialAtt0.Parent = closest
					tutorialBeam.Enabled = true
				elseif tutorialBeam then
					tutorialBeam.Enabled = false
				end
				task.wait(1)
			end
		end)
	elseif step == 2 then
		-- Step 2: Guide to Pad 1 Holder
		local baseFolder = workspace:FindFirstChild("Bases")
		local base = nil
		if baseFolder then
			-- Find by OwnerID attribute (matching PlayerHandler)
			for _, b in ipairs(baseFolder:GetChildren()) do
				if b:GetAttribute("OwnerID") == Player.UserId then
					base = b
					break
				end
			end
			-- Fallback to name
			if not base then
				base = baseFolder:FindFirstChild(Player.Name .. "Base")
			end
		end
		
		if base then
			local pads = base:FindFirstChild("Pads")
			local pad1 = pads and (pads:FindFirstChild("1") or pads:FindFirstChild("Pad1"))
			local holder = pad1 and pad1:FindFirstChild("Holder")
			if holder then
				tutorialAtt0.Parent = holder
				tutorialBeam.Enabled = true
			end
		end
	elseif step == 3 then
		-- Step 3: Find the placed model's collect part
		local baseFolder = workspace:FindFirstChild("Bases")
		local base = nil
		if baseFolder then
			for _, b in ipairs(baseFolder:GetChildren()) do
				if b:GetAttribute("OwnerID") == Player.UserId then
					base = b
					break
				end
			end
		end
		
		if base then
			local liveModels = base:FindFirstChild("LiveModels")
			local pads = base:FindFirstChild("Pads")
			if liveModels then
				local model = liveModels:GetChildren()[1]
                local padName = model and model:GetAttribute("PadName")
                local pad = padName and pads and pads:FindFirstChild(padName)
				local collect = pad and pad:FindFirstChild("Collect")
				if collect then
					tutorialAtt0.Parent = collect
					tutorialBeam.Enabled = true
				end
			end
		end
	elseif step == 4 then
		-- Step 4: Oxygen TouchPart
		local important = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Important")
		local oxygenPart = important and important:FindFirstChild("Oxygen") and important.Oxygen:FindFirstChild("Touchpart")
		if oxygenPart then
			tutorialAtt0.Parent = oxygenPart
			tutorialBeam.Enabled = true
		end
	end
end

-- Efficient Timer Update
task.spawn(function()
	while true do
		local dt = task.wait(1)
		for model, visualData in pairs(ACTIVE_VISUALS) do
			if model.Parent then
				visualData.timerValue -= dt
				local display = visualData.display
				local timerLabel = display and display:FindFirstChild("Timer")
				if timerLabel then
					timerLabel.Text = formatTime(visualData.timerValue)
				end
			else
				removeVisuals(model)
			end
		end
	end
end)

SpawnRemote.OnClientEvent:Connect(onModelSpawn)
DespawnRemote.OnClientEvent:Connect(onModelDespawn)
CashCollect.OnClientEvent:Connect(onCashCollect)
UpgradeModelRemote.OnClientEvent:Connect(onUpgradeModel)
UpdateTutorialRemote.OnClientEvent:Connect(onUpdateTutorial)

CollectionService:GetInstanceRemovedSignal("SpawnModel"):Connect(function(model)
    if ACTIVE_VISUALS[model] then onModelDespawn(model) end
end)
