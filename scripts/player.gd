extends CharacterBody3D

const SPEED = 4.0
const SPRINT_SPEED = 6.5
var mouse_sensitivity = 0.003
var _skip_mouse_event := false
var _last_mouse_mode := Input.MOUSE_MODE_VISIBLE

const SWAY_AMOUNT = 0.05
const SWAY_SMOOTHING = 4.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
const JUMP_VELOCITY = 4.5
var step_cooldown = false
var flashlight_cooldown = false

const CAM_LAG_SPEED = 12.0
var current_bob_speed = 0.0
var bob_pos = Vector2.ZERO

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var flashlight = $Head/Camera3D/SpotLight3D
@onready var raycast = $Head/Camera3D/RayCast3D

var enemy_ref: Node3D

var target_rot_x = 0.0
var target_rot_y = 0.0

var noise = FastNoiseLite.new()
var noise_time = 0.0
var trauma = 0.0
var breathing_time = 0.0

var default_fov = 60.0
var sprint_fov = 70.0
var is_sprinting = false

var was_clicking = false
var wall_check: ShapeCast3D

var stamina = 100.0
const STAMINA_MAX = 100.0
const STAMINA_DRAIN_RATE = 15.0
const STAMINA_REGEN_RATE = 10.0
var stamina_depleted = false
var breathing_sfx: AudioStreamPlayer

func _ready():
	add_to_group("player")
	raycast.enabled = true
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	raycast.target_position = Vector3(0, 0, -3.0)

	wall_check = ShapeCast3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.3
	wall_check.shape = sphere
	wall_check.target_position = Vector3(0, 0, -0.5)
	wall_check.max_results = 1
	head.add_child(wall_check)

	breathing_sfx = AudioStreamPlayer.new()
	breathing_sfx.stream = load("res://sfx/enemy/breathing_loop.mp3")
	breathing_sfx.volume_db = -10.0
	breathing_sfx.bus = "Master"
	add_child(breathing_sfx)

	noise.seed = randi()
	noise.frequency = 1.5
	noise.fractal_octaves = 2

	await get_tree().physics_frame
	enemy_ref = get_tree().get_first_node_in_group("enemy")

	flashlight.spot_angle = 35.0
	flashlight.spot_range = 25.0
	flashlight.visible = true

	target_rot_y = rotation.y

func _process(delta):
	var current_mouse = Input.get_mouse_mode()
	if current_mouse != _last_mouse_mode:
		_last_mouse_mode = current_mouse
		if current_mouse == Input.MOUSE_MODE_CAPTURED:
			_skip_mouse_event = true
	_process_external_look(delta)

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider:
			if Input.is_action_just_pressed("interact") and collider.has_method("interact"):
				EventBus.log_debug("Player interacting with: %s" % collider.name)
				collider.interact()
			if Input.is_action_pressed("interact") and collider.has_method("interact_hold"):
				EventBus.log_debug("Player holding interact on: %s" % collider.name)
				collider.interact_hold(delta)

	head.rotation.x = target_rot_x
	head.rotation.y = target_rot_y
	noise_time += delta
	breathing_time += delta

	if trauma > 0:
		trauma = max(trauma - delta * 0.4, 0.0)

	var idle_sway_amount = 0.005 + (trauma * 0.02)
	var idle_x = sin(breathing_time * 0.8) * idle_sway_amount
	var idle_y = cos(breathing_time * 1.5) * idle_sway_amount

	var shake_power = pow(trauma, 2) * 0.3
	var noise_x = noise.get_noise_2d(noise_time * 20.0, 0.0) * shake_power
	var noise_y = noise.get_noise_2d(0.0, noise_time * 20.0) * shake_power
	var noise_z = noise.get_noise_2d(noise_time * 10.0, 100.0) * (shake_power * 0.5)

	var wall_push = 0.0
	if wall_check.is_colliding():
		wall_push = 0.25

	camera.h_offset = idle_x + noise_x
	camera.v_offset = idle_y + noise_y
	camera.rotation.z = noise_z
	camera.transform.origin.z = lerp(camera.transform.origin.z, wall_push, delta * 5.0)

	var target_fov = default_fov
	if is_sprinting: target_fov = sprint_fov
	target_fov -= (trauma * 5.0)
	camera.fov = target_fov

	if not is_sprinting:
		stamina = min(stamina + STAMINA_REGEN_RATE * delta, STAMINA_MAX)
		if stamina == STAMINA_MAX:
			stamina_depleted = false
			if breathing_sfx.playing: breathing_sfx.stop()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if _skip_mouse_event:
			_skip_mouse_event = false
			return
		target_rot_y -= event.relative.x * mouse_sensitivity
		target_rot_x -= event.relative.y * mouse_sensitivity
		target_rot_x = clamp(target_rot_x, deg_to_rad(-70), deg_to_rad(70))

