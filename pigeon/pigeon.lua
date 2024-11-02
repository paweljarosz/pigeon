--
-- PIGEON
--
-- Version: 1.3
-- Library written while Defold was in version: 1.9.4
--
-- PIGEON is a library to easily and safely manage posting messages in Defold.
-- Ensures safe interface by allowing to easily check message correctness.
-- Simplifies sending data to all listening subscribers.
-- Allows to set up hooks that are triggered instantly when a message is send.
--
-- Based partially on "Dispatcher" by Critique Gaming:
-- https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua
-- Uses "Defold hashed" for pre-hashing by Sergey Lerg:
-- https://github.com/Lerg/defold-hashed
-- Can utilise "Log" for logging and saving logs by Brian "Subsoap/Pkeod" Kramer:
-- https://github.com/subsoap/log
-- or "Defold-Log" for logging by Maksim "Insality" Tuprikov:
-- https://github.com/Insality/defold-log
--
-- By Pawel Jarosz, 2023-2024
-- License: MIT

--
-- EXTERNAL DEPENDENCIES
--
-- PIGEON can be coupled with external libraries (like Log or hashed)
-- If it is not tied to one library it uses a default, simple behaviour.

-- Logging - either use just built-in print function or logging library:
-- LOG - A library by Brian 'Subsoap' Kramer for easy logging:
-- https://github.com/subsoap/log

---@class logger @You can provide own logger that exposes logging functions.
---@field debug function
---@field trace function
---@field info function
---@field warn function
---@field error function
---@field crit function
local logger = {
	debug = print,
	trace = print,
	info = print,
	warn = print,
	error = print,
	crit = print,
}

---@class hashed You can use this library with Defold-hashed by Sergey Lerg
local hashed = hash

---@class PIGEON
---@field public letters table
---Defined messages.
---PIGEON contains example "letters" module that contains defined constant message data in a single module.
---Letters describes all Defold system messages by default.
---You can modify, add or remove messages (letters) with API function)
---or you can access this data directly with PIGEON.letters[hashed_message_id].
---Everytime a letter is posted using PIGEON @see PIGEON.send or @see PIGEON.send_to,
---the message data is verified according to those settings.
---@see PIGEON.define
local PIGEON = {}

PIGEON.letters = require "pigeon.letters"

-- Localize global values/modules/functions:
local msg, ipairs, pairs, type, tostring = msg, ipairs, pairs, type, tostring

--
-- INTERNAL STATE
--
local id_count = 0
local events = {}
local subscribers = {}
local message_queue = {}
local message_queue_count = 0
local default_tag = "pign"

--
-- PRIVATE INTERNAL FUNCTIONS, IMPLEMENTATION
--

---Set logging functions to built-in print
local function set_logger_print()
	for key, log_fn in pairs(logger) do
		log_fn = print
	end
end

---Set logging calls to empty functions
local function set_logger_empty_call()
	for key, log_fn in pairs(logger) do
		log_fn = function() end
	end
end

---Generate a unique id (ascending order integer)
local function generate_id()
	local id = id_count
	id_count = id + 1
	return id
end

---Ensure message_id is hashed
---@param	message_id	string|userdata		Defold message_id string or hashed.
---@return				userdata			Hashed message_id
local function message_id_to_hash(message_id)
	if not message_id then
		logger.error("'message_id' is not given.", default_tag)
		return message_id
	end
	if type(message_id) == "string" then
		message_id = hashed(message_id) -- Ensure message_id is hashed
	end
	if type(message_id) ~= "userdata" then
		logger.error("'message_id' is neither string nor hash.", default_tag)
		return message_id
	end

	return message_id
end

---Check if data is of given type (or of second given type)
---@param	data				any			Data to check.
---@param	value_type			any			Expected type.
---@param	second_value_type	any|nil		Optional expected second type.
---@return						boolean		True if data is of expected type, false otherwise.
local function data_has_type(data, value_type, second_value_type)
	if not data then
		logger.error("data not given.", default_tag)
		return false
	end
	if not type then
		logger.error("type not given.", default_tag)
		return false
	end
	if not second_value_type and type(data) ~= value_type then
		logger.error("data has incorrect type: "..(type(data) or "")..". Expected: "..(value_type or ""), default_tag)
		return false
	end
	if second_value_type and not ((type(data) == value_type) or (type(data) == second_value_type)) then
		logger.error("data has incorrect type: "..(type(data) or "")..". Expected: "..(value_type or "").." or: "..(second_value_type), default_tag)
		return false
	end
	return true
