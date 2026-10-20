class_name AudioBus
extends Node

# Procedural synthesizer and audio manager for Riftline: Last Train.
# Generates authentic dieselpunk SFX without external audio files.

var players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer
var sounds: Dictionary = {}
var enabled: bool = true

# Music Subsystem
var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var active_music_player: AudioStreamPlayer = null
var current_track: String = ""
var music_tween: Tween = null
var music_tracks: Dictionary = {}
const BASE_MUSIC_DB: float = -12.0

var sound_volumes: Dictionary = {
	"gatling": -4.0,   # Heavy mechanical machine gun thump, comfortable rapid cadence
	"cannon": -1.5,    # Massive artillery boom with chest-thumping sub-bass
	"boom": -3.0,      # Deep ordnance detonation
	"hit": -6.0,       # Heavy kinetic steel impact
	"drone": -7.5,     # Crisp pneumatic micro-cannon
	"arc": -5.5,       # Deep plasma pulse
	"cryo": -6.5,      # Compressed gas venting
	"warn": -6.0,      # Warm brassy dieselpunk horn
	"ui": -10.0,
	"ui_select": -8.0,
	"level": -6.0,
	"victory": -4.0
}

func _init() -> void:
	generate_sounds()

func _ready() -> void:
	setup_buses()
	for i in range(12):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "SFX"
	add_child(ambient_player)
	
	music_player_a = AudioStreamPlayer.new()
	music_player_a.bus = "Music"
	add_child(music_player_a)
	
	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = "Music"
	add_child(music_player_b)
	
	load_music_tracks()
	load_sfx_files()

func setup_buses() -> void:
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_send(music_bus_idx, "Master")
	
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		AudioServer.add_bus()
		sfx_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(sfx_bus_idx, "Master")

func _load_audio_stream(primary_path: String, fallback_path: String = "") -> AudioStream:
	# Prefer compact OGG on all platforms; fall back to WAV for desktop/dev.
	if ResourceLoader.exists(primary_path):
		var s: AudioStream = load(primary_path) as AudioStream
		if s != null:
			return s
	if fallback_path != "" and ResourceLoader.exists(fallback_path):
		return load(fallback_path) as AudioStream
	return null

func load_music_tracks() -> void:
	var menu_res := _load_audio_stream(
		"res://assets/audio/music/riftline_main_menu.ogg",
		"res://assets/audio/music/riftline_main_menu.wav"
	)
	if menu_res is AudioStreamWAV:
		var menu_wav := menu_res as AudioStreamWAV
		menu_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		menu_wav.loop_begin = 0
		menu_wav.loop_end = int(menu_wav.get_length() * menu_wav.mix_rate)
	elif menu_res is AudioStreamOggVorbis:
		(menu_res as AudioStreamOggVorbis).loop = true
	if menu_res != null:
		music_tracks["menu"] = menu_res
	var travel_res := _load_audio_stream(
		"res://assets/audio/music/riftline_travel.ogg",
		"res://assets/audio/music/riftline_travel.wav"
	)
	if travel_res is AudioStreamWAV:
		var travel_wav := travel_res as AudioStreamWAV
		travel_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		travel_wav.loop_begin = 0
		travel_wav.loop_end = int(travel_wav.get_length() * travel_wav.mix_rate)
	elif travel_res is AudioStreamOggVorbis:
		(travel_res as AudioStreamOggVorbis).loop = true
	if travel_res != null:
		music_tracks["travel"] = travel_res
	# P1: combat bed — ships as assets/audio/music/riftline_combat.{ogg,wav}.
	# Until that file exists in the repo, play_combat_music() falls back to travel.
	var combat_res := _load_audio_stream(
		"res://assets/audio/music/riftline_combat.ogg",
		"res://assets/audio/music/riftline_combat.wav"
	)
	if combat_res is AudioStreamWAV:
		var combat_wav := combat_res as AudioStreamWAV
		combat_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		combat_wav.loop_begin = 0
		combat_wav.loop_end = int(combat_wav.get_length() * combat_wav.mix_rate)
	elif combat_res is AudioStreamOggVorbis:
		(combat_res as AudioStreamOggVorbis).loop = true
	if combat_res != null:
		music_tracks["combat"] = combat_res

