--
-- LETTERS
--
-- Letters for Pigeon are special messages with message_id and message data defined (or not).
-- Message_ids are pre-hashed utilising Defold Hashed by Sergey Lerg:
-- https://github.com/Lerg/defold-hashed
--
-- By Pawel Jarosz, 2023-2026
-- License: MIT

local hashed = require "pigeon.hashed"

---@alias HashedMessageId	hash|userdata
---@alias MessageId			string|hash|userdata|HashedMessageId
---@alias MessagesGroup		MessageId|MessageId[]|table<number|string, MessageId>
---@alias MessageDefinition	table<string, string>|table|nil

---@class BaseLetterDefinition
---@field id	HashedMessageId		@Hashed message id
---@field data	MessageDefinition	@Optional message data definition table

---@alias Letters table<string, MessageDefinition|nil>

---@type Letters
local Letters = {}

--
-- DEFOLD SYSTEM MESSAGES - received from or to post to certain components. Based on Defold API 1.12.2.
--

--
-- CAMERA
--

---@class CameraMessageDefinition
---@field aspect_ratio	string @[number] The aspect ratio of the camera (width/height)
---@field fov			string @[number] Field of view (in radians)
---@field near_z		string @[number] Near Z plane distance
---@field far_z			string @[number] Far Z plane distance
---@field orthographic_projection	string @[boolean] Whether to use orthographic projection
---@field orthographic_zoom			string @[number] Zoom level for orthographic projection
---@field orthographic_mode			string @[number] Orthographic zoom behavior when orthographic_projection is enabled

---Post this message to a camera-component to set its properties at run-time.
---@class LetterSetCamera : BaseLetterDefinition
---@field data CameraMessageDefinition Camera properties to set
Letters.set_camera = {
	id = hashed.set_camera,
	data = {
		aspect_ratio = "number",
		fov = "number",
		near_z = "number",
		far_z = "number",
		orthographic_projection = "boolean",
		orthographic_zoom = "number",
		orthographic_mode = "number"
	}
}

---Legacy compatibility message kept for older projects.
---Not part of current Defold stable camera message docs (prefer camera.acquire_focus()).
---@class LetterAcquireCameraFocus : BaseLetterDefinition
Letters.acquire_camera_focus = { id = hashed.acquire_camera_focus }

---Legacy compatibility message kept for older projects.
---Not part of current Defold stable camera message docs (prefer camera.release_focus()).
---@class LetterReleaseCameraFocus : BaseLetterDefinition
Letters.release_camera_focus = { id = hashed.release_camera_focus }

--
-- COLLECTION PROXY
--

---@class TimeStepMessageDefinition
---@field factor	string @[number] Time-step scaling factor
---@field mode		string @[number] Time-step mode (0=continuous, 1=discrete)

---Post this message to a collection-proxy-component to modify the time-step.
---@class LetterSetTimeStep : BaseLetterDefinition
---@field data TimeStepMessageDefinition Time step configuration
Letters.set_time_step = {
	id = hashed.set_time_step,
	data = {
		factor = "number",
		mode = "number"
	}
}

---Post this message to start loading the referenced collection. When loading completes, proxy_loaded will be sent back.
---@class LetterLoad : BaseLetterDefinition
Letters.load = { id = hashed.load }

---Post this message to start unloading the referenced collection. When unloading completes, proxy_unloaded will be sent back.
---@class LetterUnload : BaseLetterDefinition
Letters.unload = { id = hashed.unload }

---Post this message to start background loading of the referenced collection. When loading completes, proxy_loaded will be sent back.
---@class LetterAsyncLoad : BaseLetterDefinition
Letters.async_load = { id = hashed.async_load }

---Message sent back when collection loading is complete (from load or async_load).
---@class LetterProxyLoaded : BaseLetterDefinition
Letters.proxy_loaded = { id = hashed.proxy_loaded }

---Message sent back when collection unloading is complete.
---@class LetterProxyUnloaded : BaseLetterDefinition
Letters.proxy_unloaded = { id = hashed.proxy_unloaded }

---Post this message to initialize game objects and components in the referenced collection.
---@class LetterInit : BaseLetterDefinition
Letters.init = { id = hashed.init }

---Post this message to finalize game objects and components in the referenced collection.
---@class LetterFinal : BaseLetterDefinition
Letters.final = { id = hashed.final }

--
-- COLLECTION PROXY, GAME OBJECT
--

---Post this message to enable a component. Supported by: Camera, Collection Proxy, Collision Object,
---Gui, Label, Spine Model, Sprite, Tile Grid, Model, Mesh
---@class LetterEnable : BaseLetterDefinition
Letters.enable = { id = hashed.enable }

