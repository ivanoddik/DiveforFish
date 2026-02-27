if not game:IsLoaded() then
	game.Loaded:Wait()
end

local userInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local isTouchScreen = userInputService.TouchEnabled

local notifications = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Notifications"))
local swimModule = require(script:WaitForChild("Libraries"):WaitForChild("SwimModule"))
local lightingModule = require(script:WaitForChild("Libraries"):WaitForChild("UnderwaterLighting"))

local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
local STORAGE = ReplicatedStorage:WaitForChild("Storage")
local SOUNDS = STORAGE:WaitForChild("Sound")
local SPLASH_SOUND = SOUNDS:WaitForChild("Splash")

local EnterWater = REMOTES:WaitForChild("EnterWater")
local ExitWater = REMOTES:WaitForChild("ExitWater")

local plr = game:GetService("Players").LocalPlayer
local pGui = plr:WaitForChild("PlayerGui")
local mainGui = pGui:WaitForChild("Main")
local hud = mainGui:WaitForChild("HUD")
local topHolder = hud:WaitForChild("TopHolder")
local oxygenFrame = topHolder:WaitForChild("Oxygen")
local oxygenBar = oxygenFrame:WaitForChild("Bar")
local oxygenScale = oxygenFrame:FindFirstChildOfClass("UIScale")

local blueGradient = oxygenBar:WaitForChild("BlueGradient")
local yellowGradient = oxygenBar:WaitForChild("YellowGradient")
local redGradient = oxygenBar:WaitForChild("RedGradient")

local char = plr.Character or plr.CharacterAdded:Wait()
repeat task.wait() until char:FindFirstChildOfClass("Humanoid")
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

local tag = script.Configuration:GetAttribute("CollectionServiceTag") or "Water"
local folder = script.PartFolder.Value
local CollectionService = game:GetService("CollectionService")

local waterParts = {}
local function updateWaterParts()
	if folder then
		waterParts = folder:GetChildren()
	else
		waterParts = CollectionService:GetTagged(tag)
	end
end
updateWaterParts()

local headInWater = nil
local bodyInWater = false
local lastOxygen = 100
local currentOxygenTween = nil
local oxygenWarningSent = false

local function updateOxygenUI(oxygen)
	local maxOxygen = plr:GetAttribute("MaxOxygen") or 100
	local scale = math.clamp(oxygen / maxOxygen, 0, 1)
	
	if currentOxygenTween then currentOxygenTween:Cancel() end
	
	local percentage = (oxygen / maxOxygen) * 100
	
	-- Handle large increases or resets (more than 50% jump) with instant set or specific tween
	local immediateUpdate = math.abs((oxygen - lastOxygen) / maxOxygen) > 0.5
	
	if immediateUpdate then
		oxygenBar.Size = UDim2.fromScale(scale, 1)
	else
		local barTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		currentOxygenTween = TweenService:Create(oxygenBar, barTweenInfo, {Size = UDim2.fromScale(scale, 1)})
		currentOxygenTween:Play()
	end
	
	redGradient.Enabled = percentage < 25
	yellowGradient.Enabled = percentage >= 25 and percentage < 60
	blueGradient.Enabled = percentage >= 60
	
	if percentage < 25 and not oxygenWarningSent then
		oxygenWarningSent = true
		notifications.Show("Warning low oxygen!", false)
	elseif percentage >= 25 and oxygenWarningSent then
		oxygenWarningSent = false
	end
	
	if oxygen >= maxOxygen and lastOxygen < maxOxygen then
		if oxygenScale then
			local bounceInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local tweenBack = TweenService:Create(oxygenScale, bounceInfo, {Scale = 1.2})
			tweenBack:Play()
			tweenBack.Completed:Connect(function()
				TweenService:Create(oxygenScale, TweenInfo.new(0.15), {Scale = 1}):Play()
			end)
		end
		SPLASH_SOUND:Play()
	end
	lastOxygen = oxygen
end

plr.CharacterAdded:Connect(function(newChar)
	char = newChar
	hum = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
	
	-- Reset Tracking
	headInWater = nil
	cameraInWater = nil
	
	-- Instant Bar Reset on Spawn
	if oxygenBar then
		oxygenBar.Size = UDim2.fromScale(1, 1)
	end
	if blueGradient then blueGradient.Enabled = true end
	if yellowGradient then yellowGradient.Enabled = false end
	if redGradient then redGradient.Enabled = false end
end)

plr:GetAttributeChangedSignal("Oxygen"):Connect(function()
	updateOxygenUI(plr:GetAttribute("Oxygen") or 100)
end)

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local updateInterval = 0.1
local lastUpdate = 0
local mobileExitDebounce = false

RunService.Heartbeat:Connect(function()
	if os.clock() - lastUpdate < updateInterval then return end
	lastUpdate = os.clock()

	updateWaterParts()
	overlapParams.FilterDescendantsInstances = waterParts

	local head = char:FindFirstChild("Head")
	-- Point at the very top of the head
	local headPos = head and (head.Position + Vector3.new(0, head.Size.Y / 2, 0)) or hrp.Position + Vector3.new(0, 2, 0)

	-- Precise check for the very top surface of the head
	local isHeadIn = #workspace:GetPartBoundsInRadius(headPos, 0.1, overlapParams) > 0
	
	-- Broad detection for lower/upper territory
	local isUpperIn = #workspace:GetPartBoundsInRadius(hrp.Position + Vector3.new(0, 1, 0), 0.7, overlapParams) > 0
	local isLowerIn = #workspace:GetPartBoundsInRadius(hrp.Position + Vector3.new(0, -2.572, 0), 0.7, overlapParams) > 0
	
	local frontPos = hrp.CFrame * Vector3.new(0, 0, -1.5)
	local isFrontIn = #workspace:GetPartBoundsInRadius(frontPos, 0.5, overlapParams) > 0

	-- NEW Precise Surface constraint call
	swimModule:UpdateSurfaceConstraint(hrp.Position, waterParts, isFrontIn)

	if isUpperIn then
		swimModule:Start()
		bodyInWater = true
	elseif not isUpperIn and not isLowerIn then
		swimModule:Stop()
		bodyInWater = false
	elseif not isUpperIn and isLowerIn then
		-- No longer exit based on jump status here to prevent physics glitches
		swimModule:Start()
		bodyInWater = true
	end

	-- Enforce lighting state based on HeadInWater instead of camera
	if isHeadIn then
		lightingModule:Add()
	else
		lightingModule:Remove()
	end

	-- Check for head state change to fire RemoteEvents (fires on first check due to nil initialization)
	if isHeadIn ~= headInWater then
		headInWater = isHeadIn
		if headInWater then 
			EnterWater:FireServer() 
		else 
			ExitWater:FireServer() 
		end
	end
end)

hum.Died:Connect(function()
	lightingModule:Remove()
	swimModule:Stop()
end)

-- Ensure lighting is removed if player is no longer in water (double safety)
char.ChildRemoved:Connect(function(child)
    if child:IsA("Humanoid") then
        lightingModule:Remove()
        swimModule:Stop()
    end
end)
