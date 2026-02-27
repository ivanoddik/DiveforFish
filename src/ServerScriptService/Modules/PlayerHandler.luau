local PlayerHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BASES_FOLDER = workspace:WaitForChild("Bases")
local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local ASSETS = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Assets")
local COLLECTED_GUI = ASSETS:WaitForChild("Collected")

local UpdateBaseBillboard = REMOTES:WaitForChild("UpdateBaseBillboard")
local EnterWater = REMOTES:WaitForChild("EnterWater")
local ExitWater = REMOTES:WaitForChild("ExitWater")
local UpgradeModelRemote = REMOTES:WaitForChild("UpgradeModel")

local ModelPlacementHandler = require(script.Parent:WaitForChild("ModelPlacementHandler"))
local Calibration = require(ReplicatedStorage.Modules.Calibration)
local DataService = require(script.Parent:WaitForChild("DataService"))

-- State / Caching
local oxygenTimers = {} 
local PlayerBases = {}
local BasePartsCache = {}
local ThumbnailCache = {} 
local activeGuis = {} 
local upgradeDebounces = {}
local teleportTasks = {}

-- Constants
local OXYGEN_UPDATE_RATE = 0.25
local NORMAL_MUTATION = "Normal"
local OXYGEN_SAVE_THRESHOLD = 15

local function calculateUpgradePrice(earnings, level)
	local levelFactor = 1
	if level == 2 then
		levelFactor = 1.55
	elseif level > 2 then
		levelFactor = 1.55 * (1.2 ^ (level - 2))
	end
	return math.ceil(earnings * 19.5 * levelFactor)
end

local function handleUpgradeRequest(player, modelID)
	if typeof(modelID) ~= "number" then return end
	
	local now = os.clock()
	if now - (upgradeDebounces[player] or 0) < 0.8 then return end
	upgradeDebounces[player] = now
	
	local base = PlayerBases[player.UserId]
	if not base then return end
	
	local liveModels = base:FindFirstChild("LiveModels")
	if not liveModels then return end
	
	local targetModel = nil
	for _, m in liveModels:GetChildren() do
		if m:GetAttribute("ModelID") == modelID then
			targetModel = m
			break
		end
	end
	
	if not targetModel then return end
	
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	local level = targetModel:GetAttribute("Level") or 1
	local earnings = targetModel:GetAttribute("Earnings") or 0
	local price = calculateUpgradePrice(earnings, level)
	
	if profile.Data.Cash >= price then
		profile:Increment("Cash", -price)
		
		local newLevel = level + 1
		local newEarnings = earnings + 10
		targetModel:SetAttribute("Level", newLevel)
		targetModel:SetAttribute("Earnings", newEarnings)
		
		-- Update profile to persist upgrades
		local padName = targetModel:GetAttribute("PadName")
		if padName then
			local placedModels = profile.Data.PlacedModels or {}
			if placedModels[padName] then
				placedModels[padName].level = newLevel
				placedModels[padName].earnings = newEarnings
				profile:Update("PlacedModels", placedModels)
			end
		end
		
		UpgradeModelRemote:FireClient(player, targetModel)
	end
end

local function captureOriginalSettings(base)
	if BasePartsCache[base] then return end
	BasePartsCache[base] = {}
	
	local function scan(instance)
		if instance:IsA("BasePart") then
			BasePartsCache[base][instance] = {
				Transparency = instance.Transparency,
				CanCollide = instance.CanCollide
			}
		end
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") then
				BasePartsCache[base][descendant] = {
					Transparency = descendant.Transparency,
					CanCollide = descendant.CanCollide
				}
			end
		end
	end
	
	local builds = base:FindFirstChild("Builds")
	if builds then scan(builds) end
	local params = base:FindFirstChild("Pads")
	if params then scan(params) end
end

