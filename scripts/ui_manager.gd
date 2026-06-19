extends CanvasLayer

signal game_started
signal difficulty_selected(difficulty_name)

var hud: Control # Make HUD class-level
var start_screen: Control
var pause_menu: Control
var pause_main: PanelContainer # Upgraded to PanelContainer
var pause_options: PanelContainer # Upgraded to PanelContainer
var is_game_active = false
var is_paused = false
var current_difficulty: String = "normal"

# Game Over Screen Nodes
var game_over_screen: Control
var game_over_retry_btn: Button
var game_over_menu_btn: Button


# Objective UI
var objective_label: Label

# Post Process Ref
var vhs_material_ref: ShaderMaterial # Bad Stream Shader

# Debug UI
var debug_control: Control
var debug_labels = {}
var debug_log: RichTextLabel

# Custom HUD elements
var stamina_heart: Label
var start_desc_label: Label
var pause_resume_btn: Button
var options_first_btn: Button
var btn_opt_texture_style: Button
var instructions_label: HBoxContainer
var pause_prompts_lbl: HBoxContainer
var options_prompts_lbl: HBoxContainer
var is_gamepad_active = false
var notification_container: VBoxContainer
var options_preview_rect: TextureRect

# Loading Screen
var loading_screen: ColorRect
var loading_label: Label

# Crosshair
var crosshair_dot: ColorRect

# Stamina UI (Beating heart + Bar)
var stamina_fill: ColorRect
var stamina_bg_ref: ColorRect
var stamina_label: Label

# Options Preview & Description Panel
var desc_label: Label
var impact_label: Label
var value_label: Label
var preview_material: ShaderMaterial

# Controls Legend
var controls_legend_vbox: VBoxContainer
var last_controls_gamepad = false

# Dynamic UI State
var stamina_fade_timer = 0.0
var stamina_opacity = 0.0

func _process(delta):
	# Dynamically update button prompts if gamepad state changes
	if instructions_label:
		var target_prompts = _get_input_prompts()
		if instructions_label.text != target_prompts:
			instructions_label.text = target_prompts
	
	if is_game_active and controls_legend_vbox:
		if is_gamepad_active != last_controls_gamepad:
			last_controls_gamepad = is_gamepad_active
			_update_controls_legend()

	# Update pause / options menu prompts if visible
	if is_paused and pause_menu and pause_menu.visible:
		_update_menu_prompts()

	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	# Update gameplay interaction label
	if hud and hud.visible:
		var interact_panel = hud.get_node_or_null("InteractPanel")
		var interact_lbl = hud.get_node_or_null("InteractPanel/InteractLabel")
		if interact_panel and interact_lbl:
			var show_prompt = false
			var prompt_text = ""
			if player and player.raycast and player.raycast.is_colliding():
				var collider = player.raycast.get_collider()
				if collider and collider.has_method("interact"):
					show_prompt = true
					# Highlight crosshair red to signal interactable
					if crosshair_dot:
						crosshair_dot.color = Color(0.9, 0.15, 0.15, 1.0)
					
					var action_verb = "Interact"
					if collider.has_method("get_interaction_text"):
						action_verb = collider.get_interaction_text()
					
					var button_str = "[E]"
					if Input.get_connected_joypads().size() > 0 and is_gamepad_active:
						if is_playstation_controller():
							button_str = "[CROSS]"
						else:
							button_str = "[A]"
					
					prompt_text = "Press %s to %s" % [button_str, action_verb]
			
			if interact_panel.visible != show_prompt:
				interact_panel.visible = show_prompt
			if show_prompt:
				interact_lbl.set_prompt(prompt_text)
			else:
				# Reset crosshair to white when not hovering
				if crosshair_dot:
					crosshair_dot.color = Color(1.0, 1.0, 1.0, 0.75)
	
	# --- Update Values ---
	if stamina_fill:
		stamina_fill.size.x = (player.stamina / 100.0) * 100.0

	# --- Fading Logic ---
	var want_stamina = player.is_sprinting or player.stamina < 99.0
	if want_stamina:
		stamina_fade_timer = 0.0
		stamina_opacity = move_toward(stamina_opacity, 1.0, delta * 5.0)
	else:
		stamina_fade_timer += delta
		if stamina_fade_timer > 0.5:
			stamina_opacity = move_toward(stamina_opacity, 0.0, delta * 2.0)

	if stamina_bg_ref: stamina_bg_ref.modulate.a = stamina_opacity
	if stamina_fill: stamina_fill.modulate.a = stamina_opacity
	if stamina_label: stamina_label.modulate.a = stamina_opacity
	if stamina_heart: stamina_heart.modulate.a = stamina_opacity

func _ready():
	is_gamepad_active = Input.get_connected_joypads().size() > 0
	layer = 100 # Ensure UI is above Post-Processing (which is layer 5)
	Engine.max_fps = 20 # PS1 framerate by default
	add_to_group("ui_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS # Essential for pausing

	setup_ui()
	setup_pause_menu()
	setup_debug_ui()
	setup_game_over_screen()

	EventBus.notification_requested.connect(show_notification)
	EventBus.debug_log_requested.connect(log_debug)
	EventBus.generator_interaction_held.connect(_on_generator_interaction_held)

	last_controls_gamepad = is_gamepad_active

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)









func set_player_sensitivity(val: float):

	var player = get_tree().get_first_node_in_group("player")

	if player:

		player.mouse_sensitivity = val

		log_debug("Sensitivity: " + str(val))



func setup_debug_ui():

	debug_control = Control.new()

	debug_control.set_anchors_preset(Control.PRESET_FULL_RECT)

	debug_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	debug_control.visible = false # Hidden by default

	add_child(debug_control)

	

	var container = VBoxContainer.new()

	container.position = Vector2(10, 150) # Moved down further

	container.add_theme_constant_override("separation", 2)

	debug_control.add_child(container)

	

	# Pre-create categories

	var categories = ["FPS", "Player", "Enemy", "EnemyFOV", "RayHit", "Map", "System"]

	for cat in categories:

		var lbl = Label.new()

		lbl.text = cat + ": ..."

		lbl.add_theme_color_override("font_color", Color.YELLOW)

		lbl.add_theme_font_size_override("font_size", 10) # Smaller

		container.add_child(lbl)

		debug_labels[cat] = lbl

	

	# Log

	debug_log = RichTextLabel.new()

	debug_log.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

	debug_log.position = Vector2(DisplayServer.window_get_size().x - 410, DisplayServer.window_get_size().y - 210)

	debug_log.size = Vector2(400, 200)

	debug_log.scroll_following = true

	debug_log.add_theme_font_size_override("normal_font_size", 8) # Smaller

	debug_log.add_theme_color_override("default_color", Color(0.7, 0.7, 0.7))

	debug_control.add_child(debug_log)



func update_debug(key: String, value):

	if not debug_control or not debug_control.visible: return

	

	if debug_labels.has(key):

		debug_labels[key].text = key + ": " + str(value)



func log_debug(message: String):

	print("[DEBUG] " + message)

	if debug_log:

		var time = Time.get_time_string_from_system()

		debug_log.append_text("[%s] %s\n" % [time, message])



