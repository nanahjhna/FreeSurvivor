extends Node

## Centralized one-shot sound effects.
## Village and dungeon background music are intentionally not loaded here.

const SOUND_ROOT := "res://assets/audio/sfx/"

var _streams: Dictionary = {}
var _last_played_ms: Dictionary = {}
var _throttle_ms: Dictionary = {
	"hit_light": 55,
	"hit_heavy": 75,
	"hit_crit": 110,
	"pickup": 45,
}

func _ready() -> void:
	_ensure_audio_buses()

func _ensure_audio_buses() -> void:
	# Settings already exposes BGM/SFX volume controls. Keep the buses available
	# without adding any background music content.
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func play(sound_id: String, volume_db: float = 0.0) -> void:
	if not _can_play(sound_id):
		return
	var stream := _load_stream(sound_id)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_3d(sound_id: String, world_position: Vector3, volume_db: float = 0.0, unit_size: float = 8.0) -> void:
	if not _can_play(sound_id):
		return
	var stream := _load_stream(sound_id)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()

func _load_stream(sound_id: String) -> AudioStream:
	if _streams.has(sound_id):
		return _streams[sound_id] as AudioStream
	var path := SOUND_ROOT + sound_id + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("SFX 리소스를 찾을 수 없습니다: %s" % path)
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream:
		_streams[sound_id] = stream
	return stream

func _can_play(sound_id: String) -> bool:
	var now := Time.get_ticks_msec()
	var last := int(_last_played_ms.get(sound_id, -1000000))
	var limit := int(_throttle_ms.get(sound_id, 0))
	if now - last < limit:
		return false
	_last_played_ms[sound_id] = now
	return true
