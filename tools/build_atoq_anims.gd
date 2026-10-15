extends SceneTree
## Arma src/entities/atoq/atoq_anims.tres: la librería "Atoq" (idle, walk, run, bite, howl, hit, death) para las piezas
## de atoq_model.tscn, con las pistas relativas a su raíz. El hocico mira a +Z: rotar en +X baja la cabeza y abre la
## mandíbula, y lleva las patas hacia atrás.
## godot --headless --path . --script res://tools/build_atoq_anims.gd

const OUTPUT := "res://src/entities/atoq/atoq_anims.tres"
const BODY_Y := 0.55
const LEGS := ["Body/LegFL", "Body/LegFR", "Body/LegBL", "Body/LegBR"]
## Muestras por ciclo de las animaciones en loop.
const SAMPLES := 12


func _initialize() -> void:
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", _idle())
	library.add_animation(&"walk", _gait(0.8, 0.35, 0.02, [0.0, 0.5, 0.5, 0.0], 0.04))
	library.add_animation(&"run", _gait(0.45, 0.75, 0.06, [0.0, 0.08, 0.5, 0.58], 0.12))
	library.add_animation(&"bite", _bite())
	library.add_animation(&"howl", _howl())
	library.add_animation(&"hit", _hit())
	library.add_animation(&"death", _death())
	var err := ResourceSaver.save(library, OUTPUT)
	print("atoq_anims: ", error_string(err))
	quit(0 if err == OK else 1)


func _track(anim: Animation, path: String, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(path))
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for key: Array in keys:
		anim.track_insert_key(track, key[0], key[1])


func _loop(anim: Animation, path: String, length: float, value: Callable) -> void:
	var keys := []
	for i in SAMPLES + 1:
		var t := length * i / SAMPLES
		keys.append([t, value.call(TAU * i / SAMPLES)])
	_track(anim, path, keys)


func _new(length: float, loop := false) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return anim


func _rest_legs(anim: Animation, keys: Array) -> void:
	for leg: String in LEGS:
		_track(anim, leg + ":rotation", keys)


func _idle() -> Animation:
	var anim := _new(2.0, true)
	_loop(anim, "Body:position", 2.0, func(a: float) -> Vector3: return Vector3(0, BODY_Y + 0.008 * sin(a), 0))
	_loop(anim, "Body/Head:rotation", 2.0, func(a: float) -> Vector3: return Vector3(0.05 * sin(a + 1.0), 0.12 * sin(a * 0.5), 0))
	_loop(anim, "Body/Tail:rotation", 2.0, func(a: float) -> Vector3: return Vector3(0.1, 0.35 * sin(a * 2.0), 0))
	_loop(anim, "Body/Head/Jaw:rotation", 2.0, func(_a: float) -> Vector3: return Vector3.ZERO)
	_loop(anim, "Body:rotation", 2.0, func(_a: float) -> Vector3: return Vector3.ZERO)
	_rest_legs(anim, [[0.0, Vector3.ZERO]])
	return anim


## Un paso (trote o galope): cada pata oscila `swing` con su fase (FL, FR, BL, BR, en vueltas); el cuerpo rebota
## `bob` y cabecea `pitch`.
func _gait(length: float, swing: float, bob: float, phases: Array, pitch: float) -> Animation:
	var anim := _new(length, true)
	for i in LEGS.size():
		var phase: float = TAU * phases[i]
		_loop(anim, LEGS[i] + ":rotation", length, func(a: float) -> Vector3: return Vector3(swing * sin(a + phase), 0, 0))
	_loop(anim, "Body:position", length, func(a: float) -> Vector3: return Vector3(0, BODY_Y + bob * absf(sin(a)), 0))
	_loop(anim, "Body:rotation", length, func(a: float) -> Vector3: return Vector3(pitch * sin(a + 0.8), 0, 0))
	_loop(anim, "Body/Head:rotation", length, func(a: float) -> Vector3: return Vector3(-pitch * sin(a + 0.8) + 0.1, 0, 0))
	_loop(anim, "Body/Tail:rotation", length, func(a: float) -> Vector3: return Vector3(-0.25 + 0.15 * sin(a), 0.2 * sin(a), 0))
	_loop(anim, "Body/Head/Jaw:rotation", length, func(a: float) -> Vector3: return Vector3(0.12 + 0.08 * sin(a), 0, 0) if swing > 0.5 else Vector3.ZERO)
	return anim


func _bite() -> Animation:
	var anim := _new(0.5)
	_track(anim, "Body:rotation", [[0.0, Vector3.ZERO], [0.15, Vector3(0.12, 0, 0)], [0.25, Vector3(0.18, 0, 0)], [0.5, Vector3.ZERO]])
	_track(anim, "Body:position", [[0.0, Vector3(0, BODY_Y, 0)], [0.15, Vector3(0, BODY_Y - 0.04, 0)], [0.5, Vector3(0, BODY_Y, 0)]])
	_track(anim, "Body/Head:rotation", [[0.0, Vector3.ZERO], [0.15, Vector3(-0.35, 0, 0)], [0.25, Vector3(0.3, 0, 0)], [0.5, Vector3.ZERO]])
	_track(anim, "Body/Head/Jaw:rotation", [[0.0, Vector3.ZERO], [0.15, Vector3(0.8, 0, 0)], [0.25, Vector3(0.0, 0, 0)], [0.32, Vector3(0.15, 0, 0)], [0.5, Vector3.ZERO]])
	_track(anim, "Body/Tail:rotation", [[0.0, Vector3.ZERO], [0.25, Vector3(-0.5, 0, 0)], [0.5, Vector3.ZERO]])
	_rest_legs(anim, [[0.0, Vector3.ZERO], [0.15, Vector3(0.25, 0, 0)], [0.5, Vector3.ZERO]])
	return anim


