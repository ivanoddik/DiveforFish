local UpgradeHandler = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Modules.DataService)
local PlayerHandler = require(ServerScriptService.Modules.PlayerHandler)
local TutorialHandler = require(ServerScriptService.Modules.TutorialHandler)
local Calibration = require(ReplicatedStorage.Modules.Calibration)
local Anti = require(ReplicatedStorage.Persistence.Anti)

local DEBOUNCE_TIME = 0.5

-- STATE
local playerDebounces = {}
local priceCache = {} 

-- PRICING LOGIC
local function getUpgradePrice(statName, playerProfile)
	local oxygenLevel = playerProfile.Data.OxygenUpgradeLevel or 0
	local backpackLevel = playerProfile.Data.BackpackUpgrades or 0
	
	return Calibration.GetUpgradePrice(statName, oxygenLevel, backpackLevel)
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
		local cfg = Calibration.Get().Upgrades["Backpack"]
		local costs = cfg and cfg.Costs or {}
		if (profile.Data.BackpackUpgrades or 0) >= #costs then
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