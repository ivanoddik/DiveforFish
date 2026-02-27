local UpgradeHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Modules.DataService)
local PlayerHandler = require(ServerScriptService.Modules.PlayerHandler)
local TutorialHandler = require(ServerScriptService.Modules.TutorialHandler)
local Anti = require(ReplicatedStorage.Persistence.Anti)

-- CONFIGURATION
local BACKPACK_UPGRADE_COSTS = {
	[1] = 500_000,
	[2] = 25_000_000,
	[3] = 1_000_000_000,
	[4] = 750_000_000_000,
}

local DEBOUNCE_TIME = 0.5

-- STATE
local playerDebounces = {}
local priceCache = {} 

-- PRICING LOGIC
local function getUpgradePrice(statName, playerProfile)
	local oxygenLevel = playerProfile.Data.OxygenUpgradeLevel or 0
	
	if statName == "Oxygen1" then
		local basePrice = 500
		local currentIncrement = 25
		local totalPrice = basePrice
		
		for i = 1, oxygenLevel do
			totalPrice += currentIncrement
			currentIncrement += 1
		end
		return totalPrice
		
	elseif statName == "Oxygen5" then
		local basePrice = 2800
		local currentIncrement = 30
		local totalPrice = basePrice
		
		for i = 1, oxygenLevel do
			totalPrice += currentIncrement
			if i % 2 == 0 then
				currentIncrement += 2
			end
		end
		return totalPrice
		
	elseif statName == "Oxygen10" then
		local basePrice = 6300
		local currentIncrement = 35
		local totalPrice = basePrice
		
		for i = 1, oxygenLevel do
			totalPrice += currentIncrement
			if i % 2 == 0 then
				currentIncrement += 3
			end
		end
		return totalPrice
		
	elseif statName == "Backpack" then
		local backpackLevel = (playerProfile.Data.BackpackUpgrades or 0) + 1
		return BACKPACK_UPGRADE_COSTS[backpackLevel] or math.huge
	end
	
	return math.huge
end

-- Optimization: Atomic update for Oxygen
function UpgradeHandler.ApplyOxygenUpgrade(player, increment, price)
	local profile = DataService:GetProfile(player)
	if not profile then return false end
	
	if price and profile.Data.Cash < price then return false end
	
	local dataKey = increment == 1 and "OxygenUpgrades1" or increment == 5 and "OxygenUpgrades5" or "OxygenUpgrades10"
	
	profile:BatchUpdate(function(data)
		if price then data.Cash -= price end
		data[dataKey] = (data[dataKey] or 0) + 1
		data.OxygenUpgradeLevel = (data.OxygenUpgradeLevel or 0) + 1
		data.MaxOxygen = (data.MaxOxygen or 0) + increment
		data.Oxygen = (data.Oxygen or 0) + increment
		return true
	end)
	
	player:SetAttribute("MaxOxygen", profile.Data.MaxOxygen)
	player:SetAttribute("Oxygen", profile.Data.Oxygen)
	player:SetAttribute("OxygenUpgradeLevel", profile.Data.OxygenUpgradeLevel)
	player:SetAttribute(dataKey, profile.Data[dataKey])
	player:SetAttribute("Cash", profile.Data.Cash)
	
	return true
end

function UpgradeHandler.ApplyBackpackUpgrade(player, price)
	local profile = DataService:GetProfile(player)
	if not profile then return false end
	
	if price and profile.Data.Cash < price then return false end

	local success = false
	profile:BatchUpdate(function(data)
		if price then data.Cash -= price end
		data.BackpackUpgrades = (data.BackpackUpgrades or 0) + 1
		data.BackpackCapacity = (data.BackpackCapacity or 1) + 1
		success = true
		return true
	end)
	
	if success then
		player:SetAttribute("BackpackUpgrades", profile.Data.BackpackUpgrades)
		player:SetAttribute("BackpackCapacity", profile.Data.BackpackCapacity)
		player:SetAttribute("Cash", profile.Data.Cash)
		
		local Notify = ReplicatedStorage.Remotes.Notify
		Notify:FireClient(player, "Upgraded Carry!", true)
		
		TutorialHandler.OnUpgradePerformed(player)
	end

	return success
end

-- UPGRADE EXECUTION
local function handleUpgradeStat(player, statName)
	local now = os.clock()
	if playerDebounces[player] and (now - playerDebounces[player]) < DEBOUNCE_TIME then
		return
	end
	playerDebounces[player] = now

	local profile = DataService:GetProfile(player)
	if not profile then return end
	
	local incrementValue = 0
	local isLevelCapped = false
	
	if statName == "Oxygen1" then
		incrementValue = 1
	elseif statName == "Oxygen5" then
		incrementValue = 5
	elseif statName == "Oxygen10" then
		incrementValue = 10
	elseif statName == "Backpack" then
		incrementValue = 1
		if (profile.Data.BackpackUpgrades or 0) >= #BACKPACK_UPGRADE_COSTS then
			isLevelCapped = true
		end
	else
		return
	end

	local Notify = ReplicatedStorage.Remotes.Notify
	if isLevelCapped then
		Notify:FireClient(player, "Upgrade Maxed Out!", false)
		return
	end
	
	if not priceCache[player] then priceCache[player] = {} end
	local price = priceCache[player][statName] or getUpgradePrice(statName, profile)
	
	if profile.Data.Cash >= price then
		local success = false
		
		if statName == "Backpack" then
			success = UpgradeHandler.ApplyBackpackUpgrade(player, price)
		else
			-- Oxygen tiers
			success = UpgradeHandler.ApplyOxygenUpgrade(player, incrementValue, price)
			if success then
				Notify:FireClient(player, "Upgraded Oxygen!", true)
				TutorialHandler.OnUpgradePerformed(player)
			end
		end
		
		if success then
			-- Invalidate cache after modification
			priceCache[player][statName] = getUpgradePrice(statName, profile)
		end
	else
		Notify:FireClient(player, "Can't afford upgrade", false)
	end
end

function UpgradeHandler.Init()
	local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
	local UpgradeStat = REMOTES:WaitForChild("UpgradeStat") or Instance.new("RemoteEvent", REMOTES)
	UpgradeStat.Name = "UpgradeStat"
	
	UpgradeStat.OnServerEvent:Connect(handleUpgradeStat)

	Players.PlayerRemoving:Connect(function(player)
		playerDebounces[player] = nil
		priceCache[player] = nil
	end)

	if Anti and Anti.Init then
	end
end

return UpgradeHandler