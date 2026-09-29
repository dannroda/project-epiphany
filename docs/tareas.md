# Tareas — Project Epiphany

> Export de `compass/`, que es la fuente de verdad. No editar: los cambios se hacen en `compass/` o con `scompass`, y este archivo se regenera.
> Generado: 2026-09-29

## M0 — Refactor del player + base de datos  (0/10)

Que ítems, estado del juego, guardado y componentes existan como base para los hitos siguientes. Diseño y snippets: `gdd.md` §11.

**Hecho cuando:**
- El player arranca con el equipo que dice `GameState` (no con espada y escudo cableados en la escena).
- F5 guarda, F9 carga y el estado vuelve igual (posición, inventario, equipo, flags).
- Desde el Save Inspector se abre una partida, se edita, se valida y se juega como escenario.
- El enemigo recibe daño vía `Hitbox` → `Hurtbox` → `Health`.

### 0.1 Limpieza · Pendiente

- [ ] `player/hand.gd`: `is_empty` devuelve lo contrario → `not is_instance_valid(...)`
- [ ] `enemy.tscn`: la `Sword1H` no tiene `character`; evitar que se active hasta 0.8
- [ ] Borrar `src/debug/camera_selector.gd` (vacío) o darle uso
- [ ] `levels/test.gd`: sacar el código comentado
- [ ] `print_rich` de `enemy.gd` / `equipable_item.gd` → detrás de un flag de debug o eliminar

**Notas:** Se puede hacer en cualquier momento.

### 0.2 Input map · Pendiente

- [ ] `interact`, `dodge`, `item_1`, `item_2`
- [ ] `aim_left`, `aim_right`, `aim_up`, `aim_down` (stick derecho)
- [ ] `target_next`, `target_prev`
- [ ] `pause`, `map`, `menu_tab_left`, `menu_tab_right`
- [ ] `debug_quicksave` (F5), `debug_quickload` (F9)

**Notas:** Ver `gdd.md` §4.3. Se puede hacer en cualquier momento.

**Referencias:** `gdd.md#input`

### 0.3 Ítems: datos · Pendiente

- [ ] `src/items/item_data.gd`: `ItemData` con `Category`, `make_damage()`, `is_equipment()`
- [ ] `item_behavior.gd` + `melee_behavior.gd` (`combo: Array[AttackData]`); stubs de projectile, place y consumable
- [ ] `src/items/modifiers/item_modifier.gd` (vacío, estructura lista)
- [ ] `src/items/item_use_context.gd`
- [ ] `item_database.gd` + autoload `Items` (`src/items/items.gd`)
- [ ] `src/items/inventory.gd`
- [ ] `data/items/`: sword_basic, shield_wood, shield_mirror, tunic, bow, arrow, bomb_bag, bomb, potion, bottle_empty, small_key, boss_key, dungeon_map, compass, heart_container
- [ ] `data/item_database.tres` con todos

**Prueba:** `Items.get_item(&"sword_basic").display_name` desde un script de prueba o el debugger.

**Referencias:** `gdd.md#items-datos`

### 0.4 Flags · Pendiente

- [ ] `src/state/flag_definition.gd` (`id`, `description`, `default_value`) y `flag_registry.gd`
- [ ] `data/flag_registry.tres` con las flags conocidas hoy (p. ej. `ow_test_chest`)

**Referencias:** `gdd.md#estado-flags`

### 0.5 GameState · Pendiente

- [ ] `src/state/dungeon_state.gd`
- [ ] Autoload `GameState`: inventario, equipo, `item_buttons`, `max_health`, flags, mazmorras, spawn, `give()`, `equip()`
- [ ] `write_to(cfg)` / `read_from(cfg)` (espejos exactos; `read_from` resetea antes de leer)
- [ ] Partida nueva: `sword_basic`, `shield_wood`, `tunic` equipados

**Referencias:** `gdd.md#estado-flags`

### 0.6 Guardado · Pendiente

- [ ] `src/save/save_codec.gd` (estático): `write`, `read`, `checksum`, `is_tampered`, `validate`, `plain_saves`
- [ ] Autoload `SaveManager`: `save_game`, `load_game`, `load_scenario`, F5/F9, `--scenario=` y `next_scenario.txt`
- [ ] Guardar/restaurar la posición del player (en debug, posición exacta)
- [ ] Feature tag `plain_saves` en el preset de export de debug
- [ ] Excluir `debug/scenarios/*` del preset release
- [ ] `debug/scenarios/start.cfg` y `full_inventory.cfg` escritos a mano

**Prueba:** Guardar, cerrar, abrir, cargar → mismo estado. Modificar a mano un `.cfg` plano → aparece el warning de `validate` y `save_tampered == true`.

**Referencias:** `gdd.md#guardado`

### 0.7 Componentes y EntityConfig · Pendiente

- [ ] `damage_info.gd`, `health.gd`, `hitbox.gd` (con `active_attack` y ya golpeados por swing), `hurtbox.gd`
- [ ] `src/combat/attack_data.gd` y `src/components/attack_runner.gd`
- [ ] `src/entities/entity_config.gd` con `Feature` como flags y `apply_to()`
- [ ] `data/entities/`: player, skeleton, test_box
- [ ] `data/attacks/`: sword_slash (Slice_Diagonal), shield_thrust, skeleton_slash

