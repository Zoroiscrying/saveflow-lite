class_name SaveFlowSerializerAudioStreamPlayer
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "audio_stream_player"


func get_display_name() -> String:
	return "AudioStreamPlayer"


func supports_node(node: Node) -> bool:
	return node is AudioStreamPlayer and not (node is AudioStreamPlayer2D) and not (node is AudioStreamPlayer3D)


func gather_from_node(node: Node) -> Variant:
	var target := node as AudioStreamPlayer
	if target == null:
		return {}
	return {
		"volume_db": target.volume_db,
		"pitch_scale": target.pitch_scale,
		"bus": target.bus,
		"stream_paused": target.stream_paused,
		"is_playing": target.playing,
		"playback_position": target.get_playback_position(),
	}


func apply_to_node(node: Node, data: Variant) -> void:
	_apply_audio_state(node as AudioStreamPlayer, data)


static func _apply_audio_state(target: Object, data: Variant) -> void:
	if target == null:
		return
	if not (data is Dictionary):
		return
	var payload: Dictionary = data
	if payload.has("volume_db"):
		target.set("volume_db", float(payload["volume_db"]))
	if payload.has("pitch_scale"):
		target.set("pitch_scale", float(payload["pitch_scale"]))
	if payload.has("bus"):
		target.set("bus", String(payload["bus"]))
	if payload.has("stream_paused"):
		target.set("stream_paused", bool(payload["stream_paused"]))

	var should_play: bool = bool(payload.get("is_playing", false))
	var playback_position: float = max(0.0, float(payload.get("playback_position", 0.0)))
	if should_play:
		if target.has_method("play"):
			target.call("play", playback_position)
		return
	if target.has_method("stop"):
		target.call("stop")
