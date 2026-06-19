extends StaticBody3D

signal activated

var is_active = false
var progress = 0.0
const RESTART_TIME = 3.0 # 3 seconds to fully restart
var held_this_frame = false

# Visual nodes
var status_mesh: MeshInstance3D
var status_light: OmniLight3D
var flywheel_mesh: MeshInstance3D

# Audio players
var hum_player: AudioStreamPlayer3D
var crank_player: AudioStreamPlayer3D

var nearby_lights: Array[OmniLight3D] = []
const LIGHT_RADIUS: float = 8.0
const LIGHT_ON_ENERGY: float = 1.0
const LIGHT_OFF_ENERGY: float = 0.2

# Clicks timer
var crank_timer = 0.0
const CRANK_RATE = 0.15 # Click every 0.15 seconds

func _ready():
	add_to_group("generators")
	# Configure collision layer to match interactables (layer 1 & 2)
	collision_layer = 1 | 2
	collision_mask = 1
	
	# Create generator visual parts programmatically
	_create_visuals()
	
	# Create collision shape
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)
	
	# Set up audio players
	hum_player = AudioStreamPlayer3D.new()
	hum_player.name = "HumPlayer"
	hum_player.max_distance = 15.0
	hum_player.unit_size = 4.0
	if FileAccess.file_exists("res://sfx/generator_hum.mp3"):
		hum_player.stream = load("res://sfx/generator_hum.mp3")
		hum_player.volume_db = -15.0
	add_child(hum_player)
	
	crank_player = AudioStreamPlayer3D.new()
	crank_player.name = "CrankPlayer"
	crank_player.max_distance = 10.0
	crank_player.unit_size = 3.0
	add_child(crank_player)
	
	# Initialize default visuals
	_update_status_visuals()
	_find_nearby_lights()

func _create_visuals():
	var base := MeshFactory.box(Vector3(1.2, 0.8, 1.2), MaterialFactory.make_unshaded(Color(0.2, 0.22, 0.2)))
	base.position.y = 0.4
	add_child(base)
	
	var block := MeshFactory.cylinder(0.25, 0.25, 0.5, 6, MaterialFactory.make_unshaded(Color(0.12, 0.12, 0.12)))
	block.position = Vector3(0.0, 0.95, 0.1)
	block.rotation.x = PI / 2.0
	add_child(block)
	
	var flywheel_mat = MaterialFactory.make_unshaded(Color(0.4, 0.1, 0.1))
	flywheel_mesh = MeshFactory.cylinder(0.3, 0.3, 0.1, 6, flywheel_mat)
	flywheel_mesh.position = Vector3(0.0, 0.95, -0.2)
	flywheel_mesh.rotation.x = PI / 2.0
	add_child(flywheel_mesh)
	
	status_mesh = MeshFactory.sphere(0.07, 0.14)
	status_mesh.position = Vector3(0.4, 0.85, 0.4)
	add_child(status_mesh)
	
	# 5. Status PointLight3D
	status_light = OmniLight3D.new()
	status_light.omni_range = 3.5
	status_light.light_energy = 0.5
	status_light.shadow_enabled = false
	status_mesh.add_child(status_light)

func _process(delta):
	if is_active:
		# Spin the flywheel when generator is running!
		flywheel_mesh.rotate_y(delta * 12.0)
		return
		
	if not held_this_frame:
		if progress > 0.0:
			progress = max(progress - delta * 1.2, 0.0) # Decays back to zero
	else:
		# Process cranking sound while being held (tempo increases as progress increases)
		crank_timer += delta
		var current_crank_rate = lerp(0.26, 0.09, progress)
		if crank_timer >= current_crank_rate:
			crank_timer = 0.0
			_play_crank_sound()
			
	# Update visual indicator lamp state
	_update_status_visuals()
	
	held_this_frame = false # Reset for next frame

func interact():
	if is_active:
		return
	EventBus.log_debug("Generator interaction started at: %s" % global_position)
	EventBus.notify_generator_interaction_held()

func interact_hold(delta):
	if is_active:
		return
	held_this_frame = true
	progress = min(progress + delta / RESTART_TIME, 1.0)
	
	if progress >= 1.0:
		EventBus.log_debug("Generator fully cranked, activating at: %s" % global_position)
		activate_generator()

