local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Persistence = ReplicatedStorage:WaitForChild("Persistence")
local ProfileService = require(Persistence:WaitForChild("ProfileService"))
local Signal = require(Persistence:WaitForChild("Signal"))

local DataService = {}
DataService.PlayerProfiles = {}
DataService.OnProfileLoaded = Signal.new()

-- Constants
local TESTING_MODE = false
local PROFILE_STORE_NAME = "Play3"

local DEFAULT_DATA = {
	Cash = 0,
	Rebirths = 0,
	Rebirth = 0,
	Oxygen = 100,
	MaxOxygen = 100,
	OxygenUpgrades1 = 0,
	OxygenUpgrades5 = 0,
	OxygenUpgrades10 = 0,
	OxygenUpgradeLevel = 0,
	BackpackUpgrades = 0,
	CarryLevel = 1,
	BackpackCapacity = 1,
	Collections = {},
	DailyDay = 1,
	LastClaimTime = 0,
	LastLoginTime = 0,
	LastLogoutTime = 0,
	PlacedModels = {},
	InventoryTools = {},
	TutorialCompleted = false,
}

-- Validation Schema (Simple type checking)
local VALIDATION_SCHEMA = {
	Cash = "number",
	Rebirths = "number",
	Rebirth = "number",
	Oxygen = "number",
	MaxOxygen = "number",
	OxygenUpgrades1 = "number",
	OxygenUpgrades5 = "number",
	OxygenUpgrades10 = "number",
	OxygenUpgradeLevel = "number",
	BackpackUpgrades = "number",
	CarryLevel = "number",
	BackpackCapacity = "number",
	Collections = "table",
	DailyDay = "number",
	LastClaimTime = "number",
	LastLoginTime = "number",
	LastLogoutTime = "number",
	PlacedModels = "table",
	InventoryTools = "table",
	TutorialCompleted = "boolean",
}

-- Multipliers Config
local MULTIPLIERS = {
	Premium = 1.1, -- 10% bonus
}

local ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, DEFAULT_DATA)

if TESTING_MODE then
	ProfileStore = ProfileStore.Mock
	warn("DataService :: [MOCKUP] Profiles loaded for testing")
else
	print("DataService :: [NORM] Standard profiles loaded for normal profiles")
end

-- Profile Class
local PlayerProfile = {}
PlayerProfile.__index = PlayerProfile

function PlayerProfile.new(player, profile)
	local self = setmetatable({}, PlayerProfile)
	self.Player = player
	self.Profile = profile
	self.Data = profile.Data
	self.DataChanged = Signal.new()
	self._leaderstats = nil
	self.CurrentMultiplier = 1
	
	self:Verify()
	self:Reconcile()
	self:SetupLeaderstats()
	self:CheckMultipliers()
	
	-- Set initial attributes
	player:SetAttribute("Cash", self.Data.Cash or 0)
	player:SetAttribute("Rebirths", self.Data.Rebirths or 0)
	player:SetAttribute("MaxOxygen", self.Data.MaxOxygen or 100)
	player:SetAttribute("CarryLevel", self.Data.CarryLevel or 1)
	player:SetAttribute("BackpackCapacity", self.Data.BackpackCapacity or 1)
	player:SetAttribute("OxygenUpgrades1", self.Data.OxygenUpgrades1 or 0)
	player:SetAttribute("OxygenUpgrades5", self.Data.OxygenUpgrades5 or 0)
	player:SetAttribute("OxygenUpgrades10", self.Data.OxygenUpgrades10 or 0)
	player:SetAttribute("BackpackUpgrades", self.Data.BackpackUpgrades or 0)
	player:SetAttribute("Collections", game:GetService("HttpService"):JSONEncode(self.Data.Collections or {}))
	
	-- Tutorial Tracking Attributes
	player:SetAttribute("TutorialStep", self.Data.TutorialStep or 1)
	player:SetAttribute("TutorialComplete", self.Data.TutorialCompleted or false)
	
	return self
end

function PlayerProfile:Verify()
	for key, expectedType in pairs(VALIDATION_SCHEMA) do
		if self.Data[key] == nil then
			self.Data[key] = DEFAULT_DATA[key]
		elseif type(self.Data[key]) ~= expectedType then
			warn(string.format("[DataService] Data validation failed for %s: %s expected %s, got %s", self.Player.Name, key, expectedType, type(self.Data[key])))
			self.Data[key] = DEFAULT_DATA[key]
		end
	end