func setup_ui():
	# --- HUD (Gameplay UI) ---
	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false # Hidden initially until game starts
	add_child(hud)
	
	# --- Loading Screen (above everything) ---
	loading_screen = ColorRect.new()
	loading_screen.name = "LoadingScreen"
	loading_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_screen.color = Color(0.0, 0.0, 0.0, 1.0)
	loading_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_screen.z_index = 200 # Highest layer
	loading_screen.visible = false
	add_child(loading_screen)
	
	# Loading screen layout: scanline stripe, title, status
	var load_vbox = VBoxContainer.new()
	load_vbox.set_anchors_preset(Control.PRESET_CENTER)
	load_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	load_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	load_vbox.custom_minimum_size = Vector2(600, 120)
	load_vbox.add_theme_constant_override("separation", 14)
	loading_screen.add_child(load_vbox)
	
	var load_title = Label.new()
	load_title.text = "◆  SECURITY FOOTAGE SYSTEM  ◆"
	load_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_title.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0))
	load_title.add_theme_font_size_override("font_size", 13)
	load_vbox.add_child(load_title)
	
	loading_label = Label.new()
	loading_label.text = "PLEASE STAND BY..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	loading_label.add_theme_font_size_override("font_size", 18)
	load_vbox.add_child(loading_label)
	
	var load_sub = Label.new()
	load_sub.text = "DO NOT TURN OFF THE POWER"
	load_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_sub.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	load_sub.add_theme_font_size_override("font_size", 9)
	load_vbox.add_child(load_sub)
	
	# Blinking cursor under text
	var blink_bar = Label.new()
	blink_bar.text = "█"
	blink_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blink_bar.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	blink_bar.add_theme_font_size_override("font_size", 14)
	load_vbox.add_child(blink_bar)
	var blink_timer = Timer.new()
	blink_timer.wait_time = 0.5
	blink_timer.autostart = true
	loading_screen.add_child(blink_timer)
	blink_timer.timeout.connect(func():
		blink_bar.visible = not blink_bar.visible
	)
	
	# --- Notification Stack Container ---
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notification_container.position.y = 80 # Offset from top to clear the camera hud
	notification_container.custom_minimum_size = Vector2(400, 200)
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notification_container)
	
	# Viewfinder corner brackets
	var corners = ViewfinderFrame.new()
	corners.name = "Corners"
	hud.add_child(corners)
	
	# Blinking REC dot
	var rec_timer = Timer.new()
	rec_timer.name = "RECBlinkTimer"
	rec_timer.wait_time = 0.6
	rec_timer.autostart = true
	hud.add_child(rec_timer)
	
	var rec_label = Label.new()
	rec_label.text = "REC ●"
	rec_label.position = Vector2(25, 25)
	rec_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	rec_label.add_theme_font_size_override("font_size", 14)
	hud.add_child(rec_label)
	
	rec_timer.timeout.connect(func():
		if rec_label.text == "REC ●":
			rec_label.text = "REC  "
		else:
			rec_label.text = "REC ●"
	)
	
	# Retro Date / Time stamp
	var timestamp_lbl = Label.new()
	timestamp_lbl.text = "JUN. 17 1996\n03:47:12 AM"
	timestamp_lbl.position = Vector2(25, 52)
	timestamp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	timestamp_lbl.add_theme_font_size_override("font_size", 9)
	hud.add_child(timestamp_lbl)
	
	# Objective
	objective_label = Label.new()
	objective_label.text = "Pages: 0/5"
	objective_label.position = Vector2(25, 90)
	objective_label.add_theme_color_override("font_color", Color.WHITE)
	objective_label.add_theme_font_size_override("font_size", 12)
	hud.add_child(objective_label)
	
	# Stamina UI (Bottom Center)
	var stam_container = HBoxContainer.new()
	stam_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stam_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stam_container.position = Vector2(-80, -45)
	stam_container.size = Vector2(160, 30)
	stam_container.alignment = HBoxContainer.ALIGNMENT_CENTER
	
	stamina_heart = HUD_StaminaHeart.new()
	stamina_heart.name = "StaminaHeart"
	stamina_heart.custom_minimum_size = Vector2(20, 20)
	stam_container.add_child(stamina_heart)
	
	var stam_space = Control.new()
	stam_space.custom_minimum_size = Vector2(8, 0)
	stam_container.add_child(stam_space)
	
	var stam_vbox = VBoxContainer.new()
	stam_vbox.add_theme_constant_override("separation", 2)
	
	stamina_label = Label.new()
	stamina_label.text = "HEART RATE / STAMINA"
	stamina_label.add_theme_font_size_override("font_size", 7)
	stamina_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	stam_vbox.add_child(stamina_label)
	
	stamina_bg_ref = ColorRect.new()
	stamina_bg_ref.custom_minimum_size = Vector2(100, 4)
	stamina_bg_ref.color = Color(0.2, 0.2, 0.0, 0.4)
	
	stamina_fill = ColorRect.new()
	stamina_fill.size = Vector2(100, 4)
	stamina_fill.color = Color(1.0, 0.8, 0.0)
	stamina_bg_ref.add_child(stamina_fill)
	stam_vbox.add_child(stamina_bg_ref)
	stam_container.add_child(stam_vbox)
	hud.add_child(stam_container)
	
	# Gameplay interaction prompt panel and label
	var interact_panel = PanelContainer.new()
	interact_panel.name = "InteractPanel"
	interact_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	interact_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	interact_panel.position = Vector2(-150, -90)
	interact_panel.size = Vector2(300, 30)
	interact_panel.visible = false
	
	var label_style = StyleBoxFlat.new()
	label_style.bg_color = Color(0.01, 0.01, 0.01, 0.8)
	label_style.content_margin_left = 12
	label_style.content_margin_right = 12
	label_style.content_margin_top = 4
	label_style.content_margin_bottom = 4
	label_style.border_width_left = 1
	label_style.border_width_top = 1
	label_style.border_width_right = 1
	label_style.border_width_bottom = 1
	label_style.border_color = Color(0.5, 0.0, 0.0) # Dark red outline matching theme
	label_style.corner_radius_top_left = 2
	label_style.corner_radius_top_right = 2
	label_style.corner_radius_bottom_left = 2
	label_style.corner_radius_bottom_right = 2
	interact_panel.add_theme_stylebox_override("panel", label_style)
	
	var interact_lbl = PromptContainer.new()
	interact_lbl.name = "InteractLabel"
	interact_panel.add_child(interact_lbl)
	
	hud.add_child(interact_panel)

	# --- Crosshair dot (center of screen) ---
	crosshair_dot = ColorRect.new()
	crosshair_dot.name = "CrosshairDot"
	crosshair_dot.custom_minimum_size = Vector2(6, 6)
	crosshair_dot.color = Color(1.0, 1.0, 1.0, 0.75)
	crosshair_dot.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_dot.position = Vector2(-3, -3)
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair_dot)

	
	# --- Controls Legend Panel (bottom-left, always visible during play) ---
	var legend = PanelContainer.new()
	legend.name = "ControlsLegend"
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.grow_horizontal = Control.GROW_DIRECTION_END
	legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend.position = Vector2(14, -120)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var legend_style = StyleBoxFlat.new()
	legend_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	legend_style.border_width_left = 1
	legend_style.border_width_top = 1
	legend_style.border_width_right = 1
	legend_style.border_width_bottom = 1
	legend_style.border_color = Color(0.4, 0.0, 0.0, 0.7)
	legend_style.content_margin_left = 8
	legend_style.content_margin_right = 8
	legend_style.content_margin_top = 6
	legend_style.content_margin_bottom = 6
	legend.add_theme_stylebox_override("panel", legend_style)

	controls_legend_vbox = VBoxContainer.new()
	controls_legend_vbox.add_theme_constant_override("separation", 2)
	controls_legend_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(controls_legend_vbox)

	_update_controls_legend()
	hud.add_child(legend)


	# --- START SCREEN (Main Menu) - VHS Cassette Shelf Style ---
	start_screen = Control.new()
	start_screen.name = "StartScreen"
	start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Dark shelf background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.02, 0.02)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_screen.add_child(bg)
	
	# Scanline overlay (dark horizontal lines for CRT feel)
	var scanline_rect = ColorRect.new()
	scanline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanline_rect.color = Color(0, 0, 0, 0.0)
	scanline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline_rect.name = "ScanlineRect"
	start_screen.add_child(scanline_rect)
	
	# Procedural Vignette Overlay
	var vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad = Gradient.new()
	grad.set_offsets(PackedFloat32Array([0.3, 1.0]))
	grad.set_colors(PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.92)]))
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.4)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	vignette.texture = grad_tex
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_screen.add_child(vignette)
	
	# Main layout: top logo, center cassette shelf, bottom instructions
	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	start_screen.add_child(root_vbox)
	
	# ── TOP ZONE: Echo Index Logo ──
	var top_margin = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 28)
	top_margin.add_theme_constant_override("margin_left", 0)
	top_margin.add_theme_constant_override("margin_right", 0)
	top_margin.add_theme_constant_override("margin_bottom", 0)
	top_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root_vbox.add_child(top_margin)
	
	var logo_center = CenterContainer.new()
	top_margin.add_child(logo_center)
	
	var logo_img = TextureRect.new()
	logo_img.name = "EchoIndexLogo"
	if FileAccess.file_exists("res://assets/ui/echo_index_logo.png"):
		logo_img.texture = load("res://assets/ui/echo_index_logo.png")
	logo_img.custom_minimum_size = Vector2(360, 180)
	logo_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_center.add_child(logo_img)
	
	# Logo flicker effect
	var logo_flicker = Timer.new()
	logo_flicker.wait_time = randf_range(4.0, 9.0)
	logo_flicker.autostart = true
	logo_flicker.timeout.connect(func():
		var tw = logo_img.create_tween()
		tw.tween_property(logo_img, "modulate:a", 0.3, 0.05)
		tw.tween_property(logo_img, "modulate:a", 1.0, 0.04)
		tw.tween_property(logo_img, "modulate:a", 0.6, 0.03)
		tw.tween_property(logo_img, "modulate:a", 1.0, 0.06)
		logo_flicker.wait_time = randf_range(3.5, 10.0)
	)
	logo_img.add_child(logo_flicker)
	
	# Tagline under logo
	var tagline = Label.new()
	tagline.name = "SubtitleLabel"
	tagline.text = "// ARCHIVE RECOVERED — PLEASE SELECT A TAPE //"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.add_theme_color_override("font_color", Color(0.45, 0.1, 0.1))
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tagline_center = CenterContainer.new()
	tagline_center.add_theme_constant_override("margin_top", 4)
	tagline_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tagline_center.add_child(tagline)
	root_vbox.add_child(tagline_center)
	
	# ── MIDDLE ZONE: VHS Cassette Shelf ──
	var shelf_spacer = Control.new()
	shelf_spacer.custom_minimum_size = Vector2(0, 18)
	shelf_spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root_vbox.add_child(shelf_spacer)
	
	var shelf_center = CenterContainer.new()
	shelf_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(shelf_center)
	
	var shelf_hbox = HBoxContainer.new()
	shelf_hbox.add_theme_constant_override("separation", 32)
	shelf_center.add_child(shelf_hbox)
	
	# VHS tape data
	var tapes = [
		{
			"difficulty": "easy",
			"label_path": "res://assets/textures/vhs_easy.png",
			"title": "TAPE 001\nSECTOR ALPHA",
			"color": Color(0.55, 0.42, 0.10),   # rusted amber
			"info_title": "◆  TAPE 001 — SECTOR ALPHA  ◆",
			"info_lines": [
				"CLASSIFICATION: LEVEL-1 INCIDENT",
				"ENVIRONMENT: INDUSTRIAL FACILITY",
				"GRID SIZE: 4×4 LABYRINTH",
				"DATE RECORDED: 03 / 15 / 88",
				"",
				"FIELD NOTES: Earliest recovered footage.",
				"Steam pipes still pressurised. Grates slick.",
				"3 generators / 5 evidence items.",
				"",
				"\"It watched from the corner.\"",
				"     — NOTE FOUND ON TAPE CASE",
			]
		},
		{
			"difficulty": "normal",
			"label_path": "res://assets/textures/vhs_normal.png",
			"title": "TAPE 002\nWARD SEVEN",
			"color": Color(0.22, 0.48, 0.56),   # cold clinical teal
			"info_title": "◆  TAPE 002 — WARD SEVEN  ◆",
			"info_lines": [
				"CLASSIFICATION: LEVEL-2 INCIDENT",
				"ENVIRONMENT: MEDICAL WARD",
				"GRID SIZE: 8×8 LABYRINTH",
				"DATE RECORDED: 09 / 04 / 91",
				"",
				"FIELD NOTES: Fluorescent lights still cycle.",
				"Biohazard seals breached in wing C.",
				"3 generators / 5 evidence items.",
				"",
				"\"Do not look directly at the walls.\"",
				"     — SCRATCHED INTO TAPE CASING",
			]
		},
		{
			"difficulty": "hard",
			"label_path": "res://assets/textures/vhs_hard.png",
			"title": "TAPE 003\nTHE DESCENT",
			"color": Color(0.55, 0.10, 0.10),   # deep crimson
			"info_title": "◆  TAPE 003 — THE DESCENT  ◆",
			"info_lines": [
				"CLASSIFICATION: ██████ — RESTRICTED",
				"ENVIRONMENT: OUTDOOR RUINS",
				"GRID SIZE: 12×12 LABYRINTH",
				"DATE RECOVERED: ██ / ██ / ██",
				"",
				"FIELD NOTES: [DATA CORRUPTED]",
				"All previous investigators unaccounted for.",
				"3 generators / 5 evidence items.",
				"",
				"\"DO NOT PLAY THIS TAPE.\"",
				"     — WRITTEN IN MARKER ON LABEL",
			]
		},
	]
	
	# Build each VHS cassette widget
	for tape_data in tapes:
		var cassette = _build_vhs_cassette(tape_data)
		shelf_hbox.add_child(cassette)
	
	# ── BOTTOM ZONE: Instructions ──
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 4)
	bottom_spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root_vbox.add_child(bottom_spacer)
	
	instructions_label = PromptContainer.new()
	instructions_label.set_prompt(_get_input_prompts())
	var instr_center = CenterContainer.new()
	instr_center.size_flags_vertical = Control.SIZE_SHRINK_END
	instr_center.add_theme_constant_override("margin_bottom", 6)
	instr_center.add_child(instructions_label)
	root_vbox.add_child(instr_center)
	
	# ── VHS INFO OVERLAY (shows when a tape is selected) ──
	var vhs_info = Control.new()
	vhs_info.name = "VHSInfoOverlay"
	vhs_info.set_anchors_preset(Control.PRESET_FULL_RECT)
	vhs_info.visible = false
	vhs_info.z_index = 50
	
	var info_bg = ColorRect.new()
	info_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_bg.color = Color(0, 0, 0, 0.0)
	info_bg.name = "InfoBG"
	vhs_info.add_child(info_bg)
	
	var info_center = CenterContainer.new()
	info_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	vhs_info.add_child(info_center)
	
	var info_panel = PanelContainer.new()
	info_panel.name = "InfoPanel"
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.02, 0.02, 0.02, 0.0)
	info_style.border_width_left = 2
	info_style.border_width_top = 2
	info_style.border_width_right = 2
	info_style.border_width_bottom = 2
	info_style.border_color = Color(0.6, 0.0, 0.0, 0.0)
	info_style.corner_radius_top_left = 4
	info_style.corner_radius_top_right = 4
	info_style.corner_radius_bottom_left = 4
	info_style.corner_radius_bottom_right = 4
	info_style.content_margin_left = 40
	info_style.content_margin_right = 40
	info_style.content_margin_top = 32
	info_style.content_margin_bottom = 32
	info_panel.add_theme_stylebox_override("panel", info_style)
	info_panel.custom_minimum_size = Vector2(500, 320)
	info_center.add_child(info_panel)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_panel.add_child(info_vbox)
	
	var info_title_lbl = Label.new()
	info_title_lbl.name = "InfoTitleLabel"
	info_title_lbl.text = ""
	info_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title_lbl.add_theme_font_size_override("font_size", 18)
	info_title_lbl.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
	info_title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	info_title_lbl.add_theme_constant_override("outline_size", 4)
	info_vbox.add_child(info_title_lbl)
	
	var info_sep = ColorRect.new()
	info_sep.custom_minimum_size = Vector2(400, 1)
	info_sep.color = Color(0.4, 0.0, 0.0, 0.8)
	info_vbox.add_child(info_sep)
	
	# ── Action buttons row ──
	var info_btn_row = HBoxContainer.new()
	info_btn_row.name = "InfoButtonRow"
	info_btn_row.add_theme_constant_override("separation", 20)
	info_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_btn_row.modulate.a = 0.0
	info_btn_row.visible = false
	info_vbox.add_child(info_btn_row)
	
	# Helper to build the two confirm/cancel buttons
	var _make_info_btn = func(label: String, btn_name: String, is_confirm: bool) -> Button:
		var b = Button.new()
		b.name = btn_name
		b.text = label
		b.custom_minimum_size = Vector2(160, 34)
		b.focus_mode = Control.FOCUS_ALL
		
		var col_normal = Color(0.55, 0.0, 0.0) if is_confirm else Color(0.25, 0.25, 0.25)
		var col_hover  = Color(0.85, 0.08, 0.08) if is_confirm else Color(0.5, 0.5, 0.5)
		
		var sn = StyleBoxFlat.new()
		sn.bg_color = Color(col_normal.r * 0.12, col_normal.g * 0.12, col_normal.b * 0.12, 0.9)
		sn.border_width_left = 2; sn.border_width_top = 2
		sn.border_width_right = 2; sn.border_width_bottom = 2
		sn.border_color = col_normal
		sn.corner_radius_top_left = 3; sn.corner_radius_top_right = 3
		sn.corner_radius_bottom_left = 3; sn.corner_radius_bottom_right = 3
		sn.content_margin_left = 12; sn.content_margin_right = 12
		sn.content_margin_top = 6; sn.content_margin_bottom = 6
		
		var sh = sn.duplicate()
		sh.bg_color = Color(col_hover.r * 0.22, col_hover.g * 0.22, col_hover.b * 0.22, 0.95)
		sh.border_color = col_hover
		
		b.add_theme_stylebox_override("normal", sn)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("focus", sh)
		b.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		b.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
		b.add_theme_font_size_override("font_size", 13)
		
		b.pivot_offset = Vector2(80, 17)
		b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
		b.focus_entered.connect(func():
			var tw = b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_QUAD)
			_play_ui_sfx("hover")
		)
		b.focus_exited.connect(func():
			var tw = b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD)
		)
		b.mouse_entered.connect(func(): b.grab_focus())
		return b
	
	var play_btn = _make_info_btn.call("▶  PLAY TAPE", "PlayTapeButton", true)
	var eject_btn = _make_info_btn.call("⏏  EJECT", "EjectButton", false)
	info_btn_row.add_child(eject_btn)
	info_btn_row.add_child(play_btn)
	
	# Eject: hide the overlay and return focus to cassette shelf
	eject_btn.pressed.connect(func():
		_play_ui_sfx("vhs_eject")
		var tw = vhs_info.create_tween()
		tw.tween_property(vhs_info, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			vhs_info.visible = false
			vhs_info.modulate.a = 1.0
			_set_cassettes_focus_enabled(true)
			_focus_first_cassette()
		)
	)
	
	start_screen.add_child(vhs_info)
	
	add_child(start_screen)
	
	# Focus first cassette
	var first_cassette = shelf_hbox.get_child(0) if shelf_hbox.get_child_count() > 0 else null
	if first_cassette:
		var first_btn = first_cassette.find_child("CassetteButton", true, false)
		if first_btn:
			first_btn.grab_focus()


