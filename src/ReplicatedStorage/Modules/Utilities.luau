local Utilities = {}

-- Lightweight Signal (RBXScriptSignal-like)
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local alive = true
	handlers[fn] = true

	return {
		Disconnect = function()
			if not alive then
				return
			end
			alive = false
			handlers[fn] = nil
		end,
	}
end

function Signal:Fire(...)
	for fn in pairs(self._handlers) do
		task.spawn(fn, ...)
	end
end

Utilities.Signal = Signal

-- Simple Maid (cleanup)
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(taskObj)
	table.insert(self._tasks, taskObj)
	return taskObj
end

function Maid:DoCleaning()
	for i = #self._tasks, 1, -1 do
		local t = self._tasks[i]
		self._tasks[i] = nil

		if typeof(t) == "RBXScriptConnection" then
			t:Disconnect()
		elseif type(t) == "function" then
			t()
		elseif type(t) == "table" and type(t.Destroy) == "function" then
			t:Destroy()
		elseif type(t) == "table" and type(t.Disconnect) == "function" then
			t:Disconnect()
		elseif typeof(t) == "Instance" then
			t:Destroy()
		end
	end
end

Utilities.Maid = Maid

function Utilities.DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = Utilities.DeepCopy(v)
	end
	return out
end

function Utilities.ClampVector3ToBounds(pos, minV, maxV)
	return Vector3.new(
		math.clamp(pos.X, minV.X, maxV.X),
		math.clamp(pos.Y, minV.Y, maxV.Y),
		math.clamp(pos.Z, minV.Z, maxV.Z)
	)
end

function Utilities.Round(n, decimals)
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

return Utilities


