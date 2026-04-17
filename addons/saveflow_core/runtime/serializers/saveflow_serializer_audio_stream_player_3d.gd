class_name SaveFlowSerializerAudioStreamPlayer3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "audio_stream_player_3d"


func get_display_name() -> String:
	return "AudioStreamPlayer3D"


func supports_node(node: Node) -> bool:
	return node is AudioStreamPlayer3D


func gather_from_node(node: Node) -> Variant:
	var target := node as AudioStreamPlayer3D
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
		"attenuation_model": target.attenuation_model,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as AudioStreamPlayer3D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("max_distance"):
		target.max_distance = float(payload["max_distance"])
	if payload.has("attenuation_model"):
		target.attenuation_model = int(payload["attenuation_model"]) as AudioStreamPlayer3D.AttenuationModel
	SaveFlowSerializerAudioStreamPlayer._apply_audio_state(target, payload)