func _build_vhs_cassette(data: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.custom_minimum_size = Vector2(170, 250)
	
	# The clickable cassette button area
	var btn = Button.new()
	btn.name = "CassetteButton"
	btn.custom_minimum_size = Vector2(160, 210)
	btn.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	btn.focus_mode = Control.FOCUS_ALL
	
	# Style: nearly invisible — cassette image is the visual
	var sty_normal = StyleBoxFlat.new()
	sty_normal.bg_color = Color(0, 0, 0, 0)
	sty_normal.border_width_bottom = 0
	sty_normal.border_width_top = 0
	sty_normal.border_width_left = 0
	sty_normal.border_width_right = 0
	btn.add_theme_stylebox_override("normal", sty_normal)
	btn.add_theme_stylebox_override("hover", sty_normal.duplicate())
	btn.add_theme_stylebox_override("pressed", sty_normal.duplicate())
	btn.add_theme_stylebox_override("focus", sty_normal.duplicate())
	
	# Cassette body (dark grey rectangle with bevels)
	var cassette_body = PanelContainer.new()
	cassette_body.name = "CassetteBody"
	cassette_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	cassette_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var body_style = StyleBoxFlat.new()
	body_style.bg_color = Color(0.08, 0.08, 0.08)
	body_style.border_width_left = 3
	body_style.border_width_top = 3
	body_style.border_width_right = 3
	body_style.border_width_bottom = 5
	body_style.border_color = Color(0.18, 0.18, 0.18)
	body_style.corner_radius_top_left = 5
	body_style.corner_radius_top_right = 5
	body_style.corner_radius_bottom_left = 3
	body_style.corner_radius_bottom_right = 3
	body_style.shadow_color = Color(0, 0, 0, 0.6)
	body_style.shadow_size = 8
	body_style.shadow_offset = Vector2(3, 4)
	cassette_body.add_theme_stylebox_override("panel", body_style)
	
	var body_vbox = VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 6)
	body_vbox.add_theme_constant_override("margin_top", 10)
	cassette_body.add_child(body_vbox)
	
	# Label texture image
	var label_rect = TextureRect.new()
	label_rect.name = "LabelTexture"
	label_rect.custom_minimum_size = Vector2(140, 100)
	label_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	label_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	label_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists(data["label_path"]):
		label_rect.texture = load(data["label_path"])
	body_vbox.add_child(label_rect)
	
	# Tape window cutout area (stylized)
	var tape_window = PanelContainer.new()
	tape_window.custom_minimum_size = Vector2(0, 48)
	tape_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw_style = StyleBoxFlat.new()
	tw_style.bg_color = Color(0.03, 0.03, 0.03)
	tw_style.border_width_left = 2
	tw_style.border_width_top = 2
	tw_style.border_width_right = 2
	tw_style.border_width_bottom = 2
	tw_style.border_color = Color(0.12, 0.12, 0.12)
	tw_style.corner_radius_top_left = 3
	tw_style.corner_radius_top_right = 3
	tw_style.corner_radius_bottom_left = 20
	tw_style.corner_radius_bottom_right = 20
	tw_style.content_margin_left = 20
	tw_style.content_margin_right = 20
	tw_style.content_margin_top = 8
	tw_style.content_margin_bottom = 4
	tape_window.add_theme_stylebox_override("panel", tw_style)
	
	# Two reel circles
	var reels_hbox = HBoxContainer.new()
	reels_hbox.add_theme_constant_override("separation", 30)
	reels_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reels_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape_window.add_child(reels_hbox)
	for _r in range(2):
		var reel = PanelContainer.new()
		reel.custom_minimum_size = Vector2(24, 24)
		reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r_style = StyleBoxFlat.new()
		r_style.bg_color = Color(0.1, 0.1, 0.1)
		r_style.border_width_left = 2
		r_style.border_width_top = 2
		r_style.border_width_right = 2
		r_style.border_width_bottom = 2
		r_style.border_color = Color(0.3, 0.3, 0.3)
		r_style.corner_radius_top_left = 12
		r_style.corner_radius_top_right = 12
		r_style.corner_radius_bottom_left = 12
		r_style.corner_radius_bottom_right = 12
		reel.add_theme_stylebox_override("panel", r_style)
		reels_hbox.add_child(reel)
	body_vbox.add_child(tape_window)
	
	# Difficulty label at the bottom of cassette
	var diff_lbl = Label.new()
	diff_lbl.text = data["title"]
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 11)
	diff_lbl.add_theme_color_override("font_color", data["color"])
	diff_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_vbox.add_child(diff_lbl)
	
	btn.add_child(cassette_body)
	
	# Selection indicator (colored dot glow under cassette)
	var indicator = Label.new()
	indicator.name = "Indicator"
	indicator.text = "▼  SELECT  ▼"
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.add_theme_font_size_override("font_size", 11)
	indicator.add_theme_color_override("font_color", data["color"])
	indicator.modulate.a = 0.0
	
	container.add_child(btn)
	container.add_child(indicator)
	
	# Animate cassette pop-up and indicator on focus
	btn.pivot_offset = Vector2(80, 105)
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.focus_entered.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "position:y", -14.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tw2 = indicator.create_tween()
		tw2.tween_property(indicator, "modulate:a", 1.0, 0.15)
		_play_ui_sfx("hover")
	)
	btn.focus_exited.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var tw2 = indicator.create_tween()
		tw2.tween_property(indicator, "modulate:a", 0.0, 0.1)
	)
	btn.mouse_entered.connect(func(): btn.grab_focus())
	
	# On press: play VHS insert sequence then launch game
	var difficulty = data["difficulty"]
	var info_title = data["info_title"]
	btn.pressed.connect(func():
		_play_ui_sfx("click")
		_play_vhs_insert_sequence(difficulty, info_title)
	)
	
	return container

