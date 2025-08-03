local HttpService = game:GetService("HttpService")

local toNum = tonumber

local UUID = {}

function UUID.new(hasCurlyBrackets: boolean?): string?
	hasCurlyBrackets = hasCurlyBrackets or false

	local uuid: string = HttpService:GenerateGUID(hasCurlyBrackets)
	if not uuid then
		return
	end

	if #uuid % 2 ~= 0 then
		uuid = uuid .. "0"
	end

	return uuid
end

function UUID:ConvertToBinary(uuid: string): string
	if not uuid then
		return
	end

	local hex: string = uuid:gsub("-", "")
	local binary: string = ""

	for i = 1, #hex, 2 do
		local hex_group = hex:sub(i, i + 1)
		local num = toNum(hex_group, 16)
		binary = binary .. string.char(num)
	end

	return binary
end

function UUID:ConvertToUUID(binary: string): string
	if not binary then
		return
	end

	local hex = ""

	for i = 1, #binary do
		local num = binary:sub(i, i):byte()
		local hex_group = ("%02X"):format(num)
		hex = hex .. hex_group
	end

	return (
		hex:sub(1, 8)
		.. "-"
		.. hex:sub(9, 12)
		.. "-"
		.. hex:sub(13, 16)
		.. "-"
		.. hex:sub(17, 20)
		.. "-"
		.. hex:sub(21, 32)
	):lower()
end

return UUID
