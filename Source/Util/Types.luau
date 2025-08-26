type func = (...any) -> ...any

export type MechanicData = {
	initFunction: func,
	SERVER_initFunction: func,
	REPLICATED_initFunction: func,
	destroyFunction: func,
	SERVER_destroyFunction: func,
	REPLICATED_destroyFunction: func,
	toggleFunction: func,
	SERVER_toggleFunction: func,
	REPLICATED_toggleFunction: func,
	cleanupFunction: func,
	SERVER_cleanupFunction: func,
	REPLICATED_cleanupFunction: func,

	functionConnections: { [RBXScriptSignal]: func },
}

export type MechanicInfo = {
	loadingOrder: number,
	toggledOnStart: boolean,
	enabledOnStart: boolean,
	data: MechanicData,
	name: string,
}

export type Bindable = {
	_connections: { func },

	Connect: func,
	Fire: func,
	Destroy: func,
}

export type Mechanic = {
	controller: MechanicController,
	name: string,

	_initialized: boolean,
	_toggled: boolean,
	_enabled: boolean?,
	_connections: { RBXScriptConnection },

	_initFunction: func,
	_destroyFunction: func,
	_toggleFunction: func,
	_cleanupFunction: func,
	_data: MechanicData,

	Toggled: Bindable,

	Toggle: func,
	Enable: func,
	Disable: func,
	Destroy: func,
	Init: func,
	IsEnabled: func,
	IsDisabled: func,
	IsToggled: func,
	IsUsing: func,
} & { _id: number }

export type MechanicController = {
	id: number,
	rig: Model,
	player: Player,
	mechanics: { [string]: Mechanic },

	_connections: { [string]: RBXScriptConnection },
	_indexedMechanics: { [number]: string },

	Destroy: func,
}

export type BitPackData = {
	replicationAction: number,
	controllerId: number,
	mechanicToggle: boolean?,
	mechanicId: number?,
}

return nil
