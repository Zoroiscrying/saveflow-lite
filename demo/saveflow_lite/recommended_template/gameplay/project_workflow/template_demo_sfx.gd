extends Node

const SAMPLE_RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next_player_index := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for index in range(3):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func play_ui_toggle() -> void:
	_play_tone(520.0, 0.05, 0.16)


func play_save() -> void:
	_play_chord([660.0, 880.0], 0.07, 0.18)


func play_manual_save() -> void:
	_play_chord([784.0, 988.0, 1174.0], 0.09, 0.16)


func play_load() -> void:
	_play_chord([520.0, 660.0], 0.08, 0.16)


func play_mutate() -> void:
	_play_tone(360.0, 0.09, 0.17)


func play_event() -> void:
	_play_chord([740.0, 988.0], 0.1, 0.18)


func play_pickup() -> void:
	_play_chord([392.0, 523.0], 0.08, 0.10)


func play_reset() -> void:
	_play_tone(280.0, 0.12, 0.16)


func play_move_tick() -> void:
	_play_tone(220.0, 0.03, 0.06)


func _play_chord(frequencies: Array, duration: float, amplitude: float) -> void:
	if frequencies.is_empty():
		return
	for frequency_variant in frequencies:
		_play_tone(float(frequency_variant), duration, amplitude)


func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
	if _players.is_empty():
		return
	var stream := _get_stream(frequency, duration, amplitude)
	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.play()


func _get_stream(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var cache_key := "%s:%s:%s" % [snappedf(frequency, 0.1), snappedf(duration, 0.01), snappedf(amplitude, 0.01)]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var frame_count: int = maxi(1, int(SAMPLE_RATE * duration))
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame in range(frame_count):
		var t := float(frame) / SAMPLE_RATE
		var envelope := sin(min(1.0, t / duration) * PI)
		var sample := sin(TAU * frequency * t) * amplitude * envelope
		var pcm := int(clampi(int(sample * 32767.0), -32767, 32767))
		var unsigned_value := pcm if pcm >= 0 else 65536 + pcm
		data[frame * 2] = unsigned_value & 0xFF
		data[frame * 2 + 1] = (unsigned_value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	_cache[cache_key] = stream
	return stream
