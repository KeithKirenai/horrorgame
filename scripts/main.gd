extends Node3D

const LevelGenerator = preload("res://scripts/level_generator.gd")
const UIManager = preload("res://scripts/ui_manager.gd")
const PlayerScene = preload("res://player.tscn")
const VHSShader = preload("res://shaders/bad_stream.gdshader")
const EnemyScene = preload("res://enemy.tscn")

var vhs_material: ShaderMaterial

var _ui: UIManager
var _level_gen: LevelGenerator
var _player: Node3D

func _ready():
	randomize()

	InputManager.setup_gamepad_inputs()
	setup_environment()
	setup_post_processing()

	_ui = UIManager.new()
	_ui.name = "UIManager"
	add_child(_ui)
	_ui.vhs_material_ref = vhs_material
	GameStateManager.ui_manager = _ui
	_ui.log_debug("Game Starting...")

	_level_gen = LevelGenerator.new()
	_level_gen.name = "LevelGenerator"
	add_child(_level_gen)
	GameStateManager.level_generator = _level_gen
	_level_gen.level_generated.connect(_on_level_generated)

	_player = PlayerScene.instantiate()
	_player.name = "Player"
	add_child(_player)
	GameStateManager.player = _player
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.visible = false

	_ui.game_started.connect(_on_game_started)
	_ui.difficulty_selected.connect(_on_difficulty_selected)

	GameStateManager.game_over_requested.connect(game_over)
	GameStateManager.win_game_requested.connect(win_game)
	GameStateManager.generator_activated.connect(_on_generator_activated)
	GameStateManager.generator_deactivated.connect(_on_generator_deactivated)
	GameStateManager.exit_unlock_ready.connect(check_exit_unlock)

	_ui.hide_loading()