end

---Define message to be checked in runtime by PIGEON.
---@param	message_id		string|userdata		Defold message_id string or hashed.
---@param	message_def		table|nil			Optional message definition - a table containing required fields as keys with their types as values.
---@return					boolean				True if defined succesfully, false otherwise.
local function define(message_id, message_def)
	if not message_id then
		logger.error("Failed to define: "..(message_id or "")..". Message_id is not given.", default_tag)
		return false
	end
	if not ( (type(message_id) == "string") or (type(message_id) == "userdata") ) then
		logger.error("Failed to define: "..(message_id or "")..". Message_id is neither string nor hash.", default_tag)
		return false
	end
	-- Defensive programming can be removed on production, when sure
	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		logger.error("Failed to define: "..(message_id or "")..". Message_id is incorrect.", default_tag)
		return false
	end
	if PIGEON.letters[hashed_message_id] and not data_has_type(message_def, "table") then
		logger.error("Failed to redefine: "..(message_id or "")..". New data is incorrect.", default_tag)
		return false
	end

	PIGEON.letters[hashed_message_id] = {
		id = hashed_message_id,
		data = message_def,
	}
	logger.trace("Successfully defined message, id: "..(message_id or ""), default_tag)
	return true
end

---Unsubscribe subscriber of given id
---@param	id	number|boolean|nil		Id of the subscriber to unsubscribe. If false or nil it will do nothing and will return false.
---@return		boolean					True if unsubscribed succesfully, false otherwise.
local function unsubscribe(id)
	if not id then return false end
	-- Defensive programming can be removed on production, when sure
	if not data_has_type(id, "number") then
		logger.error("Failed to unsubscribe. Subscriber 'id' is not given or is not a number.", default_tag)
		return false
	end

	local subscriber = subscribers[id]
	if not subscriber then
		logger.warn("Skipped unsubscribing already unsubscribed or not existing subscriber: "..id, default_tag)
		return true
	end

	-- Clear events
	for _, message_id in ipairs(subscriber.messages) do
		local event = events[message_id]
		if event then
			event.subs[id] = nil
			event.hooks[id] = nil
		end
	end

	subscribers[id] = nil
	logger.trace("Successfully unsubscribed: "..id, default_tag)
	return true
end

---Subscribe subscriber of given id
---@param	messages	table|string|userdata	Messages to subscribe for. Can be a single message as string or hash or a table containing messages as strings or hashes.
---@return				table					Converted messages table
local function convert_to_messages_table(messages)
	if messages and (type(messages) == "string" or type(messages) == "userdata") then
		return { message_id_to_hash(messages) }
	else
		return messages
	end
end

---Subscribe subscriber of given id
---@param	messages	table|string|userdata	Messages to subscribe for. Can be a single message as string or hash or a table containing messages as strings or hashes.
---@param	hook		function|nil			Optional function callback hooked to the message everytime it is send.
---@param	url			userdata|nil			Optional Url of the subscriber - if not provided the caller's script url is used.
---@return				number|boolean			Returns unique id of subscriber if subscribed succesfully, false otherwise.
local function subscribe(messages, hook, url)
	-- Defensive programming can be removed on production, when sure
	messages = convert_to_messages_table(messages)
	if not data_has_type(messages, "table") then
		logger.error("Failed to subscribe. 'messages' is not given or is not a table.", default_tag)
		return false
	end
	if hook and not data_has_type(hook, "function") then
		logger.error("Failed to subscribe. 'hook' is not a function.", default_tag)
		return false
	end

	local id = generate_id()
	url = url or msg.url()

	if subscribers[id] then
		logger.warn("Overwriting subscriber registered, id: "..id, default_tag)
		unsubscribe(id)
	end

	-- Ensure messages are hashed
	for i,message_id in ipairs(messages) do
		local hashed_message_id = message_id_to_hash(message_id)
		if not hashed_message_id then
			logger.error("Failed to subscribe, one of messages, id: "..(message_id or "").." is incorrect.", default_tag)
			return false
		end
		messages[i] = hashed_message_id
	end

	-- Add subscriber
	local subscriber = {
		id = id,
		url = url,
		messages = messages,
		hook = hook,
	}
	subscribers[id] = subscriber

	-- Create events for given messages
	for i, event_message_id in ipairs(messages) do
		if event_message_id then
			local event = events[event_message_id]
			if not event then
				event = { hooks = {}, subs = {} }
				events[event_message_id] = event
			end

			if hook then
				event.hooks[id] = subscriber
			else
				event.subs[id] = subscriber
			end
		end
	end

	logger.trace("Successfully subscribed subscriber, id: "..id, default_tag)
	return id
