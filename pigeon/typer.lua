---Typer provides type checking and assertion functions for Lua and Defold.
---@class Typer
local Typer = {}

---@alias DataType "nil"|"number"|"string"|"boolean"|"table"|"function"|"thread"|"userdata"|"hash"|"url"|"vector"|"vector3"|"vector4"|"matrix4"|"quat"
---@alias ExpectedDataType DataType|string|table<integer, DataType>

-- Localise globals
local string, type, types, ipairs, assert = string, type, types, ipairs, assert

-- Defold userdata type checkers from the built-in `types` API.
local defold_type_checkers = {
	hash = types and types.is_hash or nil,
	matrix4 = types and types.is_matrix4 or nil,
	quat = types and types.is_quat or nil,
	url = types and types.is_url or nil,
	vector = types and types.is_vector or nil,
	vector3 = types and types.is_vector3 or nil,
	vector4 = types and types.is_vector4 or nil
}

---Splits a string into a table by "|" sign
---@param s string @String value to split
---@return string[] @Resulting table containing split substrings
local function split_types(s)
	local result = {}
	local i = 1
	for str in string.gmatch(s, '([^|]+)') do
		result[i] = str
		i = i + 1
	end
	return result
end

---Check if data is of given type
---@param data          any                 @Data to check
---@param expected_type ExpectedDataType    @Expected type(s) as a single string representing type or a string with "|" delimiter used for multiple types or table of strings being expected types
---@return              boolean             @True if data is of expected type(s), false otherwise
function Typer.is_type(data, expected_type)
	if not expected_type then
		return false
	end

	-- Convert string to table if it's a string
	if type(expected_type) == "string" then
		expected_type = split_types(expected_type)
	end

	-- Explicitly allow nil when declared
	if data == nil then
		for _, checked_type in ipairs(expected_type) do
			if checked_type == "nil" then
				return true
			end
		end
		return false
	end

	-- Handle Defold userdata types via `types` API and Lua primitives via `type`.
	for _, checked_type in ipairs(expected_type) do
		local checker = defold_type_checkers[checked_type]
		if checker and checker(data) then
			return true
		elseif type(data) == checked_type then
			return true
		end
	end

	return false
end

---Check if value is empty (nil, empty string, zero, empty table)
---@param value     any     @Value to check
---@return          boolean @True if value is empty
function Typer.is_empty(value)
	if not value then
		return true
	end
	if type(value) == "string" then
		return value == ""
	end
	if type(value) == "number" then
		return value == 0
	end
	if type(value) == "table" then
		return next(value) == nil
	end
	return false
end

---Assert that value is of expected type
---@param value             any                 @Value to check
---@param expected_type     ExpectedDataType    @Expected type(s) as a single string representing type or a string with "|" delimiter used for multiple types or table of strings being expected types
---@param error_message?    string              @Optional custom error message
function Typer.assert_type(value, expected_type, error_message)
	assert(Typer.is_type(value, expected_type),
					error_message or string.format("Expected type %s, got %s", expected_type, type(value)))
end

---Assert that value is not empty
---@param value any @Value to check
---@param error_message? string @Optional custom error message
function Typer.assert_not_empty(value, error_message)
	assert(not Typer.is_empty(value), error_message or "Value is empty")
end

return Typer
