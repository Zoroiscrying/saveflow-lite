class_name SaveFlowSerializerAudioStreamPlayer2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "audio_stream_player_2d"


func get_display_name() -> String:
	return "AudioStreamPlayer2D"


func supports_node(node: Node) -> bool:
	return node is AudioStreamPlayer2D


func gather_from_node(node: Node) -> Variant:
	var target := node as AudioStreamPlayer2D
	if target == null:
		return {}
	return {
		"volume_db": target.volume_db,
		"pitch_scale": target.pitch_scale,
		"bus": target.bus,
		"stream_paused": target.stream_paused,
		"is_playing": target.playing,
		"playback_position": target.get_playback_position(),
		"max_distance": target.max_distance,
		"attenuation": target.attenuation,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as AudioStreamPlayer2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("max_distance"):
		target.max_distance = float(payload["max_distance"])
	if payload.has("attenuation"):
		target.attenuation = float(payload["attenuation"])
	SaveFlowSerializerAudioStreamPlayer._apply_audio_state(target, payload)
