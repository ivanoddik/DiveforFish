local ModelPlacementHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ASSETS = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
local MODELS_FOLDER = ReplicatedStorage:WaitForChild("Models")
local TEMPLATE_PROMPT = ASSETS:WaitForChild("Templateprompt")
local COLLECTOR_GUI = ASSETS:WaitForChild("CollectorGui")
local Calibration = require(ReplicatedStorage.Modules.Calibration)
local TutorialHandler = require(script.Parent:WaitForChild("TutorialHandler"))
local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local SpawnRemote = REMOTES:WaitForChild("SpawnModel")
local DespawnRemote = REMOTES:WaitForChild("DespawnModel")
local CashCollect = REMOTES:WaitForChild("CashCollect")

local NORMAL_MUTATION = "Normal"
local collectDebounces = {}

-- Offline Earnings Constants
local OFFLINE_INTERVAL = 8
local OFFLINE_MULTIPLIER = 0.2
local OFFLINE_CAP = 12 * 60 * 60

local function getOfflineMultiplier(eps)
	if eps < 100 then return 0.3 end
	if eps < 1_000 then return 0.2 end
	if eps < 10_000 then return 0.1 end
	return 0.05
end

local function formatNumber(n)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	else
		return tostring(n)
	end
end

local function findModelInfoInConfig(modelName)
	for rarity, models in pairs(Calibration.Get().Models) do
		if models[modelName] then
			return models[modelName], rarity
		end
	end
	return nil
end

local function convertPlacedModelToTool(model, player)
	local modelName = model:GetAttribute("SourceModelName") or model.Name
	local mutation = model:GetAttribute("Mutation") or NORMAL_MUTATION
	local rarity = model:GetAttribute("Rarity") or "Common"
	local level = model:GetAttribute("Level") or 1
	local earnings = model:GetAttribute("Earnings") or 0
	
	local tool = Instance.new("Tool")
	tool.Name = modelName
	
	local info = findModelInfoInConfig(modelName)
	if info and info.Icons then
		tool.TextureId = info.Icons[mutation] or info.Icons[NORMAL_MUTATION] or ""
	end
	
	tool:SetAttribute("Mutation", mutation)
	tool:SetAttribute("Rarity", rarity)
	tool:SetAttribute("Level", level)
	tool:SetAttribute("Earnings", earnings)
	tool:SetAttribute("SourceModelName", modelName)
	tool:SetAttribute("ModelID", model:GetAttribute("ModelID"))
	
	local root = model.PrimaryPart or model:FindFirstChild("Root") or model:FindFirstChildWhichIsA("BasePart")
	if root then
		local handle = root:Clone()
		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.Parent = tool
		
		-- Cleanup UI and Prompts
		for _, desc in handle:GetDescendants() do
			if desc:IsA("ProximityPrompt") or desc:IsA("BillboardGui") or desc:IsA("Highlight") or desc:IsA("UIGradient") then
				desc:Destroy()
			end
		end
		
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child ~= root then
				local part = child:Clone()
				part.Anchored = false
				part.CanCollide = false
				part.Parent = tool
				
				for _, desc in part:GetDescendants() do
					if desc:IsA("ProximityPrompt") or desc:IsA("BillboardGui") or desc:IsA("Highlight") or desc:IsA("UIGradient") then
						desc:Destroy()
					end
				end
				
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	
	CollectionService:AddTag(tool, "PlacedModelTool")
	tool.Parent = player:WaitForChild("Backpack")

	local padName = model:GetAttribute("PadName")
	if padName then
		local DataService = require(script.Parent:WaitForChild("DataService"))
		local profile = DataService:GetProfile(player)
		if profile then
			local placedModels = profile.Data.PlacedModels or {}
			placedModels[padName] = nil
			profile:Update("PlacedModels", placedModels)
		end
		
		local base = model.Parent and model.Parent.Parent
		local pad = base and base:FindFirstChild("Pads") and base.Pads:FindFirstChild(padName)
		if pad then
			pad:SetAttribute("Holding", false)
			pad:SetAttribute("HoldingID", nil)
		end
	end

	DespawnRemote:FireAllClients(model)
	model:Destroy()
