local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TutorialHandler = {}

local DataService = require(ServerScriptService.Modules.DataService)

local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local NOTIFY = REMOTES:WaitForChild("Notify")
local UPDATE_TUTORIAL = REMOTES:FindFirstChild("UpdateTutorial")
if not UPDATE_TUTORIAL then
	UPDATE_TUTORIAL = Instance.new("RemoteEvent")
	UPDATE_TUTORIAL.Name = "UpdateTutorial"
	UPDATE_TUTORIAL.Parent = REMOTES
end

local TUTORIAL_DATA = {
	[1] = {Text = "Dive in and find a car!", Reward = 0},
	[2] = {Text = "Bring it back to your base!", Reward = 0},
	[3] = {Text = "Collect your money!", Reward = 0},
	[4] = {Text = "Upgrade your oxygen!", Reward = 500}
}

local playerTutorials = {} 

local function cleanupTutorial(player)
	local data = playerTutorials[player]
	if not data then return end
	
	for _, conn in pairs(data.Connections) do
		conn:Disconnect()
	end
	
	playerTutorials[player] = nil
end

local function updateClient(player)
	local data = playerTutorials[player]
	if not data then return end
	
	UPDATE_TUTORIAL:FireClient(player, data.Step, TUTORIAL_DATA[data.Step].Text)
end

function TutorialHandler.AdvanceStep(player, fromStep)
	local data = playerTutorials[player]
	if not data then return end
	
	local currentStep = math.clamp(data.Step, 1, 4)
	if fromStep and currentStep ~= fromStep then 
		return 
	end
	
	data.Step = currentStep + 1
	
	local profile = DataService:GetProfile(player)
	if profile then
		profile:Update("TutorialStep", data.Step)
	end
	
	if data.Step > 4 then
		UPDATE_TUTORIAL:FireClient(player, 5, "Completed Tutorial!")
		
		if profile then
			profile:Update("TutorialCompleted", true)
		end
		
		task.delay(2, function()
			cleanupTutorial(player)
		end)
		return
	end
	
	updateClient(player)
	TutorialHandler.SetupStep(player)
end

function TutorialHandler.SetupStep(player)
	local data = playerTutorials[player]
	if not data then return end
	
	for _, conn in pairs(data.Connections) do conn:Disconnect() end
	data.Connections = {}
	
	if data.Step == 3 then
		if data.LastPlacedCollect and data.LastPlacedCollect.Parent then
			local conn
			conn = data.LastPlacedCollect.Touched:Connect(function(hit)
				if hit.Parent == player.Character and data.Step == 3 then
					TutorialHandler.AdvanceStep(player, 3)
				end
			end)
			table.insert(data.Connections, conn)
		end
		
	elseif data.Step == 4 then
		local important = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Important")
		local oxygenPart = important and important:FindFirstChild("Oxygen") and important.Oxygen:FindFirstChild("Touchpart")
		
		if oxygenPart then
			local conn
			conn = oxygenPart.Touched:Connect(function(hit)
				if hit.Parent == player.Character and not data.CashRewarded then
					data.CashRewarded = true
					
					local profile = DataService:GetProfile(player)
					if profile then
						profile:Increment("Cash", 500)
						NOTIFY:FireClient(player, "Reward: 500 CASH!", true)
					end
				end
			end)
			table.insert(data.Connections, conn)
		end
	end
end

function TutorialHandler.OnModelCaptured(player)
	local data = playerTutorials[player]
	if not data then return end
	
	local now = os.clock()
	if data.Debounces.Captured and (now - data.Debounces.Captured) < 1 then return end
	data.Debounces.Captured = now
	
	TutorialHandler.AdvanceStep(player, 1)
end

function TutorialHandler.OnModelPlaced(player, collectPart)
	local data = playerTutorials[player]
	if not data or data.Step ~= 2 then return end
	
	local now = os.clock()
	if data.Debounces.Placed and (now - data.Debounces.Placed) < 1 then return end
	data.Debounces.Placed = now
	
	data.LastPlacedCollect = collectPart
	TutorialHandler.AdvanceStep(player, 2)
end

function TutorialHandler.OnUpgradePerformed(player)
	local data = playerTutorials[player]
	if not data or data.Step ~= 4 then return end
	
	local now = os.clock()
	if data.Debounces.Upgrade and (now - data.Debounces.Upgrade) < 1 then return end
	data.Debounces.Upgrade = now
	
	TutorialHandler.AdvanceStep(player, 4)
end

function TutorialHandler.Init()
	DataService.OnProfileLoaded:Connect(function(player, profile)
		if profile.Data.TutorialCompleted then
			return
		end
		
		local savedStep = math.clamp(profile.Data.TutorialStep or 1, 1, 4)
		playerTutorials[player] = {
			Step = savedStep, 
			Connections = {}, 
			LastPlacedCollect = nil, 
			CashRewarded = false,
			Debounces = {}
		}
		
		local function onChar(char)
			task.wait(0.5) -- Ensure client is ready
			if playerTutorials[player] then
				TutorialHandler.SetupStep(player)
				updateClient(player)
			end
		end

		if player.Character then
			task.spawn(onChar, player.Character)
		end
		player.CharacterAdded:Connect(onChar)
	end)
	
	Players.PlayerRemoving:Connect(cleanupTutorial)
end

return TutorialHandler
