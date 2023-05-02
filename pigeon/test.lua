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

	local test_subscription = pigeon.subscribe({"test"})
	test("Correctly subscribed, message is a table.", pigeon.subscribe({"test"}))
	test("Correctly subscribed, again.", pigeon.subscribe({"test"}))
	test("Correctly subscribed, even not defined messages.", pigeon.subscribe({"test", "test2"}))
	test("Correctly subscribed, message is a single string.", pigeon.subscribe("test"))
	test("Correctly subscribed, message is a single hash.", pigeon.subscribe(hash("test")))
	test("Subscription failed, message is not a table, string or hash.", not pigeon.subscribe(1))

	test("Correctly subscribed with hook given.", pigeon.subscribe("test", function() end))
	test("Subscription failed, hook is not a function.", not pigeon.subscribe("test", 1))
	test("Correctly subscribed with url.", pigeon.subscribe({"test"}, _, "#" ))

	test("Correctly send defined message.", pigeon.send("test", {test_data = "testing"}))
	test("Don't allow to send message that is not subscribed.", not pigeon.send("test3"))

	test("Correctly unsubscribed.", pigeon.unsubscribe(test_subscription))
	test("Unsubscription failed, id is not given.", not pigeon.unsubscribe())
	test("Unsubscription failed, id is not number.", not pigeon.unsubscribe("test"))
	test("Correctly unsubscribed all subscribers.", pigeon.unsubscribe_all())

	print("Pigeon tests end   -------- [ PASSED: "..passed.." FAILED: "..failed.." ]\n")

	pigeon.toggle_logging(true)
end

return M