--
-- LETTERS
--
-- Letters for Pigeon are special messages with message_id and message data defined (or not).
-- Message_ids are pre-hashed utilising Defold Hashed by Sergey Lerg:
-- https://github.com/Lerg/defold-hashed
--
-- By Pawel Jarosz, 2023
-- License: MIT

local hashed = require "pigeon.hashed"

local M = {}

--
-- DEFOLD SYSTEM MESSAGES - received from or to post to certain components. Based on Defold API 1.4.5.
--

--
-- CAMERA
--
M.set_camera = { id = hashed.set_camera, data = {
	aspect_ratio = "number",
	fov = "number",
	near_z = "number",
	far_z = "number",
	orthographic_projection = "boolean",
	orthographic_zoom = "number"
}}
M.acquire_camera_focus = { id = hashed.acquire_camera_focus }
M.release_camera_focus = { id = hashed.release_camera_focus }

--
-- COLLECTION PROXY
--
M.set_time_step = { id = hashed.set_time_step, data = {
	factor = "number",
	mode = "number"
}}
M.load = { id = hashed.load }
M.unload = { id = hashed.unload }
M.async_load = { id = hashed.async_load }
M.proxy_loaded = { id = hashed.proxy_loaded }
M.proxy_unloaded = { id = hashed.proxy_unloaded }
M.init = { id = hashed.init }
M.final = { id = hashed.final }

--
-- COLLECTION PROXY, GAME OBJECT
--
M.enable = { id = hashed.enable }
M.disable = { id = hashed.disable }

--
-- GAME OBJECT
--
M.acquire_input_focus = { id = hashed.acquire_input_focus }
M.release_input_focus = { id = hashed.release_input_focus }
M.set_parent = { id = hashed.set_parent, data = {
	parent_id = "hash",
	keep_world_transform = "number"
}}

--
-- GUI
--
M.layout_changed = { id = hashed.layout_changed, data = {
	id = "hash",
	previous_id = "hash"
}}

--
-- MODEL
--
M.model_animation_done = { id = hashed.model_animation_done, data = {
	animation_id = "hash",
	playback = "number" -- playback is number (constant)
}}

-- PHYSICS
M.apply_force = { id = hashed.apply_force, data = {
	force = "vector3",
	position = "vector3"
}}
M.collision_response = { id = hashed.collision_response, data = {
	other_id = "hash",
	other_position = "vector3",
	other_group = "hash",
	own_group = "hash"
}}
M.contact_point_response = { id = hashed.contact_point_response, data = {
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
}}
M.trigger_response = { id = hashed.trigger_response, data = {
	other_id = "hash",
	enter = "bool",
	other_group = "hash",
	own_group = "hash"
}}
M.ray_cast_response = { id = hashed.ray_cast_response, data = {
	fraction = "number",
	position = "vector3",
	normal = "vector3",
	id = "hash",
	group = "hash",
	request_id = "number"
}}
M.ray_cast_missed = { id = hashed.ray_cast_missed, data = {
	request_id = "number"
}}

--
-- RENDER
--
M.draw_debug_text = { id = hashed.draw_debug_text, data = {
	position = "vector3",
	text = "string",
	color = "vector4"
}}
M.draw_line = { id = hashed.draw_line, data = {
	start_point = "vector3",
	end_point = "vector3",
	color = "vector4"
}}
M.window_resized = { id = hashed.window_resized, data = {
	height = "number",
	width = "number"
}}
M.resize = { id = hashed.resize, data = {
	height = "number",
	width = "number"
}}
M.clear_color = { id = hashed.clear_color, data = {
	color = "vector4"
}}

--
-- SOUND
--
M.play_sound = { id = hashed.play_sound } -- data is optional, so not verified
M.stop_sound = { id = hashed.stop_sound }
M.set_gain = { id = hashed.set_gain } -- data is optional, so not verified
M.sound_done = { id = hashed.sound_done } -- data is optional, so not verified

--
-- SPRITE
--
M.play_animation = { id = hashed.play_animation, data = {
	id = "hash"
}}
M.animation_done = { id = hashed.animation_done, data = {
	current_tile = "number",
	id = "hash"
}}

--
-- SYS
--
M.exit = { id = hashed.exit, data = {
	code = "number"
}}
M.toggle_profile = { id = hashed.toggle_profile }
M.toggle_physics_debug = { id = hashed.toggle_physics_debug }
M.start_record = { id = hashed.start_record, data = {
	file_name = "string",
	frame_period = "number",
	fps = "number",
}}
M.stop_record = { id = hashed.stop_record }
M.reboot = { id = hashed.reboot } -- args are optional, check out doc
M.set_vsync = { id = hashed.set_vsync, data = {
	swap_interval = "number"
}}
M.set_update_frequency = { id = hashed.set_update_frequency, data = {
	frequency = "number"
}}

return M