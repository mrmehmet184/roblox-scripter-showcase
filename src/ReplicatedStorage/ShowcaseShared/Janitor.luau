--!strict

local Janitor = {}
Janitor.__index = Janitor

type InternalJanitor = {
	_tasks: { any },
	_cleaned: boolean,
}

export type Janitor = typeof(setmetatable({} :: InternalJanitor, Janitor))

function Janitor.new(): Janitor
	return setmetatable({
		_tasks = {},
		_cleaned = false,
	}, Janitor)
end

function Janitor:Add<T>(taskObject: T): T
	assert(not self._cleaned, "Cannot add tasks to a cleaned Janitor")
	table.insert(self._tasks, taskObject)
	return taskObject
end

local function cleanTask(taskObject: any)
	local taskType = typeof(taskObject)

	if taskType == "RBXScriptConnection" then
		if taskObject.Connected then
			taskObject:Disconnect()
		end
	elseif taskType == "Instance" then
		taskObject:Destroy()
	elseif taskType == "function" then
		taskObject()
	elseif type(taskObject) == "table" then
		if type(taskObject.Destroy) == "function" then
			taskObject:Destroy()
		elseif type(taskObject.Cleanup) == "function" then
			taskObject:Cleanup()
		end
	end
end

function Janitor:Cleanup()
	if self._cleaned then
		return
	end

	self._cleaned = true

	for index = #self._tasks, 1, -1 do
		local taskObject = self._tasks[index]
		local ok, message = pcall(cleanTask, taskObject)
		if not ok then
			warn(string.format("[Janitor] cleanup failed: %s", tostring(message)))
		end
	end

	table.clear(self._tasks)
end

function Janitor:Destroy()
	self:Cleanup()
end

return Janitor
