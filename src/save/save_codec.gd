class_name SaveCodec
extends RefCounted
## Estático y sin autoloads: lo usan el juego y el Save Inspector.

## 2: las pociones, el agua bendita y las botellas vacías van en botellas únicas (bottle_1..4).
const VERSION := 2
## Ids viejos → nuevos: un save con el viejo no pierde ese progreso. Se aplican siempre, en cualquier versión.
const FLAG_RENAMES: Dictionary[String, String] = {}
const ITEM_RENAMES: Dictionary[String, String] = {}
const _PASS := "epiphany::d5be4747ab58940b749a5bb0214c37cc"
const _ENCRYPTED_MAGIC := "GDEC"


static func plain_saves() -> bool:
	return OS.has_feature("editor") or OS.has_feature("plain_saves")


## Escribe a .tmp, pasa la partida anterior a .bak y renombra: un corte a mitad de camino no deja una partida rota.
static func write(cfg: ConfigFile, path: String, keep_backup := true) -> Error:
	cfg.set_value(SaveKeys.META, SaveKeys.VERSION, VERSION)
	cfg.set_value(SaveKeys.META, SaveKeys.TIMESTAMP, Time.get_unix_time_from_system())
	cfg.set_value(SaveKeys.META, SaveKeys.CHECKSUM, checksum(cfg))
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


## Lleva la partida a VERSION. Una más nueva que el juego no se toca (la rechaza quien carga).
static func migrate(cfg: ConfigFile) -> void:
	var from: int = typed(cfg, SaveKeys.META, SaveKeys.VERSION, 0)
	if from > VERSION:
		return
	_rename(cfg)
	if from < 2:
		_bottles_v2(cfg)
	cfg.set_value(SaveKeys.META, SaveKeys.VERSION, VERSION)


static func _rename(cfg: ConfigFile) -> void:
	for old in FLAG_RENAMES:
		if cfg.has_section_key(SaveKeys.FLAGS, old):
			cfg.set_value(SaveKeys.FLAGS, FLAG_RENAMES[old], cfg.get_value(SaveKeys.FLAGS, old))
			cfg.erase_section_key(SaveKeys.FLAGS, old)
	for old in ITEM_RENAMES:
		var new := ITEM_RENAMES[old]
		if cfg.has_section_key(SaveKeys.INVENTORY, old):
			cfg.set_value(SaveKeys.INVENTORY, new, cfg.get_value(SaveKeys.INVENTORY, old))
			cfg.erase_section_key(SaveKeys.INVENTORY, old)
		for section in [SaveKeys.EQUIPMENT, SaveKeys.BOTTLES]:
			if not cfg.has_section(section):
				continue
			for key in cfg.get_section_keys(section):
				if str(cfg.get_value(section, key)) == old:
					cfg.set_value(section, key, StringName(new))
		var buttons: Variant = cfg.get_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, null)
		if buttons is Array:
			cfg.set_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, (buttons as Array).map(func(id: Variant) -> Variant:
				return StringName(new) if str(id) == old else id))


## Cada unidad de un ítem bottled pasa a una botella: llena primero una vacía, si no ocupa una nueva. El botón que lo
## tenía pasa a la primera.
static func _bottles_v2(cfg: ConfigFile) -> void:
	if not cfg.has_section(SaveKeys.INVENTORY):
		return
	var db: ItemDatabase = load(ItemDatabase.PATH)
	var bottles := {}
	if cfg.has_section(SaveKeys.BOTTLES):
		for bottle in cfg.get_section_keys(SaveKeys.BOTTLES):
			bottles[StringName(bottle)] = StringName(str(cfg.get_value(SaveKeys.BOTTLES, bottle)))
	var buttons: Variant = cfg.get_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, null)
	for id in cfg.get_section_keys(SaveKeys.INVENTORY):
		var item := db.get_item(id)
		if item == null or not item.bottled:
			continue
		var count: int = typed(cfg, SaveKeys.INVENTORY, id, 0)
		cfg.erase_section_key(SaveKeys.INVENTORY, id)
		for i in count:
			var bottle := _bottle_for(bottles, item.id)
			if bottle == &"":
				break
			if not bottles.has(bottle):
				cfg.set_value(SaveKeys.INVENTORY, bottle, 1)
			bottles[bottle] = item.id
			if buttons is Array:
				var index := (buttons as Array).map(func(button: Variant) -> String: return str(button)).find(id)
				if index >= 0:
					buttons[index] = bottle
	for bottle in bottles:
		cfg.set_value(SaveKeys.BOTTLES, bottle, bottles[bottle])
	if buttons is Array:
		cfg.set_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS, buttons)


