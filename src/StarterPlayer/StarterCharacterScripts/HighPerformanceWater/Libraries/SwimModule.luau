local runService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local swimModule = {}
swimModule.__index = swimModule
if runService:IsServer() then return end

local plr = game:GetService("Players").LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()

repeat task.wait() until char:FindFirstChildOfClass("Humanoid")
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- Constants
local ROTATION_SPEED = 15
local ASCEND_DESCEND_SPEED = 1.2
local SWIM_EXIT_HEIGHT = 2.0 -- Studs above surface to force exit swimming
local SWIM_JUMP_ACTION = "SwimJumpAction"

-- Overlap params for Detection
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

-- State management
local function setHumanoidPhysicsMode(active)
	if active then
		-- Disable all other states while in water
		for _, state in Enum.HumanoidStateType:GetEnumItems() do
			if state ~= Enum.HumanoidStateType.Swimming and state ~= Enum.HumanoidStateType.None then
				-- Wrap in pcall to silently ignore restricted engine states
				pcall(function()
					hum:SetStateEnabled(state, false)
				end)
			end
		end
		
		-- Ensure ONLY Swimming is enabled
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
			hum:ChangeState(Enum.HumanoidStateType.Swimming)
		end)
		
		hum.AutoRotate = false
		hum.PlatformStand = false
	else
		hum.PlatformStand = false
		hum.AutoRotate = true
		
		-- Re-enable all states when leaving water
		for _, state in Enum.HumanoidStateType:GetEnumItems() do
			if state ~= Enum.HumanoidStateType.None then
				pcall(function()
					hum:SetStateEnabled(state, true)
				end)
			end
		end
		
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
end

-- Physics controllers
local atts, forces, linVels, alignOris = {}, {}, {}, {}

local function setupPhysics(on)
	if on then
		if #atts > 0 then return end
		
		local mass = 0
		for _, part in char:GetDescendants() do
			if part:IsA("BasePart") then
				mass += part:GetMass()
			end
		end

		local att = Instance.new("Attachment")
		att.Name = "SwimAttachment"
		att.Parent = hrp
		table.insert(atts, att)

		local force = Instance.new("VectorForce")
		force.Name = "SwimBuoyancy"
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.Force = Vector3.new(0, workspace.Gravity * mass, 0)
		force.Attachment0 = att
		force.ApplyAtCenterOfMass = true
		force.Parent = hrp
		table.insert(forces, force)

		local linVel = Instance.new("LinearVelocity")
		linVel.Name = "SwimVelocity"
		linVel.MaxForce = mass * 1000
		linVel.RelativeTo = Enum.ActuatorRelativeTo.World
		linVel.Attachment0 = att
		linVel.VectorVelocity = Vector3.zero
		linVel.Enabled = true
		linVel.Parent = hrp
		table.insert(linVels, linVel)

		local alignOri = Instance.new("AlignOrientation")
		alignOri.Name = "SwimOrientation"
		alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOri.Attachment0 = att
		alignOri.MaxTorque = mass * 100000
		alignOri.Responsiveness = ROTATION_SPEED
		alignOri.CFrame = hrp.CFrame
		alignOri.Enabled = true
		alignOri.Parent = hrp
		table.insert(alignOris, alignOri)
	else
		for _, list in {atts, forces, linVels, alignOris} do
			for _, v in list do if v.Parent then v:Destroy() end end
			table.clear(list)
		end
	end
end

local isJumpingFlag = false
local function handleJumpAction(actionName, inputState, inputObject)
	if actionName == SWIM_JUMP_ACTION then
		if inputState == Enum.UserInputState.Begin then
			isJumpingFlag = true
		elseif inputState == Enum.UserInputState.End then
			isJumpingFlag = false
		end
		return Enum.ContextActionResult.Sink -- Sink Jump input to prevent Humanoid jumping
	end
end

local function getRawInput()
	local move = hum.MoveDirection
	
	-- Vertical movement
	local vertical = 0
	
	-- Strict physics-only vertical ascent: Never read hum.Jump
	if isJumpingFlag or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		vertical += ASCEND_DESCEND_SPEED 
	end
	
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then 
		vertical -= ASCEND_DESCEND_SPEED 
	end
	
	return move, vertical