func load_sfx_files() -> void:
	var sfx_map = {
		"gatling": ["res://assets/audio/sfx/sfx_gatling.ogg", "res://assets/audio/sfx/sfx_gatling.wav"],
		"cannon": ["res://assets/audio/sfx/sfx_cannon.ogg", "res://assets/audio/sfx/sfx_cannon.wav"],
		"boom": ["res://assets/audio/sfx/sfx_boom.ogg", "res://assets/audio/sfx/sfx_boom.wav"],
		"hit": ["res://assets/audio/sfx/sfx_hit.ogg", "res://assets/audio/sfx/sfx_hit.wav"],
		"drone": ["res://assets/audio/sfx/sfx_drone.ogg", "res://assets/audio/sfx/sfx_drone.wav"],
		"arc": ["res://assets/audio/sfx/sfx_arc.ogg", "res://assets/audio/sfx/sfx_arc.wav"],
		"cryo": ["res://assets/audio/sfx/sfx_cryo.ogg", "res://assets/audio/sfx/sfx_cryo.wav"],
		"warn": ["res://assets/audio/sfx/sfx_warn.ogg", "res://assets/audio/sfx/sfx_warn.wav"]
	}
	for key in sfx_map:
		var paths: Array = sfx_map[key]
		var stream := _load_audio_stream(str(paths[0]), str(paths[1]))
		if stream != null:
			sounds[key] = stream

func play_menu_music(fade_duration: float = 1.0) -> void:
	if current_track == "menu" and active_music_player != null and active_music_player.playing:
		return
	fade_to_track("menu", fade_duration)

func play_travel_music(fade_duration: float = 1.5) -> void:
	if current_track == "travel" and active_music_player != null and active_music_player.playing:
		return
	fade_to_track("travel", fade_duration)

## P1: dedicated combat bed. Falls back to the travel loop while the combat
## track asset is still missing, so behavior matches the old build either way.
func play_combat_music(fade_duration: float = 1.5) -> void:
	if not music_tracks.has("combat"):
		play_travel_music(fade_duration)
		return
	if current_track == "combat" and active_music_player != null and active_music_player.playing:
		return
	fade_to_track("combat", fade_duration)

func fade_to_track(track_name: String, duration: float = 1.5) -> void:
	if not music_tracks.has(track_name):
		return
	if current_track == track_name and active_music_player != null and active_music_player.playing:
		return
	
	current_track = track_name
	var next_player = music_player_b if active_music_player == music_player_a else music_player_a
	var prev_player = active_music_player
	
	next_player.stream = music_tracks[track_name]
	next_player.volume_db = -60.0
	next_player.play()
	active_music_player = next_player
	
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	music_tween = create_tween()
	music_tween.set_parallel(true)
	music_tween.tween_property(next_player, "volume_db", BASE_MUSIC_DB, duration)
	if prev_player != null and prev_player.playing:
		music_tween.tween_property(prev_player, "volume_db", -60.0, duration)
		music_tween.chain().tween_callback(Callable(prev_player, "stop"))

func stop_music(fade_duration: float = 1.5) -> void:
	current_track = ""
	if active_music_player == null or not active_music_player.playing:
		return
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	if fade_duration <= 0.05:
		active_music_player.stop()
		return
	music_tween = create_tween()
	var p = active_music_player
	music_tween.tween_property(p, "volume_db", -60.0, fade_duration)
	music_tween.tween_callback(Callable(p, "stop"))

func set_music_volume(factor: float) -> void:
	var idx = AudioServer.get_bus_index("Music")
	if idx != -1:
		if factor <= 0.01:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			var db = linear_to_db(clampf(factor, 0.01, 1.0))
			AudioServer.set_bus_volume_db(idx, db)

func set_sfx_volume(factor: float) -> void:
	var idx = AudioServer.get_bus_index("SFX")
	if idx != -1:
		if factor <= 0.01:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			var db = linear_to_db(clampf(factor, 0.01, 1.0))
			AudioServer.set_bus_volume_db(idx, db)

