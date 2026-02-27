local RebirthHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local DataService = require(ServerScriptService.Modules.DataService)
local PlayerHandler = require(ServerScriptService.Modules.PlayerHandler)
local Calibration = require(ReplicatedStorage.Modules.Calibration)
local Anti = require(ReplicatedStorage.Persistence.Anti)

-- CONFIGURATION
local SPEED_BOOST_PASS_ID = 1729255670
local REBIRTH_DEBOUNCE = 2

-- STATE
local playerDebounces = {}
local ownershipCache = {}

local function getBaseWalkSpeed(player, rebirths)
	return 16 + (rebirths * 10)
end

function RebirthHandler.ApplyRebirthBoosts(player, profile)
	local rebirths = profile.Data.Rebirths or 0
	
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local baseSpeed = getBaseWalkSpeed(player, rebirths)
		local multiplier = 1
		
		-- Use cached ownership
		local hasSpeedBoost = false
		if ownershipCache[player] and ownershipCache[player][SPEED_BOOST_PASS_ID] ~= nil then
			hasSpeedBoost = ownershipCache[player][SPEED_BOOST_PASS_ID]
		else
			local success, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, SPEED_BOOST_PASS_ID)
			end)
			if success then
				hasSpeedBoost = result
				if not ownershipCache[player] then ownershipCache[player] = {} end
				ownershipCache[player][SPEED_BOOST_PASS_ID] = hasSpeedBoost
			end
		end
		
		if hasSpeedBoost then
			multiplier += 0.2
		end
		humanoid.WalkSpeed = baseSpeed * multiplier
		
		profile:Update("OriginalSpeed", baseSpeed)
	end
end

function RebirthHandler.CheckRequirements(player, level)
	local profile = DataService:GetProfile(player)
	if not profile then return false end
	
	local rebirthConfig = Calibration.Get().Rebirths[level]
	if not rebirthConfig then return false end
	
	-- Check Oxygen
	local requiredOxygen = Calibration.GetOxygenRequirement(level)
	if (profile.Data.Oxygen or 0) < requiredOxygen then
		return false
	end
	
	-- Check Models (DataService guarantees Collections is a table)
	local collections = profile.Data.Collections or {}
	local validMutations = {"Normal", "Gold", "Diamond", "Emerald", "Blood"}
	
	for _, modelName in rebirthConfig.Models do
		local rarity
		for r, models in pairs(Calibration.Get().Models) do
			if models[modelName] then
				rarity = r
				break
			end
		end

		if not rarity then continue end

		local found = false
		for _, mutation in validMutations do
			local collectionKey = string.format("%s | %s [%s]", rarity, modelName, mutation)
			if table.find(collections, collectionKey) then
				found = true
				break
			end
		end
		
		if not found then return false end
	end
	
	return true
end

function RebirthHandler.ProcessRebirth(player, level)
	-- Security: Rate limiting
	local now = os.clock()
	if playerDebounces[player] and (now - playerDebounces[player]) < REBIRTH_DEBOUNCE then
		return
	end
	playerDebounces[player] = now

	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	local currentRebirths = profile.Data.Rebirths or 0
	
	if level ~= currentRebirths + 1 then 
		ReplicatedStorage.Remotes.Notify:FireClient(player, "Invalid rebirth level progression", false)
		return 
	end

	if not Calibration.Get().Rebirths[level] then return end
	
	if not RebirthHandler.CheckRequirements(player, level) then
		ReplicatedStorage.Remotes.Notify:FireClient(player, "Requirements not completed", false)
		return
	end
	
	profile:Update("Rebirths", level)
	profile:Update("Oxygen", 100)
	profile:Update("MaxOxygen", 100)
	profile:Update("Cash", 0)
	
	RebirthHandler.ApplyRebirthBoosts(player, profile)
	PlayerHandler.UpdateUnlocks(player, level)
	ReplicatedStorage.Remotes.Notify:FireClient(player, "Rebirthed successfully!", true)
end

function RebirthHandler.ProcessSkip(player)
	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	local nextRebirth = (profile.Data.Rebirths or 0) + 1
	if not Calibration.Get().Rebirths[nextRebirth] then return end
	
	profile:Update("Rebirths", nextRebirth)
	profile:Update("Cash", 0)
	
	RebirthHandler.ApplyRebirthBoosts(player, profile)
	PlayerHandler.UpdateUnlocks(player, nextRebirth)
end

function RebirthHandler.Init()
	Players.PlayerAdded:Connect(function(player)
		ownershipCache[player] = {}
		
		player.CharacterAdded:Connect(function()
			local profile = DataService:GetProfile(player)
			if profile then
				RebirthHandler.ApplyRebirthBoosts(player, profile)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerDebounces[player] = nil
		ownershipCache[player] = nil
	end)

	-- Anti integration
	if Anti and Anti.Init then
	end
end

return RebirthHandler