end

function ModelPlacementHandler.InitializeCollectorGui(collectPart)
	local gui = collectPart:FindFirstChild("CollectorGui")
	if not gui then
		gui = COLLECTOR_GUI:Clone()
		local cashLabel = gui:FindFirstChild("Cash", true)
		if cashLabel then
			cashLabel.Text = "$0"
			local realVal = Instance.new("IntValue")
			realVal.Name = "RealCash"
			realVal.Value = 0
			realVal.Parent = cashLabel
		end
		gui.Adornee = collectPart
		gui.Parent = collectPart
	end
	return gui
end

local function resetStoredCash(player, padName)
	local DataService = require(script.Parent:WaitForChild("DataService"))
	local profile = DataService:GetProfile(player)
	if profile then
		local placedModels = profile.Data.PlacedModels or {}
		if placedModels[padName] then
			placedModels[padName].storedCash = 0
			profile:Update("PlacedModels", placedModels)
		end
	end
end

function ModelPlacementHandler.SetupCollectPart(pad, base)
	local collectPart = pad:FindFirstChild("Collect")
	if not collectPart then return end
	
    task.spawn(function()
        if not base:GetAttribute("BaseReady") then
            base:GetAttributeChangedSignal("BaseReady"):Wait()
        end
        
        local liveModels = base:FindFirstChild("LiveModels")
        local hasModel = false
        if liveModels then
            for _, m in ipairs(liveModels:GetChildren()) do
                if m:GetAttribute("PadName") == pad.Name then
                    hasModel = true
                    break
                end
            end
        end
        
        if hasModel then
            ModelPlacementHandler.InitializeCollectorGui(collectPart)
        end
    end)

	collectPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		
		local ownerId = base:GetAttribute("OwnerID")
		if player.UserId ~= ownerId then return end
		
		local gui = collectPart:FindFirstChild("CollectorGui")
		local cashLabel = gui and gui:FindFirstChild("Cash", true)
		local realVal = cashLabel and cashLabel:FindFirstChild("RealCash")
		
		if realVal and realVal.Value > 0 then
			local now = os.clock()
			if now - (collectDebounces[collectPart] or 0) < 0.45 then return end
			collectDebounces[collectPart] = now
			
			local amount = realVal.Value
			realVal.Value = 0
			cashLabel.Text = "$0"
			
			local DataService = require(script.Parent:WaitForChild("DataService"))
			local profile = DataService:GetProfile(player)
			if profile then
				profile:Increment("Cash", amount)
                resetStoredCash(player, pad.Name)
				CashCollect:FireAllClients(collectPart)
			end
		end
	end)
end

