class_name SaveCodec
extends RefCounted
## Estático y sin autoloads: lo usan el juego y el Save Inspector.

const VERSION := 1
const _PASS := "epiphany::d5be4747ab58940b749a5bb0214c37cc"
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


## El valor guardado, o `default` si falta o es de otro tipo (un cambio del esquema). int ↔ float y String ↔ StringName pasan.
static func typed(cfg: ConfigFile, section: String, key: String, default: Variant) -> Variant:
	var value: Variant = cfg.get_value(section, key, default)
	var want := typeof(default)
	var got := typeof(value)
	if got == want:
		return value
	if want == TYPE_FLOAT and got == TYPE_INT:
		return float(value)
	if want == TYPE_STRING_NAME and got == TYPE_STRING:
		return StringName(value)
	if want == TYPE_STRING and got == TYPE_STRING_NAME:
		return String(value)
	push_warning("[save] %s/%s: se esperaba %s y hay %s; queda el valor por defecto" % [section, key, type_string(want), type_string(got)])
	return default


## No bloquea la carga: se pueden forzar escenarios imposibles a propósito.
static func validate(cfg: ConfigFile) -> PackedStringArray:
	var errors := PackedStringArray()
	var db: ItemDatabase = load("res://data/item_database.tres")
	var flags: FlagRegistry = load("res://data/flag_registry.tres")
	if cfg.has_section("inventory"):
		for id in cfg.get_section_keys("inventory"):
			var item := db.get_item(id)
			var count: int = typed(cfg, "inventory", id, 0)
			if item == null:
				errors.append("inventory/%s: ítem inexistente" % id)
				continue
			var cap := item.max_stack
			for other_id in cfg.get_section_keys("inventory"):
				var other := db.get_item(other_id)
				if other and other.capacity_for and other.capacity_for.id == item.id and typed(cfg, "inventory", other_id, 0) > 0:
					cap += other.capacity_bonus
			if count < 0 or count > cap:
				errors.append("inventory/%s: %d fuera de rango (0..%d)" % [id, count, cap])
	if cfg.has_section("equipment"):
		for key in cfg.get_section_keys("equipment"):
			if key == "buttons":
				errors.append_array(_button_errors(cfg, db))
				continue
			var item := db.get_item(typed(cfg, "equipment", key, &""))
			if not ItemData.Category.has(key):
				errors.append("equipment/%s: categoría inexistente" % key)
			elif item == null:
				errors.append("equipment/%s: ítem inexistente" % key)
			elif item.category != ItemData.Category[key]:
				errors.append("equipment/%s: %s es de otra categoría" % [key, item.id])
	if cfg.has_section("flags"):
		for id in cfg.get_section_keys("flags"):
			if not flags.has(id):
				errors.append("flags/%s: flag no registrada" % id)
			elif typeof(cfg.get_value("flags", id)) != typeof(flags.default_of(id)):
				errors.append("flags/%s: no es del tipo de su valor por defecto" % id)
			elif id.ends_with("_boss_door") and cfg.get_value("flags", id) == true:
				var section := "dungeon_" + id.get_slice("_", 0)
				if not cfg.get_value(section, "has_boss_key", false):
					errors.append("flags/%s: la puerta del jefe está abierta pero %s no tiene la llave del jefe" % [id, section])
	return errors


static func _button_errors(cfg: ConfigFile, db: ItemDatabase) -> PackedStringArray:
	var errors := PackedStringArray()
	var buttons: Variant = cfg.get_value("equipment", "buttons")
	if not buttons is Array or (buttons as Array).size() != 2:
		return PackedStringArray(["equipment/buttons: tienen que ser dos"])
	for id: Variant in buttons:
		if str(id) == "":
			continue
		var item := db.get_item(id) if id is StringName or id is String else null
		if item == null:
			errors.append("equipment/buttons: %s no es un ítem" % [id])
		elif typed(cfg, "inventory", item.id, 0) <= 0:
			errors.append("equipment/buttons: %s no está en el inventario" % item.id)
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
