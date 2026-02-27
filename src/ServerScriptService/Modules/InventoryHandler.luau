local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DataService = require(script.Parent:WaitForChild("DataService"))
local Calibration = require(ReplicatedStorage.Modules.Calibration)
local Anti = require(ReplicatedStorage:WaitForChild("Persistence"):WaitForChild("Anti"))
local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local UPDATE_COLLECTION = REMOTES:WaitForChild("UpdateCollection")
local CLAIM_DAILY = REMOTES:WaitForChild("ClaimDailyReward")
local UPDATE_DAILY = REMOTES:WaitForChild("UpdateDailyReward")
local Notify = REMOTES:WaitForChild("Notify")

local InventoryHandler = {}

local DAY_SECONDS = 24 * 60 * 60
local BUFF_DURATION = 15 * 60
local NORMAL_MUTATION = "Normal"

local claimDebounces = {}
local sellDebounces = {}

local function getBaseSpeed(player)
	local profile = DataService:GetProfile(player)
	local rebirths = profile and profile.Data.Rebirths or 0
	return 16 + (rebirths * 10)
end

local function applySpeedBoost(player)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	local now = os.time()
	local boostEndTime = profile.Data.SpeedBoostEndTime or 0
	
	if now < boostEndTime then
		local char = player.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if hum then
			-- Store original speed if not already stored
			if not profile.Data.OriginalSpeed then
				profile:Update("OriginalSpeed", hum.WalkSpeed)
			end
			hum.WalkSpeed = getBaseSpeed(player) * 2
		end
	end
end

function InventoryHandler.UpdateDailyLogin(player)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	local now = os.time()
	profile:Update("LastLoginTime", now)
	UPDATE_DAILY:FireClient(player, profile.Data.DailyDay, profile.Data.LastClaimTime)
end

local function findModelInfoInConfig(modelName)
	for rarity, models in pairs(Calibration.Get().Models) do
		if models[modelName] then
			return models[modelName], rarity
		end
	end
	return nil
end

function InventoryHandler.ClaimReward(player)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	-- Server-side debounce
	local now = os.time()
	if now - (claimDebounces[player] or 0) < 2 then return end
	claimDebounces[player] = now
	
	local lastClaim = profile.Data.LastClaimTime or 0
	local currentDay = profile.Data.DailyDay or 1
	
	-- Server-authoritative time validation
	if lastClaim ~= 0 and (now - lastClaim) < DAY_SECONDS then
		Notify:FireClient(player, "Daily Reward can't be collected yet", false)
		warn("[InventoryHandler] Player " .. player.Name .. " tried to claim reward too early")
		return
	end
	
	-- Distribute Reward
	if currentDay == 1 or currentDay == 6 then
		-- 2x speed for 15 mins
		local endTime = now + BUFF_DURATION
		profile:Update("SpeedBoostEndTime", endTime)
		applySpeedBoost(player)
	elseif currentDay == 2 or currentDay == 4 then
		local modelName = if currentDay == 2 then "Rolls Car" else "Green Car"
		local model = ReplicatedStorage.Models:FindFirstChild(modelName)
		if model then
			local tool = Instance.new("Tool")
			tool.Name = modelName
			
			local info, rarity = findModelInfoInConfig(modelName)
			tool.TextureId = info and info.Icons and info.Icons[NORMAL_MUTATION] or ""
			
			local root = model.PrimaryPart:Clone()
			root.Name = "Handle"
			root.Anchored = false
			root.CanCollide = false
			root.Parent = tool
			
			for _, child in model:GetChildren() do
				if child:IsA("BasePart") and child ~= model.PrimaryPart then
					local p = child:Clone()
					p.Anchored = false
					p.CanCollide = false
					p.Parent = tool
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = p
					weld.Parent = p
				end
			end
			
			tool:SetAttribute("Mutation", NORMAL_MUTATION)
			tool:SetAttribute("Rarity", rarity or "Uncommon")
			tool:SetAttribute("Level", 1)
			tool:SetAttribute("Earnings", info and info.Earnings or 0)
			tool:SetAttribute("SourceModelName", modelName)
			CollectionService:AddTag(tool, "DailyReward")
			CollectionService:AddTag(tool, "PlacedModelTool")
			tool.Parent = player:WaitForChild("Backpack")
		end
	elseif currentDay == 3 or currentDay == 5 or currentDay == 7 then
		profile:Increment("Cash", 10000)
	end
	
	-- Update state
	profile:Update("LastClaimTime", now)
	local nextDay = currentDay + 1
	if nextDay > 7 then nextDay = 1 end
	profile:Update("DailyDay", nextDay)
	
	UPDATE_DAILY:FireClient(player, nextDay, now)
	Notify:FireClient(player, "Daily reward collected!", true)
end