end

function PlayerProfile:Reconcile()
	self.Profile:Reconcile()
end

function PlayerProfile:SetupLeaderstats()
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = self.Data.Cash
	cash.Parent = leaderstats
	
	local rebirths = Instance.new("NumberValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = self.Data.Rebirths
	rebirths.Parent = leaderstats
	
	self._leaderstats = leaderstats
	leaderstats.Parent = self.Player
end

function PlayerProfile:CheckMultipliers()
	local multiplier = 1
	
	if self.Player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= MULTIPLIERS.Premium
	end
	
	self.CurrentMultiplier = multiplier
end

function PlayerProfile:Update(key, value)
	if self.Data[key] == value then return end
	
	self.Data[key] = value
	
	-- Sync leaderstats
	if self._leaderstats then
		local stat = self._leaderstats:FindFirstChild(key)
		if stat then
			stat.Value = value
		end
	end
	
	-- Sync relevant attributes
	if key == "Cash" or key == "Rebirths" or key == "BackpackCapacity" or key == "MaxOxygen" or key == "CarryLevel" 
		or key == "OxygenUpgrades1" or key == "OxygenUpgrades5" or key == "OxygenUpgrades10" or key == "BackpackUpgrades" 
		or key == "TutorialStep" then
		self.Player:SetAttribute(key, value)
	elseif key == "TutorialCompleted" then
		self.Player:SetAttribute("TutorialComplete", value)
	elseif key == "Collections" then
		self.Player:SetAttribute("Collections", game:GetService("HttpService"):JSONEncode(value or {}))
	end
	
	self.DataChanged:Fire(key, value)
end

function PlayerProfile:Increment(key, amount)
	local newValue = (self.Data[key] or 0) + amount
	self:Update(key, newValue)
end

function PlayerProfile:BatchUpdate(callback)
	local success = callback(self.Data)
	if success then
		-- Sync all possible relevant keys (attributes/leaderstats)
		local keysToSync = {
			"Cash", "Rebirths", "BackpackCapacity", "MaxOxygen", "CarryLevel", 
			"OxygenUpgrades1", "OxygenUpgrades5", "OxygenUpgrades10", "BackpackUpgrades", 
			"TutorialStep", "Collections", "Oxygen", "OxygenUpgradeLevel"
		}
		
		for _, key in ipairs(keysToSync) do
			local value = self.Data[key]
			-- leaderstats sync
			if self._leaderstats then
				local stat = self._leaderstats:FindFirstChild(key)
				if stat then
					stat.Value = value or 0
				end
			end
			
			-- attribute sync
			if key == "Collections" then
				self.Player:SetAttribute("Collections", game:GetService("HttpService"):JSONEncode(value or {}))
			else
				self.Player:SetAttribute(key, value)
			end
		end
		
		self.DataChanged:Fire("BatchUpdate", self.Data)
	end
	return success
end

function PlayerProfile:Release()
	if self.Profile then
		self.Profile:Release()
		self.Profile = nil
	end
	self.DataChanged:Destroy()
end

-- DataService Core
local function OnPlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	
	if profile ~= nil then
		profile:ListenToRelease(function()
			DataService:RemoveProfile(player)
			player:Kick("[DataService] Profile was released. This usually happens when you join another server.")
		end)

		if player:IsDescendantOf(Players) then
			local wrappedProfile = PlayerProfile.new(player, profile)
			DataService.PlayerProfiles[player] = wrappedProfile
			DataService.OnProfileLoaded:Fire(player, wrappedProfile)
		else
			profile:Release()
		end
	else
		player:Kick("[DataService] Failed to load data. Please rejoin.")
	end
end

function DataService:Init()
	for _, player in Players:GetPlayers() do
		task.spawn(OnPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		self:RemoveProfile(player)
	end)
	
	game:BindToClose(function()
		for player, _ in self.PlayerProfiles do
			self:RemoveProfile(player)
		end
	end)
end

function DataService:GetProfilesCache()
	return self.PlayerProfiles
end

function DataService:GetProfile(player)
	return self.PlayerProfiles[player]
end

function DataService:RemoveProfile(player)
	local wrappedProfile = self.PlayerProfiles[player]
	if wrappedProfile then
		wrappedProfile:Update("LastLogoutTime", os.time())
		wrappedProfile:Release()
		self.PlayerProfiles[player] = nil
	end
end

return DataService
