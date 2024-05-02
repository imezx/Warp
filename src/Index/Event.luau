--!strict
local RunService = game:GetService("RunService")
local Type = require(script.Parent.Type)

local function createInstance(parent: Instance, name: string, class: string)
	if not parent:FindFirstChild(name) then
		local newInstance: Instance = Instance.new(class)
		newInstance.Name = name
		newInstance.Parent = parent
	end
end

local function waitForChildren(parent: Instance, childrenNames: {string})
	for _, name: string in ipairs(childrenNames) do
		repeat
			task.wait()
		until parent:FindFirstChild(name)
	end
end

if RunService:IsServer() then
	createInstance(script, "Reliable", "RemoteEvent")
	createInstance(script, "Unreliable", "UnreliableRemoteEvent")
	createInstance(script, "Request", "RemoteEvent")
else
	waitForChildren(script, {"Reliable", "Unreliable", "Request"})
end

return {
	Reliable = script.Reliable,
	Unreliable = script.Unreliable,
	Request = script.Request
} :: Type.Event
