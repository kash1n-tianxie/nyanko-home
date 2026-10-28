extends SceneTree
## Import settings are part of the published source, including looping music.
func _initialize() -> void:
	var failures: Array[String]=[]
	for path: String in ["res://audio/v04/title.ogg", "res://audio/new-v025/day.ogg", "res://audio/new-v025/noon.ogg", "res://audio/new-v025/dusk.ogg"]:
		var music: AudioStreamOggVorbis=load(path) as AudioStreamOggVorbis
		if music==null or not music.loop: failures.append(path)
	print("V041_AUDIO_LOOPS ",JSON.stringify({"checks":4,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
