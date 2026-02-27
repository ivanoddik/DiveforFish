local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Calibration = require(ReplicatedStorage.Modules.Calibration)
local ModelsFolder = ReplicatedStorage:WaitForChild("Models")
local Assets = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
local TemplatePrompt = Assets:WaitForChild("Templateprompt")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpawnRemote = Remotes:WaitForChild("SpawnModel")
local DespawnRemote = Remotes:WaitForChild("DespawnModel")

local InventoryHandler = require(script.Parent:WaitForChild("InventoryHandler"))
local TutorialHandler = require(script.Parent:WaitForChild("TutorialHandler"))
local Anti = require(game:GetService("ReplicatedStorage").Persistence.Anti)

local ModelHandler = {}

-- Constants
local LIVE_MODELS_NAME = "LiveModels"
local NORMAL_MUTATION = "Normal"
local TAG_SPAWNED_MODEL = "SpawnModel"
local SPAWN_QUEUE_DELAY = 0.5
local MIN_SPAWN_DISTANCE = 8
local MAX_SPAWN_ATTEMPTS = 5

-- State
local liveModels
local ZONES = {}
local POOLS = {}
local SPAWN_QUEUE = {}
local ACTIVE_MODELS = {} 
local EXPIRATION_SORTED = {}

local MAX_SPAWN = {
	["Common"] = 7,
	["Uncommon"] = 9,
	["Rare"] = 12,
	["Epic"] = 12,
	["Legendary"] = 9,
	["Mythical"] = 7,
	["Cosmic"] = 5,
	["Secret"] = 4,
}

local currentSpawnCounts = {
	["Common"] = 0,
	["Uncommon"] = 0,
	["Rare"] = 0,
	["Epic"] = 0,
	["Legendary"] = 0,
	["Mythical"] = 0,
	["Cosmic"] = 0,
	["Secret"] = 0,
}

local MUTATION_WEIGHTS = {
	{name = "Blood", chance = 2},
	{name = "Emerald", chance = 6},
	{name = "Diamond", chance = 12},
	{name = "Gold", chance = 20},
	{name = NORMAL_MUTATION, chance = 60},
}

local RARITY_ORDER = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Cosmic", "Secret"}

-- Helpers
local function selectMutation()
	local roll = math.random(1, 100)
	local cumulative = 0
	for _, mutation in MUTATION_WEIGHTS do
		cumulative += mutation.chance
		if roll <= cumulative then
			return mutation.name
		end
	end
	return NORMAL_MUTATION
end

local function getRandomPositionInPart(part)
	local size = part.Size
	local randomX = (math.random() - 0.5) * size.X
	local randomZ = (math.random() - 0.5) * size.Z
	return part.CFrame:PointToWorldSpace(Vector3.new(randomX, size.Y / 2, randomZ))
end

local function getFromPool(modelName)
	if not POOLS[modelName] then POOLS[modelName] = {} end
	local pool = POOLS[modelName]
	if #pool > 0 then
		local model = table.remove(pool)
		model.Parent = liveModels
		return model
	end
	local source = ModelsFolder:FindFirstChild(modelName)
	if source then
		local clone = source:Clone()
		clone.Parent = liveModels
		return clone
	end
	return nil
end

local function returnToPool(model)
	local modelName = model:GetAttribute("SourceModelName") or model.Name
	model.Parent = nil
	for _, child in model:GetChildren() do
		if child:IsA("ProximityPrompt") and child.Name == "TemplatePrompt" then
			child:Destroy()
		elseif child:IsA("Highlight") then
			child:Destroy()
		end
	end
	if not POOLS[modelName] then POOLS[modelName] = {} end
	table.insert(POOLS[modelName], model)
end

local function cleanupModel(model)
	local data = ACTIVE_MODELS[model]
	if not data then return end
	
	local rarity = data.rarity
	currentSpawnCounts[rarity] = math.max(0, currentSpawnCounts[rarity] - 1)
	ACTIVE_MODELS[model] = nil
	
	for i, entry in ipairs(EXPIRATION_SORTED) do
		if entry.model == model then
			table.remove(EXPIRATION_SORTED, i)
			break
		end
	end
	
	DespawnRemote:FireAllClients(model)
	returnToPool(model)
	
	task.delay(5, function()
		if currentSpawnCounts[rarity] < MAX_SPAWN[rarity] then
			table.insert(SPAWN_QUEUE, rarity)
		end
	end)
end

