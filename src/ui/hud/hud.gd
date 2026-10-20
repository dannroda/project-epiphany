class_name Hud
extends CanvasLayer
## HUD del juego: un panel por player (corazones, slots X/Y, prompt), llaves (solo en mazmorra) y la barra del
## jefe (mockup HUD_Boss). Jugando solo, el panel de siempre; en co-op uno compacto por player en cada esquina de
## arriba (mockup HUD_Coop), con las llaves compartidas al medio.

const GROUP := &"hud"

## Lo que el mundo le avisa al HUD sin buscarlo: `Hud.events.area_announced.emit(...)`.
class Events:
	signal area_announced(text: String)
	signal boss_shown(bar: BossBar)
	signal boss_hidden

static var events := Events.new()

@export var solo_panel: PackedScene
@export var coop_panel: PackedScene
@export var item_ring: PackedScene
## Del borde de la pantalla al anillo de ítems, que va debajo del panel de su player.
@export var ring_margin := Vector2(40, 150)
## Color de la etiqueta de cada player en co-op (P1, P2); el del modelo es de 13.6.
@export var player_colors: Array[Color] = [Color(0.85, 0.643, 0.255), Color(0.357, 0.608, 0.878)]

@onready var panels: HBoxContainer = %Panels
@onready var rings: Control = %Rings
@onready var slow_dim: ColorRect = %SlowDim
@onready var coop_keys: CenterContainer = %CoopKeys
@onready var keys: HBoxContainer = %Keys
@onready var small_key_count: Label = %SmallKeyCount
@onready var boss_key: TextureRect = %BossKey
@onready var boss_key_pieces: Label = %BossKeyPieces
@onready var area_name: HBoxContainer = %AreaName
@onready var area_label: Label = %AreaLabel
@onready var saved_label: Label = %Saved
@onready var boss_bar: VBoxContainer = %BossBar
@onready var boss_health: ProgressBar = %BossHealth
@onready var area_anim: AnimationPlayer = %AreaNameAnim
@onready var saved_anim: AnimationPlayer = %SavedAnim
@onready var boss_anim: AnimationPlayer = %BossBarAnim

## Los del primero (los tests y lo que sigue siendo de uno).
var hearts: Container:
	get: return _lead_panel().hearts
var item_slots: HBoxContainer:
	get: return _lead_panel().item_slots
var prompt: PanelContainer:
	get: return _lead_panel().prompt
var prompt_text: Label:
	get: return _lead_panel().prompt_text

var _dungeon: DungeonState
var _boss: BossBar
var _boss_tween: Tween


func _ready() -> void:
	add_to_group(GROUP)
	events.area_announced.connect(show_area_name)
	events.boss_shown.connect(show_boss)
	events.boss_hidden.connect(hide_boss)
	SaveManager.saved.connect(func(_slot: int) -> void: _flash_saved())
	GameState.dungeon_changed.connect(_bind_dungeon)
	GameState.loaded.connect(_bind_dungeon)
	Players.joined.connect(_on_players_changed)
	Players.left.connect(_on_players_changed)
	_bind_dungeon()
	_rebuild_panels.call_deferred()


func _on_players_changed(_player: PlayerCharacter) -> void:
	_rebuild_panels.call_deferred()


## El panel de cada player; los que pasan de dos esperan a que haya HUD para más (por ahora el co-op es de dos).
func panel_of(player: PlayerCharacter) -> PlayerPanel:
	for panel: PlayerPanel in panels.get_children():
		if panel.player == player:
			return panel
	return null


func _lead_panel() -> PlayerPanel:
	return panel_of(Players.lead()) if panels.get_child_count() > 0 else null


func _rebuild_panels() -> void:
	if not is_inside_tree():
		return
	var shown := Players.all.filter(func(player: PlayerCharacter) -> bool: return is_instance_valid(player) and not player.is_queued_for_deletion()).slice(0, player_colors.size())
	var coop := shown.size() > 1
	keys.reparent(coop_keys.get_node(^"Box"), false)
	for panel in panels.get_children():
		panels.remove_child(panel)
		panel.queue_free()
	for i in shown.size():
		var panel: PlayerPanel = (coop_panel if coop else solo_panel).instantiate()
		if coop and i % 2 == 1:
			panel.layout_direction = Control.LAYOUT_DIRECTION_RTL
		panels.add_child(panel)
		panel.bind(shown[i], player_colors[i])
	_rebuild_rings(shown)
	if not coop and panels.get_child_count() > 0:
		keys.reparent((panels.get_child(0) as PlayerPanel).keys_spot, false)
	coop_keys.visible = coop and _dungeon != null


