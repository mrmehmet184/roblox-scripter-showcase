--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ShowcaseShared")
local Janitor = require(Shared:WaitForChild("Janitor"))
local Types = require(ReplicatedStorage.ShowcaseShared.Types)

type FullSnapshot = Types.FullSnapshot

local RemotesFolder = ReplicatedStorage:WaitForChild("ShowcaseRemotes")
local ActionRequest = RemotesFolder:WaitForChild("ActionRequest") :: RemoteEvent
local StateUpdate = RemotesFolder:WaitForChild("StateUpdate") :: RemoteEvent
local Effect = RemotesFolder:WaitForChild("Effect") :: RemoteEvent
local Snapshot = RemotesFolder:WaitForChild("Snapshot") :: RemoteFunction

local Modules = script.Parent:WaitForChild("ShowcaseClientModules")
local UIController = require(Modules:WaitForChild("UIController"))
local EffectsController = require(Modules:WaitForChild("EffectsController"))
local InputController = require(Modules:WaitForChild("InputController"))

local janitor = Janitor.new()
local uiController = janitor:Add(UIController.new())
local effectsController = janitor:Add(EffectsController.new(uiController))
janitor:Add(InputController.new({
	ActionRequest = ActionRequest,
}))

janitor:Add(StateUpdate.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) == "table" then
		uiController:HandleState(payload)
	end
end))

janitor:Add(Effect.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) == "table" then
		effectsController:Handle(payload)
	end
end))

local snapshotOk, snapshotOrError = pcall(function()
	return Snapshot:InvokeServer()
end)

if snapshotOk and typeof(snapshotOrError) == "table" then
	local snapshot = snapshotOrError :: FullSnapshot
	uiController:ApplySnapshot(snapshot)
	local version = if typeof(snapshotOrError.version) == "string" then snapshotOrError.version else "unknown"
	uiController:Notify("SHOWCASE ONLINE // VERSION " .. string.upper(version), nil, 1.8)
else
	warn(string.format("[Scripter Showcase] Snapshot failed: %s", tostring(snapshotOrError)))
	uiController:Notify("SNAPSHOT UNAVAILABLE", nil, 1.5)
end

script.Destroying:Connect(function()
	janitor:Destroy()
end)
