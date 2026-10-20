extends SceneTree
## Arma player/animation/libs/Combo.res: los golpes 2 y 3 del combo de espada salen de donde terminó el anterior.
## Backhand: desde la pose del tajo (Slice_Diagonal) donde se encadena, barre de derecha a izquierda (el barrido de
## Slice_Horizontal al revés), sigue sobre el hombro izquierdo y vuelve a la guardia. Thrust: desde el revés encadenado
## pasa a la carga de Melee_1H_Attack_Stab y sigue con la estocada. Mismo largo que los clips que reemplazan, así las
## ventanas de AttackData no cambian.
## godot --headless --path . --script res://tools/build_combo_library.gd

const SOURCE := "res://player/animation/libs/CombatMelee.res"
const OUTPUT := "res://player/animation/libs/Combo.res"
const FPS := 30.0
const DIAGONAL := &"Melee_1H_Attack_Slice_Diagonal"
const HORIZONTAL := &"Melee_1H_Attack_Slice_Horizontal"
const STAB := &"Melee_1H_Attack_Stab"
## Donde se encadena el golpe siguiente: el cancel_from de sword_slash y de sword_backhand.
const SLASH_CHAIN := 0.55
const BACKHAND_CHAIN := 0.45

var _source: AnimationLibrary
var _made := {}


func _initialize() -> void:
	_source = load(SOURCE)
	var lib := AnimationLibrary.new()
	# Tramos en fracción del largo: [desde, hasta, de, a], con de/a = [clip, fracción]; un tramo con el mismo clip lo
	# recorre, uno con clips distintos mezcla las dos poses.
	_made[&"Backhand"] = _build(_clip(HORIZONTAL).length, [
		[0.0, 0.2, [DIAGONAL, SLASH_CHAIN], [HORIZONTAL, 0.33]],
		[0.2, 0.4, [HORIZONTAL, 0.33], [HORIZONTAL, 0.11]],
		[0.4, 0.62, [HORIZONTAL, 0.11], [HORIZONTAL, 0.09]],
		[0.62, 0.85, [HORIZONTAL, 0.09], [HORIZONTAL, 0.0]],
		[0.85, 1.0, [HORIZONTAL, 0.0], [HORIZONTAL, 0.0]],
	])
	lib.add_animation(&"Backhand", _made[&"Backhand"])
	_made[&"Thrust"] = _build(_clip(STAB).length, [
		[0.0, 0.2, [&"Backhand", BACKHAND_CHAIN], [STAB, 0.2]],
		[0.2, 1.0, [STAB, 0.2], [STAB, 1.0]],
	])
	lib.add_animation(&"Thrust", _made[&"Thrust"])
	var uid := ResourceLoader.get_resource_uid(OUTPUT)
	var err := ResourceSaver.save(lib, OUTPUT)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUTPUT, uid)
	print("combo_library: ", error_string(err), " · ", lib.get_animation_list())
	quit(0 if err == OK else 1)


func _clip(clip_name: StringName) -> Animation:
	return _made[clip_name] if _made.has(clip_name) else _source.get_animation(clip_name)


func _build(length: float, spans: Array) -> Animation:
	var template := _clip(HORIZONTAL)
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_NONE
	var frames := int(round(length * FPS))
	for track in template.get_track_count():
		var type := template.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var path := template.track_get_path(track)
		var out := anim.add_track(type)
		anim.track_set_path(out, path)
		for i in frames + 1:
			var t := minf(i / FPS, length)
			anim.track_insert_key(out, t, _value(spans, t / length, path, type))
	return anim


func _value(spans: Array, f: float, path: NodePath, type: int) -> Variant:
	for span: Array in spans:
		if f > span[1] and span != spans.back():
			continue
		var w := clampf((f - span[0]) / (span[1] - span[0]), 0.0, 1.0)
		var from: Array = span[2]
		var to: Array = span[3]
		if from[0] == to[0]:
			return _sample(from[0], lerpf(from[1], to[1], w), path, type)
		w = w * w * (3.0 - 2.0 * w)
		var a: Variant = _sample(from[0], from[1], path, type)
		var b: Variant = _sample(to[0], to[1], path, type)
		return (a as Quaternion).slerp(b, w) if type == Animation.TYPE_ROTATION_3D else (a as Vector3).lerp(b, w)
	return null


func _sample(clip_name: StringName, f: float, path: NodePath, type: int) -> Variant:
	var clip := _clip(clip_name)
	var track := clip.find_track(path, type)
	var t := clampf(f, 0.0, 1.0) * clip.length
	match type:
		Animation.TYPE_POSITION_3D:
			return clip.position_track_interpolate(track, t) if track >= 0 else Vector3.ZERO
		Animation.TYPE_ROTATION_3D:
			return clip.rotation_track_interpolate(track, t) if track >= 0 else Quaternion.IDENTITY
		_:
			return clip.scale_track_interpolate(track, t) if track >= 0 else Vector3.ONE
