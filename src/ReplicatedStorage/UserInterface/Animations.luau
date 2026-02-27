local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Animations = {}

local Sounds = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Sound")
local UiClickSound = Sounds:WaitForChild("UiClick")
local UiHoverSound = Sounds:WaitForChild("UiHover")

local ZONE_DATA = {
	Common = { Studs = 13, Color = Color3.fromRGB(95, 95, 95) },
	Uncommon = { Studs = 42, Color = Color3.fromRGB(170, 255, 0) },
	Rare = { Studs = 102, Color = Color3.fromRGB(85, 170, 255) },
	Epic = { Studs = 134, Color = Color3.fromRGB(255, 170, 0) },
	Legendary = { Studs = 243, Color = Color3.fromRGB(255, 85, 0) },
	Mythical = { Studs = 300, Color = Color3.fromRGB(255, 0, 0) },
	Cosmic = { Studs = 160, Color = Color3.fromRGB(170, 0, 255) },
	Secret = { Studs = 140, Color = Color3.fromRGB(35, 35, 35) }
}

local function formatNumber(n)
	local suffixes = {
		{1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"},
		{1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}
	}
	for _, suffix in ipairs(suffixes) do
		if n >= suffix[1] then
			return string.format("$%.2f%s", n / suffix[1], suffix[2])
		end
	end
	return "$" .. math.floor(n)
end

local function pulse(instance)
	local scale = instance:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = instance
	
	scale.Scale = 1.1
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function setupContinuousRotation(hud)
	local rotators = {
		hud:WaitForChild("Pack"):WaitForChild("Sunburst"),
		hud:WaitForChild("Shark"):WaitForChild("Sunburst")
	}
	
	local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	
	for _, sunburst in rotators do
		local tween = TweenService:Create(sunburst, tweenInfo, {Rotation = 360})
		tween:Play()
	end
end

local function setupZoneDetection(hud)
	local topHolder = hud:WaitForChild("TopHolder")
	local zoneLabel = topHolder:WaitForChild("ZoneName")
	local scale = zoneLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = zoneLabel
	
	local zonesFolder = workspace:WaitForChild("Zones")
	local currentZone = nil
	local tween = nil
	
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then 
			zoneLabel.Visible = false
			return 
		end
		
		local hrpPos = character.HumanoidRootPart.Position
		local foundZone = nil
		
		for _, zonePart in zonesFolder:GetChildren() do
			if not zonePart:IsA("BasePart") then continue end
			
			local data = ZONE_DATA[zonePart.Name]
			if not data then continue end
			
			local distY = hrpPos.Y - zonePart.Position.Y
			local distXZ = Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(zonePart.Position.X, 0, zonePart.Position.Z)
			
			if distY > 0 and distY <= data.Studs and distXZ.Magnitude < zonePart.Size.X/2 then
				foundZone = { Name = zonePart.Name, Color = data.Color }
				break
			end
		end
		
		if foundZone then
			if currentZone ~= foundZone.Name then
				currentZone = foundZone.Name
				zoneLabel.Text = foundZone.Name .. " Area"
				zoneLabel.TextColor3 = foundZone.Color
				zoneLabel.Visible = true
				
				if tween then tween:Cancel() end
				scale.Scale = 0
				tween = TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
				tween:Play()
			end
		else
			currentZone = nil
			zoneLabel.Visible = false
			scale.Scale = 0
		end
	end)
end

local function setupPlayerDepth(hud)
	local depth = hud:WaitForChild("Depth")
	local playersFrame = depth:WaitForChild("Players")
	local template = playersFrame:WaitForChild("Template")
	template.Visible = false
	
	local playerIcons = {}
	
	local function getYScale(worldY)
		local alpha = math.clamp((worldY - 303) / (-99 - 303), 0, 1)
		return 0.03 + alpha * (0.97 - 0.03)
	end
	
	local function addPlayer(player)
		local icon = template:Clone()
		icon.Name = player.Name
		icon.Visible = true
		icon.Parent = playersFrame
		
		local img = icon:IsA("ImageLabel") and icon or icon:FindFirstChildOfClass("ImageLabel")
		if img then
			task.spawn(function()
				local success, content = pcall(function()
					return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if success then
					img.Image = content
				end
			end)
		end
		
		playerIcons[player] = icon
	end
	
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		if playerIcons[player] then
			playerIcons[player]:Destroy()
			playerIcons[player] = nil
		end
	end)
	
	RunService.Heartbeat:Connect(function()
		for player, icon in playerIcons do
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local y = char.HumanoidRootPart.Position.Y
				icon.Position = UDim2.new(0.5, 0, getYScale(y), 0)
			end
		end
	end)