end

---Splits a string into a table by "|" sign, e.g. split_by_vertical_line('a|b|c) returns {'a', 'b', 'c'}
---@param	s		string		String value to split
---@return			table		Resulting table containing splited substrings.
local function split_by_vertical_line(s)
	local result = {}
	local i = 1
	for str in string.gmatch(s, '([^|]+)') do
		result[i] = str
		i = i + 1
	end
	return result
end

---Checks if given message contains correct data for given message_id if it is defined in PIGEON.
---@param	message_id	userdata	Hashed message_id.
---@param	message		table		Given message table to check.
---@return				boolean		True if data is correct, false otherwise.
local function is_data_correct(message_id, message)
	local message_definition = PIGEON.letters[message_id]
	if not ( message_definition and message_definition.data and ( type(message_definition.data) == "table" ) ) then
		logger.trace("Sending anyway, because no data to check for message, id: "..message_id, default_tag)
		return true
	end

	for key, type_definition in pairs(message_definition.data) do
		local possible_types = split_by_vertical_line(type_definition)
		local is_type_ok = false
		local message_type = type(message[key])
		for i,possible_type in ipairs(possible_types) do
			local is_current_type_ok = ( message_type == possible_type )
			is_type_ok = is_type_ok or is_current_type_ok
		end
		if not is_type_ok then
			logger.error("Failed: "..tostring(message_id)..". Expects key: ["..key.."] of type: "..type_definition.." but is: "..message_type, default_tag)
			return false
		end
	end
	return true
end

---Equivalent to `msg.post`. Sends a message of given message_id with given message table to a specified url. Additionally, PIGEON checks in runtime if message is correct if defined.
---@param	url			userdata			Target url.
---@param	message_id	string|userdata		Defold message_id string or hashed.
---@param	message		table|nil			Optional message table to check.
---@return				boolean				True if data is correct and send succesfully, false otherwise.
local function send_to(url, message_id, message)
	-- Defensive programming can be removed on production, when sure
	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		logger.error("Failed to send: "..(message_id or "")..". Message_id is not given or has wrong type.", default_tag)
		return false
	end

	-- Defensive programming can be removed on production, when sure
	if not data_has_type(url, "userdata", "string") then
		logger.error("Failed to send: "..(hashed_message_id or "")..". Url is incorrect: "..(url or ""), default_tag)
		return false
	end

	message = message or {}

	if not is_data_correct(hashed_message_id, message) then
		return false
	end

	msg.post(url, hashed_message_id, message)
	return true
end

---Sends a message of given message_id with given message table to all subscribed subscribers. Additionally, PIGEON checks in runtime if message is correct if defined.
---@param	message_id	string|userdata		Defold message_id string or hashed.
---@param	message		table|nil			Optional message table to check.
---@return				boolean				True if data is correct and send succesfully, false otherwise.
local function send(message_id, message)
	-- Defensive programming can be removed on production, when sure
	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		logger.error("Failed to send: "..(message_id or "")..". Message_id is not given or has wrong type.", default_tag)
		return false
	end

	local event = events[hashed_message_id]
	if not event then
		logger.warn("Not send: "..(hashed_message_id or "")..". Message_id is not subscribed to anything.", default_tag)
		return false
	end

	message = message or {}

	if not is_data_correct(hashed_message_id, message) then
		return false
	end

	-- Add message to queue
	message_queue_count = message_queue_count + 1

	-- Call all hooks immediately
	for _, sub in pairs(event.hooks) do
		sub.hook(hashed_message_id, message)
	end

	-- Send message to all subscribers
	for _, sub in pairs(event.subs) do
		msg.post(sub.url, hashed_message_id, message)
	end

	-- If there are more messages in queue, send them
	if (message_queue_count == 1) and next(message_queue) then
		for _, queued_msg in ipairs(message_queue) do
			send(queued_msg.hashed_message_id, queued_msg.message)
		end
		message_queue = {}
	end

	-- Remove message from queue
	message_queue_count = message_queue_count - 1
	return true
end


--
-- PIGEON API
--

---Define a new message with an optional specified data definition as a table containing keys as possible keys
---and values for those keys as possible type of data to be checked in runtime by PIGEON.
---When data is sent using pigeon.send, it will be verified in run-time before sending.
---@param	message_id		string|userdata		Defold message_id string or hashed (it is ensured to be pre-hashed anyway).
---@param	message_def		table|nil			Optional message definition - a table containing required fields as keys with their types as values. Values can represent multiple types separated by `|`, e.g. "string|number|nil".
---@return					boolean				True if defined succesfully, false otherwise.
function PIGEON.define(message_id, message_def)
	return define(message_id, message_def)
end

---Subscribe to given message_id(s) and eventually add an optional hook on message sent.
---@param	messages	table|string|userdata	Table containing message_id(s) that caller will be subscribed to. Can be a single message as string or hash or a table containing messages as strings or hashes.
---@param	hook		function|nil			Optional hook function to be called everytime, when sending defined message(s).
---@param	url			userdata|nil			Optional URL of the subscriber, to which, the messages are subscribed. If not provided the caller's script url is used by default.
---@return				number|boolean			Unique id of the subscriber if subscribed succesfully, false otherwise.
function PIGEON.subscribe(messages, hook, url)
	return subscribe(messages, hook, url)
end

---Unsubscribe the given subscription.
---@param	id	number|boolean|nil	Id of the subscriber to unsubscribe. If false or nil it will do nothing and will return false.
---@return		boolean				True if unsubscribed succesfully, false otherwise.
function PIGEON.unsubscribe(id)
	return unsubscribe(id)
end

---Unsubscribe all saved subscriptions.
---@return		boolean		True if unsubscribed all succesfully, false otherwise.
function PIGEON.unsubscribe_all()
	for i,subscriber in ipairs(subscribers) do
		if not unsubscribe(subscriber.id) then
			return false
		end
	end
	return true
end

---Send a message of given message_id with given message table to all subscribed subscribers.
---Additionally, PIGEON checks in runtime if message is correct if defined.
---If the message has a hook attached, it will be called immediately.
---@param	message_id	string|userdata		Defold message_id string or hashed. It will be prehashed anyway.
---@param	message		table|nil			Optional definition message table to check before sending.
---@return				boolean				True if data is correct and send succesfully, false otherwise.
function PIGEON.send(message_id, message)
	if message_queue_count > 0 then
		message_queue[#message_queue + 1] = { message_id = message_id, message = message }
	else
		if send(message_id, message) then
			logger.info("Succesfully sent: "..message_id, default_tag)
			return true
		else
			return false
		end
	end
	return true
end

---Equivalent to Defold built-in `msg.post`. Sends a message of given message_id with an optional data in message table to a specified url.
---Additionally, PIGEON checks in runtime if message is correct if defined.
---@param	url			userdata			Target's url.
---@param	message_id	string|userdata		Defold message_id string or hashed. It will be prehashed anyway.
---@param	message		table|nil			Optional message table to check.
---@return				boolean				True if data is correct and send succesfully, false otherwise.
function PIGEON.send_to(url, message_id, message)
	return send_to(url, message_id, message)
end

---Enable or disable logging functionality.
---It only switches between default logging (printing to console) and not logging.
---If you want to use dependency logging, you need to set dependency again after enabling logging.
---The correctness of arguments is not checked! Use responsibly!
---@param	enable		boolean			Flag to set logging enabled (true) or disabled (false).
function PIGEON.toggle_logging(enable)
	if enable == true then
		set_logger_print()
	elseif enable == false then
		set_logger_empty_call()
	end
end

---Replace internal printing with logging from Log module.
---It is suited for Log API, so if you want to provide your own module, follow the API,
---or modify internal PIGEON calls for logging accordingly.
---The correctness of arguments is not checked! Use responsibly!
---@param	module		table			Lua module being replacement for logging.
---@param	tag			string|nil		Optional own string tag to replace the default tag ("pign").
function PIGEON.set_dependency_module_log(module, tag)
	if module then
		-- Support Insality Defold-Log
		if module.name  and type(module.name ) == "string" then
			logger.info = function(text) module:info(text) end
			logger.warn = function(text) module:warn(text) end
			logger.error = function(text) module:error(text) end
			logger.debug= function(text) module:debug(text) end
			logger.trace = function(text) module:trace(text) end
		else
			logger = module
		end
	else
		set_logger_print()
	end
	default_tag = tag or default_tag
end

---Replace internal built-in hashing with Defold-hashed module.
---@param	module		table		Lua module being replacement for logging.
function PIGEON.set_dependency_module_hashed(module)
	if module and type(module) == "function"
	and module("test") == hash("test")
	and type( module("test") ) == "userdata" then
		-- Support Sergey Lerg Defold-hashed
		hashed = module
	end
end

return PIGEON

