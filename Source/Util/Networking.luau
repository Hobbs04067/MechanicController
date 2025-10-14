local Types = require(script.Parent.Types)

type BitPackData = Types.BitPackData

local module = {}

local Const_maxBitsPerPack = 32

local _currentBits = Const_maxBitsPerPack

local _bitPackInfo = {
	{ size = 3, name = "replication_action" },
	{ size = 8, name = "controller_id" },
	{ size = 1, name = "mechanic_boolean" },
	{ size = 20, name = "mechanic_id" },
}

local bitPackReferenceDict = {}

for _, info in ipairs(_bitPackInfo) do
	_currentBits -= info.size
	bitPackReferenceDict[info.name] = {
		shiftAmount = _currentBits,
		maxRep = bit32.lshift(2 ^ info.size - 1, _currentBits),
	}
end

if _currentBits < 0 then
	error("MechanicController Error: Bit packing overflow! Exceeded " .. tostring(Const_maxBitsPerPack) .. " bits.")
end

function module.bitPack(packData: BitPackData): buffer
	local packedReplicationAction =
		bit32.lshift(packData.replicationAction, bitPackReferenceDict.replication_action.shiftAmount)
	local packedControllerId = bit32.lshift(packData.controllerId, bitPackReferenceDict.controller_id.shiftAmount)
	local packedMechanicBoolean = 0
	local packedMechanicId = 0

	if packData.mechanicBoolean ~= nil then
		local num = 0
		if packData.mechanicBoolean == true then
			num = 1
		end
		packedMechanicBoolean = bit32.lshift(num, bitPackReferenceDict.mechanic_boolean.shiftAmount)
		packedMechanicId = packData.mechanicId - 1
	end

	local buff = buffer.create(32)
	buffer.writei32(
		buff,
		0,
		bit32.bor(packedReplicationAction, packedControllerId, packedMechanicBoolean, packedMechanicId)
	)

	return buff
end

function module.bitUnpack(buff: buffer): BitPackData...
	local pack = buffer.readi32(buff, 0)
	pack += 1
	local data = {}

	for _, info in ipairs(_bitPackInfo) do
		local unpackedValue = bit32.rshift(
			bit32.band(pack, bitPackReferenceDict[info.name].maxRep),
			bitPackReferenceDict[info.name].shiftAmount
		)
		if info.size == 1 then
			unpackedValue = unpackedValue == 1
		end
		table.insert(data, unpackedValue)
	end

	return table.unpack(data)
end

return module