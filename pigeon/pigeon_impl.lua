-- Dependencies
local typer = require "pigeon.typer"

---@type table|fun(key: string): hash
local hashed = require "pigeon.hashed"
local letters = require "pigeon.letters"

---@alias MessageIds MessageId[]
---@alias HashedMessageIds HashedMessageId[]
---@alias Url url|string|userdata

---@class LetterEntry
---@field id any
---@field data any

---@class PigeonImpl
local PigeonImpl = {}

PigeonImpl.letters = letters

-- Map built-in letters by hashed id and keep a snapshot for override protection.
local builtin_letter_ids = {}
do
	local defs = {}
	for _, def in pairs(letters) do
		if type(def) == "table" and def.id then
			defs[def.id] = def
		end
	end
	for id, def in pairs(defs) do
		letters[id] = def
		builtin_letter_ids[id] = true
	end
end

-- Localise globals
local print, pairs, ipairs, msg, type, tostring, hash, pcall = print, pairs, ipairs, msg, type, tostring, hash, pcall

local function build_print_logger()
	return {
		debug = print,
		trace = print,
		info = print,
		warn = print,
		error = print
	}
end

local function build_noop_logger()
	local noop = function() end
	return {
		debug = noop,
		trace = noop,
		info = noop,
		warn = noop,
		error = noop
	}
end

---@type logger
local log = build_print_logger()

-- Internal state
---@type number
local id_count = 1

---@type table<hash, table>
local events = {}

---@type table<number, table>
local subscribers = {}

---@type table[]
local message_queue = {}

---@type number
local message_queue_count = 0

---@type string
local default_tag = "pigeon"

---@type table
local string_or_hash = {"string", "userdata", "hash"}

---------------------------
-- Private functions
---------------------------

---Generate a unique id (ascending order integer) for subscriptions
---@return number @Unique identifier
local function generate_id()
	local id = id_count
	id_count = id_count + 1
	return id
end

---Ensure message_id is hashed
---@param message_id	MessageId		@Defold message_id string or hashed
---@return				HashedMessageId	@Hashed message_id
local function ensure_hashed(message_id)
	typer.assert_type(message_id, string_or_hash, "message_id must be a string or hash")
	return hashed(message_id --[[@as string]])
end

---Convert messages to table of HashedMessageId
---@param message_ids	MessageIds			@Messages to subscribe for
---@return				HashedMessageIds	@Converted messages table
local function ensure_hashed_message_ids(message_ids)
	local converted = {}
	for i, message_id in ipairs(message_ids) do
		converted[i] = ensure_hashed(message_id)
	end
	return converted
end

local function resolve_messages_table(messages)
	if typer.is_type(messages, "table") then
		return ensure_hashed_message_ids(messages)
	end
	if typer.is_type(messages, string_or_hash) then
		return {ensure_hashed(messages)}
	end
	return nil
end

---@param message_id HashedMessageId
local function remove_event_if_empty(message_id)
	local event = events[message_id]
	if event and (not next(event.hooks)) and (not next(event.subs)) then
		events[message_id] = nil
	end
end

---@param value any
---@return boolean
local function is_url_value(value)
	return typer.is_type(value, {"url", "string", "userdata"})
end

---Checks if given message contains correct data for given message_id if it is defined in Pigeon
---@param message_id	HashedMessageId		@Hashed message_id
---@param message		MessageDefinition	@Given message table to check
---@return				boolean				@True if data is correct, false otherwise
local function is_data_correct(message_id, message)
	local message_definition = PigeonImpl.letters[message_id]
	if (not message) or (not message_definition) or (not message_definition.data) or
					typer.is_empty(message_definition.data) then
		log.trace("No data to check for message_id: " .. message_id)
		return true
	end

	for key, type_definition in pairs(message_definition.data) do
		local value = message[key]
		if not typer.is_type(value, type_definition) then
			log.error("Data incorrect for message_id: " .. message_id .. ". Expected key: [" .. key .. "] of type: " ..
							          type_definition .. " but is: " .. type(value))
			return false
		end
	end
	return true
end

