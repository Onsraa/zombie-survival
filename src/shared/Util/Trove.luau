--!strict
--[[
	Trove.luau
	Minimal cleanup container (a.k.a. Maid/Janitor) — addresses memory leaks from
	undisconnected events (SE-4). Track every connection / instance / cleanup
	function in a Trove, then call :Clean() (or :Destroy()) to release them all.

	Vendored intentionally: it is tiny, dependency-free, and fully owned. If the
	project later adopts a Wally cleanup package, swap the internals behind this API.

	Usage:
		local trove = Trove.new()
		trove:Connect(humanoid.Died, onDied)
		local part = trove:Add(Instance.new("Part"))
		trove:Add(function() print("custom cleanup") end)
		trove:Clean() -- disconnects, destroys, and calls everything tracked
]]

local Trove = {}
Trove.__index = Trove

-- A tracked object: an event connection, an Instance, or a cleanup function.
type Trackable = RBXScriptConnection | Instance | () -> ()

export type Trove = typeof(setmetatable(
	{} :: {
		_objects: { Trackable },
	},
	Trove
))

function Trove.new(): Trove
	return setmetatable({
		_objects = {},
	}, Trove)
end

-- Track an object and return it (so you can inline: local x = trove:Add(...)).
function Trove.Add<T>(self: Trove, object: T & Trackable): T
	table.insert(self._objects, object :: Trackable)
	return object
end

-- Connect a signal and track the connection.
function Trove.Connect(self: Trove, signal: RBXScriptSignal, callback: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(callback)
	table.insert(self._objects, connection)
	return connection
end

-- Release everything tracked, leaving the Trove reusable.
function Trove.Clean(self: Trove)
	for _, object in self._objects do
		if typeof(object) == "RBXScriptConnection" then
			object:Disconnect()
		elseif typeof(object) == "Instance" then
			object:Destroy()
		elseif typeof(object) == "function" then
			(object :: () -> ())()
		end
	end
	table.clear(self._objects)
end

-- Alias for Clean; conventional for one-shot teardown.
function Trove.Destroy(self: Trove)
	self:Clean()
end

return Trove