func _play_sfx(path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not FileAccess.file_exists(path): return
	var p = AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _on_difficulty_selected(difficulty_name: String):
	var level_gen = _level_gen
	var ui = _ui
	var player = _player

	ui.log_debug("Tape Selected: " + difficulty_name.to_upper())

	match difficulty_name:
		"easy":
			level_gen.MAZE_WIDTH = 4
			level_gen.MAZE_DEPTH = 4
		"normal":
			level_gen.MAZE_WIDTH = 8
			level_gen.MAZE_DEPTH = 8
		"hard":
			level_gen.MAZE_WIDTH = 12
			level_gen.MAZE_DEPTH = 12
		_:
			level_gen.MAZE_WIDTH = 8
			level_gen.MAZE_DEPTH = 8

	AudioManager.set_theme()

	level_gen.cleanup_level()
	GameStateManager.reset()

	ui.log_debug("Generating " + str(level_gen.MAZE_WIDTH) + "x" + str(level_gen.MAZE_DEPTH) + " level...")
	ui.show_loading("BAKING LEVEL GEOMETRY...")
	level_gen.generate_level()

	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.position = level_gen.get_start_position()
	player.rotation.y = level_gen.get_start_rotation()
	player.camera.make_current()

	ui.is_game_active = true
	ui.start_screen.hide()
	ui.hud.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.game_started.emit()
	get_tree().paused = false

func _on_level_generated():
	var ui = _ui
	var level_gen = _level_gen

	ui.log_debug("Level Generation Complete")
	ui.hide_loading()

	if ui.is_game_active:
		var pages = get_tree().get_nodes_in_group("pages")
		for p in pages:
			p.page_collected.connect(_on_page_collected)

		ui.update_objective(0, GameStateManager.TOTAL_PAGES, 0, GameStateManager.TOTAL_GENERATORS)

		_spawn_enemy(level_gen)

func _spawn_enemy(level_gen):
	var old = get_node_or_null("Enemy")
	if old:
		old.queue_free()

	var enemy = EnemyScene.instantiate()
	enemy.position = level_gen.get_enemy_start_position()
	add_child(enemy)

func _on_page_collected():
	var ui = _ui
	GameStateManager.collect_page()
	ui.update_objective(GameStateManager.pages_collected, GameStateManager.TOTAL_PAGES, GameStateManager.generators_activated, GameStateManager.TOTAL_GENERATORS)
	if GameStateManager.pages_collected >= GameStateManager.TOTAL_PAGES:
		ui.log_debug("All pages collected!")
	_play_sfx("res://sfx/page_grab.mp3", -2.0)

func _on_generator_activated():
	var ui = _ui
	ui.update_objective(GameStateManager.generators_activated, GameStateManager.TOTAL_GENERATORS, GameStateManager.pages_collected, GameStateManager.TOTAL_PAGES)
	if GameStateManager.generators_activated >= GameStateManager.TOTAL_GENERATORS:
		ui.log_debug("All generators active!")
	_play_sfx("res://sfx/generator_start.mp3", 0.0, 1.0)

func _on_generator_deactivated():
	var ui = _ui
	ui.update_objective(GameStateManager.generators_activated, GameStateManager.TOTAL_GENERATORS, GameStateManager.pages_collected, GameStateManager.TOTAL_PAGES)
	if GameStateManager.generators_activated >= GameStateManager.TOTAL_GENERATORS:
		check_exit_unlock()

func check_exit_unlock():
	var ui = _ui
	var level_gen = _level_gen

	EventBus.log_debug("Checking exit unlock condition...")
	GameStateManager.can_unlock_exit()

	if not GameStateManager.exit_door_ref:
		var door = level_gen.get_node_or_null("ExitDoor")
		if door:
			GameStateManager.exit_door_ref = door

	if GameStateManager.exit_door_ref and not GameStateManager.exit_door_ref.is_open:
		EventBus.log_debug("Exit door unlocked!")
		GameStateManager.exit_door_ref.is_open = true
		var open_light = GameStateManager.exit_door_ref.get_node_or_null("OpenLight")
		if open_light:
			open_light.visible = true
		var closed_light = GameStateManager.exit_door_ref.get_node_or_null("ClosedLight")
		if closed_light:
			closed_light.visible = false
		ui.show_notification("EXIT UNLOCKED")
		ui.log_debug("Exit door opened!")
		GameStateManager.exit_unlock_ready.emit()

func win_game():
	var ui = _ui
	var level_gen = _level_gen

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.visible = false
	var enemy = get_node_or_null("Enemy")
	if enemy:
		enemy.queue_free()
	ui.show_loading("ESCAPED...")

	await get_tree().create_timer(1.8).timeout
	level_gen.cleanup_level()
	GameStateManager.reset()
	get_tree().paused = true
	ui.hide_loading()
	ui.show_victory()

func game_over():
	EventBus.log_debug("GAME OVER triggered")
	var ui = _ui
	var player = _player
	var level_gen = _level_gen

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	var enemy = get_node_or_null("Enemy")
	if enemy:
		enemy.queue_free()
	await get_tree().create_timer(0.8).timeout
	level_gen.cleanup_level()
	GameStateManager.reset()
	get_tree().paused = true
	ui.show_game_over()

func _process(_delta):
	var ui = get_node_or_null("UIManager")
	if ui:
		ui.update_debug("FPS", Engine.get_frames_per_second())

func setup_post_processing():
	var env_layer = CanvasLayer.new()
	env_layer.name = "PostProcessLayer"
	env_layer.layer = 10
	add_child(env_layer)

	var post_rect = ColorRect.new()
	post_rect.name = "PostProcessRect"
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	env_layer.add_child(post_rect)

	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = VHSShader
	post_rect.material = shader_mat
	vhs_material = shader_mat

	shader_mat.set_shader_parameter("jitter_amount", 0.003)
	shader_mat.set_shader_parameter("luma_flicker", 0.05)
	shader_mat.set_shader_parameter("static_noise", 0.15)

	shader_mat.set_shader_parameter("scanline_opacity", 0.15)

	var texture_scale = DisplayServer.window_get_size()
	shader_mat.set_shader_parameter("texture_scale", Vector2(texture_scale.x, texture_scale.y))

func setup_environment():
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	add_child(world_env)
	var env = world_env.environment
	if not env:
		env = Environment.new()
		world_env.environment = env

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.02)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.03, 0.03, 0.04)
	env.ambient_light_energy = 0.12

	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.012
	env.fog_height_density = 1.0
	env.fog_height = 0.0
	env.fog_aerial_perspective = 0.0

func _on_game_started():
	print("Game Started Signal Received")
	AudioManager.ambient_player.stop()
