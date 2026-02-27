local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DIVE = ReplicatedStorage:WaitForChild("DIVE")
local Shared = require(DIVE:WaitForChild("Shared"))

print("[DIVE][Server]", Shared.hello())
