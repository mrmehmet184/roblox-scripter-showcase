--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteService = {}

export type RemoteSet = {
	Folder: Folder,
	ActionRequest: RemoteEvent,
	StateUpdate: RemoteEvent,
	Effect: RemoteEvent,
	Snapshot: RemoteFunction,
}

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), string.format("%s must be a Folder", name))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), string.format("%s must be a RemoteEvent", name))
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteFunction"), string.format("%s must be a RemoteFunction", name))
		return existing
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

function RemoteService.Create(): RemoteSet
	local folder = ensureFolder(ReplicatedStorage, "ShowcaseRemotes")

	return {
		Folder = folder,
		ActionRequest = ensureRemoteEvent(folder, "ActionRequest"),
		StateUpdate = ensureRemoteEvent(folder, "StateUpdate"),
		Effect = ensureRemoteEvent(folder, "Effect"),
		Snapshot = ensureRemoteFunction(folder, "Snapshot"),
	}
end

return RemoteService
