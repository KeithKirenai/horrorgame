extends Node

func setup_gamepad_inputs():
	var mappings = {
		"interact": [
			{"type": "mouse", "val": MOUSE_BUTTON_LEFT},
			{"type": "joy_button", "val": JOY_BUTTON_X}
		],
		"jump": [
			{"type": "key", "val": KEY_SPACE},
			{"type": "joy_button", "val": JOY_BUTTON_A}
		],
		"flashlight": [
			{"type": "key", "val": KEY_F},
			{"type": "joy_button", "val": JOY_BUTTON_Y},
			{"type": "joy_button", "val": JOY_BUTTON_DPAD_UP}
		],
		"sprint": [
			{"type": "key", "val": KEY_SHIFT},
			{"type": "joy_button", "val": JOY_BUTTON_LEFT_STICK},
			{"type": "joy_button", "val": JOY_BUTTON_LEFT_SHOULDER}
		],
		"ui_accept": [
			{"type": "joy_button", "val": JOY_BUTTON_A}
		],
		"ui_cancel": [
			{"type": "key", "val": KEY_ESCAPE},
			{"type": "joy_button", "val": JOY_BUTTON_B}
		],
		"pause": [
			{"type": "key", "val": KEY_ESCAPE},
			{"type": "joy_button", "val": JOY_BUTTON_START}
		],
		"ui_up": [
			{"type": "joy_button", "val": JOY_BUTTON_DPAD_UP},
			{"type": "joy_axis", "val": JOY_AXIS_LEFT_Y, "axis_value": -1.0}
		],
		"ui_down": [
			{"type": "joy_button", "val": JOY_BUTTON_DPAD_DOWN},
			{"type": "joy_axis", "val": JOY_AXIS_LEFT_Y, "axis_value": 1.0}
		],
		"ui_left": [
			{"type": "joy_button", "val": JOY_BUTTON_DPAD_LEFT},
			{"type": "joy_axis", "val": JOY_AXIS_LEFT_X, "axis_value": -1.0}
		],
		"ui_right": [
			{"type": "joy_button", "val": JOY_BUTTON_DPAD_RIGHT},
			{"type": "joy_axis", "val": JOY_AXIS_LEFT_X, "axis_value": 1.0}
		]
	}

	for action in mappings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		for item in mappings[action]:
			var event = null
			if item.type == "key":
				event = InputEventKey.new()
				event.physical_keycode = item.val
			elif item.type == "mouse":
				event = InputEventMouseButton.new()
				event.button_index = item.val
			elif item.type == "joy_button":
				event = InputEventJoypadButton.new()
				event.button_index = item.val
			elif item.type == "joy_axis":
				event = InputEventJoypadMotion.new()
				event.axis = item.val
				event.axis_value = item.get("axis_value", 0.0)

			if event:
				event.device = -1
				if not InputMap.action_has_event(action, event):
					InputMap.action_add_event(action, event)


