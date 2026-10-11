class_name BuildInfo
## Versión visible del juego. `tools/build.sh` escribe `res://build_info.cfg` al exportar; en el editor no existe.

const PATH := "res://build_info.cfg"


static func label() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.1"))
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return "v%s-dev" % version
	var text := "v%s.%s (%s%s)" % [version, cfg.get_value("build", "number", 0), cfg.get_value("build", "commit", "?"), "*" if cfg.get_value("build", "dirty", false) else ""]
	if OS.is_debug_build():
		text += " debug"
	return text
