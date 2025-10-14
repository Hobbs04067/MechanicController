type mechanic_function = (self: MechanicController, ...any) -> nil

export type MechanicData = {
	initFunction: mechanic_function,
	SERVER_initFunction: mechanic_function,
	REPLICATED_initFunction: mechanic_function,
	destroyFunction: mechanic_function,
	SERVER_destroyFunction: mechanic_function,
	REPLICATED_destroyFunction: mechanic_function,
	toggleFunction: mechanic_function,
	SERVER_toggleFunction: mechanic_function,
	REPLICATED_toggleFunction: mechanic_function,
	cleanupFunction: mechanic_function,
	SERVER_cleanupFunction: mechanic_function,
	REPLICATED_cleanupFunction: mechanic_function,

	functionConnections: { [RBXScriptSignal]: mechanic_function },
}

export type MechanicInfo = {
	loadingOrder: number,
	toggledOnStart: boolean,
	enabledOnStart: boolean,
	data: MechanicData,
	name: string,
}

export type Bindable = {
	_connections: { [string]: RBXScriptConnection },

	Connect: (self: Bindable, func: (...any) -> ...any) -> nil,
	Fire: (self: Bindable) -> nil,
	Destroy: (self: Bindable) -> nil,
}

export type Mechanic = {
	controller: MechanicController,
	name: string,

	_initialized: boolean,
	_toggled: boolean,
	_enabled: boolean?,
	_connections: { RBXScriptConnection },

	_initFunction: mechanic_function,
	_destroyFunction: mechanic_function,
	_toggleFunction: mechanic_function,
	_cleanupFunction: mechanic_function,
	_data: MechanicData,

	Toggled: Bindable,

	Toggle: (self: Mechanic, toggle: boolean) -> nil,
	SoftToggle: (self: Mechanic, toggle: boolean) -> nil,
	Enable: (self: Mechanic, toggle: boolean) -> nil,
	SoftEnable: (self: Mechanic, toggle: boolean) -> nil,
	Disable: (self: Mechanic, toggle: boolean) -> nil,
	Destroy: (self: Mechanic) -> nil,
	Init: (self: Mechanic) -> nil,
	IsEnabled: (self: Mechanic) -> boolean,
	IsDisabled: (self: Mechanic) -> boolean,
	IsToggled: (self: Mechanic) -> boolean,
	IsUsing: (self: Mechanic) -> boolean,
} & { _id: number }

export type MechanicController = {
	id: number,
	rig: Model,
	player: Player,
	mechanics: { [string]: Mechanic },
	PlayerReset: RBXScriptSignal,

	_connections: { [string]: RBXScriptConnection },
	_indexedMechanics: { [number]: string },
	_resetBindableEvent: BindableEvent,

	Destroy: (self: MechanicController) -> nil,
}

export type BitPackData = {
	replicationAction: typeof(require(script.Parent.Enums).ControllerReplicationAction),
	controllerId: number,
	mechanicBoolean: boolean?,
	mechanicId: number?,
}

return nil