---Post this message to disable a component. Supported by: Camera, Collection Proxy, Collision Object,
---Gui, Label, Spine Model, Sprite, Tile Grid, Model, Mesh
---@class LetterDisable : BaseLetterDefinition
Letters.disable = { id = hashed.disable }

--
-- GAME OBJECT
--

---Post this message to a game object instance to make that instance acquire user input focus.
---The last instance to request focus will receive it first and can consume input events.
---Scripts in the instance will receive input actions in their on_input callback function.
---@class LetterAcquireInputFocus : BaseLetterDefinition
Letters.acquire_input_focus = { id = hashed.acquire_input_focus }

---Post this message to an instance to make that instance release the user input focus.
---The instance will stop receiving input events.
---@class LetterReleaseInputFocus : BaseLetterDefinition
Letters.release_input_focus = { id = hashed.release_input_focus }

---@class SetParentMessageDefinition
---@field parent_id				string @[hash] The id of the new parent
---@field keep_world_transform	string @[number] 0/1 - whether to keep world transform (1) or not (0)

---Post this message to set the parent of an instance, making it exist in the geometrical space of its parent.
---@class LetterSetParent : BaseLetterDefinition
---@field data SetParentMessageDefinition Parent configuration
Letters.set_parent = {
	id = hashed.set_parent,
	data = {
		parent_id = "hash",
		keep_world_transform = "number"
	}
}

--
-- GUI
--
---@class LayoutChangedMessageDefinition
---@field id			string @[hash] Current layout id
---@field previous_id	string @[hash] Previous layout id

---@class LetterLayoutChanged : BaseLetterDefinition
---@field data LayoutChangedMessageDefinition Layout change information
Letters.layout_changed = {
	id = hashed.layout_changed,
	data = {
		id = "hash",
		previous_id = "hash"
	}
}

--
-- MODEL
--

---This message is sent when a Model animation has finished playing back to the script that started the animation.
---@class ModelAnimationDoneMessageDefinition
---@field animation_id	string @[hash] 	ID of the completed animation
---@field playback		string @[number] Playback mode constant

---@class LetterModelAnimationDone : BaseLetterDefinition
---@field data ModelAnimationDoneMessageDefinition Animation completion data
Letters.model_animation_done = {
	id = hashed.model_animation_done,
	data = {
		animation_id = "hash",
		playback = "number"
	}
}

--
-- PHYSICS
--

---Post this message to a collision-object-component to apply force on the collision object. The collision object must be dynamic.
---@class ApplyForceMessageDefinition
---@field force		string @[vector3] Force to be applied on the collision object (in Newtons)
---@field position	string @[vector3] Position where the force should be applied

---@class LetterApplyForce : BaseLetterDefinition
---@field data ApplyForceMessageDefinition Force application data
Letters.apply_force = {
	id = hashed.apply_force,
	data = {
		force = "vector3",
		position = "vector3"
	}
}

---Message sent when two collision objects collide. Reports collision once per frame per colliding pair.
---@class CollisionObjectMessageDefinition
---@field position	string @[vector3] World position of the object
---@field id		string @[hash] ID of the object
---@field group		string @[hash] Collision group of the object

---@class CollisionEventMessageDefinition
---@field a			string @[table with position, id, group] Collision information for object A
---@field b			string @[table with position, id, group] Collision information for object B

---@class LetterCollisionEvent : BaseLetterDefinition
---@field data CollisionEventMessageDefinition Collision event data
Letters.collision_event = { id = hashed.collision_event, data = {
	a = {
		position = "vector3",
		id = "hash",
		group = "hash"
	},
	b = {
		position = "vector3",
		id = "hash",
		group = "hash"
	}
}}

---Message broadcasted to every component of an instance with a collision object when it collides.
---@class CollisionResponseMessageDefinition
---@field other_id		string @[hash] ID of the instance that collided with
---@field other_position	string @[vector3] World position of the other instance
---@field other_group		string @[hash] Collision group of the other object
---@field own_group		string @[hash] Collision group of own object

---@class LetterCollisionResponse : BaseLetterDefinition
---@field data CollisionResponseMessageDefinition Collision response data
Letters.collision_response = {
	id = hashed.collision_response,
	data = {
		other_id = "hash",
		other_position = "vector3",
		other_group = "hash",
		own_group = "hash"
	}
}

---Detailed contact point information for a collision object
---@class ContactPointObjectMessageDefinition
---@field position		string @[vector3] World position of the object
---@field id			string @[hash] ID of the object
---@field group			string @[hash] Collision group of the object
---@field relative_velocity	string @[vector3] Relative velocity as observed from other object
---@field mass			string @[number] Mass of the object in kg
---@field normal		string @[vector3] Normal in world space

