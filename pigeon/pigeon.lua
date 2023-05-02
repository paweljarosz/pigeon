--
-- PIGEON
--
-- Pigeon is a library to easily and safely manage posting messages in Defold.
-- Ensures safe interface by allowing to easily check message correctness.
-- Simplifies sending data to all listening subscribers.
-- Allows to set up hooks that are triggered instantly when a message is send.
--
-- Based partially on "Dispatcher" by Critique Gaming:
-- https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua
-- Uses "Defold Hashed" for pre-hashing by Sergey Lerg:
-- https://github.com/Lerg/defold-hashed
-- Can utilise "Log" for logging and saving logs by Brian "Subsoap/Pkeod" Kramer:
-- https://github.com/subsoap/log
--
-- Documented API is at the end of the module.
--
-- By Pawel Jarosz, 2023
-- License: MIT

local M = {}

--
-- INTERNAL DEPENDENCIES
--
-- Pigeon contains "letters" module that contains constant message data in a single module.
-- Letters describes all Defold system messages by default.
-- You can modify, add or remove messages (letters) with API function
-- or you can access this data directly with pigeon.letter[hashed_message_id].
-- Everytime a letter is posted using Pigeon,
-- the message data is verified according to those settings.

M.letters = require "pigeon.letters"

-- Pigeon pre-hashes messages utilising Defold Hashed by Sergey Lerg:
-- https://github.com/Lerg/defold-hashed
local hashed = require "pigeon.hashed"

-- Localize global values/modules/functions:
local msg, ipairs, pairs, type, tostring = msg, ipairs, pairs, type, tostring

--
-- EXTERNAL DEPENDENCIES
--
-- Pigeon can be coupled with external libraries (like Log or Hashed)
-- If it is not tied to one library it uses a default, simple behaviour.

-- Logging - either use just built-in print function or logging library:
-- LOG - A library by Brian 'Subsoap' Kramer for easy logging:
-- https://github.com/subsoap/log
--
local log = {}

--
-- INTERNAL STATE
--
local id_count = 0
local events = {}
local subscribers = {}
local message_queue = {}
local message_queue_count = 0
local default_tag = "pigeon"

--
-- INTERNAL FUNCTIONS, IMPLEMENTATION
--
local function generate_id()
	local id = id_count
	id_count = id + 1
	return id
end

local function log_is_print()
	log.t = print  -- trace
	log.i = print  -- info
	log.w = print  -- warning
	log.e = print  -- error
end
-- Call this function to set initally print as logging function by default
log_is_print()

local function log_is_empty_call()
	log.t = function() end
	log.i = function() end
	log.w = function() end
	log.e = function() end
end

local function message_id_to_hash(message_id)
	if not message_id then
		log.e("Pigeon: 'message_id' is not given.", default_tag)
		return false
	end
	if type(message_id) == "string" then
		message_id = hashed[message_id] or hash(message_id)-- Ensure message_id is pre-hashed
	end
	if type(message_id) ~= "userdata" then
		log.e("Pigeon: 'message_id' is neither string nor hash.", default_tag)
		return false
	end

	return message_id
end

local function data_has_type(data, value_type, second_value_type)
	if not data then
		log.e("Pigeon: data not given.", default_tag)
		return false
	end
	if not type then
		log.e("Pigeon: type not given.", default_tag)
		return false
	end
	if not second_value_type and type(data) ~= value_type then
		log.e("Pigeon: data has incorrect type: "..(type(data) or "")..". Expected: "..(value_type or ""), default_tag)
		return false
	end
	if second_value_type and not ((type(data) == value_type) or (type(data) == second_value_type)) then
		log.e("Pigeon: data has incorrect type: "..(type(data) or "")..". Expected: "..(value_type or "").." or: "..(second_value_type), default_tag)
		return false
	end
	return true
end