---------------------------
-- Public API Implementation
---------------------------

---@param value any
---@return boolean
function PigeonImpl.is_url_value(value)
	return is_url_value(value)
end

---Define a single message schema to be checked in runtime by Pigeon.
---@param message_id MessageId @Defold message_id string or hashed.
---@param message_def? MessageDefinition @Optional message definition table.
---@return boolean @True if defined successfully, false otherwise.
function PigeonImpl.define(message_id, message_def)
	if not typer.is_type(message_id, {"string", "userdata"}) then
		log.error("Failed to define. 'message_id' must be a string or hash.")
		return false
	end

	local hashed_message_id = ensure_hashed(message_id)
	if not hashed_message_id then
		log.error("Failed to define. Invalid 'message_id'.")
		return false
	end

	if builtin_letter_ids[hashed_message_id] then
		log.error("Refusing to redefine built-in Defold/system message_id: " .. tostring(message_id))
		return false
	end

	if PigeonImpl.letters[hashed_message_id] and not typer.is_type(message_def, "table") then
		log.error("Failed to redefine. 'message_def' must be a table.")
		return false
	end

	PigeonImpl.letters[hashed_message_id] = {
		id = hashed_message_id,
		data = message_def
	}
	log.trace("Successfully defined message, id: " .. tostring(message_id))
	return true
end

---Define multiple message schemas at once from a table of letter definitions.
---@param letters_table table<string, LetterEntry> @Table mapping keys to {id = MessageId, data = MessageDefinition}.
---@param is_overwriting? boolean @If true, allows overwriting existing user-defined definitions. Built-in messages are always protected.
---@return table<string,boolean> @Per-key result map.
function PigeonImpl.define_batch(letters_table, is_overwriting)
	local results = {}
	for name, def in pairs(letters_table) do
		if type(def) == "table" and def.id ~= nil then
			local hashed_id = ensure_hashed(def.id)
			if builtin_letter_ids[hashed_id] then
				results[name] = PigeonImpl.define(def.id, def.data)
			elseif not PigeonImpl.letters[hashed_id] or is_overwriting then
				results[name] = PigeonImpl.define(def.id, def.data)
			end
		end
	end
	return results
end

