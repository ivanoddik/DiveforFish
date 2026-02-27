-- Made by gpm231 (Modified)

local module = {}

local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local player = players.LocalPlayer

local atmos = script:WaitForChild("Atmosphere")
local sky = script:WaitForChild("Sky")
local blur = script:WaitForChild("Blur")
local colorCorrection = script:WaitForChild("ColorCorrection")

local previousObjects = {}
local oxygenConn

local enabled = false

local function updateVisuals(oxygen)
	if not blur or not colorCorrection then return end
	
	-- Oxygen <= 40 sets Blur 0->2
	-- Oxygen <= 20 sets Blur 4 and TintColor 255,157,157
	-- Oxygen == 0 sets TintColor smoothly to 147, 51, 51 with 0.5s delay
	if oxygen <= 0 then
		blur.Size = 4
		task.delay(0.5, function()
			if not enabled then return end
			tweenService:Create(colorCorrection, TweenInfo.new(0.5), {
				TintColor = Color3.fromRGB(147, 51, 51)
			}):Play()
		end)
	elseif oxygen <= 20 then
		blur.Size = 4
		colorCorrection.TintColor = Color3.fromRGB(255, 157, 157)
	elseif oxygen <= 40 then
		blur.Size = 2
		colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	else
		blur.Size = 0
		colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	end
end

function module:Add()
	if enabled then return end
	enabled = true

	-- Move existing lighting objects into script
	for _, v in ipairs(lighting:GetChildren()) do
		if v:IsA("PostProcessEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
			v.Parent = script
			table.insert(previousObjects, v)
		end
	end

	-- Apply new lighting setup
	atmos.Parent = lighting
	sky.Parent = lighting
	blur.Parent = lighting
	colorCorrection.Parent = lighting

	-- Visual updates based on Oxygen attribute
	oxygenConn = player:GetAttributeChangedSignal("Oxygen"):Connect(function()
		updateVisuals(player:GetAttribute("Oxygen") or 100)
	end)
	updateVisuals(player:GetAttribute("Oxygen") or 100)
end

function module:Remove()
	if not enabled then return end
	enabled = false

	if oxygenConn then
		oxygenConn:Disconnect()
		oxygenConn = nil
	end

	-- Restore previous lighting objects
	for _, v in ipairs(previousObjects) do
		if v and v.Parent == script then
			v.Parent = lighting
		end
	end

	-- Reset custom effects back to script
	atmos.Parent = script
	sky.Parent = script
	blur.Parent = script
	colorCorrection.Parent = script
	
	-- Reset visuals
	blur.Size = 0
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)

	table.clear(previousObjects)
end

return module