local function define(message_id, message_def)
	-- Defensive programming can be removed on production, when sure
	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		log.e("Pigeon: Failed to define message, id: "..(message_id or "")..". Message_id is incorrect.", default_tag)
		return false
	end
	if M.letters[hashed_message_id] and not data_has_type(message_def, "table") then
		log.e("Pigeon: Failed to redefine message, id: "..(message_id or "")..". New data is incorrect.", default_tag)
		return false
	end

	M.letters[hashed_message_id] = {
		id = hashed_message_id,
		data = message_def
	}
	log.t("Pigeon: Successfully defined message, id: "..(message_id or ""), default_tag)
	return true
end

local function unsubscribe(id)
	-- Defensive programming can be removed on production, when sure
	if not data_has_type(id, "number") then
		log.e("Pigeon: Failed to unsubscribe. Subscriber 'id' is not given or is not a number.", default_tag)
		return false
	end

	local subscriber = subscribers[id]
	if not subscriber then
		log.w("Pigeon: Skipped unsubscribing already unsubscribed or not existing subscriber, id: "..id, default_tag)
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
	log.t("Pigeon: Successfully unsubscribed subscriber, id: "..id, default_tag)
	return true
end

local function subscribe(messages, hook, url)
	-- Defensive programming can be removed on production, when sure
	if messages and (type(messages) == "string" or type(messages) == "userdata") then
		messages = { message_id_to_hash(messages) }
	end
	if not data_has_type(messages, "table") then
		log.e("Pigeon: Failed to subscribe. 'messages' is not given or is not a table.", default_tag)
		return false
	end
	if hook and not data_has_type(hook, "function") then
		log.e("Pigeon: Failed to subscribe. 'hook' is not a function.", default_tag)
		return false
	end

	local id = generate_id()
	url = url or msg.url()

	if subscribers[id] then
		log.w("Pigeon: Overwriting subscriber registered, id: "..id, default_tag)
		unsubscribe(id)
	end

	-- Ensure messages are hashed
	for i,message_id in ipairs(messages) do
		local hashed_message_id = message_id_to_hash(message_id)
		if not hashed_message_id then
			log.e("Pigeon: Failed to subscribe, one of messages, id: "..(message_id or "").." is incorrect.", default_tag)
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

	log.t("Pigeon: Successfully subscribed subscriber, id: "..id, default_tag)
	return id
end

local function is_data_correct(message_id, message)
	local message_definition = M.letters[message_id]
	if not (message_definition and message_definition.data and (type(message_definition.data) == "table") ) then
		log.t("Pigeon: Sending anyway, because no data to check for message, id: "..message_id, default_tag)
		return true
	end

	for key, value_type in pairs(message_definition.data) do
		if message[key] == nil then
			log.e("Pigeon: Failed to send message, id: "..tostring(message_id)..". It expects not nil key: "..key, default_tag)
			return false
		end
		if type(message[key]) ~= value_type then
			log.e("Pigeon: Failed to send message, id: "..tostring(message_id)..". It expects key: ["..key.."] to be of type: "..value_type, default_tag)
			return false
		end
	end
	return true
end

local function send_to(url, message_id, message)
	-- Defensive programming can be removed on production, when sure
	if not data_has_type(url, "userdata", "string") then
		log.e("Pigeon: Failed to send message to url: "..(url or "")..", id:"..(message_id or "")..". Url is incorrect.", default_tag)
		return false
	end

	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		log.e("Pigeon: Failed to send message, id: "..(message_id or "").." is incorrect.", default_tag)
		return false
	end

	message = message or {}

	if not is_data_correct(hashed_message_id, message) then
		return false
	end

	msg.post(url, hashed_message_id, message)
	return true
end

local function send(message_id, message)
	-- Defensive programming can be removed on production, when sure
	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		log.e("Pigeon: Failed to send message, id: "..(message_id or "").." is incorrect.", default_tag)
		return false
	end
	local event = events[hashed_message_id]
	if not event then
		log.e("Pigeon: Failed to send message, id: "..(message_id or "")..". Message_id is not subscribed to anything.", default_tag)
		return true
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

