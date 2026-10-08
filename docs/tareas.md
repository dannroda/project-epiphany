# Tareas — Project Epiphany

> Export de `compass/`, que es la fuente de verdad. No editar: los cambios se hacen en `compass/` o con `scompass`, y este archivo se regenera.
> Generado: 2026-10-08

## M0 — Refactor del player + base de datos  (13/13)

Dejar armada la base sobre la que se construye todo lo demás: ítems como datos, estado de la partida, guardado, componentes de combate y un player ordenado en piezas. Casi nada de esto se ve en el juego todavía; lo que cambia es cómo está hecho. Diseño y código de ejemplo: `gdd.md` §11.

**Hecho cuando:**
- El player aparece con el equipo que dice `GameState`, no con la espada y el escudo puestos a mano en la escena.
- la tecla `3` guarda, la `2` carga, y el juego vuelve exactamente al mismo estado (posición, inventario, equipo, flags).
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

### 0.2 Input map · Hecho

- [x] Acciones de juego: `interact`, `dodge`, `item_1`, `item_2`
  `interact` = B (botón 1), `dodge` = RB (botón 10), `item_1` = X (botón 2), `item_2` = Y (botón 3).
- [x] Renombrar `aim_*` a `look_left`, `look_right`, `look_up`, `look_down`
  Mismo stick derecho (ejes 2 y 3), ya cargado. Cambia el nombre porque ahora sirve para dos cosas: apuntar sin objetivo fijado, y cambiar de objetivo con objetivo fijado (el mismo `look_*` leído con umbral 0.7, en M2). Un solo grupo de acciones: remapearlo mueve los dos usos.
- [x] Borrar `target_next` y `target_prev`
  El cambio de objetivo sale de `look_*`, no necesita acciones propias. Sin D-pad en el targeting: queda libre.
- [x] Menús: `pause`, `map`, `ui_tab_left`, `ui_tab_right`
  `pause` = Start (botón 6), `map` = Back (botón 4), `ui_tab_left` = LB (botón 9), `ui_tab_right` = RB (botón 10). El prefijo `ui_` marca que son del contexto de menús: por eso RB no choca con `dodge`.
- [x] Depuración: `debug_overlay`, `debug_quickload`, `debug_quicksave`
  Teclas `2` (cargar) y `3` (guardar), y `debug_overlay` en la `1`. Solo teclado: son herramientas de desarrollo, no controles del jugador. Provisorias, porque el teclado de desarrollo no tiene teclas F.

**Prueba:** Con un gamepad conectado, cada acción responde a su botón: Start abre la pausa, Back el mapa, X/Y quedan para los ítems y RB para la esquiva. No queda ningún input repetido dentro del mismo contexto.