static func _bottle_for(bottles: Dictionary, content: StringName) -> StringName:
	if content != ItemDatabase.EMPTY_BOTTLE:
		for bottle in ItemDatabase.BOTTLES:
			if bottles.get(bottle, &"") == ItemDatabase.EMPTY_BOTTLE:
				return bottle
	for bottle in ItemDatabase.BOTTLES:
		if not bottles.has(bottle):
			return bottle
	return &""


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
		if section == SaveKeys.META:
			continue
		for key in cfg.get_section_keys(section):
			parts.append("%s/%s=%s" % [section, key, var_to_str(cfg.get_value(section, key))])
	parts.sort()
	return ("|".join(parts) + _PASS).sha256_text()


static func is_tampered(cfg: ConfigFile) -> bool:
	return cfg.get_value(SaveKeys.META, SaveKeys.CHECKSUM, "") != checksum(cfg)


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
	var db: ItemDatabase = load(ItemDatabase.PATH)
	var flags: FlagRegistry = load(FlagRegistry.PATH)
	if cfg.has_section(SaveKeys.INVENTORY):
		for id in cfg.get_section_keys(SaveKeys.INVENTORY):
			var item := db.get_item(id)
			var count: int = typed(cfg, SaveKeys.INVENTORY, id, 0)
			if item == null:
				errors.append("inventory/%s: ítem inexistente" % id)
				continue
			var cap := db.capacity(item.id, func(owned: StringName) -> bool: return typed(cfg, SaveKeys.INVENTORY, owned, 0) > 0)
			if count < 0 or count > cap:
				errors.append("inventory/%s: %d fuera de rango (0..%d)" % [id, count, cap])
	if cfg.has_section(SaveKeys.EQUIPMENT):
		for key in cfg.get_section_keys(SaveKeys.EQUIPMENT):
			if key == SaveKeys.BUTTONS:
				errors.append_array(_button_errors(cfg, db))
				continue
			var item := db.get_item(typed(cfg, SaveKeys.EQUIPMENT, key, &""))
			if not ItemData.Category.has(key):
				errors.append("equipment/%s: categoría inexistente" % key)
			elif item == null:
				errors.append("equipment/%s: ítem inexistente" % key)
			elif item.category != ItemData.Category[key]:
				errors.append("equipment/%s: %s es de otra categoría" % [key, item.id])
	if cfg.has_section(SaveKeys.FLAGS):
		for id in cfg.get_section_keys(SaveKeys.FLAGS):
			if not flags.has(id):
				errors.append("flags/%s: flag no registrada" % id)
			elif typeof(cfg.get_value(SaveKeys.FLAGS, id)) != typeof(flags.default_of(id)):
				errors.append("flags/%s: no es del tipo de su valor por defecto" % id)
			elif id.ends_with("_boss_door") and cfg.get_value(SaveKeys.FLAGS, id) == true:
				var section := SaveKeys.dungeon_section(id.get_slice("_", 0))
				if not cfg.get_value(section, SaveKeys.HAS_BOSS_KEY, false):
					errors.append("flags/%s: la puerta del jefe está abierta pero %s no tiene la llave del jefe" % [id, section])
	return errors


static func _button_errors(cfg: ConfigFile, db: ItemDatabase) -> PackedStringArray:
	var errors := PackedStringArray()
	var buttons: Variant = cfg.get_value(SaveKeys.EQUIPMENT, SaveKeys.BUTTONS)
	if not buttons is Array or (buttons as Array).size() != 2:
		return PackedStringArray(["equipment/buttons: tienen que ser dos"])
	for id: Variant in buttons:
		if str(id) == "":
			continue
		var item := db.get_item(id) if id is StringName or id is String else null
		if item == null:
			errors.append("equipment/buttons: %s no es un ítem" % [id])
		elif typed(cfg, SaveKeys.INVENTORY, item.id, 0) <= 0:
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
