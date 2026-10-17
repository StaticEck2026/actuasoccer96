extends SceneTree
# Loads every script under res://scripts so that parse/compile errors are reported.
func _init():
	var bad := 0
	for d in ["res://scripts/core", "res://scripts/game", "res://scripts/render", "res://scripts/frontend", "res://scripts"]:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("FAIL ", d + "/" + f)
					bad += 1
	print("OK compile check, failures: ", bad)
	quit()