func _howl() -> Animation:
	var anim := _new(1.2)
	var sit := Vector3(-0.45, 0, 0)
	_track(anim, "Body:rotation", [[0.0, Vector3.ZERO], [0.25, sit], [0.95, sit], [1.2, Vector3.ZERO]])
	_track(anim, "Body:position", [[0.0, Vector3(0, BODY_Y, 0)], [0.25, Vector3(0, BODY_Y - 0.08, 0)], [0.95, Vector3(0, BODY_Y - 0.08, 0)], [1.2, Vector3(0, BODY_Y, 0)]])
	_track(anim, "Body/Head:rotation", [[0.0, Vector3.ZERO], [0.3, Vector3(-0.75, 0, 0)], [0.6, Vector3(-0.85, 0.08, 0)], [0.9, Vector3(-0.8, -0.08, 0)], [1.2, Vector3.ZERO]])
	_track(anim, "Body/Head/Jaw:rotation", [[0.0, Vector3.ZERO], [0.3, Vector3(0.55, 0, 0)], [0.9, Vector3(0.45, 0, 0)], [1.1, Vector3.ZERO]])
	_track(anim, "Body/Tail:rotation", [[0.0, Vector3.ZERO], [0.3, Vector3(0.5, 0, 0)], [0.95, Vector3(0.5, 0, 0)], [1.2, Vector3.ZERO]])
	for leg: String in ["Body/LegFL", "Body/LegFR"]:
		_track(anim, leg + ":rotation", [[0.0, Vector3.ZERO], [0.25, Vector3(0.45, 0, 0)], [0.95, Vector3(0.45, 0, 0)], [1.2, Vector3.ZERO]])
	for leg: String in ["Body/LegBL", "Body/LegBR"]:
		_track(anim, leg + ":rotation", [[0.0, Vector3.ZERO], [0.25, Vector3(-0.6, 0, 0)], [0.95, Vector3(-0.6, 0, 0)], [1.2, Vector3.ZERO]])
	return anim


func _hit() -> Animation:
	var anim := _new(0.3)
	_track(anim, "Body:rotation", [[0.0, Vector3.ZERO], [0.08, Vector3(-0.2, 0, 0.15)], [0.3, Vector3.ZERO]])
	_track(anim, "Body:position", [[0.0, Vector3(0, BODY_Y, 0)], [0.08, Vector3(0, BODY_Y + 0.05, 0)], [0.3, Vector3(0, BODY_Y, 0)]])
	_track(anim, "Body/Head:rotation", [[0.0, Vector3.ZERO], [0.08, Vector3(-0.4, 0.3, 0)], [0.3, Vector3.ZERO]])
	_track(anim, "Body/Head/Jaw:rotation", [[0.0, Vector3.ZERO], [0.08, Vector3(0.4, 0, 0)], [0.3, Vector3.ZERO]])
	_track(anim, "Body/Tail:rotation", [[0.0, Vector3.ZERO], [0.3, Vector3.ZERO]])
	_rest_legs(anim, [[0.0, Vector3.ZERO]])
	return anim


func _death() -> Animation:
	var anim := _new(1.0)
	var lying := Vector3(0, 0, PI / 2)
	_track(anim, "Body:rotation", [[0.0, Vector3.ZERO], [0.15, Vector3(-0.3, 0, 0.1)], [0.6, lying], [1.0, lying]])
	_track(anim, "Body:position", [[0.0, Vector3(0, BODY_Y, 0)], [0.15, Vector3(0, BODY_Y + 0.08, 0)], [0.6, Vector3(0, 0.22, 0)], [1.0, Vector3(0, 0.22, 0)]])
	_track(anim, "Body/Head:rotation", [[0.0, Vector3.ZERO], [0.15, Vector3(-0.5, 0, 0)], [0.7, Vector3(0.2, 0, 0)], [1.0, Vector3(0.2, 0, 0)]])
	_track(anim, "Body/Head/Jaw:rotation", [[0.0, Vector3.ZERO], [0.15, Vector3(0.5, 0, 0)], [0.7, Vector3(0.25, 0, 0)], [1.0, Vector3(0.25, 0, 0)]])
	_track(anim, "Body/Tail:rotation", [[0.0, Vector3.ZERO], [0.6, Vector3(0.3, 0, 0)], [1.0, Vector3(0.3, 0, 0)]])
	var spread := {"Body/LegFL": Vector3(-0.4, 0, 0), "Body/LegFR": Vector3(-0.2, 0, 0), "Body/LegBL": Vector3(0.4, 0, 0), "Body/LegBR": Vector3(0.25, 0, 0)}
	for leg: String in LEGS:
		_track(anim, leg + ":rotation", [[0.0, Vector3.ZERO], [0.6, spread[leg]], [1.0, spread[leg]]])
	return anim