func set_engine_hum_active(_active: bool) -> void:
	if ambient_player != null and ambient_player.playing:
		ambient_player.stop()

func generate_sounds() -> void:
	sounds["ui"] = create_tone(800.0, 0.04, 0.15, "sine", 0.0)
	sounds["ui_select"] = create_arpeggio([523.25, 659.25, 783.99], 0.1, 0.18)
	sounds["gatling"] = create_gunshot(0.13, 0.85)
	sounds["cannon"] = create_cannon(0.55, 0.9)
	sounds["boom"] = create_boom(0.65, 0.9)
	sounds["hit"] = create_armor_hit(0.12, 0.7)
	sounds["drone"] = create_drone_shot(0.09, 0.55)
	sounds["arc"] = create_plasma(0.16, 0.65)
	sounds["cryo"] = create_whoosh(0.24, 0.6)
	sounds["warn"] = create_klaxon(0.22, 0.6)
	sounds["level"] = create_arpeggio([440.0, 554.37, 659.25, 880.0], 0.35, 0.3)
	sounds["victory"] = create_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.6, 0.4)

func make_wav_16(float_samples: PackedFloat32Array, sample_rate: int = 44100) -> AudioStreamWAV:
	var count = float_samples.size()
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var v = clampf(float_samples[i], -1.0, 1.0)
		var s16 = int(v * 32767.0)
		bytes[i * 2] = s16 & 0xFF
		bytes[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

func create_gunshot(duration: float = 0.135, volume: float = 0.85) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	var noise_filtered = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		# Deep pitch plunge (170Hz -> 52Hz) for heavy combustive thump
		var freq = 52.0 + 120.0 * exp(-t / 0.015)
		var thump = sin(t * freq * TAU) * exp(-t / 0.035) * 1.0
		var sub = sin(t * 58.0 * TAU) * exp(-t / 0.055) * 0.6
		# Lowpass filtered mechanical blast
		var r = randf() * 2.0 - 1.0
		noise_filtered = noise_filtered * 0.72 + r * 0.28
		var blast = noise_filtered * exp(-t / 0.038) * 0.8
		var raw = (thump + sub + blast) * volume
		arr[i] = tanh(raw * 1.5)
	return make_wav_16(arr, rate)

func create_cannon(duration: float = 0.55, volume: float = 0.9) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	var noise_filtered = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		# Colossal sub-bass plunge (130Hz -> 34Hz)
		var freq = 34.0 + 105.0 * exp(-t / 0.035)
		var shockwave = sin(t * freq * TAU) * exp(-t / 0.18) * 1.2
		var sub = (sin(t * 38.0 * TAU) * 0.8 + sin(t * 76.0 * TAU) * 0.4) * exp(-t / 0.28)
		var r = randf() * 2.0 - 1.0
		noise_filtered = noise_filtered * 0.82 + r * 0.18
		var rumble = noise_filtered * exp(-t / 0.25) * 0.7
		var raw = (shockwave + sub + rumble) * volume
		arr[i] = tanh(raw * 1.6)
	return make_wav_16(arr, rate)

func create_boom(duration: float = 0.65, volume: float = 0.9) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	var noise_filtered = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		var sub = sin(t * (32.0 + 60.0 * exp(-t / 0.06)) * TAU) * exp(-t / 0.22) * 1.0
		var r = randf() * 2.0 - 1.0
		noise_filtered = noise_filtered * 0.80 + r * 0.20
		var rumble = noise_filtered * exp(-t / 0.3) * 0.9
		arr[i] = tanh((sub + rumble) * volume * 1.5)
	return make_wav_16(arr, rate)

func create_armor_hit(duration: float = 0.12, volume: float = 0.7) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	for i in range(count):
		var t = float(i) / float(rate)
		var freq = 50.0 + 100.0 * exp(-t / 0.012)
		var thud = sin(t * freq * TAU) * exp(-t / 0.035) * 1.0
		var ping = sin(t * 720.0 * TAU) * exp(-t / 0.018) * 0.45
		arr[i] = tanh((thud + ping) * volume * 1.4)
	return make_wav_16(arr, rate)

func create_drone_shot(duration: float = 0.09, volume: float = 0.55) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	for i in range(count):
		var t = float(i) / float(rate)
		var freq = 65.0 + 160.0 * exp(-t / 0.01)
		var thump = sin(t * freq * TAU) * exp(-t / 0.03) * 0.9
		var pop = sin(t * 360.0 * TAU) * exp(-t / 0.012) * 0.35
		arr[i] = tanh((thump + pop) * volume * 1.3)
	return make_wav_16(arr, rate)

func create_plasma(duration: float = 0.16, volume: float = 0.65) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	var last_noise = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		var sub = sin(t * 75.0 * TAU) * exp(-t / 0.06) * 0.9
		var r = randf() * 2.0 - 1.0
		last_noise = last_noise * 0.6 + r * 0.4
		var crackle = last_noise * exp(-t / 0.04) * 0.6
		arr[i] = tanh((sub + crackle) * volume * 1.4)
	return make_wav_16(arr, rate)

func create_whoosh(duration: float = 0.24, volume: float = 0.6) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	var filtered = 0.0
	for i in range(count):
		var t = float(i) / float(rate)
		var env = sin(PI * pow(t / duration, 0.6))
		var r = randf() * 2.0 - 1.0
		filtered = filtered * 0.7 + r * 0.3
		arr[i] = tanh(filtered * env * volume * 1.2)
	return make_wav_16(arr, rate)

func create_klaxon(duration: float = 0.22, volume: float = 0.6) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	for i in range(count):
		var t = float(i) / float(rate)
		var tone1 = sin(t * 370.0 * TAU) * 0.6
		var tone2 = sin(t * 460.0 * TAU) * 0.5
		var env = clampf(t / 0.015, 0.0, 1.0) * exp(-t / 0.16)
		arr[i] = tanh((tone1 + tone2) * env * volume * 1.3)
	return make_wav_16(arr, rate)

func create_tone(freq: float, duration: float, volume: float, waveform: String, pitch_drop: float) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	for i in range(count):
		var t = float(i) / float(rate)
		var progress = float(i) / float(count)
		var cur_freq = max(40.0, freq - pitch_drop * progress)
		var phase = t * cur_freq * TAU
		var env = (1.0 - progress) * volume
		var val = sin(phase)
		if waveform == "triangle":
			val = asin(sin(phase)) * (2.0 / PI)
		arr[i] = val * env
	return make_wav_16(arr, rate)

func create_arpeggio(freqs: Array, duration: float, volume: float) -> AudioStreamWAV:
	var rate = 44100
	var count = int(rate * duration)
	var arr = PackedFloat32Array()
	arr.resize(count)
	var step = count / max(1, freqs.size())
	for i in range(count):
		var t = float(i) / float(rate)
		var note_idx = clampi(i / step, 0, freqs.size() - 1)
		var freq = freqs[note_idx]
		var note_progress = float(i % step) / float(step)
		var env = pow(1.0 - note_progress, 1.2) * volume
		var tone = sin(t * freq * TAU) * 0.7 + sin(t * freq * 2.0 * TAU) * 0.2
		arr[i] = tone * env
	return make_wav_16(arr, rate)


func play(sfx_name: String, pitch_range: float = 0.05) -> void:
	if not enabled or not sounds.has(sfx_name):
		return
	var stream: AudioStream = sounds[sfx_name]
	var vol_db: float = sound_volumes.get(sfx_name, -5.0)
	for p in players:
		if not p.playing:
			p.stream = stream
			p.volume_db = vol_db
			p.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
			p.play()
			return
	# All busy, steal first player
	if players.size() > 0:
		players[0].stream = stream
		players[0].volume_db = vol_db
		players[0].pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
		players[0].play()

func play_engine_hum() -> void:
	# Permanently disabled: legacy 45Hz/90Hz procedural hum caused harsh buzzing.
	if ambient_player != null:
		ambient_player.stop()
		ambient_player.stream = null

func set_speed_pitch(_speed_ratio: float) -> void:
	pass
