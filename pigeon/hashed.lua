-- Hashed string library.
-- Computes Defold hashes for strings at runtime and caches the result.
--
-- Lerg.
--
-- Usage:
-- print(hashed.hello_world)
-- print(hashed.any_compatible_string)
-- print(hashed['any string with any characters'])

local _M = {}

setmetatable(_M, {
	__index = function(t, key)
		local h = hash(key)
		rawset(t, key, h)
		return h
	end
})

return _M