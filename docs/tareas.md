# Tareas — Project Epiphany

> Export de `compass/`, que es la fuente de verdad. No editar: los cambios se hacen en `compass/` o con `scompass`, y este archivo se regenera.
> Generado: 2026-10-10

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

## M2 — Targeting + Aim  (4/4)

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

Cambio después de jugarlo: el stick derecho ya no recorre la fila desde el objetivo actual, sino que apunta (Targeting.point_at): fija al candidato en la dirección del stick desde el player, con histéresis para no parpadear entre dos. La rueda del mouse sigue saltando al vecino (cycle).

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

### 2.4 Encuadre de cámara con lock-on y apuntado · Hecho

- [x] Revisar el punto medio con lock-on
  Ya existe en `TopDownCamera`; limitar cuánto se aleja del player para que no salga de pantalla.
- [x] Look-ahead hacia la dirección de `Aim`
  Desplazar el foco unos metros mientras se apunta un ítem a distancia, con suavizado.
- [x] Exportar los valores de suavizado
  Para ajustarlos jugando; dejar un watch en el overlay.

**Prueba:** Fijar un enemigo lejano: ambos quedan en pantalla. Apuntar con el arco (o con el modo debug de la retícula): la cámara se adelanta y vuelve suave al soltar.

**Notas:** La cámara de salas (clamp y transición) es M6.

Skills: `disciplines:camera-systems`.

Con lock-on el foco va al punto medio (lock_focus_weight) pero no se aleja más de max_lock_offset (4 m) del player. Mientras Aim.aiming, el foco se adelanta aim_look_ahead (3 m) hacia la dirección de Aim con su propio suavizado (look_ahead_speed) y vuelve igual de suave. Watch camera/focus_offset en el overlay. Tests en tests/test_camera.gd (objetivo a 10 m: ambos en cuadro; adelanto entra y sale suave). Para ver el adelanto jugando hace falta un ítem a distancia (M5) o prender Aim.aiming a mano.

**Referencias:** `gdd.md#camara`

## M3 — Inventario + UI  (8/8)

Pantallas Equipo e Ítems, asignar a X/Y, slots en el HUD, cofres, item get, recolectables.

**Hecho cuando:**
- Encontrar, equipar y usar un ítem.

### 3.1 Menú de pausa y pila de pantallas · Hecho

- [x] Crear `src/ui/menus/menu_stack.gd`
  Pila de pantallas: `push`/`pop`, la de arriba tiene el foco. Pausa el árbol con `get_tree().paused`; la UI con `process_mode = ALWAYS`.
- [x] Abrir con `pause`, cerrar con `pause` o `ui_cancel`
  Restaurar el foco al volver de una sub-pantalla.
- [x] Pestañas con `ui_tab_left` / `ui_tab_right`
  Equipo, Ítems y (más adelante) Mapa. Ver los mockups del artifact "Epiphany UI Mockups".
- [x] Theme base del juego
  Un `Theme` en `src/ui/theme.tres` con fuente, márgenes y estilo de foco visible para gamepad.

**Prueba:** Abrir y cerrar la pausa en medio de un combate: los enemigos y las animaciones se congelan y siguen igual al cerrar. Navegar las pestañas solo con gamepad y solo con teclado.

**Notas:** Base de todas las pantallas: inventario, mapa (6.6), opciones y título (M10).

Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`.

MenuStack (autoload, CanvasLayer 50, process ALWAYS): push/pop, pausa el árbol mientras haya pantallas, recuerda y devuelve el foco. pause abre (solo con player vivo); pause o ui_cancel cierran. Menú de pausa (src/ui/menus/pause_menu.tscn): pestañas Equipo/Ítems/Mapa con ui_tab_left/right (dan la vuelta), indicaciones LB/RB o Q/E y ayudas abajo según InputDevice. Las páginas son placeholders hasta 3.2, 3.3 y 6.6; una página puede definir focus_default(). Theme: src/ui/theme.tres (generado), predeterminado del proyecto: Alegreya Sans/Cinzel (assets/fonts, OFL), paneles, botones con foco dorado de 3 px, variaciones Title, TabLabel(Selected), Hint, Caps, KeyHint y Slot. Resolución base 1280×720 como los mockups. Falta la prueba con gamepad y la de foco cuando haya controles en las páginas.

**Referencias:** `gdd.md#ui`

**Bloquea a:** 3.2 Pantalla Equipo; 3.3 Pantalla Ítems y asignación a X/Y; 4.2 Caja de texto; 6.6 Mapa, brújula y pantalla de mapa; 10.1 Pantalla de título

### 3.2 Pantalla Equipo · Hecho

- [x] Ranuras de espada, escudo y armadura
  Una fila por categoría; las ranuras sin ítem se muestran bloqueadas.
- [x] Equipar con `GameState.equip()`
  El player cambia el modelo al instante por `equipment_changed` (de 0.9).
- [x] Stats del equipo
  Daño de la espada, reducción de la armadura, si el escudo refleja.
- [x] Preview del modelo
  `SubViewport` con una copia del modelo del player girando, con el equipo actual.

**Prueba:** Desde el escenario `full_inventory`: cambiar de escudo y armadura en la pantalla, cerrar y ver el cambio en el player; guardar y cargar conserva el equipo.

**Notas:** La cota reforzada (7.7) es el ítem que justifica esta pantalla en el MVP.

Página src/ui/menus/equipment_page.tscn dentro del menú de pausa (reemplaza el placeholder). Columnas como el mockup: preview (SubViewport con una copia de ModelController del player, sin Hitboxes ni AnimationTree, girando), corazones y stats; filas Espada/Escudo/Armadura de 4 ranuras (EquipSlot del theme), con E en lo equipado y candado en lo que no se tiene; detalle del ítem enfocado. Equipar: A/Enter llama GameState.equip(); la pantalla y el player se actualizan por equipment_changed. ItemData tiene reflects (escudo espejo) y los 17 ítems tienen descripción. La ayuda de aceptar la define cada página (accept_label). Guardar y cargar el equipo ya lo cubren los tests de GameState.

**Referencias:** `gdd.md#ui`, `gdd.md#items-mvp`

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

### 3.3 Pantalla Ítems y asignación a X/Y · Hecho

- [x] Grilla de ítems secundarios
  Ítems de categoría `USABLE`/`UPGRADE` del `Inventory`, con ícono, nombre, descripción y munición.
- [x] Asignar a X o Y
  Con el ítem seleccionado, apretar X o Y lo asigna a ese botón (`GameState.item_buttons`). Si ya estaba en el otro, se intercambian.
- [x] Actualizar por `Inventory.changed`
  Sin reconstruir la grilla cada frame.

**Prueba:** Asignar arco a X y bombas a Y, cerrar: el HUD muestra los dos. Guardar y cargar: siguen asignados.

**Notas:** En teclado Q es item_1 y ui_tab_left: en la pantalla Ítems, con un ítem enfocado, Q/R asignan y E cambia de pestaña. La parte del HUD de la prueba la cierra 3.5. ammo pasó al ItemBehavior base (arco → flechas, bolsa → bombas).

**Referencias:** `gdd.md#ui`, `gdd.md#items-mvp`

**Bloquea a:** 3.4 Usar los ítems asignados

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

**Relacionadas:** 3.5 Slots X/Y en el HUD

### 3.4 Usar los ítems asignados · Hecho

- [x] Estado `UsingItem` en el `LimboHSM`
  `item_1`/`item_2` → busca el ítem en `GameState.item_buttons`, chequea `behavior.can_use()` y reproduce `behavior.get_animation()`.
