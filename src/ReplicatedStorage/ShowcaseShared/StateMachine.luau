--!strict

export type TransitionMap = {
	[string]: {
		[string]: boolean,
	},
}

export type Listener = (nextState: string, previousState: string) -> ()

type InternalStateMachine = {
	_state: string,
	_transitions: TransitionMap,
	_listeners: { [number]: Listener },
	_nextListenerId: number,
}

local StateMachine = {}
StateMachine.__index = StateMachine

export type StateMachine = typeof(setmetatable({} :: InternalStateMachine, StateMachine))

function StateMachine.new(initialState: string, transitions: TransitionMap): StateMachine
	assert(initialState ~= "", "StateMachine initialState cannot be empty")

	local self = setmetatable({
		_state = initialState,
		_transitions = transitions,
		_listeners = {},
		_nextListenerId = 0,
	}, StateMachine)

	return self
end

function StateMachine:GetState(): string
	return self._state
end

function StateMachine:CanTransition(nextState: string): boolean
	if nextState == self._state then
		return false
	end

	local allowed = self._transitions[self._state]
	return allowed ~= nil and allowed[nextState] == true
end

function StateMachine:_notify(nextState: string, previousState: string)
	for _, listener in pairs(self._listeners) do
		local ok, message = pcall(listener, nextState, previousState)
		if not ok then
			warn(string.format("[StateMachine] listener failed: %s", tostring(message)))
		end
	end
end

function StateMachine:Transition(nextState: string): boolean
	if not self:CanTransition(nextState) then
		return false
	end

	local previousState = self._state
	self._state = nextState
	self:_notify(nextState, previousState)
	return true
end

function StateMachine:Force(nextState: string)
	if nextState == self._state then
		return
	end

	local previousState = self._state
	self._state = nextState
	self:_notify(nextState, previousState)
end

function StateMachine:Connect(listener: Listener): () -> ()
	self._nextListenerId += 1
	local listenerId = self._nextListenerId
	self._listeners[listenerId] = listener

	return function()
		self._listeners[listenerId] = nil
	end
end

return StateMachine
