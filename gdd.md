# GDD — Project Epiphany *(título provisorio)*

**Motor:** Godot 4.8 (fijo: usa los `AnimationNodeObserver*` del AnimationTree) · **IA:** LimboAI (build propio, runtime completo) · **Plataformas:** Linux / Windows · gamepad + teclado/mouse

> **Historia del documento.** Nació como GDD para la Godot Wild Jam #97 (tema *Imminent Doom*, 7 días). La jam no llegó; el proyecto sigue sin límite de jam y con un alcance nuevo: **un overworld chico + una mazmorra completa** con la mayor cantidad posible de mecánicas típicas de Zelda. La versión de la jam queda en el historial de git (`gdd-jam97-imminent-doom.md`).

---

## 1. Pitch
<!-- id: pitch -->

Action-adventure top-down con cámara inclinada al estilo *Link's Awakening* (remake de Switch), construido en 3D pero legible como 2D. El jugador recorre un pequeño overworld, junta las herramientas que le abren camino y entra a un templo antiguo donde algo está despertando. Al fondo espera el guardián: **un ojo flotante con manos**.

El tema *Imminent Doom* sigue siendo el tono: el fin se siente por ambientación y narrativa, no por timers.

## 2. Pilares de diseño
<!-- id: pilares -->

1. **Una mazmorra completa > un mundo grande a medias.** Todo lo que entra al MVP tiene que servir al recorrido overworld → mazmorra → jefe.
2. **Cada ítem abre puertas.** Regla Zelda: la mazmorra da un ítem que desbloquea su segunda mitad y derrota al jefe; el overworld esconde ítems que abren secretos y atajos.
3. **El escudo tiene doble función.** Bloqueo direccional en combate; con la mejora espejo, refleja proyectiles y luz en puzzles.
4. **El doom se siente, no se cronometra.** Luz, audio, grietas y tablillas cuentan el despertar del ojo.
5. **Todas las formas de jugar.** Gamepad y teclado/mouse son ciudadanos de primera: lock-on, apuntado con analógico derecho y apuntado con mouse.
6. **Datos antes que escenas.** Ítems, entidades, flags y partidas son datos inspeccionables y validables desde el editor.

## 3. Ambientación / historia
<!-- id: historia -->

*(Decisión abierta; se mantiene la recomendación de la jam.)*

- **Opción A — El Ojo despierta** *(recomendada)*: el templo sella a un ente antiguo. A medida que avanzás, el ojo despierta y el mundo lo muestra (grietas, luz rojiza, temblores). Hay que llegar a sellarlo.
- **Opción B — El Ojo ve el fin**: un oráculo que observó un cataclismo por siglos y enloqueció.

**Narrativa ambiental:** sin NPCs con diálogo. El texto vive en **tablillas/inscripciones** de piedra (overworld y mazmorra), que además resuelven pistas de puzzles.

**Progresión del doom:** overworld tranquilo al inicio → temblores lejanos al acercarte al templo → dentro del templo, sala a sala: grietas, polvo, luz virando a rojo, murmullo del ojo → clímax en la sala del jefe.

## 4. Cámara y control
<!-- id: camara-control -->

### 4.1 Cámara
<!-- id: camara -->

| Contexto | Comportamiento |
|---|---|
| **Overworld** | Sigue al jugador con suavizado (lo que hace `TopDownCamera` hoy). Con lock-on, enfoca el punto medio entre jugador y objetivo. |
| **Mazmorra (salas)** | Sigue al jugador **clampeada a los límites de la sala**. Al cruzar una puerta: el input se bloquea, el player camina solo a través de la puerta y la cámara hace un **deslizamiento** hacia la sala nueva (≈0.5 s). |
| **Jefe** | Igual que sala, con límites que encuadran toda la arena. |

### 4.2 Movimiento y combate
<!-- id: movimiento-combate -->

- Movimiento libre analógico (8+ direcciones), rotación suave del modelo.
- **Lock-on (Z-target)**: mantener o alternar (configurable, ya implementado). Con objetivo fijado el player strafea y la cámara encuadra a ambos.
- **Cambio de objetivo** *(pendiente)*: con objetivo fijado, mover el stick derecho de golpe (`look_*` más allá de 0.7) salta al candidato más alineado en esa dirección de pantalla. Teclado y mouse: a definir (§4.3).
- **Apuntado libre**: analógico derecho o mouse (rayo cámara → plano del suelo). Lo consumen arco, bombas lanzadas y cualquier ítem a distancia.

### 4.3 Mapa de input
<!-- id: input -->

| Acción (`InputMap`) | Gamepad (Xbox · índice en Godot) | Uso |
|---|---|---|
| `move_*` | Stick izquierdo | Moverse |
| `attack` | A · botón 0 | Espada |
| `interact` | B · botón 1 | Abrir, leer, empujar (acción contextual) |
| `dodge` | RB · botón 10 | Rodar. Queda al lado de la guardia: cubrirse y esquivar con el mismo dedo |
| `item_1` / `item_2` | X · botón 2 / Y · botón 3 | Ítems asignados |
| `block` | RT · eje 5 | Guardia |
| `z-lock` | LT · eje 4 | Fijar objetivo |
| `look_left` / `look_right` / `look_up` / `look_down` | Stick derecho · ejes 2 y 3 | Una sola dirección para dos usos. Sin objetivo fijado: apuntar (zona muerta normal). Con objetivo fijado: cambiar de objetivo cuando cruza 0.7 (el mismo `look_*` leído con otro umbral). Remapear `look_*` mueve los dos usos juntos |
| `pause` | Start · botón 6 | Menú de pausa (inventario) |
| `map` | Back · botón 4 | Mapa |
| `ui_tab_left` / `ui_tab_right` | LB · botón 9 / RB · botón 10 | Pestañas de los menús. Prefijo `ui_` porque son de otro contexto: con el juego pausado RB no choca con `dodge` |
| `debug_overlay` / `debug_quickload` / `debug_quicksave` | — | Teclas `1` / `2` / `3`, solo teclado, solo en debug. Provisorias: el teclado de desarrollo no tiene teclas F |

**Teclado y mouse: se definen más adelante.** Por ahora no hay ninguna tecla de juego mapeada: el juego se prueba con gamepad. Ideas ya discutidas para cuando se retome: guardia en click derecho, ítems en `Q`/`R`, `Tab` para el inventario y la rueda para cambiar de objetivo.

## 5. Combate
<!-- id: combate -->

- **Vida:** corazones; **1 corazón = 4 HP** (permite daño de ¼). Inicio: 3 corazones. El HUD dibuja cuartos.
- **Recibir daño:** retroceso + ≈0.8 s de invulnerabilidad con parpadeo. Al llegar a 0: game over → continuar desde la entrada de la sala / último punto de reaparición.
- **Espada:** combo corto (hoy: slash). Stab cargado / spin attack: post-MVP.
- **Escudo:** mientras se bloquea, el golpe se anula si viene **de frente** (cono de ±60°). Con escudo espejo, los proyectiles bloqueados se reflejan hacia donde mira el player (o hacia el objetivo fijado).
- **Golpe de escudo:** atacar mientras se bloquea (ya existe, `ShieldThrust`): aturde / empuja.
- **Esquiva (roll):** i-frames cortos, usa las animaciones `Dodge_*` de KayKit.
- **Enemigos (MVP):** 3 arquetipos + jefe:
  - *Esqueleto* — melee básico, enseña bloqueo.
  - *Esqueleto con escudo* — bloquea de frente; obliga a flanquear, usar bombas o golpe de escudo.
  - *Torreta / ojo menor* — dispara orbes reflejables.

## 6. Ítems y progresión
<!-- id: items-progresion -->