**Notas:** Acciones de gamepad para los hitos siguientes, en *Project › Project Settings › Input Map*. Mapeo completo, con el índice de cada botón en Godot: [[gdd#input]].

Solo gamepad por ahora: teclado y mouse se definen más adelante. Las teclas que ya existen quedan como provisorias.

Se puede hacer en cualquier momento.

**Referencias:** `gdd.md#input`

### 0.11 Sistema de depuración · Hecho

- [x] Crear el autoload `Log` (`addons/epiphany_tools/debug/runtime/log.gd`)
  Niveles debug, info, success, warning y error, y un canal por sistema (`combat`, `targeting`, `ai`, `items`, `save`, `camera`, `input`, `world`). Debug, info y success salen con `print_rich` y color; warning y error van por `push_warning`/`push_error`, así caen en la pestaña Errores con el stack. Lo registra el plugin `epiphany_tools` al activarse.
- [x] Registrar un `Logger` propio (`addons/epiphany_tools/debug/runtime/log_sink.gd`)
  Con `OS.add_logger()` en el `_init` de `Log`. Recibe todo lo que se imprime (juego, engine y addons, LimboAI incluido) y todos los errores con archivo, línea, función y backtrace. Puede llamarse desde otros hilos: guarda lo recibido en una cola protegida con `Mutex`, y `Log` la vacía en `_process`. Adentro no se puede usar `print` ni `push_error` (se llamaría a sí mismo).
- [x] Registrar `epiphany/log/level` y `epiphany/log/channels` en Project Settings
  Los registra el plugin en `_enter_tree`. Nivel: Auto (Debug en debug, Warning en release) o uno fijo. Canales: vacío = todos.
- [x] Reemplazar los prints comentados por llamadas a `Log`
  Los de `src/entities/enemy.gd` y `src/items/equipable_item.gd`, y el `printt` de `on_death_finished`. Por ejemplo: `Log.info(&"combat", name, "recibió golpe. Vida:", current_health)`.
- [x] Registrar monitores propios
  Con `Performance.add_custom_monitor("epiphany/…", callable)` para lo que ya se puede medir (enemigos vivos, objetivo fijado 0/1). Se ven como gráficos en *Debugger › Monitors*. Cada sistema nuevo (hitboxes en 0.7, por ejemplo) suma los suyos.
- [x] Crear la pestaña "Log" en el debugger del editor
  Un `EditorDebuggerPlugin` en `addons/epiphany_tools/` (si el plugin todavía no existe por 0.10, se crea acá). El juego le manda con `EngineDebugger.send_message("epiphany_log:entry", …)` las líneas de `Log` (con nivel y canal) y lo que capturó el `Logger` que no vino de `Log`: errores y mensajes del engine y de addons, con canal `engine`.
- [x] Filtrar desde la pestaña con el juego corriendo
  Al cambiar nivel o canales, el editor le manda el filtro al juego (`EditorDebuggerSession.send_message`) y el juego lo aplica al momento (`EngineDebugger.register_message_capture`).
- [x] Doble clic en una línea abre el script donde se generó
  Con `EditorInterface.edit_script()`. Para errores, la ubicación sale del backtrace que da el `Logger`; para las líneas de `Log`, de `get_stack()`.
- [x] Crear el overlay `DebugOverlay` (tecla `1`)
  Autoload con `watch(clave, valor)` para valores que cambian cada frame (estado, velocidad, objetivo), y la acción `debug_overlay` (tecla `1`) para mostrarlo u ocultarlo. Reemplaza a `LabelStateTracker` (`src/debug/label_prop.gd`) y sirve también en builds exportadas. También muestra las últimas 5 advertencias y errores.
- [ ] Para más adelante: pestaña Watches y comandos desde el editor
  Los valores del overlay en vivo en una pestaña del debugger, y botones que le mandan órdenes al juego (dar un ítem, cambiar una flag, cargar un escenario).

**Prueba:** Correr `levels/test.tscn` y golpear al esqueleto: la línea aparece en la pestaña Log del debugger. Filtrar por `combat` desde la pestaña oculta el resto sin reiniciar el juego. Doble clic en la línea abre `enemy.gd` donde se generó. En *Debugger › Monitors* aparece la categoría `epiphany`. La tecla `1` muestra y oculta el overlay. Un error provocado a propósito (por ejemplo, llamar a un método que no existe) también aparece en la pestaña, con canal `engine`, y el doble clic lleva a la línea.

**Notas:** Reemplaza los `print` y `print_rich` sueltos por un logger con niveles y canales, conectado al debugger de Godot. Es el port a GDScript del logger de godot-dojo (`include/tools/logger.hpp`), con canales agregados.

El autoload no puede llamarse `Logger`: desde Godot 4.5 es una clase del engine. Los argumentos variables (`...args: Array`) son de GDScript 4.5 en adelante.

Referencia: https://docs.godotengine.org/en/latest/tutorials/scripting/logging.html (clase `Logger`, `OS.add_logger()`, file logging). Godot ya guarda un archivo por sesión en `user://logs/godot.log` y conserva los últimos 5 (*Debug › File Logging*); para playtests alcanza con eso al principio.

Probado en headless (4.8-dev7): `Log` filtra por nivel y canal, el sink captura prints, errores y prints de otros hilos sin duplicar las líneas de `Log`, y el overlay muestra los valores y las advertencias. Probado en el editor (juego embebido): pestaña Log, filtro en vivo, doble clic, monitores y overlay.

**Referencias:** `gdd.md#depuracion`

**Relacionadas:** 0.7 Componentes y EntityConfig; 0.10 Save Inspector v0; 0.8 Enemigo sobre componentes

### 0.3 Ítems: datos · Hecho

- [x] Crear `src/combat/attack_data.gd`
  Un recurso chico con la animación y el tramo en que pega un ataque. Código en [[gdd#ventanas-ataque]]. Va primero porque la espada lo necesita.
- [x] Crear `src/components/damage_info.gd` (sin `team`)
  `DamageInfo` es de 0.7, pero `ItemData.make_damage()` y los modificadores ya lo usan. Se crea acá sin el campo `team`, que depende de `EntityConfig`; 0.7 se lo agrega.
- [x] Crear la clase `ItemData` (`src/items/item_data.gd`)
  Los datos de un ítem: id, nombre, ícono, categoría, cantidad máxima, modelo, comportamiento y daño. Código en [[gdd#items-datos]].
- [x] Crear los comportamientos en `src/items/behaviors/`
  `item_behavior.gd` (la base) y `melee_behavior.gd` (la espada, con su lista de ataques `combo`). Para proyectil, colocar y consumible, crear los archivos con la clase vacía; se completan en M5.
- [x] Crear `src/items/modifiers/item_modifier.gd`
  La base de los modificadores (fuego, rayo…). Queda vacía hasta decidir si hay espadas elementales.
- [x] Crear `src/items/item_use_context.gd`
  Los datos que recibe un comportamiento al usar un ítem: quién lo usa, desde dónde y hacia dónde apunta. `equipped` es `Node3D` por ahora: 0.9 decide qué queda en la mano.
- [x] Crear `src/items/inventory.gd`
  Lleva la cuenta de cuántos de cada ítem tiene el jugador. No es un nodo ni un recurso; lo usa `GameState` en 0.5.
- [x] Crear `src/items/item_database.gd`
  El recurso `ItemDatabase`, que busca ítems por id.
- [x] Crear los 17 ítems en `data/items/`
  `sword_basic`, `shield_wood`, `shield_mirror`, `tunic`, `armor_chainmail`, `bow`, `arrow`, `bomb_bag`, `bomb`, `potion`, `bottle_empty`, `small_key`, `boss_key`, `dungeon_map`, `compass`, `quiver_big`, `heart_container` (los de GDD §6.1). La espada lleva un `MeleeBehavior` con el ataque `data/attacks/sword_slash.tres`. Daño y cantidades máximas son provisorios.
- [x] Crear `data/item_database.tres` con los 17 ítems
  Un recurso `ItemDatabase`: arrastrar los 15 ítems a su lista `items`.
- [x] Agregar el autoload `Items` (`src/items/items.gd`)
  Crear el script y agregarlo en *Project Settings › Globals › Autoload*. Va al final porque necesita que `data/item_database.tres` ya exista.

**Prueba:** Con el juego corriendo, desde un script de prueba o el debugger remoto: `Items.get_item(&"sword_basic").display_name` devuelve el nombre de la espada.

**Notas:** Crea la base de datos de ítems. Cada ítem es un recurso `.tres` con sus datos, y lo que hace al usarse es otro recurso que se le enchufa (su comportamiento). Así una espada de fuego no necesita una clase nueva.

Todavía no se usa en el juego: el player empieza a usarla en 0.9. El código de ejemplo de cada clase está en el GDD (§11.2). Hacé los pasos en orden: el autoload necesita que los `.tres` ya existan.

Daño de la espada (2) y cantidades máximas (flechas 30, bombas 10, llaves chicas 9, contenedores 10) son provisorios: el GDD no los define. Los .tres se generaron con ResourceSaver; `tests/test_items.gd` cubre la prueba de la tarea.

**Referencias:** `gdd.md#items-datos`

**Bloquea a:** 0.5 GameState; 0.9 Refactor del player

**Relacionadas:** 0.12 Tests headless; 3.8 Íconos placeholder de los ítems

### 0.4 Flags · Hecho

- [x] Crear `src/state/flag_definition.gd`
  Un recurso con `id`, `description` y `default_value` (una flag declarada). Si Godot no deja exportar `default_value` como `Variant`, usar `bool` por ahora: casi todas las flags son sí o no.
- [x] Crear `src/state/flag_registry.gd`
  El recurso `FlagRegistry`, con la lista de definiciones y las funciones `has()` y `default_of()`. Código en [[gdd#estado-flags]].
- [x] Crear `data/flag_registry.tres` con las flags de hoy
  Con el nivel de prueba alcanza una de ejemplo: `ow_test_chest`.

**Prueba:** `load("res://data/flag_registry.tres").has(&"ow_test_chest")` devuelve `true`, y con cualquier otro id devuelve `false`.

**Notas:** Las flags son el estado del mundo que se guarda: un cofre abierto, una puerta destrabada. Se declaran en un registro para evitar errores de tipeo y para que el Save Inspector pueda avisar cuando una partida tiene una flag que no existe. Diseño en el GDD (§11.6).

`default_value` es `Variant`: Godot 4.8 deja exportarlo. `tests/test_flags.gd` cubre la prueba de la tarea.

**Referencias:** `gdd.md#estado-flags`

**Bloquea a:** 0.5 GameState; 4.5 Flags del mundo persistentes

### 0.5 GameState · Hecho

- [x] Crear `src/state/dungeon_state.gd`
  El estado de una mazmorra: llaves chicas, mapa, brújula, llave del jefe y salas visitadas.
- [x] Crear el autoload `GameState` (`src/state/game_state.gd`)
  Incluye `give()`, el único lugar por donde entran ítems (manda las llaves a la mazmorra y las mejoras a donde van), y `equip()`. Código en [[gdd#estado-flags]].
- [x] Escribir `write_to(cfg)` y `read_from(cfg)`
  Pasan el estado a un `ConfigFile` y de vuelta. `read_from` primero vuelve todo a cero y después lee, para que no queden restos de la partida anterior.
- [x] Definir la partida nueva
  Espada básica, escudo de madera y túnica equipados, y 3 corazones.

**Prueba:** Llamar `write_to()` sobre un `ConfigFile` nuevo, cambiar algo del estado (por ejemplo, sumar bombas) y llamar `read_from()` con ese mismo `ConfigFile`: el estado vuelve a ser el de antes.

**Notas:** `GameState` es la partida en memoria: inventario, equipo, flags, mazmorras y punto de aparición. Es un autoload, así sobrevive a los cambios de escena. Guardar y cargar (0.6) solo lo copia al disco y de vuelta.

Necesita 0.3 y 0.4. Diseño en el GDD (§11.6).

Partida nueva: espada, escudo de madera y túnica en el inventario y equipados, 3 corazones. `read_from` vacía el `Inventory` existente (`Inventory.clear()`) en lugar de reemplazarlo, y emite `loaded`. `write_to` guarda una copia de `item_buttons`: `ConfigFile` guarda los Array por referencia. `tests/test_game_state.gd` cubre la prueba de la tarea.

**Referencias:** `gdd.md#estado-flags`

**Bloquea a:** 0.6 Guardado; 0.9 Refactor del player; 3.6 Cofres e item get

**Bloqueada por:** 0.3 Ítems: datos; 0.4 Flags

**Relacionadas:** 1.5 Muerte y reaparición del player

### 0.6 Guardado · Hecho

- [x] Crear `src/save/save_codec.gd`
  Funciones estáticas para escribir, leer, calcular el checksum, detectar partidas modificadas y validarlas. Es estático para que también lo use el Save Inspector (0.10). Código en [[gdd#guardado]].
- [x] Escritura atómica y copia de respaldo en `SaveCodec.write`/`read`
  `ConfigFile.save()` escribe sobre el archivo: si el juego se cierra a mitad de camino, la partida queda corrupta. Escribir a `slot_N.cfg.tmp`, mover la partida anterior a `slot_N.cfg.bak` y renombrar el `.tmp` con `DirAccess.rename_absolute()`. Al leer, si `slot_N.cfg` no carga, probar con el `.bak` y avisar. El código del GDD (§11.7) todavía escribe directo: actualizarlo también.
- [x] Crear el autoload `SaveManager` (`src/save/save_manager.gd`)
  la tecla `3` guarda, la `2` carga, y al arrancar puede cargar un escenario de `debug/scenarios/` (con el argumento `--scenario=nombre` o con el archivo que deja el Save Inspector).
- [x] Guardar y restaurar la posición del player
  Por ahora alcanza con la posición exacta; cuando haya salas y overworld pasa a puntos de aparición con nombre.
- [x] Escribir dos escenarios en `debug/scenarios/`
  A mano: `start.cfg` (partida nueva) y `full_inventory.cfg` (con todo el inventario).

**Prueba:** Jugar, apretar `3`, cerrar el juego, abrirlo y apretar `2`: todo vuelve igual. Después editar a mano el archivo de `user://saves/`: al cargar aparece un aviso en la consola y `GameState.save_tampered` queda en `true`.

**Notas:** Guarda y carga partidas en `user://saves/`. Desde el editor se guarda en texto plano, para poder leerlo y editarlo; en release, encriptado, para que nadie lo edite por accidente.

Necesita 0.5. Diseño completo y código en el GDD (§11.7).

Los presets de export (plain_saves en debug, excluir debug/scenarios y tests) pasaron a 10.9: hoy solo existe un preset de Android.

`SaveCodec.read` mira los 4 primeros bytes (`GDEC`) para saber si la partida está encriptada, así no deja errores en la consola. Los escenarios se generaron con `GameState` + `SaveCodec`, así tienen checksum válido. `tests/test_save_manager.gd` guarda y carga en `levels/test.tscn` y comprueba la posición del player y el inventario. También se corrigió `give()`: el contenedor de corazón sumaba 4 sin importar la cantidad.

**Referencias:** `gdd.md#guardado`

**Bloquea a:** 0.10 Save Inspector v0; 0.12 Tests headless

**Bloqueada por:** 0.5 GameState

### 0.7 Componentes y EntityConfig · Hecho

- [x] Crear los componentes en `src/components/`
  `damage_info.gd` (los datos de un golpe), `health.gd` (vida e invulnerabilidad después de un golpe), `hurtbox.gd` (la zona que recibe golpes) y `hitbox.gd` (la zona que pega; a cada objetivo le pega una sola vez por ataque). Código en [[gdd#entidades-componentes]].
- [x] Crear `src/components/attack_runner.gd`
  Prende la hitbox solo durante el tramo del ataque que indica cada `AttackData`, y la apaga si el ataque se interrumpe. Código en [[gdd#ventanas-ataque]].
- [x] Crear `src/entities/entity_config.gd`
  La ficha de un tipo de entidad: equipo, vida, capacidades como "se puede fijar" o "se puede empujar", altura del indicador y daño de sus ataques.
- [x] Crear las fichas en `data/entities/`
  `player.tres`, `skeleton.tres` y `test_box.tres`.
- [x] Crear los ataques en `data/attacks/`
  `sword_slash.tres` (animación `CombatMelee/Melee_1H_Attack_Slice_Diagonal`), `shield_thrust.tres` (`CombatMelee/Melee_Block_Attack`) y `skeleton_slash.tres`. Los tramos en que pega (`active_from`, `active_to`) se ponen a ojo y se ajustan jugando.
- [x] Agregar `team` a `DamageInfo`
  `DamageInfo` se creó en 0.3 sin `team` porque depende de `EntityConfig.Team`. Agregarlo cuando exista `EntityConfig`.

**Prueba:** Los scripts no dan errores y los `.tres` se abren en el Inspector con todos sus campos.

**Notas:** Piezas reutilizables para todo lo que pega o recibe golpes (player, enemigos, trampas, jefe), y la ficha de datos de cada tipo de entidad. Todavía no se ven en el juego: se usan en 0.8 y 0.9.

Diseño en el GDD (§11.3 y "Ventanas de ataque").

El `AttackRunner` del GDD nunca prendía la hitbox (comparaba `monitoring` sin cambiarlo); ahora usa `active_attack` como estado y prende `monitoring` con `set_deferred`. `EntityConfig.make_damage()` arma el `DamageInfo` de un enemigo sin arma. Fichas: jugador 12 HP, esqueleto 8 HP (targetable + pushable), caja de prueba. Tramos de ataque a ojo. `tests/test_components.gd` cubre vida, hitbox, ventanas y fichas.

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#ventanas-ataque`

**Bloquea a:** 0.8 Enemigo sobre componentes; 0.9 Refactor del player

**Relacionadas:** 0.11 Sistema de depuración

### 0.8 Enemigo sobre componentes · Hecho

- [x] Darle al esqueleto su ficha (`EntityConfig`)
  En `src/entities/enemy.gd`, agregar `@export var config: EntityConfig` y llamar `config.apply_to(self)` en `_ready`. Asignar `data/entities/skeleton.tres` en el Inspector del esqueleto.
- [x] Agregar `Health` y `Hurtbox` a `enemy.tscn`
  El `Hurtbox` con su CollisionShape. Cuando recibe un golpe: empujar al esqueleto (menos cuanto más alta sea su `knockback_resistance`) y restarle vida.
- [x] Conectar `Health` con el árbol de comportamiento
  `died` pone `is_dead` en el blackboard (reemplaza `_start_death`) y `damaged` pone `is_hit`.
- [x] Borrar `take_hit`, `select` y `deselect` de `enemy.gd`
- [x] Agregar `Hitboxes/Front` y `AttackRunner` al esqueleto
  Bajo `ModelController`: una `Hitbox` delante del esqueleto y un nodo `AttackRunner`. El daño sale de `attack_damage` y `attack_knockback` de su ficha. La `Sword1H` queda solo como modelo.
- [x] Las cajas de prueba siguen siendo `RigidBody3D`
  `TestObject` recibe el empujón por `Hitbox._on_body_entered`, sin `Hurtbox`.

**Prueba:** Se prueba al terminar 0.9: pegarle al esqueleto le baja la vida y muere con su animación. Las cajas siguen saliendo despedidas.

**Notas:** El esqueleto pasa a usar los componentes de 0.7: recibe daño por `Hurtbox` y `Health` en lugar de `take_hit`. Todavía no ataca: la IA de ataque es M1.

Necesita 0.7. Ojo: la espada del player sigue llamando `take_hit` hasta 0.9, así que conviene hacer 0.8 y 0.9 seguidas.

Capas: la 5 es `Hurtbox`. La `Hurtbox` está en esa capa; la `Hitbox` detecta las capas 4 (Object) y 5. `AttackRunner` junta las `Hitbox` hijas de `hitbox_root` por nombre (`Front` → `front`) en lugar de un Dictionary exportado. El empujón y la subida se escalan con `1 - knockback_resistance`. Hasta terminar 0.9 la espada del player no le hace nada al esqueleto (ya no existe `take_hit`).

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#ventanas-ataque`

**Bloquea a:** 1.4 IA del esqueleto con `BTAttack`

**Bloqueada por:** 0.7 Componentes y EntityConfig

**Relacionadas:** 0.9 Refactor del player; 0.11 Sistema de depuración

### 0.9 Refactor del player · Hecho

- [x] Crear `player/components/equipment.gd`
  Escucha `GameState.equipment_changed` y pone el modelo de cada ítem equipado en `Hand_R`, `Hand_L` o `BackShield`. El escudo va en la mano y en la espalda a la vez (`set_guard` alterna cuál se ve). Sacar de `player.tscn` la `Sword1H` y los dos `shield_badge` puestos a mano.
- [x] Convertir `EquippableItem` en `EquippedItem`
  En `src/items/equipable_item.gd`: solo el modelo, con una referencia a su `ItemData`. Sin hitbox propia, sin `character` y sin el daño fijo de 10. La guarda que agregaste en 0.1 desaparece con esto.
- [x] Agregar `Hitboxes/Front` y `AttackRunner` al player
  Bajo `ModelController`, un área en arco o caja delante del personaje. El daño de la hitbox sale de la espada equipada y se actualiza al cambiar de espada.
- [x] Conectar el estado `Attacking` con el `AttackRunner`
  En `player/states/attacking.gd`, llamar `attack_runner.start()` al entrar y `stop()` al salir, con el `AttackData` que toca del `combo` de la espada. El golpe con escudo usa `shield_thrust.tres`.
- [x] Quitar `trigger_equipped_item` de la animación y de `hand.gd`
  Es una pista de método en `Melee_1H_Attack_Slice_Horizontal` (`player/animation/anim_bin/combat/melee/`). Después borrar `Hand.trigger_equipped_item`; si `hand.gd` queda vacío, borrarlo.
- [x] Mover el lock-on a `player/components/targeting.gd`
  Pasar ahí `_lock_best_target`, `_get_most_centered_target`, `_set_target`, `_clear_target`, `_is_in_range` y la lectura de `z-lock`, que hoy están en `state_machine.gd`. Expone el objetivo actual (`current`) y la señal `target_changed`. El cambio de objetivo es M2: acá solo se mueve lo que ya existe.
- [x] Usar la altura de la ficha en el indicador de objetivo
  `src/tools/target_indicator.gd` toma `target_height` de la `EntityConfig` de cada entidad en lugar del `height_offset` fijo.
- [x] Agregar `Health` y `Hurtbox` al player
  Con la vida inicial de `GameState.max_health`. Alcanza con que el daño llegue: bloquear según hacia dónde mirás es M1.
- [x] Dejar `player.gd` y `state_machine.gd` solo con lo suyo
  `player.gd` conecta los componentes (referencias, `set_guard`, `is_blocking()`); `state_machine.gd` queda con las transiciones y la lectura de movimiento y ataque. Diseño en [[gdd#player]].
- [x] Unificar `Targetting` → `Targeting` en nodos y estados
  Nodos y estados de animación en `player/player.tscn`, `src/entities/enemy.tscn` y `player/animation/new_animation_node_state_machine.tres`, y las referencias en `player/states/idle.gd` y `moving.gd`. Renombrar desde el editor (no a mano en los .tscn/.tres) y revisar que las rutas a nodos y las transiciones de la máquina de estados sigan andando.

**Prueba:** Cambiar el escudo equipado a `shield_mirror` desde el Save Inspector y cargar: el player aparece con el otro escudo. Pegarle al esqueleto: pierde vida una sola vez por golpe. Con *Debug › Visible Collision Shapes*, rodar o recibir un golpe en medio de un ataque apaga la hitbox.

**Notas:** El player se arma con componentes: el equipo sale de `GameState`, las hitboxes viven en el personaje y el lock-on pasa a un nodo propio. Es la tarea más grande de M0; conviene seguir los pasos en orden.

Necesita 0.3, 0.5 y 0.7. Diseño en el GDD (§11.4 y "Ventanas de ataque").

Hecho con el editor cerrado (escenas editadas en disco y caché regenerada con --import). Los modelos van en Marker3D de encaje que conservan las transformaciones que estaban a mano. El escudo espejo tiene su escena (shield_badge con material metálico). La pista trigger_equipped_item estaba también en los .res de player/animation/anim/ (Slice_Diagonal y Slice_Horizontal), que son los que usan las librerías. El renombre Targetting → Targeting se hizo en texto (escenas, máquina de estados y scripts) en lugar de desde el editor. tests/test_player.gd: la espada le pega al esqueleto una sola vez y el equipo sigue a GameState. Queda: probarlo jugando; el StaticBody3D de shield_badge genera un aviso de Jolt por escala cero.

**Referencias:** `gdd.md#player`, `gdd.md#ventanas-ataque`

**Bloquea a:** 1.1 Daño, invulnerabilidad y knockback del player; 2.1 Cambio de objetivo con el stick derecho; 6.1 `Room` y cámara por sala

**Bloqueada por:** 0.3 Ítems: datos; 0.5 GameState; 0.7 Componentes y EntityConfig

**Relacionadas:** 0.8 Enemigo sobre componentes; 1.2 Bloqueo direccional y golpe de escudo; 1.3 Esquiva (roll) con i-frames; 2.2 Componente `Aim`

### 0.10 Save Inspector v0 · Hecho

- [x] Crear el plugin `addons/epiphany_tools/` con un dock
  `plugin.cfg` + `plugin.gd`, con `EditorDock` y `add_dock()` como en `addons/scope_compass/scope_compass.gd`. Carpeta normal, no symlink.
- [x] Listar partidas y escenarios
  Las partidas de `user://saves/` y los escenarios de `res://debug/scenarios/`.
- [x] Editar la partida con pestañas armadas desde los datos
  Partida, Equipo, Inventario, Flags, Mazmorras y Texto (el .cfg crudo). Inventario y Equipo salen de `ItemDatabase` y Flags de `FlagRegistry`: no hace falta tipear ids. Diseño: canvas de mockups, fila "Herramientas de editor".
- [x] Validación en vivo
  `SaveCodec.validate()` corre con cada cambio: una píldora muestra "Válida" o "N problemas" (lleva a la pestaña del problema); lo inválido se ve en rojo con "Quitar". Se puede guardar igual.
- [x] Botones Guardar, Guardar como escenario y Jugar escenario
  Jugar escribe `user://debug/next_scenario.txt` y lanza el juego con `EditorInterface.play_main_scene()`.
- [ ] Para más adelante: tomar la posición del player del juego corriendo
  Pedírsela al juego por el debugger (`EngineDebugger`), como hace la pestaña Log.

**Prueba:** Abrir una partida en el dock, agregar `bomb=3` en `[inventory]`, validar y apretar Jugar escenario: el juego arranca con 3 bombas.

**Notas:** Un dock del editor para abrir, editar, validar y jugar partidas guardadas. Sirve para probar situaciones raras sin tener que jugar hasta ahí.

Va en `addons/epiphany_tools/`, como carpeta normal (no un symlink como `addons/scope_compass/`). La API de docks de Godot 4.8 ya la resolvió Scope Compass: `addons/scope_compass/scope_compass.gd` usa `EditorDock` y `add_dock()`; copiá ese patrón.

Necesita 0.6. Diseño en el GDD (§11.8).

El Tree genérico de la primera versión se reemplazó por pestañas después del mockup. Jugar escribe la partida del dock en `user://debug/inspector_play.cfg` (sin guardar el archivo abierto) y `next_scenario.txt` apunta a esa ruta. Los escenarios en `res://` se guardan sin `.bak`.

**Referencias:** `gdd.md#save-inspector`

**Bloquea a:** 4.5 Flags del mundo persistentes

**Bloqueada por:** 0.6 Guardado

**Relacionadas:** 0.11 Sistema de depuración

### 0.12 Tests headless · Hecho

- [x] Crear el runner `tests/run_tests.gd`
  Script que extiende `SceneTree`: recorre `tests/test_*.gd`, corre cada método `test_*` y termina con `quit(1)` si algo falló. Usar un `assert_eq()` propio que cuente fallos: un `assert()` que falla deja el proceso colgado en lugar de terminar.
- [x] Correrlo por línea de comandos
  `godot --headless --path . --import` una vez (en un checkout limpio las clases con `class_name` todavía no están registradas) y después `godot --headless --path . --script res://tests/run_tests.gd`. Anotar el comando en el README.
- [x] Tests de `SaveCodec`
  Ida y vuelta (escribir y leer da lo mismo), checksum que detecta una edición a mano, migración desde una versión anterior y recuperación desde el `.bak` cuando el archivo principal está roto.
- [x] Tests de la base de ítems
  Que cada `.tres` de ítems cargue, tenga `id` único y que `Items.get_item()` lo encuentre.

**Prueba:** Correr el comando headless: termina con código 0. Romper a propósito un test (por ejemplo, cambiar un valor esperado): termina con código 1 y dice cuál falló.

**Notas:** Para lo que se puede probar sin abrir el juego: guardado, datos de ítems y flags. Los tests de SaveCodec necesitan 0.6, y los de ítems, 0.3.

Los presets de export (plain_saves en debug, excluir debug/scenarios y tests) pasaron a 10.9: hoy solo existe un preset de Android.

**Bloqueada por:** 0.6 Guardado

**Relacionadas:** 0.3 Ítems: datos; 1.1 Daño, invulnerabilidad y knockback del player

### 0.13 Puente con el editor · Hecho

- [x] Servidor HTTP local en `epiphany_tools`
  `addons/epiphany_tools/bridge/editor_bridge.gd`: un `TCPServer` en `127.0.0.1:4713` que atiende pedidos HTTP chicos y responde JSON. Solo escucha en localhost.
- [x] Comandos `scan`, `play`, `stop` y `status`
  `scan` espera a que termine el escaneo (clases, UIDs, imports) antes de responder.
- [x] Comando `log`
  Errores y mensajes del editor (un `Logger` propio) y las líneas que llegan a la pestaña Log del juego, con número de secuencia para pedir solo lo nuevo.
- [x] Comandos `open`, `save`, `autoload` y `setting`
  Abrir un script en una línea o una escena; guardar escenas; agregar autoloads y settings desde el editor, así no se pisa `project.godot`.

**Prueba:** Con el editor abierto: `curl -s localhost:4713/ping` responde. Crear un script con `class_name` y `curl -s -X POST localhost:4713/scan`: la clase queda registrada sin tocar el editor. `play` corre la escena principal y `log` devuelve sus líneas.

**Notas:** Para que Claude pueda manejar el editor sin pedirle al usuario que le dé foco o haga clics. Es un plugin aparte, `addons/editor_bridge/`, para que pueda recargar `epiphany_tools` (`reload_plugin`) sin apagarse. Comandos: ping, status, scan, play [scene], stop, log [since], open path [line], save, plugin name enabled, reload_plugin name, autoload name path, setting name value. Si se recarga, reintenta abrir el puerto cada segundo. `autoload` y `setting` todavía no se probaron.

## M1 — Combate real  (7/7)

Vida, invulnerabilidad breve, knockback, bloqueo direccional, roll, IA del esqueleto con `BTAttack`, muerte y reaparición, corazones en el HUD.

**Hecho cuando:**
- Pelear 1 contra 1 y poder perder.

### 1.1 Daño, invulnerabilidad y knockback del player · Hecho

- [x] Conectar `Hurtbox.hit` en `player.gd`
  `_on_hurtbox_hit(info)`: reduce el daño con `equipment.damage_reduction()` (mínimo 1) y llama `Health.damage()`. El bloqueo se suma en 1.2. Código en [[gdd#ventanas-ataque]].
- [x] Estado `Hurt` en el `LimboHSM`
  Retroceso con `DamageInfo.knockback` en la dirección fuente → player, input bloqueado ≈0.25 s, animación `Hit_A`/`Hit_B`. Al entrar llama `attack_runner.stop()`.
- [x] Parpadeo mientras dura la invulnerabilidad
  Alternar la visibilidad del modelo (o un uniform del material) mientras `Health.is_invulnerable()`. Con `delta`, así la pausa no lo consume.
- [x] Monitor `epiphany/player_hp` y watch en el overlay
  `Performance.add_custom_monitor` y `DebugOverlay.watch(&"hp", …)`. Ver [[gdd#depuracion]].
- [x] Tests headless de `Health`
  Daño, invulnerabilidad (un segundo golpe dentro de la ventana no cuenta), curar sin pasar el máximo, `died` una sola vez. En el runner de 0.12.

**Prueba:** El esqueleto le pega al player: pierde vida, retrocede, parpadea ≈0.8 s y durante el parpadeo no recibe otro golpe. Los tests de `Health` pasan.

**Notas:** Primer paso de M1: que al player le duela. Usa `Health`, `Hurtbox` y `DamageInfo` de M0.

Skills: `godot:godot-gdscript`, `godot:godot-gdscript-headless-testing`.

El estado `Hurt` se alcanza desde cualquier estado (`anystate`); la animación es un OneShot `Hurt` (General/Hit_A) entre la salida del AnimationTree y `Attack`. El parpadeo alterna `ModelController/Visuals` en `_process` (la pausa lo frena). La reducción de la armadura sale de `Equipment.damage_reduction()`, con mínimo 1 de daño. Probado con tests (`test_player.gd`); la prueba con el esqueleto pegando queda para 1.4.

**Referencias:** `gdd.md#combate`, `gdd.md#entidades-componentes`

**Bloqueada por:** 0.9 Refactor del player

**Relacionadas:** 0.12 Tests headless

### 1.2 Bloqueo direccional y golpe de escudo · Hecho

- [x] Implementar `_is_in_front()` con cono de ±60°
  `block_angle_deg` exportado. El modelo KayKit mira a +Z local. Código en [[gdd#ventanas-ataque]] ("Bloqueo direccional").
- [x] `_on_blocked()`: chispa, retroceso leve y sonido
  Animación `Melee_Block_Hit`. Partículas y sonido placeholder; el pulido va en 1.7.
- [x] Ver el cono en debug
  Con el overlay activo, dibujar el cono de bloqueo (ImmediateMesh o `DebugDraw`) para ajustarlo jugando.
- [x] El golpe de escudo aturde
  `shield_thrust.tres` con poco daño y mucho knockback; al conectar setea `stunned` en el blackboard del enemigo (lo consume 1.4).

**Prueba:** Bloqueando de frente el golpe del esqueleto no hace daño; desde atrás o de costado (fuera del cono) sí. El golpe de escudo deja al esqueleto aturdido un momento.

**Notas:** Pilar 3: el escudo tiene doble función. El reflejo con escudo espejo llega en M5.

Cono: `block_angle_deg` (60) en player.gd, contra el +Z del modelo. Bloqueado: OneShot `BlockHit` (Melee_Block_Hit) en el AnimationTree, retroceso con move_and_collide (`block_pushback`) y chispas CPUParticles3D creadas en código. Sin sonido: no hay assets de audio todavía (1.7). El cono se dibuja en el piso cuando el overlay (tecla 1) está visible, celeste si está bloqueando. Aturdir es dato del ataque: `AttackData.stun_time` → `DamageInfo.stun_time` → `stunned` en el blackboard del esqueleto; shield_thrust.tres aturde 1,2 s.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 5.1 Proyectiles; 5.6 Escudo espejo y haz de luz

**Relacionadas:** 0.9 Refactor del player

### 1.3 Esquiva (roll) con i-frames · Hecho

- [x] Estado `Dodging` con las animaciones `Dodge_*`
  `Dodge_Forward`, `Dodge_Backward`, `Dodge_Left`, `Dodge_Right`. Sin objetivo fijado siempre `Dodge_Forward` en la dirección del stick; con lock-on, la que corresponde a la dirección relativa.
- [x] I-frames en una ventana del roll
  Ventana normalizada (como `AttackData`): durante ese tramo `Hurtbox.monitorable = false` o `Health` invulnerable. Exportar los valores para ajustarlos.
- [x] Buffer de input para `dodge` y `attack`
  ≈0.15 s: si se aprieta durante el final de otra acción, se ejecuta al terminar. Un solo `InputBuffer` reutilizable.
- [x] Cancelar ataques y guardia al rodar
  Al entrar: `attack_runner.stop()` y `set_guard(false)`. Decidir jugando desde qué momento del ataque se puede cancelar.

**Prueba:** Rodar a través de un ataque del esqueleto durante la ventana de i-frames: no hace daño. Apretar `dodge` al final de un ataque: el roll sale igual (buffer).

**Notas:** `dodge` está en RB, al lado de la guardia (ver [[gdd#input]]).

Skills: `disciplines:input-systems`, `godot:godot-animation`.

Dodging: duración 0,45 s a 8 m/s; i-frames del 10 % al 75 % del roll (`Health.make_invulnerable`). Animación: OneShot `Dodge` + Transition `DodgeDir` (Forward/Backward/Left/Right) en el AnimationTree; sin objetivo siempre Forward mirando hacia donde rueda. InputBuffer (0,15 s) para `attack` y `dodge`: solo consume la acción si `dispatch` la usó. Rodar cancela el ataque (`attack_cancel_from` en state_machine.gd, hoy 0 = siempre) y la guardia. Pendiente de jugar: el sentido de Left/Right con lock-on y los valores.

**Referencias:** `gdd.md#combate`, `gdd.md#input`

**Relacionadas:** 0.9 Refactor del player

### 1.4 IA del esqueleto con `BTAttack` · Hecho

- [x] Crear `ai/tasks/bt_attack.gd`
  Una sola tarea de ataque para todos los BT: toma un `AttackData` y maneja el `AttackRunner`. Código en [[gdd#ventanas-ataque]].
- [x] Navegación en el nivel de prueba
  `NavigationRegion3D` con navmesh horneado en `levels/test.tscn` y `NavigationAgent3D` en el esqueleto. Tarea `BTMoveToTarget` en `ai/tasks/`.
- [x] Rehacer `enemy_bt.tres`
  Selector: muerto → aturdido/golpeado → atacar si está en rango → perseguir si ve al player → idle/patrulla. Datos de rango y visión en la `EntityConfig`.
- [x] Telegrafiar el ataque
  Pausa corta + pose de preparación antes del golpe, para que el jugador pueda bloquear o rodar. Ajustar `active_from` del `AttackData` en vivo.
- [x] Consumir `stunned` e `is_hit` del blackboard
  Golpeado: interrumpe el ataque (`_exit` apaga la hitbox) y reproduce `Hit_*`. Aturdido (golpe de escudo, 1.2): queda quieto un tiempo.
- [x] Muerte del enemigo
  `Health.died` → animación `Skeletons_Death`, sale del grupo `targetable` (libera el lock-on), desactiva colisiones y se borra o queda el cuerpo. Hook para drops (3.7).

**Prueba:** Con *Visible Collision Shapes*: el esqueleto ve al player, lo persigue esquivando obstáculos, telegrafía y pega; si recibe un golpe en medio del ataque, la hitbox se apaga. Muere y deja de poder fijarse.

**Notas:** El esqueleto es el enemigo que enseña a bloquear. Usar las tareas de LimboAI que ya vienen (`BTPlayAnimation`, `BTCheckVar`, `BTWait`) y agregar solo las que falten en `ai/tasks/`.

Skills: `disciplines:ai-behavior-trees-utility-ai`, `disciplines:game-ai`, `godot:godot-physics`.

Tareas propias en ai/tasks/: BTFindPlayer (rango de visión + línea de visión, con histéresis), BTInAttackRange, BTMoveToTarget (NavigationAgent3D) y BTAttack (aviso: congela la pose en windup_pose durante windup_time; después arranca el AttackRunner con el tiempo ya transcurrido). move_speed, vision_range y attack_range van en EntityConfig. El esqueleto separa desired_velocity (IA) del empujón. enemy_bt.tres se regenera con un script; ramas: Muerto, Golpeado, Aturdido (consume stunned, lo setea 1.2), Atacar, Perseguir, Quieto. Muerte: Death_A (no Skeletons_Death), sale de targetable, la hurtbox deja de ser detectable y emite defeated (hook para drops de 3.7). La navmesh del nivel de prueba es solo el piso: las cajas son RigidBody y no son obstáculos. Ajustar windup_time / active_from jugando.

**Referencias:** `gdd.md#combate`, `gdd.md#ventanas-ataque`

**Bloquea a:** 5.2 Torreta / ojo menor; 8.2 Esqueleto con escudo

**Bloqueada por:** 0.8 Enemigo sobre componentes

**Relacionadas:** 3.7 Recolectables y tabla de drops

### 1.5 Muerte y reaparición del player · Hecho

- [x] Estado `Dead`
  Animación `Death_A`, input bloqueado, los enemigos dejan de atacar (grupo `player_dead` o señal).
- [x] Puntos de reaparición
  `SpawnPoint` (Marker3D con `id: StringName`) en el nivel. `GameState.spawn_point` dice cuál usar; al tocar uno nuevo (checkpoint) se actualiza.
- [x] Reaparecer con la vida llena
  Recargar la escena actual y posicionar al player en el spawn. Sin pantalla de game over (llega en M10): un fundido a negro alcanza.
- [x] Log en el canal `combat`
  Quién mató al player y con cuánto daño, para balancear.

**Prueba:** Dejarse matar: animación de muerte, fundido y reaparición en el spawn con la vida llena; los enemigos vuelven a su posición inicial.

**Notas:** En mazmorra se reaparece en la entrada de la sala (6.1); acá alcanza con el spawn del nivel.

Estado Dead (anystate, evento `die`): apaga el AnimationTree y deja Death_A; espera `delay` (1,8 s) y llama `SaveManager.respawn()`, que hace el fundido (autoload `Fader`), recarga la escena y pone al player en el SpawnPoint de `GameState.spawn_point` (si no hay, el primero). La reaparición vive en SaveManager porque el player se destruye al recargar. SpawnPoint (src/world/spawn_point.gd): `id`, y si `checkpoint` está activo, al tocarlo actualiza `GameState.spawn_point`. En test.tscn hay uno, SpawnStart (id start). BTFindPlayer ignora al player muerto. Log en `combat`: quién lo mató y con cuánto daño.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 10.3 Game over

**Relacionadas:** 0.5 GameState

### 1.6 HUD de corazones · Hecho

- [x] Crear `src/ui/hud/hud.tscn`
  `CanvasLayer` con un `Control` anclado arriba a la izquierda y margen de zona segura. Instanciado por el nivel o por un autoload de UI.
- [x] Corazones con cuartos
  Un `TextureRect` por corazón con 5 estados (0..4 cuartos). Placeholder dibujado a mano o con formas; el arte final va en 10.7.
- [x] Actualizar por señal, no por polling
  Escuchar `Health.changed` del player (y `GameState` para `max_health`). Ver los mockups en el artifact "Epiphany UI Mockups".
- [x] Animación al perder y ganar vida
  Tween de escala o sacudida en el corazón que cambió.

**Prueba:** Recibir golpes de ¼ y de 1 corazón: el HUD muestra los cuartos correctos. Cambiar `max_health` desde el Save Inspector: aparecen más corazones. Probar en 1280×720 y 2560×1080.

**Notas:** Primera pieza de UI del juego: dejar el `hud.tscn` preparado para sumar slots de ítems (3.5), llaves (6.3) y barra del jefe (9.2).

Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`.

src/ui/hud/hud.tscn (CanvasLayer 10 + MarginContainer de zona segura 32/28 + HBox Hearts), instanciado por test.tscn. HeartIcon dibuja el corazón vacío y recorta el lleno por cuartos (SVG en assets/ui/, colores del mockup). Escucha Health.changed; Health.reset() avisa al cargar/reaparecer. El corazón que cambia hace un pulso (pulse_scale, pulse_time). Capturas revisadas en 1280×720 y 2560×1080. Ojo: el toggle de debug TopCamera de test.tscn queda encima de los corazones.

**Referencias:** `gdd.md#ui`, `gdd.md#combate`

**Bloquea a:** 3.5 Slots X/Y en el HUD

### 1.7 Feel del combate · Hecho

- [x] Hit-stop al conectar un golpe
  50–80 ms. Mejor congelar solo a los dos involucrados (`process_mode` o velocidad del AnimationTree) que tocar `Engine.time_scale`.
- [x] Sacudida de cámara en `TopDownCamera`
  Modelo de trauma (decae con el tiempo, ruido). Más fuerte al recibir que al dar.
- [x] Flash blanco en el golpeado
  Uniform en un shader de overlay (`next_pass`), encendido unos frames.
- [x] Chispas al bloquear y polvo al rodar
  `GPUParticles3D` cortos, reutilizables.
- [x] SFX placeholder de golpe, bloqueo y roll
  Con variación de pitch. Bus `SFX` (se ordena en 10.5).

**Prueba:** Grabar un clip peleando contra el esqueleto y compararlo con uno antes de la tarea: cada golpe dado, recibido y bloqueado tiene respuesta visual y sonora.

**Notas:** Recién acá el combate tiene que "sentirse". Exportar todos los valores para tunearlos desde el inspector.

Skills: `disciplines:game-feel`, `disciplines:camera-systems`, `godot:godot-shaders`.

Todo pasa por el autoload Feel (src/feel/feel.gd) y los valores están en data/feel.tres (FeelSettings), con interruptores de sacudida y flash para accesibilidad. Hit-stop: desactiva el proceso del atacante y del golpeado (no toca Engine.time_scale). Sacudida: trauma² en TopDownCamera sobre h_offset/v_offset. Flash: shader aditivo como material_overlay (HitFlash, en player y esqueleto). Partículas: sparks (bloqueo) y dust (roll) con CPUParticles3D. Sonidos sintetizados en código (hit, hurt, block, roll) en el bus SFX creado en runtime; el bus definitivo va en 10.5. En headless el renderer dummy tira 'Parameter material is null' por el overlay: es ruido, en ventana no aparece. Falta la prueba subjetiva: jugar y ajustar.

**Referencias:** `gdd.md#combate`

## M2 — Targeting + Aim  (3/4)

Cambio de objetivo moviendo el stick derecho de golpe (el mismo `look_*` que apunta, leído con umbral 0.7; ver [[gdd#input]]) y apuntado con el stick derecho.

**Hecho cuando:**
- Elegir a quién fijar y apuntar libremente.

### 2.1 Cambio de objetivo con el stick derecho · Hecho

- [x] Implementar `Targeting.cycle()`
  Lee `look_*` con umbral 0.7; un salto por movimiento del stick. Elige el candidato más alineado en espacio de pantalla. Código en [[gdd#player]].
- [x] Candidatos válidos
  En pantalla, en rango y con línea de visión (raycast contra el mundo, sin enemigos). Reutilizar el filtro en el lock-on inicial.
- [x] Decidir wrap o nada jugando
  Si no hay candidato en la dirección pedida. Anotar la decisión en [[gdd#movimiento-combate]].
- [x] Feedback del salto
  El indicador hace tween hacia el nuevo objetivo y suena un clic.
- [x] Liberar al perder el objetivo
  Si muere o sale de rango: soltar con un margen de ≈0.5 s, o saltar al siguiente si el lock-on está en modo alternar.

**Prueba:** Tres esqueletos en fila: con uno fijado, mover el stick derecho a izquierda y derecha salta entre ellos en orden. Un esqueleto detrás de una pared no se puede fijar.

**Notas:** Arregla el problema conocido: hoy siempre marca el más cercano.

Skills: `godot:godot-physics`.

Nivel de prueba nuevo: levels/test_targeting.tscn (tres esqueletos en fila y uno detrás de una pared). El wrap queda exportado y apagado (`wrap_around`); la decisión final es jugando, anotada en el GDD. El indicador ya se desliza al objetivo nuevo (lerp de TargetIndicator) y suena el clic sintetizado de Feel. Tests en tests/test_targeting.gd.

**Referencias:** `gdd.md#movimiento-combate`, `gdd.md#player`

**Bloqueada por:** 0.9 Refactor del player

### 2.2 Componente `Aim` · Hecho

- [x] Crear `player/components/aim.gd`
  Fuentes FACING / STICK / MOUSE; con objetivo fijado gana el objetivo. Código en [[gdd#player]].
- [x] Mouse: rayo cámara → plano del suelo
  `Plane.intersects_ray` a la altura del player + 1.
- [x] Retícula de apuntado
  Decal o mesh plano en el suelo, visible solo mientras se usa un ítem a distancia (y siempre en debug).
- [x] Girar el modelo hacia `Aim` al usar un ítem
  Strafe: el player apunta hacia un lado y camina hacia otro.

**Prueba:** Con el overlay activo, `DebugOverlay.watch` de la dirección y la fuente: el stick derecho, el mouse y el lock-on cambian la fuente y la flecha de debug apunta bien en los tres casos.

**Notas:** Lo consumen arco, bombas lanzadas y cualquier ítem a distancia (M5) a través de `ItemUseContext.direction`.

Aim (player/components/aim.gd) sigue al GDD: objetivo fijado > última fuente usada (stick pasada la zona muerta, o mouse: rayo al plano a la altura del player + 1) > hacia donde mira el modelo. `aiming` lo prenderán los ítems a distancia: gira el modelo hacia la dirección (slerp, `turn_speed`) y Moving deja de girarlo hacia donde camina, así hay strafe. Retícula: anillo en el suelo (aiming o debug); en debug también una flecha y watches aim/source y aim/direction. mouse_on_ground() acepta un punto de pantalla para los tests.

**Referencias:** `gdd.md#player`, `gdd.md#movimiento-combate`

**Bloquea a:** 3.4 Usar los ítems asignados

**Relacionadas:** 0.9 Refactor del player

### 2.3 Controles de teclado y mouse · Hecho

- [x] Definir el mapa de teclado y mouse
  Ideas del GDD: guardia en click derecho, ítems en `Q`/`R`, `Tab` para el inventario, rueda para cambiar de objetivo. Actualizar la tabla de [[gdd#input]].
- [x] Agregar los eventos al `InputMap`
  En `project.godot`, junto a los de gamepad. Las teclas de debug (`1`/`2`/`3`) no chocan.
- [x] Cambio de objetivo con la rueda
  La rueda llama `Targeting.cycle()` con izquierda/derecha de pantalla.
- [x] Detectar el dispositivo activo
  Señal `input_device_changed(device)` en un autoload chico; el HUD la usa para mostrar el ícono del botón correcto (4.1).

**Prueba:** Jugar el nivel de prueba sin gamepad: moverse, atacar, bloquear, rodar, fijar, cambiar de objetivo y apuntar con el mouse.

**Notas:** Pilar 5: gamepad y teclado/mouse son ciudadanos de primera. El remapeo es post-MVP.

Skills: `disciplines:input-systems`.

Mapa elegido: WASD, click izquierdo ataca, click derecho guardia, Shift izquierdo fija, rueda cambia de objetivo (acciones nuevas target_prev/target_next), Espacio rueda, E interactúa, Q/R ítems, Tab o Esc pausa, M mapa, Q/E pestañas. Teclas por posición física. Se cargó con un script headless sobre ProjectSettings (device -1, como el editor). Se corrigieron las teclas de debug: 3 guarda, 2 carga (como dice el GDD). Autoload InputDevice con input_device_changed (umbrales para ignorar drift de stick y temblor de mouse). Falta la prueba jugando sin gamepad.

**Referencias:** `gdd.md#input`, `gdd.md#pilares`

### 2.4 Encuadre de cámara con lock-on y apuntado · Pendiente

- [ ] Revisar el punto medio con lock-on
  Ya existe en `TopDownCamera`; limitar cuánto se aleja del player para que no salga de pantalla.
- [ ] Look-ahead hacia la dirección de `Aim`
  Desplazar el foco unos metros mientras se apunta un ítem a distancia, con suavizado.
- [ ] Exportar los valores de suavizado
  Para ajustarlos jugando; dejar un watch en el overlay.

**Prueba:** Fijar un enemigo lejano: ambos quedan en pantalla. Apuntar con el arco (o con el modo debug de la retícula): la cámara se adelanta y vuelve suave al soltar.

**Notas:** La cámara de salas (clamp y transición) es M6.

Skills: `disciplines:camera-systems`.

**Referencias:** `gdd.md#camara`

## M3 — Inventario + UI  (0/8)

Pantallas Equipo e Ítems, asignar a X/Y, slots en el HUD, cofres, item get, recolectables.

**Hecho cuando:**
- Encontrar, equipar y usar un ítem.

### 3.1 Menú de pausa y pila de pantallas · Pendiente

- [ ] Crear `src/ui/menus/menu_stack.gd`
  Pila de pantallas: `push`/`pop`, la de arriba tiene el foco. Pausa el árbol con `get_tree().paused`; la UI con `process_mode = ALWAYS`.
- [ ] Abrir con `pause`, cerrar con `pause` o `ui_cancel`
  Restaurar el foco al volver de una sub-pantalla.
- [ ] Pestañas con `ui_tab_left` / `ui_tab_right`
  Equipo, Ítems y (más adelante) Mapa. Ver los mockups del artifact "Epiphany UI Mockups".
- [ ] Theme base del juego
  Un `Theme` en `src/ui/theme.tres` con fuente, márgenes y estilo de foco visible para gamepad.

**Prueba:** Abrir y cerrar la pausa en medio de un combate: los enemigos y las animaciones se congelan y siguen igual al cerrar. Navegar las pestañas solo con gamepad y solo con teclado.

**Notas:** Base de todas las pantallas: inventario, mapa (6.6), opciones y título (M10).

Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`.

**Referencias:** `gdd.md#ui`

**Bloquea a:** 3.2 Pantalla Equipo; 3.3 Pantalla Ítems y asignación a X/Y; 4.2 Caja de texto; 6.6 Mapa, brújula y pantalla de mapa; 10.1 Pantalla de título

### 3.2 Pantalla Equipo · Pendiente

- [ ] Ranuras de espada, escudo y armadura
  Una fila por categoría; las ranuras sin ítem se muestran bloqueadas.
- [ ] Equipar con `GameState.equip()`
  El player cambia el modelo al instante por `equipment_changed` (de 0.9).
- [ ] Stats del equipo
  Daño de la espada, reducción de la armadura, si el escudo refleja.
- [ ] Preview del modelo
  `SubViewport` con una copia del modelo del player girando, con el equipo actual.

**Prueba:** Desde el escenario `full_inventory`: cambiar de escudo y armadura en la pantalla, cerrar y ver el cambio en el player; guardar y cargar conserva el equipo.

**Notas:** La cota reforzada (7.7) es el ítem que justifica esta pantalla en el MVP.

**Referencias:** `gdd.md#ui`, `gdd.md#items-mvp`

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

### 3.3 Pantalla Ítems y asignación a X/Y · Pendiente

- [ ] Grilla de ítems secundarios
  Ítems de categoría `USABLE`/`UPGRADE` del `Inventory`, con ícono, nombre, descripción y munición.
- [ ] Asignar a X o Y
  Con el ítem seleccionado, apretar X o Y lo asigna a ese botón (`GameState.item_buttons`). Si ya estaba en el otro, se intercambian.
- [ ] Actualizar por `Inventory.changed`
  Sin reconstruir la grilla cada frame.

**Prueba:** Asignar arco a X y bombas a Y, cerrar: el HUD muestra los dos. Guardar y cargar: siguen asignados.

**Referencias:** `gdd.md#ui`, `gdd.md#items-mvp`

**Bloquea a:** 3.4 Usar los ítems asignados

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

**Relacionadas:** 3.5 Slots X/Y en el HUD

### 3.4 Usar los ítems asignados · Pendiente

- [ ] Estado `UsingItem` en el `LimboHSM`
  `item_1`/`item_2` → busca el ítem en `GameState.item_buttons`, chequea `behavior.can_use()` y reproduce `behavior.get_animation()`.
- [ ] Armar el `ItemUseContext`
  `origin` desde la mano (o un `Muzzle`), `direction` desde `Aim`, `inventory` de `GameState`. Ver [[gdd#items-datos]].
- [ ] Llamar `behavior.use()` en el momento justo
  Con un tiempo normalizado del ítem (como `AttackData`), no con pistas de método en la animación.
- [ ] Feedback de "no se puede"
  Sin munición: sonido y sacudida del slot en el HUD.

**Prueba:** Con una poción asignada a X y el player herido: apretar X la toma y cura. Con la vida llena, no la gasta y suena el "no se puede".

**Notas:** Con un ítem de prueba (por ejemplo, una poción) alcanza para cerrar la tarea; los behaviors reales son M5.

**Referencias:** `gdd.md#items-datos`, `gdd.md#player`

**Bloquea a:** 5.3 Arco y flechas; 5.4 Bombas; 5.7 Poción y botella

**Bloqueada por:** 2.2 Componente `Aim`; 3.3 Pantalla Ítems y asignación a X/Y

### 3.5 Slots X/Y en el HUD · Pendiente

- [ ] Dos slots con ícono y munición
  En `hud.tscn`, abajo a la derecha (ver mockups). Vacío si no hay ítem asignado.
- [ ] Escuchar `Inventory.changed` y el cambio de asignación
  Señal nueva en `GameState` (`item_buttons_changed`).
- [ ] Ícono del botón según el dispositivo
  X/Y en gamepad, `Q`/`R` en teclado (señal de 2.3).

**Prueba:** Disparar flechas: la munición baja en el slot. Reasignar desde la pantalla Ítems: el slot cambia sin reabrir el HUD.

**Referencias:** `gdd.md#ui`

**Bloqueada por:** 1.6 HUD de corazones

**Relacionadas:** 3.3 Pantalla Ítems y asignación a X/Y

### 3.6 Cofres e item get · Pendiente

- [ ] Crear `Interactable` e `InteractionDetector` mínimos
  `src/components/interactable.gd` y un `Area3D` en el player que elige el más cercano de frente al apretar `interact`. El prompt en pantalla es 4.1.
- [ ] Crear `src/world/chest.gd` y `chest.tscn`
  Chico y grande; se abre una sola vez gracias a su `flag`. Código en [[gdd#mundo]].
- [ ] `GameState.give()` como entrada única
  Enruta llaves, mapa, brújula, contenedores y el resto al inventario. Ver [[gdd#estado-flags]].
- [ ] Estado `ItemGet`
  Animación `PickUp`/`Use_Item` con el ítem en alto, nombre y descripción en una caja simple; el mundo en pausa hasta confirmar. La caja de texto completa llega en 4.2.
- [ ] Primer equipado automático
  Si el ítem es equipo y la ranura está vacía, se equipa. Si es usable y hay un botón libre, se asigna.

**Prueba:** Abrir un cofre con bombas: animación, texto y bombas en el inventario. Salir y volver a la escena (o guardar y cargar): el cofre sigue abierto y no da bombas de nuevo.

**Referencias:** `gdd.md#mundo`, `gdd.md#estado-flags`

**Bloquea a:** 4.1 Prompt de acción contextual; 6.3 Llaves de mazmorra y HUD

**Bloqueada por:** 0.5 GameState

### 3.7 Recolectables y tabla de drops · Pendiente

- [ ] Escena `Pickup`
  `Area3D` con ítem y cantidad: corazón, flechas ×5, bombas ×3. Rebote al aparecer, un poco de imán hacia el player y parpadeo antes de desaparecer.
- [ ] Tabla de drops ponderada
  Recurso `DropTable` (entradas con peso, incluida "nada") referenciado desde la `EntityConfig`. Las flechas y bombas solo salen si el player ya tiene el ítem.
- [ ] Soltar al morir un enemigo
  Desde el hook de muerte de 1.4. Lo reutilizan vasijas y pasto (4.4).

**Prueba:** Matar 20 esqueletos con el inventario vacío: solo caen corazones. Con bombas en el inventario, también caen bombas.

**Notas:** No hay moneda. Los drops son lo que evita quedarse sin bombas ni flechas en la mazmorra.

Skills: `disciplines:procedural-gen`, `godot:godot-resources`.

**Referencias:** `gdd.md#items-mvp`

**Bloquea a:** 4.4 Vasijas y pasto

**Relacionadas:** 1.4 IA del esqueleto con `BTAttack`

### 3.8 Íconos placeholder de los ítems · Pendiente

- [ ] Definir estilo y tamaño de íconos
  Un solo estilo (por ejemplo, silueta plana con contorno, 128 px, paleta corta) para que se lean juntos en la grilla.
- [ ] Un ícono por cada `ItemData`
  Asignarlos en los `.tres` de `data/items/`.
- [ ] Chequeo en los tests
  Que ningún ítem visible en las pantallas tenga `icon` vacío.

**Prueba:** Abrir las pantallas Equipo e Ítems con `full_inventory`: todos los ítems tienen ícono y se distinguen a tamaño de HUD.

**Notas:** Placeholders coherentes, no arte final: la dirección de arte se decide en 10.7.

Skills: `disciplines:create-game-assets`.

**Referencias:** `gdd.md#items-mvp`

**Relacionadas:** 0.3 Ítems: datos

## M4 — Interacción + mundo  (0/5)

`Interactable` con prompt contextual, tablillas y caja de texto, vasijas y pasto, flags del mundo guardadas.

**Hecho cuando:**
- El mundo recuerda lo que hiciste.

### 4.1 Prompt de acción contextual · Pendiente

- [ ] `InteractionDetector` elige el mejor `Interactable`
  Más cercano y de frente; prioridad exportada para desempatar (cofre > tablilla).
- [ ] HUD: botón + texto del prompt
  "Abrir", "Leer", "Empujar" desde `Interactable.prompt`. Con el ícono del dispositivo activo (2.3).
- [ ] Ocultar el prompt durante combate y menús
  Y mientras el player está en `Hurt`, `Dodging` o `ItemGet`.

**Prueba:** Pararse entre un cofre y una tablilla y girar: el prompt cambia según hacia dónde mira el player.

**Referencias:** `gdd.md#mundo`, `gdd.md#ui`

**Bloquea a:** 6.2 Puertas

**Bloqueada por:** 3.6 Cofres e item get

### 4.2 Caja de texto · Pendiente

- [ ] Crear `src/ui/text_box/`
  Texto que aparece letra por letra, varias páginas, avanzar con `interact`/`attack`, saltar la animación con el mismo botón.
- [ ] Pausar el juego mientras está abierta
  Usando la pila de menús de 3.1.
- [ ] Textos como datos
  Recurso `TextData` (páginas) o claves de traducción con `tr()`, para dejar lista la localización. Sin Ink ni Yarn: no hay diálogos con opciones.
- [ ] Reusar la caja en *item get*
  Reemplazar la caja simple de 3.6.

**Prueba:** Leer un texto de tres páginas con gamepad y con teclado; apretar rápido no se saltea páginas sin querer.

**Notas:** No hay NPCs con diálogo: el texto vive en tablillas e *item get* ([[gdd#historia]]).

Skills: `disciplines:dialogue-systems`, `godot:godot-ui-control`.

**Referencias:** `gdd.md#ui`, `gdd.md#historia`

**Bloquea a:** 4.3 Tablillas

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

### 4.3 Tablillas · Pendiente

- [ ] Escena `Tablet`
  `StaticBody3D` con `Interactable` ("Leer") y un `TextData` exportado.
- [ ] Marcar como leída (opcional)
  Flag opcional para pistas de puzzles; el mapa de la mazmorra puede mostrar las leídas.
- [ ] Escribir 2 tablillas de prueba
  Una de ambientación y una pista de puzzle, para validar el tono. La historia (A o B) sigue abierta: [[gdd#decisiones-abiertas]].

**Prueba:** Leer las dos tablillas del nivel de prueba; guardar y cargar conserva las leídas.

**Referencias:** `gdd.md#historia`

**Bloquea a:** 8.7 Sala 8: antesala

**Bloqueada por:** 4.2 Caja de texto

### 4.4 Vasijas y pasto · Pendiente

- [ ] Vasija rompible
  `Hurtbox` de equipo neutral: se rompe con espada, bomba o al tirarla. Suelta según su `DropTable`.
- [ ] Levantar y lanzar vasijas (opcional)
  Estado `Carrying` del player. Si se complica, queda solo rompible: está en la lista de recortes.
- [ ] Pasto cortable
  Instancias livianas (MultiMesh o escena chica) que se cortan con la espada y a veces sueltan algo.
- [ ] Reaparecen al recargar la escena
  No usan flags.

**Prueba:** Cortar un campo de 50 matas de pasto sin caídas de FPS (*Debugger › Monitors*). Romper vasijas: sueltan corazones y vuelven al recargar.

**Notas:** Último en la lista de recortes del GDD ("pasto/vasijas en overworld"); en la antesala de la mazmorra (sala 8) las vasijas con corazones sí hacen falta.

Skills: `disciplines:performance-optimization`.

**Referencias:** `gdd.md#mazmorra`, `gdd.md#items-mvp`

**Bloquea a:** 8.7 Sala 8: antesala

**Bloqueada por:** 3.7 Recolectables y tabla de drops

### 4.5 Flags del mundo persistentes · Pendiente

- [ ] Componente `PersistentFlag`
  Nodo que, dado un `flag`, lee el estado al `_ready` y lo escribe al cambiar. Lo usan cofres, puertas, muros, interruptores y tablillas.
- [ ] Validar flags en el editor
  Advertencia de configuración si el `flag` no está en `flag_registry.tres` (`_get_configuration_warnings`).
- [ ] Convención de nombres
  `ow_*` overworld, `d1_*` mazmorra. Anotarla en [[gdd#estado-flags]].
- [ ] Escenario de prueba en el Save Inspector
  Con flags puestas a mano: el mundo se carga igual que si se hubieran conseguido jugando.

**Prueba:** Abrir un cofre, romper un muro y leer una tablilla; guardar con `3`, recargar la escena y cargar con `2`: todo sigue igual. Un flag mal escrito en un cofre muestra la advertencia en el editor.

**Referencias:** `gdd.md#estado-flags`, `gdd.md#save-inspector`

**Bloquea a:** 5.5 Muros agrietados

**Bloqueada por:** 0.4 Flags; 0.10 Save Inspector v0

## M5 — Ítems secundarios  (0/8)

Proyectiles y reflejo con el escudo, arco, bombas y muros agrietados, poción.

**Hecho cuando:**
- Cada ítem se usa en al menos un puzzle.

### 5.1 Proyectiles · Pendiente

- [ ] Crear `src/entities/projectile.gd`
  Extiende `Hitbox`: velocidad, vida, `reflect()`. Código en [[gdd#entidades-componentes]].
- [ ] Chocar con el mundo
  `body_entered` contra estáticos: se destruye (o se clava, para flechas) con partículas.
- [ ] Reflejo con el escudo espejo
  En `_on_hurtbox_hit`: si bloquea, el `DamageInfo` es `reflectable` y tiene escudo espejo, devuelve el proyectil hacia `Aim` o el objetivo fijado y cambia de equipo.
- [ ] Pool de proyectiles (si hace falta)
  Solo si el profiler muestra picos al instanciar.

**Prueba:** Un proyectil de prueba disparado contra el player: con escudo de madera se bloquea y desaparece; con escudo espejo vuelve y daña al que lo disparó.

**Notas:** Skills: `godot:godot-physics`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#combate`

**Bloquea a:** 5.2 Torreta / ojo menor; 5.3 Arco y flechas; 9.5 Fase 2: el ojo

**Bloqueada por:** 1.2 Bloqueo direccional y golpe de escudo

### 5.2 Torreta / ojo menor · Pendiente

- [ ] `EntityConfig` y escena de la torreta
  Estática, con `Health`, `Hurtbox` y un `Muzzle`.
- [ ] BT: apuntar, telegrafiar y disparar orbes
  Orbe reflejable (`reflectable = true`). Brillo creciente antes de disparar.
- [ ] Vulnerable a su propio orbe reflejado y a flechas
  Con espada no (o poco), para que enseñe el reflejo.

**Prueba:** Con escudo espejo, reflejar tres orbes destruye la torreta; con escudo de madera solo se bloquean.

**Notas:** Tercer arquetipo de enemigo del MVP ([[gdd#combate]]).

Skills: `disciplines:ai-behavior-trees-utility-ai`.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 8.4 Salas 3–4: galería de trampas y sala agrietada

**Bloqueada por:** 1.4 IA del esqueleto con `BTAttack`; 5.1 Proyectiles

### 5.3 Arco y flechas · Pendiente

- [ ] `ItemData` de arco y flecha con `ProjectileBehavior`
  Munición `arrow`, `max_stack` 30 (el carcaj grande suma con `_capacity_bonus`).
- [ ] Mantener para apuntar, soltar para disparar
  `Ranged_Bow_Draw` → `Ranged_Bow_Aiming_Idle` → `Ranged_Bow_Release`. Mientras se mantiene, el player strafea y se ve la retícula (2.2).
- [ ] Escena de flecha
  Se clava en paredes un rato y desaparece.
- [ ] Interruptor de ojo
  `EyeSwitch`: `Hurtbox` que solo reacciona a flechas (o a proyectiles en general) y emite `activated`. Lo usan la sala 6 y el carcaj (7.7).

**Prueba:** Disparar a un interruptor de ojo a distancia con stick y con mouse: se activa. Sin flechas, el arco no dispara y suena el "no se puede".

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloquea a:** 5.8 Sala de pruebas de ítems; 7.7 Secretos del overworld; 8.6 Salas 6–7: ojos y puzzle combinado; 9.5 Fase 2: el ojo

**Bloqueada por:** 3.4 Usar los ítems asignados; 5.1 Proyectiles

### 5.4 Bombas · Pendiente

- [ ] `PlaceBehavior` y `ItemData` de bombas
  Coloca la bomba delante; si se está apuntando, la lanza en arco hacia `Aim`. Animación `Throw`.
- [ ] Bomba física
  `RigidBody3D` con mecha de ≈2 s y parpadeo que se acelera. Se puede empujar y patear.
- [ ] Explosión
  `Hitbox` de área un instante: daña a todos (incluido el player), impulsa `RigidBody3D` y marca `DamageInfo.element = &"explosive"`.
- [ ] Límite de bombas activas
  Una o dos a la vez.

**Prueba:** Una bomba junto a un esqueleto con escudo y a una caja física: el esqueleto recibe daño y la caja sale volando. El player también se lastima si queda en el radio.

**Notas:** Skills: `disciplines:game-feel`, `godot:godot-physics`.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloquea a:** 5.5 Muros agrietados; 5.8 Sala de pruebas de ítems; 7.4 Cueva de las bombas; 8.4 Salas 3–4: galería de trampas y sala agrietada

**Bloqueada por:** 3.4 Usar los ítems asignados

### 5.5 Muros agrietados · Pendiente

- [ ] Escena `CrackedWall`
  Solo reacciona a daño `explosive`. Al romperse: animación o reemplazo por escombros, polvo y sonido de secreto.
- [ ] Persistencia con flag
  Con `PersistentFlag` (4.5).
- [ ] Pista visual legible
  Textura de grieta distinta del resto de la pared, visible desde la cámara inclinada.

**Prueba:** Un muro agrietado del nivel de prueba: la espada no lo rompe, una bomba sí; sigue roto después de guardar y cargar.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#progresion-gating`

**Bloquea a:** 5.8 Sala de pruebas de ítems; 7.4 Cueva de las bombas

**Bloqueada por:** 4.5 Flags del mundo persistentes; 5.4 Bombas

### 5.6 Escudo espejo y haz de luz · Pendiente

- [ ] `ItemData` y modelo del escudo espejo
  Categoría `SHIELD`, con `reflects`. Material reflectivo placeholder.
- [ ] Haz de luz
  `LightBeam`: rayo (RayCast3D en cadena) con mesh visible desde una fuente fija. Rebota en espejos.
- [ ] El escudo refleja el haz mientras se bloquea
  El haz que toca el escudo sale hacia donde mira el player.
- [ ] Receptor de luz (cristal)
  `LightReceiver`: emite `activated` mientras recibe luz (o una vez, según configuración).

**Prueba:** Bloquear frente a una fuente de luz y girar hasta apuntar a un cristal: el cristal se activa. Con escudo de madera, el haz se corta en el escudo.

**Notas:** Mecánica central: abre el sello del templo (7.6) y los puzzles de reflejo (sala 3 y 7).

Skills: `godot:godot-physics`, `godot:godot-shaders`.

**Referencias:** `gdd.md#pilares`, `gdd.md#items-mvp`

**Bloquea a:** 5.8 Sala de pruebas de ítems; 7.5 Santuario del escudo espejo; 8.6 Salas 6–7: ojos y puzzle combinado

**Bloqueada por:** 1.2 Bloqueo direccional y golpe de escudo

### 5.7 Poción y botella · Pendiente

- [ ] `ItemData` de botella vacía y poción
  `ConsumableBehavior` con `heal` y `leaves` = botella vacía. Código en [[gdd#items-datos]].
- [ ] Animación de tomar
  `Use_Item`; el player queda vulnerable mientras toma (riesgo/recompensa).

**Prueba:** Tomar la poción con 1 corazón: cura y queda la botella vacía en el inventario.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloqueada por:** 3.4 Usar los ítems asignados

### 5.8 Sala de pruebas de ítems · Pendiente

- [ ] Un puzzle por ítem en un nivel sandbox
  `levels/sandbox_items.tscn`: muro bombable, ojo-interruptor lejano, reflejo de luz, orbe de torreta. Grises.
- [ ] Escenario `full_inventory` apuntando al sandbox
  Para entrar directo desde el Save Inspector.

**Prueba:** Resolver los cuatro puzzles del sandbox empezando desde el escenario.

**Notas:** Cierra el hito: "cada ítem se usa en al menos un puzzle". Sirve después como banco de pruebas de regresión.

Skills: `disciplines:level-design`.

**Referencias:** `gdd.md#items-mvp`

**Bloqueada por:** 5.3 Arco y flechas; 5.4 Bombas; 5.5 Muros agrietados; 5.6 Escudo espejo y haz de luz

## M6 — Framework de mazmorra  (0/7)

`Room` con cámara limitada y transición, puertas, llaves, bloques por grilla, interruptores, mapa y brújula con su pantalla.

**Hecho cuando:**
- Tres salas en bloques grises conectadas.

### 6.1 `Room` y cámara por sala · Pendiente

- [ ] Crear `src/world/room.gd`
  `Area3D` con `room_index`, `camera_limits` y `display_name`. Código en [[gdd#mundo]].
- [ ] Cámara clampeada a la sala
  `TopDownCamera.room`: `null` = overworld. Dibujar los límites en el editor (`@tool`) para ajustarlos.
- [ ] Transición al cambiar de sala
  Input bloqueado, el player camina solo por la puerta (estado `Transition`) y la cámara se desliza ≈0.5 s.
- [ ] Marcar sala visitada y nombre en pantalla
  `DungeonState.visit()`; el HUD muestra `display_name` al entrar por primera vez.
- [ ] Reaparecer en la entrada de la sala
  Al morir en mazmorra, en lugar del spawn del nivel ([[gdd#combate]]).

**Prueba:** Dos salas pegadas: al cruzar, la cámara se desliza y queda dentro de los límites de la nueva; la cámara nunca muestra fuera de la sala.

**Notas:** Skills: `disciplines:camera-systems`, `godot:godot-3d-essentials`.

**Referencias:** `gdd.md#mundo`, `gdd.md#camara`

**Bloquea a:** 6.2 Puertas; 6.4 Bloques por grilla; 6.6 Mapa, brújula y pantalla de mapa; 9.2 Arena del jefe y barra de vida

**Bloqueada por:** 0.9 Refactor del player

### 6.2 Puertas · Pendiente

- [ ] Crear `src/world/door.gd`
  Tipos `OPEN`, `LOCKED`, `SHUTTER`, `SWITCH`, `BOSS`. Código en [[gdd#mundo]].
- [ ] Abrir con animación y sonido
  Tween de la hoja de la puerta; la colisión se apaga al terminar.
- [ ] `SHUTTER`: la sala la cierra hasta limpiar
  `Room` cuenta sus enemigos vivos y abre las persianas cuando llega a cero.
- [ ] `SWITCH`: conectada a un interruptor
  Se abre con la señal `activated` (6.5); algunas se vuelven a cerrar si el interruptor se suelta.
- [ ] `LOCKED`/`BOSS` persistentes
  Con su `flag`; usan la llave al interactuar ("Abrir").

**Prueba:** Una sala con persiana: al entrar se cierra, al matar al último esqueleto se abre. Una puerta con llave no se abre sin llave y se queda abierta tras guardar y cargar.

**Referencias:** `gdd.md#mundo`

**Bloquea a:** 6.3 Llaves de mazmorra y HUD; 6.5 Interruptores y cableado; 6.7 Mazmorra de prueba: tres salas grises

**Bloqueada por:** 4.1 Prompt de acción contextual; 6.1 `Room` y cámara por sala

### 6.3 Llaves de mazmorra y HUD · Pendiente

- [ ] `GameState.current_dungeon` lo setea la escena de la mazmorra
  Al salir vuelve a `&""`.
- [ ] Llave chica y llave del jefe como `ItemData`
  Enrutadas por `GameState.give()` al `DungeonState`.
- [ ] HUD: llaves solo en mazmorra
  Contador de llaves chicas e ícono de llave del jefe.

**Prueba:** Juntar dos llaves y abrir una puerta: el contador baja a 1. Fuera de la mazmorra el contador no se ve.

**Referencias:** `gdd.md#estado-flags`, `gdd.md#ui`

**Bloquea a:** 6.7 Mazmorra de prueba: tres salas grises

**Bloqueada por:** 3.6 Cofres e item get; 6.2 Puertas

### 6.4 Bloques por grilla · Pendiente

- [ ] Crear `src/world/push_block.gd`
  `AnimatableBody3D` que se mueve 1 celda con tween tras empujar ≈0.3 s contra él.
- [ ] Chequear la celda destino
  `ShapeCast3D` o consulta al espacio: no entra en paredes, otros bloques ni enemigos.
- [ ] Estado `Pushing` del player y prompt "Empujar"
  Animación de empujar (KayKit `Interact` o la más parecida).
- [ ] Reset al salir de la sala
  Los bloques vuelven a su lugar al re-entrar, salvo que un flag diga que el puzzle está resuelto.

**Prueba:** Empujar un bloque contra una pared no lo mueve; empujarlo sobre un interruptor de piso lo activa. Salir y volver: el bloque está en su posición inicial.

**Notas:** Skills: `godot:godot-physics`.

**Referencias:** `gdd.md#mundo`

**Bloquea a:** 6.7 Mazmorra de prueba: tres salas grises; 7.7 Secretos del overworld

**Bloqueada por:** 6.1 `Room` y cámara por sala

### 6.5 Interruptores y cableado · Pendiente

- [ ] Interruptor de piso
  `FloorSwitch`: lo activa el player, un bloque o un `RigidBody3D`. Modos: mantener / una vez.
- [ ] Interfaz común `activated`/`deactivated`
  La comparten `FloorSwitch`, `EyeSwitch` (5.3) y `LightReceiver` (5.6).
- [ ] Cablear en el editor
  Las puertas y aparatos exportan `Array[NodePath]` de interruptores y una condición (todos / alguno). Sin código por sala.

**Prueba:** Una puerta que necesita dos interruptores: pisar uno no abre; con un bloque sobre el otro, sí.

**Referencias:** `gdd.md#mundo`

**Bloquea a:** 6.7 Mazmorra de prueba: tres salas grises

**Bloqueada por:** 6.2 Puertas

### 6.6 Mapa, brújula y pantalla de mapa · Pendiente

- [ ] Datos del mapa en cada `Room`
  Celda en la grilla del mapa (`map_cell`) y tamaño. El mapa se arma solo leyendo las salas.
- [ ] Pantalla Mapa (pestaña de pausa y acción `map`)
  Salas visitadas; con mapa, todas; con brújula, cofres sin abrir y el jefe. Posición del player.
- [ ] Mapa y brújula como ítems
  Por `GameState.give()` a `DungeonState`.
- [ ] Mapa simple del overworld
  Imagen fija con la posición del player; alcanza para el MVP.

**Prueba:** Escenario `dungeon_no_bow` sin mapa: solo se ven las salas visitadas. Agregar el mapa desde el Save Inspector: aparecen todas.

**Notas:** Skills: `disciplines:game-ui-ux`.

**Referencias:** `gdd.md#ui`, `gdd.md#estado-flags`

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas; 6.1 `Room` y cámara por sala

### 6.7 Mazmorra de prueba: tres salas grises · Pendiente

- [ ] Kit de bloques grises
  `MeshLibrary` con pared, piso, columna, puerta y escalón sobre las texturas de prototipo; armar las salas con `GridMap`.
- [ ] Tres salas conectadas
  Una con bloque e interruptor, una con persiana y esqueletos, una con puerta con llave y cofre.
- [ ] Escenario de inicio en la mazmorra
  `debug/scenarios/dungeon_test.cfg`.

**Prueba:** Recorrer las tres salas desde el escenario sin trabarse: transiciones, persiana, llave y cofre funcionan; guardar en la sala 3 y cargar deja todo igual.

**Notas:** Cierra el hito: "tres salas en bloques grises conectadas". El kit se reutiliza en M7 y M8.

Skills: `godot:godot-3d-essentials`, `disciplines:level-design`.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 7.2 Blockout del overworld; 8.3 Salas 1–2: vestíbulo y hub

**Bloqueada por:** 6.2 Puertas; 6.3 Llaves de mazmorra y HUD; 6.4 Bloques por grilla; 6.5 Interruptores y cableado

## M7 — Overworld  (0/8)

Zona chica con el gating bombas → escudo espejo → sello del templo, y los secretos.

**Hecho cuando:**
- Ida y vuelta entre overworld y mazmorra.

### 7.1 Diseño del layout del overworld · Pendiente

- [ ] Diagrama de 6–8 pantallas
  Inicio, pradera, cueva de bombas, santuario, entrada al templo y los 3 secretos. Camino crítico y atajos.
- [ ] Verificar el gating
  Que no se pueda llegar al santuario sin bombas ni al templo sin escudo espejo ([[gdd#progresion-gating]]).
- [ ] Curva de ritmo
  Dónde hay combate, dónde descanso, dónde se descubre algo.
- [ ] Actualizar el GDD
  Sección [[gdd#overworld]] y cerrar la decisión abierta del layout del overworld.

**Prueba:** El diagrama está en el GDD y responde: dónde está cada ítem, qué lo bloquea y por dónde se vuelve.

**Notas:** Sesión de diseño antes de construir.

Skills: `disciplines:level-design`.

**Referencias:** `gdd.md#overworld`, `gdd.md#progresion-gating`, `gdd.md#decisiones-abiertas`

**Bloquea a:** 7.2 Blockout del overworld

### 7.2 Blockout del overworld · Pendiente

- [ ] Crear `levels/overworld.tscn`
  Terreno y límites en gris con el kit de 6.7; `levels/test.tscn` queda como nivel de pruebas.
- [ ] Puntos de reaparición y nombres de zona
  `SpawnPoint` por zona; el HUD muestra el nombre al entrar a cada una.
- [ ] Navmesh y enemigos de la pradera
  Esqueletos y pasto (si 4.4 entró).
- [ ] Objetos físicos
  Cajas y rocas para empujar y volar con bombas.

**Prueba:** Recorrer el overworld de punta a punta con el inventario completo sin caer fuera del mapa ni trabarse.

**Notas:** Skills: `disciplines:level-design`, `godot:godot-3d-essentials`.

**Referencias:** `gdd.md#overworld`

**Bloquea a:** 7.3 Cambio de escena overworld ↔ mazmorra; 7.4 Cueva de las bombas; 7.7 Secretos del overworld

**Bloqueada por:** 6.7 Mazmorra de prueba: tres salas grises; 7.1 Diseño del layout del overworld

### 7.3 Cambio de escena overworld ↔ mazmorra · Pendiente

- [ ] `Portal`
  Área con escena destino y `spawn_point`. Actualiza `GameState.spawn_scene`, `spawn_point` y `current_dungeon`.
- [ ] Fundido y carga en segundo plano
  `ResourceLoader.load_threaded_request` para que no se congele la imagen.
- [ ] Guardado al cambiar de escena
  Autosave mínimo para no perder progreso (la política completa va en 10.2).

**Prueba:** Entrar y salir del templo varias veces: el player aparece en la puerta correcta, sin congelarse, y el estado de la mazmorra se conserva.

**Notas:** Skills: `godot:godot-resources`, `disciplines:save-systems`.

**Referencias:** `gdd.md#estado-flags`, `gdd.md#guardado`

**Bloquea a:** 7.6 Sello del templo

**Bloqueada por:** 7.2 Blockout del overworld

### 7.4 Cueva de las bombas · Pendiente

- [ ] Interior de la cueva
  Una o dos salas con `Room` (cámara de sala) o zona abierta, según el layout.
- [ ] Cofre con la bolsa de bombas
  Flag `ow_cave_bombs_chest`; tablilla que enseña a usarlas.
- [ ] Primer muro agrietado a la vista
  Justo después, para que el jugador pruebe la bomba enseguida.

**Prueba:** Desde el escenario `start`: conseguir las bombas y romper el primer muro.

**Referencias:** `gdd.md#progresion-gating`, `gdd.md#items-mvp`

**Bloquea a:** 7.5 Santuario del escudo espejo

**Bloqueada por:** 5.4 Bombas; 5.5 Muros agrietados; 7.2 Blockout del overworld

### 7.5 Santuario del escudo espejo · Pendiente

- [ ] Santuario detrás del muro agrietado
  Sala chica con un desafío corto antes del cofre (combate o bloques).
- [ ] Cofre grande con el escudo espejo
  Se equipa solo; *item get* explica que refleja la luz.
- [ ] Haz de luz de práctica
  Un cristal en el santuario para enseñar el reflejo antes del sello.

**Prueba:** Desde el escenario `bombs_only`: llegar al santuario, conseguir el escudo y activar el cristal de práctica.

**Referencias:** `gdd.md#progresion-gating`, `gdd.md#items-mvp`

**Bloquea a:** 7.6 Sello del templo

**Bloqueada por:** 5.6 Escudo espejo y haz de luz; 7.4 Cueva de las bombas

### 7.6 Sello del templo · Pendiente

- [ ] Puzzle del sello
  Fuente de luz + espejos fijos + el escudo: hay que llevar el haz hasta el sello.
- [ ] Abrir la entrada
  Flag `ow_temple_seal_open`; animación y temblor (primer momento de *doom*).
- [ ] Temblores lejanos al acercarse
  Sacudida suave de cámara y sonido grave al entrar en la zona del templo.

**Prueba:** Desde `pre_temple`: abrir el sello y entrar a la mazmorra; al volver, la entrada sigue abierta.

**Referencias:** `gdd.md#progresion-gating`, `gdd.md#historia`

**Bloquea a:** 7.8 Escenarios del overworld

**Bloqueada por:** 7.3 Cambio de escena overworld ↔ mazmorra; 7.5 Santuario del escudo espejo

### 7.7 Secretos del overworld · Pendiente

- [ ] Botella con poción tras un muro agrietado
  Opcional.
- [ ] Cota reforzada en un puzzle de bloques
  Cofre secreto; ejercita la pantalla Equipo.
- [ ] Carcaj grande post-mazmorra
  Ojo-interruptor alto o lejano que solo se alcanza con el arco; suma `_capacity_bonus` de flechas.

**Prueba:** Con `full_inventory`, encontrar los tres secretos; con `start`, el carcaj no se puede conseguir.

**Notas:** Recortables en este orden: carcaj, cota ([[gdd#roadmap]]).

**Referencias:** `gdd.md#overworld`, `gdd.md#items-mvp`

**Bloqueada por:** 5.3 Arco y flechas; 6.4 Bloques por grilla; 7.2 Blockout del overworld

### 7.8 Escenarios del overworld · Pendiente

- [ ] Crear `start`, `bombs_only` y `pre_temple`
  En `debug/scenarios/`, desde el Save Inspector.
- [ ] Recorrido completo de ida y vuelta
  Overworld → templo → overworld.

**Prueba:** Jugar `start` hasta entrar al templo y volver a salir sin usar escenarios intermedios.

**Notas:** Cierra el hito: "ida y vuelta entre overworld y mazmorra".

**Referencias:** `gdd.md#save-inspector`

**Bloqueada por:** 7.6 Sello del templo

## M8 — Contenido de mazmorra  (0/8)

Las 8 salas en bloques grises, el arco a mitad de camino, la llave del jefe.

**Hecho cuando:**
- La mazmorra se recorre entera.

### 8.1 Layout de la mazmorra · Pendiente

- [ ] Diagrama de conexiones de las 8 salas + jefe
  Hub central con 4 salidas ([[gdd#mazmorra]]).
- [ ] Contar llaves y puertas con llave
  Nunca menos llaves accesibles que puertas en cualquier orden de recorrido (evitar softlocks).
- [ ] Ubicar el arco a mitad de camino
  La segunda mitad necesita el arco; el jugador vuelve por salas ya vistas con algo nuevo.
- [ ] Curva de tensión y *doom* por sala
  Columna "Doom" del GDD.
- [ ] Actualizar el GDD
  Cerrar la decisión abierta del layout de la mazmorra.

**Prueba:** El diagrama está en el GDD; recorrerlo en papel en cualquier orden posible no deja al jugador sin llaves.

**Notas:** Skills: `disciplines:level-design`.

**Referencias:** `gdd.md#mazmorra`, `gdd.md#decisiones-abiertas`

**Bloquea a:** 8.3 Salas 1–2: vestíbulo y hub

### 8.2 Esqueleto con escudo · Pendiente

- [ ] `EntityConfig` y escena
  Variante del esqueleto con escudo equipado.
- [ ] Bloquea de frente
  Reutilizar la lógica de cono de 1.2 en el `_on_hurtbox_hit` del enemigo.
- [ ] Vulnerable de flanco, a bombas y al golpe de escudo
  El golpe de escudo le baja la guardia un momento.
- [ ] BT: avanza con guardia y gira hacia el player
  Más lento que el esqueleto común; no puede girar rápido.

**Prueba:** Pegarle de frente no hace daño; rodar a su espalda, una bomba o un golpe de escudo y luego espada, sí.

**Notas:** Skills: `disciplines:ai-behavior-trees-utility-ai`, `disciplines:game-ai`.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 8.5 Sala 5: arena y arco

**Bloqueada por:** 1.4 IA del esqueleto con `BTAttack`

### 8.3 Salas 1–2: vestíbulo y hub · Pendiente

- [ ] Sala 1: bloque por grilla → interruptor → persiana
- [ ] Sala 2: hub con 4 salidas y esqueletos
  Con llave, con persiana, la del jefe (sellada) y una libre.

**Prueba:** Desde la entrada de la mazmorra, llegar al hub y ver las 4 salidas en el estado que dice el GDD.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.4 Salas 3–4: galería de trampas y sala agrietada; 8.5 Sala 5: arena y arco

**Bloqueada por:** 6.7 Mazmorra de prueba: tres salas grises; 8.1 Layout de la mazmorra

### 8.4 Salas 3–4: galería de trampas y sala agrietada · Pendiente

- [ ] Sala 3: reflejar orbes de torretas a un cristal
  Da una llave chica.
- [ ] Sala 4: muro bombable y bombas que empujan bloques físicos
  Da el mapa.

**Prueba:** Resolver las dos salas desde `dungeon_no_bow` y salir con la llave y el mapa.

**Referencias:** `gdd.md#mazmorra`

**Bloqueada por:** 5.2 Torreta / ojo menor; 5.4 Bombas; 8.3 Salas 1–2: vestíbulo y hub

### 8.5 Sala 5: arena y arco · Pendiente

- [ ] Oleadas
  `WaveSpawner`: las oleadas aparecen al entrar; la persiana se abre al terminar la última.
- [ ] Cofre grande con el arco
  Flag `d1_chest_bow`; *item get* con flechas iniciales.

**Prueba:** Ganar las oleadas (incluido el esqueleto con escudo) y conseguir el arco; morir a mitad de oleada y reintentar empieza de cero.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.6 Salas 6–7: ojos y puzzle combinado

**Bloqueada por:** 8.2 Esqueleto con escudo; 8.3 Salas 1–2: vestíbulo y hub

### 8.6 Salas 6–7: ojos y puzzle combinado · Pendiente

- [ ] Sala 6: ojos-interruptor sobre un abismo
  Solo con flechas. Da la brújula y una llave chica. Caer al abismo: daño y vuelta a la entrada.
- [ ] Sala 7: bloques + reflejo + flechas en secuencia
  Da la llave del jefe. Recortable: fusionar con la 6 ([[gdd#roadmap]]).

**Prueba:** Con el arco, resolver las dos salas y salir con brújula y llave del jefe.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.7 Sala 8: antesala

**Bloqueada por:** 5.3 Arco y flechas; 5.6 Escudo espejo y haz de luz; 8.5 Sala 5: arena y arco

### 8.7 Sala 8: antesala · Pendiente

- [ ] Vasijas con corazones, tablilla y puerta del jefe
  La tablilla anticipa al jefe.
- [ ] Checkpoint antes del jefe
  Reaparecer en la antesala al morir contra el jefe.

**Prueba:** Abrir la puerta del jefe con su llave; morir adentro devuelve a la antesala.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.8 Recorrido completo y escenarios de la mazmorra

**Bloqueada por:** 4.3 Tablillas; 4.4 Vasijas y pasto; 8.6 Salas 6–7: ojos y puzzle combinado

### 8.8 Recorrido completo y escenarios de la mazmorra · Pendiente

- [ ] Escenarios `dungeon_no_bow`, `pre_boss` y `boss_key_door_locked`
  El último, inconsistente a propósito, para probar la validación.
- [ ] Recorrido entero sin escenarios intermedios
  Anotar tiempos y dónde se traba el jugador.
- [ ] Buscar softlocks
  Quedarse sin bombas o flechas (¿hay drops?), bloques trabados, puertas que se cierran con el player del lado equivocado.

**Prueba:** Jugar de la entrada a la puerta del jefe con un solo guardado al principio.

**Notas:** Cierra el hito: "la mazmorra se recorre entera".

**Referencias:** `gdd.md#mazmorra`, `gdd.md#save-inspector`

**Bloquea a:** 10.6 Ambientación del doom; 10.8 Pasada de rendimiento

**Bloqueada por:** 8.7 Sala 8: antesala

## M9 — Jefe  (0/7)

Importar el rig del ojo con manos y armar las fases 1 y 2 con LimboAI.

**Hecho cuando:**
- Se puede terminar el juego.

### 9.1 Importar el rig del jefe · Pendiente

- [ ] Traer el rig del ojo con manos al repo
  En `assets/boss/`, con su licencia/origen anotado.
- [ ] Verificar compatibilidad con Godot 4.8 y el `AnimationTree`
  Importar las animaciones a una `AnimationLibrary`; revisar escala y ejes respecto de KayKit.
- [ ] Cerrar la decisión abierta del rig
  En [[gdd#decisiones-abiertas]].

**Prueba:** La escena del jefe se abre en el editor y reproduce todas sus animaciones sin errores.

**Notas:** Skills: `godot:godot-animation`, `godot:godot-3d-essentials`.

**Referencias:** `gdd.md#jefe`, `gdd.md#decisiones-abiertas`

**Bloquea a:** 9.2 Arena del jefe y barra de vida; 9.3 Arquitectura del jefe

### 9.2 Arena del jefe y barra de vida · Pendiente

- [ ] Sala del jefe con `Room`
  Límites de cámara que encuadran toda la arena; puerta que se cierra al entrar.
- [ ] Intro corta
  Cámara al ojo, nombre en pantalla, música (placeholder).
- [ ] Barra de vida del jefe en el HUD
  Escucha el `Health` del jefe; aparece en la intro y se va al morir.

**Prueba:** Entrar a la arena: la puerta se cierra, la intro se puede saltar y la barra baja al pegarle.

**Referencias:** `gdd.md#jefe`, `gdd.md#ui`

**Bloquea a:** 9.4 Fase 1: manos

**Bloqueada por:** 6.1 `Room` y cámara por sala; 9.1 Importar el rig del jefe

### 9.3 Arquitectura del jefe · Pendiente

- [ ] Jefe + manos como entidades
  Cada mano con su `Health`, `Hurtbox`, `Hitbox` y `AttackRunner`; el ojo con los suyos.
- [ ] Fases con `LimboHSM`
  Estados `Phase1`, `Phase2` (y `Phase3`); cada uno corre su BT.
- [ ] Blackboard compartido
  Posición del player, manos vivas/aturdidas, fase actual. Elegir el ataque con utilidad (distancia, último ataque) para que no sea predecible.

**Prueba:** Con el overlay: la fase, el estado de cada mano y el ataque elegido se ven en vivo.

**Notas:** Skills: `disciplines:ai-behavior-trees-utility-ai`.

**Referencias:** `gdd.md#jefe`

**Bloquea a:** 9.4 Fase 1: manos

**Bloqueada por:** 9.1 Importar el rig del jefe

### 9.4 Fase 1: manos · Pendiente

- [ ] Golpe al piso telegrafiado
  Sombra en el suelo que se achica antes del impacto; onda de choque.
- [ ] Agarre
  Si atrapa al player, daño por tiempo; se escapa apretando botones o con un golpe de la otra mano.
- [ ] Mano aturdida tras el golpe al piso
  Ventana de espadazos; aturdir las dos pasa a fase 2.

**Prueba:** Se puede ganar la fase solo con bloqueo y roll; los golpes se pueden anticipar mirando la sombra.

**Notas:** Skills: `disciplines:game-feel`.

**Referencias:** `gdd.md#jefe`

**Bloquea a:** 9.5 Fase 2: el ojo

**Bloqueada por:** 9.2 Arena del jefe y barra de vida; 9.3 Arquitectura del jefe

### 9.5 Fase 2: el ojo · Pendiente

- [ ] El ojo se abre
  Transición con temblor; las manos se regeneran.
- [ ] Flecha al ojo → cae aturdido
  Ventana de espadazos.
- [ ] Orbes reflejables
  Alternativa con escudo espejo para aturdirlo.

**Prueba:** Se puede ganar la fase con flechas y también solo con reflejo; las manos siguen presionando.

**Referencias:** `gdd.md#jefe`

**Bloquea a:** 9.6 Muerte del jefe y final

**Bloqueada por:** 5.1 Proyectiles; 5.3 Arco y flechas; 9.4 Fase 1: manos

### 9.6 Muerte del jefe y final · Pendiente

- [ ] Animación de muerte y flag `d1_boss_defeated`
  Las manos caen, la sala se calma.
- [ ] Contenedor de corazón
  Aparece en la arena; `GameState.give()` suma 4 HP al máximo.
- [ ] Final del MVP
  Al tomar el contenedor o salir, pantalla de fin y créditos placeholder.

**Prueba:** Desde `pre_boss`: ganar, tomar el contenedor y llegar a los créditos. Cargar después: el jefe no reaparece.

**Notas:** Cierra el hito: "se puede terminar el juego".

**Referencias:** `gdd.md#jefe`, `gdd.md#items-mvp`

**Bloquea a:** 9.7 Fase 3 (recortable)

**Bloqueada por:** 9.5 Fase 2: el ojo

### 9.7 Fase 3 (recortable) · Pendiente

- [ ] El ojo marca el piso antes de golpes de área
- [ ] Combinar patrones de manos y ojo

**Prueba:** La fase 3 se activa por debajo de cierto umbral de vida y se puede ganar sin recibir daño inevitable.

**Notas:** Primera en la lista de recortes ([[gdd#roadmap]]). Solo si sobra tiempo.

**Referencias:** `gdd.md#jefe`, `gdd.md#roadmap`

**Bloqueada por:** 9.6 Muerte del jefe y final

## M10 — Terminación  (0/10)

Título, selección de partida, game over, opciones, ambientación del doom, audio y build para playtesters (compilar las plantillas de LimboAI).

**Hecho cuando:**
- MVP jugable por otra persona.

### 10.1 Pantalla de título · Pendiente

- [ ] Logo y menú
  Continuar / Nueva partida / Opciones / Salir. Navegable con gamepad y teclado.
- [ ] *Cargar escenario* solo en debug
  Lista de `debug/scenarios/`.
- [ ] Escena principal del proyecto
  El título pasa a ser `run/main_scene`; respetar `--scenario=` y `next_scenario.txt`.

**Prueba:** Arrancar el juego exportado: título, nueva partida, jugar, salir al título y continuar.

**Notas:** Skills: `disciplines:game-ui-ux`.

**Referencias:** `gdd.md#ui`

**Bloquea a:** 10.2 Selección de partida y autosave; 10.3 Game over; 10.4 Opciones

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

### 10.2 Selección de partida y autosave · Pendiente

- [ ] Decidir 1 o 3 ranuras
  Cerrar la decisión en [[gdd#decisiones-abiertas]].
- [ ] Pantalla de ranuras
  Corazones, ubicación y tiempo jugado (sumar `play_time` a `GameState`).
- [ ] Política de autosave
  Al cambiar de escena, al abrir cofres grandes y al entrar a la antesala. Indicador de guardado en pantalla.
- [ ] Borrar partida con confirmación

**Prueba:** Jugar en dos ranuras distintas y verificar que no se pisan; cortar el proceso a mitad de un guardado no rompe la partida.

**Notas:** Skills: `disciplines:save-systems`.

**Referencias:** `gdd.md#guardado`, `gdd.md#ui`

**Bloqueada por:** 10.1 Pantalla de título

### 10.3 Game over · Pendiente

- [ ] Pantalla al morir
  Continuar (desde la entrada de la sala / último checkpoint) o Guardar y salir.
- [ ] Reemplaza el fundido de 1.5

**Prueba:** Morir en overworld, en mazmorra y contra el jefe: cada "Continuar" lleva al lugar correcto.

**Referencias:** `gdd.md#ui`, `gdd.md#combate`

**Bloqueada por:** 1.5 Muerte y reaparición del player; 10.1 Pantalla de título

### 10.4 Opciones · Pendiente

- [ ] Lock-on mantener/alternar, sensibilidad de apuntado, volúmenes
- [ ] Guardar en `user://settings.cfg`
  Separado de la partida; se aplica al arrancar.
- [ ] Accesible desde título y pausa

**Prueba:** Cambiar cada opción, reiniciar el juego: se mantienen.

**Notas:** Skills: `disciplines:game-ui-ux`, `disciplines:input-systems`.

**Referencias:** `gdd.md#ui`

**Bloqueada por:** 10.1 Pantalla de título

### 10.5 Audio · Pendiente

- [ ] Buses Master / Music / SFX / UI / Ambience
  Volúmenes en dB desde Opciones (10.4).
- [ ] Conseguir SFX y música
  Lista de assets a conseguir en `compass/lists/` con licencias.
- [ ] Variación de SFX
  Pitch y volumen aleatorio, varias muestras por evento.
- [ ] Música por capas para el *doom*
  Capas que se suman sala a sala en la mazmorra; ducking durante *item get* y caja de texto.

**Prueba:** Recorrer el overworld y la mazmorra con auriculares: nada satura, la música cambia con el avance y los SFX repetidos no suenan idénticos.

**Notas:** Skills: `disciplines:audio-design`, `godot:godot-audio`.

**Referencias:** `gdd.md#historia`

### 10.6 Ambientación del doom · Pendiente

- [ ] Nivel de *doom* por sala
  Valor 0..1 exportado en `Room` que mueve luz, niebla y partículas.
- [ ] Luz que vira a rojo, polvo, grietas
  `WorldEnvironment` y luces interpoladas; decals de grietas.
- [ ] Temblores y murmullo
  Sacudidas de cámara esporádicas y audio ambiente (10.5).

**Prueba:** Recorrer la mazmorra de la sala 1 a la 8: la progresión de calma a latido se nota sin leer nada.

**Notas:** Pilar 4: el *doom* se siente, no se cronometra.

Skills: `godot:godot-shaders`, `godot:godot-3d-essentials`.

**Referencias:** `gdd.md#historia`, `gdd.md#pilares`, `gdd.md#mazmorra`

**Bloqueada por:** 8.8 Recorrido completo y escenarios de la mazmorra

### 10.7 Dirección de arte y pasada visual · Pendiente

- [ ] Decidir: KayKit + prototipo o dirección propia
  Cerrar la decisión en [[gdd#decisiones-abiertas]].
- [ ] Guía de estilo corta
  Paleta, materiales, tamaño de íconos y UI.
- [ ] Reemplazar placeholders críticos
  HUD, íconos, cofres, puertas, muros agrietados (que se lean como secreto).

**Prueba:** Capturas del overworld, la mazmorra y el HUD se ven como un mismo juego.

**Notas:** Skills: `disciplines:create-game-assets`.

**Referencias:** `gdd.md#decisiones-abiertas`

### 10.8 Pasada de rendimiento · Pendiente

- [ ] Presupuesto de frame
  60 FPS en la máquina más floja de los playtesters.
- [ ] Perfilar las peores escenas
  Arena con oleadas, overworld con pasto, jefe. Profiler y monitores `epiphany/*`.
- [ ] Arreglar lo que se mida
  Pools, MultiMesh, luces con sombra, partículas.

**Prueba:** Las tres escenas se mantienen en el presupuesto en build release.

**Notas:** Skills: `disciplines:performance-optimization`.

**Bloqueada por:** 8.8 Recorrido completo y escenarios de la mazmorra

### 10.9 Build para playtesters · Pendiente

- [ ] Compilar las plantillas de export del LimboAI propio
  Linux y Windows, release y debug.
- [ ] Presets de export
  Excluir `debug/scenarios/*` y `tests/`; `plain_saves` solo en el preset de debug.
- [ ] Cambiar la clave de guardado
  `SaveCodec._PASS` antes del primer release.
- [ ] Build por línea de comandos
  Script `tools/build.sh` con `godot --headless --export-release`.

**Prueba:** Instalar el build en una máquina limpia (Linux y Windows): arranca, guarda en `user://` cifrado y no incluye escenarios ni tests.

**Notas:** Skills: `godot:godot-export`.

**Referencias:** `gdd.md#guardado`

**Bloquea a:** 10.10 Publicar en itch.io y playtest

### 10.10 Publicar en itch.io y playtest · Pendiente

- [ ] Página privada o restringida en itch.io
  Con instrucciones y controles.
- [ ] Subir con `butler push` a canales por plataforma
  `linux`, `windows`; versión desde git.
- [ ] Reporte de bugs
  Cómo encontrar `user://logs/godot.log`; incluir `save_tampered`.
- [ ] Sesión de playtest observada
  Guion de observación; los hallazgos van a una lista en `compass/lists/`.

**Prueba:** Una persona que no vio el juego lo descarga, lo termina (o se traba) y deja feedback registrado.

**Notas:** Cierra el hito y el MVP: "jugable por otra persona".

Skills: `workflows:itch-publish`.

**Bloqueada por:** 10.9 Build para playtesters
