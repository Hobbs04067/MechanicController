type func = any

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

    functionConnections: { func }
}

export type MechanicInfo = {
    loadingOrder: number,
	toggledOnStart: boolean,
	enabledOnStart: boolean,
    data: MechanicData,
    name: string
}

export type Bindable = {
    
}

export type Mechanic = {
    controller: MechanicController,
	name: string,

	_initialized: boolean,
	_toggled: boolean,
	_enabled: boolean?,

    Toggled: Bindable
}

export type MechanicController = {
    
}

return nil