## El anillo de cada player: jugando solo, del lado de los slots (derecha); en co-op, del lado de su panel.
func _rebuild_rings(shown: Array) -> void:
	for ring in rings.get_children():
		rings.remove_child(ring)
		ring.queue_free()
	var coop := shown.size() > 1
	for i in shown.size():
		var ring: ItemRing = item_ring.instantiate()
		rings.add_child(ring)
		var right := not coop or i % 2 == 1
		ring.set_anchors_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
		ring.position = Vector2(rings.size.x - ring_margin.x - ring.custom_minimum_size.x if right else ring_margin.x, ring_margin.y)
		ring.bind(shown[i], player_colors, coop)
		ring.opened.connect(_on_ring_toggled)
		ring.closed.connect(_on_ring_toggled)


## Jugando solo el mundo casi se detiene mientras el anillo está abierto: se oscurece para que se note.
func _on_ring_toggled() -> void:
	slow_dim.visible = Players.all.size() == 1 and rings.get_children().any(func(ring: ItemRing) -> bool: return ring.is_open())


func ring_of(player: PlayerCharacter) -> ItemRing:
	for ring: ItemRing in rings.get_children():
		if ring.player == player:
			return ring
	return null


## Nombre de la sala o la zona al entrar por primera vez: aparece, queda un rato y se va.
## Llaves: solo dentro de una mazmorra, siguiendo los cambios de su DungeonState.
func _bind_dungeon() -> void:
	if _dungeon and _dungeon.changed.is_connected(_refresh_keys):
		_dungeon.changed.disconnect(_refresh_keys)
	_dungeon = GameState.current_dungeon_state() if GameState.current_dungeon != &"" else null
	if _dungeon:
		_dungeon.changed.connect(_refresh_keys)
	_refresh_keys()


func _refresh_keys() -> void:
	keys.visible = _dungeon != null
	coop_keys.visible = _dungeon != null and panels.get_child_count() > 1
	if _dungeon:
		small_key_count.text = "×%d" % _dungeon.small_keys
		boss_key.modulate.a = 1.0 if _dungeon.has_boss_key else 0.35
		boss_key_pieces.visible = _dungeon.boss_key_pieces > 0 and not _dungeon.has_boss_key
		boss_key_pieces.text = "%d/%d" % [_dungeon.boss_key_pieces, GameState.PIECES_PER_BOSS_KEY]


func show_area_name(text: String) -> void:
	area_label.text = text
	_restart(area_anim, &"show")


func _flash_saved() -> void:
	_restart(saved_anim, &"flash")


## Arranca el clip donde su alfa vale lo que ya tiene el nodo, así re-mostrar o esconder a mitad no salta.
func _restart(player: AnimationPlayer, clip: StringName) -> void:
	var anim := player.get_animation(clip)
	var track := anim.find_track(^".:modulate:a", Animation.TYPE_VALUE)
	var node := player.get_node(player.root_node) as CanvasItem
	var alpha := node.modulate.a if node.visible else 0.0
	player.stop(true)
	player.play(clip)
	player.seek(_time_at(anim, track, alpha) if track >= 0 else 0.0, true)


func _time_at(anim: Animation, track: int, value: float) -> float:
	for k in anim.track_get_key_count(track):
		var here: float = anim.track_get_key_value(track, k)
		if is_equal_approx(here, value):
			return anim.track_get_key_time(track, k)
		if k + 1 < anim.track_get_key_count(track):
			var next: float = anim.track_get_key_value(track, k + 1)
			if (here - value) * (next - value) < 0.0:
				return lerpf(anim.track_get_key_time(track, k), anim.track_get_key_time(track, k + 1), (value - here) / (next - here))
	return 0.0



func show_boss(bar: BossBar) -> void:
	if _boss and _boss.changed.is_connected(_refresh_boss):
		_boss.changed.disconnect(_refresh_boss)
	_boss = bar
	%BossName.text = tr(bar.display_name)
	bar.changed.connect(_refresh_boss)
	boss_health.value = bar.fraction.call()
	_refresh_boss()
	_restart(boss_anim, &"show")
	boss_anim.advance(0.0)


func hide_boss() -> void:
	if _boss and _boss.changed.is_connected(_refresh_boss):
		_boss.changed.disconnect(_refresh_boss)
	_boss = null
	if boss_bar.visible and boss_anim.current_animation != &"hide":
		_restart(boss_anim, &"hide")


func _refresh_boss() -> void:
	if _boss == null:
		return
	var phase := _boss.phase()
	%BossPhase.text = tr("HUD_BOSS_PHASE").format({phase = phase})
	%BossPhase.visible = phase > 0
	if _boss_tween:
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_health, "value", _boss.fraction.call(), 0.25).set_ease(Tween.EASE_OUT)