func _play_vhs_insert_sequence(difficulty: String, info_title: String):
	current_difficulty = difficulty
	_set_cassettes_focus_enabled(false)
	
	var vhs_info = start_screen.find_child("VHSInfoOverlay", true, false)
	if not vhs_info:
		_set_cassettes_focus_enabled(true)
		emit_signal("difficulty_selected", difficulty)
		return
	
	vhs_info.visible = true
	var info_bg = vhs_info.find_child("InfoBG", true, false)
	var info_panel = vhs_info.find_child("InfoPanel", true, false)
	var info_panel_style: StyleBoxFlat = info_panel.get_theme_stylebox("panel").duplicate()
	
	var title_lbl = vhs_info.find_child("InfoTitleLabel", true, false)
	if title_lbl:
		title_lbl.text = info_title
	
	var btn_row = vhs_info.find_child("InfoButtonRow", true, false)
	if btn_row:
		btn_row.modulate.a = 1.0
		btn_row.visible = true
	
	info_panel_style.bg_color = Color(0.02, 0.02, 0.02, 0.95)
	info_panel_style.border_color = Color(0.6, 0.0, 0.0, 0.95)
	info_panel.add_theme_stylebox_override("panel", info_panel_style)
	info_panel.modulate.a = 1.0
	
	if info_bg:
		info_bg.color = Color(0, 0, 0, 0.85)
	
	_update_vhs_button_prompts()
	
	var _launch = func():
		_play_ui_sfx("vhs_play")
		vhs_info.visible = false
		vhs_info.modulate.a = 1.0
		_set_cassettes_focus_enabled(true)
		emit_signal("difficulty_selected", difficulty)
	
	var play_btn = vhs_info.find_child("PlayTapeButton", true, false)
	if play_btn:
		var sig = play_btn.pressed
		for c in sig.get_connections():
			sig.disconnect(c.callable)
		play_btn.pressed.connect(_launch, CONNECT_ONE_SHOT)
		play_btn.grab_focus()

func _update_controls_legend():
	if not controls_legend_vbox: return
	for c in controls_legend_vbox.get_children():
		c.queue_free()

	if Input.get_connected_joypads().size() > 0 and is_gamepad_active:
		if is_playstation_controller():
			var ps_controls = [
				["L-STICK", "Move"],
				["L-STICK", "Sprint"],
				["TRIANGLE", "Flashlight"],
				["CROSS", "Interact / Grab"],
				["START", "Pause"],
			]
			for pair in ps_controls:
				_add_legend_row(pair[0], pair[1])
		else:
			var xbox_controls = [
				["L-STICK", "Move"],
				["L-STICK", "Sprint"],
				["Y", "Flashlight"],
				["A", "Interact / Grab"],
				["START", "Pause"],
			]
			for pair in xbox_controls:
				_add_legend_row(pair[0], pair[1])
	else:
		var kb_controls = [
			["WASD", "Move"],
			["SHIFT", "Sprint"],
			["F", "Flashlight"],
			["E", "Interact"],
			["G", "Grab"],
			["ESC", "Pause"],
		]
		for pair in kb_controls:
			_add_legend_row(pair[0], pair[1])