end

function swimModule:Start()
	if runService:IsServer() then return end
	if self.Enabled then return end
	
	setHumanoidPhysicsMode(true)
	setupPhysics(true)
	
	-- Bind Jump input to sink it and use our own flag for vertical ascent
	ContextActionService:BindAction(SWIM_JUMP_ACTION, handleJumpAction, true, Enum.KeyCode.Space, Enum.PlayerActions.CharacterJump)
	
	self.Enabled = true
	
	self.RSConnection = runService.Heartbeat:Connect(function(dt)
		local moveDir, verticalValue = getRawInput()
		local linVel = hrp:FindFirstChild("SwimVelocity")
		local alignOri = hrp:FindFirstChild("SwimOrientation")
		
		-- Strictly maintain ONLY Swimming state
		if hum:GetState() ~= Enum.HumanoidStateType.Swimming then
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Swimming)
			end)
		end
		
		-- Always force hum.Jump to false while swimming to prevent engine-level jumping
		hum.Jump = false
		
		-- Surface exit logic: if too far above water, stop swimming
		if self.WaterSurfaceY and hrp.Position.Y > self.WaterSurfaceY + SWIM_EXIT_HEIGHT then
			self:GetOut()
			return
		end

		if moveDir.Magnitude > 0 or math.abs(verticalValue) > 0 then
			local camCF = camera.CFrame
			
			local worldMove = (moveDir * hum.WalkSpeed) + Vector3.new(0, verticalValue * hum.WalkSpeed, 0)
			
			if linVel then
				linVel.VectorVelocity = worldMove
			end
			
			if alignOri then
				-- Horizontal Swimming: Character's head (UpVector) points in the movement direction
				local unitMove = worldMove.Unit
				
				-- Calculate horizontal basis to determine "back" and "right"
				local targetRight = unitMove:Cross(Vector3.new(0, 1, 0)).Unit
				if targetRight.Magnitude < 0.1 then
					-- If swimming nearly straight up/down, use camera basis to prevent spinning
					targetRight = camCF.RightVector
				end
				
				local targetUp = unitMove
				local targetForward = targetRight:Cross(targetUp).Unit
				
				-- Aligning the character's Y-axis (UpVector) with the movement direction for a horizontal pose
				alignOri.CFrame = CFrame.fromMatrix(Vector3.zero, targetRight, targetUp, -targetForward)
			end
		else
			if linVel then
				linVel.VectorVelocity = Vector3.zero
			end
			
			if alignOri then
				local lookDir = (camera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
				if lookDir.Magnitude < 0.1 then lookDir = Vector3.new(0, 0, -1) end
				
				alignOri.CFrame = CFrame.lookAt(Vector3.zero, lookDir, Vector3.yAxis)
			end
		end
	end)
end

function swimModule:Stop()
	if not self.Enabled then return end
	self.Enabled = false
	if self.RSConnection then
		self.RSConnection:Disconnect()
		self.RSConnection = nil
	end
	
	ContextActionService:UnbindAction(SWIM_JUMP_ACTION)
	isJumpingFlag = false
	
	setupPhysics(false)
	setHumanoidPhysicsMode(false)
end

function swimModule:UpdateSurfaceConstraint(hrpPos, waterParts, isFrontIn)
	if not self.Enabled or #waterParts == 0 then
		self.WaterSurfaceY = nil
		return
	end

	-- Raycast to find water surface for height limit check
	raycastParams.FilterDescendantsInstances = waterParts
	local rayResult = workspace:Raycast(hrpPos + Vector3.new(0, 5, 0), Vector3.new(0, -15, 0), raycastParams)
	
	if rayResult then
		self.WaterSurfaceY = rayResult.Position.Y
	else
		self.WaterSurfaceY = nil
	end
end

function swimModule:GetOut() 
	self:Stop() 
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Jumping) 
	end)
end

return setmetatable({Enabled = false, SurfaceCapped = false}, swimModule)
