local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local DataService = require(ServerScriptService.Modules.DataService)
local PlayerHandler = require(ServerScriptService.Modules.PlayerHandler)
local RebirthHandler = require(ServerScriptService.Modules.RebirthHandler)
local ModelHandler = require(ServerScriptService.Modules.ModelHandler)
local InventoryHandler = require(ServerScriptService.Modules.InventoryHandler)
local MonetizationHandler = require(ServerScriptService.Modules.MonetizationHandler)
local UpgradeHandler = require(ServerScriptService.Modules.UpgradeHandler)
local TutorialHandler = require(ServerScriptService.Modules.TutorialHandler)
local Anti = require(game:GetService("ReplicatedStorage").Persistence.Anti)

local function onPlayerAdded(player)
	local profile
	while true do
		profile = DataService:GetProfile(player)
		if profile then break end
		if not player:IsDescendantOf(Players) then return end
		task.wait(2)
	end
	
	local rebirthLevel = profile.Data.Rebirths or 0
	PlayerHandler.AssignBase(player, rebirthLevel)
end

local isInitialized = false
task.spawn(function()
	local liveModels = Workspace:FindFirstChild("LiveModels")
	if not liveModels then
		liveModels = Instance.new("Folder")
		liveModels.Name = "LiveModels"
		liveModels.Parent = Workspace
	end

	DataService:Init()
	PlayerHandler.Init()
	RebirthHandler.Init()
	ModelHandler.Init()
	InventoryHandler.Init()
	MonetizationHandler.Init()
	UpgradeHandler.Init()
	TutorialHandler.Init()
	Anti.Init()
	isInitialized = true
end)

task.spawn(function()
	while not isInitialized do task.wait() end
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerHandler.ReleaseBase(player)
end)

-- print("[MainServer] Server initialization complete with guards")