---Message sent when collision objects have contact points. Can be sent multiple times per frame.
---@class ContactPointEventMessageDefinition
---@field applied_impulse	string @[number] Impulse the contact resulted in
---@field distance			string @[number] Penetration distance between objects (always positive)
---@field a			string @[table with position, id, group, relative_velocity, mass, normal] Contact point information for object A
---@field b			string @[table with position, id, group, relative_velocity, mass, normal] Contact point information for object B

---@class LetterContactPointEvent : BaseLetterDefinition
---@field data ContactPointEventMessageDefinition Contact point event data
Letters.contact_point_event = {
	id = hashed.contact_point_event,
	data = {
		applied_impulse = "number",
		distance = "number",
		a = {
			position = "vector3",
			id = "hash",
			group = "hash",
			relative_velocity = "vector3",
			mass = "number",
			normal = "vector3"
		},
		b = {
			position = "vector3",
			id = "hash",
			group = "hash",
			relative_velocity = "vector3",
			mass = "number",
			normal = "vector3"
		}
	}
}

---Detailed contact point response sent to components of an instance with a collision object.
---@class ContactPointResponseMessageDefinition
---@field position			string @[vector3] World position of contact point
---@field normal			string @[vector3] Normal in world space (points from other object to current)
---@field relative_velocity	string @[vector3] Relative velocity as observed from other object
---@field distance			string @[number] Penetration distance (always positive)
---@field applied_impulse	string @[number] Resulting impulse
---@field life_time			string @[number] Contact life time (not currently used)
---@field mass				string @[number] Mass of current object in kg
---@field other_mass		string @[number] Mass of other object in kg
---@field other_id			string @[hash] Other instance ID
---@field other_position	string @[vector3] Other object position
---@field other_group		string @[hash] Other collision group
---@field own_group			string @[hash] Own collision group

---@class LetterContactPointResponse : BaseLetterDefinition
---@field data ContactPointResponseMessageDefinition Contact point response data
Letters.contact_point_response = {
	id = hashed.contact_point_response,
	data = {
		position = "vector3",
		normal = "vector3",
		relative_velocity = "vector3",
		distance = "number",
		applied_impulse = "number",
		life_time = "number",
		mass = "number",
		other_mass = "number",
		other_id = "hash",
		other_position = "vector3",
		other_group = "hash",
		own_group = "hash"
	}
}

---Message sent when ray cast doesn't hit any collision object.
---@class RayCastMissedMessageDefinition
---@field request_id	string @[number] Ray cast request ID

---@class LetterRayCastMissed : BaseLetterDefinition
---@field data RayCastMissedMessageDefinition Ray cast missed data
Letters.ray_cast_missed = {
	id = hashed.ray_cast_missed,
	data = {
		request_id = "number"
	}
}

---Message sent when ray cast hits a collision object.
---@class RayCastResponseMessageDefinition
---@field fraction		string @[number] Fraction of ray length where hit occurred (0-1)
---@field position		string @[vector3] Hit position in world space
---@field normal		string @[vector3] Surface normal at hit point
---@field id			string @[hash] Hit object ID
---@field group			string @[hash] Hit object collision group
---@field request_id	string @[number] Ray cast request ID

---@class LetterRayCastResponse : BaseLetterDefinition
---@field data RayCastResponseMessageDefinition Ray cast response data
Letters.ray_cast_response = {
	id = hashed.ray_cast_response,
	data = {
		fraction = "number",
		position = "vector3",
		normal = "vector3",
		id = "hash",
		group = "hash",
		request_id = "number"
	}
}

---Basic collision object information for trigger events
---@class TriggerObjectMessageDefinition
---@field id		string @[hash] ID of the object
---@field group		string @[hash] Collision group of the object

---Message sent when collision objects interact and one is a trigger.
---@class TriggerEventMessageDefinition
---@field enter		string @[boolean] True if entering trigger, false if exiting
---@field a			string @[table with id, group] Information for object A
---@field b			string @[table with id, group] Information for object B

---@class LetterTriggerEvent : BaseLetterDefinition
---@field data TriggerEventMessageDefinition Trigger event data
Letters.trigger_event = { id = hashed.trigger_event, data = {
	enter = "boolean",
	a = {
		id = "hash",
		group = "hash"
	},
	b = {
		id = "hash",
		group = "hash"
	}
}}

