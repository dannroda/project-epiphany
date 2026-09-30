# Tareas — Project Epiphany

> Export de `compass/`, que es la fuente de verdad. No editar: los cambios se hacen en `compass/` o con `scompass`, y este archivo se regenera.
> Generado: 2026-09-30

## M0 — Refactor del player + base de datos  (1/11)

Dejar armada la base sobre la que se construye todo lo demás: ítems como datos, estado de la partida, guardado, componentes de combate y un player ordenado en piezas. Casi nada de esto se ve en el juego todavía; lo que cambia es cómo está hecho. Diseño y código de ejemplo: `gdd.md` §11.

**Hecho cuando:**
- El player aparece con el equipo que dice `GameState`, no con la espada y el escudo puestos a mano en la escena.
- F5 guarda, F9 carga, y el juego vuelve exactamente al mismo estado (posición, inventario, equipo, flags).
- Desde el Save Inspector se abre una partida, se edita, se valida y se juega como escenario.
- El esqueleto recibe daño por el camino nuevo (`Hitbox` → `Hurtbox` → `Health`).

### 0.1 Limpieza · Hecho

- [x] Arreglar `is_empty` en `player/hand.gd`
  Devolvía `true` cuando la mano tenía un ítem. Tiene que quedar `return not is_instance_valid(equipped_item)`.
- [x] Evitar que la espada del esqueleto rompa el juego
  En `src/items/equipable_item.gd`, al principio de `_on_hit_box_body_entered`, agregar `if character == null: return`. La `Sword1H` de `enemy.tscn` no tiene `character` asignado y fallaría si su hitbox se activara. Esa espada pasa a ser solo decorativa en 0.8.
- [x] Borrar `src/debug/camera_selector.gd` y su `.uid`
  Estaba vacío.
- [x] Sacar el código comentado de `levels/test.gd`
- [x] Borrar los mensajes de depuración de la consola
  Los `print_rich` de `src/entities/enemy.gd` (al fijar, soltar y golpear al esqueleto), el `printt` de `on_death_finished` en ese mismo archivo, y el `print_rich` de `src/items/equipable_item.gd` (fuerza transferida). Esos scripts se reescriben en 0.7 a 0.9.

**Prueba:** Correr `levels/test.tscn`, fijar y golpear al esqueleto: no aparece nada en la consola y no hay errores.

**Notas:** Arreglos chicos del código actual. Se puede hacer en cualquier momento.

No toques `addons/scope_compass/`: es un symlink al repo de Scope Compass y los cambios van allá.

### 0.2 Input map · Pendiente

- [ ] Acciones de juego: `interact`, `dodge`, `item_1`, `item_2`
  `interact` (B / E), `dodge` (B / Espacio), `item_1` (X / click derecho) e `item_2` (Y / R).
- [ ] Apuntado: `aim_left`, `aim_right`, `aim_up`, `aim_down`
  Cada una con su dirección del stick derecho. El mouse no necesita acción: se lee directo por código.
- [ ] Cambio de objetivo: `target_next`, `target_prev`
  `target_next` (Tab y rueda abajo) y `target_prev` (Shift+Tab y rueda arriba). El flick del stick derecho se detecta por código, no es una acción.
- [ ] Menús: `pause`, `map`, `menu_tab_left`, `menu_tab_right`
  `pause` (Start / Esc o I), `map` (Select / M), `menu_tab_left` (LB / Q) y `menu_tab_right` (RB / E).
- [ ] Depuración: `debug_quicksave`, `debug_quickload`
  `debug_quicksave` (F5) y `debug_quickload` (F9), solo teclado.

**Prueba:** Las 16 acciones nuevas aparecen en el Input Map, cada una con su botón de gamepad y su tecla (las de depuración, solo tecla).

**Notas:** Acciones nuevas que van a usar los hitos siguientes. Se agregan en *Project › Project Settings › Input Map*. La tabla completa está en el GDD (§4.3).

`interact` y `dodge` comparten el botón B a propósito: el código decide cuál corresponde según haya algo para interactuar cerca.

Se puede hacer en cualquier momento.

**Referencias:** `gdd.md#input`

### 0.3 Ítems: datos · Pendiente

