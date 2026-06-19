extends Node

var ambient_player: AudioStreamPlayer
var footsteps_player: AudioStreamPlayer
var ambient_stream = preload("res://sfx/placeholder_ambience.mp3") if FileAccess.file_exists("res://sfx/placeholder_ambience.mp3") else null

var step_streams: Array[AudioStream] = []

var reverb_effect: AudioEffectReverb
var footsteps_bus_idx: int

func _ready():
	_load_step_sounds()
	_setup_footsteps_audio_bus()
	setup_audio_players()
	play_ambience()
	set_reverb()

func _load_step_sounds():
	step_streams.clear()
	for i in range(1, 9):
		var path = "res://sfx/step_industrial_%d.mp3" % i
		if FileAccess.file_exists(path):
			step_streams.append(load(path))
		else:
			print("AudioManager: Step sound not found: ", path)

func set_theme():
	_load_step_sounds()
	var amb_path = "res://sfx/ambience_industrial.mp3"
	if not FileAccess.file_exists(amb_path):
		amb_path = "res://sfx/placeholder_ambience.mp3"
	if FileAccess.file_exists(amb_path):
		var new_stream = load(amb_path)
		ambient_player.stream = new_stream
		ambient_player.play()
	else:
		print("AudioManager: No ambience found for industrial theme")

func _setup_footsteps_audio_bus():
	var bus_name = "Footsteps"
	footsteps_bus_idx = AudioServer.get_bus_count()
	var existing_idx = AudioServer.get_bus_index(bus_name)
	if existing_idx != -1:
		footsteps_bus_idx = existing_idx
	else:
		AudioServer.add_bus()
		AudioServer.set_bus_name(footsteps_bus_idx, bus_name)
		AudioServer.set_bus_send(footsteps_bus_idx, "Master")
	var has_reverb = false
	for i in range(AudioServer.get_bus_effect_count(footsteps_bus_idx)):
		if AudioServer.get_bus_effect(footsteps_bus_idx, i) is AudioEffectReverb:
			reverb_effect = AudioServer.get_bus_effect(footsteps_bus_idx, i)
			has_reverb = true
			break
	if not has_reverb:
		reverb_effect = AudioEffectReverb.new()
		AudioServer.add_bus_effect(footsteps_bus_idx, reverb_effect)

func setup_audio_players():
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "Ambience"
	ambient_player.volume_db = -12.0
	if ambient_stream:
		ambient_player.stream = ambient_stream
	else:
		print("AUDIO WARNING: No Ambience file found at 'res://sfx/placeholder_ambience.mp3'")
	add_child(ambient_player)

	footsteps_player = AudioStreamPlayer.new()
	footsteps_player.name = "Footsteps"
	footsteps_player.bus = "Footsteps"
	add_child(footsteps_player)

func play_ambience():
	if ambient_player.stream:
		ambient_player.play()

func play_step(speed_scale: float = 1.0):
	if step_streams.is_empty():
		return
	footsteps_player.stream = step_streams.pick_random()
	var base_pitch = randf_range(0.9, 1.1)
	footsteps_player.pitch_scale = base_pitch * speed_scale
	footsteps_player.play()

func set_reverb():
	if not reverb_effect: return
	reverb_effect.room_size = 0.3
	reverb_effect.damping = 0.5
	reverb_effect.wet = 0.2
