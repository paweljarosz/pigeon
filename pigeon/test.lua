local M = {}

local pigeon = require "pigeon.pigeon"

local passed = 0
local failed = 0

local function test(name, assert_value_true)
	if assert_value_true then
		passed = passed + 1
		print("[OK] Pigeon Test: "..name)
	else
		failed = failed + 1
		print("[FAIL] Pigeon Test: "..name)
	end
end

function M.run()
	passed = 0
	failed = 0

	pigeon.toggle_logging(false)

	print("")
	print("Pigeon tests start --------")

	test("Correct message definition string.", pigeon.define("test", {test_data = "string"}))
	test("Correct message definition hash.", pigeon.define(hash("test1"), {test_data = "string", test_data_second = "number"}))
	test("Redefinition with new data.", pigeon.define(hash("test1"), {test_data = "string"}))
	test("Redefinition without new data is blocked.", not pigeon.define(hash("test1")))
	test("Incorrect message definition. Wrong id type.", not pigeon.define(1, {test_data = "string"}))
	test("Incorrect message definition. Data is not table.", not pigeon.define("test", "unknown"))

	local test_subscription_id = pigeon.subscribe({"test"})
	test("Correctly subscribed, message is a table.", pigeon.subscribe({"test"}))
	test("Correctly subscribed, again.", pigeon.subscribe({"test"}))
	test("Correctly subscribed, even not defined messages.", pigeon.subscribe({"test", "test2"}))
	test("Correctly subscribed, message is a single string.", pigeon.subscribe("test"))
	test("Correctly subscribed, message is a single hash.", pigeon.subscribe(hash("test")))
	test("Subscription failed, message is not a table, string or hash.", not pigeon.subscribe(1) )
	test("Subscription failed, messages table is empty.", not pigeon.subscribe({}))

	test("Correctly subscribed with hook given.", pigeon.subscribe("test", function() end))
	test("Subscription failed, hook is not a function.", not pigeon.subscribe("test", 1))
	test("Correctly subscribed with url.", pigeon.subscribe({"test"}, nil, "#" ))

	test("Correctly send defined message.", pigeon.send("test", {test_data = "testing"}))
	test("Don't allow to send message that is not subscribed.", not pigeon.send("test3"))

	test("Correctly unsubscribed.", pigeon.unsubscribe(test_subscription_id))
	test("Unsubscription failed, id is not given.", not pigeon.unsubscribe())
	test("Unsubscription failed, id is not number.", not pigeon.unsubscribe("test"))
	test("Unsubscription failed, id is false.", not pigeon.unsubscribe(false))
	test("Unsubscription failed, id is nil.", not pigeon.unsubscribe(nil))
	test("Correctly unsubscribed all subscribers.", pigeon.unsubscribe_all())

	-- Compatibility aliases
	test("`letters` field is available.", pigeon.letters ~= nil)
	test("send_to validates arguments.", not pigeon.send_to(1, "test"))
	test("send_to sends message for valid target and id.", pigeon.send_to(".", "post_alias_test"))

	-- Dynamic subscription management (add/remove subscriptions on the fly)
	local dynamic_seen = {}
	local dynamic_subscription = pigeon.subscribe("dynamic_a", function(message_id)
		dynamic_seen[message_id] = (dynamic_seen[message_id] or 0) + 1
	end)
	test("Dynamic subscription created.", dynamic_subscription)
	test("extend_subscription adds another message for existing subscriber.", pigeon.extend_subscription(dynamic_subscription, "dynamic_b"))
	test("dynamic_a can be sent.", pigeon.send("dynamic_a"))
	test("dynamic_b can be sent after extend_subscription.", pigeon.send("dynamic_b"))
	test("Hook receives both dynamic messages.", dynamic_seen[hash("dynamic_a")] == 1 and dynamic_seen[hash("dynamic_b")] == 1)

	test("reduce_subscription removes only selected message.", pigeon.reduce_subscription(dynamic_subscription, "dynamic_b"))
	test("Removed dynamic_b is no longer sendable.", not pigeon.send("dynamic_b"))
	test("Remaining dynamic_a is still sendable.", pigeon.send("dynamic_a"))
	test("Hook still receives remaining message.", dynamic_seen[hash("dynamic_a")] == 2 and dynamic_seen[hash("dynamic_b")] == 1)

	test("extend_subscription fails for invalid messages type.", not pigeon.extend_subscription(dynamic_subscription, 1))
	test("reduce_subscription fails for invalid messages type.", not pigeon.reduce_subscription(dynamic_subscription, 1))

	test("reduce_subscription removing last message auto-unsubscribes.", pigeon.reduce_subscription(dynamic_subscription, "dynamic_a"))
	test("Last removed message is no longer sendable.", not pigeon.send("dynamic_a"))
	test("extend_subscription fails for invalid subscriber id type.", not pigeon.extend_subscription("invalid", "dynamic_x"))
	test("reduce_subscription fails for invalid subscriber id type.", not pigeon.reduce_subscription("invalid", "dynamic_x"))
	test("extend_subscription on missing subscriber id is no-op success.", pigeon.extend_subscription(999999, "dynamic_x"))
	test("reduce_subscription on missing subscriber id is no-op success.", pigeon.reduce_subscription(999999, "dynamic_x"))

	-- Recipient optimization branch in subscribe()
	local optimized_first = pigeon.subscribe("optimized_msg", nil, "#")
	test("Optimization setup subscription created.", optimized_first)
	local optimized_second = pigeon.subscribe("optimized_msg", nil, "#", nil, true)
	test("Optimized subscribe skips already subscribed recipients.", not optimized_second)
	test("Optimization setup subscriber can be unsubscribed.", pigeon.unsubscribe(optimized_first))

	-- Hook behavior: arguments/context and validation gate
	test("Define hook_behavior message schema.", pigeon.define("hook_behavior", {value = "number"}))
	local hook_calls = 0
	local hook_seen_id = nil
	local hook_seen_value = nil
	local hook_context = {source = "hook_behavior_context"}
	local hook_seen_context = nil
	local hook_subscription = pigeon.subscribe("hook_behavior", function(message_id, message, context)
		hook_calls = hook_calls + 1
		hook_seen_id = message_id
		hook_seen_value = message and message.value
		hook_seen_context = context
	end, "#", hook_context)
	test("Hook behavior subscription created.", hook_subscription)
	test("hook_behavior valid send succeeds.", pigeon.send("hook_behavior", {value = 7}))
	test("Hook receives expected message_id/message/context.",
		hook_calls == 1 and
		hook_seen_id == hash("hook_behavior") and
		hook_seen_value == 7 and
		hook_seen_context == hook_context)
	test("hook_behavior invalid send fails validation.", not pigeon.send("hook_behavior", {value = "wrong_type"}))
	test("Hook is not called when send fails validation.", hook_calls == 1)
	test("Hook behavior subscriber can be unsubscribed.", pigeon.unsubscribe(hook_subscription))
	test("After hook unsubscribe there are no subscribers for hook_behavior.", not pigeon.send("hook_behavior", {value = 9}))
	test("Hook remains not called after unsubscribe.", hook_calls == 1)

	-- Batch define_batch behavior for new, existing and overwrite modes
	local batch_first = pigeon.define_batch({
		batch_case = { id = "batch_case", data = {value = "string"} }
	})
	test("define_batch defines a new custom message.", batch_first.batch_case == true)
	test("define_batch defined schema accepts initial type.", pigeon.send_to(".", "batch_case", {value = "ok"}))
	test("define_batch defined schema rejects wrong type.", not pigeon.send_to(".", "batch_case", {value = 1}))

	local batch_no_overwrite = pigeon.define_batch({
		batch_case = { id = "batch_case", data = {value = "number"} }
	})
	test("define_batch without overwrite keeps existing custom message definition.",
		batch_no_overwrite.batch_case == nil and
		pigeon.send_to(".", "batch_case", {value = "ok"}) and
		not pigeon.send_to(".", "batch_case", {value = 1}))

	local batch_with_overwrite = pigeon.define_batch({
		batch_case = { id = "batch_case", data = {value = "number"} }
	}, true)
	test("define_batch with overwrite redefines existing custom message.",
		batch_with_overwrite.batch_case == true and
		not pigeon.send_to(".", "batch_case", {value = "ok"}) and
		pigeon.send_to(".", "batch_case", {value = 1}))

	-- Built-in message protection (issue: accidental override of Defold core messages)
	local load_hash = hash("load")
	local original_load_definition = pigeon.letters[load_hash]
	test("Built-in `load` redefinition is always blocked.", not pigeon.define("load", {menu = "string"}))
	test("Built-in `load` redefinition with hash is always blocked.", not pigeon.define(load_hash, {menu = "string"}))
	test("Built-in `load` redefinition stays blocked even with legacy third argument.", not pigeon.define("load", {menu = "string"}, true))
	test("Built-in `load` hash redefinition stays blocked even with legacy third argument.", not pigeon.define(load_hash, {menu = "string"}, true))
	local builtin_batch_result = pigeon.define_batch({
		builtin_load = { id = "load", data = {menu = "string"} }
	}, true)
	test("Built-in `load` redefinition via define_batch is always blocked.", builtin_batch_result.builtin_load == false)
	pigeon.letters[load_hash] = original_load_definition
	test("Built-in `load` definition restored after test.", pigeon.letters[load_hash] == original_load_definition)

	-- subscribe() backward compatibility: v1.3 style + optional context
	local old_style_context = {source = "old_style"}
	local old_style_context_ok = false
	local old_style_subscription = pigeon.subscribe("compat_old_style", function(_, _, context)
		old_style_context_ok = context == old_style_context
	end, "#", old_style_context)
	test("subscribe supports old style order: (messages, hook, url, context).", old_style_subscription)
	test("send works for old style subscriber.", pigeon.send("compat_old_style"))
	test("old style hook receives provided context.", old_style_context_ok)
	test("old style subscriber can be unsubscribed.", pigeon.unsubscribe(old_style_subscription))

	local url_only_subscription = pigeon.subscribe("compat_url_only", nil, "#")
	test("subscribe supports v1.3 signature: (messages, hook, url).", url_only_subscription)
	test("url-only subscriber can be unsubscribed.", pigeon.unsubscribe(url_only_subscription))

	-- alternate style is intentionally not supported in public API
	test("subscribe rejects alternate order: (messages, hook, context, url).", not pigeon.subscribe("compat_new_style", function() end, {source = "new_style"}, "#"))

	-- Logger/hash dependency API compatibility from v1.3
	local logger_stub = {
		trace = function() end,
		debug = function() end,
		info = function() end,
		warn = function() end,
		error = function() end,
	}
	test("set_dependency_module_log rejects invalid module type.", not pigeon.set_dependency_module_log(1))
	test("set_dependency_module_log accepts logger module.", pigeon.set_dependency_module_log(logger_stub))
	test("set_dependency_module_log accepts nil (reset logger).", pigeon.set_dependency_module_log(nil))
	pigeon.toggle_logging(false)

	test("set_dependency_module_hashed is deprecated no-op, always returns true.", pigeon.set_dependency_module_hashed(hash))

	-- define_batch via separate API
	local batch_define_result = pigeon.define_batch({
		compat_new_letter = { id = "compat_new_letter", data = {value = "string"} }
	})
	test("define_batch can define new messages.", batch_define_result.compat_new_letter == true)

	-- set_dependency_module_log API
	test("set_dependency_module_log rejects invalid module type.", not pigeon.set_dependency_module_log(1))
	test("set_dependency_module_log accepts logger instance directly.", pigeon.set_dependency_module_log(logger_stub))
	test("set_dependency_module_log accepts logger instance with custom tag.", pigeon.set_dependency_module_log(logger_stub, "custom_tag"))
	test("set_dependency_module_log accepts nil (resets to print logger).", pigeon.set_dependency_module_log(nil))
	pigeon.toggle_logging(false)

	-- send_to direct API (not through post alias)
	test("send_to sends to valid url string.", pigeon.send_to(".", "post_alias_test"))
	test("send_to rejects invalid url type.", not pigeon.send_to(1, "test"))

	-- pigeon.new() convenience instance
	local new_calls = {}
	local new_handler = pigeon.new({
		[hash("new_test_a")] = function(message, sender)
			new_calls[#new_calls + 1] = "a"
		end,
		[hash("new_test_b")] = function(message, sender)
			new_calls[#new_calls + 1] = "b"
		end
	})
	test("new() returns handler with on_message and final.", new_handler and type(new_handler.on_message) == "function" and type(new_handler.final) == "function")
	test("new() auto-subscribes so send succeeds for message a.", pigeon.send("new_test_a"))
	test("new() auto-subscribes so send succeeds for message b.", pigeon.send("new_test_b"))
	new_handler:on_message(hash("new_test_a"), {}, msg.url())
	new_handler:on_message(hash("new_test_b"), {}, msg.url())
	test("new() on_message dispatches to correct handlers.", #new_calls == 2 and new_calls[1] == "a" and new_calls[2] == "b")
	new_handler:on_message(hash("unknown_new_msg"), {}, msg.url())
	test("new() on_message ignores unknown messages.", #new_calls == 2)
	new_handler:final()
	test("new() final unsubscribes handler.", not pigeon.send("new_test_a"))

	local new_tagged = pigeon.new({
		[hash("new_tagged_msg")] = function() end
	}, "custom_tag")
	test("new() accepts optional tag parameter.", new_tagged and new_tagged.tag == "custom_tag")
	new_tagged:final()

	print("Pigeon tests end   -------- [ PASSED: "..passed.." FAILED: "..failed.." ]\n")

	pigeon.toggle_logging(true)
end

return M