### 6.1 Ítems del MVP
<!-- id: items-mvp -->

| Ítem | Pantalla | Comportamiento | Dónde se obtiene | Para qué sirve |
|---|---|---|---|---|
| Espada básica | Equipo | Melee | Inicio | Combate, cortar pasto |
| Escudo de madera | Equipo | Bloqueo | Inicio | Bloqueo direccional |
| **Escudo espejo** | Equipo | Bloqueo + reflejo | Overworld: santuario tras muro agrietado | **Abre el sello del templo** reflejando un haz de luz; puzzles de reflejo; alternativa en la fase 2 del jefe |
| Túnica | Equipo | Pasivo | Inicio | Placeholder de armadura |
| Cota reforzada | Equipo | Pasivo (−25% daño) | Overworld: cofre secreto (puzzle de bloques) | Ejercita la pantalla de equipo |
| Bolsa de bombas + bombas | Ítems | Colocar | Overworld: cueva | Muros agrietados, daño en área, empujar objetos físicos |
| Botella (+ poción) | Ítems | Consumible | Overworld: secreto opcional | Cura; deja la botella vacía |
| **Arco + flechas** | Ítems | Proyectil | **Mazmorra (ítem de la mazmorra)** | Interruptores de ojo lejanos, punto débil del jefe |
| Carcaj grande | Mejora | Pasivo (+max flechas) | Overworld, **post-mazmorra** (requiere arco) | Muestra el backtracking |
| Llaves chicas, llave del jefe, mapa, brújula | Mazmorra | — | Mazmorra | Estructura de mazmorra |
| Contenedor de corazón | Mejora | +1 corazón | Tras el jefe | Recompensa |

**Recolectables** (vasijas, pasto, enemigos): corazón, flechas ×5, bombas ×3. No hay moneda.

**Post-MVP:** gancho / algo que mueva objetos a distancia (aprovecha las pruebas de física), espada con elemento (fuego/rayo), spin attack.

### 6.2 Progresión (gating)
<!-- id: progresion-gating -->

```
Inicio (espada + escudo de madera)
  └─ Pradera: enemigos, pasto, tablilla
      └─ Cueva ──► BOMBAS
          └─ Muro agrietado ──► Santuario ──► ESCUDO ESPEJO
              └─ Sello del templo (reflejar haz de luz) ──► MAZMORRA
                  └─ … ──► ARCO (ítem de la mazmorra) ──► llave del jefe ──► JEFE
                      └─ Vuelta al overworld: ojo-interruptor ──► CARCAJ GRANDE
Opcionales: botella/poción (muro agrietado), cota reforzada (puzzle de bloques)
```

## 7. Overworld (MVP)
<!-- id: overworld -->