function ModelPlacementHandler.SetupPlacementPrompt(pad, base)
	local holder = pad:FindFirstChild("Holder")
	local liveModels = base:FindFirstChild("LiveModels")
	if not holder or not liveModels or not pad:GetAttribute("Active") then return end
	
	-- Clean existing
	local existing = holder:FindFirstChild("Templateprompt")
	if existing then existing:Destroy() end
	
	local prompt = TEMPLATE_PROMPT:Clone()
	
	local function getPlacedModelOnPad()
		for _, child in liveModels:GetChildren() do
			if child:GetAttribute("PadName") == pad.Name then
				return child
			end
		end
		return nil
	end

	local function updatePromptText()
		local placedModel = getPlacedModelOnPad()
		prompt.ActionText = if placedModel then "Grab/Replace" else "Place"
	end
	
	updatePromptText()
	
	liveModels.ChildAdded:Connect(updatePromptText)
	liveModels.ChildRemoved:Connect(updatePromptText)
	
	prompt.ObjectText = ""
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = holder
	
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if not character then return end
		
		local ownerID = base:GetAttribute("OwnerID")
		if not ownerID or ownerID ~= player.UserId then return end
		
		local tool = character:FindFirstChildOfClass("Tool")
		local isHoldingTool = tool and (CollectionService:HasTag(tool, "SpawnedModelTool") or CollectionService:HasTag(tool, "PlacedModelTool") or CollectionService:HasTag(tool, "SpecialTool"))
		
		-- Handle Grab/Replace
		local placedModel = getPlacedModelOnPad()
		
		if placedModel then
			if isHoldingTool then
				convertPlacedModelToTool(placedModel, player)
			else
				convertPlacedModelToTool(placedModel, player)
				
				local collectPart = pad:FindFirstChild("Collect")
				if collectPart then
					local hasOtherModelsOnPad = false
					for _, other in liveModels:GetChildren() do
						if other ~= placedModel and other:GetAttribute("PadName") == pad.Name then
							hasOtherModelsOnPad = true
							break
						end
					end
					
					if not hasOtherModelsOnPad then
						local gui = collectPart:FindFirstChild("CollectorGui")
						if gui then gui:Destroy() end
					end
				end
				return
			end
		end
		
		tool = character:FindFirstChildOfClass("Tool")
		if tool and (CollectionService:HasTag(tool, "SpawnedModelTool") or CollectionService:HasTag(tool, "PlacedModelTool") or CollectionService:HasTag(tool, "SpecialTool")) then
			local modelName = tool.Name
			local mutation = tool:GetAttribute("Mutation") or NORMAL_MUTATION
			local rarity = tool:GetAttribute("Rarity") or "Common"
			local level = tool:GetAttribute("Level") or 1
			local savedEarnings = tool:GetAttribute("Earnings")
			local sourceModel = MODELS_FOLDER:FindFirstChild(modelName)
			
			if sourceModel then
				local currentMaxID = base:GetAttribute("ModelIDCount") or 0
				currentMaxID += 1
				base:SetAttribute("ModelIDCount", currentMaxID)
				
				tool:Destroy()
				
				local clonedModel = sourceModel:Clone()
				clonedModel:SetAttribute("PadName", pad.Name)
				clonedModel:SetAttribute("ModelID", currentMaxID)
				clonedModel:SetAttribute("Mutation", mutation)
				clonedModel:SetAttribute("Rarity", rarity)
				clonedModel:SetAttribute("Level", level)
				clonedModel:SetAttribute("SourceModelName", modelName)
				
				-- Add PlacedModel tag
				CollectionService:AddTag(clonedModel, "PlacedModel")
				
				local info = findModelInfoInConfig(modelName)
				
				local holderCFrame = holder.CFrame
				local holderRotation = holderCFrame.Rotation
				local holderSize = holder.Size
				local modelSize = clonedModel:GetExtentsSize()
				local spawnPos = holderCFrame.Position + Vector3.new(0, (holderSize.Y / 2) + (modelSize.Y / 2), 0)
				local spawnCFrame = CFrame.new(spawnPos) * holderRotation
				
				clonedModel:PivotTo(spawnCFrame)
				clonedModel.Parent = liveModels
				
				local finalEarnings
				if savedEarnings and savedEarnings > 0 then
					finalEarnings = savedEarnings
				else
					-- Notify PerformanceHandler for visuals
					local multiplier = 1
					local mutationsTable = Calibration.Get().Mutations
					if mutation ~= NORMAL_MUTATION and mutationsTable then
						local mData = mutationsTable[mutation]
						if mData then
							multiplier = mData.Multiplier or mData.nMultiplier or 1
						end
					end
					
					local baseEarnings = if info then (info.Earnings or 0) else 0
					finalEarnings = math.ceil(baseEarnings * multiplier)
				end
				
				clonedModel:SetAttribute("Earnings", finalEarnings)
				
				-- Update DataService PlacedModels
				local DataService = require(script.Parent:WaitForChild("DataService"))
				local profile = DataService:GetProfile(player)
				if profile then
					local placedModels = profile.Data.PlacedModels or {}
					placedModels[pad.Name] = {
						modelName = modelName,
						mutation = mutation,
						rarity = rarity,
						level = level,
						earnings = finalEarnings,
                        storedCash = 0
					}
					profile:Update("PlacedModels", placedModels)
				end
				
				-- Add to collection on placement
				local InventoryHandler = require(script.Parent:WaitForChild("InventoryHandler"))
				InventoryHandler.AddToCollections(player, modelName, mutation, rarity)
				
				local collectPart = pad:FindFirstChild("Collect")
				if collectPart then
					ModelPlacementHandler.InitializeCollectorGui(collectPart)
				end
				
				SpawnRemote:FireAllClients(clonedModel, {
					mutation = mutation,
					earnings = finalEarnings,
					rarity = rarity,
					timer = 0,
					cframe = spawnCFrame,
					isPlaced = true,
					pad = pad
				})
				
				pad:SetAttribute("Holding", true)
				pad:SetAttribute("HoldingID", currentMaxID)
				
				TutorialHandler.OnModelPlaced(player, collectPart)
			end
		end
	end)