-- Define a new message with an optional specified data definition as a table containing keys as possible keys
-- and values for those keys as possible type of data
-- @param	message_id		[string]	- message_id string or hash (it is ensured to be pre-hashed anyway)
-- @param	[message_def]	[table]		- optional message definition
-- @return	result			[boolean]	- true if message was defined succesfully, false otherwise.
function M.define(message_id, message_def)
	return define(message_id, message_def)
end

-- Subscribe to given message_id(s) and eventually add an optional hook on message sent.
-- @param	messages	[table]		- table containing message_id(s) that caller will be subscribed to.
-- @param	[hook]		[function]	- optional hook function to be called, when sending defined message(s).
-- @param	[url]		[url]		- optional url, to which, the messages are subscribed (default is caller script).
-- @return	id			[number]	- id of the subscriber, or false if subsciption failed.
function M.subscribe(messages, hook, url)
	return subscribe(messages, hook, url)
end

-- Unsubscribe the given subscription.
-- @param	id			[number]	- id of the subscriber to unsubscribe
-- @return	result		[boolean]	- true if unsubscribed succesfully, false otherwise.
function M.unsubscribe(id)
	return unsubscribe(id)
end

-- Unsubscribe all saved subscriptions.
-- @return	result		[boolean]	- true if unsubscribed succesfully, false otherwise.
function M.unsubscribe_all()
	for i,subscriber in ipairs(subscribers) do
		if not unsubscribe(subscriber.id) then
			return false
		end
	end
	return true
end

-- Send a message with an optional data to all subscribers.
-- If the message has a hook attached, it will be called immediately.
-- @param	message_id	[string]	- message_id string or hash
-- @param	[message]	[table]		- optional message definition
-- @return	result		[boolean]	- true if message was sent succesfully, false otherwise.
function M.send(message_id, message)
	-- Defensive programming can be removed on production, when sure
	local hashed_message_id = message_id_to_hash(message_id)
	if not hashed_message_id then
		log.e("Pigeon: Failed to send message, id: "..(message_id or "")..". Message_id is not given or has wrong type.", default_tag)
		return false
	end

	if message_queue_count > 0 then
		message_queue[#message_queue + 1] = { message_id = message_id, message = message }
	else
		if send(message_id, message) then
			log.i("Pigeon: Message sent succesfully, id: "..message_id, default_tag)
			return true
		end
	end
end

-- Send a message with an optional data to specified url.
-- This is a direct replacement for Defold built-in msg.post function.
-- @param	url			[url]		- target's url
-- @param	message_id	[userdata]	- message_id string or hash
-- @param	[message]	[table]		- optional message definition
-- @return	result		[boolean]	- true if message was sent succesfully, false otherwise.
function M.send_to(url, message_id, message)
	send_to(url, message_id, message)
end

-- Enable or disable logging functionality.
-- It only switches between default logging (printing to console) and not logging.
-- If you want to use dependency logging, you need to set dependency again after enabling logging.
-- @note The correctness of arguments is not checked! Use responsibly!
-- @param	enable		[boolean]	- set logging enabled (true) or disabled (false
function M.toggle_logging(enable)
	if enable == true then
		log_is_print()
	elseif enable == false then
		log_is_empty_call()
	end
end

-- Replace internal printing with logging from Log module.
-- It is suited for Log API, so if you want to provide your own module, follow the API,
-- or modify internal Pigeon calls for logging accordingly.
-- @note The correctness of arguments is not checked! Use responsibly!
-- @param	module		[table]		- Lua module being replacement for logging
-- @param	tag			[string]	- change default tag ("pigeon") to your own
function M.set_dependency_module_log(module, tag)
	if module then
		log = module
	else
		log_is_print()
	end
	default_tag = tag or default_tag
end

return M