func activate_generator():
	is_active = true
	progress = 1.0
	
	# Play startup/climax sound
	if FileAccess.file_exists("res://sfx/generator_start.mp3"):
		var p = AudioStreamPlayer3D.new()
		p.stream = load("res://sfx/generator_start.mp3")
		p.volume_db = 4.0
		p.pitch_scale = 1.0
		p.position = position
		get_parent().add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		
	# Start engine loop hum
	if hum_player.stream:
		hum_player.play()
		
	# Update indicator visuals permanently
	_update_status_visuals()
	_toggle_nearby_lights(true)
	
	GameStateManager.activate_generator()
	emit_signal("activated")

func _update_status_visuals():
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	
	if is_active:
		mat.albedo_color = Color(0.1, 0.9, 0.1) # Green
		mat.emission = Color(0.1, 0.9, 0.1)
		status_light.light_color = Color(0.2, 0.9, 0.2)
		status_light.light_energy = 1.5
	elif progress > 0.0:
		# Blinking yellow while cranking
		var blink = int(Time.get_ticks_msec() / 150) % 2 == 0
		if blink:
			mat.albedo_color = Color(0.9, 0.8, 0.1) # Bright Yellow
			mat.emission = Color(0.9, 0.8, 0.1)
			status_light.light_color = Color(0.9, 0.8, 0.2)
			status_light.light_energy = 1.2
		else:
			mat.albedo_color = Color(0.2, 0.18, 0.0) # Dim Yellow
			mat.emission = Color(0.2, 0.18, 0.0)
			status_light.light_color = Color(0.2, 0.18, 0.0)
			status_light.light_energy = 0.1
	else:
		mat.albedo_color = Color(0.9, 0.1, 0.1) # Red
		mat.emission = Color(0.9, 0.1, 0.1)
		status_light.light_color = Color(0.9, 0.1, 0.1)
		status_light.light_energy = 0.6
		
	status_mesh.material_override = mat

func _play_crank_sound():
	# Use standard click sound at randomized pitch that scales with starting progress
	var sfx_path = "res://sfx/generator_crank.mp3"
	if FileAccess.file_exists(sfx_path):
		crank_player.stream = load(sfx_path)
		var base_pitch = lerp(0.7, 1.4, progress)
		crank_player.pitch_scale = base_pitch * randf_range(0.9, 1.1)
		crank_player.volume_db = randf_range(-3.0, 1.0)
		crank_player.play()

func _find_nearby_lights():
	var parent = get_parent()
	if not parent: return
	var nav = parent.get_node_or_null("NavRegion")
	if not nav: return
	for child in nav.get_children():
		_collect_lights_recursive(child, global_position)

func _collect_lights_recursive(node: Node, origin: Vector3):
	if node is OmniLight3D:
		if origin.distance_to(node.global_position) <= LIGHT_RADIUS:
			nearby_lights.append(node)
			node.light_energy = LIGHT_OFF_ENERGY
			return
	for child in node.get_children():
		_collect_lights_recursive(child, origin)

func _toggle_nearby_lights(on: bool):
	var energy = LIGHT_ON_ENERGY if on else LIGHT_OFF_ENERGY
	for light in nearby_lights:
		if is_instance_valid(light):
			light.light_energy = energy

func get_interaction_text() -> String:
	if is_active:
		return "Generator Online"
	elif progress > 0.0:
		return "Starting... (%d%%)" % int(progress * 100)
	else:
		return "Restart Generator"

func turn_off():
	if not is_active: return
	is_active = false
	progress = 0.0
	
	# Stop hum player
	if hum_player.playing:
		hum_player.stop()
		
	# Play shutdown sound
	if FileAccess.file_exists("res://sfx/generator_off.mp3"):
		var p = AudioStreamPlayer3D.new()
		p.stream = load("res://sfx/generator_off.mp3")
		p.pitch_scale = 1.0
		p.volume_db = 6.0
		p.position = position
		get_parent().add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		
	_update_status_visuals()
	_toggle_nearby_lights(false)
	
	GameStateManager.deactivate_generator()