---Message broadcasted when collision object interacts with a trigger.
---@class TriggerResponseMessageDefinition
---@field other_id		string @[hash] ID of the triggering instance
---@field enter			string @[boolean] True if entering trigger, false if exiting
---@field other_group	string @[hash] Collision group of triggering object
---@field own_group		string @[hash] Collision group of own object

---@class LetterTriggerResponse : BaseLetterDefinition
---@field data TriggerResponseMessageDefinition Trigger response data
Letters.trigger_response = {
	id = hashed.trigger_response,
	data = {
		other_id = "hash",
		enter = "boolean",
		other_group = "hash",
		own_group = "hash"
	}
}

--
-- RENDER
--

---@class DrawDebugTextMessageDefinition
---@field position	string @[vector3] Text position
---@field text		string @[string] Debug text
---@field color		string @[vector4] Text color

---@class LetterDrawDebugText : BaseLetterDefinition
---@field data DrawDebugTextMessageDefinition Debug text data
Letters.draw_debug_text = {
	id = hashed.draw_debug_text,
	data = {
		position = "vector3",
		text = "string",
		color = "vector4"
	}
}

---@class DrawLineMessageDefinition
---@field start_point	string @[vector3] Line start point
---@field end_point		string @[vector3] Line end point
---@field color			string @[vector4] Line color

---@class LetterDrawLine : BaseLetterDefinition
---@field data DrawLineMessageDefinition Line drawing data
Letters.draw_line = {
	id = hashed.draw_line,
	data = {
		start_point = "vector3",
		end_point = "vector3",
		color = "vector4"
	}
}

---@class WindowDimensionsMessageDefinition
---@field height	string @[number] Window height
---@field width		string @[number] Window width

---@class LetterWindowResized : BaseLetterDefinition
---@field data WindowDimensionsMessageDefinition Window dimensions
Letters.window_resized = {
	id = hashed.window_resized,
	data = {
		height = "number",
		width = "number"
	}
}

---@class LetterResize : BaseLetterDefinition
---@field data WindowDimensionsMessageDefinition Window dimensions
Letters.resize = {
	id = hashed.resize,
	data = {
		height = "number",
		width = "number"
	}
}

---@class ClearColorMessageDefinition
---@field color		string @[vector4] Clear color

---@class LetterClearColor : BaseLetterDefinition
---@field data ClearColorMessageDefinition Clear color data
Letters.clear_color = {
	id = hashed.clear_color,
	data = {
		color = "vector4"
	}
}

--
-- SOUND
--

---@class PlaySoundMessageDefinition
---@field delay		string @[number?] Optional delay in seconds before the sound starts playing (default: 0)
---@field gain		string @[number?] Optional sound gain between 0 and 1 (default: 1)
---@field play_id	string @[number?] Optional identifier of the sound for distinguishing consecutive plays
---@field start_time	string @[number?] Optional start offset in seconds (mutually exclusive with start_frame)
---@field start_frame	string @[number?] Optional start offset in frames (takes precedence over start_time)

---Post this message to a sound-component to play its sound. Supports up to 32 voices per component.
---@class LetterPlaySound : BaseLetterDefinition
---@field data PlaySoundMessageDefinition? Optional sound playback configuration
Letters.play_sound = {
	id = hashed.play_sound,
	data = {
		delay = "number|nil",
		gain = "number|nil",
		play_id = "number|nil",
		start_time = "number|nil",
		start_frame = "number|nil"
	}
}

---Post this message to a sound-component to stop playing all active voices.
---@class LetterStopSound : BaseLetterDefinition
Letters.stop_sound = { id = hashed.stop_sound }

---@class SetGainMessageDefinition
---@field gain		string @[number?] Optional sound gain between 0 and 1 (default: 1)

---Post this message to a sound-component to set gain on all active playing voices.
---@class LetterSetGain : BaseLetterDefinition
---@field data SetGainMessageDefinition? Optional gain configuration
Letters.set_gain = { id = hashed.set_gain }

---@class SoundDoneMessageDefinition
---@field play_id		string @[number?] Optional ID number supplied with play_sound message

---Message sent when sound completes playing (if play_id was provided).
---@class LetterSoundDone : BaseLetterDefinition
---@field data SoundDoneMessageDefinition? Optional sound completion data
Letters.sound_done = { id = hashed.sound_done }

---@class SoundStoppedMessageDefinition
---@field play_id		string @[number?] Optional ID number supplied with play_sound message

---Message sent when sound is manually stopped (if play_id was provided).
---@class LetterSoundStopped : BaseLetterDefinition
---@field data SoundStoppedMessageDefinition? Optional sound stop data
Letters.sound_stopped = { id = hashed.sound_stopped }

--
-- SPRITE
--

