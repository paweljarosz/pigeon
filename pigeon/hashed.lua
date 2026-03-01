-- Hashed string library.
-- Computes Defold hashes for strings at runtime and caches the result.
--
-- Lerg.
-- https://github.com/Lerg/defold-hashed
--
-- Contribution: Paweł Jarosz 2024 - Added __call.
-- Contribution: Paweł Jarosz 2026 - Added Lua annotations.
--
-- Usage:
-- print(hashed.hello_world)
-- print(hashed.any_compatible_string)
-- print(hashed['any string with any characters'])
-- print(hashed'any string')
-- print(hashed"any string")

---@alias hash userdata|hash
local _M = {}

setmetatable(_M, {
	__index = function(t, key)
		local h = hash(key)
		rawset(t, key, h)
		return h ---[[@as hash]]
	end,
	-- Allows calling the module directly
	__call = function(t, key)
		local h = hash(key)
		rawset(t, key, h)
		return h ---[[@as hash]]
	end
})

return _M