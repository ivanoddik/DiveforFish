local Anti = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local MAX_GRAVITY_DELTA = 300
local STRIKE_LIMIT = 5
local TICK_RATE = 0.5
local RAYCAST_BUFFER = 0.5

-- State
local playerState = {} -- [player] = { lastPos, strikes, lastTick }

function Anti.ValidateMovement(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	local state = playerState[player]
	if not state then
		playerState[player] = { lastPos = root.Position, strikes = 0, lastTick = os.clock() }
		return
	end
	
	local currentPos = root.Position
	local delta = (currentPos - state.lastPos)
	local verticalDist = math.abs(delta.Y)
	local timeElapsed = os.clock() - state.lastTick
	
	if timeElapsed < 0.1 then return end
	
	local suspicious = false
	
	-- 1. Vertical Delta (Teleport/Fly)
	if verticalDist > MAX_GRAVITY_DELTA then
		suspicious = true
	end
	
	-- 2. Raycast Noclip check
	if delta.Magnitude > 3 then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character}
		
		local result = workspace:Raycast(state.lastPos, delta, params)
		if result and result.Instance and result.Instance.CanCollide then
			-- Ensure they actually passed THROUGH it, not just hit it
			local throughCheck = workspace:Raycast(currentPos, -delta, params)
			if throughCheck and throughCheck.Instance == result.Instance then
				suspicious = true
			end
		end
	end
	
	if suspicious then
		state.strikes += 1
		root.CFrame = CFrame.new(state.lastPos) -- Rubberband
		
		if state.strikes >= STRIKE_LIMIT then
			player:Kick("[Anti-Exploit] Abnormal gameplay detected.")
		end
	else
		state.lastPos = currentPos
		state.lastTick = os.clock()
		state.strikes = math.max(0, state.strikes - 0.1) -- Slow decay
	end
end

function Anti.CheckNetworkOwnership(player)
	local character = player.Character
	if not character then return end
	
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if part.ReceiveAge > 0 and part:GetNetworkOwner() ~= player then
				-- Hardening: Force ownership if it drifts or is manipulated
				pcall(function() part:SetNetworkOwner(player) end)
			end
		end
	end
end

function Anti.Init()
	Players.PlayerAdded:Connect(function(player)
		playerState[player] = nil
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		playerState[player] = nil
	end)
	
	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			Anti.ValidateMovement(player)
			Anti.CheckNetworkOwnership(player)
		end
	end)
end

return Anti