local function setVisibility(base, instance, visible)
	local cache = BasePartsCache[base]
	if not cache then return end

	local function apply(target)
		if not target:IsA("BasePart") then return end
		local settings = cache[target]
		if visible then
			if settings then
				target.Transparency = settings.Transparency
				target.CanCollide = settings.CanCollide
			end
		else
			target.Transparency = 1
			target.CanCollide = false
		end
	end

	apply(instance)
	for _, descendant in instance:GetDescendants() do
		apply(descendant)
	end
end

local function findModelInfoInConfig(modelName)
	local modelsConfig = Calibration.Get().Models
	for rarity, models in pairs(modelsConfig) do
		if models[modelName] then
			return models[modelName], rarity
		end
	end
	return nil
end

local function updateBillboard(base, player)
	local spawnLoc = base:FindFirstChild("Spawn")
	local billboard = spawnLoc and spawnLoc:FindFirstChild("YourBase")
	
	if player then
		local userId = player.UserId
		local thumbnail = ThumbnailCache[userId]
		
		if billboard then
			billboard.Enabled = true
			local icon = billboard:FindFirstChild("Icon", true)
			local nameLabel = billboard:FindFirstChild("playerName", true)
			
			if nameLabel then nameLabel.Text = "@" .. player.Name .. "'s Base" end
			
			if not thumbnail then
				task.spawn(function()
					local success, content = pcall(function()
						return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
					end)
					if success then
						ThumbnailCache[userId] = content
						if icon then icon.Image = content end
					end
				end)
			elseif icon then
				icon.Image = thumbnail
			end
		end
		
		UpdateBaseBillboard:FireAllClients(base, player.Name, thumbnail)
	else
		if billboard then
			billboard.Enabled = false
			local icon = billboard:FindFirstChild("Icon", true)
			local nameLabel = billboard:FindFirstChild("playerName", true)
			if nameLabel then nameLabel.Text = "" end
			if icon then icon.Image = "" end
		end
		UpdateBaseBillboard:FireAllClients(base, nil, nil)
	end
end

local function hideBaseCompletely(base)
	local builds = base:FindFirstChild("Builds")
	if builds then
		for _, floor in builds:GetChildren() do
			setVisibility(base, floor, false)
		end
	end

	local pads = base:FindFirstChild("Pads")
	if pads then
		for _, pad in pads:GetChildren() do
			pad:SetAttribute("Active", false)
			pad:SetAttribute("Holding", false)
			pad:SetAttribute("HoldingID", 0)
			setVisibility(base, pad, false)
		end
	end

	updateBillboard(base, nil)
end

local function clearSpawnedTools(player)
	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") and CollectionService:HasTag(item, "SpawnedModelTool") then
				item:Destroy()
			end
		end
	end
	
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and CollectionService:HasTag(item, "SpawnedModelTool") then
				item:Destroy()
			end
		end
	end
end

function PlayerHandler.SaveInventory(player)
	local count = 0
	local backpack = player:FindFirstChild("Backpack")
	
	local toolsToSave = {}

	local function processTool(tool)
		if not tool:IsA("Tool") then return end
		
		local isCapturable = CollectionService:HasTag(tool, "SpawnedModelTool") or CollectionService:HasTag(tool, "PlacedModelTool")
		local isSpecial = CollectionService:HasTag(tool, "SpecialTool")
		
		if isCapturable or isSpecial then
			-- Don't save SpawnedModelTools to profile if they are volatile
			if isCapturable then
				count += 1
			end
			
			if not CollectionService:HasTag(tool, "SpawnedModelTool") then
				table.insert(toolsToSave, {
					modelName = tool:GetAttribute("SourceModelName") or tool.Name,
					mutation = tool:GetAttribute("Mutation") or NORMAL_MUTATION,
					rarity = tool:GetAttribute("Rarity") or "Common",
					level = tool:GetAttribute("Level") or 1,
					earnings = tool:GetAttribute("Earnings") or 0,
					isSpecial = isSpecial or nil
				})
			end
		end
	end

	if backpack then
		for _, tool in backpack:GetChildren() do
			processTool(tool)
		end
	end
	
	local character = player.Character
	if character then
		for _, tool in character:GetChildren() do
			processTool(tool)
		end
	end
	
	-- Save to DataService
	local profile = DataService:GetProfile(player)
	if profile then
		profile:Update("InventoryTools", toolsToSave)
	end

	player:SetAttribute("BackpackCount", count)
	return count