end

function Animations.ToggleFrame(frame, state)
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	
	local player = Players.LocalPlayer
	local pGui = player:WaitForChild("PlayerGui")

	if state then
		if frame:GetAttribute("Active") then return end
		
		-- Force all other ACTIVE frames to close first
		local main = pGui:WaitForChild("Main")
		local frames = main:FindFirstChild("Frames")
		if frames then
			for _, f in frames:GetChildren() do
				if f:IsA("GuiObject") and f ~= frame and f:GetAttribute("Active") == true then
					Animations.ToggleFrame(f, false)
				end
			end
		end

		frame.Visible = true
		frame:SetAttribute("Active", true)
		scale.Scale = 0
		TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	else
		if not frame:GetAttribute("Active") then return end
		frame:SetAttribute("Active", false)
		local tween = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0})
		tween:Play()
		tween.Completed:Connect(function()
			if frame:GetAttribute("Active") == false then
				frame.Visible = false
			end
		end)
	end

	local anyActive = false
	local main = pGui:WaitForChild("Main")
	if main then
		local frames = main:FindFirstChild("Frames")
		if frames then
			for _, f in frames:GetChildren() do
				if f:IsA("Frame") and f:GetAttribute("Active") == true then
					anyActive = true
					break
				end
			end
		end
	end
	
	local camera = workspace.CurrentCamera
	local targetFOV = anyActive and 55 or 70 
	local targetBlur = anyActive and 12 or 0
	
	TweenService:Create(camera, TweenInfo.new(0.5), {FieldOfView = targetFOV}):Play()
	local blur = Lighting:FindFirstChild("UiBlur")
	if blur then
		TweenService:Create(blur, TweenInfo.new(0.5), {Size = targetBlur}):Play()
	end
end

local function setupButton(button)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	
	button.MouseEnter:Connect(function()
		UiHoverSound:Play()
		TweenService:Create(scale, TweenInfo.new(0.2), {Scale = 1.05}):Play()
	end)
	
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2), {Scale = 1}):Play()
	end)
	
	button.MouseButton1Down:Connect(function()
		UiClickSound:Play()
		pulse(button)
	end)
end

function Animations.Init()
	local player = Players.LocalPlayer
	local pGui = player:WaitForChild("PlayerGui")
	local main = pGui:WaitForChild("Main")
	local hud = main:WaitForChild("HUD")
	local currencyHolder = hud:WaitForChild("CurrenyHolder")
	
	local blur = Lighting:FindFirstChild("UiBlur") or Instance.new("BlurEffect")
	blur.Name = "UiBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local moneyFrame = currencyHolder:WaitForChild("Money")
	local oxygenFrame = currencyHolder:WaitForChild("Oxygen")
	
	local cashTitle = moneyFrame:WaitForChild("Title")
	local oxygenTitle = oxygenFrame:WaitForChild("Title")
	
	local lastCash = player:GetAttribute("Cash") or 0
	cashTitle.Text = formatNumber(lastCash)
	
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local newCash = player:GetAttribute("Cash") or 0
		pulse(moneyFrame)
		
		local startValue = lastCash
		lastCash = newCash
		
		task.spawn(function()
			local duration = 0.5
			local elapsed = 0
			while elapsed < duration do
				elapsed += task.wait()
				local t = elapsed / duration
				local current = startValue + (newCash - startValue) * t
				cashTitle.Text = formatNumber(math.floor(current))
			end
			cashTitle.Text = formatNumber(newCash)
		end)
	end)
	
	player:GetAttributeChangedSignal("Oxygen"):Connect(function()
		local val = player:GetAttribute("Oxygen") or 0
		oxygenTitle.Text = tostring(math.floor(val))
		pulse(oxygenFrame)
	end)
	
	oxygenTitle.Text = tostring(math.floor(player:GetAttribute("Oxygen") or 0))

	for _, button in CollectionService:GetTagged("ButtonAnim") do
		setupButton(button)
	end
	
	CollectionService:GetInstanceAddedSignal("ButtonAnim"):Connect(function(instance)
		if (instance:IsA("ImageButton") or instance:IsA("TextButton")) then
			setupButton(instance)
		end
	end)
	
	setupZoneDetection(hud)
	setupPlayerDepth(hud)
	setupContinuousRotation(hud)
end

return Animations