**Notas:** Ventanas de ataque: `gdd.md` §11.3.

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#ventanas-ataque`

### 0.8 Enemigo sobre componentes · Pendiente

- [ ] `Enemy` con `@export var config: EntityConfig` y `config.apply_to(self)`
- [ ] Nodos `Health` + `Hurtbox`; `Hurtbox.hit` → knockback (según `knockback_resistance`) y `Health.damage`
- [ ] `Health.died` → `is_dead` en el blackboard; `Health.damaged` → `is_hit`
- [ ] Eliminar `take_hit` y `select`/`deselect` con prints
- [ ] `Hitboxes/Front` + `AttackRunner`; daño desde `config.attack_damage`; `Sword1H` solo visual
- [ ] `TestObject`: sigue como `RigidBody3D`, recibe impulso por `Hitbox._on_body_entered`

**Notas:** La tarea `BTAttack` y la IA que ataca son M1; acá solo la estructura.

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#ventanas-ataque`

### 0.9 Refactor del player · Pendiente

- [ ] `Equipment`: escucha `GameState.equipment_changed` e instancia `equip_scene` en las manos; reemplaza `Sword1H` y `shield_badge` fijos
- [ ] `EquippableItem` → `EquippedItem`: solo visual, sin `HitBox`, sin `character`, sin daño fijo
- [ ] `Hitboxes/Front` + `AttackRunner` en el player; `damage_factory` desde la espada equipada
- [ ] `Attacking`: `attack_runner.start()` en `_enter`, `stop()` en `_exit`; `ShieldThrust` como `AttackData`
- [ ] Quitar el method track `trigger_equipped_item` y `Hand.trigger_equipped_item`
- [ ] `Targeting`: extraer el lock-on de `state_machine.gd`; expone `current` y `target_changed`
- [ ] `TargetIndicator` usa `EntityConfig.target_height`
- [ ] `Health` + `Hurtbox` en el player (desde `GameState.max_health`)
- [ ] `player.gd` como orquestador; `state_machine.gd` solo transiciones e input

**Prueba:** Cambiar `equipment[SHIELD]` a `shield_mirror` desde el Save Inspector → al cargar se ve el otro escudo. Pegarle al esqueleto → pierde vida vía `Health`, una vez por swing. Rodar o recibir un golpe a mitad del ataque → la hitbox se apaga (Visible Collision Shapes).

**Referencias:** `gdd.md#player`, `gdd.md#ventanas-ataque`

### 0.10 Save Inspector v0 · Pendiente

- [ ] `addons/epiphany_tools/plugin.cfg` + `plugin.gd` con un dock
- [ ] Lista de partidas (`user://saves/`) y escenarios (`res://debug/scenarios/`)
- [ ] `Tree` sección › clave › valor, editable
- [ ] Botón Validar (`SaveCodec.validate`) con errores resaltados
- [ ] Guardar, Guardar como escenario, Jugar escenario
- [ ] Después: autocompletado de ids de ítems y flags

**Prueba:** Abrir una partida, agregar `bomb=3`, validar y jugarla como escenario.

**Notas:** Verificar la API de docks en 4.8 (cambió el sistema de pantallas del editor, ver el parche de LimboAI).

**Referencias:** `gdd.md#save-inspector`

## M1 — Combate real

Vida, invulnerabilidad breve, knockback, bloqueo direccional, roll, IA del esqueleto con `BTAttack`, muerte y reaparición, corazones en el HUD.

**Hecho cuando:**
- Pelear 1 contra 1 y poder perder.

## M2 — Targeting + Aim

Cambio de objetivo (flick del stick derecho, Tab, rueda) y apuntado con stick derecho o mouse.

**Hecho cuando:**
- Elegir a quién fijar y apuntar libremente.

## M3 — Inventario + UI

Pantallas Equipo e Ítems, asignar a X/Y, slots en el HUD, cofres, item get, recolectables.

**Hecho cuando:**
- Encontrar, equipar y usar un ítem.

## M4 — Interacción + mundo

`Interactable` con prompt contextual, tablillas y caja de texto, vasijas y pasto, flags del mundo guardadas.

**Hecho cuando:**
- El mundo recuerda lo que hiciste.

## M5 — Ítems secundarios

Proyectiles y reflejo con el escudo, arco, bombas y muros agrietados, poción.

**Hecho cuando:**
- Cada ítem se usa en al menos un puzzle.

## M6 — Framework de mazmorra

`Room` con cámara limitada y transición, puertas, llaves, bloques por grilla, interruptores, mapa y brújula con su pantalla.

**Hecho cuando:**
- Tres salas en bloques grises conectadas.

## M7 — Overworld

Zona chica con el gating bombas → escudo espejo → sello del templo, y los secretos.

**Hecho cuando:**
- Ida y vuelta entre overworld y mazmorra.

## M8 — Contenido de mazmorra

Las 8 salas en bloques grises, el arco a mitad de camino, la llave del jefe.

**Hecho cuando:**
- La mazmorra se recorre entera.

## M9 — Jefe

Importar el rig del ojo con manos y armar las fases 1 y 2 con LimboAI.

**Hecho cuando:**
- Se puede terminar el juego.

## M10 — Terminación

Título, selección de partida, game over, opciones, ambientación del doom, audio y build para playtesters (compilar las plantillas de LimboAI).

**Hecho cuando:**
- MVP jugable por otra persona.
