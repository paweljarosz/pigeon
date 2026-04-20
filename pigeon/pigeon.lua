--
-- Pigeon
--
-- Version: 1.5
--
-- Read details in the README.md file.
--
-- Copyright Paweł Jarosz 2023-2026
-- License: MIT

---------------------------
-- External dependencies
---------------------------
-- Pigeon can be coupled with an external library for logging.
-- By default it uses a simple print function.
-- Library must be compatible with logger API.
---@see Pigeon.set_dependency_module_log

---@class logger
---@field debug function
---@field trace function
---@field info function
---@field warn function
---@field error function

---------------------------
-- Internal dependencies
---------------------------
local PigeonImpl = require "pigeon.pigeon_impl"

---Letters are messages defined by Pigeon.
---Pigeon provides an example "letters" module that contains constant message data definitions in a single module.
---This Letters module describes all Defold system messages by default.
---You can modify, add, or remove messages (letters) with API functions,
---or you can access this data directly using Pigeon.letters[hashed_message_id].
---Every time a message is posted using Pigeon with this message defined as a letter,
---the message data is verified according to these settings.
---@class Pigeon
---@field public letters Letters
---@field define fun(message_id: MessageId, message_def?: MessageDefinition): boolean
---@field define_batch fun(letters_table: table<string, LetterEntry>, is_overwriting?: boolean): table<string,boolean>
---@field subscribe fun(messages: MessagesGroup, callback?: function, url?: url|userdata|string, context?: table, is_optimizing?: boolean): number|boolean
---@field extend_subscription fun(id: number, messages: MessagesGroup): boolean
---@field reduce_subscription fun(id: number, messages: MessagesGroup): boolean
---@field unsubscribe fun(id: number|number[]|boolean|nil): boolean
---@field unsubscribe_all fun(): boolean
---@field send fun(message_id: MessageId, message?: table): boolean
---@field send_to fun(url: url|userdata|string|hash, message_id: MessageId, message?: table): boolean
---@field toggle_logging fun(enable: boolean): boolean
---@field set_dependency_module_log fun(module: table|nil, tag?: string): boolean
---@field set_dependency_module_hashed fun(module: function): boolean @Deprecated, no-op.
---@field new fun(handlers: table<hash, function>, tag?: string): table
local Pigeon = {}

---------------------------
-- Public members
---------------------------
Pigeon.letters = PigeonImpl.letters

---------------------------
-- Pigeon API
---------------------------

---Define a single message schema for runtime validation.
---Built-in Defold/system message ids are always protected from redefinition.
---@param	message_id		MessageId			@Defold message_id string or hashed.
---@param	message_def?	MessageDefinition	@Optional message definition table.
---@return					boolean				@True if defined successfully, false otherwise.
function Pigeon.define(message_id, message_def)
	return PigeonImpl.define(message_id, message_def)
end

---Define multiple message schemas at once from a table of letter definitions.
---Built-in Defold/system message ids are always protected from redefinition.
---@param	letters_table	table<string, LetterEntry>	@Table mapping keys to {id = MessageId, data = MessageDefinition}.
---@param	is_overwriting?	boolean						@If true, allows overwriting existing user-defined definitions.
---@return					table<string,boolean>		@Per-key result map.
function Pigeon.define_batch(letters_table, is_overwriting)
	return PigeonImpl.define_batch(letters_table, is_overwriting)
end

---Subscribe to given message_id(s) and optionally add a hook called immediately on send.
---Hook runs synchronously in the sender context (inside Pigeon.send) before msg.post,
---and does not run in the receiver script.
---@param	messages	MessagesGroup		@Table containing message_id(s) that caller will be subscribed to. Can be a single message as string or hash or a table containing messages as strings or hashes.
---@param	callback?	function			@Optional callback function to be called everytime, when sending subscribed message(s). Uses context parameter.
---@param	url?		url|userdata|string		@Optional URL of the subscriber (v1.3 order).
---@param	context?	table				@Optional context to be passed to the callback function.
---@param	is_optimizing? boolean @If true, skips subscribing to messages already registered for the same url.
---@return				number|boolean		@Unique id of the subscription if subscribed succesfully, false otherwise.
function Pigeon.subscribe(messages, callback, url, context, is_optimizing)
	if (url ~= nil) and (not PigeonImpl.is_url_value(url)) then
		return false
	end
	return PigeonImpl.subscribe(messages, callback, context, url, is_optimizing)
