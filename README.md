# Pigeon

Pigeon is a library to easily and safely manage posting messages in Defold.
* Ensures safe interface by allowing to easily check sent message correctness.
* Simplifies sending data to all listening subscribers.
* Allows to set up hooks that are triggered instantly when a message is send.

![Pigeon logo](assets/pigeon_hero.png)

Based partially on "Dispatcher" by Critique Gaming:
["https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua"](https://github.com/critique-gaming/crit/blob/main/crit/dispatcher.lua)

Uses "Defold Hashed" for pre-hashing by Sergey Lerg:
["https://github.com/Lerg/defold-hashed"](https://github.com/Lerg/defold-hashed)

Can utilise "Log" for logging and saving logs by Brian "Subsoap" Kramer:
["https://github.com/subsoap/log"](https://github.com/subsoap/log)

Current version: 1.0

Current Defold API: 1.4.5

By Pawel Jarosz, 2023

License: MIT


## Installation

In order to use Pigeon in your Defold game add it to your [game.project](defold://open?path=/game.project) as a [Defold library dependency](https://defold.com/manuals/libraries/). Don't forget to fetch the libraries.

Once added, you must require the main Lua module in scripts via

```
local pigeon = require("pigeon.pigeon")
```

## Defold Example

Check out main/example.script

## API

### define(message_id, message_def)
Define a new message with an optional specified data definition as a table containing keys as possible keys
and values for those keys as possible type of data
**PARAMETER:**	`message_id`		[string]	- message_id string or hash (it is ensured to be pre-hashed anyway)
* **PARAMETER:**	`[message_def]`     [table]		- optional message definition
* **RETURNS:**      `result`			[boolean]	- true if message was defined succesfully, false otherwise.
```
	pigeon.define("test_message", { test_value = "string" })
```

### subscribe(messages, hook, url)
Subscribe to given message_id(s) and eventually add an optional hook on message sent.
* **PARAMETER:**	`messages`	[table]		- table containing message_id(s) that caller will be subscribed to.
* **PARAMETER:**	`[hook]`	[function]	- optional hook function to be called, when sending defined message(s).
* **PARAMETER:**	`[url]`		[url]		- optional url, to which, the messages are subscribed (default is caller script).
* **RETURNS:**      `id`		[number]	- id of the subscriber, or false if subsciption failed.
```
	pigeon.subscribe("test_message", function() print("My hook!") end, msg.url())
```

### unsubscribe(id)
Unsubscribe the given subscription.
* **PARAMETER:**	`id`		[number]	- id of the subscriber to unsubscribe
* **RETURNS:**	    `result`	[boolean]	- true if unsubscribed succesfully, false otherwise.
```
	pigeon.unsubscribe(1)
```

### unsubscribe_all()
Unsubscribe all saved subscriptions.
* **RETURNS:**	    `result`	[boolean]	- true if unsubscribed succesfully, false otherwise.
```
	pigeon.unsubscribe_all()
```

### send(message_id, message)
Send a message with an optional data to all subscribers.
If the message has a hook attached, it will be called immediately.
* **PARAMETER:**	`message_id`	[string]	- message_id string or hash
* **PARAMETER:**	`[message]`	    [table]		- optional message definition
* **RETURNS:**	    `result`		[boolean]	- true if message was sent succesfully, false otherwise.
```
	pigeon.send("test_message", { test_value = "test_string" })
```

### send_to(url, message_id, message)
Send a message with an optional data to specified url.
This is a direct replacement for Defold built-in msg.post function.
* **PARAMETER:**	`url`			[url]		- target's url
* **PARAMETER:**	`message_id`	[userdata]	- message_id string or hash
* **PARAMETER:**	`[message]` 	[table]		- optional message definition
* **RETURNS:**	    `result`		[boolean]	- true if message was sent succesfully, false otherwise.
```
	pigeon.send_to(msg.url(), "test_message", { test_value = "test_string" })
```

### toggle_logging(enable)
Enable or disable logging functionality.
It only switches between default logging (printing to console) and not logging.
If you want to use dependency logging, you need to set dependency again after enabling logging.
Note! The correctness of arguments is not checked! Use responsibly!
* **PARAMETER:**	`enable`		[boolean]	- set logging enabled (true) or disabled (false)
```
	pigeon.toggle_logging(false)
```

### set_dependency_module_log(module, tag)
Replace internal printing with logging from Log module.
It is suited for Log API, so if you want to provide your own module, follow the API,
or modify internal Pigeon calls for logging accordingly.
Note! The correctness of arguments is not checked! Use responsibly!
* **PARAMETER:**	`module`		[table]	- Lua module being replacement for logging
* **PARAMETER:**	`tag`			[string]	- change default tag ("pigeon") to your own
```
    local log = require "log.log"
	pigeon.set_dependency_module_log(log)
```

## Tests

To check if Pigeon is working properly you can run a set of unit and functional tests from the test module:

```
local pigeon_test = require "pigeon.pigeon_test"
pigeon_test.run()
```

Happy Defolding!

---