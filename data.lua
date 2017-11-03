-- Inputs
data:extend{
	{
		type = "custom-input",
		name = "stop-recording",
		key_sequence = "U",
	},
	{
		type = "custom-input",
		name = "save-recording",
		key_sequence = "I",
	},
	{
		type = "custom-input",
		name = "bp_order_entity",
		key_sequence = "J",
	},
	{
		type = "custom-input",
		name = "bp_order_entity_remove",
		key_sequence = "SHIFT + J",
	},
	{
		type = "custom-input",
		name = "bp_area_trigger",
		key_sequence = "K",
	},
	{
		type = "sprite",
		name = "tas_playback_next",
			filename = "__tas_playback__/graphics/generic_buttons.png",
			priority = "medium",
			width = 64,
			height = 64,
			x = 0,
			y =  0,
			flags = {"icon"},
	},
	{
		type = "sprite",
		name = "tas_playback_prev",
			filename = "__tas_playback__/graphics/generic_buttons.png",
			priority = "medium",
			width = 64,
			height = 64,
			x = 64,
			y =  0,
			flags = {"icon"},
	},
	{
		type = "sprite",
		name = "tas_playback_undo",
			filename = "__tas_playback__/graphics/generic_buttons.png",
			priority = "medium",
			width = 64,
			height = 64,
			x = 0,
			y =  64,
			flags = {"icon"},
	},
	{
		type = "sprite",
		name = "tas_playback_save",
			filename = "__tas_playback__/graphics/generic_buttons.png",
			priority = "medium",
			width = 64,
			height = 64,
			x = 64,
			y =  64,
			flags = {"icon"},
	}
} 

