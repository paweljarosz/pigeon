# Pigeon

Pigeon is a library to easily and safely manage posting messages in Defold.
* Ensures safe interface by allowing to easily check sent message correctness.
* Simplifies sending data to all listening subscribers.
* Allows to set up hooks that are triggered instantly when a message is sent.

![Pigeon logo](assets/pigeon_hero.png)

Based partially on "Dispatcher" by Critique Gaming:
["https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua"](https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua)

Uses "Defold Hashed" for pre-hashing by Sergey Lerg:
["https://github.com/Lerg/defold-hashed"](https://github.com/Lerg/defold-hashed)

Can utilise "Log" for logging and saving logs by Brian "Subsoap" Kramer:
["https://github.com/subsoap/log"](https://github.com/subsoap/log)

or "Defold-Log" by Maksim "Insality" Tuprikov:
["https://github.com/Insality/defold-log"](https://github.com/Insality/defold-log)

Current Pigeon version: 1.3

Checked with Defold API version: 1.9.4

By Paweł Jarosz, 2023-2024

License: MIT

## Revisions

#### 1.3 - Nov 2024
* Added possibility to define multiple types in message definition using `|` as separator. Example script extended with this usage. Quick Reference:
    ```lua
	    pigeon.define("test_message", { test_value = "string|number|nil" }) -- define message with one test_value being string, number or nil
		pigeon.send("test_message", {test_value = 1 }) -- we can then send a message with number
		pigeon.send("test_message", {test_value = "test" }) -- or string
		pigeon.send("test_message", {test_value = nil }) -- or nil
		pigeon.send("test_message". {}) -- and because the only defined key here can be nil, so we as well can pass empty table
		pigeon.send("test_message") -- or nothing at all
	```
* Added Lua annotations to all functions in Pigeon.
* Improved documentation.


#### 1.2 - Oct 2024
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

## Installation

In order to use Pigeon in your Defold game add it to your [game.project](defold://open?path=/game.project) as a [Defold library dependency](https://defold.com/manuals/libraries/). Don't forget to fetch the libraries.

Once added, you must require the main Lua module in scripts via

```lua
local pigeon = require("pigeon.pigeon")
```

## Defold Example

Check out main/example.script

## API

---
### define(message_id, message_def)

Define a new message with an optional specified data definition as a table containing keys as possible keys and values for those keys as possible type of data to be checked in runtime by PIGEON. When data is sent using pigeon.send, it will be verified in run-time before sending.
| | name | type | description |
|-|-|-|-|
|param| `message_id` | `string\|userdata` | Defold message_id string or hashed (it is ensured to be pre-hashed anyway). |
|param| `message_def` | `table\|nil` | Optional message definition - a table containing required fields as keys with their types as values. Values can represent multiple types separated by `|`, e.g. "string|number|nil". |
|return| | `boolean` | True if defined succesfully, false otherwise. |

Example:
```
	pigeon.define("test_message", { test_value = "string" })
	pigeon.define("test_message", { test_value = "string|number|nil" })
```
---

### subscribe(messages, hook, url)
Subscribe to given message_id(s) and eventually add an optional hook on message sent.

| | name | type | description |
|-|-|-|-|
|param| `messages` | `table\|string\|userdata` | Table containing message_id(s) that caller will be subscribed to. Can be a single message as `string` or `hash` or a table containing messages as strings or hashes. |
|param| `hook` | `function\|nil` | Optional hook function to be called everytime, when sending defined message(s). |
|param| `url` | `userdata\|nil` | Optional URL of the subscriber, to which, the messages are subscribed. If not provided the caller's script url is used by default. |
|return| | `number\|boolean` | Unique id of the subscriber if subscribed succesfully, false otherwise. |

Example:
```
	pigeon.subscribe("test_message", function() print("My hook!") end, msg.url())
```
---

### unsubscribe(id)
Unsubscribe the given subscription.

| | name | type | description |
|-|-|-|-|
|param| `id` | `number\|\|nil` | Id of the subscriber to unsubscribe. If false or nil it will do nothing and will return false. |
|return| | `boolean` | True if unsubscribed succesfully, false otherwise. |

Example:
```
	pigeon.unsubscribe(1)
```
---

### unsubscribe_all()
Unsubscribe all saved subscriptions.

| | name | type | description |
|-|-|-|-|
|return| | `boolean` | True if unsubscribed succesfully all subscribers, false otherwise. |

Example:
```
	pigeon.unsubscribe_all()
```
---

### send(message_id, message)
Send a message with an optional data to all subscribers.
Additionally, Pigeon checks in runtime if message is correct if defined.
If the message has a hook attached, it will be called immediately.

| | name | type | description |
|-|-|-|-|
|param| `message_id` | `string\|userdata` | Defold message_id string or hashed. It will be prehashed anyway. |
|param| `message` | `table\|nil` | Optional message definition table to check before sending. |
|return| | `boolean` | True if data is correct and send succesfully, false otherwise. |

Example:
```
	pigeon.send("test_message", { test_value = "test_string" })
	-- you can check if message was sent:
	local is_message_sent = pigeon.send("test_message")
```
---

### send_to(url, message_id, message)
Equivalent to Defold built-in `msg.post`.
Send a message of given message_id with an optional data in message table to a specified url.
Additionally, Pigeon checks in runtime if message is correct if defined.

| | name | type | description |
|-|-|-|-|
|param| `url` | `userdata` | Target's url. |
|param| `message_id` | `string\|userdata` | Defold message_id string or hashed. It will be prehashed anyway. |
|param| `message` | `table\|nil` | Optional message definition table to check before sending. |
|return| | `boolean` | True if data is correct and send succesfully, false otherwise. |

Example:
```
	pigeon.send_to(msg.url(), "test_message", { test_value = "test_string" })
	-- is a direct equivalent to:
	-- msg.post(msg.url(), "test_message", { test_value = "test_string" })
```
---

### toggle_logging(enable)
Enable or disable logging functionality.
It only switches between default logging (printing to console) and not logging.
If you want to use dependency logging, you need to set dependency again after enabling logging.
Note! The correctness of arguments is not checked! Use responsibly!

| | name | type | description |
|-|-|-|-|
|param| `enable` | `boolean` | Flag to set logging enabled (true) or disabled (false). |

Example:
```
	pigeon.toggle_logging(false)
```
---

### set_dependency_module_log(module, tag)
Replace internal printing with logging from Log module.
It is suited for Log API, so if you want to provide your own module, follow the API,
or modify internal Pigeon calls for logging accordingly.
Note! The correctness of arguments is not checked! Use responsibly!

| | name | type | description |
|-|-|-|-|
|param| `module` | `table` | Lua module being replacement for logging. |
|param| `tag` | `string\|nil` | Optional own string tag to replace the default tag ("pign"). |

Example:
```
    local subsoap_log = require "log.log"
	pigeon.set_dependency_module_log(subsoap_log)
```
or:
```
	local insality_log = require "log.log"
	pigeon.set_dependency_module_log(insality_log.get_logger("pigeon"))
```
---

## FAQ

*Problem*: My game objects are initialized at the same time, I want to send messages from the `init()` of one of them. Pigeon complains that there's no subscriber, but the other Game Object is subscribing from its `init()`.

*Solution*: 

The Defold manual states that the [order of game object initialization cannot be controlled](https://defold.com/manuals/application-lifecycle/#:~:text=The%20order%20in%20which%20game%20object%20component%20init()%20functions%20are%20called%20is%20unspecified.%20You%20should%20not%20assume%20that%20the%20engine%20initializes%20objects%20belonging%20to%20the%20same%20collection%20in%20a%20certain%20order.). One way to solve this issue is by delaying the call to `pigeon.send()` so the other game objects have time to initialize. 
See this [Forum thread](https://forum.defold.com/t/pigeon-easy-and-safe-messaging-library-for-defold/73187/10)  for details.

```
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

## Tests

To check if Pigeon is working properly you can run a set of unit and functional tests from the test module:

```
local pigeon_test = require "pigeon.pigeon_test"
pigeon_test.run()
```

Happy Defolding!

---