- [ ] Crear `src/combat/attack_data.gd`
  Un recurso chico con la animación y el tramo en que pega un ataque. Código en [[gdd#ventanas-ataque]]. Va primero porque la espada lo necesita.
- [ ] Crear la clase `ItemData` (`src/items/item_data.gd`)
  Los datos de un ítem: id, nombre, ícono, categoría, cantidad máxima, modelo, comportamiento y daño. Código en [[gdd#items-datos]].
- [ ] Crear los comportamientos en `src/items/behaviors/`
  `item_behavior.gd` (la base) y `melee_behavior.gd` (la espada, con su lista de ataques `combo`). Para proyectil, colocar y consumible, crear los archivos con la clase vacía; se completan en M5.
- [ ] Crear `src/items/modifiers/item_modifier.gd`
  La base de los modificadores (fuego, rayo…). Queda vacía hasta decidir si hay espadas elementales.
- [ ] Crear `src/items/item_use_context.gd`
  Los datos que recibe un comportamiento al usar un ítem: quién lo usa, desde dónde y hacia dónde apunta.
- [ ] Crear `src/items/inventory.gd`
  Lleva la cuenta de cuántos de cada ítem tiene el jugador. No es un nodo ni un recurso; lo usa `GameState` en 0.5.
- [ ] Crear `src/items/item_database.gd`
  El recurso `ItemDatabase`, que busca ítems por id.
- [ ] Crear los 15 ítems en `data/items/`
  Clic derecho › Nuevo recurso › `ItemData`: `sword_basic`, `shield_wood`, `shield_mirror`, `tunic`, `bow`, `arrow`, `bomb_bag`, `bomb`, `potion`, `bottle_empty`, `small_key`, `boss_key`, `dungeon_map`, `compass`, `heart_container`. Alcanza con id, nombre y categoría; íconos y modelos pueden quedar vacíos.
- [ ] Crear `data/item_database.tres` con los 15 ítems
  Un recurso `ItemDatabase`: arrastrar los 15 ítems a su lista `items`.
- [ ] Agregar el autoload `Items` (`src/items/items.gd`)
  Crear el script y agregarlo en *Project Settings › Globals › Autoload*. Va al final porque necesita que `data/item_database.tres` ya exista.

**Prueba:** Con el juego corriendo, desde un script de prueba o el debugger remoto: `Items.get_item(&"sword_basic").display_name` devuelve el nombre de la espada.

**Notas:** Crea la base de datos de ítems. Cada ítem es un recurso `.tres` con sus datos, y lo que hace al usarse es otro recurso que se le enchufa (su comportamiento). Así una espada de fuego no necesita una clase nueva.

Todavía no se usa en el juego: el player empieza a usarla en 0.9. El código de ejemplo de cada clase está en el GDD (§11.2). Hacé los pasos en orden: el autoload necesita que los `.tres` ya existan.

**Referencias:** `gdd.md#items-datos`

### 0.4 Flags · Pendiente

- [ ] Crear `src/state/flag_definition.gd`
  Un recurso con `id`, `description` y `default_value` (una flag declarada). Si Godot no deja exportar `default_value` como `Variant`, usar `bool` por ahora: casi todas las flags son sí o no.
- [ ] Crear `src/state/flag_registry.gd`
  El recurso `FlagRegistry`, con la lista de definiciones y las funciones `has()` y `default_of()`. Código en [[gdd#estado-flags]].
- [ ] Crear `data/flag_registry.tres` con las flags de hoy
  Con el nivel de prueba alcanza una de ejemplo: `ow_test_chest`.

**Prueba:** `load("res://data/flag_registry.tres").has(&"ow_test_chest")` devuelve `true`, y con cualquier otro id devuelve `false`.

**Notas:** Las flags son el estado del mundo que se guarda: un cofre abierto, una puerta destrabada. Se declaran en un registro para evitar errores de tipeo y para que el Save Inspector pueda avisar cuando una partida tiene una flag que no existe. Diseño en el GDD (§11.6).

**Referencias:** `gdd.md#estado-flags`

### 0.5 GameState · Pendiente

- [ ] Crear `src/state/dungeon_state.gd`
  El estado de una mazmorra: llaves chicas, mapa, brújula, llave del jefe y salas visitadas.
- [ ] Crear el autoload `GameState` (`src/state/game_state.gd`)
  Incluye `give()`, el único lugar por donde entran ítems (manda las llaves a la mazmorra y las mejoras a donde van), y `equip()`. Código en [[gdd#estado-flags]].
- [ ] Escribir `write_to(cfg)` y `read_from(cfg)`
  Pasan el estado a un `ConfigFile` y de vuelta. `read_from` primero vuelve todo a cero y después lee, para que no queden restos de la partida anterior.
- [ ] Definir la partida nueva
  Espada básica, escudo de madera y túnica equipados, y 3 corazones.

**Prueba:** Llamar `write_to()` sobre un `ConfigFile` nuevo, cambiar algo del estado (por ejemplo, sumar bombas) y llamar `read_from()` con ese mismo `ConfigFile`: el estado vuelve a ser el de antes.

**Notas:** `GameState` es la partida en memoria: inventario, equipo, flags, mazmorras y punto de aparición. Es un autoload, así sobrevive a los cambios de escena. Guardar y cargar (0.6) solo lo copia al disco y de vuelta.

Necesita 0.3 y 0.4. Diseño en el GDD (§11.6).

**Referencias:** `gdd.md#estado-flags`

### 0.6 Guardado · Pendiente

- [ ] Crear `src/save/save_codec.gd`
  Funciones estáticas para escribir, leer, calcular el checksum, detectar partidas modificadas y validarlas. Es estático para que también lo use el Save Inspector (0.10). Código en [[gdd#guardado]].
- [ ] Crear el autoload `SaveManager` (`src/save/save_manager.gd`)
  F5 guarda, F9 carga, y al arrancar puede cargar un escenario de `debug/scenarios/` (con el argumento `--scenario=nombre` o con el archivo que deja el Save Inspector).
- [ ] Guardar y restaurar la posición del player
  Por ahora alcanza con la posición exacta; cuando haya salas y overworld pasa a puntos de aparición con nombre.
- [ ] Agregar la feature `plain_saves` al preset de debug
  En *Project › Export › Features*, para que las builds de prueba también guarden en texto plano.
- [ ] Excluir `debug/scenarios/*` del preset de release
  En *Resources › Filters to exclude files*.
- [ ] Escribir dos escenarios en `debug/scenarios/`
  A mano: `start.cfg` (partida nueva) y `full_inventory.cfg` (con todo el inventario).

**Prueba:** Jugar, apretar F5, cerrar el juego, abrirlo y apretar F9: todo vuelve igual. Después editar a mano el archivo de `user://saves/`: al cargar aparece un aviso en la consola y `GameState.save_tampered` queda en `true`.

**Notas:** Guarda y carga partidas en `user://saves/`. Desde el editor se guarda en texto plano, para poder leerlo y editarlo; en release, encriptado, para que nadie lo edite por accidente.

Necesita 0.5. Diseño completo y código en el GDD (§11.7).

**Referencias:** `gdd.md#guardado`

### 0.11 Sistema de depuración · Pendiente

- [ ] Crear el autoload `Log` (`src/debug/log.gd`)
  Niveles debug, info, success, warning y error, y un canal por sistema (`combat`, `targeting`, `ai`, `items`, `save`, `camera`, `input`, `world`). Debug, info y success salen con `print_rich` y color; warning y error van por `push_warning`/`push_error`, así caen en la pestaña Errores con el stack.
- [ ] Registrar un `Logger` propio (`src/debug/log_sink.gd`)
  Con `OS.add_logger()` en el `_init` de `Log`. Recibe todo lo que se imprime (juego, engine y addons, LimboAI incluido) y todos los errores con archivo, línea, función y backtrace. Puede llamarse desde otros hilos: guarda lo recibido en una cola protegida con `Mutex`, y `Log` la vacía en `_process`. Adentro no se puede usar `print` ni `push_error` (se llamaría a sí mismo).
- [ ] Agregar `epiphany/log/level` y `epiphany/log/channels` a `project.godot`
  Con *Advanced Settings* activado se editan desde Project Settings.
- [ ] Reemplazar los prints comentados por llamadas a `Log`
  Los de `src/entities/enemy.gd` y `src/items/equipable_item.gd`, y el `printt` de `on_death_finished`. Por ejemplo: `Log.info(&"combat", name, "recibió golpe. Vida:", current_health)`.
- [ ] Registrar monitores propios
  Con `Performance.add_custom_monitor("epiphany/…", callable)` para lo que ya se puede medir (enemigos vivos, objetivo fijado 0/1). Se ven como gráficos en *Debugger › Monitors*. Cada sistema nuevo (hitboxes en 0.7, por ejemplo) suma los suyos.
- [ ] Crear la pestaña "Log" en el debugger del editor
  Un `EditorDebuggerPlugin` en `addons/epiphany_tools/` (si el plugin todavía no existe por 0.10, se crea acá). El juego le manda con `EngineDebugger.send_message("epiphany_log:entry", …)` las líneas de `Log` (con nivel y canal) y lo que capturó el `Logger` que no vino de `Log`: errores y mensajes del engine y de addons, con canal `engine`.
- [ ] Filtrar desde la pestaña con el juego corriendo
  Al cambiar nivel o canales, el editor le manda el filtro al juego (`EditorDebuggerSession.send_message`) y el juego lo aplica al momento (`EngineDebugger.register_message_capture`).
- [ ] Doble clic en una línea abre el script donde se generó
  Con `EditorInterface.edit_script()`. Para errores, la ubicación sale del backtrace que da el `Logger`; para las líneas de `Log`, de `get_stack()`.
- [ ] Crear el overlay `DebugOverlay` (F3)
  Autoload con `watch(clave, valor)` para valores que cambian cada frame (estado, velocidad, objetivo), y la acción `debug_overlay` (F3) para mostrarlo u ocultarlo. Reemplaza a `LabelStateTracker` (`src/debug/label_prop.gd`) y sirve también en builds exportadas.
- [ ] Para más adelante: pestaña Watches y comandos desde el editor
  Los valores del overlay en vivo en una pestaña del debugger, y botones que le mandan órdenes al juego (dar un ítem, cambiar una flag, cargar un escenario).

**Prueba:** Correr `levels/test.tscn` y golpear al esqueleto: la línea aparece en la pestaña Log del debugger. Filtrar por `combat` desde la pestaña oculta el resto sin reiniciar el juego. Doble clic en la línea abre `enemy.gd` donde se generó. En *Debugger › Monitors* aparece la categoría `epiphany`. F3 muestra y oculta el overlay. Un error provocado a propósito (por ejemplo, llamar a un método que no existe) también aparece en la pestaña, con canal `engine`, y el doble clic lleva a la línea.

**Notas:** Reemplaza los `print` y `print_rich` sueltos por un logger con niveles y canales, conectado al debugger de Godot. Es el port a GDScript del logger de godot-dojo (`include/tools/logger.hpp`), con canales agregados.

Conviene hacerla antes de 0.7, así los componentes nuevos ya nacen usando `Log`. El autoload no puede llamarse `Logger`: desde Godot 4.5 es una clase del engine. Los argumentos variables (`...args: Array`) son de GDScript 4.5 en adelante.

Referencia: https://docs.godotengine.org/en/latest/tutorials/scripting/logging.html (clase `Logger`, `OS.add_logger()`, file logging). Godot ya guarda un archivo por sesión en `user://logs/godot.log` y conserva los últimos 5 (*Debug › File Logging*); para playtests alcanza con eso al principio.

**Referencias:** `gdd.md#depuracion`

### 0.7 Componentes y EntityConfig · Pendiente

- [ ] Crear los componentes en `src/components/`
  `damage_info.gd` (los datos de un golpe), `health.gd` (vida e invulnerabilidad después de un golpe), `hurtbox.gd` (la zona que recibe golpes) y `hitbox.gd` (la zona que pega; a cada objetivo le pega una sola vez por ataque). Código en [[gdd#entidades-componentes]].
- [ ] Crear `src/components/attack_runner.gd`
  Prende la hitbox solo durante el tramo del ataque que indica cada `AttackData`, y la apaga si el ataque se interrumpe. Código en [[gdd#ventanas-ataque]].
- [ ] Crear `src/entities/entity_config.gd`
  La ficha de un tipo de entidad: equipo, vida, capacidades como "se puede fijar" o "se puede empujar", altura del indicador y daño de sus ataques.
- [ ] Crear las fichas en `data/entities/`
  `player.tres`, `skeleton.tres` y `test_box.tres`.
- [ ] Crear los ataques en `data/attacks/`
  `sword_slash.tres` (animación `CombatMelee/Melee_1H_Attack_Slice_Diagonal`), `shield_thrust.tres` (`CombatMelee/Melee_Block_Attack`) y `skeleton_slash.tres`. Los tramos en que pega (`active_from`, `active_to`) se ponen a ojo y se ajustan jugando.

**Prueba:** Los scripts no dan errores y los `.tres` se abren en el Inspector con todos sus campos.

**Notas:** Piezas reutilizables para todo lo que pega o recibe golpes (player, enemigos, trampas, jefe), y la ficha de datos de cada tipo de entidad. Todavía no se ven en el juego: se usan en 0.8 y 0.9.

Diseño en el GDD (§11.3 y "Ventanas de ataque").

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#ventanas-ataque`

### 0.8 Enemigo sobre componentes · Pendiente

- [ ] Darle al esqueleto su ficha (`EntityConfig`)
  En `src/entities/enemy.gd`, agregar `@export var config: EntityConfig` y llamar `config.apply_to(self)` en `_ready`. Asignar `data/entities/skeleton.tres` en el Inspector del esqueleto.
- [ ] Agregar `Health` y `Hurtbox` a `enemy.tscn`
  El `Hurtbox` con su CollisionShape. Cuando recibe un golpe: empujar al esqueleto (menos cuanto más alta sea su `knockback_resistance`) y restarle vida.
- [ ] Conectar `Health` con el árbol de comportamiento
  `died` pone `is_dead` en el blackboard (reemplaza `_start_death`) y `damaged` pone `is_hit`.
- [ ] Borrar `take_hit`, `select` y `deselect` de `enemy.gd`
- [ ] Agregar `Hitboxes/Front` y `AttackRunner` al esqueleto
  Bajo `ModelController`: una `Hitbox` delante del esqueleto y un nodo `AttackRunner`. El daño sale de `attack_damage` y `attack_knockback` de su ficha. La `Sword1H` queda solo como modelo.
- [ ] Las cajas de prueba siguen siendo `RigidBody3D`
  `TestObject` recibe el empujón por `Hitbox._on_body_entered`, sin `Hurtbox`.

**Prueba:** Se prueba al terminar 0.9: pegarle al esqueleto le baja la vida y muere con su animación. Las cajas siguen saliendo despedidas.

**Notas:** El esqueleto pasa a usar los componentes de 0.7: recibe daño por `Hurtbox` y `Health` en lugar de `take_hit`. Todavía no ataca: la IA de ataque es M1.

Necesita 0.7. Ojo: la espada del player sigue llamando `take_hit` hasta 0.9, así que conviene hacer 0.8 y 0.9 seguidas.

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#ventanas-ataque`

### 0.9 Refactor del player · Pendiente

- [ ] Crear `player/components/equipment.gd`
  Escucha `GameState.equipment_changed` y pone el modelo de cada ítem equipado en `Hand_R`, `Hand_L` o `BackShield`. El escudo va en la mano y en la espalda a la vez (`set_guard` alterna cuál se ve). Sacar de `player.tscn` la `Sword1H` y los dos `shield_badge` puestos a mano.
- [ ] Convertir `EquippableItem` en `EquippedItem`
  En `src/items/equipable_item.gd`: solo el modelo, con una referencia a su `ItemData`. Sin hitbox propia, sin `character` y sin el daño fijo de 10. La guarda que agregaste en 0.1 desaparece con esto.
- [ ] Agregar `Hitboxes/Front` y `AttackRunner` al player
  Bajo `ModelController`, un área en arco o caja delante del personaje. El daño de la hitbox sale de la espada equipada y se actualiza al cambiar de espada.
- [ ] Conectar el estado `Attacking` con el `AttackRunner`
  En `player/states/attacking.gd`, llamar `attack_runner.start()` al entrar y `stop()` al salir, con el `AttackData` que toca del `combo` de la espada. El golpe con escudo usa `shield_thrust.tres`.
- [ ] Quitar `trigger_equipped_item` de la animación y de `hand.gd`
  Es una pista de método en `Melee_1H_Attack_Slice_Horizontal` (`player/animation/anim_bin/combat/melee/`). Después borrar `Hand.trigger_equipped_item`; si `hand.gd` queda vacío, borrarlo.
- [ ] Mover el lock-on a `player/components/targeting.gd`
  Pasar ahí `_lock_best_target`, `_get_most_centered_target`, `_set_target`, `_clear_target`, `_is_in_range` y la lectura de `z-lock`, que hoy están en `state_machine.gd`. Expone el objetivo actual (`current`) y la señal `target_changed`. El cambio de objetivo es M2: acá solo se mueve lo que ya existe.
- [ ] Usar la altura de la ficha en el indicador de objetivo
  `src/tools/target_indicator.gd` toma `target_height` de la `EntityConfig` de cada entidad en lugar del `height_offset` fijo.
- [ ] Agregar `Health` y `Hurtbox` al player
  Con la vida inicial de `GameState.max_health`. Alcanza con que el daño llegue: bloquear según hacia dónde mirás es M1.
- [ ] Dejar `player.gd` y `state_machine.gd` solo con lo suyo
  `player.gd` conecta los componentes (referencias, `set_guard`, `is_blocking()`); `state_machine.gd` queda con las transiciones y la lectura de movimiento y ataque. Diseño en [[gdd#player]].

**Prueba:** Cambiar el escudo equipado a `shield_mirror` desde el Save Inspector y cargar: el player aparece con el otro escudo. Pegarle al esqueleto: pierde vida una sola vez por golpe. Con *Debug › Visible Collision Shapes*, rodar o recibir un golpe en medio de un ataque apaga la hitbox.

**Notas:** El player se arma con componentes: el equipo sale de `GameState`, las hitboxes viven en el personaje y el lock-on pasa a un nodo propio. Es la tarea más grande de M0; conviene seguir los pasos en orden.

Necesita 0.3, 0.5 y 0.7. Diseño en el GDD (§11.4 y "Ventanas de ataque").

**Referencias:** `gdd.md#player`, `gdd.md#ventanas-ataque`

### 0.10 Save Inspector v0 · Pendiente

- [ ] Crear el plugin `addons/epiphany_tools/` con un dock
  `plugin.cfg` + `plugin.gd`, con `EditorDock` y `add_dock()` como en `addons/scope_compass/scope_compass.gd`. Carpeta normal, no symlink.
- [ ] Listar partidas y escenarios
  Las partidas de `user://saves/` y los escenarios de `res://debug/scenarios/`.
- [ ] Mostrar y editar la partida en un `Tree`
  Sección › clave › valor, con edición de sí/no, números y texto.
- [ ] Botón Validar
  Usa `SaveCodec.validate()` y marca en rojo lo que está mal (ítems que no existen, cantidades fuera de rango, flags no declaradas). Se puede guardar igual, para forzar casos imposibles a propósito.
- [ ] Botones Guardar, Guardar como escenario y Jugar escenario
  Jugar escribe `user://debug/next_scenario.txt` y lanza el juego con `EditorInterface.play_main_scene()`.
- [ ] Para más adelante: autocompletar ids de ítems y flags

**Prueba:** Abrir una partida en el dock, agregar `bomb=3` en `[inventory]`, validar y apretar Jugar escenario: el juego arranca con 3 bombas.

**Notas:** Un dock del editor para abrir, editar, validar y jugar partidas guardadas. Sirve para probar situaciones raras sin tener que jugar hasta ahí.

Va en `addons/epiphany_tools/`, como carpeta normal (no un symlink como `addons/scope_compass/`). La API de docks de Godot 4.8 ya la resolvió Scope Compass: `addons/scope_compass/scope_compass.gd` usa `EditorDock` y `add_dock()`; copiá ese patrón.

Necesita 0.6. Diseño en el GDD (§11.8).

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
