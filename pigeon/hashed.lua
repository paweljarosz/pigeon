-- Hashed string library.
-- Computes Defold hashes for strings at runtime and caches the result.
--
-- Lerg.
-- Contribution: Pawel Jarosz 2024 - Added __call.
--
-- Usage:
-- print(hashed.hello_world)
-- print(hashed.any_compatible_string)
-- print(hashed['any string with any characters'])
-- print(hashed'any string')
-- print(hashed"any string")

local _M = {}

setmetatable(_M, {
	__index = function(t, key)
		local h = hash(key)
		rawset(t, key, h)
		return h
	end,
	-- Allows calling the module directly
	__call = function(t, key)
		local h = hash(key)
		rawset(t, key, h)
		return h
	end
})

return _M