---@class PlayAnimationMessageDefinition
---@field id	string @[hash] The id of the animation to play
---@field offset		string @[number?] Normalized initial value of animation cursor
---@field playback_rate	string @[number?] Animation playback rate (must be positive)

---Post this message to a sprite component to make it play an animation from its tile set.
---@class LetterPlayAnimation : BaseLetterDefinition
---@field data PlayAnimationMessageDefinition Animation data
Letters.play_animation = {
	id = hashed.play_animation,
	data = {
		id = "hash",
		offset = "number|nil",
		playback_rate = "number|nil"
	}
}

---@class AnimationDoneMessageDefinition
---@field current_tile	string @[number] The current tile of the sprite
---@field id			string @[hash] ID of the animation that was completed

---Message sent when animation completes. Only sent for animations with playback modes:
---Once Forward, Once Backward, or Once Ping Pong.
---@class LetterAnimationDone : BaseLetterDefinition
---@field data AnimationDoneMessageDefinition Animation completion data
Letters.animation_done = {
	id = hashed.animation_done,
	data = {
		current_tile = "number",
		id = "hash"
	}
}

--
-- SYS
--

---@class ExitMessageDefinition
---@field code		string @[number] Exit code to report to the OS (0 means clean exit)

---Terminates the game application and reports the specified code to the OS.
---Can only be sent to the designated @system socket.
---@class LetterExit : BaseLetterDefinition
---@field data ExitMessageDefinition Exit configuration
Letters.exit = {
	id = hashed.exit,data = {
		code = "number"
	}
}

---Toggles the on-screen profiler showing real-time performance metrics.
---Can only be sent to the designated @system socket.
---@class LetterToggleProfile : BaseLetterDefinition
Letters.toggle_profile = { id = hashed.toggle_profile }

---Toggles the on-screen physics visual debugging mode.
---Can only be sent to the designated @system socket.
---@class LetterTogglePhysicsDebug : BaseLetterDefinition
Letters.toggle_physics_debug = { id = hashed.toggle_physics_debug }

---@class StartRecordMessageDefinition
---@field file_name		string @[string] Output file name for the video recording
---@field frame_period	string @[number] Frame period to record (write every nth frame, default: 2)
---@field fps			string @[number] Playback speed in frames per second (default: 30)

---Starts video recording of the game frame-buffer to file (desktop platforms only).
---Can only be sent to the designated @system socket.
---@class LetterStartRecord : BaseLetterDefinition
---@field data StartRecordMessageDefinition Recording configuration
Letters.start_record = {
	id = hashed.start_record,
	data = {
		file_name = "string",
		frame_period = "number",
		fps = "number",
	}
}

---Stops the currently active video recording (desktop platforms only).
---Can only be sent to the designated @system socket.
---@class LetterStopRecord : BaseLetterDefinition
Letters.stop_record = { id = hashed.stop_record }

---@class RebootMessageDefinition
---@field arg1	string @[string] First command line argument
---@field arg2	string @[string] Second command line argument
---@field arg3	string @[string] Third command line argument
---@field arg4	string @[string] Fourth command line argument
---@field arg5	string @[string] Fifth command line argument
---@field arg6	string @[string] Sixth command line argument

---Reboots the game engine with specified command line arguments.
---Can only be sent to the designated @system socket.
---@class LetterReboot : BaseLetterDefinition
---@field data RebootMessageDefinition? Reboot configuration (optional)
Letters.reboot = { id = hashed.reboot }

---Resume rendering.
---Can only be sent to the designated @system socket.
---@class LetterResumeRendering : BaseLetterDefinition
Letters.resume_rendering = { id = hashed.resume_rendering }

---@class SetVsyncMessageDefinition
---@field swap_interval	string @[number] Target swap interval (0=disabled, 1=every v-blank, 2=every other v-blank)

---Sets the vsync swap interval for front and back buffers synchronization.
---Can only be sent to the designated @system socket.
---@class LetterSetVsync : BaseLetterDefinition
---@field data SetVsyncMessageDefinition Vsync configuration
Letters.set_vsync = {
	id = hashed.set_vsync,
	data = {
		swap_interval = "number"
	}
}

---@class SetUpdateFrequencyMessageDefinition
---@field frequency	string @[number] Target update frequency (e.g. 60 for 60 fps)

---Sets game update-frequency (frame cap) at runtime.
---Can only be sent to the designated @system socket.
---@class LetterSetUpdateFrequency : BaseLetterDefinition
---@field data SetUpdateFrequencyMessageDefinition Frequency configuration
Letters.set_update_frequency = {
	id = hashed.set_update_frequency,
	data = {
		frequency = "number"
	}
}

return Letters
