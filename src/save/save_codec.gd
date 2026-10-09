class_name SaveCodec
extends RefCounted
## Estático y sin autoloads: lo usan el juego y el Save Inspector.

const VERSION := 1
const _PASS := "epiphany::change-me-before-release"
const _ENCRYPTED_MAGIC := "GDEC"


static func plain_saves() -> bool:
	return OS.has_feature("editor") or OS.has_feature("plain_saves")


## Escribe a .tmp, pasa la partida anterior a .bak y renombra: un corte a mitad de camino no deja una partida rota.
static func write(cfg: ConfigFile, path: String, keep_backup := true) -> Error:
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "timestamp", Time.get_unix_time_from_system())
	cfg.set_value("meta", "checksum", checksum(cfg))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var err := cfg.save(tmp) if plain_saves() else cfg.save_encrypted_pass(tmp, _PASS)
	if err != OK:
		return err
	if FileAccess.file_exists(path) and not keep_backup:
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		err = DirAccess.rename_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, path)


## Si la partida no carga, prueba con el .bak.
static func read(path: String, cfg: ConfigFile) -> Error:
	var err := _read_file(path, cfg)
	if err != OK and FileAccess.file_exists(path + ".bak"):
		cfg.clear()
		err = _read_file(path + ".bak", cfg)
		if err == OK:
			push_warning("[save] %s no cargó; se usó la copia de respaldo" % path)
	return err


static func checksum(cfg: ConfigFile) -> String:
	var parts := PackedStringArray()
	for section in cfg.get_sections():
		if section == "meta":
			continue
		for key in cfg.get_section_keys(section):
			parts.append("%s/%s=%s" % [section, key, var_to_str(cfg.get_value(section, key))])
	parts.sort()
	return ("|".join(parts) + _PASS).sha256_text()


static func is_tampered(cfg: ConfigFile) -> bool:
	return cfg.get_value("meta", "checksum", "") != checksum(cfg)


## No bloquea la carga: se pueden forzar escenarios imposibles a propósito.
static func validate(cfg: ConfigFile) -> PackedStringArray:
	var errors := PackedStringArray()
	var db: ItemDatabase = load("res://data/item_database.tres")
	var flags: FlagRegistry = load("res://data/flag_registry.tres")
	if cfg.has_section("inventory"):
		for id in cfg.get_section_keys("inventory"):
			var item := db.get_item(id)
			var count: int = cfg.get_value("inventory", id)
			if item == null:
				errors.append("inventory/%s: ítem inexistente" % id)
			elif count < 0 or count > item.max_stack:
				errors.append("inventory/%s: %d fuera de rango (0..%d)" % [id, count, item.max_stack])
	if cfg.has_section("flags"):
		for id in cfg.get_section_keys("flags"):
			if not flags.has(id):
				errors.append("flags/%s: flag no registrada" % id)
			elif id.ends_with("_boss_door") and cfg.get_value("flags", id) == true:
				var section := "dungeon_" + id.get_slice("_", 0)
				if not cfg.get_value(section, "has_boss_key", false):
					errors.append("flags/%s: la puerta del jefe está abierta pero %s no tiene la llave del jefe" % [id, section])
	return errors


static func _read_file(path: String, cfg: ConfigFile) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var encrypted := file.get_buffer(4).get_string_from_ascii() == _ENCRYPTED_MAGIC
	file.close()
	if encrypted:
		return cfg.load_encrypted_pass(path, _PASS)
	return cfg.load(path) if plain_saves() else ERR_FILE_UNRECOGNIZED