function ModelHandler.CaptureModel(model, player)
	local data = ACTIVE_MODELS[model]
	if not data then return end
	
	local backpackCount = player:GetAttribute("BackpackCount") or 0
	local backpackCapacity = player:GetAttribute("BackpackCapacity") or 1
	
	if backpackCount >= backpackCapacity then return end
	-- Validation removed
	
	local rarity = data.rarity
	local mutation = data.mutation or NORMAL_MUTATION
	local originalName = model:GetAttribute("SourceModelName") or model.Name
	
	ACTIVE_MODELS[model] = nil
	for i, entry in ipairs(EXPIRATION_SORTED) do
		if entry.model == model then
			table.remove(EXPIRATION_SORTED, i)
			break
		end
	end
	
	currentSpawnCounts[rarity] = math.max(0, currentSpawnCounts[rarity] - 1)
	DespawnRemote:FireAllClients(model)
	
	local tool = Instance.new("Tool")
	tool.Name = originalName
	
	local rarityConfig = Calibration.Get().Models[rarity]
	if rarityConfig then
		local modelData = rarityConfig[originalName]
		if modelData and modelData.Icons then
			tool.TextureId = modelData.Icons[mutation] or modelData.Icons[NORMAL_MUTATION] or ""
		end
	end
	
	tool:SetAttribute("Mutation", mutation)
	tool:SetAttribute("Rarity", rarity)
	tool:SetAttribute("SourceModelName", originalName)
	
	local root = model:FindFirstChild("Root") or (model:IsA("BasePart") and model) or model.PrimaryPart
	if root then
		local handle = root:Clone()
		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.Parent = tool
		for _, desc in handle:GetDescendants() do
			if desc:IsA("ProximityPrompt") then desc:Destroy() end
		end
		for _, child in model:GetDescendants() do
			if child:IsA("BasePart") and child ~= root and not child:IsDescendantOf(tool) then
				local part = child:Clone()
				part.Parent = tool
				part.Anchored = false
				part.CanCollide = false
				for _, desc in part:GetDescendants() do
					if desc:IsA("ProximityPrompt") then desc:Destroy() end
				end
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	
	model:Destroy()
	CollectionService:AddTag(tool, "SpawnedModelTool")
	
	local backpack = player:WaitForChild("Backpack", 5) -- Safety timeout
	if backpack then
		tool.Parent = backpack
	else
		tool:Destroy()
	end
	
	TutorialHandler.OnModelCaptured(player)
	task.delay(5, function()
		if currentSpawnCounts[rarity] < MAX_SPAWN[rarity] then
			table.insert(SPAWN_QUEUE, rarity)
		end
	end)
end

local function spawnModel(rarity)
	local rarityConfig = Calibration.Get().Models[rarity]
	if not rarityConfig then return end
	
	local modelNames = {}
	for name, _ in pairs(rarityConfig) do table.insert(modelNames, name) end
	if #modelNames == 0 then return end
	
	local selectedName = modelNames[math.random(1, #modelNames)]
	local modelData = rarityConfig[selectedName]
	local zonePart = ZONES[rarity]
	if not zonePart then return end
	
	local model = getFromPool(selectedName)
	if not model then return end
	
	local root = model.PrimaryPart or model:FindFirstChild("Root") or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		model:Destroy()
		return
	end
	model.PrimaryPart = root
	
	local mutationName = selectMutation()
	model:SetAttribute("SourceModelName", selectedName)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("Mutation", mutationName)
	
	local finalEarnings = Calibration.GetModelEarnings(selectedName, mutationName)
	local timeLeft = modelData.BaseTime or 50
	local expiration = os.clock() + timeLeft
	
	local spawnPos
	local foundValid = false
	for i = 1, MAX_SPAWN_ATTEMPTS do
		local potentialPos = getRandomPositionInPart(zonePart)
		local isTooClose = false
		for otherModel, _ in pairs(ACTIVE_MODELS) do
			if (potentialPos - otherModel:GetPivot().Position).Magnitude < MIN_SPAWN_DISTANCE then
				isTooClose = true
				break
			end
		end
		if not isTooClose then
			spawnPos = potentialPos
			foundValid = true
			break
		end
	end
	if not foundValid then spawnPos = getRandomPositionInPart(zonePart) end

	model:PivotTo(CFrame.new(spawnPos))
	
	local prompt = TemplatePrompt:Clone()
	prompt.ActionText = "Catch"
	prompt.ObjectText = selectedName
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		ModelHandler.CaptureModel(model, player)
	end)
	
	CollectionService:AddTag(model, TAG_SPAWNED_MODEL)
	
	ACTIVE_MODELS[model] = {rarity = rarity, mutation = mutationName}
	
	local entry = {model = model, expiration = expiration}
	local inserted = false
	for i, existing in ipairs(EXPIRATION_SORTED) do
		if expiration < existing.expiration then
			table.insert(EXPIRATION_SORTED, i, entry)
			inserted = true
			break
		end
	end
	if not inserted then table.insert(EXPIRATION_SORTED, entry) end
	
	currentSpawnCounts[rarity] += 1
	
	local parentConn
	parentConn = model:GetPropertyChangedSignal("Parent"):Connect(function()
		if not model.Parent or (model.Parent ~= liveModels and not model.Parent:IsA("Tool")) then
			if parentConn then parentConn:Disconnect() end
			cleanupModel(model)
		end
	end)
	
	SpawnRemote:FireAllClients(model, {mutation = mutationName, earnings = finalEarnings, timer = timeLeft, rarity = rarity, position = spawnPos})
end

local function startManagerLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			
			-- Process Expirations (Priority based)
			while #EXPIRATION_SORTED > 0 and EXPIRATION_SORTED[1].expiration <= now do
				local entry = table.remove(EXPIRATION_SORTED, 1)
				cleanupModel(entry.model)
			end
			
			-- Process Queue sequentially
			if #SPAWN_QUEUE > 0 then
				local rarity = table.remove(SPAWN_QUEUE, 1)
				spawnModel(rarity)
				task.wait(SPAWN_QUEUE_DELAY)
			end
		end
	end)
end

function ModelHandler.Init()
	liveModels = Workspace:WaitForChild(LIVE_MODELS_NAME, 10) or Instance.new("Folder", Workspace)
	liveModels.Name = LIVE_MODELS_NAME
	
	local zonesFolder = Workspace:WaitForChild("Zones", 5)
	if zonesFolder then
		for rarity, _ in pairs(MAX_SPAWN) do
			for _, child in zonesFolder:GetChildren() do
				if child:IsA("BasePart") and child.Name:lower() == rarity:lower() then
					ZONES[rarity] = child
					break
				end
			end
		end
	end
	
	for _, rarity in RARITY_ORDER do
		if ZONES[rarity] then
			for i = 1, MAX_SPAWN[rarity] do table.insert(SPAWN_QUEUE, rarity) end
		end
	end
	
	startManagerLoop()
end

return ModelHandler