end

local function updateCollectedGui(player, gui)
	local profile = DataService:GetProfile(player)
	if not profile or not gui then return end
	
	local count = player:GetAttribute("BackpackCount") or 0
	local backpackLabel = gui:FindFirstChild("Backpack", true)
	local iconImage = gui:FindFirstChild("Icon", true)
	
	if backpackLabel then
		local capacity = profile.Data.BackpackCapacity or 1
		backpackLabel.Text = count .. "/" .. capacity
	end
	
	if iconImage then
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		if not (tool and(CollectionService:HasTag(tool, "SpawnedModelTool") or CollectionService:HasTag(tool, "PlacedModelTool"))) then
			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				for _, t in backpack:GetChildren() do
					if t:IsA("Tool") and (CollectionService:HasTag(t, "SpawnedModelTool") or CollectionService:HasTag(t, "PlacedModelTool")) then
						tool = t
						break
					end
				end
			end
		end
		
		if tool and (CollectionService:HasTag(tool, "SpawnedModelTool") or CollectionService:HasTag(tool, "PlacedModelTool")) then
			local modelData = findModelInfoInConfig(tool.Name)
			if modelData and modelData.Icons then
				local mutation = tool:GetAttribute("Mutation") or NORMAL_MUTATION
				iconImage.Image = modelData.Icons[mutation] or modelData.Icons[NORMAL_MUTATION] or ""
			end
		else
			iconImage.Image = ""
		end
	end
end

function PlayerHandler.UpdateUnlocks(player, rebirthLevel)
	local base = PlayerBases[player.UserId]
	if not base then return end
	
	local builds = base:FindFirstChild("Builds")
	local padsFolder = base:FindFirstChild("Pads")
	
	-- Determine unlocked floors and pads by checking all rebirth configs up to current level
	local unlockedFloors = { ["Floor1"] = true } -- Floor1 is always unlocked
	local unlockedPads = {}
	
	for i = 1, 10 do
		unlockedPads[i] = true -- First 10 pads are default
	end
	
	local configs = Calibration.Get().Rebirths
	for i = 1, rebirthLevel do
		if configs[i] then
			if configs[i].Floor then
				unlockedFloors["Floor" .. configs[i].Floor] = true
			end
			if configs[i].Pad then
				unlockedPads[configs[i].Pad] = true
			end
		end
	end
	
	if builds then
		for _, floor in builds:GetChildren() do
			setVisibility(base, floor, unlockedFloors[floor.Name] == true)
		end
	end
	
	if padsFolder then
		for _, pad in padsFolder:GetChildren() do
			local padId = tonumber(pad.Name)
			if padId then
				local unlocked = unlockedPads[padId] == true
				
				setVisibility(base, pad, unlocked)
				if unlocked and not pad:GetAttribute("Active") then
					pad:SetAttribute("Active", true)
					ModelPlacementHandler.SetupPlacementPrompt(pad, base)
				end
			end
		end
	end
end

function PlayerHandler.GetPlayerBase(player)
	return PlayerBases[player.UserId]
end