---Subscribe to given message_id(s) and optionally add a hook on message sent.
---Hook runs synchronously in the sender context (inside PigeonImpl.send) before msg.post.
---@param messages	MessageIds|MessageId	@Messages to subscribe for
---@param hook?		function				@Optional hook function that receives (message_id:hash, message:table, context:table)
---@param context?	table					@Optional context to be passed to the hook function
---@param url?		Url						@Optional URL of the subscriber
---@param is_optimizing? boolean @Skip subscribing to messages already registered for the same url
---@return			number|boolean			@Unique id of subscriber if subscribed successfully, false otherwise
function PigeonImpl.subscribe(messages, hook, context, url, is_optimizing)
	assert(messages, "'messages' must be provided")
	if typer.is_empty(messages) then
		log.warn("Failed to subscribe. 'messages' is empty.")
		return false
	end

	local messages_table
	if typer.is_type(messages, "table") then
		messages_table = ensure_hashed_message_ids(messages --[[@as MessageIds]])
	elseif typer.is_type(messages, string_or_hash) then
		messages_table = {ensure_hashed(messages --[[@as MessageId]])}
	else
		log.error("Failed to subscribe. 'messages' must be a table, hash, or string.")
		return false
	end

	if hook and not typer.is_type(hook, "function") then
		log.error("Failed to subscribe. 'hook' must be a function.")
		return false
	end

	local id = generate_id()
	local resolved_url = url or msg.url()
	if not is_url_value(resolved_url) then
		log.error("Failed to subscribe. 'url' must be a Defold url userdata or string.")
		return false
	end

	if is_optimizing then
		local already_subscribed = {}
		for _, sub in pairs(subscribers) do
			if sub.url == resolved_url and not sub.hook then
				for _, message_id in ipairs(sub.messages) do
					already_subscribed[message_id] = true
				end
			end
		end

		local filtered = {}
		for _, message_id in ipairs(messages_table) do
			if not already_subscribed[message_id] then
				filtered[#filtered + 1] = message_id
			end
		end

		if #filtered == 0 then
			log.warn("Not subscribing. Messages already registered for url: " .. tostring(resolved_url))
			return false
		end

		messages_table = filtered
	end

	-- Add subscriber
	local subscriber = {
		id = id,
		url = resolved_url,
		messages = messages_table,
		hook = hook,
		context = context
	}
	subscribers[id] = subscriber

	-- Create events for given messages
	for _, event_message_id in ipairs(messages_table) do
		if event_message_id then
			local event = events[event_message_id] or {
				hooks = {},
				subs = {}
			}
			events[event_message_id] = event

			if hook then
				event.hooks[id] = subscriber
			else
				event.subs[id] = subscriber
			end
		end
	end

	log.trace("Successfully subscribed subscriber with id: " .. id)
	return id
end

---Add message subscriptions to an existing subscriber id.
---@param id number @Id of the subscriber to extend
---@param messages MessageIds|MessageId @Messages to add
---@return boolean @True if updated successfully, false otherwise
function PigeonImpl.extend_subscription(id, messages)
	if not id or not typer.is_type(id, "number") then
		log.error("Failed to add subscriptions. 'id' must be a number.")
		return false
	end

	local subscriber = subscribers[id]
	if not subscriber then
		log.debug("Attempted to add subscriptions to non-existing subscriber with id: " .. id)
		return true
	end

	local messages_table = resolve_messages_table(messages)
	if not messages_table then
		log.error("Failed to add subscriptions. 'messages' must be a table, hash, or string.")
		return false
	end

	local existing = {}
	for _, message_id in ipairs(subscriber.messages) do
		existing[message_id] = true
	end

	for _, message_id in ipairs(messages_table) do
		if message_id and not existing[message_id] then
			subscriber.messages[#subscriber.messages + 1] = message_id
			local event = events[message_id] or {
				hooks = {},
				subs = {}
			}
			events[message_id] = event
			if subscriber.hook then
				event.hooks[id] = subscriber
			else
				event.subs[id] = subscriber
			end
		end
	end

	log.trace("Successfully added subscriptions to subscriber with id: " .. id)
	return true
end

---Remove message subscriptions from an existing subscriber id.
---@param id number @Id of the subscriber to update
---@param messages MessageIds|MessageId @Messages to remove
---@return boolean @True if updated successfully, false otherwise
function PigeonImpl.reduce_subscription(id, messages)
	if not id or not typer.is_type(id, "number") then
		log.error("Failed to remove subscriptions. 'id' must be a number.")
		return false
	end

	local subscriber = subscribers[id]
	if not subscriber then
		log.debug("Attempted to remove subscriptions from non-existing subscriber with id: " .. id)
		return true
	end

	local messages_table = resolve_messages_table(messages)
	if not messages_table then
		log.error("Failed to remove subscriptions. 'messages' must be a table, hash, or string.")
		return false
	end

	local to_remove = {}
	for _, message_id in ipairs(messages_table) do
		to_remove[message_id] = true
	end

	local remaining = {}
	for _, message_id in ipairs(subscriber.messages) do
		if not to_remove[message_id] then
			remaining[#remaining + 1] = message_id
		end
	end

	if #remaining == 0 then
		return PigeonImpl.unsubscribe(id)
	end

	for _, message_id in ipairs(messages_table) do
		local event = events[message_id]
		if event then
			event.subs[id] = nil
			event.hooks[id] = nil
			remove_event_if_empty(message_id)
		end
	end

	subscriber.messages = remaining
	log.trace("Successfully removed subscriptions from subscriber with id: " .. id)
	return true
end

---Unsubscribe one or more subscribers by id.
---@param id number|number[]|boolean|nil @Single subscriber id, or a table of subscriber ids to unsubscribe.
---@return boolean @True if all unsubscribed successfully, false otherwise.
function PigeonImpl.unsubscribe(id)
	if typer.is_type(id, "table") then
		local all_ok = true
		for _, single_id in ipairs(id --[[@as number[] ]]) do
			if not single_id then
				-- skip false/nil entries silently
			elseif not PigeonImpl._unsubscribe_single(single_id) then
				all_ok = false
			end
		end
		return all_ok
	end
	if not id then
		return false
	end
	return PigeonImpl._unsubscribe_single(id --[[@as number|boolean|nil]])
end

---@param id number|boolean|nil
---@return boolean
function PigeonImpl._unsubscribe_single(id)
	if not id or not typer.is_type(id, "number") then
		log.error("Failed to unsubscribe. 'id' must be a number.")
		return false
	end

	local subscriber = subscribers[id]
	if not subscriber then
		log.debug("Attempted to unsubscribe non-existing subscriber with id: " .. id)
		return true
	end

	for _, message_id in ipairs(subscriber.messages) do
		local event = events[message_id]
		if event then
			event.subs[id] = nil
			event.hooks[id] = nil
			remove_event_if_empty(message_id)
		end
	end

	subscribers[id] = nil
	log.trace("Successfully unsubscribed subscriber with id: " .. id)
	return true
end

---Unsubscribe all saved subscriptions
---@return boolean @True if unsubscribed all successfully, false otherwise
function PigeonImpl.unsubscribe_all()
	for id, _ in pairs(subscribers) do
		if not PigeonImpl.unsubscribe(id) then
			return false
		end
	end
	return true
end

---Send a message to all subscribed subscribers
---@param message_id MessageId @Defold message_id string or hashed
---@param message? table @Optional message table to check
---@return boolean @True if data is correct and sent successfully, false otherwise
function PigeonImpl.send(message_id, message)
	--client:setoption(option, value)log.debug("Pigeon: Sending message - id: ".. tostring(message_id) or "")
	local hashed_message_id = ensure_hashed(message_id)
	if not hashed_message_id then
		log.warn("Not sending. 'message_id' is not provided: " .. hashed_message_id)
		return false
	end

	local event = events[hashed_message_id]
	if (not event) or ((not next(event.hooks)) and (not next(event.subs))) then
		remove_event_if_empty(hashed_message_id)
		log.warn("Not sending. 'message_id' is not subscribed: " .. hashed_message_id)
		return false
	end

	message = message or {}

	if not is_data_correct(hashed_message_id, message) then
		log.warn("Not sending. Data is incorect for: " .. hashed_message_id)
		return false
	end

	-- Add message to queue
	message_queue_count = message_queue_count + 1
	-- Call all hooks immediately
	for _, sub in pairs(event.hooks) do
		log.debug("Pigeon: Calling hook for " .. tostring(hashed_message_id))
		sub.hook(hashed_message_id, message, sub.context)
	end

	-- Send message to all subscribers
	for _, sub in pairs(event.subs) do
		msg.post(sub.url, hashed_message_id, message)
	end

	-- If there are more messages in queue, send them
	if (message_queue_count == 1) and next(message_queue) then
		for _, queued_msg in ipairs(message_queue) do
			PigeonImpl.send(queued_msg.message_id, queued_msg.message)
		end
		message_queue = {}
	end

	-- Remove message from queue
	message_queue_count = message_queue_count - 1

	--log.debug("Pigeon: Message sent: " .. tostring(message_id))

	return true
end

---Send a message to a specified url or game object id.
---Accepts the same target forms as Defold's `msg.post`: a `url` userdata,
---a url-like `string` (e.g. "/gui#hud" or "#fragment"), or a `hash`
---(e.g. the id returned by `factory.create` or `go.get_id`).
---@param url url|string|hash @Target url, url-like string, or game object hash id
---@param message_id string|hash @Defold message_id string or hashed
---@param message? table @Optional message table to check
---@return boolean @True if data is correct and sent successfully, false otherwise
function PigeonImpl.send_to(url, message_id, message)
	if not is_url_value(url) then
		log.error("Failed to send. 'url' is invalid: " .. tostring(url))
		return false
	end

	local hashed_message_id = ensure_hashed(message_id)
	if not hashed_message_id then
		log.error("Failed to send. Invalid 'message_id': " .. tostring(message_id))
		return false
	end

	message = message or {}

	if not is_data_correct(hashed_message_id, message) then
		log.warn("Not sending. Data is incorect for: " .. hashed_message_id)
		return false
	end

	msg.post(url, hashed_message_id, message)
	return true
end

---Replace internal printing with logging from Log module
---@param module table|nil @Lua module being replacement for logging. Nil resets to print logger.
---@param tag? string @Optional own string tag to replace the default tag
function PigeonImpl.set_logger(module, tag)
	if module == nil then
		log = build_print_logger()
		default_tag = tag or default_tag
		return true
	end

	if not typer.is_type(module, "table") then
		log.error("Logging module must be a table.")
		return false
	end

	-- A logger instance exposing trace/debug/info/warn/error
	if module.trace and type(module.trace) == "function" and
	   module.debug and type(module.debug) == "function" and
	   module.info and type(module.info) == "function" and
	   module.warn and type(module.warn) == "function" and
	   module.error and type(module.error) == "function" then

		log = {
			trace = function(text) module:trace(text) end,
			debug = function(text) module:debug(text) end,
			info = function(text) module:info(text) end,
			warn = function(text) module:warn(text) end,
			error = function(text) module:error(text) end
		}
	-- A module factory exposing .new(tag, ...)
	elseif module.new and type(module.new) == "function" then
		tag = tag or default_tag
		local squid_instance = module.new(tag, true)
		log = {
			trace = function(text) squid_instance:trace(text) end,
			debug = function(text) squid_instance:debug(text) end,
			info = function(text) squid_instance:info(text) end,
			warn = function(text) squid_instance:warn(text) end,
			error = function(text) squid_instance:error(text) end
		}
	-- A named logger object (e.g. Defold-Log instance)
	elseif typer.is_type(module.name, "string") then
		log = {
			info = function(text) module:info(text) end,
			warn = function(text) module:warn(text) end,
			error = function(text) module:error(text) end,
			debug = function(text) module:debug(text) end,
			trace = function(text) module:trace(text) end
		}
	-- Fallback: use given table directly
	else
		log = module
	end

	default_tag = tag or default_tag
	return true
end

function PigeonImpl.subscribe_events(events)
	assert(events, "'events' must be provided")
	assert(typer.is_type(events, "table"), "'events' must be a table")

	for _, event in ipairs(events) do
		local event_message_id = event.id
		local event_handler = event.handler
		local event_context = event.context
		local event_url = event.url

		PigeonImpl.subscribe(event_message_id, event_handler, event_context, event_url)
	end
end

---Creates new instance that registers message handlers and subscribes to their messages
---@param handlers table<hash, function> @Table of message handlers where key is hashed message_id and value is handler function
---@param tag? string @Optional own string tag to replace the default tag ("pign")
---@return table @Table containing on_message function and final function to be used in script
function PigeonImpl.new(handlers, tag)
	assert(handlers, "'handlers' must be provided")
	assert(type(handlers) == "table", "'handlers' must be a table")

	-- Extract message_ids from handlers
	local messages = {}
	for message_id, _ in pairs(handlers) do
		table.insert(messages, message_id)
	end

	-- Subscribe to all messages
	local subscription = PigeonImpl.subscribe(messages)
	tag = tag or default_tag

	-- Create message handler
	local handler = {
		subscription = subscription,
		tag = tag,
		on_message = function(self, message_id, message, sender)
			log.trace("Received message: " .. message_id, tag)
			if handlers[message_id] then
				handlers[message_id](message, sender, self)
			end
		end,
		final = function(self)
			PigeonImpl.unsubscribe(subscription)
			log.info("Unsubscribed pigeon instance", tag)
		end
	}

	return handler
end

---Enable or disable logging functionality
---@param enable boolean @Flag to set logging enabled (true) or disabled (false)
function PigeonImpl.toggle_logging(enable)
	if enable == true then
		log = build_print_logger()
	elseif enable == false then
		log = build_noop_logger()
	end
	return true
end

return PigeonImpl
