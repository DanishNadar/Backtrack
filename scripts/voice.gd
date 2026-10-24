class_name Voice
extends RefCounted
## Recorded voice lines live in public/voice/, one file per line, named by the
## line's id (every file name is listed in public/voice/README.md). A line with no
## recording yet is simply silent.

const DIR := "res://public/voice/"
const EXTENSIONS := ["wav", "ogg", "mp3"]


## The recording for `id`, or null if it hasn't been recorded yet.
static func load_line(id: String) -> AudioStream:
	for ext in EXTENSIONS:
		var path: String = DIR + id + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Id of a cutscene beat: "<scene>_<beat number>_<speaker>", where lines with
## no speaker are read by the narrator. For example "awakening_03_doctor".
static func beat_id(scene: String, index: int, beat: Dictionary) -> String:
	var speaker: String = beat.get("speaker", "narrator")
	return "%s_%02d_%s" % [scene, index + 1, speaker.to_lower()]