local function runOxygenLoop()
	local lastTick = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < OXYGEN_UPDATE_RATE then return end
		local dt = now - lastTick
		lastTick = now
		
		for _, player in Players:GetPlayers() do
			local profile = DataService:GetProfilesCache()[player]
			if not profile then continue end
			
			local timers = oxygenTimers[player]
			if not timers then
				timers = { depletionTimer = 0, regenTimer = 0, exitTime = 0, lastSavedOxygen = profile.Data.Oxygen or 100 }
				oxygenTimers[player] = timers
			end

			local inWater = player:GetAttribute("InWater")
			local currentOxygen = profile.Data.Oxygen or 100
			local maxOxygen = profile.Data.MaxOxygen or 100
			
			if inWater then
				timers.regenTimer = 0
				timers.depletionTimer += dt
				
				if timers.depletionTimer >= 0.25 then
					timers.depletionTimer = 0
					local newOxygen = math.max(0, currentOxygen - 3)
					
					-- Debounce datastore writes: only update profile if significantly changed or reached zero
					if math.abs(newOxygen - timers.lastSavedOxygen) >= OXYGEN_SAVE_THRESHOLD or newOxygen <= 0 then
						profile:Update("Oxygen", newOxygen)
						timers.lastSavedOxygen = newOxygen
					else
						-- Maintain session consistency via attributes even if not saving to profile yet
						profile.Data.Oxygen = newOxygen
					end
					player:SetAttribute("Oxygen", newOxygen)
					
					if newOxygen <= 0 then
						local char = player.Character
						local hum = char and char:FindFirstChild("Humanoid")
						if hum and hum.Health > 0 then
							hum.Health = 0 -- DIRECT HEALTH SET
							char:BreakJoints() -- FORCE DEATH
						end
					end
				end
				
				local char = player.Character
				local head = char and char:FindFirstChild("Head")
				if head then
					local gui = activeGuis[player]
					if not gui then
						gui = COLLECTED_GUI:Clone()
						gui.Adornee = head
						gui.Parent = head
						activeGuis[player] = gui
					end
					updateCollectedGui(player, gui)
				end
			else
				timers.depletionTimer = 0
				local timeSinceExit = os.clock() - timers.exitTime
				
				if currentOxygen < maxOxygen and timeSinceExit >= 0.2 then
					timers.regenTimer += dt
					if timers.regenTimer >= 0.15 then
						timers.regenTimer = 0
						local newOxygen = math.min(maxOxygen, currentOxygen + 28)
						
						if math.abs(newOxygen - timers.lastSavedOxygen) >= OXYGEN_SAVE_THRESHOLD or newOxygen == maxOxygen then
							profile:Update("Oxygen", newOxygen)
							timers.lastSavedOxygen = newOxygen
						else
							profile.Data.Oxygen = newOxygen
						end
						player:SetAttribute("Oxygen", newOxygen)
					end
				else
					timers.regenTimer = 0
				end
				
				if activeGuis[player] then
					activeGuis[player]:Destroy()
					activeGuis[player] = nil
				end
			end
		end
	end)
end

function PlayerHandler.TeleportToSpawn(player, base)
	if teleportTasks[player] then task.cancel(teleportTasks[player]) end
	
	teleportTasks[player] = task.spawn(function()
		local retries = 0
		local maxRetries = 40
		
		while retries < maxRetries do
			if not player:IsDescendantOf(Players) then return end
			
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local spawnPart = base and base:FindFirstChild("Spawn")
			
			if root and spawnPart then
				root.CFrame = spawnPart.CFrame + Vector3.new(0, 5, 0)
				teleportTasks[player] = nil
				return
			end
			
			retries += 1
			task.wait(0.25)
		end
		teleportTasks[player] = nil
	end)
end

local inventoryConnections = {}

local function monitorInventory(player)
	if inventoryConnections[player] then
		for _, conn in pairs(inventoryConnections[player]) do
			conn:Disconnect()
		end
	end
	
	inventoryConnections[player] = {}
	
	local function onChildAdded(child)
		if child:IsA("Tool") then
			PlayerHandler.SaveInventory(player)
		end
	end
	
	local function onChildRemoved(child)
		if child:IsA("Tool") then
			PlayerHandler.SaveInventory(player)
		end
	end
	
	local backpack = player:WaitForChild("Backpack")
	table.insert(inventoryConnections[player], backpack.ChildAdded:Connect(onChildAdded))
	table.insert(inventoryConnections[player], backpack.ChildRemoved:Connect(onChildRemoved))
	
	player.CharacterAdded:Connect(function(char)
		table.insert(inventoryConnections[player], char.ChildAdded:Connect(onChildAdded))
		table.insert(inventoryConnections[player], char.ChildRemoved:Connect(onChildRemoved))
	end)
	
	if player.Character then
		table.insert(inventoryConnections[player], player.Character.ChildAdded:Connect(onChildAdded))
		table.insert(inventoryConnections[player], player.Character.ChildRemoved:Connect(onChildRemoved))
	end