- [x] Armar el `ItemUseContext`
  `origin` desde la mano (o un `Muzzle`), `direction` desde `Aim`, `inventory` de `GameState`. Ver [[gdd#items-datos]].
- [x] Llamar `behavior.use()` en el momento justo
  Con un tiempo normalizado del ítem (como `AttackData`), no con pistas de método en la animación.
- [x] Feedback de "no se puede"
  Sin munición: sonido y sacudida del slot en el HUD.

**Prueba:** Con una poción asignada a X y el player herido: apretar X la toma y cura. Con la vida llena, no la gasta y suena el "no se puede".

**Notas:** Todos los ítems usan General/Use_Item hasta que su behavior pida otra animación (el estado cambia ItemAnim en el AnimationTree). use() sale en behavior.use_at (0.5 por defecto). La poción cura toda la vida (heal = -1) y deja la botella vacía en el mismo botón. Botón vacío o ítem que no se puede usar: sonido 'deny' y sacudida del slot.

**Referencias:** `gdd.md#items-datos`, `gdd.md#player`

**Bloquea a:** 5.3 Arco y flechas; 5.4 Bombas; 5.7 Poción y botella

**Bloqueada por:** 2.2 Componente `Aim`; 3.3 Pantalla Ítems y asignación a X/Y

### 3.5 Slots X/Y en el HUD · Hecho

- [x] Dos slots con ícono y munición
  En `hud.tscn`, abajo a la derecha (ver mockups). Vacío si no hay ítem asignado.
- [x] Escuchar `Inventory.changed` y el cambio de asignación
  Señal nueva en `GameState` (`item_buttons_changed`).
- [x] Ícono del botón según el dispositivo
  X/Y en gamepad, `Q`/`R` en teclado (señal de 2.3).

**Prueba:** Disparar flechas: la munición baja en el slot. Reasignar desde la pantalla Ítems: el slot cambia sin reabrir el HUD.

**Notas:** Los slots van arriba a la derecha, como en los mockups HUD_Overworld/HUD_Dungeon (la tarea decía abajo). La prueba de disparar flechas queda para 5.3; el test baja la munición a mano.

**Referencias:** `gdd.md#ui`

**Bloqueada por:** 1.6 HUD de corazones

**Relacionadas:** 3.3 Pantalla Ítems y asignación a X/Y

### 3.6 Cofres e item get · Hecho

- [x] Crear `Interactable` e `InteractionDetector` mínimos
  `src/components/interactable.gd` y un `Area3D` en el player que elige el más cercano de frente al apretar `interact`. El prompt en pantalla es 4.1.
- [x] Crear `src/world/chest.gd` y `chest.tscn`
  Chico y grande; se abre una sola vez gracias a su `flag`. Código en [[gdd#mundo]].
- [x] `GameState.give()` como entrada única
  Enruta llaves, mapa, brújula, contenedores y el resto al inventario. Ver [[gdd#estado-flags]].
- [x] Estado `ItemGet`
  Animación `PickUp`/`Use_Item` con el ítem en alto, nombre y descripción en una caja simple; el mundo en pausa hasta confirmar. La caja de texto completa llega en 4.2.
- [x] Primer equipado automático
  Si el ítem es equipo y la ranura está vacía, se equipa. Si es usable y hay un botón libre, se asigna.

**Prueba:** Abrir un cofre con bombas: animación, texto y bombas en el inventario. Salir y volver a la escena (o guardar y cargar): el cofre sigue abierto y no da bombas de nuevo.

**Notas:** Item get como el mockup ItemGet: anillos con el ícono sobre el player y caja abajo; pausa con la pose congelada (Use_Item) hasta confirmar. ItemData tiene 'article' para el título. Capa de física 6 = Interactable. Cofre placeholder (cajas); el modelo real llega con el arte. El nivel de prueba tiene un cofre con la bolsa de bombas (flag ow_test_chest).

**Referencias:** `gdd.md#mundo`, `gdd.md#estado-flags`

**Bloquea a:** 4.1 Prompt de acción contextual; 6.3 Llaves de mazmorra y HUD

**Bloqueada por:** 0.5 GameState

### 3.7 Recolectables y tabla de drops · Hecho

- [x] Escena `Pickup`
  `Area3D` con ítem y cantidad: corazón, flechas ×5, bombas ×3. Rebote al aparecer, un poco de imán hacia el player y parpadeo antes de desaparecer.
- [x] Tabla de drops ponderada
  Recurso `DropTable` (entradas con peso, incluida "nada") referenciado desde la `EntityConfig`. Las flechas y bombas solo salen si el player ya tiene el ítem.
- [x] Soltar al morir un enemigo
  Desde el hook de muerte de 1.4. Lo reutilizan vasijas y pasto (4.4).

**Prueba:** Matar 20 esqueletos con el inventario vacío: solo caen corazones. Con bombas en el inventario, también caen bombas.

**Notas:** No hay moneda. Los drops son lo que evita quedarse sin bombas ni flechas en la mazmorra. Tabla del esqueleto (data/drops/skeleton.tres): nada 55, corazón 30, flechas ×5 10 (pide arco), bombas ×3 10 (pide bolsa); pesos provisorios. El recolectable es un Sprite3D con el ícono del ítem (placeholder). DropTable.drop_at() lo reutilizan vasijas y pasto (4.4).

**Referencias:** `gdd.md#items-mvp`

**Bloquea a:** 4.4 Vasijas y pasto

**Relacionadas:** 1.4 IA del esqueleto con `BTAttack`

### 3.8 Íconos placeholder de los ítems · Hecho

- [x] Definir estilo y tamaño de íconos
  Un solo estilo (por ejemplo, silueta plana con contorno, 128 px, paleta corta) para que se lean juntos en la grilla.
- [x] Un ícono por cada `ItemData`
  Asignarlos en los `.tres` de `data/items/`.
- [x] Chequeo en los tests
  Que ningún ítem visible en las pantallas tenga `icon` vacío.

**Prueba:** Abrir las pantallas Equipo e Ítems con `full_inventory`: todos los ítems tienen ícono y se distinguen a tamaño de HUD.

**Notas:** Placeholders coherentes, no arte final: la dirección de arte se decide en 10.7.

Skills: `disciplines:create-game-assets`.

Estilo: silueta plana con contorno oscuro (#1a1410), SVG de 128 px en assets/ui/items/<id>.svg, un color base por ítem tomado de los mockups. Revisados en una hoja de contacto a 96 y 40 px sobre el fondo de la UI; se aclararon el arco y la bomba porque se perdían en el fondo oscuro. Test: test_every_item_has_an_icon.

**Referencias:** `gdd.md#items-mvp`

**Relacionadas:** 0.3 Ítems: datos

## M4 — Interacción + mundo  (6/6)

`Interactable` con prompt contextual, tablillas y caja de texto, vasijas y pasto, flags del mundo guardadas.

**Hecho cuando:**
- El mundo recuerda lo que hiciste.

### 4.1 Prompt de acción contextual · Hecho

- [x] `InteractionDetector` elige el mejor `Interactable`
  Más cercano y de frente; prioridad exportada para desempatar (cofre > tablilla).
- [x] HUD: botón + texto del prompt
  "Abrir", "Leer", "Empujar" desde `Interactable.prompt`. Con el ícono del dispositivo activo (2.3).
- [x] Ocultar el prompt durante combate y menús
  Y mientras el player está en `Hurt`, `Dodging` o `ItemGet`.

**Prueba:** Pararse entre un cofre y una tablilla y girar: el prompt cambia según hacia dónde mira el player.

**Notas:** Pastilla como en HUD_Overworld/HUD_Dungeon, debajo de los slots X/Y. La prioridad se llama prompt_priority (Area3D ya tiene 'priority'); el cofre tiene 1. 'Combate' = lock-on activo: ahí no hay prompt.

**Referencias:** `gdd.md#mundo`, `gdd.md#ui`

**Bloquea a:** 6.2 Puertas

**Bloqueada por:** 3.6 Cofres e item get

### 4.2 Caja de texto · Hecho

- [x] Crear `src/ui/text_box/`
  Texto que aparece letra por letra, varias páginas, avanzar con `interact`/`attack`, saltar la animación con el mismo botón.
- [x] Pausar el juego mientras está abierta
  Usando la pila de menús de 3.1.
- [x] Textos como datos
  Recurso `TextData` (páginas) o claves de traducción con `tr()`, para dejar lista la localización. Sin Ink ni Yarn: no hay diálogos con opciones.
- [x] Reusar la caja en *item get*
  Reemplazar la caja simple de 3.6.

**Prueba:** Leer un texto de tres páginas con gamepad y con teclado; apretar rápido no se saltea páginas sin querer.

**Notas:** No hay NPCs con diálogo: el texto vive en tablillas e item get. TextBox tiene dos estilos de los mockups: STONE (Tablet: piedra, Cinzel centrado, 'A Continuar' abajo) e ITEM (ItemGet: caja oscura con borde dorado y triángulo). TextData.pages pasan por tr(). Avanzan interact/attack/aceptar; tras abrir o cambiar de página se ignora el input 0,25 s.

**Referencias:** `gdd.md#ui`, `gdd.md#historia`

**Bloquea a:** 4.3 Tablillas

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

### 4.3 Tablillas · Hecho

- [x] Escena `Tablet`
  `StaticBody3D` con `Interactable` ("Leer") y un `TextData` exportado.
- [x] Marcar como leída (opcional)
  Flag opcional para pistas de puzzles; el mapa de la mazmorra puede mostrar las leídas.
- [x] Escribir 2 tablillas de prueba
  Una de ambientación y una pista de puzzle, para validar el tono. La historia (A o B) sigue abierta: [[gdd#decisiones-abiertas]].

**Prueba:** Leer las dos tablillas del nivel de prueba; guardar y cargar conserva las leídas.

**Notas:** Tablet con flag opcional (is_read() para que el mapa marque las pistas leídas). Dos de prueba en levels/test.tscn: ambientación (data/texts/test_tablet_lore.tres) y pista de bombas con flag ow_test_tablet_hint. Textos neutrales entre las historias A y B. Modelo placeholder (losa + base).

**Referencias:** `gdd.md#historia`

**Bloquea a:** 8.7 Sala 8: antesala

**Bloqueada por:** 4.2 Caja de texto

### 4.4 Vasijas y pasto · Hecho

- [x] Vasija rompible
  `Hurtbox` de equipo neutral: se rompe con espada, bomba o al tirarla. Suelta según su `DropTable`.
- [ ] Levantar y lanzar vasijas (opcional)
  Estado `Carrying` del player. Si se complica, queda solo rompible: está en la lista de recortes.
- [x] Pasto cortable
  Instancias livianas (MultiMesh o escena chica) que se cortan con la espada y a veces sueltan algo.
- [x] Reaparecen al recargar la escena
  No usan flags.

**Prueba:** Cortar un campo de 50 matas de pasto sin caídas de FPS (*Debugger › Monitors*). Romper vasijas: sueltan corazones y vuelven al recargar.

**Notas:** Último en la lista de recortes del GDD; en la antesala (sala 8) las vasijas con corazones sí hacen falta. Paso 2 (levantar/lanzar, estado Carrying) recortado: las vasijas solo se rompen; se puede retomar más adelante. Breakable (vasija y pasto) con Hurtbox neutral en la capa 5; tablas data/drops/pot.tres y grass.tres (pesos provisorios). Medido en ventana sin vsync (1280×720): 50 matas suman ~0,05 ms y 1 draw call (Godot instancia las mallas iguales); cortando, frame medio 1,13 ms y peor 1% 3 ms. No hace falta MultiMesh.

**Referencias:** `gdd.md#mazmorra`, `gdd.md#items-mvp`

**Bloquea a:** 8.7 Sala 8: antesala

**Bloqueada por:** 3.7 Recolectables y tabla de drops

### 4.5 Flags del mundo persistentes · Hecho

- [x] Componente `PersistentFlag`
  Nodo que, dado un `flag`, lee el estado al `_ready` y lo escribe al cambiar. Lo usan cofres, puertas, muros, interruptores y tablillas.
- [x] Validar flags en el editor
  Advertencia de configuración si el `flag` no está en `flag_registry.tres` (`_get_configuration_warnings`).
- [x] Convención de nombres
  `ow_*` overworld, `d1_*` mazmorra. Anotarla en [[gdd#estado-flags]].
- [x] Escenario de prueba en el Save Inspector
  Con flags puestas a mano: el mundo se carga igual que si se hubieran conseguido jugando.

**Prueba:** Abrir un cofre, romper un muro y leer una tablilla; guardar con `3`, recargar la escena y cargar con `2`: todo sigue igual. Un flag mal escrito en un cofre muestra la advertencia en el editor.

**Notas:** PersistentFlag (@tool) avisa el valor al entrar, al cambiar y al cargar; los objetos que exportan 'flag' (Chest, Tablet) muestran la misma advertencia con PersistentFlag.warnings_for(). Advierte si no está registrado o no sigue ow_*/dN_*. Escenario debug/scenarios/test_flags.cfg (cofre abierto, pista leída, bolsa con 5 bombas en X). Muros: llegan en 5.5 y usan el mismo componente.

**Referencias:** `gdd.md#estado-flags`, `gdd.md#save-inspector`

**Bloquea a:** 5.5 Muros agrietados

**Bloqueada por:** 0.4 Flags; 0.10 Save Inspector v0

### 4.6 Integrar Dialogue Manager · Hecho

**Prioridad:** media

- [x] Instalar Dialogue Manager y verificar compatibilidad
  Plugin de Nathan Hoad en addons/. Probar con Godot 4.8-dev7: que el editor lo cargue sin errores y que los tests headless sigan pasando.
- [x] Usar nuestra TextBox como globo
  La TextBox de 4.2 (estilos STONE e ITEM de los mockups) muestra las líneas que entrega Dialogue Manager: letra por letra, páginas, guarda de input y pausa con la pila de menús.
- [x] Pasar tablillas e item get a archivos .dialogue
  Las dos tablillas de prueba y el texto del item get. El estilo y el rótulo salen de tags o del título del bloque. Reemplaza TextData; los tests de 4.2, 4.3 y 3.6 siguen pasando.
- [x] Condiciones y flags desde el diálogo
  Acceso a GameState desde los .dialogue (leer y poner flags, p. ej. marcar una pista como leída), para que futuros NPCs o textos condicionales no requieran código.
- [x] Traducciones
  Dejar configurada la generación de claves/CSV o PO de Dialogue Manager, así la localización no se rehace después.
- [x] Anotar la decisión en el GDD
  Reemplaza 'sin Ink ni Yarn' de 4.2: se usa Dialogue Manager para tener el sistema andando antes de que haya muchos textos; UI propia, no la del plugin.

**Prueba:** Leer las dos tablillas y abrir el cofre: se ven igual que antes (estilos de los mockups), pero el texto sale de .dialogue. Un texto condicional cambia según un flag. Guardar y cargar conserva las tablillas leídas.

**Notas:** Decisión del 2026-10-08: el GDD no tiene NPCs con diálogo, pero se integra el plugin ya para no adaptar tablillas e item get después. Elegido sobre Dialogic porque solo maneja el contenido y deja la UI propia (mockups), es liviano y hay menos superficie para romperse con Godot 4.8-dev. Instalado Dialogue Manager v4.1.0 (para Godot 4.7) desde la release de GitHub: import, arranque y tests headless OK en 4.8-dev7; falta confirmar que el editor lo cargue sin errores. Textos en data/dialogue/*.dialogue; el personaje de la línea es el rótulo de la tablilla; item_get.dialogue tiene un cue por id de ítem (si falta, usa la descripción). Traducciones: IDs estáticos [ID:…] como claves; el plugin mantiene la lista de plantillas POT.

## M5 — Ítems secundarios  (9/9)

Proyectiles y reflejo con el escudo, arco, bombas y muros agrietados, poción.

**Hecho cuando:**
- Cada ítem se usa en al menos un puzzle.

### 5.1 Proyectiles · Hecho

- [x] Crear `src/entities/projectile.gd`
  Extiende `Hitbox`: velocidad, vida, `reflect()`. Código en [[gdd#entidades-componentes]].
- [x] Chocar con el mundo
  `body_entered` contra estáticos: se destruye (o se clava, para flechas) con partículas.
- [x] Reflejo con el escudo espejo
  En `_on_hurtbox_hit`: si bloquea, el `DamageInfo` es `reflectable` y tiene escudo espejo, devuelve el proyectil hacia `Aim` o el objetivo fijado y cambia de equipo.
- [x] Pool de proyectiles (si hace falta)
  Solo si el profiler muestra picos al instanciar.

**Prueba:** Un proyectil de prueba disparado contra el player: con escudo de madera se bloquea y desaparece; con escudo espejo vuelve y daña al que lo disparó.

**Notas:** Skills: godot:godot-physics, disciplines:physics-tuning. El source del DamageInfo es el proyectil (bloqueo direccional) y shooter guarda quién disparó. Ignora CharacterBody3D en body_entered (el player está en la capa 1). Pool descartado con medición: 30 orbes/s (instanciar, reflejar, destruir) en ventana sin vsync → frame medio 1,3 ms, máximo 2,6–4,8 ms. Escena de prueba: src/entities/projectile.tscn (orbe).

**Referencias:** `gdd.md#entidades-componentes`, `gdd.md#combate`

**Bloquea a:** 5.2 Torreta / ojo menor; 5.3 Arco y flechas; 9.5 Fase 2: el ojo

**Bloqueada por:** 1.2 Bloqueo direccional y golpe de escudo

### 5.2 Torreta / ojo menor · Hecho

- [x] `EntityConfig` y escena de la torreta
  Estática, con `Health`, `Hurtbox` y un `Muzzle`.
- [x] BT: apuntar, telegrafiar y disparar orbes
  Orbe reflejable (`reflectable = true`). Brillo creciente antes de disparar.
- [x] Vulnerable a su propio orbe reflejado y a flechas
  Con espada no (o poco), para que enseñe el reflejo.

**Prueba:** Con escudo espejo, reflejar tres orbes destruye la torreta; con escudo de madera solo se bloquean.

**Notas:** Tercer arquetipo de enemigo del MVP. Turret (StaticBody3D, sin navegación): la cabeza gira hacia el player, carga 0,9 s (iris y luz que crecen) y dispara un orbe reflejable a 9 m/s; 1,4 s de espera entre tiros. 6 de vida: tres orbes reflejados o tres flechas. La espada rebota con chispas. Árbol en src/entities/turret/turret_bt.tres con tareas propias (bt_turn_to_target, bt_charge_shot, bt_fire_orb) y bt_find_player. Modelo placeholder (pilar + ojo). Una de prueba en levels/test.tscn en (8, 0.25, 6), con el camino libre de cajas.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 8.4 Salas 3–4: galería de trampas y sala agrietada

**Bloqueada por:** 1.4 IA del esqueleto con `BTAttack`; 5.1 Proyectiles

### 5.3 Arco y flechas · Hecho

- [x] `ItemData` de arco y flecha con `ProjectileBehavior`
  Munición `arrow`, `max_stack` 30 (el carcaj grande suma con `_capacity_bonus`).
- [x] Mantener para apuntar, soltar para disparar
  Ranged_Bow_Draw → Ranged_Bow_Aiming_Idle → Ranged_Bow_Release (rama filtrada al torso). Sin objetivo fijado el player se planta y el stick izquierdo apunta (OoT); con objetivo fijado la flecha va al objetivo y el stick izquierdo camina en strafe. El stick derecho y el mouse también apuntan. Las flechas ignoran los cuerpos que cuelgan de un personaje (el escudo KayKit trae StaticBody propio).
- [x] Escena de flecha
  Se clava en paredes un rato y desaparece.
- [x] Interruptor de ojo
  `EyeSwitch`: `Hurtbox` que solo reacciona a flechas (o a proyectiles en general) y emite `activated`. Lo usan la sala 6 y el carcaj (7.7).

**Prueba:** Disparar a un interruptor de ojo a distancia con stick y con mouse: se activa. Sin flechas, el arco no dispara y suena el "no se puede".

**Notas:** Mantener X/Y tensa (estado AimingItem): rama BowPhase/BowBlend en el AnimationTree filtrada al torso, así el player strafea a 2,5 m/s con las piernas animadas; Aiming_Idle en loop con timeline propio. Soltar dispara (mín. 0,15 s). Arco KayKit bow_withString en la mano del escudo mientras apunta (Equipment.hold). Carcaj grande: ItemData.capacity_for/capacity_bonus (+20 flechas) se calcula desde el inventario, sin guardar nada extra. EyeSwitch solo reacciona a proyectiles; flag opcional. Uno de prueba en levels/test.tscn. El apuntado con mouse lo cubren los tests de Aim (2.2); los de esta tarea usan el stick y la dirección del modelo.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloquea a:** 5.8 Sala de pruebas de ítems; 7.7 Secretos del overworld; 8.6 Salas 6–7: ojos y puzzle combinado; 9.5 Fase 2: el ojo

**Bloqueada por:** 3.4 Usar los ítems asignados; 5.1 Proyectiles

### 5.4 Bombas · Hecho

- [x] `PlaceBehavior` y `ItemData` de bombas
  Coloca la bomba delante; si se está apuntando, la lanza en arco hacia `Aim`. Animación `Throw`.
- [x] Bomba física
  `RigidBody3D` con mecha de ≈2 s y parpadeo que se acelera. Se puede empujar y patear.
- [x] Explosión
  `Hitbox` de área un instante: daña a todos (incluido el player), impulsa `RigidBody3D` y marca `DamageInfo.element = &"explosive"`.
- [x] Límite de bombas activas
  Una o dos a la vez.

**Prueba:** Una bomba junto a un esqueleto con escudo y a una caja física: el esqueleto recibe daño y la caja sale volando. El player también se lastima si queda en el radio.

**Notas:** Skills: disciplines:game-feel, godot:godot-physics. Apuntando (objetivo fijado, stick derecho o mouse a más de 1,5 m) la bomba se lanza en arco y cae en el punto en 0,7 s; si no, se coloca delante. Animación General/Throw; el player recupera el control al 60 % (ItemBehavior.end_at). Mecha 2 s con parpadeo que se acelera; la espada la patea. Explosión: Hitbox con hits_all (daña a todos, el player incluido), radio 2,2 m, 1 corazón, element explosive (la madera no la frena, 5.9), empuja RigidBody3D, rompe vasijas/pasto y detona otras bombas. Bola de fuego del tamaño del radio. Máximo 2 activas. La bolsa trae 10 bombas y el arco 10 flechas (ItemData.bundled).

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloquea a:** 5.5 Muros agrietados; 5.8 Sala de pruebas de ítems; 7.4 Cueva de las bombas; 8.4 Salas 3–4: galería de trampas y sala agrietada

**Bloqueada por:** 3.4 Usar los ítems asignados

### 5.5 Muros agrietados · Hecho

- [x] Escena `CrackedWall`
  Solo reacciona a daño `explosive`. Al romperse: animación o reemplazo por escombros, polvo y sonido de secreto.
- [x] Persistencia con flag
  Con `PersistentFlag` (4.5).
- [x] Pista visual legible
  Textura de grieta distinta del resto de la pared, visible desde la cámara inclinada.

**Prueba:** Un muro agrietado del nivel de prueba: la espada no lo rompe, una bomba sí; sigue roto después de guardar y cargar.

**Notas:** CrackedWall: StaticBody3D 2,4×2,4 m con Hurtbox neutral que solo reacciona a element explosive; la espada rebota con chispas. Al romperse: pared oculta, escombros, polvo, pedazos y sonido de secreto ('secret'); emite broken. Persistencia con PersistentFlag y advertencia en el editor (flag obligatorio). Pista visual: piedra más clara con grietas oscuras en el frente y el borde superior (placeholder). Uno de prueba en levels/test.tscn en (-10, 0.25, 2) con flag ow_test_cracked_wall.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#progresion-gating`

**Bloquea a:** 5.8 Sala de pruebas de ítems; 7.4 Cueva de las bombas

**Bloqueada por:** 4.5 Flags del mundo persistentes; 5.4 Bombas

### 5.6 Escudo espejo y haz de luz · Hecho

- [x] `ItemData` y modelo del escudo espejo
  Categoría `SHIELD`, con `reflects`. Material reflectivo placeholder.
- [x] Haz de luz
  `LightBeam`: rayo (RayCast3D en cadena) con mesh visible desde una fuente fija. Rebota en espejos.
- [x] El escudo refleja el haz mientras se bloquea
  El haz que toca el escudo sale hacia donde mira el player.
- [x] Receptor de luz (cristal)
  `LightReceiver`: emite `activated` mientras recibe luz (o una vez, según configuración).

**Prueba:** Bloquear frente a una fuente de luz y girar hasta apuntar a un cristal: el cristal se activa. Con escudo de madera, el haz se corta en el escudo.

**Notas:** Mecánica central: abre el sello del templo (7.6) y los puzzles de reflejo (sala 3 y 7). LightBeam: rayos en cadena (capa 1) recalculados cada cuadro de física, dibujados con cilindros emisivos; rebota en LightMirror (grupo light_mirror, reflexión especular) y en el player con escudo espejo (Player.light_hit): bloqueando de frente sale hacia Aim desde el escudo; en la espalda rebota (el espejo refleja siempre, 5.9). Madera o sin cubrirse: el haz se corta. LightReceiver: activated/deactivated; con latch queda encendido y, con flag, entre partidas. Escenas: light_source, light_receiver, light_mirror (placeholders). Puzzle de prueba en levels/test.tscn: fuente en (13, 0.25, -15.5) hacia el oeste y cristal en (6, 0.25, -12).

**Referencias:** `gdd.md#pilares`, `gdd.md#items-mvp`

**Bloquea a:** 5.8 Sala de pruebas de ítems; 7.5 Santuario del escudo espejo; 8.6 Salas 6–7: ojos y puzzle combinado

**Bloqueada por:** 1.2 Bloqueo direccional y golpe de escudo

### 5.7 Poción y botella · Hecho

- [x] `ItemData` de botella vacía y poción
  `ConsumableBehavior` con `heal` y `leaves` = botella vacía. Código en [[gdd#items-datos]].
- [x] Animación de tomar
  `Use_Item`; el player queda vulnerable mientras toma (riesgo/recompensa).

**Prueba:** Tomar la poción con 1 corazón: cura y queda la botella vacía en el inventario.

**Notas:** Casi todo salió en 3.4: potion con ConsumableBehavior (heal = -1, toda la vida; leaves = bottle_empty, que queda en el mismo botón) y la animación General/Use_Item. Riesgo/recompensa: la poción se toma a mitad de la animación (use_at 0,5); un golpe antes pasa a Hurt, corta el trago y no la gasta. Rellenar la botella (la descripción dice que se puede) no tiene tarea: hace falta una fuente o algo que la llene.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloqueada por:** 3.4 Usar los ítems asignados

### 5.8 Sala de pruebas de ítems · Hecho

- [x] Un puzzle por ítem en un nivel sandbox
  `levels/sandbox_items.tscn`: muro bombable, ojo-interruptor lejano, reflejo de luz, orbe de torreta. Grises.
- [x] Escenario `full_inventory` apuntando al sandbox
  Para entrar directo desde el Save Inspector.

**Prueba:** Resolver los cuatro puzzles del sandbox empezando desde el escenario.

**Notas:** Cierra el hito: 'cada ítem se usa en al menos un puzzle'. Sirve después como banco de pruebas de regresión. levels/sandbox_items.tscn (greybox, CSG): cuatro cubículos con una vasija de corazones detrás de algo que se abre — BOMBAS (muro agrietado, flag ow_sb_cracked_wall), ARCO (ojo en un corral bajo: la espada no llega, las flechas pasan por arriba → Gate), LUZ (fuente que cruza el sur; con el escudo espejo se desvía al cristal latch → Gate), ORBE (torreta en un corral; reflejarle los orbes → Gate). Gate nuevo (src/world/gate.gd): reja que se hunde; base para 6.2. levels/sandbox_items.gd expone solved(). full_inventory arranca en el sandbox con el escudo espejo. test_sandbox resuelve los cuatro desde el escenario. Se arregló de paso el dibujo de los tramos del haz (LightBeam escalaba en espacio global).

**Referencias:** `gdd.md#items-mvp`

**Bloqueada por:** 5.3 Arco y flechas; 5.4 Bombas; 5.5 Muros agrietados; 5.6 Escudo espejo y haz de luz

### 5.9 Protección del escudo según el tipo de daño y por la espalda · Hecho

**Prioridad:** media

- [x] Qué frena cada escudo, como dato
  ItemData.protects_against: Array[StringName] con los elementos de DamageInfo.element que el escudo frena ("" = físico: espadas, flechas, orbes). Madera: solo físico; no frena explosiones ("explosive", 5.4) ni fuego ("fire"). Espejo: físico, más reflects. Nada frena explosiones (a confirmar jugando).
- [x] Bloqueo de frente según el elemento
  Si el golpe es de un elemento que el escudo no frena, entra el daño completo aunque se bloquee de frente (con un feedback distinto: el escudo no aguanta).
- [x] El escudo en la espalda protege
  Sin bloquear, los proyectiles que llegan desde atrás (cono de ±45° de la espalda, exportado) se frenan si el escudo frena su elemento. Chispas y sonido de bloqueo, sin animación ni retroceso. Los golpes cuerpo a cuerpo por la espalda no se frenan, para que la guardia de frente siga siendo la defensa principal.
- [x] El escudo espejo refleja siempre
  Cualquier proyectil reflejable que intercepta el espejo vuelve: de frente bloqueando, hacia Aim (como en 5.1); en la espalda, de vuelta por donde vino (hacia quien lo tiró). También refleja el haz de luz de 5.6 cuando lo intercepta.
- [x] Tests
  Madera: flecha por la espalda se frena, explosión/fuego entran aunque se bloquee. Espejo: orbe por la espalda vuelve al que lo tiró; de frente bloqueando vuelve hacia la mira. Golpe de espada por la espalda: daño.

**Prueba:** Con escudo de madera: una flecha por la espalda se frena; una bomba o fuego lastiman aunque se bloquee de frente. Con escudo espejo: un orbe por la espalda vuelve y daña a la torreta que lo disparó.

**Notas:** Idea del 2026-10-08: que el escudo en la espalda proteja, y que cada escudo frene distintos tipos de daño (la madera frena flechas pero no explosiones ni fuego). El espejo refleja siempre que intercepta, porque es un espejo. Usa DamageInfo.element, que ya existe: "explosive" lo pone la bomba (5.4), "light" el haz (5.6), "fire" queda para espadas elementales post-MVP. Relacionada con 5.2 (torreta: primer enemigo que dispara), 5.4 y 5.6. Desde 2026-10-08 el escudo oculto no colisiona (Equipment.show_shield_in_hand).

## M6 — Framework de mazmorra  (7/7)

`Room` con cámara limitada y transición, puertas, llaves, bloques por grilla, interruptores, mapa y brújula con su pantalla.

**Hecho cuando:**
- Tres salas en bloques grises conectadas.

### 6.1 `Room` y cámara por sala · Hecho

- [x] Crear `src/world/room.gd`
  `Area3D` con `room_index`, `camera_limits` y `display_name`. Código en [[gdd#mundo]].
- [x] Cámara clampeada a la sala
  `TopDownCamera.room`: `null` = overworld. Dibujar los límites en el editor (`@tool`) para ajustarlos.
- [x] Transición al cambiar de sala
  Input bloqueado, el player camina solo por la puerta (estado `Transition`) y la cámara se desliza ≈0.5 s.
- [x] Marcar sala visitada y nombre en pantalla
  `DungeonState.visit()`; el HUD muestra `display_name` al entrar por primera vez.
- [x] Reaparecer en la entrada de la sala
  Al morir en mazmorra, en lugar del spawn del nivel ([[gdd#combate]]).

**Prueba:** Dos salas pegadas: al cruzar, la cámara se desliza y queda dentro de los límites de la nueva; la cámara nunca muestra fuera de la sala.

**Notas:** Skills: disciplines:camera-systems, godot:godot-3d-essentials. Room (@tool) dibuja su rectángulo en el editor; tamaño = su CollisionShape3D (caja) o camera_limits a mano. La cámara detecta la sala por el centro del player cada cuadro (body_entered disparaba con la cápsula todavía afuera y fallaba al reaparecer). Vista medida ≈ 14,7 × 31 m (ver GDD §4.1): salas más chicas dejan la cámara centrada. Cruce: estado Transition 0,5 s caminando hacia la sala nueva; la cámara se desliza. Primera visita: DungeonState.visit + nombre en el HUD con el estilo del mockup (HUD_Overworld). Al morir en mazmorra reaparece en GameState.room_entry (donde quedó al terminar de entrar; no se guarda). Nivel de prueba: levels/test_rooms.tscn (sala A chica, sala B grande).

**Referencias:** `gdd.md#mundo`, `gdd.md#camara`

**Bloquea a:** 6.2 Puertas; 6.4 Bloques por grilla; 6.6 Mapa, brújula y pantalla de mapa; 9.2 Arena del jefe y barra de vida

**Bloqueada por:** 0.9 Refactor del player

### 6.2 Puertas · Hecho

- [x] Crear `src/world/door.gd`
  Tipos `OPEN`, `LOCKED`, `SHUTTER`, `SWITCH`, `BOSS`. Código en [[gdd#mundo]].
- [x] Abrir con animación y sonido
  Tween de la hoja de la puerta; la colisión se apaga al terminar.
- [x] `SHUTTER`: la sala la cierra hasta limpiar
  `Room` cuenta sus enemigos vivos y abre las persianas cuando llega a cero.
- [x] `SWITCH`: conectada a un interruptor
  Se abre con la señal `activated` (6.5); algunas se vuelven a cerrar si el interruptor se suelta.
- [x] `LOCKED`/`BOSS` persistentes
  Con su `flag`; usan la llave al interactuar ("Abrir").

**Prueba:** Una sala con persiana: al entrar se cierra, al matar al último esqueleto se abre. Una puerta con llave no se abre sin llave y se queda abierta tras guardar y cargar.

**Notas:** Door (@tool): la hoja se hunde 2,5 m (0,5 s, sonido 'door' y polvo); la colisión se apaga al terminar; al cerrar vuelve enseguida. Colores por tipo y placa dorada en LOCKED/BOSS. LOCKED gasta una llave chica, BOSS pide la del jefe sin gastarla; sin llave: 'no se puede' y texto de data/dialogue/doors.dialogue. Persistencia con PersistentFlag (advertencia si falta). SHUTTER: Room la cierra 0,6 s después de entrar si hay enemigos vivos adentro (grupo enemies, por posición) y la abre al limpiar. SWITCH: se conecta por nombre a 'activated' (y 'deactivated' si stays_open = false), así sirve cualquier nodo. Se arregló PersistentFlag: el aviso inicial diferido usaba el valor viejo y deshacía una carga hecha al entrar a la escena. levels/test_rooms.tscn: persiana A→B (esqueleto en B), puerta con llave B→C (flag d1_test_locked_door), sala C.

**Referencias:** `gdd.md#mundo`

**Bloquea a:** 6.3 Llaves de mazmorra y HUD; 6.5 Interruptores y cableado; 6.7 Mazmorra de prueba: tres salas grises

**Bloqueada por:** 4.1 Prompt de acción contextual; 6.1 `Room` y cámara por sala

### 6.3 Llaves de mazmorra y HUD · Hecho

- [x] `GameState.current_dungeon` lo setea la escena de la mazmorra
  Al salir vuelve a `&""`.
- [x] Llave chica y llave del jefe como `ItemData`
  Enrutadas por `GameState.give()` al `DungeonState`.
- [x] HUD: llaves solo en mazmorra
  Contador de llaves chicas e ícono de llave del jefe.

**Prueba:** Juntar dos llaves y abrir una puerta: el contador baja a 1. Fuera de la mazmorra el contador no se ve.

**Notas:** Nodo Dungeon (src/world/dungeon.gd) en la escena de cada mazmorra: setea GameState.current_dungeon en _enter_tree y lo vuelve a &"" al salir. GameState emite dungeon_changed; DungeonState emite changed al cambiar llaves, mapa, brújula o salas: el HUD se actualiza por eventos. Las llaves ya existían como ItemData y GameState.give() las enruta al DungeonState (0.5/3.6). HUD como en HUD_Dungeon: debajo de los corazones, llave chica ×N y llave del jefe atenuada si no se tiene; solo dentro de una mazmorra.

**Referencias:** `gdd.md#estado-flags`, `gdd.md#ui`

**Bloquea a:** 6.7 Mazmorra de prueba: tres salas grises

**Bloqueada por:** 3.6 Cofres e item get; 6.2 Puertas

### 6.4 Bloques por grilla · Hecho

- [x] Crear `src/world/push_block.gd`
  `AnimatableBody3D` que se mueve 1 celda con tween tras empujar ≈0.3 s contra él.
- [x] Chequear la celda destino
  `ShapeCast3D` o consulta al espacio: no entra en paredes, otros bloques ni enemigos.
- [x] Estado `Pushing` del player y prompt "Empujar"
  Animación de empujar (KayKit `Interact` o la más parecida).
- [x] Reset al salir de la sala
  Los bloques vuelven a su lugar al re-entrar, salvo que un flag diga que el puzzle está resuelto.

**Prueba:** Empujar un bloque contra una pared no lo mueve; empujarlo sobre un interruptor de piso lo activa. Salir y volver: el bloque está en su posición inicial.

**Notas:** Skills: godot:godot-physics. PushBlock (AnimatableBody3D 1,8 m, grilla de 2 m): tras 0,3 s empujando se mueve una celda en 0,35 s y el player lo acompaña (estado Pushing, anim General/Interact: KayKit no tiene empujar). Prompt 'Empujar': interactuar también empuja una celda. Celda destino: consulta de caja para cuerpos (bloques, enemigos) + rayos para las paredes CSG (Jolt no las detecta con la caja: son mallas) + rayo de piso. Room emite player_left (lo dispara la cámara) y el bloque vuelve a su lugar, salvo solved_flag (queda en solved_position). FloorSwitch (paso 1 de 6.5) hecho acá para la prueba: HOLD/ONCE, lo pisan player, bloques y RigidBody3D. Puzzle en la sala B de levels/test_rooms.tscn.

**Referencias:** `gdd.md#mundo`

**Bloquea a:** 6.7 Mazmorra de prueba: tres salas grises; 7.7 Secretos del overworld

**Bloqueada por:** 6.1 `Room` y cámara por sala

### 6.5 Interruptores y cableado · Hecho

- [x] Interruptor de piso
  `FloorSwitch`: lo activa el player, un bloque o un `RigidBody3D`. Modos: mantener / una vez.
- [x] Interfaz común `activated`/`deactivated`
  La comparten `FloorSwitch`, `EyeSwitch` (5.3) y `LightReceiver` (5.6).
- [x] Cablear en el editor
  Las puertas y aparatos exportan `Array[NodePath]` de interruptores y una condición (todos / alguno). Sin código por sala.

**Prueba:** Una puerta que necesita dos interruptores: pisar uno no abre; con un bloque sobre el otro, sí.

**Notas:** FloorSwitch se hizo en 6.4. Interfaz común: active + activated/deactivated (LightReceiver expone active = lit). Wiring (src/world/wiring.gd): lista de NodePath + condición ALL/ANY, avisa con changed(satisfied). Lo usan Door (reemplazó el 'switch' único) y Gate. Ejemplo en levels/test_rooms.tscn: nicho en la sala B con NicheDoor cableada a BlockSwitch y PlayerSwitch (ALL).

**Referencias:** `gdd.md#mundo`

**Bloquea a:** 6.7 Mazmorra de prueba: tres salas grises

**Bloqueada por:** 6.2 Puertas

### 6.6 Mapa, brújula y pantalla de mapa · Hecho

- [x] Datos del mapa en cada `Room`
  Celda en la grilla del mapa (`map_cell`) y tamaño. El mapa se arma solo leyendo las salas.
- [x] Pantalla Mapa (pestaña de pausa y acción `map`)
  Salas visitadas; con mapa, todas; con brújula, cofres sin abrir y el jefe. Posición del player.
- [x] Mapa y brújula como ítems
  Por `GameState.give()` a `DungeonState`.
- [x] Mapa simple del overworld
  Imagen fija con la posición del player; alcanza para el MVP.

**Prueba:** Escenario `dungeon_no_bow` sin mapa: solo se ven las salas visitadas. Agregar el mapa desde el Save Inspector: aparecen todas.

**Notas:** Skills: `disciplines:game-ui-ux`. Hecho 2026-10-08: `Room.map_cell` + `boss_room` (el tamaño de celda es fijo, como en el mockup); título y piso desde el nodo `Dungeon`. Brújula: cofres sin abrir (grupo "chests") y ojo del jefe. Overworld: nodo `OverworldMap` con foto cenital ortográfica (`assets/ui/maps/test_level.png`). La tecla M abre la pausa en Mapa. Escenario `dungeon_no_bow` (test_rooms sin mapa). Tests en `tests/test_map.gd`.

**Referencias:** `gdd.md#ui`, `gdd.md#estado-flags`

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas; 6.1 `Room` y cámara por sala

### 6.7 Mazmorra de prueba: tres salas grises · Hecho

- [x] Kit de bloques grises
  `MeshLibrary` con pared, piso, columna, puerta y escalón sobre las texturas de prototipo; armar las salas con `GridMap`.
- [x] Tres salas conectadas
  Una con bloque e interruptor, una con persiana y esqueletos, una con puerta con llave y cofre.
- [x] Escenario de inicio en la mazmorra
  `debug/scenarios/dungeon_test.cfg`.

**Prueba:** Recorrer las tres salas desde el escenario sin trabarse: transiciones, persiana, llave y cofre funcionan; guardar en la sala 3 y cargar deja todo igual.

**Notas:** Cierra el hito: "tres salas en bloques grises conectadas". El kit se reutiliza en M7 y M8.

Skills: `godot:godot-3d-essentials`, `disciplines:level-design`.

Hecho 2026-10-08: kit `data/kits/gray_kit.tres` (lo arma `src/tools/build_gray_kit.gd`; texturas Kenney Prototype; celdas de 2 m). `levels/dungeon_test.tscn` (id `d0`, flags `d0_*`) como mini candado-y-llave según el artículo de metodología de mazmorras Zelda: la llave está en la sala lateral (guardia, con persiana y esqueletos), la puerta con llave lleva a la cámara con la brújula. Arreglo de paso: un `FloorSwitch` ONCE con flag no reabría su puerta al cargar la partida. Test: `tests/test_gray_dungeon.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 7.2 Blockout del overworld; 8.3 Salas 1–2: vestíbulo y hub

**Bloqueada por:** 6.2 Puertas; 6.3 Llaves de mazmorra y HUD; 6.4 Bloques por grilla; 6.5 Interruptores y cableado

## M7 — Overworld  (8/8)

Zona chica con el gating bombas → escudo espejo → sello del templo, y los secretos.

**Hecho cuando:**
- Ida y vuelta entre overworld y mazmorra.

### 7.1 Diseño del layout del overworld · Hecho

- [x] Diagrama de 6–8 pantallas
  Inicio, pradera, cueva de bombas, santuario, entrada al templo y los 3 secretos. Camino crítico y atajos.
- [x] Verificar el gating
  Que no se pueda llegar al santuario sin bombas ni al templo sin escudo espejo ([[gdd#progresion-gating]]).
- [x] Curva de ritmo
  Dónde hay combate, dónde descanso, dónde se descubre algo.
- [x] Actualizar el GDD
  Sección [[gdd#overworld]] y cerrar la decisión abierta del layout del overworld.

**Prueba:** El diagrama está en el GDD y responde: dónde está cada ítem, qué lo bloquea y por dónde se vuelve.

**Notas:** Sesión de diseño antes de construir.

Skills: `disciplines:level-design`.

Hecho 2026-10-08: layout de 8 zonas en GDD §7.1 (diagrama, tabla por zona, verificación del gating, atajo que abre solo desde el Santuario, curva de ritmo). Aplica el artículo de metodología de mazmorras Zelda: cebo temprano (templo y ojo del risco visibles), enseñar antes de exigir (muro de práctica, puzzle de luz en el Santuario), hub con referencia visual.

**Referencias:** `gdd.md#overworld`, `gdd.md#progresion-gating`, `gdd.md#decisiones-abiertas`

**Bloquea a:** 7.2 Blockout del overworld

### 7.2 Blockout del overworld · Hecho

- [x] Crear `levels/overworld.tscn`
  Terreno y límites en gris con el kit de 6.7; `levels/test.tscn` queda como nivel de pruebas.
- [x] Puntos de reaparición y nombres de zona
  `SpawnPoint` por zona; el HUD muestra el nombre al entrar a cada una.
- [x] Navmesh y enemigos de la pradera
  Esqueletos y pasto (si 4.4 entró).
- [x] Objetos físicos
  Cajas y rocas para empujar y volar con bombas.

**Prueba:** Recorrer el overworld de punta a punta con el inventario completo sin caer fuera del mapa ni trabarse.

**Notas:** Skills: `disciplines:level-design`, `godot:godot-3d-essentials`.

Hecho 2026-10-08: `levels/overworld.tscn` con el kit gris + piezas de exterior (pasto, acantilado, cerco, árbol, abismo). 8 zonas con `AreaZone` (nombre en el HUD) y `SpawnPoint` por zona; aberturas con gating de 1 celda, abiertas hasta 7.4/7.5/7.7. Navmesh horneada desde el `GridMap`; 3 esqueletos en la pradera; cajas y rocas (`physics_box.tscn`, `physics_rock.tscn`). Test `tests/test_overworld.gd`: recorre las 8 zonas caminando con input y verifica que el abismo frena al player pero no a las flechas.

**Referencias:** `gdd.md#overworld`

**Bloquea a:** 7.3 Cambio de escena overworld ↔ mazmorra; 7.4 Cueva de las bombas; 7.7 Secretos del overworld

**Bloqueada por:** 6.7 Mazmorra de prueba: tres salas grises; 7.1 Diseño del layout del overworld

### 7.3 Cambio de escena overworld ↔ mazmorra · Hecho

- [x] `Portal`
  Área con escena destino y `spawn_point`. Actualiza `GameState.spawn_scene`, `spawn_point` y `current_dungeon`.
- [x] Fundido y carga en segundo plano
  `ResourceLoader.load_threaded_request` para que no se congele la imagen.
- [x] Guardado al cambiar de escena
  Autosave mínimo para no perder progreso (la política completa va en 10.2).

**Prueba:** Entrar y salir del templo varias veces: el player aparece en la puerta correcta, sin congelarse, y el estado de la mazmorra se conserva.

**Notas:** Skills: `godot:godot-resources`, `disciplines:save-systems`.

Hecho 2026-10-08: `Portal` + `SaveManager.travel_to()` (pausa, fundido, `load_threaded_request`, spawn con cámara enganchada, autosave en `autosave_slot`). La fachada del templo del overworld lleva a la mazmorra gris (`dungeon_test`, spawn `start`); la salida sur del vestíbulo vuelve al spawn `templo`. En M8 el portal apunta al templo. Test: `tests/test_portal.gd`.

**Referencias:** `gdd.md#estado-flags`, `gdd.md#guardado`

**Bloquea a:** 7.6 Sello del templo

**Bloqueada por:** 7.2 Blockout del overworld

### 7.4 Cueva de las bombas · Hecho

- [x] Interior de la cueva
  Una o dos salas con `Room` (cámara de sala) o zona abierta, según el layout.
- [x] Cofre con la bolsa de bombas
  Flag `ow_cave_bombs_chest`; tablilla que enseña a usarlas.
- [x] Primer muro agrietado a la vista
  Justo después, para que el jugador pruebe la bomba enseguida.

**Prueba:** Desde el escenario `start`: conseguir las bombas y romper el primer muro.

**Notas:** Hecho 2026-10-08: zona abierta (sin `Room`). Cofre `ow_cave_bombs_chest` + tablilla (cue `cave_bombs`); muro de práctica `ow_cave_practice_wall` con vasija de corazones detrás; muro `ow_shrine_cracked_wall` en el paso al Santuario (el gating ya es real). Test `tests/test_cave.gd` (desde `start`: cofre, bomba con el botón, muro roto). Pulido pendiente: paredes del recoveco tapan al player.

**Referencias:** `gdd.md#progresion-gating`, `gdd.md#items-mvp`

**Bloquea a:** 7.5 Santuario del escudo espejo

**Bloqueada por:** 5.4 Bombas; 5.5 Muros agrietados; 7.2 Blockout del overworld

### 7.5 Santuario del escudo espejo · Hecho

- [x] Santuario detrás del muro agrietado
  Sala chica con un desafío corto antes del cofre (combate o bloques).
- [x] Cofre grande con el escudo espejo
  Se equipa solo; *item get* explica que refleja la luz.
- [x] Haz de luz de práctica
  Un cristal en el santuario para enseñar el reflejo antes del sello.

**Prueba:** Desde el escenario `bombs_only`: llegar al santuario, conseguir el escudo y activar el cristal de práctica.

**Notas:** Hecho 2026-10-08: bloque → interruptor `ow_shrine_switch` → reja del cofre grande (`ow_shrine_mirror_chest`, escudo espejo con `equip_on_get`). Haz de práctica: cristal `ow_shrine_shortcut` abre la reja del atajo a la entrada del templo (solo desde adentro). Escenario `bombs_only`. Arreglos de paso: `Gate` no se abría al cargar con el cableado ya satisfecho y `LightReceiver` con flag se restauraba tarde y sin avisar. Test `tests/test_shrine.gd`.

**Referencias:** `gdd.md#progresion-gating`, `gdd.md#items-mvp`

**Bloquea a:** 7.6 Sello del templo

**Bloqueada por:** 5.6 Escudo espejo y haz de luz; 7.4 Cueva de las bombas

### 7.6 Sello del templo · Hecho

- [x] Puzzle del sello
  Fuente de luz + espejos fijos + el escudo: hay que llevar el haz hasta el sello.
- [x] Abrir la entrada
  Flag `ow_temple_seal_open`; animación y temblor (primer momento de *doom*).
- [x] Temblores lejanos al acercarse
  Sacudida suave de cámara y sonido grave al entrar en la zona del templo.

**Prueba:** Desde `pre_temple`: abrir el sello y entrar a la mazmorra; al volver, la entrada sigue abierta.

**Notas:** Hecho 2026-10-08: fuente + espejo fijo + escudo → cristal `ow_temple_seal_open` → `TempleSeal` (Gate con sacudida, retumbo y polvo). `TremorZone` en la entrada del templo. Sonido nuevo `rumble` en Feel. Escenario `pre_temple`. Test `tests/test_temple_seal.gd`.

**Referencias:** `gdd.md#progresion-gating`, `gdd.md#historia`

**Bloquea a:** 7.8 Escenarios del overworld

**Bloqueada por:** 7.3 Cambio de escena overworld ↔ mazmorra; 7.5 Santuario del escudo espejo

### 7.7 Secretos del overworld · Hecho

- [x] Botella con poción tras un muro agrietado
  Opcional.
- [x] Cota reforzada en un puzzle de bloques
  Cofre secreto; ejercita la pantalla Equipo.
- [x] Carcaj grande post-mazmorra
  Ojo-interruptor alto o lejano que solo se alcanza con el arco; suma `_capacity_bonus` de flechas.

**Prueba:** Con `full_inventory`, encontrar los tres secretos; con `start`, el carcaj no se puede conseguir.

**Notas:** Recortables en este orden: carcaj, cota ([[gdd#roadmap]]).

Hecho 2026-10-08: gruta (muro + poción + tablilla con pista), arboleda (dos bloques → reja → cota), risco (ojo con flecha → nicho → carcaj +20). Test `tests/test_secrets.gd` (los tres con todo; sin arco el ojo no despierta).

**Referencias:** `gdd.md#overworld`, `gdd.md#items-mvp`

**Bloqueada por:** 5.3 Arco y flechas; 6.4 Bloques por grilla; 7.2 Blockout del overworld

### 7.8 Escenarios del overworld · Hecho

- [x] Crear `start`, `bombs_only` y `pre_temple`
  En `debug/scenarios/`, desde el Save Inspector.
- [x] Recorrido completo de ida y vuelta
  Overworld → templo → overworld.

**Prueba:** Jugar `start` hasta entrar al templo y volver a salir sin usar escenarios intermedios.

**Notas:** Cierra el hito: "ida y vuelta entre overworld y mazmorra".

Hecho 2026-10-08: `start` ahora arranca en el overworld (escena principal del juego); `bombs_only` y `pre_temple` ya venían de 7.5 y 7.6 (generados con SaveCodec, mismo formato que el Save Inspector). `tests/test_overworld_run.gd` juega `start` hasta el templo y vuelve.

**Referencias:** `gdd.md#save-inspector`

**Bloqueada por:** 7.6 Sello del templo

## M8 — Contenido de mazmorra  (8/8)

Las 8 salas en bloques grises, el arco a mitad de camino, la llave del jefe.

**Hecho cuando:**
- La mazmorra se recorre entera.

### 8.1 Layout de la mazmorra · Hecho

- [x] Diagrama de conexiones de las 8 salas + jefe
  Hub central con 4 salidas ([[gdd#mazmorra]]).
- [x] Contar llaves y puertas con llave
  Nunca menos llaves accesibles que puertas en cualquier orden de recorrido (evitar softlocks).
- [x] Ubicar el arco a mitad de camino
  La segunda mitad necesita el arco; el jugador vuelve por salas ya vistas con algo nuevo.
- [x] Curva de tensión y *doom* por sala
  Columna "Doom" del GDD.
- [x] Actualizar el GDD
  Cerrar la decisión abierta del layout de la mazmorra.

**Prueba:** El diagrama está en el GDD; recorrerlo en papel en cualquier orden posible no deja al jugador sin llaves.

**Notas:** Skills: `disciplines:level-design`.

Hecho 2026-10-08: diagrama, tabla de puertas, conteo de llaves (2 y 2, la llave 1 solo sirve en el hub este), arco a mitad de camino y curva en GDD §8.1.

**Referencias:** `gdd.md#mazmorra`, `gdd.md#decisiones-abiertas`

**Bloquea a:** 8.3 Salas 1–2: vestíbulo y hub

### 8.2 Esqueleto con escudo · Hecho

- [x] `EntityConfig` y escena
  Variante del esqueleto con escudo equipado.
- [x] Bloquea de frente
  Reutilizar la lógica de cono de 1.2 en el `_on_hurtbox_hit` del enemigo.
- [x] Vulnerable de flanco, a bombas y al golpe de escudo
  El golpe de escudo le baja la guardia un momento.
- [x] BT: avanza con guardia y gira hacia el player
  Más lento que el esqueleto común; no puede girar rápido.

**Prueba:** Pegarle de frente no hace daño; rodar a su espalda, una bomba o un golpe de escudo y luego espada, sí.

**Notas:** Skills: `disciplines:ai-behavior-trees-utility-ai`, `disciplines:game-ai`.

Hecho 2026-10-08: `shield_skeleton.tscn` + `data/entities/shield_skeleton.tres`. La guardia vive en `Enemy._guard_stops` y se configura en `EntityConfig` (grupo Escudo); el golpe de escudo es el `SHIELD_THRUST` que ya existía (atacar bloqueando, aturde). Mismo BT del esqueleto, más lento (1.8 m/s) y con `turn_speed` 2.2 rad/s. Test `tests/test_shield_skeleton.gd`.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 8.5 Sala 5: arena y arco

**Bloqueada por:** 1.4 IA del esqueleto con `BTAttack`

### 8.3 Salas 1–2: vestíbulo y hub · Hecho

- [x] Sala 1: bloque por grilla → interruptor → persiana
- [x] Sala 2: hub con 4 salidas y esqueletos
  Con llave, con persiana, la del jefe (sellada) y una libre.

**Prueba:** Desde la entrada de la mazmorra, llegar al hub y ver las 4 salidas en el estado que dice el GDD.

**Notas:** Hecho 2026-10-08: `levels/temple.tscn` con la geometría de las 9 salas (§8.1) y el contenido de vestíbulo y hub. La puerta del templo del overworld ahora lleva acá (antes a `dungeon_test`). Test `tests/test_temple.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.4 Salas 3–4: galería de trampas y sala agrietada; 8.5 Sala 5: arena y arco

**Bloqueada por:** 6.7 Mazmorra de prueba: tres salas grises; 8.1 Layout de la mazmorra

### 8.4 Salas 3–4: galería de trampas y sala agrietada · Hecho

- [x] Sala 3: reflejar orbes de torretas a un cristal
  Da una llave chica.
- [x] Sala 4: muro bombable y bombas que empujan bloques físicos
  Da el mapa.

**Prueba:** Resolver las dos salas desde `dungeon_no_bow` y salir con la llave y el mapa.

**Notas:** Hecho 2026-10-08: galería (torreta → reflejo → ojo → llave 1; ojo de la puerta norte solo con flecha) y sala agrietada (bomba vuela la caja del hueco → mapa; muro agrietado a la arena). Simplificación: en vez de "bombas empujan bloques a un interruptor", la bomba despeja el paso (más robusto con física). `dungeon_no_bow` ahora es del templo (en el hub); el escenario viejo de las salas de prueba se llama `test_rooms`. Test en `tests/test_temple.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloqueada por:** 5.2 Torreta / ojo menor; 5.4 Bombas; 8.3 Salas 1–2: vestíbulo y hub

### 8.5 Sala 5: arena y arco · Hecho

- [x] Oleadas
  `WaveSpawner`: las oleadas aparecen al entrar; la persiana se abre al terminar la última.
- [x] Cofre grande con el arco
  Flag `d1_chest_bow`; *item get* con flechas iniciales.

**Prueba:** Ganar las oleadas (incluido el esqueleto con escudo) y conseguir el arco; morir a mitad de oleada y reintentar empieza de cero.

**Notas:** Hecho 2026-10-08: `WaveSpawner` + `WaveSpawn` (oleadas como nodos hijos, flag `d1_arena_cleared`, hace de interruptor); `Room` no abre persianas mientras corren oleadas. Cofre grande del arco tras una reja. Tests en `tests/test_temple.gd` (oleadas + arco; morir a mitad reinicia).

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.6 Salas 6–7: ojos y puzzle combinado

**Bloqueada por:** 8.2 Esqueleto con escudo; 8.3 Salas 1–2: vestíbulo y hub

### 8.6 Salas 6–7: ojos y puzzle combinado · Hecho

- [x] Sala 6: ojos-interruptor sobre un abismo
  Solo con flechas. Da la brújula y una llave chica. Caer al abismo: daño y vuelta a la entrada.
- [x] Sala 7: bloques + reflejo + flechas en secuencia
  Da la llave del jefe. Recortable: fusionar con la 6 ([[gdd#roadmap]]).

**Prueba:** Con el arco, resolver las dos salas y salir con brújula y llave del jefe.

**Notas:** Hecho 2026-10-08: `Pit` (caer = daño y vuelta a la entrada de la sala), `Bridge` (sube con sus interruptores) y la pieza Hueco del kit. Ojos: dos ojos con flecha → brújula y puente → llave 2. Puzzle: bloque → reja del haz → cristal → reja del ojo → flecha → llave del jefe + sello del hub (cableado entre salas). Test en `tests/test_temple.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.7 Sala 8: antesala

**Bloqueada por:** 5.3 Arco y flechas; 5.6 Escudo espejo y haz de luz; 8.5 Sala 5: arena y arco

### 8.7 Sala 8: antesala · Hecho

- [x] Vasijas con corazones, tablilla y puerta del jefe
  La tablilla anticipa al jefe.
- [x] Checkpoint antes del jefe
  Reaparecer en la antesala al morir contra el jefe.

**Prueba:** Abrir la puerta del jefe con su llave; morir adentro devuelve a la antesala.

**Notas:** Hecho 2026-10-08: vasijas de corazones, tablilla (cue `antechamber`), puerta del jefe `d1_boss_door`. Checkpoint: `TopDownCamera._remember_entry` ignora la sala del jefe, así que morir ahí reaparece en la antesala. Escenarios `pre_boss` y `boss_key_door_locked` generados (8.8 los valida). Tests en `tests/test_temple.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.8 Recorrido completo y escenarios de la mazmorra

**Bloqueada por:** 4.3 Tablillas; 4.4 Vasijas y pasto; 8.6 Salas 6–7: ojos y puzzle combinado

### 8.8 Recorrido completo y escenarios de la mazmorra · Hecho

- [x] Escenarios `dungeon_no_bow`, `pre_boss` y `boss_key_door_locked`
  El último, inconsistente a propósito, para probar la validación.
- [x] Recorrido entero sin escenarios intermedios
  Anotar tiempos y dónde se traba el jugador.
- [x] Buscar softlocks
  Quedarse sin bombas o flechas (¿hay drops?), bloques trabados, puertas que se cierran con el player del lado equivocado.

**Prueba:** Jugar de la entrada a la puerta del jefe con un solo guardado al principio.

**Notas:** Cierra el hito: "la mazmorra se recorre entera".

Hecho 2026-10-08: escenarios `dungeon_no_bow`, `pre_boss`, `boss_key_door_locked` (+ regla en `SaveCodec.validate`: puerta del jefe abierta sin llave). Recorrido completo automatizado (tiempos simulados por tramo: vestíbulo+hub 6 s, galería 6 s, agrietada 12 s, arena 7 s, ojos 12 s, puzzle 7 s, antesala 3 s). Softlocks revisados en GDD §8.1. Pendiente: jugarla a mano para tiempos reales y dónde se traba un jugador.

**Referencias:** `gdd.md#mazmorra`, `gdd.md#save-inspector`

**Bloquea a:** 10.6 Ambientación del doom; 10.8 Pasada de rendimiento

**Bloqueada por:** 8.7 Sala 8: antesala

## M9 — Jefe  (8/8)

Integrar el ojo con manos (piezas que mueve el código) y armar las fases 1 y 2 con LimboAI.

**Hecho cuando:**
- Se puede terminar el juego.

### 9.1 Integrar el modelo del jefe · Hecho

- [x] Traer el modelo del jefe al proyecto
  Las mallas de `assets/epiphany/meshes/jefe/` (salen de `tools/blender/build_jefe.py`), armadas en una escena.
- [x] Armar la jerarquía que mueve el código
  Pivotes para el ojo (look_at), los párpados (rotación en X) y las manos (cambio de pose entre abierta, puño y garra); sockets de orbes y de reposo.
- [x] Revisar escala y ejes en la sala del jefe
  Que entre en el encuadre de la cámara del jefe (≈26 × 14,5 m) en la sala de 22 × 14 m.

**Prueba:** La escena del jefe se abre en el editor con el cuerpo, el ojo (gira entero con look_at), los dos párpados y las dos manos (tres poses cada una) como nodos separados, y sus sockets (salida de orbes, anclas y reposo de las manos) en su lugar.

**Notas:** Skills: `godot:godot-3d-essentials`. Sin rig ni AnimationTree: el .blend de la jam no tenía; las piezas las mueve el código (decidido el 2026-10-09, gdd §9).

2026-10-09: boss.tscn con Boss (eye_open, look_at_point, hand_rest) y BossHand (pose). Cuerpo a 3 m en (24, 0, 14,5) de la Guarida, entero en cuadro. tests/test_boss.gd. Pendiente para 9.6: el portal de salida está en el centro de la sala y tapa el ojo; tiene que aparecer recién al morir el jefe.

**Referencias:** `gdd.md#jefe`, `gdd.md#decisiones-abiertas`

**Bloquea a:** 9.2 Arena del jefe y barra de vida; 9.3 Arquitectura del jefe

### 9.2 Arena del jefe y barra de vida · Hecho

- [x] Sala del jefe con `Room`
  Límites de cámara que encuadran toda la arena; puerta que se cierra al entrar.
- [x] Intro corta
  Cámara al ojo, nombre en pantalla, música (placeholder).
- [x] Barra de vida del jefe en el HUD
  Escucha el `Health` del jefe; aparece en la intro y se va al morir.

**Prueba:** Entrar a la arena: la puerta se cierra, la intro se puede saltar y la barra baja al pegarle.

**Referencias:** `gdd.md#jefe`, `gdd.md#ui`

**Bloquea a:** 9.4 Fase 1: manos

**Bloqueada por:** 6.1 `Room` y cámara por sala; 9.1 Integrar el modelo del jefe

### 9.3 Arquitectura del jefe · Hecho

- [x] Jefe + manos como entidades
  Cada mano con su `Health`, `Hurtbox`, `Hitbox` y `AttackRunner`; el ojo con los suyos.
- [x] Fases con `LimboHSM`
  Estados `Phase1`, `Phase2` (y `Phase3`); cada uno corre su BT.
- [x] Blackboard compartido
  Posición del player, manos vivas/aturdidas, fase actual. Elegir el ataque con utilidad (distancia, último ataque) para que no sea predecible.

**Prueba:** Con el overlay: la fase, el estado de cada mano y el ataque elegido se ven en vivo.

**Notas:** Skills: `disciplines:ai-behavior-trees-utility-ai`.

**Referencias:** `gdd.md#jefe`

**Bloquea a:** 9.4 Fase 1: manos

**Bloqueada por:** 9.1 Integrar el modelo del jefe

### 9.4 Fase 1: manos · Hecho

- [x] Golpe al piso telegrafiado
  Sombra en el suelo que se achica antes del impacto; onda de choque.
- [x] Agarre
  Si atrapa al player, daño por tiempo; se escapa apretando botones o con un golpe de la otra mano.
- [x] Mano aturdida tras el golpe al piso
  Ventana de espadazos; aturdir las dos pasa a fase 2.

**Prueba:** Se puede ganar la fase solo con bloqueo y roll; los golpes se pueden anticipar mirando la sombra.

**Notas:** Skills: `disciplines:game-feel`. Hecho 2026-10-10: el agarre se suelta solo a botones (8) o por tiempo (lo tira a los 3 s); no se implementó el escape con el golpe de la otra mano.

**Referencias:** `gdd.md#jefe`

**Bloquea a:** 9.5 Fase 2: el ojo

**Bloqueada por:** 9.2 Arena del jefe y barra de vida; 9.3 Arquitectura del jefe

### 9.5 Fase 2: el ojo · Hecho

- [x] El ojo se abre
  Transición con temblor; las manos se regeneran.
- [x] Flecha al ojo → cae aturdido
  Ventana de espadazos.
- [x] Orbes reflejables
  Alternativa con escudo espejo para aturdirlo.

**Prueba:** Se puede ganar la fase con flechas y también solo con reflejo; las manos siguen presionando.

**Referencias:** `gdd.md#jefe`

**Bloquea a:** 9.6 Muerte del jefe y final

**Bloqueada por:** 5.1 Proyectiles; 5.3 Arco y flechas; 9.4 Fase 1: manos

### 9.6 Muerte del jefe y final · Hecho

- [x] Animación de muerte y flag `d1_boss_defeated`
  Las manos caen, la sala se calma.
- [x] Contenedor de corazón
  Aparece en la arena; `GameState.give()` suma 4 HP al máximo.
- [x] Final del MVP
  Al tomar el contenedor o salir, pantalla de fin y créditos placeholder.
- [x] Poner required_flag = d1_boss_defeated al BossExitPortal
  El portal (9.8) ya está en la sala; con el flag aparece al vencer al jefe.

**Prueba:** Desde `pre_boss`: ganar, tomar el contenedor y llegar a los créditos. Cargar después: el jefe no reaparece.

**Notas:** Cierra el hito: "se puede terminar el juego".

**Referencias:** `gdd.md#jefe`, `gdd.md#items-mvp`

**Bloquea a:** 9.7 Fase 3 (recortable)

**Bloqueada por:** 9.5 Fase 2: el ojo

### 9.7 Fase 3 (recortable) · Hecho

- [x] El ojo marca el piso antes de golpes de área
- [x] Combinar patrones de manos y ojo

**Prueba:** La fase 3 se activa por debajo de cierto umbral de vida y se puede ganar sin recibir daño inevitable.

**Notas:** Primera en la lista de recortes ([[gdd#roadmap]]). Solo si sobra tiempo.

**Referencias:** `gdd.md#jefe`, `gdd.md#roadmap`

**Bloqueada por:** 9.6 Muerte del jefe y final

### 9.8 Portal de salida en la sala del jefe · Hecho

**Prioridad:** media · **Etiquetas:** `mazmorra`

- [x] Portal.required_flag: oculto hasta que el flag sea verdadero
- [x] Escena warp_portal.tscn en el centro de la sala del jefe, al overworld (Spawn_templo)
- [x] Test, captura y GDD

**Prueba:** Desde pre_boss: pararse en el portal de la sala del jefe y aparecer en la Entrada del templo.

**Notas:** Sin flag por ahora porque no hay jefe; 9.6 le pone d1_boss_defeated.

## M10 — Terminación  (15/22)

Título, selección de partida, game over, opciones, ambientación del doom, audio y build para playtesters (compilar las plantillas de LimboAI).

**Hecho cuando:**
- MVP jugable por otra persona.

### 10.1 Pantalla de título · Hecho

- [x] Logo y menú
  Continuar / Nueva partida / Opciones / Salir. Navegable con gamepad y teclado.
- [x] *Cargar escenario* solo en debug
  Lista de `debug/scenarios/`.
- [x] Escena principal del proyecto
  El título pasa a ser `run/main_scene`; respetar `--scenario=` y `next_scenario.txt`.

**Prueba:** Arrancar el juego exportado: título, nueva partida, jugar, salir al título y continuar.

**Notas:** Skills: `disciplines:game-ui-ux`.

Hecho 2026-10-09: título como `run/main_scene` (mockup Main), `MenuItem` y `HintBar` reutilizables, `SaveManager.new_game()`/`quit_to_title()`/`has_save()`, versión en `application/config/version`. Opciones queda deshabilitado hasta 10.4, que también suma "Salir al título" en la pausa. Test `tests/test_title.gd`.

**Referencias:** `gdd.md#ui`

**Bloquea a:** 10.2 Selección de partida y autosave; 10.3 Game over; 10.4 Opciones

**Bloqueada por:** 3.1 Menú de pausa y pila de pantallas

### 10.2 Selección de partida y autosave · Hecho

- [x] Decidir 1 o 3 ranuras
  Cerrar la decisión en [[gdd#decisiones-abiertas]].
- [x] Pantalla de ranuras
  Corazones, ubicación y tiempo jugado (sumar `play_time` a `GameState`).
- [x] Política de autosave
  Al cambiar de escena, al abrir cofres grandes y al entrar a la antesala. Indicador de guardado en pantalla.
- [x] Borrar partida con confirmación

**Prueba:** Jugar en dos ranuras distintas y verificar que no se pisan; cortar el proceso a mitad de un guardado no rompe la partida.

**Notas:** Skills: `disciplines:save-systems`.

Hecho 2026-10-09: 3 ranuras (decisión cerrada), `FileSelect` + `SlotCard` (mockup FileSelect, con Copiar), `play_time` y `location` en la partida, autosave en escena/cofre grande/antesala con indicador en el HUD. `SaveManager.save_dir` es variable para que los tests no toquen las partidas reales. Tests `tests/test_slots.gd`.

**Referencias:** `gdd.md#guardado`, `gdd.md#ui`

**Bloqueada por:** 10.1 Pantalla de título

**Relacionadas:** 10.21 Título y ranuras: Continuar, Nueva partida y ranura de autosave

### 10.3 Game over · Hecho

- [x] Pantalla al morir
  Continuar (desde la entrada de la sala / último checkpoint) o Guardar y salir.
- [x] Reemplaza el fundido de 1.5

**Prueba:** Morir en overworld, en mazmorra y contra el jefe: cada "Continuar" lleva al lugar correcto.

**Notas:** Hecho 2026-10-09: `GameOver` (mockup) reemplaza el fundido de 1.5; `SaveManager.save_checkpoint()` para Guardar y salir; `MenuStack` respeta pantallas `modal`. Morir contra el jefe vuelve a la antesala (8.7). Tests `tests/test_game_over.gd` + los de muerte actualizados.

**Referencias:** `gdd.md#ui`, `gdd.md#combate`

**Bloqueada por:** 1.5 Muerte y reaparición del player; 10.1 Pantalla de título

### 10.4 Opciones · Hecho

- [x] Lock-on mantener/alternar, sensibilidad de apuntado, volúmenes
- [x] Guardar en `user://settings.cfg`
  Separado de la partida; se aplica al arrancar.
- [x] Accesible desde título y pausa

**Prueba:** Cambiar cada opción, reiniciar el juego: se mantienen.

**Notas:** Skills: `disciplines:game-ui-ux`, `disciplines:input-systems`.

Hecho 2026-10-09: autoload `Settings` + `OptionsPanel` (todo el mockup Options; la vibración no existía y se agregó vía `Feel.shake`). Pantalla desde el título; pestaña Sistema en la pausa con Guardar y salir al título. Crea los buses Music/SFX/UI/Ambience (10.5 los usa). Tests `tests/test_options.gd`.

**Referencias:** `gdd.md#ui`

**Bloquea a:** 10.18 Idiomas: inglés y español

**Bloqueada por:** 10.1 Pantalla de título

### 10.5 Audio · Hecho

- [x] Buses Master / Music / SFX / UI / Ambience
  Volúmenes en dB desde Opciones (10.4).
- [x] Conseguir SFX y música
  Lista de assets a conseguir en `compass/lists/` con licencias.
- [x] Variación de SFX
  Pitch y volumen aleatorio, varias muestras por evento.
- [x] Música por capas para el *doom*
  Capas que se suman sala a sala en la mazmorra; ducking durante *item get* y caja de texto.

**Prueba:** Recorrer el overworld y la mazmorra con auriculares: nada satura, la música cambia con el avance y los SFX repetidos no suenan idénticos.

**Notas:** Skills: `disciplines:audio-design`, `godot:godot-audio`.

Hecho 2026-10-09: buses (vía `Settings`), SFX de Kenney CC0 con variación, sonidos de interfaz globales, música en capas sintetizada (`render_music.gd` + autoload `Music`) que sigue `Room.doom` y hace ducking con menús. Lista `assets-de-audio` con licencias y lo que falta conseguir. Test `tests/test_audio.gd`.

**Referencias:** `gdd.md#historia`

### 10.6 Ambientación del doom · Hecho

- [x] Nivel de *doom* por sala
  Valor 0..1 exportado en `Room` que mueve luz, niebla y partículas.
- [x] Luz que vira a rojo, polvo, grietas
  `WorldEnvironment` y luces interpoladas; decals de grietas.
- [x] Temblores y murmullo
  Sacudidas de cámara esporádicas y audio ambiente (10.5).

**Prueba:** Recorrer la mazmorra de la sala 1 a la 8: la progresión de calma a latido se nota sin leer nada.

**Notas:** Pilar 4: el *doom* se siente, no se cronometra.

Skills: `godot:godot-shaders`, `godot:godot-3d-essentials`.

Hecho 2026-10-09: `Room.doom` + `DoomAmbience` (luz, niebla, polvo, grietas con decals generados, temblores con retumbo); el murmullo de la música va por el bus Ambience. Test `tests/test_doom.gd` (recorre las salas 1 a 8 y verifica que todo sube). El rojo del clímax es fuerte: se ajusta con los exports de `DoomAmbience`.

**Referencias:** `gdd.md#historia`, `gdd.md#pilares`, `gdd.md#mazmorra`

**Bloqueada por:** 8.8 Recorrido completo y escenarios de la mazmorra

### 10.7 Dirección de arte y pasada visual · Hecho

- [x] Decidir: KayKit + prototipo o dirección propia
  Cerrar la decisión en [[gdd#decisiones-abiertas]].
- [x] Guía de estilo corta
  Paleta, materiales, tamaño de íconos y UI.
- [x] Reemplazar placeholders críticos
  HUD, íconos, cofres, puertas, muros agrietados (que se lean como secreto).

**Prueba:** Capturas del overworld, la mazmorra y el HUD se ven como un mismo juego.

**Notas:** Skills: `disciplines:create-game-assets`.

Hecho 2026-10-09: decisión cerrada (KayKit + prototipo pulido) y guía de estilo en GDD §10.1. KayKit Dungeon Remastered (CC0) para cofres (normal y dorado), muros agrietados y antorchas con luz que titila en el templo. Las puertas quedan como estaban (el marco de KayKit no entra en los huecos de 2 m); HUD e íconos ya seguían los mockups. El pack `kenney_fantasy-ui-borders` que se agregó no se usó: cambiaría el look de los mockups.

**Referencias:** `gdd.md#decisiones-abiertas`

### 10.8 Pasada de rendimiento · Revisión

- [x] Presupuesto de frame
  60 FPS en la máquina más floja de los playtesters.
- [ ] Perfilar las peores escenas
  Arena con oleadas, overworld con pasto, jefe. Profiler y monitores `epiphany/*`.
- [x] Arreglar lo que se mida
  Pools, MultiMesh, luces con sombra, partículas.

**Prueba:** Las tres escenas se mantienen en el presupuesto en build release.

**Notas:** Skills: `disciplines:performance-optimization`.

2026-10-09: presupuesto 16,6 ms p95; `src/tools/profile_scenes.gd` mide pradera, arena y antesala (todas ≈ 5 ms medio, ≤ 8 ms p95 en RX 580). Arreglado el tirón al aparecer oleadas (un enemigo por cuadro). Queda en Revisión: falta la escena del jefe (M9) y medir en build release (10.9) en la máquina más floja.

**Bloqueada por:** 8.8 Recorrido completo y escenarios de la mazmorra

### 10.9 Build para playtesters · Revisión

- [ ] Compilar las plantillas de export del LimboAI propio
  template_release para Linux, Windows, macOS y web (wasm32 nothreads). Instalar además las plantillas de Godot 4.8-dev7 (en curso, 2026-10-10).
- [x] Presets de export
  Excluir `debug/scenarios/*` y `tests/`; `plain_saves` solo en el preset de debug.
- [x] Cambiar la clave de guardado
  `SaveCodec._PASS` antes del primer release.
- [x] Build por línea de comandos
  Script `tools/build.sh` con `godot --headless --export-release`.
- [ ] Preset de macOS sin firmar
  Universal (Intel + Apple Silicon), bundle id, ícono .icns; sin firma ni notarización por ahora (los playtesters abren con clic derecho → Abrir o xattr -dr com.apple.quarantine). Sin Mac para probar: se confía en los reportes. LimboAI necesita liblimboai.macos.template_release.framework (osxcross o una Mac).
- [ ] Ícono y metadatos del .exe (opcional)
  rcedit configurado en el editor (con wine en Linux); sin firma, SmartScreen avisa y se sigue con 'Ejecutar de todas formas'.

**Prueba:** Instalar el build en una máquina limpia (Linux y Windows): arranca, guarda en `user://` cifrado y no incluye escenarios ni tests.

**Notas:** Skills: `godot:godot-export`. Decidido 2026-10-10: Windows y macOS van sin firmar; macOS sin probar (no hay Mac), se arreglan los reportes.

**Referencias:** `gdd.md#guardado`

**Bloquea a:** 10.10 Publicar en itch.io y playtest

**Relacionadas:** 10.22 Build web

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

**Relacionadas:** 10.22 Build web

### 10.11 UI restante a escenas · Hecho

**Prioridad:** media · **Etiquetas:** `ui`

- [x] Filas de stats de ItemDetail como escena
  item_detail.gd add_stat arma HBox + Labels + MarginContainer + HSeparator con .new(). Pasar a stat_row.tscn.
- [x] Pestaña Equipo: grilla y ranuras como escenas
  equipment_page.gd crea VBox/Label/HBox por categoría, Button por ranura y el Label de la insignia E. Secciones en la escena y ranura reutilizando item_slot.tscn o una equip_slot.tscn.
- [x] Pestaña Mapa: celdas, leyenda y stats como escenas
  map_page.gd crea MapRoomCell, filas de leyenda y filas de stats por código; map_room_cell.gd arma su StyleBoxFlat en código (pasar a variaciones del tema).
- [x] Corazones (HeartIcon) como escena
  HUD, tarjeta de ranura y Equipo hacen HeartIcon.new(), y heart_icon.gd arma sus TextureRect internos por código.
- [x] Test: ningún script de src/ui crea Controls con .new()
  Un test que recorra src/ui/**/*.gd y falle si encuentra Label.new(), Button.new(), *Container.new(), etc. (permitiendo Tween, Image, etc.).

**Notas:** Lo que todavía se arma por código (anterior a la regla: toda la UI son .tscn, los scripts solo llenan datos). Lo repetido es su propia escena chica, instanciada por ítem; estilos en theme.tres.

### 10.12 Rango de fijado: una sola fuente · Hecho

**Prioridad:** baja · **Etiquetas:** `combate`

- [x] Decidir la fuente única del rango
  O se edita solo Targeting.targeting_range (y la forma se oculta/regenera), o Targeting lee el radio de la forma y se borra el export.
- [x] Que el inspector refleje el valor real
  Si queda el export: setter @tool que actualice la forma en el editor, así no hay dos números distintos.
- [x] Test del rango de fijado
  El radio efectivo del detector y la distancia de suelte coinciden con el valor elegido.

**Notas:** Targeting.targeting_range (12 m) pisaba en _ready el radio del CylinderShape3D de TargetDetector, así que cambiar la forma en el editor no tenía efecto.

2026-10-09: la fuente única es la forma (radio 6 m, visible como gizmo en el editor). Se borró el export y `_set_range`; `targeting_range` quedó como getter de solo lectura. Test `test_range_is_the_detector_radius`.

### 10.13 Refactor de código de UI innecesario · Hecho

**Prioridad:** media · **Etiquetas:** `ui`

- [x] MenuItem sin script: ▶ por ícono del tema
  MenuItem/icons/icon = textura ▶, icon_normal_color/hover alpha 0, icon_focus_color dorado. Borrar label/_refresh y usar text directo; adaptar escenas y tests que usan .label.
- [x] Revisar el resto de scripts de UI por lo mismo
  Candidatos: SlotCard._paint (variaciones según foco/vacía), pestañas de la pausa (TabLabel/TabLabelSelected), HintBar, ConfirmDialog, modulate de fichas.
- [x] Suite verde y capturas sin cambios visuales

**Notas:** Código que reemplaza algo que el tema ya resuelve. MenuItem quedó sin script: ▶ = MenuItem/icons/icon con icon_normal_color alpha 0 e icon_focus/hover dorados; hover se ve como foco. Revisado el resto: SlotCard (vacía/llena), pestañas y modos de FileSelect dependen de estado, no de foco; se quitó slot.text = "" en Equipo y el botón DEBUG pasó a la variación DebugButton.

### 10.14 Cámara: sala entera y pared sur recortada · Hecho

**Prioridad:** alta · **Etiquetas:** `camara`

- [x] Alejar la cámara para que entre una sala de 22 × 14 m
- [x] Recortar la pared sur con un shader de corte
- [x] Capturas, tests y GDD

**Notas:** offset (0, 17.4, 10.0): vista ≈ 26 × 14.5 m. data/kits/shaders/cutaway.gdshader en wall.tres y column.tres; la cámara pasa cut_area/cut_height al entrar a cada sala.

### 10.15 Interruptores de piso: solo un bloque los resuelve · Hecho

**Prioridad:** media · **Etiquetas:** `puzzles`

- [x] Modo BLOCK en FloorSwitch: el player sostiene, el bloque resuelve
- [x] Gate.stays_open y close(); temple: Vestíbulo y Puzzle en BLOCK
- [x] Tests, prueba en el templo y GDD

**Notas:** ONCE sigue disponible (overworld y mazmorra gris lo usan); se elige por puzzle.

### 10.16 Mostrar con la cámara lo que activa un interruptor · Hecho

**Prioridad:** media · **Etiquetas:** `camara`, `puzzles`

- [x] TopDownCamera.reveal: pausa, se acerca, abre, vuelve
- [x] reveal_on_open opcional en Door y Gate (solo la primera vez)
- [x] Sin reveal al cargar partida; tests, captura y GDD

### 10.17 Enemigos quietos en el overworld · Hecho

**Prioridad:** alta · **Etiquetas:** `ia`

- [x] Visión 12 m por la cámara más amplia
- [x] Skeleton2 fuera del cerco y test de enemigos encimados
- [x] path_desired_distance 1.0 por la navmesh a 0.5 m

### 10.18 Idiomas: inglés y español · Pendiente

**Prioridad:** media · **Etiquetas:** `ui`

- [ ] Sistema de traducción con TranslationServer
  Archivo de traducciones (CSV o .po) con es y en; los textos se piden por clave con tr(). Por ahora solo esos dos idiomas, pero que sumar otro sea agregar una columna o archivo.
- [ ] Pasar todos los textos a claves
  UI, menús, HUD, carteles, diálogos, nombres y descripciones de ítems (data/), item get, game over. Nada de texto suelto en escenas ni scripts.
- [ ] Elegir idioma la primera vez que se abre el juego
  Pantalla (escena .tscn en el MenuStack) antes del título, solo si settings.cfg no tiene idioma. Arranca preseleccionado el idioma del sistema (OS.get_locale_language) si es es o en. Hace falta su mockup en el canvas de UI.
- [ ] Idioma en Opciones
  Selector en OptionsPanel (título y pausa), guardado en user://settings.cfg con Settings; cambia en vivo sin reiniciar.

**Prueba:** Borrar settings.cfg y abrir el juego: pide idioma antes del título. Elegir inglés: todo el juego (menús, HUD, ítems, diálogos) en inglés. Cambiar a español desde Opciones en la pausa: cambia al instante y se mantiene al reiniciar. Un test recorre las claves y falla si alguna falta en algún idioma.

**Notas:** Skills: `disciplines:game-ui-ux`, `disciplines:dialogue-systems` (hooks de localización).

**Referencias:** `gdd.md#ui`

**Bloqueada por:** 10.4 Opciones

### 10.19 Final y créditos de verdad · Pendiente

**Prioridad:** media · **Etiquetas:** `ui`

- [ ] Revisar el final actual
  Pantalla Ending (src/ui/menus/ending.tscn): hoy es FIN + créditos placeholder sin mockup. Ver qué se siente al terminar el jefe y qué falta (ritmo, epílogo, cierre del doom).
- [ ] Mockup de final y créditos en el canvas de UI
- [ ] Créditos reales
  Autoría, herramientas (Godot, Blender, LimboAI), assets de terceros con sus licencias (sale de compass/lists/assets-de-audio y los kits que queden), agradecimientos. Que se puedan pasar/acelerar.
- [ ] Breve epílogo antes de los créditos
  Cámara sobre el templo calmado o el overworld sin doom; corto y salteable.

**Prueba:** Ganar desde pre_boss: epílogo, créditos completos con todas las licencias, se pueden acelerar/saltear y vuelve al flujo de siempre (seguir explorando o título).

**Referencias:** `gdd.md#jefe`, `gdd.md#ui`

**Relacionadas:** 10.20 Intro / cutscene de apertura; 11.29 Overworld después del jefe

### 10.20 Intro / cutscene de apertura · Pendiente

**Prioridad:** media · **Etiquetas:** `camara`

- [ ] Guion corto de la intro
  Según la historia del GDD (El Ojo despierta, opción A): sin diálogos, se cuenta con imagen y alguna tablilla/texto breve. Decidir duración (30–60 s) y planos.
- [ ] Sistema simple de cutscenes
  Secuencia de planos de cámara, esperas, textos y eventos (AnimationPlayer o una lista de pasos), reutilizable para la intro del jefe y el epílogo de 10.19. Salteable con aceptar.
- [ ] Armar la intro
  Al empezar partida nueva, antes de darle el control al player. Solo la primera vez (flag en la partida); opción de volver a verla no hace falta.

**Prueba:** Partida nueva: corre la intro, se puede saltear, termina dando el control al player en el overworld. Cargar la partida: no se repite.

**Referencias:** `gdd.md#historia`

**Relacionadas:** 10.19 Final y créditos de verdad; 11.22 Tablillas de historia

### 10.21 Título y ranuras: Continuar, Nueva partida y ranura de autosave · Hecho

**Prioridad:** alta · **Etiquetas:** `ui`

- [x] Continuar carga directo la última partida
  Hoy los dos abren FileSelect (title_screen.gd) y solo cambia el slot preseleccionado. Continuar tiene que llamar SaveManager.load_game(latest_slot()) sin pasar por la selección.
- [x] Nueva partida elige dónde crearla
  Abre FileSelect en modo nueva partida: slots vacíos crean partida; elegir uno ocupado pide confirmar que se sobrescribe (ConfirmDialog). Si no hay ninguna partida, va directo al primer slot.
- [x] Revisar el mockup Main/FileSelect
  Que el flujo coincida con el canvas de UI; si el mockup no lo cubre, ajustarlo.
- [x] Ranura 0: último autosave / guardado rápido
  Hoy SLOTS = 3 (0–2) y autosave() escribe en la ranura de la partida en curso. Pasa a: ranura 0 = 'Auto', siempre la última partida guardada sola (autosave o rápido), sin importar de qué ranura venga; ranuras 1–3 = guardados del jugador (Guardar en la pausa). La 0 no se elige para Nueva partida ni se sobrescribe a mano; se puede cargar desde FileSelect y Continuar la usa si es la más reciente.
- [x] Migrar las partidas existentes
  slot_0..2.cfg pasan a slot_1..3.cfg al arrancar (una sola vez), para no perder lo guardado.
- [x] Mostrar la ranura Auto en FileSelect
  Tarjeta propia arriba (etiqueta 'Auto' o 'Último guardado'), distinta de las otras tres; mockup en el canvas de UI.

**Prueba:** Con partidas guardadas: Continuar entra directo a la última jugada (auto o manual). Nueva partida: elegir un slot vacío arranca de cero; uno ocupado pide confirmación y, si se cancela, no toca la partida. Jugar, dejar que autoguarde: la ranura Auto se actualiza y las manuales no cambian hasta guardar a mano. Partidas viejas siguen apareciendo tras la migración.

**Notas:** Implementado: Auto en la ranura 0, migración 0–2 → 1–3, Continuar directo, Cargar partida (opción nueva en el título) y Nueva partida que elige dónde. Mockups Main (Cargar partida) y FileSelect (tarjeta Auto) publicados en el canvas el 2026-10-10.

**Relacionadas:** 10.2 Selección de partida y autosave

### 10.22 Build web · Pendiente

**Prioridad:** media · **Etiquetas:** `build`

- [ ] Preset Web
  Exporta con el renderer Compatibility (rendering_method.web = gl_compatibility); 'Extensions Support' encendido para cargar LimboAI (GDExtension), sin threads para que corra en itch sin COOP/COEP. Agregarlo a tools/build.sh.
- [ ] LimboAI para web
  liblimboai.web.template_release.wasm32.nothreads.wasm compilado con emscripten (la versión que pide limboai.gdextension); probar que los BT del jefe y los enemigos corren.
- [ ] Revisar el juego en Compatibility
  El escritorio usa Forward+: comparar el cutaway del templo, la emisión de la paleta, tonemap, niebla/doom, sombras y las cáusticas (projector + DrawableTexture). Lo que no ande, un fallback para web.
- [ ] Navegador
  Guardado en user:// (IndexedDB) persiste al recargar; el audio arranca tras el primer clic; gamepad y teclado; pantalla completa; tamaño del .pck y tiempo de carga.
- [ ] Publicar en itch
  Proyecto HTML embebido (tamaño 1280×720, botón de pantalla completa), junto a los builds de escritorio de 10.10.

**Prueba:** Abrir el build en Chrome y Firefox desde itch: carga en un tiempo razonable, se juega el overworld y el templo hasta el jefe con gamepad y teclado, el guardado sobrevive a recargar la página y se ve parecido al build de escritorio.

**Notas:** Skills: `godot:godot-export`.

**Relacionadas:** 10.9 Build para playtesters; 10.10 Publicar en itch.io y playtest

## M11 — Pulido: assets y contenido  (20/50)

Vestir el templo y el overworld con KayKit, más enemigos, trampas, un doom legible y los detalles técnicos de la revisión del 2026-10-09.

**Hecho cuando:**
- Ninguna sala ni zona se ve de prototipo o vacía.
- El player y lo interactivo se leen bien con el doom.

### 11.1 Importar KayKit Dungeon Remastered y Medieval · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`

- [x] Bajar de GitHub e importar (modelos, texturas y licencia)

### 11.2 Kit del templo con piezas KayKit · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`

- [x] Generador tools/build_temple_kit.gd → data/kits/temple_kit.tres (mismos ítems/colisiones que gray_kit)
- [x] Shader cutaway con use_uv + materiales kaykit_stone/kaykit_floor y atlas compartido
- [x] Templo usa el kit nuevo con 4 variantes de piso (~15 % de celdas)
- [x] Suite completa (181, solo falla el test conocido de player.tscn) y capturas de las 9 salas
- [x] GDD §10.1 actualizado

**Notas:** Paredes con wall_half estiradas a 3.1 m de alto; columna pillar escalada. El overworld sigue con el kit gris. Las esquinas entre la columna y la pared dejan ver el vacío (rojo con el doom); se puede tapar en 11.3.

### 11.3 Decorar las salas del templo · Pendiente

**Prioridad:** alta · **Etiquetas:** `arte`

### 11.4 Decorar el overworld · Pendiente

**Prioridad:** alta · **Etiquetas:** `arte`

**Relacionadas:** 12.2 Terreno del overworld

### 11.5 Galería de trampas: pinchos · Pendiente

**Prioridad:** media · **Etiquetas:** `mazmorra`

### 11.6 Más enemigos en el overworld y el templo · Hecho

**Prioridad:** alta · **Etiquetas:** `ia`

### 11.7 Doom legible: player y objetos sin teñir · Hecho

**Prioridad:** media · **Etiquetas:** `arte`

- [x] Capa visual legible
  Player y objetos en la capa 2; el sol rojo no la ilumina pero sí le deja proyectar sombra.
- [x] Luz neutra para lo legible
  LegibleLight: misma dirección que el sol, color calmo, solo la capa 2.
- [x] Sin niebla ni grietas sobre lo legible
  Copias de material con disable_fog (también lo que viste el equipo); las grietas excluyen la capa.

**Prueba:** En la antesala (doom 0.9), el player, la tablilla y las vasijas conservan sus colores sobre el piso rojo y siguen proyectando sombra.

### 11.8 Silueta del player detrás de paredes · Hecho

**Prioridad:** media · **Etiquetas:** `camara`

**Notas:** Overlay por stencil: hit_flash escribe el stencil donde el player se ve y occluded_silhouette (sin depth test) pinta en dorado solo donde no. Revisado detrás del jefe y bajo la máscara de la puerta norte del Hub. Test test_silhouette_only_on_the_player.

### 11.9 Navmesh sobre el piso · Pendiente

**Prioridad:** baja · **Etiquetas:** `ia`

### 11.10 Warning de transform singular en la suite · Hecho

**Prioridad:** baja · **Etiquetas:** `tecnico`

**Notas:** 2026-10-09: eran los StaticBody de los dos escudos del player. El AnimationTree arrancaba inactivo (se activaba al entrar a Idle) y, desde la segunda carga de escena, el primer cuadro fundía desde una pose con escala 0: la mano quedaba con escala cero y Jolt avisaba. Arreglo: el AnimationTree arranca activo en player.tscn. La suite quedó sin ningún aviso de transform singular.

### 11.11 HUD sin slots vacíos y reveal dentro de la sala · Hecho

**Prioridad:** baja · **Etiquetas:** `ui`

- [x] Ocultar los slots X/Y sin ítem asignado
  Se oculta el Body; el slot guarda su lugar para que el otro botón no se corra.
- [x] Acotar el acercamiento del reveal a la sala
  TopDownCamera.reveal_focus: Room.clamp_focus con la vista escalada por reveal_zoom.

**Prueba:** Nueva partida: el HUD no muestra los slots X/Y hasta asignarles un ítem. Al pisar un interruptor con reveal, el acercamiento no muestra nada fuera de la sala.

### 11.12 Tamaños de sala variados · Pendiente

**Prioridad:** baja · **Etiquetas:** `mazmorra`

### 11.13 Modelos KayKit: esqueletos para los enemigos y Knight para el player · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`, `personajes`

- [x] Pack Skeletons reducido a assets/kaykit_skeletons (gltf/glb + textura + licencia); el Adventurers nuevo es idéntico a assets/kaykit_adventure
- [x] tools/build_character_models.gd → escenas Visuals en src/entities/models (Minion, Warrior, Rogue, Mage, Knight)
- [x] enemy.tscn con Minion, shield_skeleton con Warrior vía EntityConfig.model, player con Knight
- [x] Suite completa (182, solo el fallo conocido) y capturas de cerca y en el templo
- [x] GDD §10.1

**Notas:** Las animaciones de los packs nuevos (General, MovementBasic) son idénticas a las de kaykit_charanim: no hay nada extra. Los binds handslot.l/r pasan a hand.l/r porque el rig del proyecto no tiene esos huesos.

### 11.14 Puertas con interruptor cerradas al cargar partida · Hecho

**Prioridad:** alta · **Etiquetas:** `bug`, `guardado`

- [x] Wiring emite settled al frame siguiente; Door/Gate/Bridge toman de ahí el estado inicial
- [x] EyeSwitch avisa activated cuando su flag se restaura en la misma escena
- [x] Test de regresión con pre_boss (falla sin el arreglo) y suite completa: 182, solo el fallo conocido

**Notas:** HubSeal está antes que PuzzleEye en temple.tscn: al cargar leía el ojo antes de que restaurara su flag y quedaba cerrado. Afectaba a cualquier puerta/reja/puente cuyo interruptor esté después en el árbol.

### 11.15 Íconos de ítems y equipo renderizados desde los modelos 3D · Hecho

**Prioridad:** media · **Etiquetas:** `ui`, `arte`

- [x] tools/render_item_icons.gd: PNG 256 px con contorno, 14 ítems; mapa, brújula y corazón siguen en SVG
- [x] Escudos de Adventurers: madera = shield_round, espejo = shield_square cromado (también en la mano y el esqueleto)
- [x] Arco de Adventurers con cuerda; bolsa de bombas = tres bombas
- [x] Armaduras: shader palette_remap; la cota pasa el metal del Knight a dorado (player, preview e ícono)
- [x] HUD de llaves con los PNG; SVG viejos borrados
- [x] Suite completa y capturas (HUD, Equipo, Ítems, item get, escudos, cota)
- [x] GDD §6 y §10.1

**Notas:** Los íconos se regeneran con godot --path . --script res://tools/render_item_icons.gd y después hay que importar (editor o --import con el editor cerrado). El escudo de madera también cambió en la mano y en el esqueleto.

### 11.16 Letra de los prompts de input legible sobre cualquier fondo · Hecho

**Prioridad:** alta · **Etiquetas:** `ui`, `bug`

- [x] InputPrompts rellena con #0b0d10 lo calado de cada SVG (flood fill desde el borde, caché por ruta)
- [x] Capturas de HUD y pestañas de la pausa
- [x] Suite completa
- [x] GDD §10.1 (UI)

### 11.17 Pausa: páginas en un TabContainer y títulos en un TabBar · Hecho

**Prioridad:** baja · **Etiquetas:** `ui`

- [x] Pages → TabContainer sin barra; Tabs → TabBar con variación PauseTabBar (reemplaza TabLabel/TabLabelSelected)
- [x] Clic en una pestaña cambia la página (test nuevo en test_map)
- [x] Capturas: igual que antes
- [x] Suite completa
- [x] GDD §9

### 11.18 Pared sur del templo: lámina de ladrillos sin colisión tapando la puerta sur · Hecho

**Prioridad:** alta · **Etiquetas:** `bug`, `camara`

- [x] Encontrar qué dibuja las franjas
  Los ladrillos de la pared propia sobresalen ~7 cm de la celda; el corte empezaba 5 cm dentro de la sala y quedaba una lámina de 2 cm a toda altura.
- [x] Empezar el corte 0.3 m dentro de la sala
  TopDownCamera.SOUTH_WALL_RELIEF; test test_south_wall_cut_covers_the_brick_relief.

**Prueba:** En cualquier sala del templo, la pared sur queda como un zócalo bajo, sin franjas ni sombras de ladrillos, y la puerta sur se ve.

### 11.19 Pasos de puerta laterales del templo: losa del alto de la pared sin colisión · Hecho

**Prioridad:** alta · **Etiquetas:** `bug`, `mazmorra`

**Notas:** Reportado por Daniel el 2026-10-09 (captura). Causa: las dos puertas laterales del templo, la (6, 24) y la (18, 24), tenían la pieza Puerta con orientación 0; el marco (3,1 m de alto, solo colisión de piso) quedaba cruzado en el paso. Se giraron 90° (orientación 16) y test_doorways_face_their_wall valida que cada marco siga a su pared.

### 11.20 Cueva con ojo de agua y cáusticas animadas · Pendiente

**Prioridad:** baja · **Etiquetas:** `arte`, `overworld`

- [ ] Decidir qué hay en la cueva
  Abierto: recompensa, secreto, tablilla de historia, pieza de corazón, un ítem… Definirlo antes de diseñar la sala, y anotarlo en el GDD.
- [ ] Entrada en el overworld y la sala de la cueva
  Cueva chica, una o dos salas; piezas propias en Blender (roca, estalactitas, cristales) en estilo Altiplano del Ojo.
- [ ] Shader de agua propio (water.gdshader)
  Base: la idea de espuma procedural de 'Wind Waker Water' (NekotoArts, godotshaders.com, CC0, Godot 3) reescrita para 4.x y nuestro estilo: colores de la franja agua de la paleta y el tinte 0.72 de epiphany.tres; transparente con color según profundidad (depth texture), así se ve el fondo y las cáusticas; espuma en la orilla por profundidad; manchas de espuma con borde duro en coordenadas de mundo (sin costuras entre tiles); olas de vértice opcionales y apagadas en pozos chicos, con normales planas por cara para mantener el facetado.
- [ ] Cáusticas: DrawableTexture2D + shader texture_blit como light_projector
  Como en ../caustics_demo (probado en 4.8-dev7): un SpotLight3D sobre el agua con sombra (CausticsProjector) regenera cada frame una DrawableTexture2D con blit_rect usando un material shader_type texture_blit, y la usa como light_projector; el PR #115653 hace que el atlas actualice solo esa región. Es luz, no pintura: respeta sombras (columnas, el player) y se suma a la iluminación. Atenuación radial para no ver el borde del projector. Limitación de dev7: texture_blit no compila con global uniform; los parámetros se copian a mano (set_wave_param). Medir el costo del blit y de la sombra del spot.
- [ ] Luz y ambiente de la cueva
  Penumbra, el agua como fuente de luz suave que tiñe las cáusticas; sonido de goteo.
- [ ] Agua y cáusticas del mismo patrón
  Como la variante Wind Waker de la demo: un .gdshaderinc con el patrón (wind_waker_pattern) lo incluyen el agua (spatial) y las cáusticas (texture_blit), así la espuma de la superficie y la luz del fondo se mueven juntas. Pasar el patrón a coordenadas de mundo (la demo usa el UV del mesh, con mesh_center/mesh_size). El agua es transparente y no recibe las cáusticas (o con cast_shadow apagado como en la demo); el fondo y las paredes cercanas sí. Un nodo WaterPool arma superficie + projector y expone tamaño y profundidad. Decal animado solo si el spot resulta caro.

**Prueba:** Entrar a la cueva desde el overworld: a través del agua se ve el fondo con cáusticas que se mueven al mismo ritmo que el brillo de la superficie, hay espuma en la orilla, sin costuras, cortes ni parpadeos; el estilo combina con el resto (paleta, facetado); el rendimiento no cae respecto del overworld.

**Notas:** Skills: `disciplines:level-design`, `godot:godot-shaders`, `godot:godot-3d-essentials`. PR: https://github.com/godotengine/godot/pull/115653. Prototipo propio: /home/drod/Proyectos/Godot/caustics_demo (5 aguas comparadas, cada una con sus cáusticas; tecla 5 = Wind Waker).

**Referencias:** `gdd.md#overworld`, `gdd.md#arte`

**Relacionadas:** 11.23 Vertiente de la cueva: agua bendita

### 11.21 Piezas de corazón · Hecho

**Prioridad:** media · **Etiquetas:** `items`, `overworld`

- [x] Ítem pieza de corazón
  4 piezas = 1 contenedor; contador en la pantalla de equipo; item get distinto para la 4ª.
- [x] Esconder 4–6 en el overworld
  Detrás de muros agrietados, arriba de andenes, en un puzzle chico, en la cueva del agua.

**Prueba:** Juntar 4 piezas: suma un corazón. El contador se guarda y se ve en equipo.

### 11.22 Tablillas de historia · Hecho

**Prioridad:** media · **Etiquetas:** `historia`, `overworld`

- [x] Escribir 6–8 textos cortos
  Cuentan 'El Ojo despierta' (GDD §3, opción A) en orden suelto; uno o dos dan pistas de secretos.
- [x] Repartirlas en overworld y templo
  Con la tablilla existente; cada una con flag de leída.

**Prueba:** Leer todas las tablillas cuenta la historia completa sin contradicciones; las pistas llevan a un secreto real.

**Referencias:** `gdd.md#historia`

**Relacionadas:** 10.20 Intro / cutscene de apertura; 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker)

### 11.23 Vertiente de la cueva: agua bendita · Pendiente

**Prioridad:** media · **Etiquetas:** `items`, `overworld`

- [ ] Interactuar con el agua llena la botella
  Agua bendita: cura más que la poción (o cura y quita doom un rato).
- [ ] Recargable
  Se puede volver a llenar; da razón para volver a la cueva.

**Prueba:** Con la botella vacía, interactuar con la vertiente: se llena; usarla cura según lo definido.

**Relacionadas:** 11.20 Cueva con ojo de agua y cáusticas animadas

### 11.24 Más secretos en el overworld · Pendiente

**Prioridad:** baja · **Etiquetas:** `overworld`, `puzzles`

- [ ] Lista de 4–6 secretos chicos
  Cuevitas con cofre, pasto que esconde algo, roca que se empuja, muro agrietado extra.
- [ ] Armarlos
  Recompensas: flechas, bombas, piezas de corazón.

**Prueba:** Cada secreto se encuentra con las herramientas que el player tiene en ese momento y queda resuelto al cargar.

### 11.25 Nuevos enemigos con los modelos existentes · Pendiente

**Prioridad:** media · **Etiquetas:** `enemigos`, `ia`

- [x] Arquero chullpa
  Dispara de lejos; se bloquea con el escudo y se refleja con el espejo.
- [ ] Enemigo con punto débil
  Solo por la espalda o solo con bombas.
- [x] Esqueleto arquero
  Pedido: esqueletos que disparen flechas. Mantiene distancia, telegraph con el tensado, la flecha se bloquea con el escudo.

**Prueba:** Los dos enemigos aparecen en overworld o templo, se leen sus telegraphs y tienen contra clara.

### 11.26 Prueba de combate opcional · Pendiente

**Prioridad:** baja · **Etiquetas:** `combate`

- [ ] Sala de oleadas
  3 oleadas mezclando enemigos; la puerta se cierra hasta terminar.
- [ ] Recompensa
  Cota reforzada, carcaj o pieza de corazón.

**Prueba:** Entrar, sobrevivir las 3 oleadas, la puerta abre y aparece la recompensa; no se repite al cargar.

### 11.27 Mini-santuario de reflejos · Pendiente

**Prioridad:** baja · **Etiquetas:** `mazmorra`, `puzzles`

- [ ] Diseñar 3–4 salas
  Todo con el escudo espejo: haces de luz, ojos-interruptor, espejos que giran.
- [ ] Recompensa al final

**Prueba:** Se completa solo con el escudo espejo; cada sala enseña una variante del reflejo.

### 11.28 Atajos que se abren al volver · Pendiente

**Prioridad:** baja · **Etiquetas:** `overworld`

- [ ] Uno o dos atajos de vuelta
  Puente o escalera que se despliega desde el lado de adentro; flag persistente.

**Prueba:** Abrir el atajo desde adentro: queda abierto y acorta el recorrido al templo.

### 11.29 Overworld después del jefe · Pendiente

**Prioridad:** baja · **Etiquetas:** `overworld`, `audio`

- [ ] Sin doom
  Luz, niebla y música calmas tras d1_boss_defeated.
- [ ] Algo nuevo accesible
  Una zona o secreto que solo aparece después.

**Prueba:** Vencer al jefe y salir: el overworld se ve y suena distinto, y hay algo nuevo para encontrar.

**Relacionadas:** 10.19 Final y créditos de verdad

### 11.30 Ítem post-MVP: gancho o telequinesis · Pendiente

**Prioridad:** baja · **Etiquetas:** `items`

- [ ] Elegir el ítem
  Gancho, o algo que mueva objetos a distancia (aprovecha la física). GDD §6.1 post-MVP.
- [ ] Comportamiento y puzzles
  ItemBehavior nuevo + 2–3 usos en el mundo.

**Prueba:** El ítem tiene un uso en combate y abre al menos dos lugares que antes no se podían.

**Referencias:** `gdd.md#items-mvp`

### 11.31 Sub-jefe del templo · Pendiente

**Prioridad:** baja · **Etiquetas:** `jefe`, `enemigos`

- [ ] Chullpa guardián gigante
  Custodia el arco a mitad del templo; patrón propio, una sola fase.
- [ ] Sala y recompensa
  Al vencerlo aparece el cofre del arco.

**Prueba:** Llegar al sub-jefe, vencerlo con espada y escudo, y obtener el arco; al cargar no reaparece.

### 11.32 Modo difícil o contrarreloj · Pendiente

**Prioridad:** baja · **Etiquetas:** `rejugabilidad`

- [ ] Elegir uno
  Difícil: más daño y menos drops. Contrarreloj: tiempo total al final.
- [ ] Desbloquear al terminar

**Prueba:** Tras los créditos aparece la opción; una partida en ese modo cambia lo prometido.

### 11.33 Combate: sacar lo tosco · Revisión

**Prioridad:** alta · **Etiquetas:** `combate`

- [ ] Diagnóstico jugando
  Grabar y anotar qué se siente mal. Sospechas del código: un solo tajo (sword_slash.tres sin ventanas afinadas), el estado Attacking frena con un tween de 0.3 s y espera el fade_out entero para soltar el control (no se puede cancelar ni encadenar), sin avance en el golpe, feel.tres sin valores.
- [x] Respuesta y cancelación
  El tajo sale en el primer frame posible; ventana de cancelación al final (rodar, bloquear, siguiente golpe) con input buffer; giro hacia el stick o el objetivo fijado al iniciar el golpe.
- [x] Impacto
  Hit-stop corto (40–80 ms), knockback según el golpe, flash, chispas, sacudida chica, sonido por superficie; pequeño avance (lunge) al pegar.
- [x] Enemigos que se leen
  Telegraphs más claros (pausa + brillo antes del golpe), ventanas de recuperación, reacción al golpe (stagger) consistente.
- [x] Afinar feel.tres y AttackData
  Valores en datos, no en código; anotar los finales en el GDD §5.

**Prueba:** Pelear contra 3 chullpas en el overworld: cada golpe responde al instante, se puede rodar o bloquear al final de un tajo, los impactos se sienten, y en una sesión de playtest nadie lo describe como tosco.

**Notas:** Skills: `disciplines:game-feel`, `disciplines:input-systems`, `godot:godot-animation`. Hecho: cancel_from/lunge en AttackData, golpe encadenable (Attacking→Attacking), giro al objetivo o stick, chispas al pegar, aviso rojo (HitFlash.warn) y recovery_time 0,4 s en BTAttack, feel.tres con valores. Falta jugarlo (paso 1) y el sonido por superficie.

**Referencias:** `gdd.md#combate`

**Bloquea a:** 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker)

**Relacionadas:** 11.49 VFX de combate

### 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker) · Pendiente

**Prioridad:** media · **Etiquetas:** `combate`

- [ ] Combo de 3 golpes
  Tajo, revés y estocada encadenados con el buffer; el tercero hace más daño y empuja. Animaciones de Rig_Medium (CombatMelee).
- [ ] Ataque giratorio cargado
  Mantener ataque: la espada brilla (neón), al soltar gira 360°. Versión grande al cargar más (Great Spin).
- [ ] Contraataque (parry de Wind Waker)
  Cuando un enemigo telegrafía, aparece un prompt corto: al apretarlo, el player salta por encima o rodea y pega por la espalda. Sirve también con las manos del jefe.
- [ ] Técnicas extra a elegir
  Estocada en carrera (dash attack), salto con golpe (jump strike), rayo de espada con la vida llena (Minish Cap). Elegir 1–2 para la demo.
- [ ] Cómo se aprenden
  Como los pergaminos de Minish Cap: algunas técnicas se enseñan en tablillas/santuarios del overworld (cruza con 11.22 y 11.24); el combo y el giro desde el inicio. Mostrarlas en la pantalla de equipo.
- [ ] Input y tutorial
  Que no choquen con lock-on, bloqueo y rodar; prompt la primera vez que se aprende cada una; anotar en el mapa de input del GDD §4.3.

**Prueba:** Con el combate pulido (11.33): encadenar el combo de 3, cargar y soltar el giro, contraatacar a un chullpa en su telegraph y usar una técnica aprendida en una tablilla; ninguna se dispara sin querer al rodar, bloquear o fijar.

**Notas:** Skills: `disciplines:game-feel`, `disciplines:input-systems`, `godot:godot-animation`.

**Referencias:** `gdd.md#combate`, `gdd.md#input`

**Bloqueada por:** 11.33 Combate: sacar lo tosco

**Relacionadas:** 11.22 Tablillas de historia; 11.35 Saltar: ítem tipo Pluma de Roc

### 11.35 Saltar: ítem tipo Pluma de Roc · Pendiente

**Prioridad:** media · **Etiquetas:** `combate`, `movimiento`

- [x] Decidido: ítem tipo Pluma de Roc
  Nada de salto libre ni automático: se salta con un ítem que se consigue (Minish Cap), así el gating de saltos empieza cuando lo tenés. Anotado en GDD §4.2.
- [ ] Estado Jumping en el player
  Arco con altura fija, control en el aire limitado, sombra en el piso para leer dónde cae (la cámara es cenital), aterrizaje con polvo; animaciones de Rig_Medium.
- [ ] Integración con combate
  Saltar esquiva golpes bajos (ondas de choque de las manos del jefe); golpe en el aire / caída con la espada (jump strike de 11.34).
- [ ] Integración con el mundo
  Huecos de un tile, subir a andenes bajos, bajar de cualquier borde; revisar que no rompa puzzles ni salte paredes de sala (alto máximo menor que pircas y muros).
- [ ] Ítem y input
  ItemData + ItemBehavior de la pluma; se asigna a un botón de ítem como el arco o las bombas (sin botón propio). Ícono renderizado desde un modelo propio (build_equipo.py).
- [ ] Dónde se consigue y qué abre
  Elegir el lugar (cofre en el overworld, mini-santuario 11.27, sub-jefe 11.31…) y armar 2–3 lugares que solo se alcanzan saltando, más una pieza de corazón (11.21). Actualizar la progresión del GDD §6.2.

**Prueba:** Sin la pluma no se puede saltar. Con la pluma asignada: saltar un hueco de un tile y subir a un andén bajo; la sombra deja ver dónde cae. No se puede saltar una pirca ni un muro de sala. Saltar esquiva la onda de choque del golpe de las manos del jefe.

**Notas:** Skills: `godot:godot-physics`, `disciplines:game-feel`, `disciplines:level-design`.

**Referencias:** `gdd.md#input`, `gdd.md#movimiento-combate`, `gdd.md#items-mvp`

**Relacionadas:** 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker)

### 11.36 Mapa: más información y navegable · Hecho

**Prioridad:** media · **Etiquetas:** `ui`

- [x] Overworld con niebla de exploración
  Hoy es una foto cenital fija con el marcador. Las zonas (AreaZone) se destapan al visitarlas; las no vistas quedan en sombra con su contorno.
- [x] Marcas en el mapa
  Mazmorra: puertas (con llave, jefe, selladas), cofres abiertos/cerrados, salas sin terminar, escaleras. Overworld: entradas a cuevas/templo, santuarios, tablillas leídas, cofres encontrados. Leyenda (map_legend_icon) acorde.
- [x] Zoom, paneo y cursor
  Mover un cursor con el stick/mouse sobre el mapa; al pasar sobre una sala o zona muestra su nombre y qué falta (cofres, piezas de corazón).
- [x] Pines propios
  Opcional: el jugador pone 2–4 marcas para acordarse de algo (muro sospechoso, lugar alto para la pluma). Se guardan en la partida.
- [x] Mockup de la pestaña Mapa actualizado
  En el canvas de UI, antes de construir.

**Prueba:** Partida nueva: el overworld aparece tapado salvo la zona inicial y se va destapando. En el templo, con mapa y brújula, se ven puertas, cofres cerrados y el jefe; con el cursor se lee el nombre de cada sala. Los pines se mantienen al cargar.

**Notas:** Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`.

**Referencias:** `gdd.md#ui`

**Relacionadas:** 11.37 Minimapa en el HUD

### 11.37 Minimapa en el HUD · Pendiente

**Prioridad:** media · **Etiquetas:** `ui`

- [x] Mockup HUD_Minimap
  Esquina libre del HUD (no choca con corazones, ítems ni la barra del jefe); tamaño chico, marco simple bronce.
- [ ] Mazmorra
  Las salas alrededor de la actual (3×3), con puertas y el player con flecha de orientación; usa los mismos datos que la pestaña Mapa (Room.map_cell, DungeonState).
- [ ] Overworld
  Recorte de la foto cenital alrededor del player, con la niebla de 11.36 y las marcas cercanas.
- [ ] Cuándo se ve
  Opción en Opciones (encendido/apagado); se oculta en cutscenes, item get, diálogos y en la sala del jefe.

**Prueba:** Recorrer el templo: el minimapa sigue al player sala a sala y coincide con la pestaña Mapa. En el overworld muestra la zona y se destapa igual. Se apaga desde Opciones y no aparece durante el jefe ni en cutscenes.

**Notas:** Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`. Escena .tscn, nada armado por código.

**Referencias:** `gdd.md#ui`

**Relacionadas:** 11.36 Mapa: más información y navegable

### 11.38 Silueta x-ray con fresnel · Hecho

**Prioridad:** media · **Etiquetas:** `camara`

**Notas:** Pedido por Daniel el 2026-10-10 (godotshaders stencil-based-silhouette y el custom x-ray de apples/godot-stencil-demo): la silueta del player gana fresnel, brilla en los bordes y es más transparente en el centro.

### 11.39 Luces estilo Wind Waker (volúmenes de stencil) · Hecho

**Prioridad:** media · **Etiquetas:** `arte`

- [x] Componente WindWakerLight (escena + shaders propios)
- [x] Ordenar prioridades con la silueta del player
- [x] Ponerla en las antorchas del templo y revisar en capturas

**Notas:** Pedido por Daniel el 2026-10-10, como las Wind Waker lights de apples/godot-stencil-demo (el repo no tiene licencia: se reimplementa la técnica, sin copiar código). Esfera con 3 pasadas de stencil: marcar lo que queda delante, multiplicar color adentro, limpiar; prioridad propia por luz. Cuidar que no pise el stencil de la silueta del player (ref 1). Uso: antorchas del templo.

### 11.40 Agujero en lo que tapa al player · Hecho

**Prioridad:** media · **Etiquetas:** `camara`

- [x] Uniform global con la posición en pantalla y la profundidad del player
- [x] Recorte circular (con borde suave o dither) en los materiales que tapan
- [x] Decidir con Daniel si convive con la silueta o la reemplaza

**Notas:** Pedido por Daniel el 2026-10-10. Decidido: agujero contra paredes, silueta contra objetos; en el borde del mundo, silueta (el agujero mostraba el vacío). Uniform global player_hole desde TopDownCamera; player_hole.gdshaderinc en cutaway.gdshader y epiphany_wall.gdshader; variantes 'borde' del kit del overworld que OverworldMap pone al cargar.

### 11.41 Esqueleto con escudo: bloquear con el escudo delante · Revisión

**Prioridad:** alta · **Etiquetas:** `combate`, `enemigos`

- [x] Pose del escudo al bloquear
  Mismo socket que el player: de frente, 20° hacia afuera, delante de la mano.
- [x] Bloquea cuando de verdad tiene el escudo arriba
  Que el bloqueo coincida con lo que se ve: escudo levantado mirando al player; si no, el golpe entra.
- [x] Se lee el bloqueo
  Chispa y sonido en el escudo, retroceso; capturas desde la cámara del juego.

### 11.42 Arco que se tensa · Revisión

**Prioridad:** media · **Etiquetas:** `items`, `arte`

- [x] Arco con hueso o shape key de tensado (Blender, otra sesión)
  Cuerda que se estira hacia la mano derecha y palas que se doblan.
- [x] Tensado sigue a Ranged_Bow_Draw
  El tensado va de 0 a 1 mientras se mantiene; al soltar vuelve de golpe.
- [x] Flecha en la cuerda mientras se tensa

### 11.43 Bombas: tocar coloca, mantener apunta y tira · Revisión

**Prioridad:** media · **Etiquetas:** `items`

- [x] Tocar: coloca la bomba a los pies como ahora
- [x] Mantener: levanta la bomba y apunta como el arco
  Mira/arco de tiro en el piso; soltar la tira en parábola.
- [x] Mecha sigue corriendo mientras se apunta
- [x] Tests y GDD

### 11.44 Levantar y tirar objetos · En curso

**Prioridad:** alta · **Etiquetas:** `items`, `interaccion`

- [x] Objetos levantables
  Vasijas, piedras, arbustos: componente Liftable con peso.
- [x] Estado Carrying
  Interactuar levanta (anim KayKit), se camina más lento, se tira con el mismo botón o se apoya.
- [x] Tirar: parábola, rompe y daña
  Al chocar se rompe (vasija suelta su loot) y daña enemigos.
- [ ] Puzzles que lo usen
  Piedra sobre placa de presión, vasija para tapar un hueco. Se hace con los mini puzzles de 11.45 (stone.tscn ya aprieta placas).

### 11.45 Tutorial de controles y mini puzzle por ítem · En curso

**Prioridad:** alta · **Etiquetas:** `ui`, `puzzles`

- [ ] Tutorial de controles al empezar
  Carteles/tablitas en el claro del inicio: moverse, atacar, rodar, bloquear, fijar, interactuar; muestra el botón según el dispositivo.
- [ ] Mini puzzle al conseguir cada ítem
  Sala chica justo después del cofre con una tablita que da la pista: arco (ojo/diana), bombas (pared rajada), escudo espejo (rayo), levantar (placa).
- [ ] Tablitas con el ícono del botón
  El texto de la tablita usa los íconos de input actuales.
- [ ] Tests y GDD

### 11.46 Jefe: game juice · Pendiente

**Prioridad:** alta · **Etiquetas:** `jefe`, `feel`

- [ ] Cuerpo vivo
  Balanceo de flotación, inclinación hacia la mano que ataca, parpadeo del propulsor; parpadeos ocasionales, párpados entrecerrados al apuntar.
- [ ] Ojo que carga
  La pupila se dilata y el iris pulsa la emisión (material override por instancia) mientras carga el orbe; la boca de horno respira y se enciende en cada ataque.
- [ ] Anticipación y peso de las manos
  Antes del golpe sube de más, cierra el puño y tiembla; cae más rápido, squash al tocar el piso y rebote chico. Mismo criterio para el agarre y el barrido.
- [ ] Impactos
  Hit-stop (~60 ms) en el golpe al piso y cuando el player le pega (Feel ya lo tiene); grietas que quedan en el piso y piedritas; vibración del control; sacudida direccional; la sombra crece y destella el último instante.
- [ ] Mano aturdida
  Tambaleo mareado, el ojo de neón del dorso titila, chispas.
- [ ] Fases y muerte
  Cambio de fase: párpados que se abren de golpe, destello, polvo del techo. Muerte en etapas: placas que se desprenden, neón que se apaga, explosiones chicas en las juntas, cámara lenta en el último golpe.

**Prueba:** Pelear contra el jefe de punta a punta: cada ataque se anticipa y se lee, los golpes al piso pesan (hit-stop, grietas, vibración), el ojo y el cuerpo reaccionan, y la muerte se siente como un final.

**Notas:** Skills: `disciplines:game-feel`, `godot:godot-animation`, `godot:godot-shaders`.

**Referencias:** `gdd.md#jefe`

**Relacionadas:** 11.47 Manos del jefe con shape keys; 11.50 Audio del jefe

### 11.47 Manos del jefe con shape keys · Pendiente

**Prioridad:** media · **Etiquetas:** `jefe`, `arte`

- [ ] Una malla por mano con blend shapes
  En build_jefe.py, como el arco: base abierta y shape keys «puno» y «garra» (los dedos rotan por falange); reemplaza las tres mallas sueltas.
- [ ] Transiciones en el código
  BossHand interpola los blend shapes en vez de alternar visibilidad (Open/Fist/Claw).

**Prueba:** Los dedos se cierran y abren de forma continua al pasar de una pose a otra; el ícono y la pelea siguen igual.

**Notas:** Skills: `godot:godot-animation`.

**Referencias:** `gdd.md#jefe`

**Relacionadas:** 11.46 Jefe: game juice

### 11.48 Pose de item get · Pendiente

**Prioridad:** media · **Etiquetas:** `personajes`, `feel`

- [ ] Animación
  Las dos manos en alto con el objeto (como Carry, con IK horneado en build_carry_anims.py o un script hermano); entrada y salida cortas.
- [ ] Integración
  La caja de item get muestra al player en la pose con el objeto arriba y un destello; sonido propio.

**Prueba:** Abrir un cofre grande: el player levanta el ítem con las dos manos, se ve el objeto arriba y vuelve a su pose al cerrar la caja.

**Notas:** Skills: `godot:godot-animation`, `disciplines:game-feel`.

### 11.49 VFX de combate · Pendiente

**Prioridad:** media · **Etiquetas:** `feel`, `combate`

- [ ] Estela de la espada
  Trail en el filo durante la ventana de golpe (AttackData), en la paleta (hueso/neón).
- [ ] Partículas en el estilo
  Una sola fuente de partículas low poly con colores de la paleta: chispas al rebotar, polvo al rodar, anillo de carga del giro, estela de la flecha, explosión de bomba estilizada.

**Prueba:** Pelear y usar los ítems: cada acción tiene su efecto, todos con el mismo estilo, y no bajan los FPS con varios enemigos.

**Notas:** Skills: `disciplines:game-feel`, `godot:godot-shaders`. Va con 11.33.

**Referencias:** `gdd.md#combate`

**Relacionadas:** 11.33 Combate: sacar lo tosco

### 11.50 Audio del jefe · Pendiente

**Prioridad:** baja · **Etiquetas:** `jefe`, `audio`

- [ ] Voz propia
  Zumbido mecánico de fondo, chirrido de párpados, carga del orbe, rugido de fase, golpes con más grave.
- [ ] Tema de música
  Reemplazar el placeholder (Music.boss_fight) por un tema propio, con capas por fase.

**Prueba:** La pelea tiene sonido propio y la música cambia con las fases.

**Notas:** Skills: `disciplines:audio-design`, `godot:godot-audio`.

**Referencias:** `gdd.md#jefe`

**Relacionadas:** 11.46 Jefe: game juice

## M12 — Assets propios (Blender)  (2/13)

Rehacer en Blender todos los assets con un mismo estilo, empezando por el overworld, que hoy sigue con el kit gris.

**Hecho cuando:**
- El overworld no usa piezas del kit gris ni de KayKit.
- Templo, interactivos, ítems y personajes comparten la misma paleta y el mismo estilo.

### 12.1 Guía de estilo: paleta, escala y pieza de prueba · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`

- [x] Textura de paleta única con degradés
  Estilo atlas KayKit, con los colores de [[gdd#arte]]: pasto #7aa86b, acantilado #947a61, piedra gris, naranja, madera, dorado, celeste de cristal, violeta del sello, rojo del doom. Un solo material compartido.
- [x] Hoja de escala
  Knight, celda de 2 m, paso de 1 y de 3 celdas, alto de pared.
- [x] Pieza de prueba exportada a Godot
  Pasto y acantilado importan bien con la paleta. Falta probar el corte de la pared sur (cutaway.gdshader con use_uv) con piezas propias: se prueba al armar el kit del templo (12.7).
- [x] Pipeline: .blend directo en assets/epiphany/, referencias fuera de la importación

**Prueba:** Una pieza de prueba importada en Godot se ve con la paleta, a escala del Knight, y se recorta con el shader de la pared sur.

**Notas:** Guía en [[gdd#arte]] (Assets propios). Identidad: Altiplano del Ojo. El corte de la pared sur con piezas propias se prueba en 12.7.

**Referencias:** `gdd.md#arte`

**Bloquea a:** 12.2 Terreno del overworld; 12.3 Lugares del overworld; 12.4 Vegetación y props del overworld; 12.5 Interactivos y pickups; 12.6 Equipo y objetos del inventario; 12.7 Kit del templo propio; 12.8 Personajes propios; 12.9 Efectos con malla

### 12.2 Terreno del overworld · En curso

**Prioridad:** alta · **Etiquetas:** `arte`

- [x] Pasto: base + 3–4 variantes
  Florcitas, piedritas, manchas de tierra.
- [ ] Camino de tierra: recto, curva, T, cruce, final, borde con pasto
- [x] Piso de piedra de la plaza: base + rota + musgo
- [ ] Acantilado: recto, esquina ext/int, final, tope con pasto
- [ ] Aberturas en acantilado de 1 y 3 celdas
  1 celda = gating (muro agrietado o reja), 3 = paso libre. Ver [[gdd#overworld-layout]].
- [ ] Escalones y rampa (tierra y piedra)
- [ ] Abismo: borde recto, esquinas, fondo oscuro/niebla
- [ ] Cerco: recto, esquina, final, poste, roto
- [ ] Borde del mundo (árboles densos / acantilado alto)
- [x] Kit del overworld para el GridMap
  Como build_temple_kit.gd: mismos ítems, colisiones y navegación que el kit gris, mallas nuevas.

**Prueba:** El GridMap del overworld usa solo estas piezas y la navmesh y las colisiones siguen andando.

**Referencias:** `gdd.md#overworld-layout`

**Bloquea a:** 12.3 Lugares del overworld

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.4 Decorar el overworld

### 12.3 Lugares del overworld · En curso

**Prioridad:** alta · **Etiquetas:** `arte`, `puzzles`

- [ ] Hito del claro del inicio
  Piedra tallada, fogata o similar.
- [ ] Kit de cueva: boca, piso y pared de roca, estalagmitas
  Para la cueva de las bombas y la gruta oculta.
- [x] Muro agrietado de exterior + escombros
  Ladrillo gris con musgo, que no se confunda con el acantilado. cracked_wall.tscn.
- [ ] Kit de santuario: piso, paredes, columnas, pedestal
- [x] Puzzle de luz: fuente, espejo fijo 45°, cristal receptor
  src/world/light/.
- [x] Reja, bloque empujable e interruptor de piso de exterior
  gate.tscn, push_block.tscn, floor_switch.tscn.
- [ ] Entrada del templo: fachada, escalinata, columnas
  La pieza más importante del overworld.
- [x] Sello violeta con el ojo
  temple_seal.tscn.
- [ ] Risco del ojo: cornisa, ojo-interruptor, puente, nicho del carcaj
  eye_switch.tscn, bridge.tscn.
- [x] Portal de salida del jefe: disco y anillo
  warp_portal.tscn. Opcional.

**Prueba:** Cada zona de [[gdd#overworld-layout]] tiene sus piezas propias y se reconoce sin el nombre de zona.

**Referencias:** `gdd.md#overworld-layout`

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba; 12.2 Terreno del overworld

### 12.4 Vegetación y props del overworld · En curso

**Prioridad:** alta · **Etiquetas:** `arte`

- [x] Árbol que bloquea celda: grande, chico, grupo para bordes
- [x] Pasto cortable: mata entera, cortada, hojitas
  grass.tscn.
- [x] Vasija: entera y en pedazos
  pot.tscn.
- [x] Roca física y caja física
  physics_rock.tscn, physics_box.tscn.
- [x] Tablilla de piedra del overworld
  tablet.tscn.
- [x] Rocas grandes fijas (2–3)
- [ ] Decoración: arbustos, flores, hongos, tronco caído, tocón
  Opcional.
- [ ] Fondo: nubes y colinas lejanas
  Hoy salen de KayKit Medieval. Opcional.

**Prueba:** Pasto, vasijas, rocas y cajas usan los modelos nuevos y se rompen o mueven como antes.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.5 Interactivos y pickups · En curso

**Prioridad:** media · **Etiquetas:** `arte`

- [x] Cofre chico de madera (tapa aparte)
- [x] Cofre grande dorado (tapa aparte)
- [ ] Pickups: corazón, flechas ×5, bombas ×3
- [x] Bomba con mecha y flecha
- [ ] Orbe (proyectil reflejable)
- [x] Llave chica, llave del jefe
- [x] Mapa, brújula, contenedor de corazón
  Hoy son SVG planos; con modelo, todos los íconos salen de render_item_icons.gd.

**Prueba:** Cofres, pickups, bomba, flecha y orbe usan los modelos nuevos; los íconos se regeneran con render_item_icons.gd.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.6 Equipo y objetos del inventario · Hecho

**Prioridad:** media · **Etiquetas:** `arte`

- [x] Espada(s)
  Según lo que se decida de espadas con elemento.
- [x] Escudo de madera y escudo espejo
- [x] Cota reforzada
  Que la variante dorada siga andando con palette_remap, o modelarla aparte.
- [x] Arco y carcaj grande
- [x] Bolsa de bombas
- [x] Botella vacía y con poción

**Prueba:** Equipo e ítems se ven en la mano, en la preview de Equipo y en los íconos.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.7 Kit del templo propio · En curso

**Prioridad:** baja · **Etiquetas:** `arte`, `mazmorra`

- [x] Piso + variantes (roto, yuyos, grieta del doom)
- [ ] Pared a celda 2×2: recta, esquina, final, con antorcha
- [x] Columna y escalón
- [ ] Abismo interior con borde
- [x] Pasos de puerta + puertas por tipo
  Normal, con cerradura, persiana, de interruptor y del jefe (grande, con el ojo). door.tscn.
- [x] Piezas de puzzle versión templo
  Muro agrietado, reja, bloque, interruptor, ojo-interruptor, cristal, espejo, fuente de luz.
- [x] Torreta / ojo menor
  src/entities/turret/.
- [x] Antorcha de pared y brasero
  wall_torch.tscn.
- [ ] Decoración: estandartes, escombros, vasijas, tablilla, ojo tallado
- [ ] Doom: grietas, venas rojas, polvo
- [x] Sala del jefe: piso de arena y pilares

**Prueba:** temple_kit.tres arma el templo con las piezas nuevas y el corte de la pared sur sigue andando.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.8 Personajes propios · En curso

**Prioridad:** baja · **Etiquetas:** `arte`, `personajes`

- [x] Player
  Mismos nombres de huesos que el Rig_Medium de KayKit, para no perder las animaciones.
- [x] Esqueleto
- [x] Esqueleto con escudo
- [ ] Jefe: ojo + dos manos con rig propio
  El rig de la otra jam no está en el repo. Ver [[gdd#jefe]].

**Prueba:** Los modelos nuevos usan las animaciones de player/animation/libs/ sin retarget.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.9 Efectos con malla · Pendiente

**Prioridad:** baja · **Etiquetas:** `arte`

- [ ] Haz de luz
- [ ] Polvo y hojas
- [ ] Pedazos de vasija y escombros
- [ ] Explosión
- [ ] Anillo del portal

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.10 Pipeline Blender→Godot: glb publicado + plugin de import · Revisión

**Prioridad:** alta · **Etiquetas:** `arte`, `herramientas`

- [x] Plugin de import en addons/epiphany_tools/import
  EditorScenePostImportPlugin: material de paleta por nombre (normal/emisión), guarda mallas en meshes/<fuente>/<pieza>.res (mismas rutas de hoy).
- [x] Custom properties → nodos
  col=box|sphere|capsule → colisión primitiva; socket → Marker3D; spring → cadena de SpringBoneSimulator3D.
- [x] epi publica .glb
  epi.publish(name) guarda el .blend en art/blender/ (art/.gdignore) y exporta assets/epiphany/<name>.glb con extras y sin imágenes; los build_*.py viejos siguen con epi.save hasta 12.11.
- [x] Piloto con el personaje nuevo (12.12)
  Hecho con un blockout skinneado: el .glb trae Skeleton3D con huesos extra, SpringBoneSimulator3D desde la property spring, Marker3D de sockets en los huesos de las manos, y anima con las libs del jugador (AnimationPlayer con root en el nodo padre del Skeleton3D).
- [x] Sufijos de Godot
  Probado -noimp. -navmesh/-occ/-loop son nativos; aplicarlos (p. ej. Carry_Idle-loop) va en la migración 12.11.

**Notas:** Basado en la doc de sufijos de import de Godot y el workflow de Blender Studio (DOGWALK). Los build_*.py guardan el .blend de trabajo y publican un .glb; Godot importa solo el .glb (no necesita Blender para builds/web). Un EditorScenePostImportPlugin reemplaza los scripts headless de extracción.

**Bloquea a:** 12.11 Migrar los .blend al pipeline glb

**Relacionadas:** 12.12 Estilo toon (Wind Waker) + personaje cyber-shinobi

### 12.11 Migrar los .blend al pipeline glb · Pendiente

**Prioridad:** media · **Etiquetas:** `arte`, `herramientas`

- [ ] Props y equipo (objetos, equipo, naturaleza, lugares, jefe)
- [ ] Templo y kits (build_temple_kit / build_overworld_kit)
- [ ] Personajes (jugador, chullpas) y carry
- [ ] Retirar scripts headless viejos y verificar builds sin Blender

**Notas:** Después de validar 12.10: pasar objetos, equipo, lugares, templo, naturaleza, jefe, terreno y personajes a glb; retirar extract_epiphany_meshes y build_character_models; los kits leen del glb.

**Bloqueada por:** 12.10 Pipeline Blender→Godot: glb publicado + plugin de import

### 12.12 Estilo toon (Wind Waker) + personaje cyber-shinobi · En curso

**Prioridad:** media · **Etiquetas:** `arte`, `personajes`

- [x] Prueba de estilo en Blender (estilo_toon.py)
  Hecha: renders en docs/estilo/. El blockout de piezas epi se descartó (se veía cuadrado/viejo; suavizarlo lo volvía un globo).
- [ ] Shader cel en Godot
  Shader propio (light() con corte duro de 2 tonos, sombra de color de la tira oscura de la paleta, rim light opcional para el pelo negro). Probarlo también en el escenario: cambia el look del mundo.
- [ ] Personaje al pipeline glb
  Pasar estilo_toon.py a un build_*.py que use paleta (UV a las tiras en vez de materiales sueltos) y epi.publish; pesos automáticos del cuerpo; huesos spring para mechones laterales, cintas y colas de la faja; sockets de sable y pistola (custom property socket).
- [ ] Cara como textura con expresiones
  Pasar las calcomanías a una textura de cara (o atlas) para cambiar expresión y parpadear, como Wind Waker.
- [ ] Sable de energía y pistola
  Empuñadura + hoja emisiva con trail; pistola simple.
- [ ] Paleta alternativa cyber + emisión
- [ ] Revisar polígonos
  Contar tris del personaje (co-op: hasta 4 en pantalla) y bajar subdivisión o resolución de curvas si hace falta.
- [ ] Render A/B en el templo
  El personaje toon con el shader en el templo actual, contra el jugador de ahora.

**Notas:** Rumbo elegido 2026-10-10: look tipo Wind Waker HD con cel shading (no low-poly de piezas ni anime realista). Proporciones chibi, así que sirve el Rig_Medium y las animaciones de KayKit. Prueba en tools/blender/estilo_toon.py (renders de referencia en docs/estilo/): cuerpo continuo con Skin modifier + subdivisión y pesos automáticos; pelo en mechones de curvas NURBS afinadas con rulo; cara de calcomanías proyectadas (ojo, iris, pupila, brillo, párpado, cejas, rubor, boca); mangas y pollera con pliegues senoidales; cel shading de 2 tonos con sombra de color. Las tiras de la paleta ya tienen tono claro y oscuro: sirven como lit/shade del shader. El setting andino tampoco es definitivo (cyber-shinobi estilo Megaman Zero: sables de energía y pistolas). Diseño: pelo negro con rulos y rodetes con kunais, ojos rojos, capucha y mangas anchas con ribete emisivo, faja roja tipo obi, delantal crema, pollera, medias con liga roja, botas.

**Relacionadas:** 12.10 Pipeline Blender→Godot: glb publicado + plugin de import

### 12.13 Reajuste de estilo toon de todos los assets · Pendiente

**Prioridad:** media · **Etiquetas:** `arte`

- [ ] Shader cel en el material de paleta y recorrida del mundo actual
  Sale de 12.12 paso 2. Capturas de overworld, templo y jefe; lista de qué alcanza con shader y qué hay que remodelar.
- [ ] Ajustar la paleta para sombras de color
  Las tiras ya tienen tono claro y oscuro: llevar el oscuro a sombras saturadas y frías tipo WW, no grises.
- [ ] Vegetación
  Copas en masas redondeadas y blandas, pasto y matas (12.4).
- [ ] Terreno y lugares
  Suavizar bordes y siluetas donde lo pida el shader (12.2, 12.3).
- [ ] Templo y restos de KayKit
  Terminar el kit propio (12.7) y sacar las piezas KayKit dungeon que queden.
- [ ] Personajes: jugador, chullpas y jefe
  Con la técnica de estilo_toon.py, después de validar el shinobi (12.8).
- [ ] Objetos, equipo e íconos
  Remodelar lo que haga falta y re-renderizar los íconos del inventario (tools/render_item_icons.gd, 11.15).
- [ ] Efectos estilo WW
  Humo en espirales, líneas de viento, explosiones cartoon, golpes (con 12.9 y 11.49).
- [ ] Agua toon y cáusticas
  El shader de agua estilo Wind Waker y las cáusticas de la cueva (11.20).

**Notas:** Con el estilo Wind Waker elegido (12.12), todo el juego tiene que convivir con el personaje nuevo. Primero se mide cuánto resuelve el shader: todas las piezas epi comparten el material de paleta (data/kits/materials/epiphany.tres), así que el cel shading se prueba en el mundo entero de una vez. Recién ahí se decide qué hay que remodelar. Lo que siga siendo KayKit va a desentonar más.

## M13 — Co-op local (estilo Four Swords)  (0/8)

Dos jugadores en la misma pantalla recorren el overworld y el templo juntos, con progreso compartido y puzzles que aprovechan a los dos.

**Hecho cuando:**
- Dos controles juegan una partida de punta a punta (overworld, templo y jefe) sin bugs de cámara ni de salas.
- Hay al menos tres puzzles que piden a los dos jugadores.
- Un solo jugador puede seguir jugando como siempre.

### 13.1 Código listo para varios players · Pendiente

**Prioridad:** alta · **Etiquetas:** `coop`, `arquitectura`

- [ ] Registro de players
  Un autoload o nodo `Players` con la lista y señales (joined/left); reemplaza las ~40 referencias al grupo "player" y los get_first_node_in_group.
- [ ] Regla para lo nuevo
  Desde ahora ningún sistema asume un solo player (anotado en GDD §13).
- [ ] Tests
  Los tests existentes pasan con 1 player; uno nuevo instancia 2 y revisa que salas, HUD e IA no se rompan.

**Prueba:** Con 1 player el juego es idéntico; instanciar un segundo player no tira errores en overworld ni templo.

**Notas:** Skills: `godot:godot-nodes-scenes`, `disciplines:input-systems`, `disciplines:camera-systems`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 13.2 Input por jugador y unirse a la partida; 13.3 Cámara y salas para dos; 13.4 Reglas del co-op; 13.5 HUD de dos jugadores; 13.6 Player 2 con su color; 13.7 Enemigos y jefe con varios objetivos; 13.8 Puzzles cooperativos

### 13.2 Input por jugador y unirse a la partida · Pendiente

**Prioridad:** alta · **Etiquetas:** `coop`, `input`

- [ ] Acciones por dispositivo
  Cada player lee su control (device id); InputBuffer, Aim y Targeting pasan a ser del player. Teclado+mouse cuenta como un dispositivo.
- [ ] Unirse / salir
  Start en un segundo control suma al P2 en cualquier momento; salir lo saca sin cortar la partida.
- [ ] Prompts por jugador
  InputPrompts muestra los botones del control de cada uno.

**Prueba:** Con dos controles, cada uno mueve solo a su player; el P2 entra y sale con Start sin pausar el juego.

**Notas:** Skills: `godot:godot-nodes-scenes`, `disciplines:input-systems`, `disciplines:camera-systems`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.2 Players en red

**Bloqueada por:** 13.1 Código listo para varios players

### 13.3 Cámara y salas para dos · Pendiente

**Prioridad:** alta · **Etiquetas:** `coop`, `camara`

- [ ] Encuadre de los dos
  Reusar el encuadre del lock-on: la cámara mantiene a ambos; si se alejan demasiado, un borde invisible los frena.
- [ ] Cambio de sala
  Estilo Four Swords: al cruzar uno la puerta, el otro es llevado con él (o hace falta que estén los dos). Decidir y anotar.
- [ ] Escenas
  Overworld ↔ templo llevan a los dos al spawn.

**Prueba:** Recorrer el templo de punta a punta con dos players: nunca queda uno fuera de cuadro ni en otra sala.

**Notas:** Skills: `godot:godot-nodes-scenes`, `disciplines:input-systems`, `disciplines:camera-systems`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.3 Mundo sincronizado

**Bloqueada por:** 13.1 Código listo para varios players

### 13.4 Reglas del co-op · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `diseño`

- [ ] Vida, muerte y revivir
  Cada uno con sus corazones; el caído queda como burbuja/espíritu y revive al tocarlo o en la sala siguiente. Game over solo si caen los dos.
- [ ] Inventario y equipo
  Progreso compartido (GameState); decidir si los ítems se comparten o cada uno equipa los suyos; munición compartida.
- [ ] Drops
  Corazones al que lo toca; rupias no hay.
- [ ] Anotar en el GDD
  Sección de co-op con las reglas.

**Prueba:** Morir con uno solo no termina la partida y se puede revivir; con los dos, game over.

**Notas:** Skills: `disciplines:game-ui-ux`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

### 13.5 HUD de dos jugadores · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `ui`

- [ ] Mockup
  Corazones e ítems del P2 en la otra esquina, con su color.
- [ ] Escenas
  El HUD instancia un panel por player (nada armado por código).

**Prueba:** Con dos players, cada uno ve sus corazones e ítems; al salir el P2 su panel desaparece.

**Notas:** Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

### 13.6 Player 2 con su color · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `arte`

- [ ] Variante de paleta
  Una entrada en VARIANTS (epiphany_palette.py) para el P2: otra tela y otro neón, como los Links de colores de Four Swords.
- [ ] Combinar con las armaduras
  Que la cota reforzada también tenga su versión P2.

**Prueba:** P1 y P2 se distinguen de un vistazo con cualquier armadura.

**Notas:** Skills: `disciplines:create-game-assets`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

### 13.7 Enemigos y jefe con varios objetivos · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `ia`

- [ ] Elegir objetivo
  Los BT de LimboAI eligen al más cercano o al último que les pegó; cambian con histéresis.
- [ ] Jefe
  Las manos pueden ir cada una por un player; balance de vida con 2.
- [ ] Escalado
  Un poco más de vida o enemigos con dos players.

**Prueba:** Con dos players, los enemigos se reparten y el jefe ataca a los dos; con uno, igual que siempre.

**Notas:** Skills: `disciplines:game-ai`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

### 13.8 Puzzles cooperativos · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `puzzles`

- [ ] Revisar los puzzles actuales
  Que no se rompan ni queden triviales con dos (bloques, interruptores, haces).
- [ ] Puzzles para dos
  Interruptores dobles, uno sostiene el escudo espejo mientras el otro tira la flecha, cajas que se empujan entre dos. En solo, una alternativa (bloque o tiempo).

**Prueba:** Hay al menos tres puzzles que piden a los dos; en solo siguen siendo resolubles.

**Notas:** Skills: `disciplines:level-design`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

## M14 — Co-op online  (0/6)

Llevar el co-op local a la red: host autoritativo, dos jugadores en distintas máquinas, con el combate igual de preciso.

**Hecho cuando:**
- Dos máquinas juegan juntas el templo entero con 100 ms de latencia sin desincronizar puertas, cofres, puzzles ni el jefe.
- El combate se siente igual que en local para el host y casi igual para el cliente.

### 14.1 Arquitectura de red · Pendiente

**Prioridad:** alta · **Etiquetas:** `online`, `arquitectura`

- [ ] Decidir
  Host autoritativo con ENet (MultiplayerAPI de Godot) y transporte Steam más adelante; el host corre IA, física, puzzles y guardado.
- [ ] Anotar en el GDD

**Prueba:** Documento corto con la arquitectura elegida, qué corre en el host y qué en el cliente.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.2 Players en red; 14.3 Mundo sincronizado; 14.4 Combate en red; 14.5 Lobby y conexión; 14.6 Guardado en co-op

### 14.2 Players en red · Pendiente

**Prioridad:** alta · **Etiquetas:** `online`

- [ ] El cliente manda input
  MultiplayerSynchronizer o RPC del input del P2; el host simula y devuelve estado.
- [ ] Predicción del propio player
  El cliente mueve a su player al instante y corrige con el estado del host.

**Prueba:** Con 100 ms de latencia simulada, el cliente se mueve sin retraso perceptible y sin tirones.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.2 Input por jugador y unirse a la partida; 14.1 Arquitectura de red

### 14.3 Mundo sincronizado · Pendiente

**Prioridad:** alta · **Etiquetas:** `online`

- [ ] Objetos con estado
  Puertas, cofres, interruptores, oleadas, drops, bombas y cajas físicas de Jolt (solo las simula el host).
- [ ] Escenas
  Cambio de escena y de sala sincronizado; el cliente carga lo mismo que el host.

**Prueba:** Recorrer el templo en red: nada queda desincronizado (puertas, cofres, bloques, puente).

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.3 Cámara y salas para dos; 14.1 Arquitectura de red

### 14.4 Combate en red · Pendiente

**Prioridad:** alta · **Etiquetas:** `online`, `combate`

- [ ] Golpes del cliente
  Hitboxes validadas en el host con compensación de latencia; bloqueo y parry con margen.
- [ ] Feedback local
  Hit-stop y flash se muestran al instante en el cliente.

**Prueba:** Pelear contra chullpas y el jefe como cliente con 100 ms: los golpes se sienten y no hay daño fantasma.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 14.1 Arquitectura de red

### 14.5 Lobby y conexión · Pendiente

**Prioridad:** media · **Etiquetas:** `online`, `ui`

- [ ] Crear y unirse
  Por IP/código en debug; invitación de Steam en release.
- [ ] Desconexiones
  Si cae el cliente, el host sigue solo; si cae el host, el cliente vuelve al título con aviso.

**Prueba:** Crear partida, invitar, jugar y desconectar al cliente sin que el host pierda progreso.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 14.1 Arquitectura de red

### 14.6 Guardado en co-op · Pendiente

**Prioridad:** media · **Etiquetas:** `online`, `guardado`

- [ ] Solo el host guarda
  El cliente participa en la partida del host; decidir qué se lleva el cliente (nada, o una copia).

**Prueba:** Terminar una sesión online, recargarla en el host: el progreso está y no se duplica nada.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 14.1 Arquitectura de red

## Listas

### Assets de audio  (3/6)

- [x] Kenney Impact Sounds (CC0) — golpes, daño, bloqueo, macetas, reflejo · assets/audio/sfx/kenney_impact-sounds
- [x] Kenney RPG Audio (CC0) — cortes, rodada, puertas, clics · assets/audio/sfx/kenney_rpg-audio
- [x] Kenney Interface Sounds (CC0) — rechazo, levantar, sonidos de menú · assets/audio/sfx/kenney_interface-sounds
- [ ] Música de verdad para overworld y templo (hoy: capas sintetizadas por src/tools/render_music.gd)
- [ ] SFX de explosión, secreto, curación y temblor (hoy sintetizados en Feel)
- [ ] Pasos (footsteps) y ambiente del templo (Kenney Impact Sounds trae pasos; falta el evento)
