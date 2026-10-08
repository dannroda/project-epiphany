extends Control
## Pestaña Equipo: ranuras por categoría, detalle del ítem enfocado, stats y preview del modelo.

const SLOTS_PER_ROW := 4
const ROWS := [[ItemData.Category.SWORD, "ESPADA"], [ItemData.Category.SHIELD, "ESCUDO"], [ItemData.Category.ARMOR, "ARMADURA"]]
const CATEGORY_NAMES := { ItemData.Category.SWORD: "Espada", ItemData.Category.SHIELD: "Escudo", ItemData.Category.ARMOR: "Armadura" }
const LOCK := preload("res://assets/ui/lock.svg")
const HP_PER_HEART := 4

## Lo lee el menú de pausa para la ayuda del botón de aceptar.
var accept_label := "Equipar"

@onready var rows: VBoxContainer = %Rows
@onready var preview_root: Node3D = %PreviewRoot
@onready var hearts: HBoxContainer = %Hearts
@onready var damage_value: Label = %DamageValue
@onready var reduction_value: Label = %ReductionValue
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_kind: Label = %DetailKind
@onready var detail_text: Label = %DetailText
@onready var detail_stats: VBoxContainer = %DetailStats

var _slots: Dictionary[Button, ItemData] = {}
var _preview_model: Node3D


func _ready() -> void:
	_build_rows()
	GameState.equipment_changed.connect(func(_c: ItemData.Category, _id: StringName) -> void: _refresh.call_deferred())
	_refresh()


func focus_default() -> void:
	for slot in _slots:
		if _is_equipped(_slots[slot]):
			slot.grab_focus()
			return


func _process(delta: float) -> void:
	if _preview_model:
		_preview_model.rotate_y(delta * 0.8)


func _build_rows() -> void:
	for row in ROWS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 10)
		var title := Label.new()
		title.text = row[1]
		title.theme_type_variation = &"Caps"
		box.add_child(title)
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 14)
		var items := Items.database.items.filter(func(item: ItemData) -> bool: return item.category == row[0])
		for i in SLOTS_PER_ROW:
			var slot := Button.new()
			slot.custom_minimum_size = Vector2(96, 96)
			slot.theme_type_variation = &"EquipSlot"
			slot.expand_icon = true
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.focus_mode = FOCUS_ALL
			line.add_child(slot)
			if i < items.size():
				_slots[slot] = items[i]
				slot.pressed.connect(_equip.bind(items[i]))
			else:
				slot.disabled = true
				slot.icon = LOCK
			slot.focus_entered.connect(_show_detail.bind(slot))
			slot.mouse_entered.connect(slot.grab_focus)
		box.add_child(line)
		rows.add_child(box)


func _refresh() -> void:
	for slot in _slots:
		var item := _slots[slot]
		var owned := GameState.inventory.has(item.id)
		slot.disabled = not owned
		slot.icon = item.icon if owned else LOCK
		slot.text = ""
		_set_badge(slot, _is_equipped(item))
	_refresh_stats()
	_refresh_preview()
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused and (_slots.has(focused) or focused.get_parent().get_parent() in rows.get_children()):
		_show_detail(focused)


func _is_equipped(item: ItemData) -> bool:
	return GameState.equipment.get(item.category, &"") == item.id


func _equip(item: ItemData) -> void:
	if GameState.inventory.has(item.id) and not _is_equipped(item):
		GameState.equip(item)


func _set_badge(slot: Button, equipped: bool) -> void:
	var badge := slot.get_node_or_null(^"Badge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "Badge"
		badge.text = "E"
		badge.theme_type_variation = &"KeyHint"
		badge.position = Vector2(6, 6)
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		slot.add_child(badge)
	badge.visible = equipped


func _show_detail(slot: Button) -> void:
	for child in detail_stats.get_children():
		child.queue_free()
	var item: ItemData = _slots.get(slot)
	if item == null or not GameState.inventory.has(item.id):
		detail_icon.texture = LOCK
		detail_name.text = "Sin descubrir"
		detail_kind.text = ""
		detail_text.text = "Todavía no encontraste este equipo."
		return
	detail_icon.texture = item.icon
	detail_name.text = item.display_name
	detail_kind.text = "%s%s" % [CATEGORY_NAMES[item.category], " · equipado" if _is_equipped(item) else ""]
	detail_text.text = item.description
	match item.category:
		ItemData.Category.SWORD:
			_stat("Daño", _hearts_text(item.damage))
		ItemData.Category.SHIELD:
			_stat("Bloqueo", "Frontal ±60°")
			_stat("Refleja", "Proyectiles y luz" if item.reflects else "No")
		ItemData.Category.ARMOR:
			_stat("Reducción de daño", "%d %%" % roundi(item.damage_reduction * 100))


func _stat(label: String, value: String) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.theme_type_variation = &"Hint"
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	row.add_child(value_label)
	detail_stats.add_child(row)


func _refresh_stats() -> void:
	var sword := _equipped_item(ItemData.Category.SWORD)
	var armor := _equipped_item(ItemData.Category.ARMOR)
	damage_value.text = _hearts_text(sword.damage if sword else 0)
	reduction_value.text = "%d %%" % roundi((armor.damage_reduction if armor else 0.0) * 100)
	for child in hearts.get_children():
		child.queue_free()
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	var current: int = player.health.current if player else GameState.max_health
	for i in ceili(GameState.max_health / float(HP_PER_HEART)):
		var heart := HeartIcon.new()
		heart.quarters = clampi(current - i * HP_PER_HEART, 0, HP_PER_HEART)
		hearts.add_child(heart)


func _equipped_item(category: ItemData.Category) -> ItemData:
	var id: StringName = GameState.equipment.get(category, &"")
	return Items.get_item(id) if id != &"" else null


func _hearts_text(hp: int) -> String:
	var hearts_count := hp / float(HP_PER_HEART)
	if is_equal_approx(hearts_count, 1.0):
		return "1 corazón"
	if hearts_count < 1.0:
		return {0.25: "¼ de corazón", 0.5: "½ corazón", 0.75: "¾ de corazón"}.get(snappedf(hearts_count, 0.25), "—")
	return "%s corazones" % str(snappedf(hearts_count, 0.25))


## Copia del modelo del player con el equipo actual, girando en un SubViewport propio.
func _refresh_preview() -> void:
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player == null:
		return
	_preview_model = player.model.duplicate() as Node3D
	for path in [^"Hitboxes", ^"AnimationTree", ^"Visuals/HitFlash"]:
		var node := _preview_model.get_node_or_null(path)
		if node:
			node.free()
	_preview_model.transform = Transform3D.IDENTITY
	preview_root.add_child(_preview_model)
	var anim := _preview_model.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim:
		anim.play(&"General/Idle_A")