end

function ModelPlacementHandler.RunEarningsLoop(BasesFolder)
	task.spawn(function()
        local DataService = require(script.Parent:WaitForChild("DataService"))
		while true do
			task.wait(1)
			for _, base in BasesFolder:GetChildren() do
                if not base:GetAttribute("BaseReady") then continue end
                
				local liveModels = base:FindFirstChild("LiveModels")
				local padsFolder = base:FindFirstChild("Pads")
				if not liveModels or not padsFolder then continue end
				
                local ownerID = base:GetAttribute("OwnerID")
                local player = nil
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.UserId == ownerID then
                        player = p
                        break
                    end
                end
                
                local profile = player and DataService:GetProfile(player)

				for _, model in liveModels:GetChildren() do
					local padName = model:GetAttribute("PadName")
					local earnings = model:GetAttribute("Earnings") or 0
					if padName and earnings > 0 then
						local pad = padsFolder:FindFirstChild(padName)
						local collect = pad and pad:FindFirstChild("Collect")
						local gui = collect and collect:FindFirstChild("CollectorGui")
						local cashLabel = gui and gui:FindFirstChild("Cash", true)
						local realVal = cashLabel and cashLabel:FindFirstChild("RealCash")
						
						if realVal then
							realVal.Value += earnings
							cashLabel.Text = "$" .. formatNumber(realVal.Value)
                            
                            -- Persist current earnings into profile so they aren't lost on leave/crash
                            if profile then
                                local placedModels = profile.Data.PlacedModels or {}
                                if placedModels[padName] then
                                    placedModels[padName].storedCash = realVal.Value
                                    profile:Update("PlacedModels", placedModels)
                                end
                            end
						end
					end
				end
			end
		end
	end)
end