function InventoryHandler.AddToCollections(player, modelName, mutation, rarity)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	mutation = mutation or NORMAL_MUTATION
	rarity = rarity or "Common"
	local collectionKey = string.format("%s | %s [%s]", rarity, modelName, mutation)
	
	-- Secure Collections mutation by ensuring defaults are used
	local collections = profile.Data.Collections
	if not table.find(collections, collectionKey) then
		table.insert(collections, collectionKey)
		profile:Update("Collections", collections)
		
		local RebirthHandler = require(script.Parent:WaitForChild("RebirthHandler"))
		RebirthHandler.CheckRequirements(player, (profile.Data.Rebirths or 0) + 1)
	end
	
	UPDATE_COLLECTION:FireClient(player, collections)
end

function InventoryHandler.ProcessSell(player)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	-- Server-side debounce
	local now = os.clock()
	if now - (sellDebounces[player] or 0) < 1 then return end
	sellDebounces[player] = now
	
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	if not backpack then return end
	
	local toolsDictionary = {}
	
	local function addValidTool(tool)
		if not tool:IsA("Tool") then return end
		if not (CollectionService:HasTag(tool, "SpawnedModelTool") or CollectionService:HasTag(tool, "PlacedModelTool") or CollectionService:HasTag(tool, "SpecialTool")) then return end
		
		-- Server-Authoritative Validation: Verify tool against ModelsConfig and profile data
		local modelName = tool:GetAttribute("SourceModelName") or tool.Name
		local rarity = tool:GetAttribute("Rarity")
		local mutation = tool:GetAttribute("Mutation")
		
		local info, configRarity = findModelInfoInConfig(modelName)
		if not info or (rarity and rarity ~= configRarity) then
			warn("[InventoryHandler] Player " .. player.Name .. " tried to sell invalid tool: " .. tool.Name)
			return
		end

		if CollectionService:HasTag(tool, "SpecialTool") then
			toolsDictionary[tool] = true
			return
		end

		local foundInInventory = false
		for _, savedTool in ipairs(profile.Data.InventoryTools) do
			if savedTool.modelName == modelName and savedTool.mutation == mutation then
				foundInInventory = true
				break
			end
		end

		if CollectionService:HasTag(tool, "PlacedModelTool") and not foundInInventory and not CollectionService:HasTag(tool, "DailyReward") then
			warn("[InventoryHandler] Player " .. player.Name .. " tried to sell tool not in saved inventory")
		end

		toolsDictionary[tool] = true
	end
	
	for _, tool in backpack:GetChildren() do
		addValidTool(tool)
	end
	
	if character then
		local equippedTool = character:FindFirstChildOfClass("Tool")
		if equippedTool then
			addValidTool(equippedTool)
		end
	end
	
	local toolsToSell = {}
	for tool, _ in pairs(toolsDictionary) do
		table.insert(toolsToSell, tool)
	end

	if #toolsToSell == 0 then return end
	
	local totalEarnings = 0
	for _, tool in toolsToSell do
		local modelName = tool:GetAttribute("SourceModelName") or tool.Name
		
		totalEarnings += Calibration.GetSellValue(modelName)
		tool:Destroy()
	end
	
	profile:Increment("Cash", totalEarnings)
	Notify:FireClient(player, "Sold inventory for $" .. totalEarnings .. "!", true)
end

function InventoryHandler.Init()
	game.Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applySpeedBoost(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		claimDebounces[player] = nil
		sellDebounces[player] = nil
	end)

	CLAIM_DAILY.OnServerEvent:Connect(function(player)
		InventoryHandler.ClaimReward(player)
	end)

	local important = Workspace:WaitForChild("Map"):WaitForChild("Important")
	local sellPart = important:WaitForChild("Sell"):WaitForChild("Touchpart")
	local sellPrompt = sellPart:WaitForChild("SellPrompt")
	
	sellPrompt.Triggered:Connect(function(player)
		InventoryHandler.ProcessSell(player)
	end)

	-- Heartbeat loop for Speed Boost restoration and Anti-Exploit
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(game.Players:GetPlayers()) do
			-- Anti-Exploit Tick
			Anti.ValidateMovement(player)
			Anti.CheckNetworkOwnership(player)

			-- Speed Boost Expiration Check (Safe restoration)
			local profile = DataService:GetProfile(player)
			if profile then
				local now = os.time()
				local boostEndTime = profile.Data.SpeedBoostEndTime or 0
				local char = player.Character
				local hum = char and char:FindFirstChild("Humanoid")
				
				if hum then
					if now < boostEndTime then
						-- Ensure speed is active if within time
						local targetSpeed = getBaseSpeed(player) * 2
						if hum.WalkSpeed ~= targetSpeed then
							hum.WalkSpeed = targetSpeed
						end
					elseif profile.Data.OriginalSpeed then
						-- Restore original speed when boost expires
						hum.WalkSpeed = profile.Data.OriginalSpeed
						profile:Update("OriginalSpeed", nil)
					end
				end
			end
		end
	end)
end

return InventoryHandler
