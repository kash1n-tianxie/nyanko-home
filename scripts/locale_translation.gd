extends Translation
## Godot keeps Label/Button source text untouched, including saved gameplay data.
const Locale = preload("res://scripts/game_locale.gd")
func _get_message(src_message: StringName, _context: StringName) -> StringName:
 return StringName(Locale.text(str(src_message)))