end

function PlayerHandler.Init()
	EnterWater.OnServerEvent:Connect(function(player)
		player:SetAttribute("InWater", true)
	end)

	ExitWater.OnServerEvent:Connect(function(player)
		if oxygenTimers[player] then
			oxygenTimers[player].exitTime = os.clock()
		end
		player:SetAttribute("InWater", false)
	end)

	UpgradeModelRemote.OnServerEvent:Connect(handleUpgradeRequest)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("InWater", false)
		
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			
			-- Ensure standard death logic is enabled
			humanoid.BreakJointsOnDeath = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			
			-- Reset Oxygen on respawn
			local profile = DataService:GetProfile(player)
			if profile then
				local maxO2 = profile.Data.MaxOxygen or 100
				profile:Update("Oxygen", maxO2)
				player:SetAttribute("Oxygen", maxO2)
				if oxygenTimers[player] then
					oxygenTimers[player].lastSavedOxygen = maxO2
				end
			end
			
			local function disableRegen()
				local healthScript = character:FindFirstChild("Health")
				if healthScript then
					healthScript.Disabled = true
					healthScript:Destroy()
				end
			end
			
			disableRegen()
			character.ChildAdded:Connect(function(child)
				if child.Name == "Health" then
					disableRegen()
				end
			end)
			
			humanoid.Died:Connect(function()
				clearSpawnedTools(player)
				PlayerHandler.SaveInventory(player)
			end)

			player:SetAttribute("InWater", false)
			local base = PlayerBases[player.UserId]
			if base then
				PlayerHandler.TeleportToSpawn(player, base)
			end
		end)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		oxygenTimers[player] = nil
		PlayerBases[player.UserId] = nil
		ThumbnailCache[player.UserId] = nil
		upgradeDebounces[player] = nil
		if teleportTasks[player] then
			task.cancel(teleportTasks[player])
			teleportTasks[player] = nil
		end
		if activeGuis[player] then
			activeGuis[player]:Destroy()
			activeGuis[player] = nil
		end
		
		if inventoryConnections[player] then
			for _, conn in pairs(inventoryConnections[player]) do
				conn:Disconnect()
			end
			inventoryConnections[player] = nil
		end
	end)

	for _, base in BASES_FOLDER:GetChildren() do
		base:SetAttribute("Occupied", false)
		base:SetAttribute("ModelIDCount", 0)
		base:SetAttribute("OwnerID", 0)
		
		local liveModels = base:FindFirstChild("LiveModels")
		if not liveModels then
			liveModels = Instance.new("Folder")
			liveModels.Name = "LiveModels"
			liveModels.Parent = base
		end

		local pads = base:FindFirstChild("Pads")
		if pads then
			for _, pad in pads:GetChildren() do
				ModelPlacementHandler.SetupCollectPart(pad, base)
			end
		end

		captureOriginalSettings(base)
		hideBaseCompletely(base)
	end
	
	runOxygenLoop()
	ModelPlacementHandler.RunEarningsLoop(BASES_FOLDER)
	
	DataService.OnProfileLoaded:Connect(function(player)
		local profile = DataService:GetProfile(player)
		if profile then
			-- Restore Oxygen to Max on join
			local maxO2 = profile.Data.MaxOxygen or 100
			profile.Data.Oxygen = maxO2
			player:SetAttribute("Oxygen", maxO2)
			
			-- Restore Tools
			local backpack = player:WaitForChild("Backpack")
			local inventoryTools = profile.Data.InventoryTools or {}
			
			for _, toolData in ipairs(inventoryTools) do
				local model = ReplicatedStorage.Models:FindFirstChild(toolData.modelName)
				if model then
					-- Efficient model reconstruction
					local tool = Instance.new("Tool")
					tool.Name = toolData.modelName
					
					local info = findModelInfoInConfig(toolData.modelName)
					if info and info.Icons then
						tool.TextureId = info.Icons[toolData.mutation] or info.Icons[NORMAL_MUTATION] or ""
					end
					
					tool:SetAttribute("Mutation", toolData.mutation)
					tool:SetAttribute("Rarity", toolData.rarity)
					tool:SetAttribute("Level", toolData.level)
					tool:SetAttribute("Earnings", toolData.earnings)
					tool:SetAttribute("SourceModelName", toolData.modelName)
					
					local rootSource = model.PrimaryPart or model:FindFirstChild("Root") or model:FindFirstChildWhichIsA("BasePart")
					if rootSource then
						local handle = rootSource:Clone()
						handle.Name = "Handle"
						handle.Anchored = false
						handle.CanCollide = false
						handle.Parent = tool
						
						for _, child in model:GetChildren() do
							if child:IsA("BasePart") and child ~= rootSource then
								local p = child:Clone()
								p.Anchored = false
								p.CanCollide = false
								p.Parent = tool
								local weld = Instance.new("WeldConstraint")
								weld.Part0 = handle
								weld.Part1 = p
								weld.Parent = p
							end
						end
					end
					
					if toolData.isSpecial then
						CollectionService:AddTag(tool, "SpecialTool")
						tool:SetAttribute("SpecialTool", true)
					else
						CollectionService:AddTag(tool, "PlacedModelTool")
					end
					tool.Parent = backpack
				end
			end
			
			PlayerHandler.SaveInventory(player)
			monitorInventory(player)
		end

		local InventoryHandler = require(script.Parent:WaitForChild("InventoryHandler"))
		InventoryHandler.UpdateDailyLogin(player)
	end)
