# Pigeon

Pigeon is a Defold messaging helper focused on easier and safer runtime communication:

* Easy publish-subscribe messaging system.
* Send to all listening subscribers at once.
* Safe interface (optional runtime data validation).
* Built-in Defold message schemas (aka letters).
* Hook callbacks executed synchronously when a message is sent (with optional context).
* Public API annotations are visible in Defold Editor (hover docs and function signatures).

![Pigeon logo](assets/pigeon_hero.png)

Newest Pigeon version is 1.5, verified with Defold 1.12.4.

By Paweł Jarosz, 2023-2026

License: MIT

## Installation

In order to use Pigeon in your Defold game add it to your [game.project](defold://open?path=/game.project) as a [Defold library dependency](https://defold.com/manuals/libraries/). Don't forget to fetch the libraries.

Newest version link:

```lua
https://github.com/paweljarosz/pigeon/archive/refs/tags/v1.5.zip
```

Once added, you must require the main Lua module in scripts via:

```lua
local pigeon = require("pigeon.pigeon")
```

## Quick API Reference

Pigeon checks messages just before sending them, if there is a definition of a desired message. Those definitions / message schemas are called "Letters". You can add letters at runtime using dedicated functions or access the internal table of messages too. Then, pigeon sends the message to all active subscribers (or you can send to a specific one using a URL).

Define a message - with optional data definition:

```lua
pigeon.define("my_message", { my_value = "string" } )
pigeon.define("my_message", { my_value = "string|number|nil", my_other_value = "number|nil" } )
```

Define multiple messages at once:

```lua
pigeon.define_batch( {
    msg_a = { id = "msg_a", data = { value = "string" } },
    msg_b = { id = "msg_b", data = { value = "number" } }
} )
```

Subscribe to message(s) - with an optional hook, url and/or context:

```lua
local id = pigeon.subscribe("my_message")
local id = pigeon.subscribe("my_message", function() print("Hook!") end, msg.url(), self)
```

Dynamically add or remove messages from an existing subscription:

```lua
pigeon.extend_subscription(id, "another_message")
pigeon.reduce_subscription(id, "another_message")
```

Send message - with optional data to all subscribers:

```lua
pigeon.send("my_message")
pigeon.send("my_message", { my_value = "my_string" } )
```

Send message directly to url (equivalent to msg.post):

```lua
pigeon.send_to(msg.url(), "my_message", { test_value = "test_string" } )
```

Unsubscribe:

```lua
pigeon.unsubscribe(id)
pigeon.unsubscribe_all()
```

Create a convenience handler instance:

```lua
self.handler = pigeon.new( {
    [hash("my_message")] = function(message, sender, handler)
        print("Received:", message)
    end
} )
-- in on_message:  self.handler:on_message(message_id, message, sender)
-- in final:       self.handler:final()
```

Access defined message schemas (letters):

```lua
local def = pigeon.letters[hash("set_parent")]
```

Toggle or replace logging:

```lua
pigeon.toggle_logging(false)
pigeon.set_dependency_module_log(my_logger_module, "my_tag")
```

Use with logging modules:

```lua
-- With Log
local subsoap_log = require "log.log"
pigeon.set_dependency_module_log(subsoap_log)

-- With Defold-Log
local insality_log = require "log.log"
pigeon.set_dependency_module_log(insality_log.get_logger("pigeon"))

-- With Squid
local squid = require "squid.squid"
pigeon.set_dependency_module_log(squid)
```

## API

Sign <strong>"?"</strong> after a name of a parameter means it's optional:

---

### Pigeon.define(message_id, message_def?)

Define a single message schema for runtime validation. Built-in Defold/system message ids (e.g. `load`, `enable`) are always protected from redefinition.

| | name | type | description |
|-|-|-|-|
|param| `message_id` | `string\|userdata` | Defold message id as string or hash. |
|param| `message_def?` | `table\|nil` | Optional message definition table (supports multi-type like `"string\|number\|nil"`). |
|return| | `boolean` | `true` if defined successfully, `false` otherwise. |

Example:

```lua
pigeon.define("test_message", { test_value = "string|number|nil" } )
pigeon.define("load", { menu = "string" } ) -- always false (protected built-in)
```

---

### Pigeon.define_batch(letters_table, is_overwriting?)

Define multiple message schemas at once from a table of letter definitions. Built-in Defold/system message ids are always protected from redefinition.

| | name | type | description |
|-|-|-|-|
|param| `letters_table` | `table` | Table of letter definitions in shape `{ key = { id = ..., data = ... } }`. |
|param| `is_overwriting?` | `boolean\|nil` | If `true`, allows overwriting existing user-defined definitions. |
|return| | `table<string, boolean>` | Per-key result map. |

Example:

```lua
pigeon.define_batch( {
    msg_a = { id = "msg_a", data = { value = "string" } },
    msg_b = { id = "msg_b", data = { value = "number" } }
} )

-- With overwrite
pigeon.define_batch( {
    msg_a = { id = "msg_a", data = { value = "number" } }
}, true)
```

---

### Pigeon.subscribe(messages, hook?, url?, context?, is_optimizing?)

Subscribe to one or more message ids.

| | name | type | description |
|-|-|-|-|
|param| `messages` | `table\|string\|userdata` | Message id or list of message ids. |
|param| `hook?` | `function\|nil` | Optional callback invoked **synchronously** during `pigeon.send()`, **before** `msg.post` delivers the message to regular subscribers. Called as `hook(message_id, message, context)`. Hook subscribers are stored separately - they do not receive `msg.post` deliveries, only the immediate callback. |
|param| `url?` | `userdata\|string\|nil` | Optional Defold URL of the subscriber that will receive `msg.post` deliveries. If omitted, defaults to `msg.url()` (the caller's own URL). Only relevant for regular (non-hook) subscriptions. When a `hook` is provided, `url` is stored but `msg.post` is not called for that subscriber. |
|param| `context?` | `table\|nil` | Optional context table passed as the third argument to the `hook` callback. **The context belongs to the subscriber**. It is the data provided at subscribe-time, not by the sender. This allows the subscriber to pass instance-specific data (e.g. `self`) that the hook can safely access when triggered by any sender. Ignored if no `hook` is provided. |
|param| `is_optimizing?` | `boolean\|nil` | If `true`, filters out messages that are already subscribed for the same `url` (without a hook). Prevents duplicate subscriptions. Useful when calling `subscribe` multiple times for the same target (e.g. during re-initialization). If all requested messages are already covered, returns `false` and no new subscription is created. |
|return| | `number\|boolean` | Unique subscriber id on success, `false` otherwise. |

Example:

```lua
-- Basic subscription (no hook, receives msg.post in on_message)
pigeon.subscribe("test_message")

-- With hook (called immediately during pigeon.send, before msg.post)
pigeon.subscribe("test_message", my_hook, msg.url())

-- With hook and subscriber's context (e.g. self)
-- When any script calls pigeon.send("move", { new_pos = ... } ),
-- the hook fires immediately with this subscriber's self as context:
local function on_move_hook(message_id, message, ctx)
    go.set_position(ctx.my_game_object_id, message.new_pos)
end
pigeon.subscribe("move", on_move_hook, nil, self)
```

**Important:** The `context` is provided by the subscriber at subscribe-time and stored with the subscription. When `pigeon.send()` triggers the hook, the context passed to the hook is always the subscriber's — regardless of which script called `pigeon.send()`. Defold APIs that take an explicit target id (e.g. `go.set_position(id, pos)`) can work correctly inside hooks.

---

### Pigeon.extend_subscription(id, messages)

Add message ids to existing subscriber id.

| | name | type | description |
|-|-|-|-|
|param| `id` | `number` | Existing subscriber id returned by `pigeon.subscribe(...)`. |
|param| `messages` | `table\|string\|userdata` | One message id or a list of message ids to add. |
|return| | `boolean` | `true` if updated successfully, `false` otherwise. |

Example:

```lua
local id = pigeon.subscribe("menu_open")
pigeon.extend_subscription(id, { "menu_close", "menu_toggle" } )
```

---

### Pigeon.reduce_subscription(id, messages)

Remove message ids from existing subscriber id.

| | name | type | description |
|-|-|-|-|
|param| `id` | `number` | Existing subscriber id returned by `pigeon.subscribe(...)`. |
|param| `messages` | `table\|string\|userdata` | One message id or a list of message ids to remove. |
|return| | `boolean` | `true` if updated successfully, `false` otherwise. |

If all message ids are removed, the subscriber is automatically unsubscribed.

Example:

```lua
local id = pigeon.subscribe( { "menu_open", "menu_close", "menu_toggle" } )
pigeon.reduce_subscription(id, "menu_toggle")
```

---

### Pigeon.unsubscribe(id)

Unsubscribe one or more subscribers by id.

| | name | type | description |
|-|-|-|-|
|param| `id` | `number\|number[]\|boolean\|nil` | Single subscriber id, or a table of subscriber ids to unsubscribe. If any id was `false`/`nil`, it does nothing for it. |
|return| | `boolean` | `true` if all unsubscribed successfully, `false` otherwise. |

Example:

```lua
-- Single
pigeon.unsubscribe(sub_id)

-- Multiple at once
pigeon.unsubscribe( { sub_id_a, sub_id_b, sub_id_c } )
```

---

### Pigeon.unsubscribe_all()

Unsubscribe all subscribers.

| | name | type | description |
|-|-|-|-|
|return| | `boolean` | `true` if all were unsubscribed, `false` otherwise. |

Example:

```lua
pigeon.unsubscribe_all()
```

---

### Pigeon.send(message_id, message?)

Send to all subscribers of `message_id` with runtime schema validation.

| | name | type | description |
|-|-|-|-|
|param| `message_id` | `string\|userdata` | Message id to dispatch. |
|param| `message?` | `table\|nil` | Optional message payload. |
|return| | `boolean` | `true` if sent, `false` if data is invalid or there are no subscribers for that message id. |

If a message id was removed via `reduce_subscription()` and no other subscribers remain, `pigeon.send(message_id)` returns `false`.

Example:

```lua
pigeon.send("enemy_spawned", { position = vmath.vector3(10, 20, 0) } )
pigeon.send("game_over")
```

---

### Pigeon.send_to(url, message_id, message?)

Equivalent to `msg.post(url, message_id, message)` with optional schema validation.
Accepts the same target forms as `msg.post`: a `url` userdata, a url-like
`string` (e.g. `"/gui#hud"` or `"#fragment"`), or a `hash` game object id
(e.g. the id returned by `factory.create` or `go.get_id`).

| | name | type | description |
|-|-|-|-|
|param| `url` | `url\|string\|hash` | Target URL, url-like string, or game object hash id. |
|param| `message_id` | `string\|userdata` | Message id to send. |
|param| `message?` | `table\|nil` | Optional message payload. |
|return| | `boolean` | `true` if sent, `false` on invalid url or data. |

**Note:** It is recommended to switch all `pigeon.send_to` calls to `msg.post` in the codebase for the production version where you are sure, pigeon helped you secure interfaces with proper types in every case.

Example:

```lua
pigeon.send_to(msg.url(), "set_parent", { parent_id = go.get_id("/parent"), keep_world_transform = 1 } )
pigeon.send_to("/gui#hud", "update_score", { score = 100 } )

-- Passing a game object id (hash) returned by factory.create, just like msg.post does:
local instance_id = factory.create("#cell_factory")
pigeon.send_to(instance_id, "cell_was_created", { position_in_tiles = position_in_tiles })
```

---

### Pigeon.toggle_logging(enable)

Enable/disable internal logging (`print` vs silent logger).

| | name | type | description |
|-|-|-|-|
|param| `enable` | `boolean` | `true` enables default print logger, `false` disables all logging. |
|return| | `boolean` | Always `true`. |

Example:

```lua
pigeon.toggle_logging(false) -- silence all pigeon logs
pigeon.send("quiet_message")
pigeon.toggle_logging(true)  -- re-enable logging
```

---

### Pigeon.set_dependency_module_log(module, tag?)

Set or reset the logging backend. Accepts a logger instance (with `trace`/`debug`/`info`/`warn`/`error` methods), a factory module with `.new(tag)`, or `nil` to reset to default `print` logger.

| | name | type | description |
|-|-|-|-|
|param| `module` | `table\|nil` | Logger object/module. `nil` resets to default print logger. |
|param| `tag?` | `string\|nil` | Optional tag. |
|return| | `boolean` | `true` on success, `false` on invalid module. |

Example:

```lua
local my_logger = require "utils.my_logger"
pigeon.set_dependency_module_log(my_logger, "pigeon")

-- Reset to default print logger
pigeon.set_dependency_module_log(nil)
```

---

### ~~Pigeon.set_dependency_module_hashed(module)~~ — DEPRECATED

No-op. Pigeon always uses its internal `hashed` module. Kept for backward compatibility — always returns `true`.

---

### Pigeon.new(handlers, tag?)

Create a convenience handler instance that auto-subscribes to all message ids from `handlers` and dispatches them via `on_message`.

| | name | type | description |
|-|-|-|-|
|param| `handlers` | `table<hash, function>` | Table of message handlers where key is hashed message id and value is handler function `function(message, sender, handler_instance)`. |
|param| `tag?` | `string\|nil` | Optional logging tag. |
|return| | `table` | Handler instance with `on_message`, `final`, `subscription` and `tag` fields. |

Returned instance fields:

* `on_message(self, message_id, message, sender)` — dispatch incoming messages to handlers.
* `final(self)` — unsubscribe and clean up.
* `subscription` — subscriber id.
* `tag` — logging tag.

Example:

```lua
local pigeon = require "pigeon.pigeon"

function init(self)
    self.handler = pigeon.new( {
        [hash("enemy_spawned")] = function(message, sender, handler)
            print("Enemy spawned at:", message.position)
        end,
        [hash("enemy_defeated")] = function(message, sender, handler)
            print("Score:", message.score)
        end
    } )
end

function on_message(self, message_id, message, sender)
    self.handler:on_message(message_id, message, sender)
end

function final(self)
    self.handler:final()
end
```

---

### Pigeon.letters

Table containing all defined message schemas (built-in Defold messages and user-defined ones). Indexed by hashed message id.

```lua
local def = pigeon.letters[hash("set_parent")]
print(def.id)   -- hash of "set_parent"
print(def.data)  -- { parent_id = "hash", keep_world_transform = "number" }
```

**Note:** You have full runtime access to this table and can read, modify, or remove entries directly. However, take a particular caution when doing so, because incorrect modifications can break runtime validation or affect other systems relying on these definitions. Prefer using `pigeon.define()` for safe modifications.

---

## FAQ

*Problem*: My game objects are initialized at the same time, I want to send messages from the `init()` of one of them. Pigeon logs this warning:

```
WARN: Not sending. 'message_id' is not subscribed: [hash: ...]
```

but the other Game Object is subscribing from its `init()` to this `message_id`.

*Solution*:

The Defold manual states that the [order of game object initialization cannot be controlled](https://defold.com/manuals/application-lifecycle/#collection-init). One way to solve this issue is by delaying the call to `pigeon.send()` so the other game objects have time to initialize. 
See this [forum thread](https://forum.defold.com/t/pigeon-easy-and-safe-messaging-library-for-defold/73187/10)  for details.

```lua
local pigeon = require "pigeon.pigeon"
local H = require "pigeon.hashed"

function init(self)
    msg.post("#", H.late_init)
end

function on_message(self, message_id, message)
    if message_id == H.late_init then
        -- do late-initialization here
        pigeon.send("to_other_subscriber")
    end
end
```

---

*Problem*: Pigeon logs this warning and the message is not sent:

```
WARN: Not sending. Data is incorect for: [hash: ...]
```

*Explanation*:

This means the data table you passed to `pigeon.send()` or `pigeon.send_to()` does not match the schema defined via `pigeon.define()`. For example, if you defined:

```lua
pigeon.define("my_message", { value = "string" })
```

and then tried to send:

```lua
pigeon.send("my_message", { value = 123 })  -- number instead of string
```

Pigeon rejects the message because `123` is a `number`, not a `string`. Check the field types in your `pigeon.define()` call and make sure the data you send matches. You can use multi-type definitions (e.g. `"string|number|nil"`) if a field should accept more than one type.

---

## Tests

To check if Pigeon is working properly you can run a set of unit and functional tests from the test module:

```lua
local pigeon_test = require "pigeon.test"
pigeon_test.run()
```


## Changelog

### 1.5 - Apr 2026

* UPDATE: `pigeon.send_to()` now accepts the same target forms as Defold's built-in `msg.post()`. In addition to a `url` userdata and a url-like `string`, you can now pass a `hash` game object id directly — for example the id returned by `factory.create` or `go.get_id`.

```lua
-- All of these now work with pigeon.send_to, exactly like msg.post:
local instance_id = factory.create("#cell_factory")
pigeon.send_to(instance_id, "cell_was_created", { position_in_tiles = position_in_tiles })
pigeon.send_to(msg.url(instance_id), "cell_was_created", { position_in_tiles = position_in_tiles })
pigeon.send_to("/gui#hud", "update_score", { score = 100 })
pigeon.send_to(msg.url(), "set_parent", { parent_id = go.get_id("/parent") })
```

* FIX: `pigeon.send_to()` no longer crashes when called with an invalid target (e.g. `nil`, `boolean`, `table`). Previously the internal error log attempted to concatenate the target value with a string, which raised an error for userdata/non-string values. Invalid targets are now safely rejected with `false` and a proper error message.

* UPDATE: Added tests covering the new target forms (`url`, `string`, `hash`) and safe rejection of invalid types in `pigeon.send_to()`.

* Version 1.5 is fully backward compatible with 1.4 — only accepted target types are widened; all existing calls keep working unchanged.

### 1.4 - Feb 2026

* NEW: Added optional context support for hooks in `pigeon.subscribe()`.
The context is the **subscriber's data** (e.g. `self`) passed at subscribe-time and stored with the subscription. When any script calls `pigeon.send()`, the hook fires immediately with the subscriber's context — not the sender's. This allows safe access to instance-specific data inside hooks.

```lua
-- Script B subscribes with its own self as context:
local function my_hook(message_id, message, ctx)
    go.set_position(ctx.my_id, message.new_pos)
end
pigeon.subscribe("move", my_hook, nil, self)

-- Script A sends — B's hook fires immediately with B's self as ctx:
pigeon.send("move", { new_pos = vmath.vector3(100, 200, 0) } )
```

* NEW: Added `pigeon.extend_subscription(id, messages)` — add new message ids to an existing subscription without creating a new one.

* NEW: Added `pigeon.reduce_subscription(id, messages)` — remove specific message ids from an existing subscription. If all messages are removed, the subscription is automatically unsubscribed.

* NEW: Added `pigeon.new(handlers, tag?)` — create a convenience handler instance that auto-subscribes to all message ids from the handlers table and dispatches them via `on_message`. Call `handler:final()` to clean up.

* NEW: Added `pigeon.define_batch(letters_table, is_overwriting?)` — define multiple message schemas at once from a table of letter definitions.

* NEW: `pigeon.unsubscribe()` now accepts a table of subscriber ids to unsubscribe multiple subscriptions at once.

* FIX: Built-in Defold message ids (for example `load`, `unload`, `enable`) are protected from accidental redefinition (always blocked). This fixes issues, when users could accidentally overwrite internally used message_ids.

* DEPRECATED: `pigeon.set_dependency_module_hashed()` is now a deprecated and if you call it it's no-op. Pigeon always uses the internal `hashed` module.

* UPDATE: Refactored internals (separate implementation `pigeon_impl.lua`, new separate module for checking types:  `pigeon.typer`).

* UPDATE: Added or expanded Lua annotations directly in `pigeon/pigeon.lua` and added `pigeon/typer.lua` as a dedicated runtime type checking module.

* UPDATE: Added tests to cover new functionalities.

* Version 1.4 should be backward compatible with 1.3, as all API functions remained unchanged, only new, safer behaviour is added via using trailing optional parameters in calls, while keeping default as in the previou version. Deprecated function (`set_dependency_module_hashed`) is still kept for backward compatibility.

### 1.3 - Nov 2024

* Added possibility to define multiple types in message definition using `|` as separator. Example script extended with this usage. Quick Reference:

```lua
pigeon.define("test_message", { test_value = "string|number|nil" } ) -- define message with one test_value being string, number or nil
pigeon.send("test_message", {test_value = 1 } ) -- we can then send a message with number
pigeon.send("test_message", {test_value = "test" } ) -- or string
pigeon.send("test_message", {test_value = nil } ) -- or nil
pigeon.send("test_message", {} ) -- and because the only defined key here can be nil, so we as well can pass empty table
pigeon.send("test_message") -- or nothing at all
```

* Added Lua annotations to all functions in Pigeon.
* Improved documentation.

### 1.2 - Oct 2024

* Added possibility to use another logger - [Defold-Log by Insality](https://github.com/Insality/defold-log). Quick Reference:

```lua
local insality_log = require "log.log"
pigeon.set_dependency_module_log(insality_log.get_logger("pigeon"))
```

* Replaced deprecated system font with always on top font.

#### 1.1 - Jan 2024

* bugfix: `pigeon.send()` now correctly returns `false`, when no subscribers are subscribed to the given message and message is therfore not sent. Thanks to [LaksVister](https://github.com/LaksVister) for finding it out!

#### 1.0 - May 2023

* First release version

## License

MIT. See [LICENSE.md](LICENSE.md).

## Thanks

Based initially on "Dispatcher" by Critique Gaming:
["https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua"](https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua)

Uses "Defold Hashed" for pre-hashing by Sergey Lerg:
["https://github.com/Lerg/defold-hashed"](https://github.com/Lerg/defold-hashed)

Can utilise "Log" for logging and saving logs by Brian "Subsoap" Kramer:
["https://github.com/subsoap/log"](https://github.com/subsoap/log)

or "Defold-Log" by Maksim "Insality" Tuprikov:
["https://github.com/Insality/defold-log"](https://github.com/Insality/defold-log)

or "Squid" by me:
["https://github.com/paweljarosz/squid"](https://github.com/paweljarosz/squid)

## Support

If you like this module, you can show your appreciation by supporting me via [Github Sponsors](https://github.com/sponsors/paweljarosz), [Ko-Fi](https://ko-fi.com/witchcrafter) or [Patreon](https://www.patreon.com/witchcrafter_rpg), and wishlisting my Dream Game: [Witchcrafter: Empire Legends](https://store.steampowered.com/app/1374370/Witchcrafter_Empire_Legends/)

Happy Defolding!