Una zona chica (≈6–8 "pantallas" de tamaño Link's Awakening), sin transiciones de sala: cámara de seguimiento libre. El nivel `levels/test.tscn` actual cumple el rol de overworld de pruebas.

Contenido mínimo: punto de inicio, pradera con enemigos, cueva de las bombas, santuario del escudo espejo, entrada al templo con sello de luz, 2 secretos (poción, cota), 1 secreto post-mazmorra (carcaj). Objetos físicos (cajas, rocas) para mecánicas de empuje/explosión.

## 8. Mazmorra — El Templo
<!-- id: mazmorra -->

8 salas + jefe. Hub central con puertas que se van abriendo.

| # | Sala | Puzzle / mecánica | Combate | Obtiene | Doom |
|---|---|---|---|---|---|
| 1 | Vestíbulo | Bloque por grilla → interruptor de piso abre persiana | — | — | Calma, luz natural |
| 2 | Hub central | 4 salidas: con llave, con persiana, del jefe (sellada), libre | Esqueletos | — | Primeras grietas |
| 3 | Galería de trampas | Torretas disparan orbes → reflejar con escudo espejo a un cristal | Torretas | Llave chica | Polvo cae al resolver |
| 4 | Sala agrietada | Muro bombable; bombas empujan bloques físicos a un interruptor | — | Mapa | Temblor breve |
| 5 | Arena | Puerta se cierra hasta limpiar la sala | Oleada con esqueleto con escudo | **Cofre grande: ARCO** | Rugido lejano |
| 6 | Sala de ojos | Ojos-interruptor sobre un abismo, solo alcanzables con flechas | Torreta | Brújula + llave chica | Luz vira a rojizo |
| 7 | Puzzle combinado | Bloques + reflejo + flechas en secuencia | Mixto | **Llave del jefe** | Murmullo audible |
| 8 | Antesala | Vasijas con corazones, tablilla, puerta del jefe | — | — | Latido constante |
| 9 | **Jefe** | Ver §9 | — | Contenedor de corazón | Clímax |

*El layout exacto (qué puerta conecta con cuál) es la próxima sesión de diseño de niveles.*

## 9. Jefe — El Ojo con manos
<!-- id: jefe -->

Rig reutilizado de otra jam *(pendiente importarlo al repo)*.

- **Fase 1 — Manos:** golpes y agarres telegrafiados. Bloquear o rodar. Tras un golpe al piso, la mano queda aturdida → ventana para espadazos. Aturdir ambas manos → fase 2.
- **Fase 2 — El Ojo:** el ojo se abre. **Flecha al ojo** = cae aturdido → ventana de espadazos. El ojo dispara orbes: se pueden **reflejar con el escudo espejo** como alternativa para aturdirlo. Las manos se regeneran y siguen presionando.
- **Fase 3 (si da el tiempo):** el ojo "marca" el piso antes de golpes de área; combina patrones.
- Barra de vida del jefe en el HUD.

## 10. UI
<!-- id: ui -->

*Mockups de todas las pantallas: artifact "Epiphany UI Mockups".*

| Pantalla | Contenido |
|---|---|
| **Título** | Logo, Continuar / Nueva partida / Opciones / Salir. En builds de debug: *Cargar escenario*. |
| **Selección de partida** | 3 ranuras: corazones, ubicación, tiempo jugado. *(MVP puede usar 1 ranura.)* |
| **HUD** | Corazones (¼), llaves chicas + llave del jefe (solo en mazmorra), botones de ítem X/Y con munición, indicador de acción contextual (A/B: *Abrir*, *Empujar*, *Leer*), barra del jefe, nombre de la zona al entrar. |
| **Pausa › Equipo** | Espada, escudo, armadura (con ranuras bloqueadas para lo no conseguido), stats, preview del modelo. |
| **Pausa › Ítems** | Grilla de ítems secundarios; asignar a X/Y; descripción; munición. |
| **Pausa › Mapa** | Mapa de la mazmorra (salas visitadas; con mapa: todas; con brújula: cofres y jefe); overworld: mapa simple. |
| **Caja de texto** | Tablillas e *item get*. |
| **Item get** | Animación con el ítem en alto + nombre + descripción corta. |
| **Game over** | Continuar / Guardar y salir. |
| **Opciones** | Lock-on mantener/alternar, sensibilidad de apuntado, volumen, remapeo (post-MVP). |
| **Debug (solo editor/debug)** | Overlay de valores en vivo (tecla `1`), cargar/guardar rápido (teclas `2`/`3`), pestaña Log en el debugger del editor. Ver §11.9. |

---

## 11. Arquitectura técnica
<!-- id: arquitectura -->

### 11.1 Estructura de carpetas
<!-- id: estructura-carpetas -->

```
data/
  items/*.tres              # un ItemData por ítem
  attacks/*.tres            # un AttackData por ataque (sword_slash…)
  item_database.tres        # registro de todos los ítems
  entities/*.tres           # un EntityConfig por tipo de entidad
  flag_registry.tres        # flags válidas del mundo
src/
  items/                    item_data.gd, item_database.gd, inventory.gd, item_use_context.gd, items.gd (autoload)
  items/behaviors/          item_behavior.gd, melee_behavior.gd, projectile_behavior.gd,
                            place_behavior.gd, consumable_behavior.gd
  items/modifiers/          item_modifier.gd (fuego, rayo… decisión abierta)
  components/               health.gd, hitbox.gd, hurtbox.gd, damage_info.gd, interactable.gd,
                            attack_runner.gd
  combat/                   attack_data.gd
  entities/                 entity_config.gd, enemy.gd, projectile.gd
  world/                    room.gd, door.gd, chest.gd, push_block.gd, floor_switch.gd
  state/                    game_state.gd (autoload), dungeon_state.gd, flag_registry.gd
  save/                     save_codec.gd (estático, lo usan juego y editor), save_manager.gd (autoload)
  ui/                       hud/, menus/, text_box/
ai/tasks/                   tareas custom de LimboAI (bt_attack.gd…); carpeta por defecto de LimboAI
addons/epiphany_tools/      Log, LogSink y DebugOverlay (§11.9), Save Inspector (MVP), tabla de ítems (más adelante)
tests/                      run_tests.gd + test_*.gd: godot --headless --path . --script res://tests/run_tests.gd
debug/scenarios/*.cfg       partidas preparadas (excluidas del export release)
```

**Autoloads:** `Items` (acceso al `ItemDatabase`), `GameState` (estado runtime: inventario, equipo, flags, mazmorras), `SaveManager` (GameState ↔ disco).

### 11.2 Ítems: datos + comportamiento enchufable
<!-- id: items-datos -->

Un `ItemData` guarda los datos comunes; lo que el ítem **hace** es un `ItemBehavior` aparte. Así una espada de fuego que lanza un rayo no pelea con una jerarquía de herencia.

```gdscript
# src/items/item_data.gd
class_name ItemData
extends Resource
## Datos estáticos de un ítem. Nunca se modifica en runtime:
## el estado (cantidad, munición, cooldown) vive en Inventory / nodos.

enum Category { SWORD, SHIELD, ARMOR, USABLE, AMMO, DUNGEON, UPGRADE }

@export var id: StringName                    ## Estable. Es lo que se guarda en la partida.
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var category: Category
@export var max_stack: int = 1
@export var equip_scene: PackedScene          ## Solo visual: la Hitbox vive en el personaje (§11.3)
@export var behavior: ItemBehavior            ## null = pasivo (armadura, mejoras)
@export var modifiers: Array[ItemModifier] = []

@export_group("Combate")
@export var damage: int = 0                   ## En HP (1 corazón = 4)
@export var knockback: float = 0.0

@export_group("Pasivos")
@export var damage_reduction: float = 0.0     ## Armaduras: 0.25 = −25%


func is_equipment() -> bool:
	return category in [Category.SWORD, Category.SHIELD, Category.ARMOR]


func make_damage(source: Node3D) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = damage
	info.knockback = knockback
	info.source = source
	for modifier in modifiers:
		modifier.modify_damage(info)
	return info
```

```gdscript
# src/items/behaviors/item_behavior.gd
class_name ItemBehavior
extends Resource
## SIN ESTADO: el recurso es compartido por todos los que usan el ítem.
## Todo lo variable llega en el ItemUseContext.

func get_animation(_item: ItemData) -> StringName:
	return &""


func can_use(_ctx: ItemUseContext, _item: ItemData) -> bool:
	return true


func use(_ctx: ItemUseContext, _item: ItemData) -> void:
	pass
```

```gdscript
# src/items/item_use_context.gd
class_name ItemUseContext
extends RefCounted
## Lo que un behavior necesita saber del usuario, sin acoplarse al Player.

var user: Node3D
var origin: Vector3            ## Desde dónde sale un proyectil (mano / "muzzle")
var direction: Vector3         ## De Aim: lock-on > stick/mouse > hacia donde mira
var inventory: Inventory
var equipped: Node3D           ## Nodo instanciado en la mano, si hay (0.9 define el tipo)
```

Los tres (cuatro) comportamientos base:

```gdscript
# src/items/behaviors/melee_behavior.gd
class_name MeleeBehavior
extends ItemBehavior
## Las ventanas de golpe viven en AttackData, no en las animaciones:
## AttackRunner enciende/apaga la Hitbox del usuario según el progreso (§11.3).

@export var combo: Array[AttackData] = []


func get_attack(combo_index: int) -> AttackData:
	if combo.is_empty():
		return null
	return combo[combo_index % combo.size()]


func get_animation(_item: ItemData) -> StringName:
	return combo[0].animation if not combo.is_empty() else &""
```

```gdscript
# src/items/behaviors/projectile_behavior.gd
class_name ProjectileBehavior
extends ItemBehavior

@export var animation: StringName = &"BowRelease"
@export var projectile_scene: PackedScene
@export var speed: float = 18.0
@export var ammo: ItemData                     ## null = munición infinita


func get_animation(_item: ItemData) -> StringName:
	return animation


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	return ammo == null or ctx.inventory.has(ammo.id)


func use(ctx: ItemUseContext, item: ItemData) -> void:
	if ammo:
		ctx.inventory.remove(ammo.id)
	var projectile: Projectile = projectile_scene.instantiate()
	ctx.user.get_tree().current_scene.add_child(projectile)
	projectile.launch(ctx.origin, ctx.direction * speed, item.make_damage(ctx.user))
```

```gdscript
# src/items/behaviors/consumable_behavior.gd
class_name ConsumableBehavior
extends ItemBehavior

@export var heal: int = 0
@export var leaves: ItemData                   ## Botella vacía al tomar la poción


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	var health: Health = ctx.user.get_node(^"Health")
	return heal == 0 or not health.is_full()


func use(ctx: ItemUseContext, item: ItemData) -> void:
	ctx.user.get_node(^"Health").heal(heal)
	ctx.inventory.remove(item.id)
	if leaves:
		ctx.inventory.add(leaves.id)
```

`PlaceBehavior` (bombas) es igual a `ProjectileBehavior` pero instancia la escena delante del player (o la lanza en arco si está apuntando).

**Modificadores** (espada de fuego, rayo — decisión abierta, estructura lista):

```gdscript
# src/items/modifiers/item_modifier.gd
class_name ItemModifier
extends Resource

func modify_damage(_info: DamageInfo) -> void:
	pass

# Ejemplo: ElementModifier -> info.element = &"fire"
```

**Registro:** un solo recurso, export-safe (no escanea carpetas `res://`, que en export tienen `.remap`).

```gdscript
# src/items/item_database.gd
@tool
class_name ItemDatabase
extends Resource

@export var items: Array[ItemData] = []:
	set(value):
		items = value
		_by_id.clear()

var _by_id: Dictionary[StringName, ItemData] = {}


func get_item(id: StringName) -> ItemData:
	if _by_id.is_empty():
		for item in items:
			if item:
				_by_id[item.id] = item
	return _by_id.get(id)


func has_item(id: StringName) -> bool:
	return get_item(id) != null
```

```gdscript
# src/items/items.gd  (autoload "Items")
extends Node

const DATABASE_PATH := "res://data/item_database.tres"

var database: ItemDatabase


func _ready() -> void:
	database = load(DATABASE_PATH)   # load y no preload: el autoload compila aunque la base no exista


func get_item(id: StringName) -> ItemData:
	return database.get_item(id)
```

**Inventario** (estado runtime; guarda ids y cantidades, nunca nodos):

```gdscript
# src/items/inventory.gd
class_name Inventory
extends RefCounted

signal changed(id: StringName, count: int)

var _counts: Dictionary[StringName, int] = {}
var _capacity_bonus: Dictionary[StringName, int] = {}   ## Carcaj grande, bolsa grande…


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func capacity(id: StringName) -> int:
	return Items.get_item(id).max_stack + _capacity_bonus.get(id, 0)


## Devuelve cuánto entró realmente.
func add(id: StringName, amount: int = 1) -> int:
	var added := mini(amount, capacity(id) - count(id))
	if added <= 0:
		return 0
	_counts[id] = count(id) + added
	changed.emit(id, _counts[id])
	return added


func remove(id: StringName, amount: int = 1) -> bool:
	if not has(id, amount):
		return false
	_counts[id] -= amount
	if _counts[id] == 0:
		_counts.erase(id)
	changed.emit(id, count(id))
	return true


func ids() -> Array[StringName]:
	return _counts.keys()
```

> **Tabla de ítems en el editor:** el inspector ya edita un ítem a la vez. Cuando haya ~15 ítems, un dock que muestre `item_database.tres` como tabla editable (un `Tree` con columnas) para comparar balance. Es solo una vista sobre los mismos `Resource`: no cambia la arquitectura.

### 11.3 Entidades: `EntityConfig` + componentes
<!-- id: entidades-componentes -->

- **Nodo componente** si necesita transform, shape, señales físicas o proceso propio: `Health`, `Hitbox`, `Hurtbox`, `Interactable`.
- **Dato en `EntityConfig`** si es una propiedad o capacidad: targetable, pushable, equipo, altura del lock-on…

```gdscript
# src/entities/entity_config.gd
class_name EntityConfig
extends Resource

enum Team { PLAYER, ENEMY, NEUTRAL }
enum Feature { TARGETABLE = 1, PUSHABLE = 2, BURNABLE = 4, REFLECTS = 8, GRABBABLE = 16 }

const _GROUPS: Dictionary[Feature, StringName] = {
	Feature.TARGETABLE: &"targetable",
	Feature.PUSHABLE: &"pushable",
	Feature.BURNABLE: &"burnable",
	Feature.REFLECTS: &"reflects",
	Feature.GRABBABLE: &"grabbable",
}

@export_flags("Targetable:1", "Pushable:2", "Burnable:4", "Reflects:8", "Grabbable:16")
var features: int = 0
@export var team: Team = Team.ENEMY
@export var max_health: int = 8                 ## HP (1 corazón = 4)
@export var target_height: float = 1.0          ## Dónde apunta el lock-on / indicador
@export var knockback_resistance: float = 0.0   ## 0 = recibe todo, 1 = inamovible
@export var attack_damage: int = 2              ## Daño base de sus ataques (sin arma equipada)
@export var attack_knockback: float = 6.0


func has(feature: Feature) -> bool:
	return (features & feature) != 0


func apply_to(entity: Node) -> void:
	for feature in _GROUPS:
		if has(feature):
			entity.add_to_group(_GROUPS[feature])
```

Cada tipo de enemigo tiene su `.tres` (`data/entities/skeleton.tres`) compartido por todas sus instancias. Llamar `config.apply_to(self)` en `_ready` mantiene funcionando el `TargetDetector` actual (grupo `targetable`).

```gdscript
# src/components/damage_info.gd  (se crea en 0.3 sin `team`; 0.7 lo agrega)
class_name DamageInfo
extends RefCounted

var amount: int = 0
var knockback: float = 0.0
var source: Node3D
var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
var element: StringName = &""
var reflectable: bool = false
```

```gdscript
# src/components/health.gd
class_name Health
extends Node

signal changed(current: int, max_value: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 12
@export var invulnerability_time: float = 0.8

var current: int
var _invulnerable_left: float = 0.0   ## Con delta, así la pausa no la consume


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_full() -> bool:
	return current >= max_health


func damage(amount: int) -> bool:
	if current <= 0 or is_invulnerable():
		return false
	current = maxi(current - amount, 0)
	_invulnerable_left = invulnerability_time
	damaged.emit(amount)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)
```

```gdscript
# src/components/hurtbox.gd
class_name Hurtbox
extends Area3D
## La entidad decide qué hacer con el golpe (bloqueo, daño, reflejo).

signal hit(info: DamageInfo)

var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL


func receive(info: DamageInfo) -> void:
	hit.emit(info)
```

```gdscript
# src/components/hitbox.gd
class_name Hitbox
extends Area3D
## La enciende/apaga AttackRunner (ataques) o queda siempre activa (proyectiles, trampas).

signal landed(hurtbox: Hurtbox)

var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
## () -> DamageInfo. Player: ItemData del arma equipada. Enemigo: su EntityConfig.
var damage_factory: Callable
## La setea AttackRunner al activar; null = sin multiplicadores.
var active_attack: AttackData:
	set(value):
		active_attack = value
		_already_hit.clear()   # cada swing puede volver a pegarle a todos

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func build_damage() -> DamageInfo:
	var info: DamageInfo = damage_factory.call()
	info.team = team
	if active_attack:
		info.amount = roundi(info.amount * active_attack.damage_multiplier)
		info.knockback *= active_attack.knockback_multiplier
	return info


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.team == team or not damage_factory.is_valid():
		return
	if hurtbox in _already_hit:
		return
	_already_hit.append(hurtbox)
	hurtbox.receive(build_damage())
	landed.emit(hurtbox)


## Objetos físicos sin Hurtbox (cajas, rocas): solo impulso.
func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and damage_factory.is_valid():
		var info := build_damage()
		var push := body.global_position - global_position
		push.y = 0.0
		body.apply_central_impulse(push.normalized() * info.knockback + Vector3.UP * 4.0)
```

#### Ventanas de ataque: `AttackData` + `AttackRunner`
<!-- id: ventanas-ataque -->

Las ventanas de golpe **no se marcan en las animaciones** (method tracks). Son datos:

- No hay que editar cada animación de cada enemigo. Las librerías KayKit son compartidas; el timing no.
- El timing es del **ataque**, no de la animación: dos armas pueden usar la misma animación con ventanas distintas.
- Si el ataque se interrumpe (golpe, roll, muerte), `stop()` apaga la hitbox. Con un method track, si nunca se llega a la key de "apagar", la hitbox queda encendida.
- Lo usan igual el player (estado `Attacking`) y los enemigos (tarea `BTAttack` de LimboAI).

**La Hitbox vive en el personaje, no en la hoja de la espada.** Es un `Area3D` con forma de arco o caja delante del personaje, colgado de `ModelController` para que gire con el modelo. Se pueden tener varias con nombre (`front`, `spin`, `slam`).

- Evita el *tunneling*: un swing rápido cubre la ventana en 3 o 4 frames de física, y una hitbox fina pegada al hueso puede atravesar al enemigo sin tocarlo.
- Se lee mejor en vista cenital: el golpe cubre el área que el jugador espera, como en los Zelda top-down.
- Sirve igual para enemigos sin arma (las manos del jefe, mordiscos, embestidas).
- El arma en la mano queda como modelo visual. Si un ataque necesita seguir un hueso, se agrega una `Hitbox` en un `BoneAttachment3D` con otro nombre.

```gdscript
# src/combat/attack_data.gd
class_name AttackData
extends Resource

@export var animation: StringName
@export_range(0.0, 1.0) var active_from: float = 0.3   ## Tiempo normalizado (0..1) de la animación
@export_range(0.0, 1.0) var active_to: float = 0.55
@export var hitbox: StringName = &"front"              ## Cuál Hitbox del usuario activar
@export var damage_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0
```

```gdscript
# src/components/attack_runner.gd
class_name AttackRunner
extends Node
## Enciende y apaga hitboxes según el progreso del ataque. Lo comparten player y enemigos.

@export var hitboxes: Dictionary[StringName, Hitbox] = {}

var current: AttackData
var _elapsed := 0.0
var _length := 1.0
var _speed := 1.0


func _ready() -> void:
	set_physics_process(false)


func start(attack: AttackData, length: float, speed: float = 1.0) -> void:
	stop()
	current = attack
	_length = maxf(length, 0.001)
	_speed = speed
	_elapsed = 0.0
	set_physics_process(true)


## Se llama también al salir del estado: garantiza que nunca quede una hitbox activa.
func stop() -> void:
	if current:
		_set_active(false)
	current = null
	set_physics_process(false)


func is_running() -> bool:
	return current != null


func _physics_process(delta: float) -> void:
	_elapsed += delta * _speed
	var t := _elapsed / _length
	_set_active(t >= current.active_from and t < current.active_to)
	if t >= 1.0:
		stop()


func _set_active(active: bool) -> void:
	var hitbox: Hitbox = hitboxes.get(current.hitbox)
	if hitbox and hitbox.monitoring != active:
		hitbox.active_attack = current if active else null
		hitbox.set_deferred(&"monitoring", active)
```

**Player:** el estado `Attacking` dispara el OneShot como hoy y arranca el runner. Los combos salen del `MeleeBehavior`.

```gdscript
# player/states/attacking.gd (extracto)
func _enter() -> void:
	var attack: AttackData = player.equipment.current_attack()   # MeleeBehavior.get_attack(combo_index)
	player.anim_tree.set(&"parameters/Attack/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var length := player.anim_player.get_animation(attack.animation).length
	player.attack_runner.start(attack, length)


func _exit() -> void:
	player.attack_runner.stop()
```

**Enemigos:** una sola tarea de LimboAI para todos los BT. Solo cambia el `.tres` de `AttackData`.

```gdscript
# ai/tasks/bt_attack.gd
@tool
extends BTAction

@export var attack: AttackData


func _generate_name() -> String:
	return "Attack  %s" % (attack.animation if attack else "?")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if attack == null:
		warnings.append("Falta asignar un AttackData.")
	return warnings


func _enter() -> void:
	var anim: AnimationPlayer = agent.anim_player
	anim.play(attack.animation)
	agent.get_node(^"AttackRunner").start(attack, anim.current_animation_length, anim.get_playing_speed())


func _tick(_delta: float) -> Status:
	return RUNNING if agent.get_node(^"AttackRunner").is_running() else SUCCESS


func _exit() -> void:
	agent.get_node(^"AttackRunner").stop()   # si el BT interrumpe el ataque (golpe, muerte)
```

**Ajustar el timing:** las ventanas no se ven en el timeline. Con *Debug › Visible Collision Shapes* y un cambio de `debug_color` al activar la hitbox, la ventana se ve en vivo. Como los tiempos son normalizados, se ajustan desde el inspector con el juego corriendo. Un `@tool` que previsualice la ventana sobre la animación queda para después del MVP.

**Bloqueo direccional** en el player:

```gdscript
# player/player.gd (extracto)
@export var block_angle_deg: float = 60.0


func _on_hurtbox_hit(info: DamageInfo) -> void:
	if is_blocking() and _is_in_front(info.source):
		_on_blocked(info)   # chispa, retroceso leve, sonido
		if info.reflectable and has_mirror_shield():
			info.source.reflect(aim.get_direction(), EntityConfig.Team.PLAYER)
		return
	var reduced := roundi(info.amount * (1.0 - equipment.damage_reduction()))
	if health.damage(maxi(reduced, 1)):
		apply_knockback(info)


func _is_in_front(source: Node3D) -> bool:
	if not is_instance_valid(source):
		return false
	var to_source := source.global_position - global_position
	to_source.y = 0.0
	# El modelo KayKit mira hacia +Z local (ver Moving._free_move / look_at)
	var facing := model.global_basis.z
	facing.y = 0.0
	return facing.normalized().dot(to_source.normalized()) >= cos(deg_to_rad(block_angle_deg))
```

**Proyectil** (reutiliza `Hitbox`):

```gdscript
# src/entities/projectile.gd
class_name Projectile
extends Hitbox

@export var lifetime: float = 4.0
var velocity: Vector3
var _damage: DamageInfo


func launch(from: Vector3, initial_velocity: Vector3, info: DamageInfo) -> void:
	global_position = from
	velocity = initial_velocity
	_damage = info
	team = info.team
	damage_factory = func() -> DamageInfo: return _damage
	look_at(from + velocity)
	landed.connect(func(_h: Hurtbox) -> void: queue_free())


func reflect(direction: Vector3, new_team: EntityConfig.Team) -> void:
	velocity = direction.normalized() * velocity.length()
	team = new_team
	_damage.team = new_team
	_damage.source = self


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
```

### 11.4 Player refactorizado
<!-- id: player -->

```
Player (CharacterBody3D)            player.gd: orquesta, ya no contiene lógica de lock-on
├─ ModelController (Skeleton, AnimationTree, Hand_R, Hand_L, BackShield)
│  └─ Hitboxes/Front (Hitbox)       gira con el modelo; más con nombre si hacen falta (spin, slam)
├─ Health                           max_health <- GameState.max_health
├─ Hurtbox
├─ AttackRunner                     ventanas de golpe desde AttackData
├─ Equipment                        instancia equip_scene de GameState.equipment en las manos
├─ Targeting                        lock-on + cambio de objetivo (sale de state_machine.gd)
├─ Aim                              dirección de apuntado unificada
├─ InteractionDetector (Area3D)     elige el Interactable más cercano de frente
└─ MovementState (LimboHSM)         Spawning, Idle, Moving, Attacking, UsingItem, Dodging,
                                    Hurt, Transition (puertas), ItemGet
```

**Aim** — una sola dirección para todos los modos de control:

```gdscript
# player/components/aim.gd
class_name Aim
extends Node

enum Source { FACING, STICK, MOUSE }

const STICK_DEADZONE := 0.3

@export var player: PlayerCharacter
var source: Source = Source.FACING


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		source = Source.MOUSE
	elif event is InputEventJoypadMotion and _stick().length() > STICK_DEADZONE:
		source = Source.STICK


func get_direction() -> Vector3:
	var target := player.targeting.current
	if target:
		return _flat(target.global_position - player.global_position)

	match source:
		Source.STICK:
			var stick := _stick()
			if stick.length() > STICK_DEADZONE:
				return Vector3(stick.x, 0.0, stick.y).normalized()
		Source.MOUSE:
			var hit = _mouse_on_ground()
			if hit != null:
				var dir := _flat(hit - player.global_position)
				if not dir.is_zero_approx():
					return dir

	return _flat(player.model.global_basis.z)


func _stick() -> Vector2:
	return Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")


func _mouse_on_ground() -> Variant:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var ground := Plane(Vector3.UP, player.global_position.y + 1.0)
	return ground.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()
```

**Targeting — cambio de objetivo** (arregla "siempre marca el más cercano"):

```gdscript
# player/components/targeting.gd (extracto)
const MIN_ALIGNMENT := 0.5   ## cono de ~60° hacia la dirección pedida

const SWITCH_THRESHOLD := 0.7   ## umbral de "stick de golpe"; apuntar usa la zona muerta normal

var _last_dir := Vector2.ZERO


## Mismas acciones que Aim (`look_*`), leídas con otro umbral: remapear una mueve las dos.
func _physics_process(_delta: float) -> void:
	if current == null:
		_last_dir = Vector2.ZERO
		return
	var dir := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", SWITCH_THRESHOLD)
	if dir != Vector2.ZERO and _last_dir == Vector2.ZERO:   # cruzó el umbral: un salto por movimiento
		cycle(dir.normalized())
	_last_dir = dir


## Salta al candidato mejor alineado con `screen_dir` (espacio de pantalla).
func cycle(screen_dir: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	var from := camera.unproject_position(current.global_position)
	var best: Node3D = null
	var best_score := -INF
	for candidate in valid_candidates(camera):
		if candidate == current:
			continue
		var offset := camera.unproject_position(candidate.global_position) - from
		var alignment := offset.normalized().dot(screen_dir)
		if alignment < MIN_ALIGNMENT:
			continue
		var score := alignment * 2.0 - offset.length() / 500.0   # alineado > cercano
		if score > best_score:
			best_score = score
			best = candidate
	if best:
		set_target(best)
```

> Sin objetivo fijado, el stick derecho apunta (`look_*`, en `Aim`). Con objetivo fijado apuntar no hace falta (todo apunta al objetivo), así que el mismo stick queda libre para cambiar de objetivo. Si no hay candidato en la dirección pedida, no pasa nada (o se hace wrap, a decidir jugando).

### 11.5 Mundo: interacción, salas, puertas
<!-- id: mundo -->

```gdscript
# src/components/interactable.gd
class_name Interactable
extends Area3D

signal interacted(by: PlayerCharacter)

@export var prompt: String = "Abrir"   ## Lo muestra el HUD en el botón contextual
@export var enabled: bool = true


func interact(by: PlayerCharacter) -> void:
	if enabled:
		interacted.emit(by)
```

```gdscript
# src/world/chest.gd
class_name Chest
extends StaticBody3D

@export var item: ItemData
@export var amount: int = 1
@export var flag: StringName            ## p.ej. &"d1_chest_bow"
@export var big: bool = false           ## Cofre grande: ítem de la mazmorra / llave del jefe

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if GameState.get_flag(flag):
		_show_opened()
		interactable.enabled = false
	interactable.interacted.connect(_open)


func _open(by: PlayerCharacter) -> void:
	interactable.enabled = false
	GameState.set_flag(flag, true)
	GameState.give(item, amount)   # enruta llaves de mazmorra, mejoras, inventario
	_show_opened()
	by.play_item_get(item)         # estado ItemGet: ítem en alto + caja de texto
```

**Sala + cámara:**

```gdscript
# src/world/room.gd
class_name Room
extends Area3D
## El CollisionShape cubre la sala; al entrar el player, la cámara cambia de sala.

signal player_entered(room: Room)

@export var room_index: int = 0          ## Bit en DungeonState.visited_rooms
@export var camera_limits: Rect2         ## Local, en XZ: dónde puede estar el FOCO de la cámara
@export var display_name: String = ""


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body is PlayerCharacter:
			player_entered.emit(self))


func clamp_focus(point: Vector3) -> Vector3:
	var local := to_local(point)
	local.x = clampf(local.x, camera_limits.position.x, camera_limits.end.x)
	local.z = clampf(local.z, camera_limits.position.y, camera_limits.end.y)
	return to_global(local)
```

```gdscript
# src/tools/top_down_camera.gd (extracto)
var room: Room                 ## null = overworld (seguimiento libre)
var _transitioning := false


func enter_room(new_room: Room) -> void:
	var first := room == null
	room = new_room
	if first:
		return
	_transitioning = true
	target_node.begin_door_transition()        # estado Transition: camina solo, sin input
	var to := room.clamp_focus(target_node.global_position) + offset
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", to, 0.5)
	tween.tween_callback(func() -> void:
		_transitioning = false
		target_node.end_door_transition())


func _physics_process(delta: float) -> void:
	if not target_node or _transitioning:
		return
	var focus := _compute_focus()               # jugador o punto medio con lock-on (como hoy)
	if room:
		focus = room.clamp_focus(focus)
	global_position = global_position.lerp(focus + offset, smooth_speed * delta)
```

```gdscript
# src/world/door.gd (extracto)
class_name Door
extends StaticBody3D

enum Kind { OPEN, LOCKED, SHUTTER, SWITCH, BOSS }

@export var kind: Kind = Kind.OPEN
@export var flag: StringName            ## Persistencia para LOCKED / BOSS


func _ready() -> void:
	if kind in [Kind.LOCKED, Kind.BOSS] and GameState.get_flag(flag):
		open(false)


func try_unlock() -> bool:
	var dungeon := GameState.current_dungeon_state()
	match kind:
		Kind.LOCKED:
			if dungeon.small_keys <= 0:
				return false
			dungeon.small_keys -= 1
		Kind.BOSS:
			if not dungeon.has_boss_key:
				return false
		_:
			return false
	GameState.set_flag(flag, true)
	open(true)
	return true
```

Las puertas `SHUTTER` las abre la sala (al limpiar enemigos) y las `SWITCH` un interruptor por señal. **Bloques por grilla**: `AnimatableBody3D` que se mueve 1 celda con tween al empujar ≈0.3 s contra él; los `RigidBody3D` quedan para objetos físicos (bombas, rocas, enemigos livianos).

### 11.6 Estado del juego y flags
<!-- id: estado-flags -->

```gdscript
# src/state/game_state.gd  (autoload "GameState")
extends Node

signal flag_changed(id: StringName, value: Variant)
signal equipment_changed(category: ItemData.Category, id: StringName)
signal loaded                                             ## Después de reset() o read_from()

const FLAGS: FlagRegistry = preload("res://data/flag_registry.tres")

var inventory := Inventory.new()
var equipment: Dictionary[ItemData.Category, StringName] = {}
var item_buttons: Array[StringName] = [&"", &""]          ## X / Y
var max_health: int = 12
var flags: Dictionary[StringName, Variant] = {}
var dungeons: Dictionary[StringName, DungeonState] = {}
var current_dungeon: StringName = &""
var spawn_scene: String = ""
var spawn_point: StringName = &""
var save_tampered := false


func get_flag(id: StringName) -> Variant:
	return flags.get(id, FLAGS.default_of(id))


func set_flag(id: StringName, value: Variant) -> void:
	assert(FLAGS.has(id), "Flag no registrada: %s" % id)
	flags[id] = value
	flag_changed.emit(id, value)


func equip(item: ItemData) -> void:
	assert(item.is_equipment())
	equipment[item.category] = item.id
	equipment_changed.emit(item.category, item.id)


func current_dungeon_state() -> DungeonState:
	if not dungeons.has(current_dungeon):
		dungeons[current_dungeon] = DungeonState.new()
	return dungeons[current_dungeon]


## Punto único de entrada para cofres, drops y recompensas.
func give(item: ItemData, amount: int = 1) -> void:
	match item.id:
		&"small_key": current_dungeon_state().small_keys += amount
		&"boss_key": current_dungeon_state().has_boss_key = true
		&"dungeon_map": current_dungeon_state().has_map = true
		&"compass": current_dungeon_state().has_compass = true
		&"heart_container": max_health += 4 * amount
		_: inventory.add(item.id, amount)
```

```gdscript
# src/state/dungeon_state.gd
class_name DungeonState
extends RefCounted

var small_keys: int = 0
var has_map := false
var has_compass := false
var has_boss_key := false
var visited_rooms: int = 0      ## bitmask: bit N = sala con room_index N


func visit(room_index: int) -> void:
	visited_rooms |= 1 << room_index


func was_visited(room_index: int) -> bool:
	return (visited_rooms & (1 << room_index)) != 0
```

**Flags con nombre, no bitmask global.** Un bitmask global se rompe al reordenar bits y no se lee en el editor. El único bitmask es `visited_rooms`, acotado a una mazmorra. Las misiones son un `int` de etapa (`oracle_stage = 2`), no N booleanos.

```gdscript
# src/state/flag_registry.gd
@tool
class_name FlagRegistry
extends Resource
## Flags válidas. Evita typos y alimenta la validación del Save Inspector.

@export var definitions: Array[FlagDefinition] = []


func has(id: StringName) -> bool:
	return _find(id) != null


func default_of(id: StringName) -> Variant:
	var definition := _find(id)
	return definition.default_value if definition else null


func _find(id: StringName) -> FlagDefinition:
	for definition in definitions:
		if definition.id == id:
			return definition
	return null

# FlagDefinition (Resource): id: StringName, description: String, default_value: Variant
```

### 11.7 Guardado
<!-- id: guardado -->

- **Formato:** `ConfigFile`, en `user://saves/slot_N.cfg`.
- **Release:** encriptado (`save_encrypted_pass`). La clave está en el binario, así que es ofuscación y no seguridad, pero alcanza para el objetivo: nadie edita la partida por accidente y después reporta un "bug".
- **Editor / builds de debug:** texto plano (feature `editor` o la feature tag custom `plain_saves` en el preset de export).
- **`meta/checksum`:** si no coincide al cargar, se marca `save_tampered` (se incluye en reportes de bugs), pero la partida carga igual.
- **`meta/version`** + migraciones.
- **Escritura atómica:** se escribe a `slot_N.cfg.tmp`, la partida anterior pasa a `slot_N.cfg.bak` y el `.tmp` se renombra. Si `slot_N.cfg` no carga, se lee el `.bak`.
- **Posición:** por ahora `[player] position` guarda la posición exacta y `spawn_scene` la escena; con salas y overworld pasa a `spawn_point`.

Ejemplo de partida en texto plano:

```ini
[meta]
version=1
timestamp=1790660850.0
checksum="3f1a…"

[player]
max_health=12
spawn_scene="res://levels/overworld.tscn"
spawn_point=&"temple_entrance"

[inventory]
bomb=3
arrow=12
bow=1
bomb_bag=1

[equipment]
SWORD=&"sword_basic"
SHIELD=&"shield_mirror"
ARMOR=&"tunic"
buttons=Array[StringName]([&"bow", &"bomb_bag"])

[flags]
ow_cave_bombs_chest=true
ow_temple_seal_open=true
d1_chest_bow=true

[dungeon_d1]
small_keys=1
has_map=true
has_compass=false
has_boss_key=false
visited_rooms=47
```

`SaveCodec` es **estático** y sin dependencias de autoloads, para que lo use tanto el juego como el plugin del editor:

```gdscript
# src/save/save_codec.gd
class_name SaveCodec
extends RefCounted
## Estático y sin autoloads: lo usan el juego y el Save Inspector.

const VERSION := 1
const _PASS := "epiphany::change-me-before-release"
const _ENCRYPTED_MAGIC := "GDEC"


static func plain_saves() -> bool:
	return OS.has_feature("editor") or OS.has_feature("plain_saves")


## Escribe a .tmp, pasa la partida anterior a .bak y renombra: un corte a mitad de camino no deja una partida rota.
static func write(cfg: ConfigFile, path: String) -> Error:
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "timestamp", Time.get_unix_time_from_system())
	cfg.set_value("meta", "checksum", checksum(cfg))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var err := cfg.save(tmp) if plain_saves() else cfg.save_encrypted_pass(tmp, _PASS)
	if err != OK:
		return err
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
```

```gdscript
# src/save/save_manager.gd  (autoload "SaveManager")
extends Node

const SAVE_DIR := "user://saves/"
const SCENARIO_DIR := "res://debug/scenarios/"
const NEXT_SCENARIO_FILE := "user://debug/next_scenario.txt"   ## Lo escribe el Save Inspector


func _ready() -> void:
	if not OS.is_debug_build():
		return
	for arg in OS.get_cmdline_user_args():          # godot -- --scenario=pre_boss
		if arg.begins_with("--scenario="):
			load_scenario(arg.get_slice("=", 1))
			return
	if FileAccess.file_exists(NEXT_SCENARIO_FILE):
		var scenario := FileAccess.get_file_as_string(NEXT_SCENARIO_FILE).strip_edges()
		DirAccess.remove_absolute(NEXT_SCENARIO_FILE)
		load_scenario(scenario)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_quicksave"):   # tecla 3
		save_game()
	elif event.is_action_pressed(&"debug_quickload"): # tecla 2
		load_game()


func save_game(slot: int = 0) -> Error:
	var cfg := ConfigFile.new()
	GameState.write_to(cfg)
	return SaveCodec.write(cfg, SAVE_DIR + "slot_%d.cfg" % slot)


func load_game(slot: int = 0) -> Error:
	return _load_path(SAVE_DIR + "slot_%d.cfg" % slot)


func load_scenario(scenario: String) -> Error:
	return _load_path(SCENARIO_DIR + scenario + ".cfg")


func _load_path(path: String) -> Error:
	var cfg := ConfigFile.new()
	var err := SaveCodec.read(path, cfg)
	if err != OK:
		push_error("No se pudo cargar %s (%s)" % [path, error_string(err)])
		return err
	for problem in SaveCodec.validate(cfg):
		push_warning("[save] " + problem)
	_migrate(cfg, cfg.get_value("meta", "version", 0))
	GameState.read_from(cfg)
	GameState.save_tampered = SaveCodec.is_tampered(cfg)
	return OK


func _migrate(_cfg: ConfigFile, from_version: int) -> void:
	match from_version:
		_:
			pass   # v1 es la primera; acá van los cambios de estructura futuros
```

```gdscript
# src/state/game_state.gd (serialización)
func write_to(cfg: ConfigFile) -> void:
	cfg.set_value("player", "max_health", max_health)
	cfg.set_value("player", "spawn_scene", spawn_scene)
	cfg.set_value("player", "spawn_point", spawn_point)
	cfg.set_value("player", "current_dungeon", current_dungeon)
	for id in inventory.ids():
		cfg.set_value("inventory", id, inventory.count(id))
	for category in equipment:
		cfg.set_value("equipment", ItemData.Category.find_key(category), equipment[category])
	cfg.set_value("equipment", "buttons", item_buttons.duplicate())   # ConfigFile guarda los Array por referencia
	for id in flags:
		cfg.set_value("flags", id, flags[id])
	for dungeon_id in dungeons:
		var d := dungeons[dungeon_id]
		var section := "dungeon_" + dungeon_id
		cfg.set_value(section, "small_keys", d.small_keys)
		cfg.set_value(section, "has_map", d.has_map)
		cfg.set_value(section, "has_compass", d.has_compass)
		cfg.set_value(section, "has_boss_key", d.has_boss_key)
		cfg.set_value(section, "visited_rooms", d.visited_rooms)

# read_from(cfg) es el espejo: vacía el estado (sin reemplazar el Inventory, para no cortar sus señales),
# lee cada sección, saltea ítems inexistentes con un aviso y emite `loaded`.
```

### 11.8 Herramientas de editor: Save Inspector
<!-- id: save-inspector -->

Plugin en `addons/epiphany_tools/` (dock). Funcionalidades:

1. **Abrir** cualquier partida (encriptada o plana) de `user://saves/` o un escenario de `debug/scenarios/`, usando `SaveCodec.read`.
2. **Ver y editar** por secciones en un `Tree` (sección › clave › valor), con editores por tipo (bool, int, StringName con autocompletado desde `ItemDatabase` / `FlagRegistry`).
3. **Validar** con `SaveCodec.validate`: errores marcados en rojo, pero se puede guardar igual (escenarios imposibles a propósito).
4. **Guardar** como partida (plana o encriptada) o **como escenario**.
5. **Jugar escenario:** escribe `user://debug/next_scenario.txt` y lanza la escena principal. `SaveManager` lo consume al arrancar.

Escenarios iniciales sugeridos: `start`, `bombs_only`, `pre_temple`, `dungeon_no_bow`, `pre_boss`, `full_inventory`, `boss_key_door_locked` (inconsistente a propósito).

### 11.9 Depuración
<!-- id: depuracion -->

Reemplaza los `print` y `print_rich` sueltos. Es el port a GDScript del logger de godot-dojo (`include/tools/logger.hpp`), con canales agregados y conectado al debugger de Godot. Referencia: [Logging en la documentación de Godot](https://docs.godotengine.org/en/latest/tutorials/scripting/logging.html).

```
Log (API: niveles y canales)  ──print_rich / push_*──▶  salida del engine
                                                          │
          errores del engine, addons, prints sueltos ─────┤
                                                          ▼
                                   LogSink (extends Logger, OS.add_logger)
                                      cola + Mutex (puede venir de otro hilo)
                                                          │  Log la vacía en _process
                          ┌───────────────────────────────┼──────────────────────┐
                          ▼                               ▼                      ▼
                pestaña Log del editor           overlay (errores)       archivo / reporte
                 (EngineDebugger)                                         (más adelante)
```

| Pieza | Qué hace | Dónde |
|---|---|---|
| `Log` (autoload) | Niveles `DEBUG`, `INFO`, `SUCCESS`, `WARNING`, `ERROR`. Un canal por sistema: `combat`, `targeting`, `ai`, `items`, `save`, `camera`, `input`, `world`. Debug, info y success salen con `print_rich` y color; warning y error por `push_warning`/`push_error`, así caen en la pestaña Errores con el stack. Nivel y canales en `epiphany/log/level` (Auto = Debug en debug, Warning en release) y `epiphany/log/channels` (vacío = todos); el plugin los registra en Project Settings | `addons/epiphany_tools/debug/runtime/log.gd` |
| `LogSink` | `Logger` propio registrado con `OS.add_logger()` en el `_init` de `Log`. Recibe todo lo que imprime el proceso (juego, engine, addons) y los errores con archivo, línea y backtrace. Solo encola: puede correr en otros hilos y adentro no se puede usar `print` ni `push_error` | `addons/epiphany_tools/debug/runtime/log_sink.gd` |
| Pestaña "Log" | `EditorDebuggerPlugin`. El juego le manda cada línea (`EngineDebugger.send_message("epiphany_log:entry", …)`): nivel, canal, texto, hora y ubicación. Filtros por nivel y canal que se aplican al juego corriendo, y doble clic para abrir el script en la línea | `addons/epiphany_tools/` |
| Monitores | `Performance.add_custom_monitor("epiphany/…", callable)`: gráficos en *Debugger › Monitors*. Cada sistema registra los suyos (enemigos vivos, hitboxes activas…). Funcionan también en builds exportadas | cada sistema |
| `DebugOverlay` (autoload) | `watch(clave, valor)` para valores que cambian cada frame; se muestra con la tecla `1` (`debug_overlay`). Muestra también las últimas 5 advertencias y errores. Reemplaza a `LabelStateTracker`. Es lo que queda en builds exportadas | `addons/epiphany_tools/debug/runtime/debug_overlay.gd` |

Uso:

```gdscript
Log.debug(&"targeting", "Fijado:", name)
Log.info(&"combat", name, "recibió golpe. Vida:", current_health)
Log.warning(&"save", "Checksum no coincide:", path)

if Log.is_enabled(Log.Level.DEBUG, &"ai"):   # solo si el mensaje es caro de armar
	Log.debug(&"ai", _describe_blackboard())
```

**Reglas:**
- El autoload se llama `Log` porque `Logger` es una clase del engine desde Godot 4.5.
- En release el nivel por defecto es `WARNING`. GDScript no elimina las llamadas al compilar: los argumentos se evalúan igual, de ahí `is_enabled()` para mensajes caros.
- `Log` y `DebugOverlay` viven en el plugin `epiphany_tools`, que los registra como autoloads al activarse; la idea es que pueda separarse como plugin propio.
- La pestaña y los filtros en vivo existen solo cuando el juego corre desde el editor (`EngineDebugger.is_active()`). En builds exportadas quedan la consola, el overlay y `user://logs/godot.log` (Godot guarda uno por sesión y conserva los últimos 5).
- El `Logger` se llama en el mismo hilo que imprime (verificado en 4.8-dev7): `Log` prende `skip_main_thread` mientras imprime y el sink descarta esas líneas, así no se duplican. Lo que llega de otros hilos se encola igual.

**Más adelante:** pestaña "Watches" con los valores del overlay, y comandos desde el editor (dar un ítem, cambiar una flag, cargar un escenario) por el mismo canal de mensajes.

---

## 12. Roadmap al MVP
<!-- id: roadmap -->

| # | Hito | Qué se puede probar al terminarlo |
|---|---|---|
| **0** | **Refactor del player + base de datos** (ítems, GameState, guardado v0, componentes, Save Inspector v0) — *tareas en `compass/` (legible en `docs/tareas.md`)* | Guardar, recargar y quedar igual; jugar un escenario |
| **1** | **Combate real**: vida, i-frames, knockback, bloqueo direccional, roll, IA del esqueleto (BT), muerte/respawn, corazones en HUD | Pelear 1 contra 1 y poder perder |
| **2** | **Targeting + Aim**: cambio de objetivo, apuntado stick/mouse | Elegir a quién fijar y apuntar libre |
| **3** | **Inventario + UI**: pantallas Equipo/Ítems, asignar X/Y, slots en HUD, cofres, *item get*, recolectables | Encontrar, equipar y usar un ítem |
| **4** | **Interacción + mundo**: Interactable + prompt, tablillas/caja de texto, vasijas/pasto, flags guardadas | El mundo recuerda lo que hiciste |
| **5** | **Ítems secundarios**: proyectiles + reflejo, arco, bombas + muros agrietados, poción | Cada ítem se usa en al menos un puzzle |
| **6** | **Framework de mazmorra**: Room + cámara clamp/transición, puertas, llaves, bloques por grilla, interruptores, mapa/brújula + pantalla de mapa | Tres salas en bloques grises conectadas |
| **7** | **Overworld**: zona chica, gating bombas → escudo espejo → sello del templo, secretos | Ida y vuelta overworld ↔ mazmorra |
| **8** | **Contenido de mazmorra**: 8 salas en bloques grises, arco a mitad de camino, llave del jefe | La mazmorra se recorre entera |
| **9** | **Jefe**: importar rig, fases 1–2 con LimboAI | Se puede terminar el juego |
| **10** | **Terminación**: título, selección de partida, game over, opciones, doom ambiental, audio, build para playtesters (compilar LimboAI templates) | MVP |

Recortes si hace falta, en orden: fase 3 del jefe → cota reforzada → carcaj post-mazmorra → sala 7 (fusionar con 6) → pasto/vasijas en overworld.

**No se corta:** doble función del escudo, ítem de la mazmorra, jefe con 2 fases, guardado.

## 13. Fuera del MVP
<!-- id: fuera-mvp -->

Moneda y tiendas · NPCs con diálogo · piezas de corazón · gancho / telequinesis · espadas múltiples o elementales (estructura lista) · spin attack · remapeo de controles · más de una mazmorra · pesca y otras actividades (hay animaciones, tentador pero no).

## 14. Decisiones abiertas
<!-- id: decisiones-abiertas -->

- [ ] Historia: opción A o B (o propia). Título del juego.
- [ ] ¿Varias espadas o una espada con modificadores elementales?
- [ ] Layout exacto de la mazmorra (conexiones entre salas) y del overworld.
- [ ] Ranuras de guardado: ¿1 o 3 en el MVP?
- [ ] Arte: ¿se mantiene el look KayKit + texturas de prototipo o hay dirección de arte propia?
- [ ] Rig del jefe: importarlo al repo y verificar compatibilidad con el AnimationTree actual.