end

function PlayerHandler.AssignBase(player, rebirthLevel)
	local availableBases = {}
	for _, base in BASES_FOLDER:GetChildren() do
		if not base:GetAttribute("Occupied") then
			table.insert(availableBases, base)
		end
	end

	if #availableBases == 0 then
		player:Kick("All bases are occupied. Try a new server.")
		return
	end

	local assignedBase = availableBases[math.random(1, #availableBases)]
	assignedBase:SetAttribute("Occupied", true)
	assignedBase:SetAttribute("ModelIDCount", 0)
	assignedBase:SetAttribute("OwnerID", player.UserId)
	
	local ownerValue = assignedBase:FindFirstChild("Owner") or Instance.new("NumberValue", assignedBase)
	ownerValue.Name = "Owner"
	ownerValue.Value = player.UserId
	
	PlayerBases[player.UserId] = assignedBase

	PlayerHandler.UpdateUnlocks(player, rebirthLevel or 0)
	updateBillboard(assignedBase, player)
	
	PlayerHandler.TeleportToSpawn(player, assignedBase)

    task.spawn(function()
        task.wait(1.5)
        assignedBase:SetAttribute("BaseReady", true)

        local profile = DataService:GetProfile(player)
        if profile then
            local lastLogout = profile.Data.LastLogoutTime or 0
            ModelPlacementHandler.CalculateOfflineEarnings(player, profile, lastLogout)
        end
    end)
	
	return assignedBase
end

function PlayerHandler.SwapBase(player, newBasePrefab)
	local oldBase = PlayerBases[player.UserId]
	if not oldBase then return end
    
    oldBase:SetAttribute("BaseReady", false)
	
	local newBase = newBasePrefab:Clone()
	newBase.Name = oldBase.Name
	
	for name, value in pairs(oldBase:GetAttributes()) do
		newBase:SetAttribute(name, value)
	end
    
    newBase:SetAttribute("OwnerID", player.UserId)
	
	local oldSpawn = oldBase:FindFirstChild("Spawn")
	local newSpawn = newBase:FindFirstChild("Spawn")
	
	if oldSpawn and newSpawn then
		local offset = newBase:GetPivot():Inverse() * newSpawn.CFrame
		newBase:PivotTo(oldSpawn.CFrame * offset:Inverse())
	end
	
	local folders = {"LiveModels", "Owner"}
	for _, folderName in ipairs(folders) do
		local oldFolder = oldBase:FindFirstChild(folderName)
		local newFolder = newBase:FindFirstChild(folderName)
		
		if oldFolder then
			if newFolder then newFolder:Destroy() end
			oldFolder.Parent = newBase
		end
	end
	
	updateBillboard(newBase, player)
	
	PlayerBases[player.UserId] = newBase
	newBase.Parent = BASES_FOLDER
	
	captureOriginalSettings(newBase)
	
	local profile = DataService:GetProfile(player)
	local rebirthLevel = profile and profile.Data.Rebirths or 0
	PlayerHandler.UpdateUnlocks(player, rebirthLevel)
	
	oldBase:Destroy()
	
	local pads = newBase:FindFirstChild("Pads")
    local liveModels = newBase:FindFirstChild("LiveModels")
	if pads then
		for _, pad in pads:GetChildren() do
            pad:SetAttribute("Holding", false)
            pad:SetAttribute("HoldingID", nil)
            
			ModelPlacementHandler.SetupCollectPart(pad, newBase)
			if pad:GetAttribute("Active") then
				ModelPlacementHandler.SetupPlacementPrompt(pad, newBase)
			end
		end
	end

    if liveModels and pads then
        for _, model in ipairs(liveModels:GetChildren()) do
            local padName = model:GetAttribute("PadName")
            local pad = pads:FindFirstChild(padName)
            if pad then
                pad:SetAttribute("Holding", true)
                pad:SetAttribute("HoldingID", model:GetAttribute("ModelID"))
                
                task.defer(function()
                    REMOTES:WaitForChild("SpawnModel"):FireClient(player, model, {
                        mutation = model:GetAttribute("Mutation") or NORMAL_MUTATION,
                        earnings = model:GetAttribute("Earnings") or 0,
                        rarity = model:GetAttribute("Rarity") or "Common",
                        timer = 0,
                        cframe = model:GetPivot(),
                        isPlaced = true,
                        pad = pad
                    })
                end)
            end
        end
    end
	
	PlayerHandler.TeleportToSpawn(player, newBase)
    
    task.defer(function()
        task.wait(1)
        newBase:SetAttribute("BaseReady", true)
    end)
	
	return newBase
end

function PlayerHandler.ReleaseBase(player)
	local base = PlayerBases[player.UserId]
	if base then
		base:SetAttribute("Occupied", false)
		base:SetAttribute("ModelIDCount", 0)
		base:SetAttribute("OwnerID", 0)
        base:SetAttribute("BaseReady", false)
        
		local ownerValue = base:FindFirstChild("Owner")
		if ownerValue then ownerValue.Value = 0 end
        
        -- Cleanup models
        local liveModels = base:FindFirstChild("LiveModels")
        if liveModels then
            liveModels:ClearAllChildren()
        end
        
        -- Cleanup floating GUIs on pads
        local pads = base:FindFirstChild("Pads")
        if pads then
            for _, pad in pads:GetChildren() do
                local collect = pad:FindFirstChild("Collect")
                if collect then
                    local gui = collect:FindFirstChild("CollectorGui")
                    if gui then gui:Destroy() end
                end
            end
        end

		hideBaseCompletely(base)
		PlayerBases[player.UserId] = nil
	end
end

return PlayerHandler