end

---Add message subscriptions to an existing subscriber id.
---@param	id	number					@Id of the subscriber to update.
---@param	messages	MessagesGroup	@Table containing message_id(s) to add.
---@return		boolean				@True if updated successfully, false otherwise.
function Pigeon.extend_subscription(id, messages)
	return PigeonImpl.extend_subscription(id, messages)
end

---Remove message subscriptions from an existing subscriber id.
---@param	id	number					@Id of the subscriber to update.
---@param	messages	MessagesGroup	@Table containing message_id(s) to remove.
---@return		boolean				@True if updated successfully, false otherwise.
function Pigeon.reduce_subscription(id, messages)
	return PigeonImpl.reduce_subscription(id, messages)
end

---Unsubscribe one or more subscriptions.
---@param	id	number|number[]|boolean|nil	@Single subscriber id, or a table of subscriber ids. If false or nil it will do nothing and will return false.
---@return		boolean				@True if all unsubscribed succesfully, false otherwise.
function Pigeon.unsubscribe(id)
	return PigeonImpl.unsubscribe(id)
end

---Unsubscribe all saved subscriptions.
---@return		boolean		@True if unsubscribed all succesfully, false otherwise.
function Pigeon.unsubscribe_all()
	return PigeonImpl.unsubscribe_all()
end

---Send a message of given message_id with given message table to all subscribed subscribers.
---Additionally, Pigeon checks in runtime if message is correct if defined.
---If the message has a hook attached, it will be called immediately.
---@param	message_id	MessageId			@Defold message_id string or hashed. It will be prehashed anyway.
---@param	message?	table				@Optional definition message table to check before sending.
---@return				boolean				@True if data is correct and send succesfully, false otherwise.
function Pigeon.send(message_id, message)
	return PigeonImpl.send(message_id, message)
end

---Equivalent to Defold built-in `msg.post`. Sends a message of given message_id with an optional data in message table to a specified url.
---Accepts the same target forms as `msg.post`: a `url` userdata, a url-like
---`string` (e.g. "/gui#hud" or "#fragment"), or a `hash` game object id
---(e.g. the id returned by `factory.create` or `go.get_id`).
---Additionally, Pigeon checks in runtime if message is correct if defined.
---@param	url			url|string|hash|userdata	@Target's url, url-like string, or game object hash id.
---@param	message_id	MessageId					@Defold message_id string or hashed. It will be prehashed anyway.
---@param	message?	table						@Optional message table to check.
---@return				boolean						@True if data is correct and send succesfully, false otherwise.
function Pigeon.send_to(url, message_id, message)
	return PigeonImpl.send_to(url, message_id, message)
end

---Enable or disable logging functionality.
---It only switches between default logging (printing to console) and not logging.
---If you want to use dependency logging, you need to set dependency again after enabling logging.
---The correctness of arguments is not checked! Use responsibly!
---@param	enable		boolean				@Flag to set logging enabled (true) or disabled (false).
function Pigeon.toggle_logging(enable)
	return PigeonImpl.toggle_logging(enable)
end

---Replace internal printing with logging from Log module.
---It is suited for Log API, so if you want to provide your own module, follow the API,
---or modify internal Pigeon calls for logging accordingly.
---The correctness of arguments is not checked! Use responsibly!
---@param	module		table|nil			@Lua module being replacement for logging. Nil resets to default print logger.
---@param	tag?		string				@Optional own string tag to replace the default tag ("pign").
function Pigeon.set_dependency_module_log(module, tag)
	return PigeonImpl.set_logger(module, tag)
end

---@deprecated Pigeon always uses its internal `hashed` module. This function is a no-op kept for backward compatibility.
---@param	module		function
---@return				boolean
function Pigeon.set_dependency_module_hashed(module)
	return true
end

---Creates a new instance that registers message handlers and subscribes to their messages with an optional tag for logging.
---@param handlers	table<hash, function>	@Table of message handlers where key is hashed message_id and value is handler function
---@param tag?		string					@Optional own string tag to replace the default tag ("pign").
---@return			table					@Table containing on_message function and final function to be used in script
function Pigeon.new(handlers, tag)
	return PigeonImpl.new(handlers, tag)
end

return Pigeon --@as Pigeon
