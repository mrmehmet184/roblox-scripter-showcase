--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local InputController = {}
InputController.__index = InputController

type InternalInputController = {
	_remotes: any,
	_destroyed: boolean,
}

export type InputController = typeof(setmetatable({} :: InternalInputController, InputController))

local ATTACK_ACTION = "ShowcaseAttack"
local PARRY_ACTION = "ShowcaseParry"

function InputController.new(remotes: any): InputController
	local self = setmetatable({
		_remotes = remotes,
		_destroyed = false,
	}, InputController)

	ContextActionService:BindActionAtPriority(
		ATTACK_ACTION,
		function(_, inputState: Enum.UserInputState, inputObject: InputObject)
			return self:_onAttack(inputState, inputObject)
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonR2
	)

	ContextActionService:BindActionAtPriority(
		PARRY_ACTION,
		function(_, inputState: Enum.UserInputState)
			return self:_onParry(inputState)
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL2
	)

	ContextActionService:SetTitle(ATTACK_ACTION, "STRIKE")
	ContextActionService:SetTitle(PARRY_ACTION, "PARRY")
	ContextActionService:SetPosition(ATTACK_ACTION, UDim2.new(1, -155, 1, -165))
	ContextActionService:SetPosition(PARRY_ACTION, UDim2.new(1, -265, 1, -105))

	return self
end

function InputController:_getAimDirection(inputObject: InputObject): Vector3?
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end

	local usePointer = inputObject.UserInputType == Enum.UserInputType.MouseButton1

	if usePointer then
		local topLeftInset = GuiService:GetGuiInset()
		local pointerPosition = UserInputService:GetMouseLocation() - topLeftInset
		local ray = camera:ViewportPointToRay(pointerPosition.X, pointerPosition.Y)
		return ray.Direction.Unit
	end

	return camera.CFrame.LookVector.Unit
end

function InputController:_onAttack(inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if self._destroyed or inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end

	local direction = self:_getAimDirection(inputObject)
	if direction == nil then
		return Enum.ContextActionResult.Pass
	end

	self._remotes.ActionRequest:FireServer("Attack", {
		direction = direction,
	})

	return Enum.ContextActionResult.Sink
end

function InputController:_onParry(inputState: Enum.UserInputState): Enum.ContextActionResult
	if self._destroyed or inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end

	self._remotes.ActionRequest:FireServer("Parry")
	return Enum.ContextActionResult.Sink
end

function InputController:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	ContextActionService:UnbindAction(ATTACK_ACTION)
	ContextActionService:UnbindAction(PARRY_ACTION)
end

return InputController
