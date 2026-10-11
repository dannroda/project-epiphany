extends Control
## Pestaña Equipo: ranuras por categoría, detalle del ítem enfocado, stats y preview del modelo.

const SECTIONS := { ^"Sword": ItemData.Category.SWORD, ^"Shield": ItemData.Category.SHIELD, ^"Armor": ItemData.Category.ARMOR }
const CATEGORY_NAMES := { ItemData.Category.SWORD: "EQUIP_CATEGORY_SWORD", ItemData.Category.SHIELD: "EQUIP_CATEGORY_SHIELD", ItemData.Category.ARMOR: "EQUIP_CATEGORY_ARMOR" }
const LOCK := preload("res://assets/ui/lock.svg")
const HP_PER_HEART := 4

## Lo lee el menú de pausa para la ayuda del botón de aceptar.
var accept_label := "EQUIP_ACCEPT"

@onready var rows: VBoxContainer = %Rows
@onready var preview_root: Node3D = %PreviewRoot
@onready var hearts: HFlowContainer = %Hearts
@onready var damage_value: Label = %DamageValue
@onready var reduction_value: Label = %ReductionValue
@onready var pieces_icon: HeartPieceIcon = %PiecesIcon
@onready var pieces_value: Label = %PiecesValue
@onready var detail: PanelContainer = %Detail

var _slots: Dictionary[Button, ItemData] = {}
var _preview_model: Node3D


func _ready() -> void:
	_bind_slots()
	GameState.equipment_changed.connect(func(_c: ItemData.Category, _id: StringName) -> void: _refresh.call_deferred())
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh.call_deferred()


func focus_default() -> void:
	for slot in _slots:
		if _is_equipped(_slots[slot]):
			slot.grab_focus()
			return


func _process(delta: float) -> void:
	if _preview_model:
		_preview_model.rotate_y(delta * 0.8)


func _bind_slots() -> void:
	for section: NodePath in SECTIONS:
		var category: ItemData.Category = SECTIONS[section]
		var items := Items.database.items.filter(func(item: ItemData) -> bool: return item.category == category)
		var line := rows.get_node(section).get_node(^"Line")
		for i in line.get_child_count():
			var slot := line.get_child(i) as Button
			if i < items.size():
				_slots[slot] = items[i]
				slot.pressed.connect(_equip.bind(items[i]))
			else:
				slot.disabled = true
				slot.icon = LOCK
			slot.focus_entered.connect(_show_detail.bind(slot))
			slot.mouse_entered.connect(slot.grab_focus)


func _refresh() -> void:
	for slot in _slots:
		var item := _slots[slot]
		var owned := GameState.inventory.has(item.id)
		slot.disabled = not owned
		slot.icon = item.icon if owned else LOCK
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
	(slot.get_node(^"Badge") as Label).visible = equipped


func _show_detail(slot: Button) -> void:
	var item: ItemData = _slots.get(slot)
	if item == null or not GameState.inventory.has(item.id):
		detail.show_item(LOCK, "EQUIP_UNDISCOVERED", "", "EQUIP_UNDISCOVERED_DESC")
		return
	var kind := tr(CATEGORY_NAMES[item.category])
	if _is_equipped(item):
		kind = tr("EQUIP_KIND_EQUIPPED").format({category = kind})
	detail.show_item(item.icon, item.display_name, kind, item.description)
	match item.category:
		ItemData.Category.SWORD:
			detail.add_stat("EQUIP_STAT_DAMAGE", _hearts_text(item.damage))
		ItemData.Category.SHIELD:
			detail.add_stat("EQUIP_STAT_BLOCK", "EQUIP_BLOCK_FRONTAL")
			detail.add_stat("EQUIP_STAT_REFLECTS", "EQUIP_REFLECTS_PROJECTILES" if item.reflects else "COMMON_NO")
		ItemData.Category.ARMOR:
			detail.add_stat("EQUIP_STAT_REDUCTION", "%d %%" % roundi(item.damage_reduction * 100))


func _refresh_stats() -> void:
	var sword := _equipped_item(ItemData.Category.SWORD)
	var armor := _equipped_item(ItemData.Category.ARMOR)
	damage_value.text = _hearts_text(sword.damage if sword else 0)
	reduction_value.text = "%d %%" % roundi((armor.damage_reduction if armor else 0.0) * 100)
	pieces_icon.pieces = GameState.heart_pieces()
	pieces_value.text = "%d / %d" % [GameState.heart_pieces(), GameState.PIECES_PER_HEART]
	for child in hearts.get_children():
		child.queue_free()
	var player := Players.lead()
	var current: int = player.health.current if player else GameState.max_health
	var count := ceili(GameState.max_health / float(HP_PER_HEART))
	for i in count:
		var filled := clampi(current - i * HP_PER_HEART, 0, HP_PER_HEART)
		hearts.add_child(HeartIcon.create(filled, HeartIcon.SIZE * (1.0 if count <= 8 else 0.8)))


func _equipped_item(category: ItemData.Category) -> ItemData:
	var id: StringName = GameState.equipment.get(category, &"")
	return Items.get_item(id) if id != &"" else null


func _hearts_text(hp: int) -> String:
	var hearts_count := hp / float(HP_PER_HEART)
	if is_equal_approx(hearts_count, 1.0):
		return tr("EQUIP_HEARTS_ONE")
	if hearts_count < 1.0:
		return tr({0.25: "EQUIP_HEARTS_QUARTER", 0.5: "EQUIP_HEARTS_HALF", 0.75: "EQUIP_HEARTS_THREE_QUARTERS"}.get(snappedf(hearts_count, 0.25), "—"))
	return tr("EQUIP_HEARTS").format({hearts = str(snappedf(hearts_count, 0.25))})


## Copia del modelo del player con el equipo actual, girando en un SubViewport propio.
func _refresh_preview() -> void:
	if _preview_model:
		_preview_model.queue_free()
		_preview_model = null
	var player := Players.lead()
	if player == null:
		return
	_preview_model = player.model.duplicate() as Node3D
	for path in [^"Hitboxes", ^"AnimationTree", ^"Visuals/HitFlash"]:
		var node := _preview_model.get_node_or_null(path)
		if node:
			node.free()
	for mesh in _preview_model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = null
	_preview_model.transform = Transform3D.IDENTITY
	preview_root.add_child(_preview_model)
	var anim := _preview_model.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim:
		anim.play(&"General/Idle_A")
