local Notifications = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local mainGui = pGui:WaitForChild("Main")
local hud = mainGui:WaitForChild("HUD")
local holder = hud:WaitForChild("NotificationHolder")

local validTemplate = holder:WaitForChild("ValidNotification")
local invalidTemplate = holder:WaitForChild("InvalidNotification")
local tutorialDisplay = holder:WaitForChild("TutorialDisplay")

local SOUND_FOLDER = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Sound")
local NOTIFICATION_SOUND = SOUND_FOLDER:WaitForChild("Notification")
local ERROR_SOUND = SOUND_FOLDER:WaitForChild("Error")

local CONFETTI_SOUND = SOUND_FOLDER:WaitForChild("Confetti")

-- Constants
local DISPLAY_TIME = 2.3
local FADE_TIME = 0.35
local MAX_STACK = 10

-- Capture original sizes
local VALID_SIZE = validTemplate.Size
local INVALID_SIZE = invalidTemplate.Size

-- State
local activeNotifications = {}

validTemplate.Visible = false
invalidTemplate.Visible = false
tutorialDisplay.Visible = false

local function playConfetti()
	CONFETTI_SOUND:Play()
	local screenGui = pGui:WaitForChild("Main")
	local colors = {Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255)}
	
	for i = 1, 30 do
		task.spawn(function()
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromOffset(math.random(10, 20), math.random(10, 20))
			frame.Position = UDim2.new(math.random(), 0, -0.1, 0)
			frame.BackgroundColor3 = colors[math.random(1, #colors)]
			frame.Rotation = math.random(0, 360)
			frame.BorderSizePixel = 0
			frame.Parent = screenGui
			
			local tweenInfo = TweenInfo.new(math.random(2, 4), Enum.EasingStyle.Linear)
			local tween = TweenService:Create(frame, tweenInfo, {
				Position = UDim2.new(frame.Position.X.Scale, 0, 1.1, 0),
				Rotation = frame.Rotation + math.random(180, 720),
				BackgroundTransparency = 1
			})
			tween:Play()
			tween.Completed:Connect(function() frame:Destroy() end)
		end)
	end
end

local function animateIn(label, targetSize)
	label.Size = UDim2.new(0, 0, 0, 0)
	label.Visible = true
	
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Size = targetSize }):Play()
end

local function animateOut(label)
	local info = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(label, info, { Size = UDim2.new(0, 0, 0, 0) })
	tween:Play()
	tween.Completed:Wait()
	label:Destroy()
end

function Notifications.Show(text, isValid)
	local stack = activeNotifications[text]
	
	if stack then
		stack.count = math.min(stack.count + 1, MAX_STACK)
		stack.timer = DISPLAY_TIME
		stack.instance.Text = string.format("%s (x%d)", text, stack.count)
		
		if isValid then NOTIFICATION_SOUND:Play() else ERROR_SOUND:Play() end
		local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
		local bounceSize = UDim2.new(
			stack.originalSize.X.Scale * 1.1, stack.originalSize.X.Offset,
			stack.originalSize.Y.Scale * 1.1, stack.originalSize.Y.Offset
		)
		TweenService:Create(stack.instance, info, { Size = bounceSize }):Play()
		return
	end
	
	local template = isValid and validTemplate or invalidTemplate
	local originalSize = isValid and VALID_SIZE or INVALID_SIZE
	
	local clone = template:Clone()
	clone.Text = text
	clone.Name = "ActiveNotification"
	clone.Parent = holder
	
	activeNotifications[text] = {
		instance = clone,
		count = 1,
		timer = DISPLAY_TIME,
		originalSize = originalSize
	}
	
	if isValid then NOTIFICATION_SOUND:Play() else ERROR_SOUND:Play() end
	animateIn(clone, originalSize)
	
	-- Handle removal
	task.spawn(function()
		while activeNotifications[text] and activeNotifications[text].timer > 0 do
			local dt = task.wait(0.1)
			if activeNotifications[text] then
				activeNotifications[text].timer -= dt
			end
		end
		
		if activeNotifications[text] then
			local inst = activeNotifications[text].instance
			activeNotifications[text] = nil
			animateOut(inst)
		end
	end)
end

function Notifications.Init()
	local REMOTES = ReplicatedStorage:WaitForChild("Remotes")
	local Notify = REMOTES:WaitForChild("Notify")
	local UpdateTutorial = REMOTES:WaitForChild("UpdateTutorial")
	
	Notify.OnClientEvent:Connect(function(text, isValid)
		Notifications.Show(text, isValid)
		if text == "Thank you for your purchase!" then
			playConfetti()
		end
	end)
	
	UpdateTutorial.OnClientEvent:Connect(function(step, text)
		local label = tutorialDisplay:FindFirstChildWhichIsA("TextLabel") or tutorialDisplay
		
		if step == 0 then -- Temporary message
			label.Text = text
			tutorialDisplay.Visible = true
			task.delay(3, function()
				if label.Text == text then
					tutorialDisplay.Visible = false
				end
			end)
		elseif step == 5 then -- Completed Tutorial
			label.Text = text
			tutorialDisplay.Visible = true
			playConfetti()
			task.delay(3, function()
				if label.Text == text then
					tutorialDisplay.Visible = false
				end
			end)
		else
			label.Text = text
			tutorialDisplay.Visible = true
		end
	end)
end

return Notifications
