local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Animations"))
local Monetization = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Monetization"))
local Player = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Player"))
local Notifications = require(ReplicatedStorage:WaitForChild("UserInterface"):WaitForChild("Notifications"))

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local mainGui = pGui:WaitForChild("Main")
local hud = mainGui:WaitForChild("HUD")
local toggleButton = hud:WaitForChild("ToggleMusic")

local SOUND_FOLDER = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Sound")
local musicList = {
	SOUND_FOLDER:WaitForChild("Music1"),
	SOUND_FOLDER:WaitForChild("Music2"),
	SOUND_FOLDER:WaitForChild("Music3")
}

local ICON_PLAY = "rbxassetid://136478212701181"
local ICON_PAUSE = "rbxassetid://89582676721488"

local currentMusicIndex = math.random(1, #musicList)
local isPaused = false

local function playNextMusic()
	local currentMusic = musicList[currentMusicIndex]
	
	if not isPaused then
		currentMusic:Play()
	end
	
	local connection
	connection = currentMusic.Ended:Connect(function()
		connection:Disconnect()
		currentMusicIndex = (currentMusicIndex % #musicList) + 1
		playNextMusic()
	end)
end

toggleButton.MouseButton1Click:Connect(function()
	local currentMusic = musicList[currentMusicIndex]
	isPaused = not isPaused
	
	if isPaused then
		currentMusic:Pause()
		toggleButton.Image = ICON_PAUSE
	else
		currentMusic:Resume()
		toggleButton.Image = ICON_PLAY
	end
end)

-- Initialize
Animations.Init()
Monetization.Init()
Player.Init()
Notifications.Init()
toggleButton.Image = ICON_PLAY
playNextMusic()