func _add_legend_row(key_text: String, action_text: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_prompt = PromptContainer.new()
	key_prompt.set_prompt("[%s]" % key_text)
	key_prompt.custom_minimum_size = Vector2(52, 0)
	row.add_child(key_prompt)
	var act_lbl = Label.new()
	act_lbl.text = action_text
	act_lbl.add_theme_font_size_override("font_size", 8)
	act_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	act_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(act_lbl)
	controls_legend_vbox.add_child(row)

func update_objective(current_pages, total_pages, current_gens = 0, total_gens = 0):
	if objective_label:
		if total_gens > 0:
			objective_label.text = "Pages: %d/%d\nPower: %d/%d" % [current_pages, total_pages, current_gens, total_gens]
			if current_pages >= total_pages and current_gens >= total_gens:
				objective_label.text = "Pages: %d/%d\nPower: %d/%d\nFIND THE EXIT" % [current_pages, total_pages, current_gens, total_gens]
				objective_label.add_theme_color_override("font_color", Color.GREEN)
			else:
				objective_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		else:
			objective_label.text = "Pages: %d/%d" % [current_pages, total_pages]
			if current_pages >= total_pages:
				objective_label.text = "Pages: %d/%d\nFIND THE EXIT" % [current_pages, total_pages]
				objective_label.add_theme_color_override("font_color", Color.GREEN)



func _input(event):
	# Detect last used input device
	var prev_gamepad_state = is_gamepad_active
	if event is InputEventJoypadButton:
		is_gamepad_active = true
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.3:
			is_gamepad_active = true
	elif event is InputEventKey or event is InputEventMouseButton:
		is_gamepad_active = false
	elif event is InputEventMouseMotion:
		if event.relative.length_squared() > 10.0:
			is_gamepad_active = false

	if prev_gamepad_state != is_gamepad_active:
		_update_vhs_button_prompts()

	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_control.visible = !debug_control.visible

	# Cassette Selection Overlay Inputs (Console Style)
	var vhs_info = start_screen.get_node_or_null("VHSInfoOverlay") if start_screen else null
	if vhs_info and vhs_info.visible:
		if event.is_action_pressed("ui_accept"):
			var play_btn = vhs_info.find_child("PlayTapeButton", true, false)
			if play_btn:
				play_btn.pressed.emit()
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("ui_cancel"):
			var eject_btn = vhs_info.find_child("EjectButton", true, false)
			if eject_btn:
				eject_btn.pressed.emit()
				get_viewport().set_input_as_handled()
				return

	if is_game_active:
		if event.is_action_pressed("pause"):
			toggle_pause()
		elif event.is_action_pressed("ui_cancel"):
			if is_paused:
				if pause_options.visible:
					_on_back_pressed()
				else:
					toggle_pause()
		# Map system input logic removed



func setup_pause_menu():
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	add_child(pause_menu)
	
	# Blur Shader Background
	var blur_bg = ColorRect.new()
	blur_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var blur_shader = Shader.new()
	blur_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
void fragment() {
	COLOR = textureLod(screen_texture, SCREEN_UV, blur_amount);
}
"""
	var blur_mat = ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur_bg.material = blur_mat
	pause_menu.add_child(blur_bg)
	
	# Vignette on top of blur
	var pause_vignette = TextureRect.new()
	pause_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad = Gradient.new()
	grad.set_offsets(PackedFloat32Array([0.4, 1.0]))
	grad.set_colors(PackedColorArray([Color(0.05, 0, 0, 0.2), Color(0, 0, 0, 0.9)]))
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	pause_vignette.texture = grad_tex
	pause_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.add_child(pause_vignette)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	# Styles for Panel Containers
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.01, 0.01, 0.01, 0.8)
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(0.5, 0.0, 0.0)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 24
	card_style.content_margin_right = 24
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	
	# --- MAIN PAUSE PANEL ---
	pause_main = PanelContainer.new()
	pause_main.add_theme_stylebox_override("panel", card_style)
	center.add_child(pause_main)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	pause_main.add_child(main_vbox)
	
	var title = Label.new()
	title.text = "- SURVEILLANCE PAUSED -"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0))
	main_vbox.add_child(title)
	
	pause_resume_btn = create_premium_button("RESUME SESSION", _on_resume_pressed, "Resume the active simulation.", "")
	main_vbox.add_child(pause_resume_btn)
	main_vbox.add_child(create_premium_button("SURVEILLANCE CONFIG", _on_options_pressed, "Configure video feed controls and audio settings.", ""))
	main_vbox.add_child(create_premium_button("RETURN TO MAIN MENU", _on_return_to_menu, "Abandon this run and return to the start screen.", ""))
	
	# Key instructions at the bottom of Main Pause Menu
	pause_prompts_lbl = PromptContainer.new()
	main_vbox.add_child(pause_prompts_lbl)
	
	# --- OPTIONS PANEL ---
	pause_options = PanelContainer.new()
	pause_options.add_theme_stylebox_override("panel", card_style)
	pause_options.visible = false
	center.add_child(pause_options)
	
	var opt_vbox = VBoxContainer.new()
	opt_vbox.add_theme_constant_override("separation", 10)
	pause_options.add_child(opt_vbox)
	
	var opt_title = Label.new()
	opt_title.text = "=== SURVEILLANCE FEED CONFIG ==="
	opt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opt_title.add_theme_font_size_override("font_size", 12)
	opt_title.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0))
	opt_vbox.add_child(opt_title)
	
	var layout = HBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	opt_vbox.add_child(layout)
	
	# Left Column: Settings list
	var settings_col = VBoxContainer.new()
	settings_col.add_theme_constant_override("separation", 8)
	layout.add_child(settings_col)
	
	# System Settings
	var sys_header = Label.new()
	sys_header.text = "--- FEED SETTINGS ---"
	sys_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sys_header.add_theme_font_size_override("font_size", 9)
	sys_header.add_theme_color_override("font_color", Color(0.65, 0.0, 0.0))
	settings_col.add_child(sys_header)
	
	# Display mode buttons
	var display_hbox = HBoxContainer.new()
	display_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	var disp_lbl = Label.new()
	disp_lbl.text = "DISPLAY:"
	disp_lbl.add_theme_font_size_override("font_size", 8)
	disp_lbl.custom_minimum_size = Vector2(52, 0)
	display_hbox.add_child(disp_lbl)
	
	var disp_impact = _make_impact_badge("low")
	display_hbox.add_child(disp_impact)
	
	var disp_val = _make_value_label("---")
	display_hbox.add_child(disp_val)
	
	options_first_btn = create_premium_button("WINDOWED", func(): 
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		disp_val.text = "WIN"
		disp_impact.text = "LOW"
		disp_impact.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	, "Switch to windowed mode.\n\nCURRENT: WIN\nCOST: LOW", "")
	options_first_btn.custom_minimum_size = Vector2(72, 24)
	var disp_btn_f = create_premium_button("FULLSCREEN", func(): 
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		disp_val.text = "FULL"
		disp_impact.text = "MED"
		disp_impact.add_theme_color_override("font_color", Color(0.8, 0.7, 0.1))
	, "Switch to fullscreen mode.\n\nCURRENT: FULL\nCOST: MED", "")
	options_first_btn.add_theme_font_size_override("font_size", 9)
	disp_btn_f.add_theme_font_size_override("font_size", 9)
	display_hbox.add_child(options_first_btn)
	display_hbox.add_child(disp_btn_f)
	settings_col.add_child(display_hbox)
	
	# Texture Style button
	var tex_hbox = HBoxContainer.new()
	tex_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	var tex_lbl = Label.new()
	tex_lbl.text = "TEXTURE STYLE:"
	tex_lbl.add_theme_font_size_override("font_size", 8)
	tex_lbl.custom_minimum_size = Vector2(80, 0)
	tex_hbox.add_child(tex_lbl)
	
	var tex_impact = _make_impact_badge("medium")
	tex_hbox.add_child(tex_impact)
	
	var tex_val = _make_value_label("PS1")
	tex_hbox.add_child(tex_val)
	
	btn_opt_texture_style = create_premium_button("TEXTURES", func():
		var level_gen = GameStateManager.level_generator
		if level_gen:
			match level_gen.texture_style:
				"ai_ps1":
					level_gen.texture_style = "ai_raw"
					tex_val.text = "RAW"
					tex_impact.text = "HIGH"
					tex_impact.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
				"ai_raw":
					level_gen.texture_style = "procedural"
					tex_val.text = "PROC"
					tex_impact.text = "LOW"
					tex_impact.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
				"procedural":
					level_gen.texture_style = "ai_ps1"
					tex_val.text = "PS1"
					tex_impact.text = "MED"
					tex_impact.add_theme_color_override("font_color", Color(0.8, 0.7, 0.1))
			level_gen.reload_textures()
	, "Cycle texture quality.\n\nCURRENT: PS1\nCOST: MED", "texture_style")
	btn_opt_texture_style.custom_minimum_size = Vector2(90, 24)
	btn_opt_texture_style.add_theme_font_size_override("font_size", 9)
	tex_hbox.add_child(btn_opt_texture_style)
	settings_col.add_child(tex_hbox)
	
	# Volume Slider
	var vol_hbox = HBoxContainer.new()
	vol_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	var vol_lbl = Label.new()
	vol_lbl.text = "FEED VOLUME:"
	vol_lbl.add_theme_font_size_override("font_size", 8)
	vol_lbl.custom_minimum_size = Vector2(80, 0)
	vol_hbox.add_child(vol_lbl)
	
	vol_hbox.add_child(_make_impact_badge("---"))
	
	var vol_val = _make_value_label("100%")
	vol_hbox.add_child(vol_val)
	
	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	var master_bus = AudioServer.get_bus_index("Master")
	vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus))
	vol_slider.custom_minimum_size = Vector2(110, 16)
	vol_slider.value_changed.connect(func(val):
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(val))
		AudioServer.set_bus_mute(master_bus, val <= 0.001)
		vol_val.text = str(int(val * 100)) + "%"
		_play_ui_sfx("hover")
	)
	vol_slider.mouse_entered.connect(func(): vol_slider.grab_focus())
	vol_slider.focus_entered.connect(func():
		_play_ui_sfx("hover")
		_on_option_hovered("Adjust master feedback volume.\n\nCURRENT: " + vol_val.text + "\nCOST: NONE", "")
	)
	vol_hbox.add_child(vol_slider)
	settings_col.add_child(vol_hbox)
	
	# Look Sensitivity Slider
	var sens_hbox = HBoxContainer.new()
	sens_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	var sens_lbl = Label.new()
	sens_lbl.text = "CAMERA SENS:"
	sens_lbl.add_theme_font_size_override("font_size", 8)
	sens_lbl.custom_minimum_size = Vector2(80, 0)
	sens_hbox.add_child(sens_lbl)
	
	sens_hbox.add_child(_make_impact_badge("---"))
	
	var sens_val = _make_value_label("0.003")
	sens_hbox.add_child(sens_val)
	
	var sens_slider = HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.008
	sens_slider.step = 0.0005
	var p_node = get_tree().get_first_node_in_group("player")
	sens_slider.value = p_node.mouse_sensitivity if p_node else 0.003
	sens_slider.custom_minimum_size = Vector2(110, 16)
	sens_slider.value_changed.connect(func(val):
		set_player_sensitivity(val)
		sens_val.text = str(val)
		_play_ui_sfx("hover")
	)
	sens_slider.mouse_entered.connect(func(): sens_slider.grab_focus())
	sens_slider.focus_entered.connect(func():
		_play_ui_sfx("hover")
		_on_option_hovered("Adjust camera look sensitivity.\n\nCURRENT: " + sens_val.text + "\nCOST: NONE", "")
	)
	sens_hbox.add_child(sens_slider)
	settings_col.add_child(sens_hbox)
	
	# Framerate Limit Slider
	var fps_hbox = HBoxContainer.new()
	fps_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	var fps_lbl = Label.new()
	fps_lbl.text = "FRAMERATE:"
	fps_lbl.add_theme_font_size_override("font_size", 8)
	fps_lbl.custom_minimum_size = Vector2(80, 0)
	fps_hbox.add_child(fps_lbl)
	
	var fps_impact = _make_impact_badge("low")
	fps_hbox.add_child(fps_impact)
	
	var fps_val = _make_value_label(str(Engine.max_fps) + " FPS")
	fps_hbox.add_child(fps_val)
	
	var _update_fps_impact := func(val: float):
		fps_val.text = str(int(val)) + " FPS"
		if val <= 25:
			fps_impact.text = "LOW"
			fps_impact.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		elif val <= 40:
			fps_impact.text = "MED"
			fps_impact.add_theme_color_override("font_color", Color(0.8, 0.7, 0.1))
		else:
			fps_impact.text = "HIGH"
			fps_impact.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	
	_update_fps_impact.call(Engine.max_fps)
	
	var fps_slider = HSlider.new()
	fps_slider.min_value = 10
	fps_slider.max_value = 60
	fps_slider.step = 5
	fps_slider.value = Engine.max_fps
	fps_slider.custom_minimum_size = Vector2(110, 16)
	fps_slider.value_changed.connect(func(val):
		Engine.max_fps = val
		_update_fps_impact.call(val)
		_play_ui_sfx("hover")
	)
	fps_slider.mouse_entered.connect(func(): fps_slider.grab_focus())
	fps_slider.focus_entered.connect(func():
		_play_ui_sfx("hover")
		_on_option_hovered("Adjust camera feed framerate for authentic PS1 feel. Lower = more retro.\n\nCURRENT: " + fps_val.text + "\nCOST: " + fps_impact.text, "fps")
	)
	fps_hbox.add_child(fps_slider)
	settings_col.add_child(fps_hbox)
	


	# Accessibility Settings
	var access_lbl = Label.new()
	access_lbl.text = "--- ACCESSIBILITY ---"
	access_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	access_lbl.add_theme_font_size_override("font_size", 8)
	access_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	settings_col.add_child(access_lbl)

	var access_hbox = HBoxContainer.new()
	access_hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
	var rim_lbl = Label.new()
	rim_lbl.text = "ENEMY RIM GLOW: "
	rim_lbl.add_theme_font_size_override("font_size", 8)
	access_hbox.add_child(rim_lbl)

	var btn_rim = create_premium_button("TOGGLE GLOW", func():
		var enemy = get_tree().get_first_node_in_group("enemy")
		if enemy and enemy.has_method("toggle_rim_glow"):
			enemy.toggle_rim_glow()
	, "Toggle a white rim glow around the stalker to make them highly visible in pitch darkness.", "rim_glow")
	btn_rim.custom_minimum_size = Vector2(120, 24)
	btn_rim.add_theme_font_size_override("font_size", 9)
	access_hbox.add_child(btn_rim)
	settings_col.add_child(access_hbox)
		
	var space = Control.new()
	space.custom_minimum_size = Vector2(0, 10)
	settings_col.add_child(space)

	
	var btn_back = create_premium_button("SAVE & BACK", _on_back_pressed, "Return to main pause menu.", "")
	btn_back.custom_minimum_size = Vector2(220, 28)
	settings_col.add_child(btn_back)
	
	# Right Column: Visual Preview Panel
	var preview_col = VBoxContainer.new()
	preview_col.custom_minimum_size = Vector2(180, 250)
	preview_col.add_theme_constant_override("separation", 8)
	preview_col.alignment = VBoxContainer.ALIGNMENT_CENTER
	layout.add_child(preview_col)
	
	var preview_title = Label.new()
	preview_title.text = "[ LIVE FEED MONITOR ]"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 8)
	preview_title.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0))
	preview_col.add_child(preview_title)
	
	options_preview_rect = TextureRect.new()
	options_preview_rect.texture = null
	options_preview_rect.custom_minimum_size = Vector2(160, 130)
	options_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	options_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	options_preview_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_col.add_child(options_preview_rect)
	
	preview_material = ShaderMaterial.new()
	preview_material.shader = preload("res://shaders/bad_stream.gdshader")
	preview_material.set_shader_parameter("noise_rate", 24.0)
	preview_material.set_shader_parameter("jitter_amount", 0.0)
	preview_material.set_shader_parameter("luma_flicker", 0.0)
	preview_material.set_shader_parameter("static_intensity", 0.0)
	preview_material.set_shader_parameter("scanline_intensity", 0.0)
	options_preview_rect.material = preview_material

	# Description Box
	var preview_desc_panel = PanelContainer.new()
	var preview_desc_style = StyleBoxFlat.new()
	preview_desc_style.bg_color = Color(0, 0, 0, 0.6)
	preview_desc_style.border_width_left = 1
	preview_desc_style.border_width_top = 1
	preview_desc_style.border_width_right = 1
	preview_desc_style.border_width_bottom = 1
	preview_desc_style.border_color = Color(0.2, 0.0, 0.0)
	preview_desc_style.corner_radius_top_left = 3
	preview_desc_style.corner_radius_top_right = 3
	preview_desc_style.corner_radius_bottom_left = 3
	preview_desc_style.corner_radius_bottom_right = 3
	preview_desc_style.content_margin_left = 8
	preview_desc_style.content_margin_right = 8
	preview_desc_style.content_margin_top = 6
	preview_desc_style.content_margin_bottom = 6
	preview_desc_panel.add_theme_stylebox_override("panel", preview_desc_style)
	preview_col.add_child(preview_desc_panel)
	
	desc_label = Label.new()
	desc_label.text = "Hover over any setting to view feed simulation diagnostics."
	desc_label.custom_minimum_size = Vector2(160, 60)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	preview_desc_panel.add_child(desc_label)
	
	# Performance impact line (updated on hover)
	impact_label = Label.new()
	impact_label.text = ""
	impact_label.custom_minimum_size = Vector2(160, 12)
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact_label.add_theme_font_size_override("font_size", 7)
	impact_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	preview_desc_panel.add_child(impact_label)
	
	# Current value line (updated on hover)
	value_label = Label.new()
	value_label.text = ""
	value_label.custom_minimum_size = Vector2(160, 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 7)
	value_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	preview_desc_panel.add_child(value_label)
	
	# Key instructions at the bottom of Options Panel
	options_prompts_lbl = PromptContainer.new()
	opt_vbox.add_child(options_prompts_lbl)



func _make_impact_badge(level: String) -> Label:
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.custom_minimum_size = Vector2(58, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match level:
		"low":
			lbl.text = "LOW"
			lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		"medium":
			lbl.text = "MED"
			lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.1))
		"high":
			lbl.text = "HIGH"
			lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		_:
			lbl.text = "---"
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	return lbl

func _make_value_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size = Vector2(48, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return lbl


func create_premium_button(text: String, callback: Callable, hover_text: String = "", preview_effect: String = "") -> Button:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	btn.custom_minimum_size = Vector2(220, 32)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.02, 0.02, 0.02, 0.75)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.5, 0.0, 0.0)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	style_normal.content_margin_top = 6
	style_normal.content_margin_bottom = 6
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.18, 0.0, 0.0, 0.8)
	style_hover.border_color = Color(0.9, 0.1, 0.1)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.3, 0.0, 0.0, 0.9)
	style_pressed.border_color = Color(1.0, 0.3, 0.3)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)
	
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.5, 0.5))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", 11)
	
	# Connect signals for animation and sound
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
	
	btn.mouse_entered.connect(func():
		btn.grab_focus()
	)
	
	btn.focus_entered.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_play_ui_sfx("hover")
		if hover_text != "":
			_on_option_hovered(hover_text, preview_effect)
	)
	
	btn.focus_exited.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	
	btn.pressed.connect(func():
		_play_ui_sfx("click")
	)
	
	return btn

func _play_ui_sfx(type: String):
	var path = ""
	var volume = -10.0
	var pitch = randf_range(0.9, 1.1)
	
	if type == "click":
		path = "res://sfx/ui_click.mp3"
		volume = -5.0
	elif type == "hover":
		path = "res://sfx/ui_hover.mp3"
		volume = -12.0 # Louder and more audible hover sound
	elif type == "vhs_play":
		path = "res://sfx/vhs_play.mp3"
		volume = 0.0
		pitch = 1.0
	elif type == "vhs_eject":
		path = "res://sfx/vhs_eject.mp3"
		volume = 0.0
		pitch = 1.0
		
	if path != "" and FileAccess.file_exists(path):
		var sfx = AudioStreamPlayer.new()
		sfx.stream = load(path)
		sfx.volume_db = volume
		sfx.pitch_scale = pitch
		sfx.bus = "Master"
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

func _on_option_hovered(description: String, effect: String):
	# Parse out embeded CURRENT / COST lines for the impact/value display
	var clean_desc = description
	var current_val = ""
	var cost_val = ""
	var lines = description.split("\n")
	if lines.size() >= 3 and lines[lines.size()-2].begins_with("CURRENT:"):
		current_val = lines[lines.size()-2].trim_prefix("CURRENT:").strip_edges()
		cost_val = lines[lines.size()-1].trim_prefix("COST:").strip_edges()
		clean_desc = ""
		for i in range(lines.size()-2):
			if i > 0: clean_desc += "\n"
			clean_desc += lines[i]
	
	if desc_label:
		desc_label.text = clean_desc
	if start_desc_label:
		start_desc_label.text = clean_desc
	
	if impact_label:
		if cost_val != "":
			impact_label.text = "PERFORMANCE COST: " + cost_val
			match cost_val.to_lower():
				"low":
					impact_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
				"medium", "med":
					impact_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.1))
				"high":
					impact_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
				_:
					impact_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			impact_label.text = ""
	
	if value_label:
		value_label.text = ("VALUE: " + current_val) if current_val != "" else ""
		
	if not preview_material: return
	
	# Reset all to clean default first
	preview_material.set_shader_parameter("jitter_amount", 0.0)
	preview_material.set_shader_parameter("luma_flicker", 0.0)
	preview_material.set_shader_parameter("static_intensity", 0.0)
	preview_material.set_shader_parameter("scanline_intensity", 0.0)
	preview_material.set_shader_parameter("noise_rate", 24.0)
	
	match effect:
		"jitter":
			preview_material.set_shader_parameter("jitter_amount", 0.02)
			preview_material.set_shader_parameter("static_intensity", 0.08)
		"flicker":
			preview_material.set_shader_parameter("luma_flicker", 0.25)
			preview_material.set_shader_parameter("static_intensity", 0.08)
		"static":
			preview_material.set_shader_parameter("static_intensity", 0.35)
		"scanlines":
			preview_material.set_shader_parameter("scanline_intensity", 0.6)
		"fps":
			preview_material.set_shader_parameter("noise_rate", 12.0)
			preview_material.set_shader_parameter("jitter_amount", 0.005)
			preview_material.set_shader_parameter("static_intensity", 0.08)
		"full_filter":
			preview_material.set_shader_parameter("jitter_amount", 0.003)
			preview_material.set_shader_parameter("luma_flicker", 0.05)
			preview_material.set_shader_parameter("static_intensity", 0.08)
			preview_material.set_shader_parameter("scanline_intensity", 0.15)
			preview_material.set_shader_parameter("noise_rate", 24.0)
		_:
			# Clean
			pass




func show_loading(text: String = "PLEASE STAND BY..."):
	if not loading_screen: return
	if loading_label:
		loading_label.text = text.to_upper()
	loading_screen.modulate.a = 1.0
	loading_screen.visible = true

func hide_loading():
	if not loading_screen or not loading_screen.visible: return
	# Smooth fade-out
	var tween = get_tree().create_tween()
	tween.tween_property(loading_screen, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): loading_screen.visible = false)

func show_notification(text: String):
	if not notification_container or not notification_container.is_inside_tree():
		return
		
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10) # Low-res PSX look
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1)) # Warm Warning Yellow
	
	notification_container.add_child(label)
	
	var tween = create_tween()
	# Slow fade out over 4 seconds
	tween.tween_property(label, "modulate:a", 0.0, 4.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(label.queue_free)

func _on_generator_interaction_held():
	show_notification("HOLD TO RESTART GENERATOR")

func show_victory():
	is_game_active = false
	hud.hide()
	start_screen.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_focus_first_cassette()
	
	# Update subtitle tagline to show Victory!
	var subtitle = start_screen.find_child("SubtitleLabel", true, false)
	if subtitle:
		subtitle.text = "★  TAPE RECOVERED — YOU ESCAPED — SELECT ANOTHER TAPE  ★"
		subtitle.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
		subtitle.add_theme_font_size_override("font_size", 10)

func show_game_over():
	is_game_active = false
	hud.hide()
	if game_over_screen:
		game_over_screen.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if game_over_retry_btn:
		game_over_retry_btn.grab_focus()

func setup_game_over_screen():
	# --- GAME OVER SCREEN ---
	game_over_screen = Control.new()
	game_over_screen.name = "GameOverScreen"
	game_over_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_screen.visible = false
	add_child(game_over_screen)

	# Fullscreen black background with opacity (so we see the corrupted frame behind)
	var go_bg = ColorRect.new()
	go_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	go_bg.color = Color(0.02, 0.0, 0.0, 0.95)
	go_bg.mouse_filter = Control.MOUSE_FILTER_STOP # Blocks clicking through to main menu
	game_over_screen.add_child(go_bg)

	# Glitch Scanline Overlay for Game Over
	var go_scanline = ColorRect.new()
	go_scanline.set_anchors_preset(Control.PRESET_FULL_RECT)
	go_scanline.color = Color(0.0, 0.0, 0.0, 0.05)
	go_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_screen.add_child(go_scanline)

	var go_center = CenterContainer.new()
	go_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_screen.add_child(go_center)

	var go_vbox = VBoxContainer.new()
	go_vbox.add_theme_constant_override("separation", 18)
	go_center.add_child(go_vbox)

	var go_title = Label.new()
	go_title.text = "✖  TAPE CORRUPTED  ✖\nSUBJECT ELIMINATED"
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_title.add_theme_color_override("font_color", Color(0.85, 0.0, 0.0))
	go_title.add_theme_font_size_override("font_size", 18)
	go_vbox.add_child(go_title)

	var go_sub = Label.new()
	go_sub.text = "CAMERA FEED LOST // ERROR CODE: 0x800F020B"
	go_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	go_sub.add_theme_font_size_override("font_size", 9)
	go_vbox.add_child(go_sub)

	var go_space = Control.new()
	go_space.custom_minimum_size = Vector2(0, 15)
	go_vbox.add_child(go_space)

	# Buttons
	game_over_retry_btn = create_premium_button("RETRY TAPE", func():
		_on_game_over_retry()
	, "Restart the current tape with the same difficulty.", "")
	game_over_retry_btn.custom_minimum_size = Vector2(200, 32)
	go_vbox.add_child(game_over_retry_btn)

	game_over_menu_btn = create_premium_button("RETURN TO SHELF", func():
		_on_game_over_return_to_menu()
	, "Eject the current tape and return to the main selection shelf.", "")
	game_over_menu_btn.custom_minimum_size = Vector2(200, 32)
	go_vbox.add_child(game_over_menu_btn)

func _on_game_over_retry():
	if game_over_screen:
		game_over_screen.visible = false
	# Re-emit difficulty selected to start a new run with the same difficulty
	emit_signal("difficulty_selected", current_difficulty)

func _on_game_over_return_to_menu():
	if game_over_screen:
		game_over_screen.visible = false
	_on_return_to_menu()






func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused

	var player = GameStateManager.player

	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pause_main.visible = true
		pause_options.visible = false
		if pause_resume_btn:
			pause_resume_btn.grab_focus()
		AudioManager.ambient_player.play()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		AudioManager.ambient_player.stop()

func _on_resume_pressed():
	toggle_pause()

func _on_quit_pressed():
	get_tree().quit()

func _on_return_to_menu():
	# Close pause, then call scene reset back to menu
	is_paused = false
	get_tree().paused = false
	pause_menu.visible = false
	is_game_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.visible = false
	AudioManager.ambient_player.stop()
	if AudioManager.ambient_stream:
		AudioManager.ambient_player.stream = AudioManager.ambient_stream
	AudioManager.ambient_player.play()
	var level_gen = GameStateManager.level_generator
	if level_gen:
		var player = GameStateManager.player
		if player:
			player.process_mode = Node.PROCESS_MODE_DISABLED
			player.visible = false
		var main = level_gen.get_parent()
		if main:
			var enemy = main.get_node_or_null("Enemy")
			if enemy:
				enemy.queue_free()
		show_loading("RETURNING TO BASE...")
		level_gen.cleanup_level()
		GameStateManager.reset()
		hide_loading()
	start_screen.show()
	_focus_first_cassette()


func _focus_first_cassette():
	# Re-focus the first cassette button so gamepad/keyboard works on the menu
	if not start_screen:
		return
	var shelf_hbox = start_screen.find_child("HBoxContainer", true, false)
	if shelf_hbox and shelf_hbox.get_child_count() > 0:
		var first_cassette = shelf_hbox.get_child(0)
		if first_cassette:
			var first_btn = first_cassette.find_child("CassetteButton", true, false)
			if first_btn:
				first_btn.grab_focus()

func _set_cassettes_focus_enabled(enabled: bool):
	if not start_screen: return
	var shelf_hbox = start_screen.find_child("HBoxContainer", true, false)
	if shelf_hbox:
		for cassette in shelf_hbox.get_children():
			var btn = cassette.find_child("CassetteButton", true, false)
			if btn:
				btn.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _update_vhs_button_prompts():
	var vhs_info = start_screen.get_node_or_null("VHSInfoOverlay") if start_screen else null
	if not vhs_info or not vhs_info.visible: return
	
	var play_btn = vhs_info.find_child("PlayTapeButton", true, false)
	var eject_btn = vhs_info.find_child("EjectButton", true, false)
	
	if play_btn:
		if Input.get_connected_joypads().size() > 0 and is_gamepad_active:
			if is_playstation_controller():
				play_btn.text = "[✖] PLAY TAPE"
			else:
				play_btn.text = "[A] PLAY TAPE"
		else:
			play_btn.text = "[ENTER] PLAY TAPE"
			
	if eject_btn:
		if Input.get_connected_joypads().size() > 0 and is_gamepad_active:
			if is_playstation_controller():
				eject_btn.text = "[●] EJECT"
			else:
				eject_btn.text = "[B] EJECT"
		else:
			eject_btn.text = "[ESC] EJECT"

func _on_options_pressed():
	pause_main.visible = false
	pause_options.visible = true
	if options_first_btn:
		options_first_btn.grab_focus()

func _on_back_pressed():
	pause_options.visible = false
	pause_main.visible = true
	if pause_resume_btn:
		pause_resume_btn.grab_focus()





func is_playstation_controller() -> bool:
	var joypads = Input.get_connected_joypads()
	if joypads.size() > 0:
		var joy_name = Input.get_joy_name(joypads[0]).to_lower()
		if "sony" in joy_name or "playstation" in joy_name or "ps" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name:
			return true
	return false

func _get_input_prompts() -> String:
	var gp_connected = Input.get_connected_joypads().size() > 0
	if gp_connected and is_gamepad_active:
		if is_playstation_controller():
			return "[L-STICK]/[D-PAD]: Navigate | [L-STICK]: Move | [R-STICK]: Look | [TRIANGLE]: Light | [CROSS]: Action/Select | [SHARE]: Radar"
		else:
			return "[L-STICK]/[D-PAD]: Navigate | [L-STICK]: Move | [R-STICK]: Look | [Y]: Light | [A]: Action/Select | [BACK]: Radar"
	else:
		return "[ARROW KEYS]: Navigate | [WASD]: Move | [MOUSE]: Look | [F]: Light | [E]: Action | [TAB]: Radar | [ENTER]: Select"

func _update_menu_prompts():
	var gp_connected = Input.get_connected_joypads().size() > 0
	var is_ps = is_playstation_controller()
	
	# Pause Main Menu prompts
	if pause_prompts_lbl:
		var target_text = ""
		if gp_connected and is_gamepad_active:
			if is_ps:
				target_text = "[D-PAD]: Navigate | [CROSS]: Select | [CIRCLE]: Resume"
			else:
				target_text = "[D-PAD]: Navigate | [A]: Select | [B]: Resume"
		else:
			target_text = "[W]/[S]/[UP]/[DOWN]: Navigate | [ENTER]: Select | [ESC]: Resume"
		pause_prompts_lbl.set_prompt(target_text)
			
	# Pause Options Menu prompts
	if options_prompts_lbl:
		var target_text = ""
		if gp_connected and is_gamepad_active:
			if is_ps:
				target_text = "[D-PAD]: Navigate | [DPAD_LR]: Adjust Sliders | [CROSS]: Select/Toggle | [CIRCLE]: Save & Back"
			else:
				target_text = "[D-PAD]: Navigate | [DPAD_LR]: Adjust Sliders | [A]: Select/Toggle | [B]: Save & Back"
		else:
			target_text = "[W]/[S]/[UP]/[DOWN]: Navigate | [A]/[D]/[LEFT]/[RIGHT]: Adjust Sliders | [ENTER]: Select/Toggle | [ESC]: Save & Back"
		options_prompts_lbl.set_prompt(target_text)


class PromptContainer extends HBoxContainer:
	var text = ""
	
	func _ready():
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	func set_prompt(t: String):
		if text == t: return
		text = t
		
		# Clear existing
		for child in get_children():
			child.queue_free()
			
		var idx = 0
		while idx < t.length():
			var open_bracket = t.find("[", idx)
			if open_bracket == -1:
				_add_text_label(t.substr(idx))
				break
				
			if open_bracket > idx:
				_add_text_label(t.substr(idx, open_bracket - idx))
				
			var close_bracket = t.find("]", open_bracket)
			if close_bracket == -1:
				_add_text_label(t.substr(open_bracket))
				break
				
			var tag = t.substr(open_bracket + 1, close_bracket - open_bracket - 1)
			_add_icon(tag)
			idx = close_bracket + 1
			
	func _add_text_label(t: String):
		if t.is_empty(): return
		var lbl = Label.new()
		lbl.text = t
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		add_child(lbl)
		
	func _add_icon(tag: String):
		var icon = VectorInputIcon.new()
		icon.tag = tag
		add_child(icon)


class VectorInputIcon extends Control:
	var tag = ""
	
	func _ready():
		var w = 22.0
		if tag.length() > 1:
			w = 18.0 + (tag.length() * 6.0)
		custom_minimum_size = Vector2(w, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	func _draw():
		var s = get_size()
		var center = s / 2.0
		var r = 8.0
		
		var is_gp_button = tag in ["A", "B", "X", "Y", "CROSS", "CIRCLE", "SQUARE", "TRIANGLE", "L-STICK", "R-STICK", "D-PAD", "DPAD_LR", "BACK", "START", "SHARE", "OPTIONS"]
		
		if is_gp_button:
			var base_col = Color(0.15, 0.15, 0.15)
			
			# Determine colors and symbols
			var symbol_col = Color.WHITE
			var symbol_text = ""
			var is_playstation_shape = false
			
			match tag:
				"A":
					symbol_col = Color(0.1, 0.8, 0.1)
					symbol_text = "A"
				"B":
					symbol_col = Color(0.9, 0.1, 0.1)
					symbol_text = "B"
				"X":
					symbol_col = Color(0.1, 0.5, 0.9)
					symbol_text = "X"
				"Y":
					symbol_col = Color(0.9, 0.8, 0.0)
					symbol_text = "Y"
				"CROSS":
					symbol_col = Color(0.35, 0.45, 0.9)
					is_playstation_shape = true
				"CIRCLE":
					symbol_col = Color(0.9, 0.1, 0.1)
					is_playstation_shape = true
				"SQUARE":
					symbol_col = Color(0.85, 0.35, 0.75)
					is_playstation_shape = true
				"TRIANGLE":
					symbol_col = Color(0.1, 0.8, 0.1)
					is_playstation_shape = true
				"L-STICK", "R-STICK":
					draw_circle(center, r, base_col)
					draw_circle(center, r, Color(0.4, 0.4, 0.4), false, 1.0)
					draw_circle(center, r - 3, Color(0.6, 0.6, 0.6), true)
					_draw_centered_text(tag.substr(0, 1), center, Color.WHITE, 8)
					return
				"D-PAD", "DPAD_LR":
					var w = 3.0
					var l = 6.0
					draw_rect(Rect2(center.x - w/2.0, center.y - l, w, l*2.0), Color(0.4, 0.4, 0.4))
					draw_rect(Rect2(center.x - l, center.y - w/2.0, l*2.0, w), Color(0.4, 0.4, 0.4))
					if tag == "DPAD_LR":
						draw_line(Vector2(center.x - l + 1, center.y), Vector2(center.x - l + 3, center.y - 2), Color.WHITE, 1.0)
						draw_line(Vector2(center.x - l + 1, center.y), Vector2(center.x - l + 3, center.y + 2), Color.WHITE, 1.0)
						draw_line(Vector2(center.x + l - 1, center.y), Vector2(center.x + l - 3, center.y - 2), Color.WHITE, 1.0)
						draw_line(Vector2(center.x + l - 1, center.y), Vector2(center.x + l - 3, center.y + 2), Color.WHITE, 1.0)
					return
				"BACK", "SHARE", "SELECT":
					var rect = Rect2(center.x - 6.0, center.y - 4.0, 12.0, 8.0)
					draw_style_box(_get_sb(Color(0.4, 0.4, 0.4)), rect)
					draw_rect(Rect2(center.x - 3, center.y - 2, 2, 2), Color.WHITE)
					draw_rect(Rect2(center.x + 1, center.y - 2, 2, 2), Color.WHITE)
					return
				"START", "OPTIONS":
					var rect = Rect2(center.x - 6.0, center.y - 4.0, 12.0, 8.0)
					draw_style_box(_get_sb(Color(0.4, 0.4, 0.4)), rect)
					draw_line(Vector2(center.x - 3, center.y - 2), Vector2(center.x + 3, center.y - 2), Color.WHITE, 1.0)
					draw_line(Vector2(center.x - 3, center.y), Vector2(center.x + 3, center.y), Color.WHITE, 1.0)
					draw_line(Vector2(center.x - 3, center.y + 2), Vector2(center.x + 3, center.y + 2), Color.WHITE, 1.0)
					return
			
			draw_circle(center, r, base_col)
			draw_circle(center, r, symbol_col, false, 1.0)
			
			if is_playstation_shape:
				_draw_ps_shape(tag, center, symbol_col)
			else:
				_draw_centered_text(symbol_text, center, symbol_col, 9)
		else:
			# Draw Keyboard keycap
			var rect = Rect2(1.0, 1.0, s.x - 2.0, s.y - 2.0)
			var bg_style = StyleBoxFlat.new()
			bg_style.bg_color = Color(0.18, 0.18, 0.18)
			bg_style.border_width_left = 1
			bg_style.border_width_top = 1
			bg_style.border_width_right = 1
			bg_style.border_width_bottom = 2
			bg_style.border_color = Color(0.5, 0.5, 0.5)
			bg_style.corner_radius_top_left = 2
			bg_style.corner_radius_top_right = 2
			bg_style.corner_radius_bottom_left = 2
			bg_style.corner_radius_bottom_right = 2
			draw_style_box(bg_style, rect)
			_draw_centered_text(tag, center + Vector2(0, -1), Color(0.9, 0.9, 0.9), 8)
			
	func _draw_ps_shape(type: String, center: Vector2, col: Color):
		match type:
			"CROSS":
				var cross_size = 3.0
				draw_line(center - Vector2(cross_size, cross_size), center + Vector2(cross_size, cross_size), col, 1.5)
				draw_line(center - Vector2(cross_size, -cross_size), center + Vector2(cross_size, -cross_size), col, 1.5)
			"CIRCLE":
				draw_circle(center, 3.5, col, false, 1.5)
			"SQUARE":
				draw_rect(Rect2(center.x - 3, center.y - 3, 6, 6), col, false, 1.5)
			"TRIANGLE":
				var p1 = center + Vector2(0, -4.5)
				var p2 = center + Vector2(-4, 3)
				var p3 = center + Vector2(4, 3)
				draw_line(p1, p2, col, 1.5)
				draw_line(p2, p3, col, 1.5)
				draw_line(p3, p1, col, 1.5)
				
	func _draw_centered_text(t: String, pos: Vector2, col: Color, font_sz: int):
		var font = ThemeDB.fallback_font
		if font:
			var text_size = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz)
			var draw_pos = Vector2(pos.x - text_size.x / 2.0, pos.y + font_sz * 0.3)
			draw_string(font, draw_pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, col)
			
	func _get_sb(border_col: Color) -> StyleBoxFlat:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.15)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = border_col
		sb.corner_radius_top_left = 2
		sb.corner_radius_top_right = 2
		sb.corner_radius_bottom_left = 2
		sb.corner_radius_bottom_right = 2
		return sb


# ==========================================
# CUSTOM DRAWING & ANIMATION CLASSES FOR HUD
# ==========================================

class ViewfinderFrame extends Control:
	func _ready():
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	func _draw():
		var s = get_size()
		var pad = 25.0
		var seg_len = 40.0
		var thickness = 2.0
		var col = Color(1.0, 1.0, 1.0, 0.35) # Retro camera HUD white
		
		# Top Left
		draw_rect(Rect2(pad, pad, seg_len, thickness), col)
		draw_rect(Rect2(pad, pad, thickness, seg_len), col)
		
		# Top Right
		draw_rect(Rect2(s.x - pad - seg_len, pad, seg_len, thickness), col)
		draw_rect(Rect2(s.x - pad - thickness, pad, thickness, seg_len), col)
		
		# Bottom Left
		draw_rect(Rect2(pad, s.y - pad - thickness, seg_len, thickness), col)
		draw_rect(Rect2(pad, s.y - pad - seg_len, thickness, seg_len), col)
		
		# Bottom Right
		draw_rect(Rect2(s.x - pad - seg_len, s.y - pad - thickness, seg_len, thickness), col)
		draw_rect(Rect2(s.x - pad - thickness, s.y - pad - seg_len, thickness, seg_len), col)

class HUD_StaminaHeart extends Label:
	var stamina = 100.0
	
	func _ready():
		text = "♥"
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_theme_font_size_override("font_size", 20)
		add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		pivot_offset = size / 2.0
		resized.connect(func(): pivot_offset = size / 2.0)
		
	func _process(_delta):
		var beat_freq = 1.0
		if stamina > 60.0:
			beat_freq = 1.0
		elif stamina > 25.0:
			beat_freq = 2.0
		else:
			beat_freq = 4.0
			
		var scale_val = 1.0 + sin(Time.get_ticks_msec() * 0.006 * beat_freq) * 0.2
		scale = Vector2(scale_val, scale_val)