func _process_external_look(delta):
	var joy_look = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	var deadzone = 0.15
	if joy_look.length() > deadzone:
		joy_look = joy_look.normalized() * ((joy_look.length() - deadzone) / (1.0 - deadzone))
		joy_look.x = sign(joy_look.x) * pow(abs(joy_look.x), 1.5)
		joy_look.y = sign(joy_look.y) * pow(abs(joy_look.y), 1.5)
		var controller_sens = 15.0
		target_rot_y -= joy_look.x * mouse_sensitivity * controller_sens * (delta * 60.0)
		target_rot_x -= joy_look.y * mouse_sensitivity * controller_sens * (delta * 60.0)
		target_rot_x = clamp(target_rot_x, deg_to_rad(-70), deg_to_rad(70))

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1

	var joy_move = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_dir += joy_move

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	var trying_to_sprint = Input.is_action_pressed("sprint") and input_dir.y < 0
	is_sprinting = trying_to_sprint and !stamina_depleted and stamina > 0

	if is_sprinting:
		stamina -= STAMINA_DRAIN_RATE * delta
		if stamina <= 0:
			stamina = 0
			stamina_depleted = true
			if !breathing_sfx.playing: breathing_sfx.play()
	elif stamina_depleted:
		if !breathing_sfx.playing: breathing_sfx.play()

	var current_speed = SPRINT_SPEED if is_sprinting else SPEED

	var input_vector = Vector3(input_dir.x, 0, input_dir.y)
	var global_euler = head.global_transform.basis.get_euler()
	var camera_basis = Basis.from_euler(Vector3(0, global_euler.y, 0))
	var direction = camera_basis * input_vector
	direction.y = 0
	direction = direction.normalized()

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		var bob_speed = 12.0 if is_sprinting else 8.0
		current_bob_speed = lerp(current_bob_speed, bob_speed, delta * 5.0)

		bob_pos.x += delta * current_bob_speed
		bob_pos.y += delta * current_bob_speed * 2.0

		var bob_amount = 0.05 if is_sprinting else 0.02
		var bob_x = cos(bob_pos.x * 0.5) * (bob_amount * 0.5)
		var bob_y = sin(bob_pos.y * 0.5) * bob_amount

		if stamina < 30.0:
			bob_x += randf_range(-0.01, 0.01)

		camera.transform.origin.x = lerp(camera.transform.origin.x, bob_x, delta * 8.0)
		camera.transform.origin.y = lerp(camera.transform.origin.y, bob_y, delta * 8.0)

		var target_tilt = -input_dir.x * 0.03
		var tilt_noise = noise.get_noise_2d(noise_time * 10.0, 100.0) * (pow(trauma, 2) * 0.3 * 0.5)
		camera.rotation.z = lerp(camera.rotation.z, target_tilt + tilt_noise, delta * 5.0)

		if sin(bob_pos.y * 0.5) < -0.9 and !step_cooldown:
			AudioManager.play_step()

			add_trauma(0.05 if is_sprinting else 0.02)
			step_cooldown = true
		elif sin(bob_pos.y * 0.5) > -0.5:
			step_cooldown = false

	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 3.0)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 3.0)

	move_and_slide()

	var slide_count = get_slide_collision_count()
	if slide_count > 0:
		for i in range(slide_count):
			var col = get_slide_collision(i)
			if col and col.get_collider():
				var cname = col.get_collider().name
				var cgroup = ""
				if col.get_collider().is_in_group("enemy"): cgroup = "enemy"
				elif col.get_collider().is_in_group("pages"): cgroup = "page"
				if cgroup != "":
					EventBus.log_debug("Player collided with: %s (%s)" % [cname, cgroup])

	if Input.is_action_just_pressed("flashlight"):
		if !flashlight_cooldown:
			if !flashlight.visible:
				flashlight.visible = true
				_play_flashlight_sfx(true)
			elif flashlight.visible:
				flashlight.visible = false
				_play_flashlight_sfx(false)
			flashlight_cooldown = true
	else:
		flashlight_cooldown = false

	if flashlight.visible:
		if randf() > 0.96: flashlight.light_energy = randf_range(6.0, 12.0)
		else: flashlight.light_energy = lerp(flashlight.light_energy, 8.0, delta * 10.0)

func _play_flashlight_sfx(on: bool):
	var stream = load("res://sfx/fl_on.mp3") if on else load("res://sfx/fl_off.mp3")
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = stream
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)

func add_trauma(amount):
	trauma = clamp(trauma + amount, 0.0, 1.0)
