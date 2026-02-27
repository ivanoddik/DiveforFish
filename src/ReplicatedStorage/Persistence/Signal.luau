-- Simple Signal Implementation
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({
		_listeners = {}
	}, Signal)
end

function Signal:Connect(callback)
	local connection = {
		_callback = callback,
		_signal = self,
		Connected = true
	}
	
	function connection:Disconnect()
		if not self.Connected then return end
		self.Connected = false
		local listeners = self._signal._listeners
		local index = table.find(listeners, self)
		if index then
			table.remove(listeners, index)
		end
	end
	
	table.insert(self._listeners, connection)
	return connection
end

function Signal:Fire(...)
	for _, connection in self._listeners do
		task.spawn(connection._callback, ...)
	end
end

function Signal:Destroy()
	self._listeners = {}
end

return Signal