function ModelPlacementHandler.CalculateOfflineEarnings(player, profile, logoutTime)
	if not logoutTime or logoutTime <= 0 then return 0 end
	
	local timeAway = os.time() - logoutTime
	if timeAway < OFFLINE_INTERVAL then 
        timeAway = 0 
    end
	
	timeAway = math.min(timeAway, OFFLINE_CAP)
	local intervals = math.floor(timeAway / OFFLINE_INTERVAL)
	
	local placedModels = profile.Data.PlacedModels or {}
	local totalEPS = 0 -- Earnings Per Second (interval)
	
	for _, modelData in pairs(placedModels) do
		totalEPS += (modelData.earnings or 0)
	end
	
	local totalEarned = 0
	if totalEPS > 0 and intervals > 0 then
		local scalingMult = getOfflineMultiplier(totalEPS)
		totalEarned = math.floor(totalEPS * intervals * scalingMult)
	end
	
	local basesFolder = workspace:FindFirstChild("Bases")
	local base = nil
	
	local timeout = 0
	while timeout < 20 do -- Increased timeout
		base = basesFolder:FindFirstChild(player.Name .. "Base")
		if not base then
			for _, b in ipairs(basesFolder:GetChildren()) do
				if b:GetAttribute("OwnerID") == player.UserId then
					base = b
					break
				end
			end
		end
		
		if base and base:GetAttribute("BaseReady") then
            if base:FindFirstChild("Pads") and base:FindFirstChild("LiveModels") then
                break
            end
		end
		
		task.wait(0.5)
		timeout += 0.5
	end

	if base then
		local padsFolder = base:FindFirstChild("Pads")
		local liveModels = base:FindFirstChild("LiveModels")
		if padsFolder and liveModels then
            local totalOfflineDistributed = 0
            local modelCount = 0
            local modelPadNames = {}
            for pName in pairs(placedModels) do 
                modelCount += 1 
                table.insert(modelPadNames, pName)
            end

			for _, padName in ipairs(modelPadNames) do
                local modelData = placedModels[padName]
				local pad = padsFolder:FindFirstChild(padName)
				local sourceModel = MODELS_FOLDER:FindFirstChild(modelData.modelName)
				if pad and sourceModel then
					local holder = pad:FindFirstChild("Holder")
					if not holder then continue end
					
					local currentMaxID = base:GetAttribute("ModelIDCount") or 0
					currentMaxID += 1
					base:SetAttribute("ModelIDCount", currentMaxID)
					
					local clonedModel = sourceModel:Clone()
					local mutation = modelData.mutation or NORMAL_MUTATION
					local rarity = modelData.rarity or "Common"
					local level = modelData.level or 1
					local earnings = modelData.earnings or 0
                    local previouslyStored = modelData.storedCash or 0
                    
                    local modelOffline = 0
                    if totalEarned > 0 and totalEPS > 0 then
                        modelOffline = math.floor((earnings / totalEPS) * totalEarned)
                        totalOfflineDistributed += modelOffline
                    end
                    
                    if _ == #modelPadNames then
                        modelOffline += (totalEarned - totalOfflineDistributed)
                    end
					
					clonedModel:SetAttribute("ModelID", currentMaxID)
					clonedModel:SetAttribute("Mutation", mutation)
					clonedModel:SetAttribute("Rarity", rarity)
					clonedModel:SetAttribute("Level", level)
					clonedModel:SetAttribute("SourceModelName", modelData.modelName)
					clonedModel:SetAttribute("Earnings", earnings)
					clonedModel:SetAttribute("PadName", padName)
					
					CollectionService:AddTag(clonedModel, "PlacedModel")

					local spawnCFrame = holder.CFrame * CFrame.new(0, (holder.Size.Y / 2) + (clonedModel:GetExtentsSize().Y / 2), 0)
					clonedModel:PivotTo(spawnCFrame)
					clonedModel.Parent = liveModels
					
					pad:SetAttribute("Holding", true)
					pad:SetAttribute("HoldingID", currentMaxID)
					
					local collectPart = pad:FindFirstChild("Collect")
                    if collectPart then
                        local gui = ModelPlacementHandler.InitializeCollectorGui(collectPart)
                        local cashLabel = gui:FindFirstChild("Cash", true)
                        local realVal = cashLabel and cashLabel:FindFirstChild("RealCash")
                        
                        if realVal then
                            local amountToAdd = modelOffline + previouslyStored
                            realVal.Value = amountToAdd
                            cashLabel.Text = "$" .. formatNumber(realVal.Value)
                            
                            placedModels[padName].storedCash = amountToAdd
                        end
                    end

					SpawnRemote:FireAllClients(clonedModel, {
						mutation = mutation,
						earnings = earnings,
						rarity = rarity,
						timer = 0,
						cframe = spawnCFrame,
						isPlaced = true,
						pad = pad
					})
				end
			end
            profile:Update("PlacedModels", placedModels)
		end
	end
	
	return totalEarned
end

return ModelPlacementHandler
