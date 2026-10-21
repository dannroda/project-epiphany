# Tareas — Project Epiphany

> Export de `compass/`, que es la fuente de verdad. No editar: los cambios se hacen en `compass/` o con `scompass`, y este archivo se regenera.
> Generado: 2026-10-21

## M0 — Refactor del player + base de datos  (13/13)

Dejar armada la base sobre la que se construye todo lo demás: ítems como datos, estado de la partida, guardado, componentes de combate y un player ordenado en piezas. Casi nada de esto se ve en el juego todavía; lo que cambia es cómo está hecho. Diseño y código de ejemplo: `gdd.md` §11.

**Hecho cuando:**
- El player aparece con el equipo que dice `GameState`, no con la espada y el escudo puestos a mano en la escena.
- la tecla `3` guarda, la `2` carga, y el juego vuelve exactamente al mismo estado (posición, inventario, equipo, flags).
- Desde el Save Inspector se abre una partida, se edita, se valida y se juega como escenario.
- El esqueleto recibe daño por el camino nuevo (`Hitbox` → `Hurtbox` → `Health`).

### 0.1 Limpieza · Hecho

Arreglos chicos del código actual antes del refactor: corregir `is_empty` de la mano, evitar que la espada sin dueño del esqueleto rompa el juego y sacar archivos vacíos, código comentado y mensajes de depuración.

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

Definir en el Input Map las acciones de gamepad que van a usar los hitos siguientes (juego, menús y depuración), según [[gdd#input]] y sin inputs repetidos dentro de un mismo contexto. Teclado y mouse quedan para más adelante.

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

Reemplazar los `print` y `print_rich` sueltos por un logger con niveles y canales (autoload `Log`), conectado al debugger de Godot con una pestaña propia para filtrar en vivo, monitores y un overlay en el juego.

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

Crear la base de datos de ítems: cada ítem es un `.tres` con sus datos y un comportamiento enchufable, así una espada de fuego no necesita una clase nueva. Incluye el inventario, los 17 ítems y el autoload `Items`.

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

Declarar las flags del mundo (un cofre abierto, una puerta destrabada) en un registro, para evitar errores de tipeo y que el Save Inspector pueda avisar cuando una partida tiene una flag que no existe.

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

Crear `GameState`, la partida en memoria (inventario, equipo, flags, mazmorras y punto de aparición), como autoload para que sobreviva a los cambios de escena, con `write_to`/`read_from` y la partida nueva.

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

Guardar y cargar partidas en `user://saves/`: en texto plano desde el editor para poder leerlas y editarlas, encriptadas en release para que nadie las edite por accidente; con escritura atómica, respaldo y la posición del player.

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

Crear las piezas reutilizables para todo lo que pega o recibe golpes (player, enemigos, trampas, jefe) y la ficha `EntityConfig` de cada tipo de entidad, con sus fichas y ataques en `data/`.

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

Pasar el esqueleto a los componentes de 0.7: que reciba daño por `Hurtbox` y `Health` en lugar de `take_hit`, con su ficha y su `AttackRunner`. Todavía no ataca: la IA de ataque es M1.

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

Armar el player con componentes: el equipo sale de `GameState`, las hitboxes viven en el personaje con su `AttackRunner` y el lock-on pasa a un nodo propio, dejando `player.gd` y la máquina de estados solo con lo suyo.

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

Un dock del editor para abrir, editar, validar y jugar partidas guardadas y escenarios, para probar situaciones raras sin tener que jugar hasta ahí.

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

Un runner de tests headless que se corre por línea de comandos y termina con código 1 si algo falla, para probar sin abrir el juego lo que se puede: guardado, datos de ítems y flags.

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

Un servidor HTTP local en el editor para que Claude pueda manejarlo (registrar clases, correr y frenar escenas, leer el log, abrir y guardar) sin pedirle al usuario que le dé foco o haga clics.

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

Que al player le duela: recibir daño por la `Hurtbox`, retroceder y parpadear durante una invulnerabilidad breve en la que no recibe otro golpe. Primer paso de M1, sobre `Health`, `Hurtbox` y `DamageInfo` de M0.

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

Pilar 3, el escudo tiene doble función: bloquear de frente (cono de ±60°) anula el golpe con chispa y retroceso leve, y el golpe de escudo aturde al enemigo un momento. El reflejo con escudo espejo llega en M5.

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

Esquiva (roll) con i-frames en una ventana del roll, que cancela ataques y guardia, y buffer de input para que `dodge` y `attack` apretados un poco antes salgan igual.

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

El esqueleto es el enemigo que enseña a bloquear: tiene que ver al player, perseguirlo esquivando obstáculos, telegrafiar el ataque y pegar, reaccionar a golpes y aturdimiento, y morir. Usar las tareas de LimboAI que ya vienen y agregar solo las que falten.

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

Cuando el player muere: animación de muerte, fundido y reaparición en el spawn del nivel con la vida llena, con los enemigos de vuelta en su posición. La reaparición en la entrada de la sala de mazmorra es 6.1.

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

Primera pieza de UI del juego: corazones con cuartos en el HUD, actualizados por señal y animados al perder y ganar vida, dejando `hud.tscn` preparado para sumar slots de ítems, llaves y la barra del jefe.

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

Que el combate se sienta: hit-stop, sacudida de cámara, flash blanco en el golpeado, chispas al bloquear, polvo al rodar y SFX placeholder, con todos los valores exportados para tunearlos desde el inspector.

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

Hoy el lock-on siempre marca el más cercano. Cambiar de objetivo con el stick derecho entre candidatos válidos (no detrás de paredes), con feedback del salto y soltando el lock-on al perder el objetivo.

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

Componente `Aim` con la dirección de apuntado (objetivo fijado, stick derecho o mouse), una retícula y el giro del modelo al usar un ítem. Lo consumen el arco, las bombas lanzadas y los ítems a distancia de M5 por `ItemUseContext.direction`.

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

Pilar 5: gamepad y teclado/mouse son ciudadanos de primera. Definir el mapa de teclado y mouse, cambiar de objetivo con la rueda y detectar el dispositivo activo, para poder jugar sin gamepad. El remapeo es post-MVP.

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

Ajustar el encuadre: con lock-on que entren el player y el objetivo, y al apuntar que la cámara se adelante hacia la dirección de `Aim` y vuelva suave, con el suavizado exportado. La cámara de salas es M6.

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

Base de todas las pantallas (inventario, mapa, opciones, título): una pila de menús y el menú de pausa, que congela el juego y tiene pestañas navegables con gamepad y teclado, más el theme base del juego.

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

Pantalla Equipo en el menú de pausa: ranuras de espada, escudo y armadura para equipar con `GameState.equip()`, con stats y preview del modelo. La cota reforzada (7.7) es el ítem que justifica esta pantalla en el MVP.

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

Pantalla Ítems: grilla de los ítems secundarios desde donde se asignan a X o Y, actualizada por `Inventory.changed`, con la asignación guardada en la partida.

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

Usar el ítem asignado a X o Y: estado `UsingItem` que arma el `ItemUseContext` y llama `behavior.use()` en el momento justo de la animación, con feedback de "no se puede" cuando el ítem no se puede usar.

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

Slots X/Y en el HUD con el ícono y la munición del ítem asignado, actualizados al cambiar el inventario o la asignación, y con el ícono del botón según el dispositivo activo.

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

Cofres que se abren interactuando y dan su ítem con la secuencia de item get, con `GameState.give()` como entrada única, primer equipado automático y una flag para que el cofre no vuelva a dar el ítem.

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

No hay moneda: los drops son lo que evita quedarse sin bombas ni flechas en la mazmorra. Recolectables y una tabla de drops ponderada que sueltan los enemigos al morir, solo con lo que el player puede usar.

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

Un ícono placeholder coherente por cada `ItemData`, que se distinga a tamaño de HUD, para las pantallas y el HUD. No es arte final: la dirección de arte se decide en 10.7.

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

Prompt de acción contextual en el HUD: muestra qué hace `interact` ("Abrir", "Leer", "Empujar") con el `Interactable` más cercano y de frente, así el jugador sabe con qué va a interactuar. Se oculta en combate, en menús y cuando el player no puede actuar.

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

Caja de texto propia para tablillas e item get: letra por letra, varias páginas, pausa el juego y se avanza con `interact`/`attack` sin saltear páginas sin querer. Los textos van como datos para dejar lista la localización.

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

Tablillas legibles (`Tablet`) con su texto, que pueden marcarse como leídas para que el mapa muestre las pistas. Escribir dos de prueba (ambientación y pista de puzzle) para validar el tono de la historia.

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

Vasijas rompibles y pasto cortable que sueltan drops según su `DropTable` y reaparecen al recargar, para dar vida al mundo y corazones donde hagan falta. Levantar y lanzar vasijas es opcional y recortable.

- [x] Vasija rompible
  `Hurtbox` de equipo neutral: se rompe con espada, bomba o al tirarla. Suelta según su `DropTable`.
- [x] Levantar y lanzar vasijas (opcional)
  Hecho más adelante: el player levanta y lanza vasijas (src/world/thrown_object.gd).
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

Componente `PersistentFlag` para que cofres, puertas, muros, interruptores y tablillas recuerden su estado entre partidas, con aviso en el editor si el flag está mal escrito y una convención de nombres (`ow_*`, `d1_*`). Es lo que hace que el mundo recuerde lo que hiciste.

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

Integrar el plugin Dialogue Manager con nuestra `TextBox` como globo y pasar tablillas e item get a archivos `.dialogue`. Así hay textos condicionales con flags y traducciones desde ya, sin rehacerlos cuando haya muchos textos.

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

Proyectiles base (`Projectile`, extiende `Hitbox`) que chocan con el mundo y que el escudo espejo puede reflejar hacia quien los tiró. Son la base de los orbes de la torreta, las flechas y el reflejo con el escudo.

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

Torreta / ojo menor: enemigo fijo que apunta, telegrafía y dispara orbes reflejables. Solo cae con su propio orbe reflejado o con flechas, para enseñar el reflejo con el escudo espejo.

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

Arco y flechas: mantener para apuntar y soltar para disparar, con munición limitada y flechas que se clavan. Suma `EyeSwitch`, un interruptor que solo reacciona a proyectiles, para puzzles a distancia (sala 6 y el carcaj).

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

Bombas que se colocan delante o se lanzan en arco hacia la mira, con mecha y explosión que daña a todos (el player incluido) y empuja objetos físicos. Son la llave de los muros agrietados y del gating del overworld.

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

Muros agrietados (`CrackedWall`) que solo se rompen con explosiones, con una grieta legible desde la cámara y estado persistente por flag. Es el primer uso de las bombas para abrir caminos y secretos.

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

Escudo espejo y haz de luz: un `LightBeam` que rebota en espejos y en el escudo mientras se bloquea, y un cristal (`LightReceiver`) que se activa al recibirlo. Es la mecánica central que abre el sello del templo y los puzzles de reflejo.

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

Poción y botella: tomar la poción cura y deja la botella vacía en el inventario. El player queda vulnerable mientras toma, como riesgo/recompensa.

- [x] `ItemData` de botella vacía y poción
  `ConsumableBehavior` con `heal` y `leaves` = botella vacía. Código en [[gdd#items-datos]].
- [x] Animación de tomar
  `Use_Item`; el player queda vulnerable mientras toma (riesgo/recompensa).

**Prueba:** Tomar la poción con 1 corazón: cura y queda la botella vacía en el inventario.

**Notas:** Casi todo salió en 3.4: potion con ConsumableBehavior (heal = -1, toda la vida; leaves = bottle_empty, que queda en el mismo botón) y la animación General/Use_Item. Riesgo/recompensa: la poción se toma a mitad de la animación (use_at 0,5); un golpe antes pasa a Hurt, corta el trago y no la gasta. Rellenar la botella (la descripción dice que se puede) no tiene tarea: hace falta una fuente o algo que la llene.

**Referencias:** `gdd.md#items-mvp`, `gdd.md#items-datos`

**Bloqueada por:** 3.4 Usar los ítems asignados

### 5.8 Sala de pruebas de ítems · Hecho

Sala de pruebas (`levels/sandbox_items.tscn`) con un puzzle gris por ítem: muro bombable, ojo lejano, reflejo de luz y orbe de torreta, accesible desde el escenario `full_inventory`. Cierra el hito y queda como banco de pruebas de regresión.

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

Que cada escudo frene ciertos tipos de daño según `DamageInfo.element` (la madera frena flechas pero no explosiones ni fuego) y que el escudo en la espalda también proteja de proyectiles. El espejo refleja siempre que intercepta, porque es un espejo.

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

`Room`: sala de mazmorra con la cámara limitada a sus bordes y transición deslizada al pasar de una a otra. Marca la sala como visitada, muestra su nombre la primera vez y es el punto de reaparición al morir en la mazmorra.

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

Puertas de mazmorra (`Door`): abierta, con llave, persiana, de interruptor y del jefe, que se abren con animación y sonido. Las persianas encierran hasta limpiar la sala y las de llave quedan abiertas entre partidas.

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

Llaves chicas y del jefe que van al `DungeonState` de la mazmorra actual, con contador en el HUD solo dentro de la mazmorra. Para eso la escena de la mazmorra setea `GameState.current_dungeon`.

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

Bloques que se empujan de a una celda (`PushBlock`) con el estado `Pushing` del player, sin meterse en paredes, bloques ni enemigos. Vuelven a su lugar al salir de la sala, salvo que el puzzle esté resuelto, para que no quede trabado.

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

Interruptor de piso y una interfaz común `activated`/`deactivated` con `EyeSwitch` y `LightReceiver`, para cablear puertas y aparatos desde el editor (todos o alguno) sin código por sala.

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

Mapa y brújula de la mazmorra como ítems y la pantalla Mapa (pestaña de pausa y acción `map`): salas visitadas, todas con mapa, cofres y jefe con brújula, y la posición del player. El mapa se arma solo desde las `Room`; el overworld lleva una imagen fija.

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

Mazmorra de prueba de tres salas grises conectadas, armadas con un kit de bloques en `GridMap`, que ejerciten bloque e interruptor, persiana con esqueletos y puerta con llave y cofre. Cierra el hito y deja el kit para M7 y M8.

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

## M7 — Overworld  (11/11)

Zona chica con el gating bombas → escudo espejo → sello del templo, y los secretos.

**Hecho cuando:**
- Ida y vuelta entre overworld y mazmorra.

### 7.1 Diseño del layout del overworld · Hecho

Diseñar el layout del overworld antes de construir: 6–8 pantallas con camino crítico, atajos y secretos, verificando el gating bombas → escudo espejo → sello y la curva de ritmo. Cierra la decisión abierta del layout en el GDD.

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

Blockout gris del overworld (`levels/overworld.tscn`) con el kit de 6.7: zonas con nombre y reaparición, navmesh, esqueletos y pasto en la pradera, y objetos físicos. `levels/test.tscn` queda como nivel de pruebas.

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

`Portal` para pasar entre overworld y mazmorra con fundido y carga en segundo plano, sin congelar la imagen y apareciendo en la puerta correcta. Guarda al cambiar de escena para no perder progreso.

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

Cueva de las bombas: cofre con la bolsa de bombas, tablilla que enseña a usarlas y un muro agrietado justo después para probarlas enseguida. Es el primer paso del gating del overworld.

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

Santuario del escudo espejo detrás del muro agrietado: un desafío corto, el cofre grande con el escudo y un cristal de práctica que enseña el reflejo de luz antes del sello del templo.

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

Sello del templo: puzzle de luz con fuente, espejos fijos y el escudo espejo que abre la entrada a la mazmorra para siempre. Es el primer momento de *doom*: temblor al abrirse y temblores lejanos al acercarse.

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

Tres secretos del overworld: botella con poción tras un muro agrietado, cota reforzada en un puzzle de bloques y carcaj grande en un ojo que solo se alcanza con el arco, después de la mazmorra. Si falta tiempo se recortan primero el carcaj y después la cota.

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

Escenarios `start`, `bombs_only` y `pre_temple` para arrancar en cada etapa del overworld desde el Save Inspector, y un recorrido completo de `start` al templo y de vuelta. Cierra el hito: ida y vuelta entre overworld y mazmorra.

- [x] Crear `start`, `bombs_only` y `pre_temple`
  En `debug/scenarios/`, desde el Save Inspector.
- [x] Recorrido completo de ida y vuelta
  Overworld → templo → overworld.

**Prueba:** Jugar `start` hasta entrar al templo y volver a salir sin usar escenarios intermedios.

**Notas:** Cierra el hito: "ida y vuelta entre overworld y mazmorra".

Hecho 2026-10-08: `start` ahora arranca en el overworld (escena principal del juego); `bombs_only` y `pre_temple` ya venían de 7.5 y 7.6 (generados con SaveCodec, mismo formato que el Save Inspector). `tests/test_overworld_run.gd` juega `start` hasta el templo y vuelve.

**Referencias:** `gdd.md#save-inspector`

**Bloqueada por:** 7.6 Sello del templo

### 7.9 Rediseño del overworld como hub de varias mazmorras · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `overworld`, `nivel`

El overworld de 3 × 3 pantallas quedó hecho para una sola mazmorra y se siente encajonado. Rediseñarlo como hub (referencia: análisis del Light World de A Link to the Past, Overworld Overload partes 1 y 2): regiones núcleo con su mazmorra unidas por zonas de conexión, paredes de terreno y puertas de ítem que abren atajos o regiones nuevas, recorrido y ritmo revisados. Entra la Chullpa (11.60) y quedan lugares para las que vengan.

- [x] Propuesta de layout (variantes) y elección
  Propuesta en https://claude.ai/artifact/8N6Sst4jMsTDTgKLWdqm4B. Daniel (2026-10-11): el tamaño no importa, 4 mazmorras, viaje rápido ahora. Propuesta D, la mezcla: quebrada de la B, anillos de la A, terrazas de la C solo al este, 6 portales. Aprobada por Daniel.
- [x] Diseño elegido en el GDD (§7): regiones, gating, ritmo
  GDD §7 y §7.1 (gdd#overworld-layout): mapa de la variante D, tabla de regiones, cadena de mazmorras, gating, viaje rápido y ritmo; §6.2 con D2–D4.
- [x] Blockout del GridMap nuevo
  debug/tmp/ow/build_layout.gd (generador de una vez): 7 × 5 pantallas de 12 × 8 celdas; lugares viejos mudados con su contenido (celdas y nodos), regiones nuevas lisas con AreaZone, quebrada y laguna de Abismo con Pit por orilla (Pit vuelve al marcador más cercano), escalones de una vía como tiras de Escalón, angostura de una celda. world_rect del mapa (−85, −41, 170, 82). Tests de overworld al día (rutas de las dos orillas, angostura). GDD §7.1 (Blockout del layout D).
- [x] Puente de la quebrada y entrada de la Chullpa
  Bridge que sube del fondo con una flecha al ojo de la otra orilla (ow_ravine_bridge_eye); torre provisoria de la Chullpa con su Portal en el norte de la Necrópolis y Spawn_chullpa delante. Los lugares viejos ya se mudaron en el paso 3. Postes del gancho, salto de una vía y puertas de D3/D4 esperan 11.90.
- [x] Terreno orgánico, decoración y navmesh regenerados
  Rehecho con el puente y la Chullpa (945f45f); se repite cada vez que cambian el GridMap o los puntos fijos.
- [x] Tests y escenarios al día
  Escenario travel (los 6 portales prendidos, puente subido, todo el mapa visitado; para recorrerlo) y test_scenario_spawn_points_exist: el punto de cada escenario existe en su escena.
- [x] Recorrerlo (Daniel)
- [x] Viaje rápido: mockup de la pantalla
  Artboard 'Pausa · Mapa (overworld nuevo) con portales de viaje' (Pause_Map_Travel) en https://claude.ai/artifact/UuD7d42rAXuYTBcMd9iZJy. Aprobado por Daniel.
- [x] Viaje rápido: portales y viaje desde el Mapa
  travel_portal.tscn ×6 en overworld.tscn (ow_portal_<id>); Mapa: marcas, cursor que se engancha, tarjeta y X Viajar con travel_dialog; interactuar en un portal abre el Mapa. test_travel_portals_light_up_and_the_map_travels. Playtest 2026-10-12 'no puedo teletransportarme': el diálogo arrancaba en Cancelar (A cancelaba); ahora arranca en Viajar como el mockup (ConfirmDialog.confirm_first). El portal del Claro estaba pegado a la tablilla de controles y E podía leerla: se mudó a (−51, 17); el test pide que ningún portal tenga otro interactuable a menos de 3 m.
- [x] Laguna de agua real y Bañado de agua baja
  Daniel (2026-10-11): la Laguna con el agua de la cueva de la vertiente (water.gdshader: espuma en la orilla, color por profundidad) sobre el hueco; cascada en el acantilado norte donde termina la quebrada; caer al agua salpica y vuelve a la orilla (no se nada); la isla de D3 con el gancho. El Bañado, agua baja que se camina.
- [x] Que todo se pueda alcanzar y cruzar
  Playtest 2026-10-12: áreas imposibles de alcanzar o cruzar. test_every_region_is_reachable_except_the_item_gated (navmesh + link del puente): con el puente se llega a todas las zonas menos la Cumbre y la isla de la Laguna (gancho) y las franjas de la Quebrada (angostura y bajadas, 11.90). Falta que Daniel diga qué lugares puntuales no pudo cruzar.
- [x] Mapa: A viaja, X pone pin
  Daniel (2026-10-12): era contraintuitivo que el viaje fuera con X. Mockups Pause_Map_Travel, Pause_Map_Regions y Pause_Map_Overworld al día; map_page: ui_accept viaja (si hay portal enganchado), item_1 pone o quita pin; barra de ayudas en el orden del mockup.

**Capturas:** `compass/images/m7-09-mapa.jpg`, `compass/images/m7-09-1.jpg`, `compass/images/m7-09-2.jpg`, `compass/images/m7-09-3.jpg`, `compass/images/m7-09-4.jpg`, `compass/images/m7-09-5.jpg`

### 7.10 Overworld con forma de Zelda 2D, no cuadrado · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `overworld`, `nivel`

Daniel (2026-10-12, con el mapa de Link's Awakening de referencia): el mundo se ve cuadriculado, regiones rectangulares de una pantalla. Que se parezca más a los Zelda 2D: bordes de riscos que zigzaguean, hileras de árboles como paredes, caminos que serpentean, regiones de tamaños y formas distintas, rincones y entradas escondidas. Los secretos se esconden por diseño (entrada en un risco, detrás de una hilera de árboles, cueva interior) y no con ZoneVeil, que en el overworld delata que hay algo oculto; el velo queda para otros usos. Se mantienen las regiones, la cadena de mazmorras y el gating de §7 (variante D).

- [x] Análisis de la referencia (Link's Awakening, ALttP): qué hace que no se vea cuadrado
  Propuesta en https://claude.ai/artifact/NF4jYH76khQkD2mr4A8tus: hoy son salas rectangulares unidas por aberturas, la lógica de un mapa de mazmorra. Los Zelda 2D tienen terreno continuo, bordes de paisaje (cornisas, hileras de árboles, cercos, agua), formas y tamaños distintos, caminos que guían, densidad y los secretos en cuevas interiores.
- [x] Propuesta del layout nuevo (variantes) y elección de Daniel
  Daniel (2026-10-12): el boceto va encaminado como primera versión (lo que cambie sale de recorrerlo); un poco más grande para más secretos: 100 × 48 celdas (200 × 96 m), generado por debug/tmp/ow2/layout.py y dibujado con los tiles de la sesión de arte (tilemap.py). El atajo del santuario queda como salida trasera de la cueva al andén del templo. Cadena de 11.113 aplicada: D1 nueva en el claro de la Arboleda (propuesta, avisada a diseño), templo final, sin rocas de guantes.
- [x] Cuevas interiores: Santuario, Gruta y Cueva de las bombas en escenas propias; ZoneVeil fuera del overworld
  Daniel (2026-10-12): la gruta y los santuarios pasan a ser cuevas interiores. Afuera, solo la boca o la grieta en la cara de un risco. Hecho: levels/shrine_cave.tscn (con salida trasera al andén del templo), grotto_cave.tscn y bomb_cave.tscn, armadas con el contenido del overworld viejo; afuera, una muesca de una celda en la cara del risco con su puerta y spawn. Sin ZoneVeil en el overworld.
- [x] Blockout del GridMap nuevo, con terrazas reales
  Daniel (2026-10-12): terrazas reales, las mesetas se caminan por arriba. Un nivel = 2,6 m. GridMap con cell_size.y 2,6, piso en y = nivel (0, 1, 2), montaña Monte en y = 3. Hecho: layout.json → GridMap, export y Blender con niveles (risco entre niveles, baranda invisible salvo en saltos), lo jugable mudado. Escalinatas y saltos de arte (src/world/terrazas/) puestos en las celdas de escalón. Daniel (2026-10-13), con la Chullpa como D1: la Chullpa va a los Cerros (se llega con espada y bombas) y la Arboleda es una meseta a la que se entra cruzando con la pluma un abismo de una celda desde una cornisa del claro (la Queñoa queda D2). El bañado sigue las celdas de bañado, con orilla contra la laguna.
- [x] Terreno orgánico, decoración, navmesh y mapa regenerados
  Contornos relajados (las escaleras de celdas pasan a curvas y diagonales; menos en agua y caminos), sin agujeros entre la laguna y el bañado. Decoración, plantas despejadas alrededor de escalinatas, navmesh y foto del mapa regenerados. El mapa y el minimapa revelan igual: boceto en pergamino donde no se pasó, foto a color donde sí. Falta: el agua del bañado son planos rectangulares y se nota el borde recto sobre la orilla.
- [x] Tests y escenarios al día, puzzles y secretos puestos
  Daniel (2026-10-13) eligió:
  - Risco: escalinata a la cornisa y abismo de 4 m (RiscoPit, nivel 2). El ojo abre con flecha el nicho del carcaj grande y una pieza de corazón.
  - Santuario: después de D4. El bloque abre el atajo al andén del templo; el cristal, con el escudo espejo, abre el cofre del contenedor de corazón.
  - Piezas de corazón: Pradera (escalón de 0,6 m, con la pluma), Risco, Islotes de la Laguna y Cerros (muro agrietado).
  - Secretos en muescas de risco con muro agrietado: Cumbre 5 bombas, Quebrada 10 flechas, Mirador poción, Cardonal 5 bombas. No hay rupias en el juego.
  Al día: test_overworld, test_jump, test_heart_pieces, test_secrets (nuevo), test_shrine, test_overworld_run, test_map, test_portal, test_temple_seal, test_grove_puzzle, test_enemy_ai, test_save_codec (escenarios re-firmados). test_zone_veil se borró. Flags nuevos en flag_registry. El puzzle de la Arboleda se corrió 2 m al norte: la orilla relajada del risco tapaba las placas. Pendiente: el texto de la tablilla del santuario habla del escudo espejo como premio. [[gdd#overworld-layout]]
- [x] Recorrerlo (Daniel)

**Capturas:** `compass/images/m7-09-mapa.jpg`

### 7.11 Overworld: huecos de salto largo y mini quest de las sandalias · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `overworld`, `nivel`

Daniel (2026-10-13): la pluma cruza 1 celda (2 m) y sandalias + pluma 3 (6 m). La angostura (Arboleda ↔ Cardonal) y los huecos de los islotes de la Laguna pasan a 3 celdas: solo se cruzan con el salto largo (11.118). El abismo del Risco pasa a 4 celdas (8 m). Mini quest en la Necrópolis, del otro lado del puente: tres ojos en las chullpas, prendidos a la vez con flechas, dan las sandalias. Depende de 11.118. [[gdd#progresion-gating]]

- [x] Angostura e islotes a 3 celdas; abismo del Risco a 4
  Daniel (2026-10-13): la pluma cruza 1 celda (2 m) y sandalias + pluma 3 (6 m). La angostura y los huecos muelle → islote → isla de D3 miden 3 celdas; el Risco 4 (8 m), con el ojo corrido al norte (Z -32.4). La pieza de los islotes va sobre el islote.
- [x] Mini quest de la Necrópolis (arco → sandalias)
  Hecho: corral de pirca de la Necrópolis (X 24..36, Z -12..-3, nivel 1). Tres chullpas (src/world/chullpa_tumba.tscn: torre de piedra con un EyeSwitch de 8 s) miran al centro; con los tres ojos prendidos a la vez aparece el cofre grande SandalsChest (flag ow_sandals_chest) con las sandalias. Test en test_secrets.
- [x] Tests del overworld al día (angostura, islotes, Risco, quest)
- [x] Recorrerlo (Daniel)

**Capturas:** `compass/images/m7-11-mapa.jpg`, `compass/images/m7-11-1.jpg`, `compass/images/m7-11-2.jpg`, `compass/images/m7-11-3.jpg`, `compass/images/m7-11-4.jpg`, `compass/images/m7-11-5.jpg`

## M8 — Contenido de mazmorra  (8/8)

Las 8 salas en bloques grises, el arco a mitad de camino, la llave del jefe.

**Hecho cuando:**
- La mazmorra se recorre entera.

### 8.1 Layout de la mazmorra · Hecho

Cerrar el layout de la mazmorra antes de construirla: cómo se conectan las 8 salas y el jefe alrededor de un hub, dónde va el arco a mitad de camino y la curva de *doom*, con llaves contadas para que ningún orden de recorrido deje al jugador trabado.

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

Un enemigo que no se resuelva a espadazos: un esqueleto con escudo que bloquea de frente y obliga a flanquearlo, usar bombas o romperle la guardia con un golpe de escudo. Más lento y torpe para girar que el común.

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

Construir el vestíbulo y el hub del templo: la sala 1 enseña el bloque por grilla con su interruptor y la persiana, y la sala 2 reparte el recorrido con 4 salidas (con llave, con persiana, la del jefe sellada y una libre) y esqueletos.

- [x] Sala 1: bloque por grilla → interruptor → persiana
- [x] Sala 2: hub con 4 salidas y esqueletos
  Con llave, con persiana, la del jefe (sellada) y una libre.

**Prueba:** Desde la entrada de la mazmorra, llegar al hub y ver las 4 salidas en el estado que dice el GDD.

**Notas:** Hecho 2026-10-08: `levels/temple.tscn` con la geometría de las 9 salas (§8.1) y el contenido de vestíbulo y hub. La puerta del templo del overworld ahora lleva acá (antes a `dungeon_test`). Test `tests/test_temple.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloquea a:** 8.4 Salas 3–4: galería de trampas y sala agrietada; 8.5 Sala 5: arena y arco

**Bloqueada por:** 6.7 Mazmorra de prueba: tres salas grises; 8.1 Layout de la mazmorra

### 8.4 Salas 3–4: galería de trampas y sala agrietada · Hecho

Las salas 3 y 4 del templo, resolubles sin el arco: una galería donde se reflejan los orbes de las torretas a un cristal para ganar una llave chica, y una sala agrietada donde las bombas abren el camino al mapa.

- [x] Sala 3: reflejar orbes de torretas a un cristal
  Da una llave chica.
- [x] Sala 4: muro bombable y bombas que empujan bloques físicos
  Da el mapa.

**Prueba:** Resolver las dos salas desde `dungeon_no_bow` y salir con la llave y el mapa.

**Notas:** Hecho 2026-10-08: galería (torreta → reflejo → ojo → llave 1; ojo de la puerta norte solo con flecha) y sala agrietada (bomba vuela la caja del hueco → mapa; muro agrietado a la arena). Simplificación: en vez de "bombas empujan bloques a un interruptor", la bomba despeja el paso (más robusto con física). `dungeon_no_bow` ahora es del templo (en el hub); el escenario viejo de las salas de prueba se llama `test_rooms`. Test en `tests/test_temple.gd`.

**Referencias:** `gdd.md#mazmorra`

**Bloqueada por:** 5.2 Torreta / ojo menor; 5.4 Bombas; 8.3 Salas 1–2: vestíbulo y hub

### 8.5 Sala 5: arena y arco · Hecho

La arena del templo: oleadas de enemigos que cierran la sala hasta vencer la última y, de premio, el cofre grande con el arco, que abre la segunda mitad de la mazmorra. Morir a mitad tiene que reiniciar las oleadas.

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

Las salas 6 y 7, donde se usa el arco recién ganado: ojos-interruptor sobre un abismo que dan la brújula y una llave chica, y un puzzle que combina bloques, reflejo y flechas para conseguir la llave del jefe.

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

La antesala antes del jefe: un respiro con vasijas de corazones, una tablilla que lo anticipa y la puerta del jefe. Funciona de checkpoint: morir contra el jefe devuelve acá.

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

Cerrar el hito comprobando que la mazmorra se recorre entera de la entrada a la puerta del jefe, sin softlocks (sin bombas o flechas, bloques trabados, puertas cerradas del lado equivocado), y dejar los escenarios `dungeon_no_bow`, `pre_boss` y `boss_key_door_locked` para probarla.

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

Traer al proyecto el modelo del jefe (el ojo con manos) armado como piezas que mueve el código, sin rig: ojo que mira, párpados, manos con tres poses y sus sockets, a una escala que entre entera en la sala del jefe.

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

Preparar el escenario de la pelea: la sala del jefe cierra la puerta al entrar, encuadra la arena entera, corre una intro corta y salteable que presenta al ojo, y el HUD muestra la barra de vida del jefe.

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

La base de la IA del jefe: el ojo y cada mano como entidades con su vida y sus golpes, fases con `LimboHSM` que corren su propio BT y un blackboard compartido que elige el ataque por utilidad para que no sea predecible.

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

Primera fase del jefe: las manos golpean el piso avisando con una sombra, agarran al player y quedan aturdidas tras el golpe, dando la ventana para pegarles. Aturdir las dos pasa a la fase 2; tiene que poder ganarse solo con bloqueo y roll.

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

Segunda fase: el ojo se abre y pasa a ser el blanco. Una flecha al ojo o devolverle sus orbes con el escudo espejo lo tira aturdido para los espadazos, mientras las manos regeneradas siguen presionando.

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

Cerrar la pelea y el hito: el jefe muere con su animación y flag `d1_boss_defeated`, deja un contenedor de corazón, aparece el portal de salida y el juego llega a un final. Se puede terminar el juego.

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

Fase 3 opcional (primera en la lista de recortes): por debajo de cierto umbral de vida el ojo marca el piso antes de golpes de área y combina sus patrones con los de las manos. Solo si sobra tiempo.

- [x] El ojo marca el piso antes de golpes de área
- [x] Combinar patrones de manos y ojo

**Prueba:** La fase 3 se activa por debajo de cierto umbral de vida y se puede ganar sin recibir daño inevitable.

**Notas:** Primera en la lista de recortes ([[gdd#roadmap]]). Solo si sobra tiempo.

**Referencias:** `gdd.md#jefe`, `gdd.md#roadmap`

**Bloqueada por:** 9.6 Muerte del jefe y final

### 9.8 Portal de salida en la sala del jefe · Hecho

**Prioridad:** media · **Etiquetas:** `mazmorra`

Una salida de la sala del jefe: un portal en el centro de la arena que lleva a la entrada del templo en el overworld, oculto hasta que un flag (el del jefe vencido, en 9.6) lo active.

- [x] Portal.required_flag: oculto hasta que el flag sea verdadero
- [x] Escena warp_portal.tscn en el centro de la sala del jefe, al overworld (Spawn_templo)
- [x] Test, captura y GDD

**Prueba:** Desde pre_boss: pararse en el portal de la sala del jefe y aparecer en la Entrada del templo.

**Notas:** Sin flag por ahora porque no hay jefe; 9.6 le pone d1_boss_defeated.

## M10 — Terminación  (28/31, 2 en revisión)

Título, selección de partida, game over, opciones, ambientación del doom, audio y build para playtesters (compilar las plantillas de LimboAI).

**Hecho cuando:**
- MVP jugable por otra persona.

### 10.1 Pantalla de título · Hecho

El juego necesita una puerta de entrada: una pantalla de título con logo y menú (Continuar, Nueva partida, Opciones, Salir) navegable con gamepad y teclado, que pase a ser la escena principal sin romper `--scenario=` ni la carga de escenarios en debug.

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

Que el jugador elija partida y no pierda progreso: pantalla de ranuras con corazones, ubicación y tiempo jugado, borrar con confirmación y un autosave en momentos clave con indicador en pantalla, sin que un corte a mitad de guardado rompa la partida.

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

Reemplazar el fundido al morir por una pantalla de game over con Continuar (desde la entrada de la sala o el último checkpoint) o Guardar y salir, que lleve al lugar correcto en overworld, mazmorra y jefe.

- [x] Pantalla al morir
  Continuar (desde la entrada de la sala / último checkpoint) o Guardar y salir.
- [x] Reemplaza el fundido de 1.5

**Prueba:** Morir en overworld, en mazmorra y contra el jefe: cada "Continuar" lleva al lugar correcto.

**Notas:** Hecho 2026-10-09: `GameOver` (mockup) reemplaza el fundido de 1.5; `SaveManager.save_checkpoint()` para Guardar y salir; `MenuStack` respeta pantallas `modal`. Morir contra el jefe vuelve a la antesala (8.7). Tests `tests/test_game_over.gd` + los de muerte actualizados.

**Referencias:** `gdd.md#ui`, `gdd.md#combate`

**Bloqueada por:** 1.5 Muerte y reaparición del player; 10.1 Pantalla de título

### 10.4 Opciones · Hecho

Un menú de opciones, desde el título y la pausa, para lock-on mantener/alternar, sensibilidad de apuntado y volúmenes, guardado en `user://settings.cfg` aparte de la partida para que se mantenga al reiniciar.

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

Darle sonido al juego: buses con volumen desde Opciones, SFX y música conseguidos con sus licencias, variación para que los sonidos repetidos no suenen idénticos y música por capas que crece con el *doom* de la mazmorra.

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

Que el *doom* se sienta sin cronometrarlo (pilar 4): cada sala del templo con un nivel que mueve luz hacia el rojo, niebla, polvo, grietas, temblores y murmullo, para que la progresión de calma a latido se note sin leer nada.

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

Decidir la dirección de arte (KayKit + prototipo o propia), escribir una guía de estilo corta y reemplazar los placeholders críticos (HUD, íconos, cofres, puertas, muros agrietados que se lean como secreto) para que overworld, mazmorra y HUD parezcan el mismo juego.

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

### 10.8 Pasada de rendimiento · Hecho

**Terminada:** 2026-10-12

Asegurar 60 FPS en la máquina más floja de los playtesters: perfilar las peores escenas (arena con oleadas, overworld con pasto, jefe) y arreglar lo que se mida.

- [x] Presupuesto de frame
  60 FPS en la máquina más floja de los playtesters.
- [x] Perfilar las peores escenas
  Arena con oleadas, overworld con pasto, jefe. Profiler y monitores `epiphany/*`.
- [x] Arreglar lo que se mida
  Pools, MultiMesh, luces con sombra, partículas.

**Prueba:** Las tres escenas se mantienen en el presupuesto en build release.

**Notas:** Skills: `disciplines:performance-optimization`.

2026-10-09: presupuesto 16,6 ms p95; `src/tools/profile_scenes.gd` mide pradera, arena y antesala (todas ≈ 5 ms medio, ≤ 8 ms p95 en RX 580). Arreglado el tirón al aparecer oleadas (un enemigo por cuadro). Queda en Revisión: falta la escena del jefe (M9) y medir en build release (10.9) en la máquina más floja.

**Bloqueada por:** 8.8 Recorrido completo y escenarios de la mazmorra

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión); 15.8 Medir la build release en la máquina más floja

### 10.9 Build para playtesters · Hecho

**Terminada:** 2026-10-12

Un build instalable para playtesters en Linux, Windows y macOS: plantillas de export con LimboAI, presets sin escenarios ni tests, clave de guardado propia y un script para compilar por línea de comandos.

- [x] Plantillas de export de LimboAI (oficial 1.8.1)
  Los template_release de Linux, Windows, macOS y web (wasm32 nothreads) salen del gdextension-4.6 oficial de LimboAI 1.8.1; el editor sigue con el build parchado (el parche es solo UI del editor). Probado 2026-10-10: export release de Linux y Windows, y el build de Linux corre el templo (LimboHSM del player, BTs de enemigos) sin errores.
- [x] Presets de export
  Excluir `debug/scenarios/*` y `tests/`; `plain_saves` solo en el preset de debug.
- [x] Cambiar la clave de guardado
  `SaveCodec._PASS` antes del primer release.
- [x] Build por línea de comandos
  Script `tools/build.sh` con `godot --headless --export-release`.
- [x] Preset de macOS sin firmar
  Preset 'macOS' en build.sh: universal (Intel + Apple Silicon), bundle id com.lonewolftechnology.epiphany, ícono .icns generado del png, firma ad-hoc (built-in) sin notarizar. Los playtesters abren con clic derecho → Abrir o xattr -dr com.apple.quarantine. Sin Mac para probar: se confía en los reportes.
- [x] Metadatos del .exe (opcional)
  El ícono va dentro del .exe (Godot 4.8 lo incrusta solo, sin rcedit). Versión 0.1.0.0, nombre y descripción 'Project Epiphany'; empresa vacía. Sin firma: SmartScreen avisa y se sigue con 'Ejecutar de todas formas'.

**Prueba:** Instalar el build en una máquina limpia (Linux y Windows): arranca, guarda en `user://` cifrado y no incluye escenarios ni tests.

**Notas:** Skills: `godot:godot-export`. Decidido 2026-10-10: Windows y macOS van sin firmar; macOS sin probar (no hay Mac), se arreglan los reportes. 2026-10-11: build de Linux probado por el usuario (arranca, sin partidas para cargar). Falta probar Windows en una máquina limpia.

**Referencias:** `gdd.md#guardado`

**Relacionadas:** 10.22 Build web; 10.28 Playtest de revisión (lo que está en Revisión)

### 10.10 Publicar en itch.io y playtest · Pendiente

Cerrar el MVP: publicar el juego en itch.io para un grupo restringido, con instrucciones y una forma clara de reportar bugs, y observar una sesión de playtest con alguien que no lo vio, registrando lo que se encuentre.

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

**Relacionadas:** 10.22 Build web

### 10.11 UI restante a escenas · Hecho

**Prioridad:** media · **Etiquetas:** `ui`

Pasar a escenas `.tscn` la UI que todavía se arma por código (filas de stats, pestañas Equipo y Mapa, corazones), como pide la regla de que los scripts solo llenen datos, y un test que impida volver a crear Controls con `.new()` en `src/ui`.

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

`Targeting.targeting_range` pisa en `_ready` el radio de la forma del detector, así que cambiarla en el editor no tiene efecto. Dejar una sola fuente para el rango de fijado y que el inspector muestre el valor real.

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

Sacar código de UI que reemplaza lo que el tema ya resuelve, empezando por el ▶ de `MenuItem` (que puede ser el ícono del tema), y revisar el resto de los scripts de UI por lo mismo, sin cambios visuales.

- [x] MenuItem sin script: ▶ por ícono del tema
  MenuItem/icons/icon = textura ▶, icon_normal_color/hover alpha 0, icon_focus_color dorado. Borrar label/_refresh y usar text directo; adaptar escenas y tests que usan .label.
- [x] Revisar el resto de scripts de UI por lo mismo
  Candidatos: SlotCard._paint (variaciones según foco/vacía), pestañas de la pausa (TabLabel/TabLabelSelected), HintBar, ConfirmDialog, modulate de fichas.
- [x] Suite verde y capturas sin cambios visuales

**Notas:** Código que reemplaza algo que el tema ya resuelve. MenuItem quedó sin script: ▶ = MenuItem/icons/icon con icon_normal_color alpha 0 e icon_focus/hover dorados; hover se ve como foco. Revisado el resto: SlotCard (vacía/llena), pestañas y modos de FileSelect dependen de estado, no de foco; se quitó slot.text = "" en Equipo y el botón DEBUG pasó a la variación DebugButton.

### 10.14 Cámara: sala entera y pared sur recortada · Hecho

**Prioridad:** alta · **Etiquetas:** `camara`

Que una sala del templo de 22 × 14 m entre entera en pantalla, alejando la cámara, y que la pared sur no tape lo que pasa adentro, recortándola con un shader de corte.

- [x] Alejar la cámara para que entre una sala de 22 × 14 m
- [x] Recortar la pared sur con un shader de corte
- [x] Capturas, tests y GDD

**Notas:** offset (0, 17.4, 10.0): vista ≈ 26 × 14.5 m. data/kits/shaders/cutaway.gdshader en wall.tres y column.tres; la cámara pasa cut_area/cut_height al entrar a cada sala.

### 10.15 Interruptores de piso: solo un bloque los resuelve · Hecho

**Prioridad:** media · **Etiquetas:** `puzzles`

Que los interruptores de piso de los puzzles se resuelvan con un bloque y no solo pisándolos: un modo `BLOCK` en el que el player los aprieta mientras está encima y la puerta se vuelve a cerrar al bajarse.

- [x] Modo BLOCK en FloorSwitch: el player sostiene, el bloque resuelve
- [x] Gate.stays_open y close(); temple: Vestíbulo y Puzzle en BLOCK
- [x] Tests, prueba en el templo y GDD

**Notas:** ONCE sigue disponible (overworld y mazmorra gris lo usan); se elige por puzzle.

### 10.16 Mostrar con la cámara lo que activa un interruptor · Hecho

**Prioridad:** media · **Etiquetas:** `camara`, `puzzles`

Cuando un interruptor abre algo lejos del player, que la cámara lo muestre: pausa, se acerca al objetivo, lo abre y vuelve. Opcional por puerta o reja, solo la primera vez y nunca al cargar partida.

- [x] TopDownCamera.reveal: pausa, se acerca, abre, vuelve
- [x] reveal_on_open opcional en Door y Gate (solo la primera vez)
- [x] Sin reveal al cargar partida; tests, captura y GDD

### 10.17 Enemigos quietos en el overworld · Hecho

**Prioridad:** alta · **Etiquetas:** `ia`

Con la cámara más alejada, los enemigos del overworld se quedan quietos estando en pantalla o se traban. Que vean al player a la nueva distancia, naveguen sin atascarse en las esquinas y ninguno aparezca encimado con paredes o cercos.

- [x] Visión 12 m por la cámara más amplia
- [x] Skeleton2 fuera del cerco y test de enemigos encimados
- [x] path_desired_distance 1.0 por la navmesh a 0.5 m

### 10.18 Idiomas: inglés y español · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `ui`

El juego en inglés y español: todos los textos por clave con `tr()`, la elección de idioma la primera vez que se abre y un selector en Opciones que cambie en vivo, dejando fácil sumar otro idioma.

- [x] Sistema de traducción con TranslationServer
  Archivo de traducciones (CSV o .po) con es y en; los textos se piden por clave con tr(). Por ahora solo esos dos idiomas, pero que sumar otro sea agregar una columna o archivo.
- [x] Pasar todos los textos a claves
  UI, menús, HUD, carteles, diálogos, nombres y descripciones de ítems (data/), item get, game over. Nada de texto suelto en escenas ni scripts.
- [x] Elegir idioma la primera vez que se abre el juego
  Pantalla (escena .tscn en el MenuStack) antes del título, solo si settings.cfg no tiene idioma. Arranca preseleccionado el idioma del sistema (OS.get_locale_language) si es es o en. Hace falta su mockup en el canvas de UI.
- [x] Idioma en Opciones
  Selector en OptionsPanel (título y pausa), guardado en user://settings.cfg con Settings; cambia en vivo sin reiniciar.

**Prueba:** Borrar settings.cfg y abrir el juego: pide idioma antes del título. Elegir inglés: todo el juego (menús, HUD, ítems, diálogos) en inglés. Cambiar a español desde Opciones en la pausa: cambia al instante y se mantiene al reiniciar. Un test recorre las claves y falla si alguna falta en algún idioma.

**Notas:** Skills: `disciplines:game-ui-ux`, `disciplines:dialogue-systems` (hooks de localización).

**Referencias:** `gdd.md#ui`

**Bloqueada por:** 10.4 Opciones

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.19 Fin de la demo · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Etiquetas:** `ui`

Al vencer al jefe el portal es la única salida, y entrar abre un diálogo de fin de demo con opciones (seguir jugando, revancha contra el jefe o volver al menú), apoyado en respuestas nuevas en el `TextBox`. Sin pantalla de créditos.

- [x] Quitar el final al tomar el contenedor
  Hoy Ending.open() salta al tomar el contenedor de corazón (boss_arena.gd _on_reward_taken). Sacarlo de ahí: tomar el contenedor es solo el item get.
- [x] Vencer no reabre la puerta: el portal es la única salida
  Sacar door.open() de _on_death_finished y que _already_won (cargar la partida en la arena) también la deje cerrada. No se vuelve a la sala anterior.
- [x] El portal del jefe dispara el fin de la demo
  Al entrar al BossExitPortal (required_flag te_boss_defeated, en levels/templo.tscn) se abre la pantalla de fin en vez de viajar directo. Guardar checkpoint antes, así el progreso del jefe queda.
- [x] Respuestas en el TextBox: diálogos con opciones
  Hoy TextBox ignora line.responses. Al terminar una línea con respuestas, mostrar la lista dentro del globo (nodos en text_box.tscn, no por código), navegable con gamepad/teclado, foco en la primera; elegir sigue con response.next_id. Respuestas con condición ocultas. Sirve para cualquier NPC o cartel con preguntas.
- [x] Diálogo de fin de demo: seguir, revancha o menú
  data/dialogue/ending.dialogue (es/en en translations): "Fin de la demo, gracias por jugar" con respuestas Seguir jugando (cierra y completa el viaje del portal al overworld, ver 11.29), Volver a retar al jefe y Volver al menú principal (guarda y quit_to_title, vía mutation o señal). Reemplaza la pantalla Ending actual.
- [x] Revancha contra el jefe
  Recarga la arena con el jefe vivo aunque te_boss_defeated esté en true (modo revancha en BossArena, no se borra el flag ni se guarda nada a mitad). Puerta cerrada e intro como siempre; morir reinicia la revancha. Al ganar no reaparece el contenedor (te_heart_container) y el portal vuelve a abrir el diálogo de fin.
- [x] Mockup del diálogo de fin de demo en el canvas de UI
- [ ] Breve epílogo (opcional)
  Si entra en la demo: cámara sobre el templo calmado o el overworld sin doom antes del diálogo; corto y salteable.

**Prueba:** Desde pre_boss: vencer al jefe y tomar el contenedor no corta el juego ni reabre la puerta; el portal es la única salida y abre el diálogo de fin de demo. Seguir jugando lleva al overworld con el progreso guardado; Volver a retar recarga la pelea completa y al ganar no da otro contenedor; Volver al menú va al título y al cargar el jefe no reaparece.

**Notas:** El fin ya no salta al tomar el contenedor: el jugador puede quedarse en la arena y decide cuándo terminar entrando al portal.

**Referencias:** `gdd.md#jefe`, `gdd.md#ui`

**Relacionadas:** 10.20 Intro / cutscene de apertura; 10.28 Playtest de revisión (lo que está en Revisión); 11.29 Overworld después del jefe

### 10.20 Intro / cutscene de apertura · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `camara`

Una intro corta y salteable al empezar partida nueva que cuente sin diálogos que El Ojo despierta, sobre un sistema simple de cutscenes que también sirva para la intro del jefe y el epílogo. Solo la primera vez.

- [x] Guion corto de la intro
  Según la historia del GDD (El Ojo despierta, opción A): sin diálogos, se cuenta con imagen y alguna tablilla/texto breve. Decidir duración (30–60 s) y planos.
- [x] Sistema simple de cutscenes
  Secuencia de planos de cámara, esperas, textos y eventos (AnimationPlayer o una lista de pasos), reutilizable para la intro del jefe y el epílogo de 10.19. Salteable con aceptar.
- [x] Armar la intro
  Al empezar partida nueva, antes de darle el control al player. Solo la primera vez (flag en la partida); opción de volver a verla no hace falta.

**Prueba:** Partida nueva: corre la intro, se puede saltear, termina dando el control al player en el overworld. Cargar la partida: no se repite.

**Referencias:** `gdd.md#historia`

**Relacionadas:** 10.19 Fin de la demo; 10.30 Afinar la intro a ojo; 11.22 Tablillas de historia

### 10.21 Título y ranuras: Continuar, Nueva partida y ranura de autosave · Hecho

**Prioridad:** alta · **Etiquetas:** `ui`

Hoy Continuar y Nueva partida abren los dos la selección de ranuras. Continuar tiene que cargar directo la última partida, Nueva partida elegir dónde crearla, y el autosave pasa a una ranura propia (Auto) que no pise las partidas manuales.

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

### 10.22 Build web · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** baja · **Etiquetas:** `build`

Un build web para jugar en el navegador desde itch, sin threads y con renderer Compatibility: que LimboAI corra, el juego se vea parecido al de escritorio y el guardado sobreviva a recargar. Prioridad muy baja: el escritorio va primero.

- [x] Preset Web
  Preset 'Web' en export_presets.cfg (2026-10-11): sin threads (corre en itch sin COOP/COEP), extensiones encendidas para LimboAI, renderer Compatibility. Falta agregarlo a tools/build.sh. Primera prueba local: anda mejor de lo esperado; se pierde lo que solo existe en Forward+.
- [x] LimboAI para web
  liblimboai.web.template_release.wasm32.nothreads.wasm ya está (gdextension oficial de LimboAI 1.8.1, como los de escritorio en 10.9); falta probar que los BT del jefe y los enemigos corren en el navegador.
- [x] Revisar el juego en Compatibility
  El escritorio usa Forward+: comparar el cutaway del templo, la emisión de la paleta, tonemap, niebla/doom, sombras y las cáusticas (projector + DrawableTexture). Lo que no ande, un fallback para web.
- [x] Navegador
  Guardado en user:// (IndexedDB) persiste al recargar; el audio arranca tras el primer clic; gamepad y teclado; pantalla completa; tamaño del .pck y tiempo de carga.

**Prueba:** Abrir el build en Chrome y Firefox desde itch: carga en un tiempo razonable, se juega el overworld y el templo hasta el jefe con gamepad y teclado, el guardado sobrevive a recargar la página y se ve parecido al build de escritorio.

**Notas:** Skills: `godot:godot-export`. Prioridad muy baja (2026-10-11): el escritorio va primero. El preset Web ya existe y la primera prueba local anduvo bien; lo pendiente es sumar la web a build.sh, reemplazos para lo que solo existe en Forward+ y publicar.

Esto fue un test

**Relacionadas:** 10.9 Build para playtesters; 10.10 Publicar en itch.io y playtest

### 10.23 Tests en paralelo · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** media · **Etiquetas:** `herramientas`

La suite de tests tarda unos 9 minutos en serie. Correrla en varios procesos headless en paralelo, cada uno con su `user://` aislado, para que termine en menos de la mitad del tiempo con los mismos resultados.

- [x] Runner en paralelo
  run_tests.gd reparte los archivos test_*.gd en N procesos headless (por defecto, los núcleos disponibles, máx. 4), balanceados por la duración de la última corrida; junta resultados y sale con 1 si algo falla.
- [x] Aislar user://
  Cada proceso con su carpeta de partidas y de opciones (test_saves_<n>, test_settings_<n>.cfg) para que no se pisen.
- [x] Medir y documentar
  Comparar contra la corrida en serie (~9 min); README/gdd con el comando y cómo correr un solo archivo.

**Prueba:** Correr la suite completa: termina en menos de la mitad del tiempo en serie, con los mismos resultados, y dos corridas seguidas dan lo mismo.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.24 Tope de FPS · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `rendimiento`

Medido 2026-10-11: con monitor de 200 Hz y vsync sin tope el juego dibuja 200 FPS aunque cada cuadro le cueste ~1,2 ms a la GPU (RX 580: 82 W promedio, picos de 120 W, contra 68 W con tope 60). Engine.max_fps 60 por defecto y opción en el menú (30/60/120/sin límite) armada en la escena de opciones.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.25 Sombras del sol acordes a la cámara cenital · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Etiquetas:** `rendimiento`

El Sun de overworld y temple usa el default de Godot (PSSM de 4 cascadas hasta 100 m): la geometría se vuelve a dibujar por cada cascada y el overworld llega a ~900 mil triángulos por cuadro con 418 mil en escena. Probar 2 cascadas (u ortogonal) con distancia máxima acorde a la cámara; comparar capturas antes/después.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.26 Paredes del GridMap más livianas · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Etiquetas:** `rendimiento`, `arte`

El 80 % de los triángulos son paredes: Acantilado 1224 tri por celda (211 celdas, 258 mil) y Pared del templo 816 (252 celdas, 206 mil). Bajar el detalle en build_lugares.py sin perder el look. Las mallas del GridMap no tienen LOD (se guardan a .res sin generarlo) y el GridMap agrupa en octantes de 8 celdas (16×16 m), así que el frustum culling es por bloque: medir también cell_octant_size 4. Occlusion culling no vale la pena con cámara cenital.

**Notas:** Godot 4.8 trae mip-level texture streaming (dev 5, GH-113429; se activa en Project Settings con reinicio del editor, runtime vía el singleton TextureStreaming). Hoy no aporta: casi todo se pinta con la paleta y el overworld usa ~270 MB de VRAM. Considerarlo si entran texturas grandes (terreno texturizado, estilo con más detalle).

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.27 Nodos creados por código pasan a sus .tscn · Revisión

**Prioridad:** media · **Etiquetas:** `arquitectura`

Regla (2026-10-11): todo lo que hereda de Node va en la escena, no con X.new() + add_child, para poder retocarlo en el inspector; el código solo ajusta lo que depende del juego. Lo que spawnea en runtime se instancia desde una escena (p. ej. un proyectil con su Trail3D). Pendientes: top_down_camera (máscara de sala), aim (MeshInstance3D de la mira), player (cono de bloqueo), item_get (OmniLight3D), chest (MeshInstance3D x2, Node3D), light_beam (MeshInstance3D x2), room (MeshInstance3D), overworld_map (Node3D, MultiMeshInstance3D), spawn_point (Area3D + CollisionShape3D), enemy (CollisionShape3D de los pedazos), liftable (CollisionShape3D, ThrownObject), doom_ambience (GPUParticles3D, Decal), boss_hand (Decal), feel (CPUParticles3D, MeshInstance3D, AudioStreamPlayer/3D: pasar a escenas de efecto instanciables), music (AudioStreamPlayer), y los PersistentFlag/Wiring/HitFlash que se agregan como hijos (door, chest, cracked_wall, portal, floor_switch, eye_switch, light_receiver, wave_spawner, wiring, hit_flash). Revisar cada caso: lo que es puro dato no cambia.

- [x] Tanda 1: cofre, haz de luz, cámara, mira, item get
  Cofre: Model/Base/Lid en chest.tscn (el arca grande cambia las mallas). Haz: beam_segment.tscn + %Tip en light_source.tscn, material en beam_material.tres. La máscara de la cámara ya se instanciaba de room_mask.tscn; la mira y la luz del item get ya no se crean por código. El contorno de Room es dibujo solo del editor: queda.
- [x] Tanda 2: PersistentFlag, Wiring y HitFlash como hijos en las escenas
  PersistentFlag es un nodo PersistentFlag en door, chest, cracked_wall, floor_switch, eye_switch, light_receiver, warp_portal y bajo ArenaWaves del templo; el dueño le copia su flag en _ready (PersistentFlag acepta el flag tarde). Los portales sueltos de los niveles no tienen flag. HitFlash es un nodo con health y visuals exportados en enemy, turret, boss (ojo y cada mano) y player (bajo Visuals); se fue HitFlash.attach. Wiring es RefCounted: no aplica.
- [x] Tanda 3: efectos de Feel, música y doom
  Ráfagas: una escena por tipo en src/feel/bursts/ (sparks, sparkle, explosion, shards, leaves, dust; lo desconocido usa dust), horneadas con los valores de antes. Onda de la explosión: src/feel/shockwave.tscn. Sonidos: sfx_player.tscn (3D, bus SFX) y ui_sound.tscn (bus UI); el stream sigue saliendo del código. Música: el autoload es src/audio/music.tscn con una capa por hijo. Doom: doom_ambience.tscn con DoomDust y LegibleLight (el templo lo instancia), grietas desde doom_crack.tscn. Grieta del golpe del jefe: slam_crack.tscn.
- [x] Tanda 4: resto del mundo
  spawn_point.tscn trae el área Checkpoint (radio en la forma); los dos checkpoints del overworld son instancias, los demás puntos siguen siendo Marker3D sueltos. Pedazo de armadura: src/entities/armor_piece.tscn. Cuerpo de lo levantado: thrown_object.tscn (capas, CCD y amortiguación en la escena; el radio lo pone cada Liftable). Mapa: %GridCopy en overworld_map.tscn y una map_piece.tscn por malla.
- [x] Tanda 5: player (cono de bloqueo)
  BlockCone (bajo ModelController), Reticle y AimArrow (bajo Aim) e ItemGetLight en player.tscn; el código solo arma la malla del cono (según block_angle_deg) y la de la flecha. Se fue flash_color de ItemGet: el color está en la luz.

**Prueba:** Jugar un rato: cofres (chico y grande), haz de luz y espejos, puertas con llave, interruptores, oleadas de la arena, bombas y explosiones, golpes a enemigos y al jefe (destello), levantar y tirar vasijas, armadura del esqueleto, mapa del overworld, música por zonas y doom del templo se ven y suenan como antes. Con el overlay de debug (1): cono de bloqueo y flecha de apuntado. En el editor, esos nodos aparecen en sus escenas.

### 10.28 Playtest de revisión (lo que está en Revisión) · En curso

**Prioridad:** alta · **Etiquetas:** `playtest`

Recorrido para revisar de a una las tareas en Revisión, en el orden de una partida. Antes: borrar ~/.local/share/godot/app_userdata/Project Epiphany/settings.cfg y empezar partida nueva. Al confirmar un paso, la tarea vinculada pasa a Hecho.

- [x] Idiomas (10.18)
  Pide idioma antes del título; en inglés menús, HUD, ítems y diálogos; Opciones → español cambia al instante y se mantiene al reiniciar.
- [x] Tutorial (11.45)
  Tablitas del claro: moverse, atacar, rodar, bloquear, fijar, interactuar; los íconos cambian entre teclado y control.
  Funcionan, pero no es la mejor forma de tutorial. Hay que revisarla
- [x] Levantar y tirar (11.44)
  Piedra → placa → reja → cofre. Vasija: caminás más lento, se rompe al tirarla y suelta loot, daña enemigos.
- [x] Agujero de la cámara (11.53)
  Junto al árbol del sendero no aparece; detrás de una pared se abre suave y se cierra al salir.
- [x] Minimapa (11.37)
  Se destapa al caminar, se apaga desde Opciones; en el templo sigue sala a sala y coincide con la pestaña Mapa.
- [x] Pared agrietada y zonas tapadas (11.51, 11.52, 11.54)
  Mismo grosor y color que el muro, solo grietas; lo de atrás tapado; al volarla se descubre sin frenarte. Desde el inicio del claro no se ve el labio de pasto ni la pared de más allá (11.54).
  No debería verse como una zona cuadrada sin explorar, ni en el minimapa ni en el overworld
- [x] Bombas (11.43)
  Toque: a los pies. Mantener: levanta y apunta, soltar tira en parábola; la mecha sigue corriendo.
- [x] Combate (11.33, 11.49, 11.25, 11.41)
  3 chullpas: respuesta instantánea, rodar/bloquear al final del tajo; VFX por acción; arquero y esqueleto con armadura telegrafían; el escudo del esqueleto bloquea solo de frente y levantado, con chispa y retroceso.
- [x] Arco (11.42)
  Al mantener, la cuerda se tensa con la flecha; al soltar vuelve de golpe.
- [x] Item get (11.48)
  Cofre grande: levanta el ítem con las dos manos.
- [x] Decoración (11.3, 11.4)
  Cada zona se reconoce sin el cartel; el templo se arruina hacia el jefe; nada tapa caminos ni interactivos.
- [x] Templo: puertas y rejas (11.51)
  Puertas y rejas llenan el grosor del muro, una reja en cada borde.
- [x] Jefe (11.47)
  Dedos que abren y cierran continuo; abren antes de agarrar, aprietan al sostener, caen flojas al vencerlas.
- [x] Build en máquina limpia (10.9)
  Linux y Windows: arranca, guarda cifrado en user://, sin escenarios ni tests.
- [ ] Cerrar 10.8 y 10.23; rendimiento (10.24–10.26)
  10.23 verificada (~16 s, estable). 10.8 la reemplazan 10.24–10.26: en Opciones, Tope de FPS (30/60/120/sin tope) cambia al instante y se guarda; las sombras del sol y las paredes se ven igual que antes, sin tirones. Las tarjetas 10.8, 10.23 y 10.24–10.26 ya están cerradas; falta solo la pasada de Daniel.
- [x] Cuerpos (11.58)
  Un enemigo muerto queda 4 s, se hunde en el piso con polvo y desaparece; lo que soltó queda; las salas y oleadas siguen abriendo al morir el último.
- [ ] Controles y pestaña Sistema (10.29)
  Opciones → Ver controles: el diagrama del control que estés usando; Y (o T) cambia entre gamepad y teclado. Pausa → Sistema: a la derecha los controles; Guardar pisa la partida cargada (pregunta antes); Cargar te deja elegir el último checkpoint o el guardado; volver al título pregunta. Los botones tienen recuadro. La tarjeta 10.29 ya está cerrada; falta solo la pasada de Daniel.
- [ ] Fin de la demo (10.19)
  Escenario pre_boss: vencé al jefe; tomar el contenedor no corta el juego y la puerta queda cerrada. Entrá al portal: diálogo 'Fin de la demo' con tres respuestas (stick/flechas, A). Probá Volver a retar (pelea completa, sin otro contenedor), Seguir jugando (overworld con el progreso) y Volver al menú (al cargar, el jefe no está).
- [x] Intro (10.20): Nueva partida desde el título corre la intro (4 planos, textos, temblor y brillo rojo en el templo); mantener A la saltea, un toque no; al terminar la cámara vuelve sola y el player se mueve; cargar o continuar no la repite. Afinar a ojo duración de planos, brillo y temblor
  Funciona! pero quedó desactualizado con el nuevo diseño del overworld
- [ ] Nodos en escena (10.27): todo se ve y suena como antes (cofres, haz de luz, puertas, interruptores, oleadas, explosiones, destello de daño, vasijas, armadura del esqueleto, mapa, música, doom); con el overlay (1), cono de bloqueo y flecha. Abrir chest.tscn, light_source.tscn, player.tscn y src/feel/bursts/ en el editor y ver que se pueden retocar
- [x] Pluma (11.35)
  Templo: la sala de la pluma (debajo de la agrietada) se entiende sin explicación; la zanja se lee como 'rodear ahora, saltar después'. La fila de huecos del Puzzle se ve desde la puerta y no hay forma de caer al entrar. El salto (alto 0,68, velocidad 4, control en el aire 2, en player/states/jumping.gd) se siente bien y la sombra deja calcular dónde cae. Risco: el abismo de 4 m se lee como 'solo flechas'.
- [x] Pluma en el overworld (11.61)
  La pieza de corazón arriba del escalón de la pradera se ve como cebo antes de tener la pluma. La grieta entre la entrada del templo y el Risco se lee como paso saltable desde los dos lados (se ve un hueco oscuro entre los acantilados); caer devuelve del lado del templo.

**Notas:** Playtest del 2026-10-12 (Daniel): hallazgos en 11.90–11.107, 7.9 (zonas inaccesibles) y 14.9 (pantalla de carga); co-op aparte en 13.15. Quedan sin probar rendimiento, controles y pestaña Sistema, fin de la demo y nodos en escena.

**Relacionadas:** 10.18 Idiomas: inglés y español; 11.45 Tutorial de controles y mini puzzle por ítem; 11.44 Levantar y tirar objetos; 11.53 Agujero de la cámara solo donde tiene sentido; 11.37 Minimapa en el HUD; 11.51 Pared agrietada que se integre al muro; 11.52 Zonas tapadas hasta abrirlas; 11.43 Bombas: tocar coloca, mantener apunta y tira; 11.33 Combate: sacar lo tosco; 11.49 VFX de combate; 11.25 Nuevos enemigos con los modelos existentes; 11.41 Esqueleto con escudo: bloquear con el escudo delante; 11.42 Arco que se tensa; 11.48 Pose de item get; 11.3 Decorar las salas del templo; 11.4 Decorar el overworld; 11.47 Manos del jefe animadas (shape keys); 13.1 Código listo para varios players; 13.2 Input por jugador y unirse a la partida; 10.9 Build para playtesters; 10.8 Pasada de rendimiento; 10.23 Tests en paralelo; 13.3 Cámara y salas para dos; 13.5 HUD de dos jugadores; 10.29 Pantalla de controles; 13.6 Player 2 con su color; 10.24 Tope de FPS; 11.58 Los enemigos muertos desaparecen después de un rato; 11.54 El velo de zona tapa también las paredes que la rodean; 10.25 Sombras del sol acordes a la cámara cenital; 10.26 Paredes del GridMap más livianas; 10.19 Fin de la demo; 13.4 Reglas del co-op; 13.9 Anillo de ítems por player

### 10.29 Pantalla de controles · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `ui`, `input`

Como la de Basic Controls de TotK: el mando dibujado con una línea a cada botón y lo que hace (mockups Controls_Gamepad y Controls_Keyboard). LB/RB cambia entre mando y teclado/mouse. Se abre desde el título (Opciones › Controles); en la pausa va dentro de la pestaña Sistema, junto a Guardar/Cargar/Opciones/Volver al título (Pause_System).

- [x] Escena desde el mockup
  Controls_Gamepad: mando dibujado, cajas a los costados con líneas; Controls_Keyboard: grupos Moverse, Combate, Ítems, Menús. Íconos de Kenney Input Prompts.
- [x] Textos desde el InputMap
  Cada caja lee los eventos de su acción (InputPrompts), así si cambia una asignación la pantalla la sigue.
- [x] Entradas
  Título › Opciones › Controles abre la pantalla completa, por MenuStack. En la pausa, la pestaña Sistema (mockups Pause_System y Pause_System_Keyboard): a la izquierda Guardar, Cargar, separador, Opciones y Volver al título; a la derecha los controles básicos del dispositivo en uso, con Y (T en teclado) para ver el otro. Guardar muestra la partida cargada y pide confirmar: siempre guarda sobre esa ranura (Pause_System_Save). Cargar muestra el último checkpoint (Auto) y lo último guardado a mano de la partida cargada; se elige con el stick (checkpoint por defecto) y A confirma (Pause_System_Load). B vuelve a los controles.
- [x] Tests y GDD

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.30 Afinar la intro a ojo · Pendiente

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `camara`

Ajustes de sensación de la intro de 10.20 (src/cutscene/intro.tscn), a ojo en el editor: el sistema y la intro ya andan.

- [ ] Duración y encuadre de los planos
  Pistas Camera:position y Camera:rotation de la animación play. Los cortes (6, 14 y 20 s; ~25 s en total) son de los planos viejos: los planos se rehicieron para el overworld nuevo (69b544fc, 1f791fc9), revisar los tiempos contra los nuevos. Que los textos INTRO_1–4 alcancen a leerse.
- [ ] Brillo rojo de la entrada del templo
  Pista TempleGlow:light_energy (pico 16, a pleno sol se nota poco) y posición/alcance del OmniLight TempleGlow.
- [ ] Temblor y polvo
  Pista de métodos: tremor(0.6/0.35/0.5) y dust en TempleDust/ClearingDust; en Cutscene: trauma_decay y max_shake.
- [ ] Qué se ve en los planos
  Escrito para los planos viejos (esqueletos en el prado, borde vacío del mapa a la izquierda); los planos se regeneraron con el overworld nuevo (69b544fc, 1f791fc9). Volver a mirar los planos nuevos y decidir si hay algo que reencuadrar u ocultar durante la intro.
- [ ] Vuelta a la cámara de juego y salteo
  settle_time (1,2 s) y skip_hold (0,8 s) en Cutscene.

**Prueba:** Partida nueva desde el título: la intro se lee cómoda, el templo se ve encenderse, el temblor se siente sin marear y lo que se ve en cada plano es intencional.

**Relacionadas:** 10.20 Intro / cutscene de apertura

### 10.31 Videos de presentación y trailer/teaser · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `marketing`, `video`

Grabar videos para presentar el juego. Pensar un trailer o teaser corto para generar expectativa (aunque muestre más de lo que hay todavía): planos del overworld, entradas de las mazmorras, pelea con un jefe, el templo del ojo.

- [x] Elegir qué mostrar y armar un guion corto (30–60 s)
  Daniel (2026-10-16): 30–45 s, misterio → acción. Overworld calmo con planos de cámara, título, cortes cada vez más rápidos en el templo (última mazmorra), cierra en el ojo del jefe y el logo. Música del juego (overworld, después templo/jefe). HUD visible solo en tomas con la cámara normal del juego; en otros ángulos, oculto.
- [x] Modo de captura: sin HUD/debug, cámara libre o con rieles para planos
  Daniel (2026-10-16): todo automático primero: la secuencia guionada como datos (tomas con escenario, cámara del juego o riel, HUD, acciones del player en el tiempo) y un director que la corre; cada toma se renderiza con Movie Maker (--write-movie, 60 fps fijos) en su propio archivo. Después, la misma secuencia en tiempo real con gpu-screen-recorder.
- [ ] Grabar los planos y editar el teaser
  Primera versión (b343f5ce): tools/teaser/record.sh graba las 12 tomas de teaser.tscn (Movie Maker, 1080p60, ~4,5 min) y tools/teaser/edit.sh arma debug/tmp/teaser/teaser.mp4 (40,8 s: overworld 13,5 s con calma, templo 13 s con capas de mazmorra, jefe 11 s con todas, cierre con el título en Cinzel). Las tomas, el corte (CUTS en edit.sh) y la música se cambian y se vuelve a correr. Falta: que Daniel lo vea y ajustar; probar la misma secuencia con gpu-screen-recorder (no está instalado).

## M11 — Pulido: contenido y feel  (221/221, 62 en revisión)

Vestir el templo y el overworld, más enemigos, trampas, un doom legible, feel de combate y del jefe y los detalles técnicos de la revisión del 2026-10-09. El arte nuevo va a M12.

**Hecho cuando:**
- Ninguna sala ni zona se ve de prototipo o vacía.
- El player y lo interactivo se leen bien con el doom.

### 11.1 Importar KayKit Dungeon Remastered y Medieval · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`

Traer al proyecto los packs KayKit Dungeon Remastered y Medieval (modelos, texturas y licencia) para tener piezas con qué vestir el templo y el overworld, que hoy se ven de prototipo.

- [x] Bajar de GitHub e importar (modelos, texturas y licencia)

### 11.2 Kit del templo con piezas KayKit · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`

Armar un kit del templo con piezas KayKit que reemplace al kit gris: mismos ítems y colisiones que `gray_kit`, para que las salas dejen de verse de prototipo sin rehacer los niveles.

- [x] Generador tools/build_temple_kit.gd → data/kits/temple_kit.tres (mismos ítems/colisiones que gray_kit)
- [x] Shader cutaway con use_uv + materiales kaykit_stone/kaykit_floor y atlas compartido
- [x] Templo usa el kit nuevo con 4 variantes de piso (~15 % de celdas)
- [x] Suite completa (181, solo falla el test conocido de player.tscn) y capturas de las 9 salas
- [x] GDD §10.1 actualizado

**Notas:** Paredes con wall_half estiradas a 3.1 m de alto; columna pillar escalada. El overworld sigue con el kit gris. Las esquinas entre la columna y la pared dejan ver el vacío (rojo con el doom); se puede tapar en 11.3.

### 11.3 Decorar las salas del templo · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Etiquetas:** `arte`

Decorar las 9 salas del templo con estandartes, braseros, escombros y venas del doom, para que se vean habitadas y distintas y la ruina crezca hacia el jefe, sin tapar el camino ni lo jugable.

- [x] Generador de decoración
  tools/decorate_levels.gd lee el GridMap, las salas y lo jugable, y escribe levels/decor/temple_decor.tscn (determinístico, se regenera); el nivel solo lo instancia.
- [x] Estandartes, braseros y escombros
  Estandartes en las paredes norte y laterales (menos cuanto más doom), braseros en las esquinas de las salas grandes, escombros contra las paredes y vasijas rotas; nada en el paso, en puertas, pozos ni encima de lo jugable.
- [x] Venas del doom
  Venas rojas en el piso de las salas con doom alto (Arena en adelante), que suben con la tensión.
- [x] Capturas y rendimiento
  Fotos de las 9 salas antes y después; profile_scenes.gd sigue dentro del presupuesto.

**Prueba:** Cada sala se ve habitada y distinta, la decoración crece en ruina hacia el jefe, nada tapa el camino ni lo jugable y el rendimiento sigue en presupuesto.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión); 12.7 Kit del templo propio

### 11.4 Decorar el overworld · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Etiquetas:** `arte`

Decorar cada zona del overworld con piezas propias de su ambiente y enmarcar la entrada del templo con su fachada, para que cada zona se reconozca sin su nombre y deje de verse vacía.

- [x] Decoración por zona
  Con el mismo generador (levels/decor/overworld_decor.tscn): fogata y tronco en el claro de inicio, apachetas en la pradera, troncos y cardones en la arboleda, rocas altas en el risco, estalagmitas y rocas en la cueva y la gruta, piedras en el santuario.
- [x] Fachada del templo
  fachada_templo detrás del sello, enmarcando la entrada.
- [x] Mapa y colisiones
  La decoración entra en el scenery de OverworldMap (sale en la foto del mapa) y las piezas altas tienen colisión.

**Prueba:** Cada zona se reconoce sin su nombre; nada tapa los caminos, las entradas ni lo jugable; la foto del mapa muestra la decoración.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión); 12.2 Terreno del overworld; 12.3 Lugares del overworld; 12.4 Vegetación y props del overworld

### 11.5 Galería de trampas: pinchos · Revisión

**Prioridad:** media · **Etiquetas:** `mazmorra`

Pinchos de piso a ritmo: avisan asomando, suben de golpe, lastiman a player y enemigos (el escudo no los frena) y bajan; en ola para cruzarlos con timing. Nacieron en la Galería (sala 3) del templo viejo, que se borró (072e1094); hoy están en el ala de la pluma del templo (PlumaSpikes) y en la cripta oscura de la Chullpa (CriptaSpikes, B-SO).

- [x] Piezas pinchos y pinchos_base
  build_templo.py: marco de hierro con nueve agujeros apoyado sobre el piso (no lo reemplaza) y nueve púas con el origen a ras del piso.
- [x] SpikeTrap
  src/world/spike_trap.tscn: period, up_time, offset, warn_time; Hitbox hits_all con elemento spikes; period 0 = siempre arriba.
- [x] Ola en la Galería
  GallerySpikes del templo viejo: columnas x=2 y x=4, z 42–54, offset 0.3 s por fila; la decoración las esquiva. Ese nivel ya no existe: la ola sigue en PlumaSpikes (levels/templo.tscn) y CriptaSpikes (levels/chullpa.tscn).
- [x] Tests y GDD
  tests/test_spike_trap.gd; fila de la sala 3 en el GDD.

**Prueba:** En el ala de la pluma del templo (PlumaSpikes) y en la cripta oscura de la Chullpa (CriptaSpikes, B-SO), cruzar los pinchos: se ve venir cada fila (asoma y tintinea), siempre queda un paso y pinchan al player y a los enemigos.

**Notas:**  Playtest 15/10: la nota es del playtest del 13/10; lo arregló 11.169 el 14/10 (pinchos ground_only y hits_on_landing: saltando con la pluma ya no pegan en el aire). Vuelve a revisión para probarla de nuevo. Playtest 17/10 (Daniel): el cofre de la llave chica de la Cripta oscura estaba detrás de los pinchos y se necesita antes de la pluma. af52d33e: el cofre pasó al lado de la entrada (22, 33), antes de los pinchos; test_chullpa camina la navmesh desde la Cripta sin pasar por ellos.

**Relacionadas:** 11.169 Galería de trampas: la pluma no salta por encima de los pinchos

### 11.6 Más enemigos en el overworld y el templo · Hecho

**Prioridad:** alta · **Etiquetas:** `ia`

El recorrido tiene zonas y salas vacías: repartir esqueletos, esqueletos con escudo y arqueros por el overworld y el templo para que haya pelea en el camino, dejando tranquilo el inicio y usando cada sala para enseñar algo (bombas contra el escudo, golpes que tiran al hueco).

- [x] Overworld: enemigos por zona, el inicio tranquilo
  Pradera, gruta, cueva, explanada del templo, risco y arboleda; el escudo y el arquero en las zonas más avanzadas.
- [x] Templo: hub, galería, sala agrietada y sala de ojos
  Cada uno usa la sala: el de escudo donde hay bombas, el de la sala de ojos del lado de la entrada para tirarlo al hueco.
- [x] Ninguno encimado con la grilla
  `test_enemies_do_not_spawn_inside_walls` en tests/test_enemy_ai.gd.
- [x] Anotar el reparto en el GDD
  [[gdd#combate]] › Dónde hay enemigos (11.6).

**Prueba:** Recorrer overworld y templo: todas las zonas salvo el inicio tienen pelea, ningún enemigo aparece dentro de una pared y los tests de IA pasan.

**Referencias:** `gdd.md#combate`

### 11.7 Doom legible: player y objetos sin teñir · Hecho

**Prioridad:** media · **Etiquetas:** `arte`

Con el doom alto el sol rojo, la niebla y las grietas tiñen todo y el player y los objetos se pierden en el piso. Tienen que conservar sus colores y su sombra para leerse sobre cualquier nivel de doom.

- [x] Capa visual legible
  Player y objetos en la capa 2; el sol rojo no la ilumina pero sí le deja proyectar sombra.
- [x] Luz neutra para lo legible
  LegibleLight: misma dirección que el sol, color calmo, solo la capa 2.
- [x] Sin niebla ni grietas sobre lo legible
  Copias de material con disable_fog (también lo que viste el equipo); las grietas excluyen la capa.

**Prueba:** En la antesala (doom 0.9), el player, la tablilla y las vasijas conservan sus colores sobre el piso rojo y siguen proyectando sombra.

### 11.8 Silueta del player detrás de paredes · Hecho

**Prioridad:** media · **Etiquetas:** `camara`

Cuando una pared tapa al player se pierde de vista. Mostrar su silueta por encima de lo que lo tapa, solo en las partes ocultas.

**Notas:** Overlay por stencil: hit_flash escribe el stencil donde el player se ve y occluded_silhouette (sin depth test) pinta en dorado solo donde no. Revisado detrás del jefe y bajo la máscara de la puerta norte del Hub. Test test_silhouette_only_on_the_player.

### 11.9 Navmesh sobre el piso · Revisión

**Prioridad:** baja · **Responsable:** project-epiphany-5c · **Etiquetas:** `ia`

La navmesh horneada del GridMap queda 0.5 m sobre el piso (y hay islas sueltas arriba de paredes y acantilados, a 3 m). Por eso el `NavigationAgent3D` de los enemigos necesita `path_desired_distance` 1.0 para no trabarse en las esquinas. Bajarla al piso y sacar la compensación.

- [x] Encontrar de dónde salen los 0.5 m
  El piso del kit gris tiene el techo de la colisión en y = 0, pero los vértices quedan en 0.5 (overworld y templo). Revisar cell_size/cell_height del NavigationMesh contra los del mapa de navegación (Project Settings › navigation), agent_max_climb y la posición del NavigationRegion3D.
- [x] Sacar las islas arriba de paredes y acantilados
  Hay polígonos a y = 3 sobre Pared y Acantilado. Un enemigo nunca llega ahí, pero ensucian el mapa y algún punto aleatorio o el más cercano puede caer arriba. Opciones: filter_baking_aabb, agent_max_climb o colisión de pared sin techo transitable.
- [x] Rehornear overworld, mazmorras y niveles de prueba
  Botón Bake de cada NavigationRegion3D (levels/overworld.tscn, templo.tscn, chullpa.tscn, quenoa.tscn, totora.tscn, cumbre.tscn, test.tscn, dungeon_test.tscn, test_rooms.tscn).
- [x] Volver `path_desired_distance` a 0.5 si ya no se traban
  src/entities/enemy.tscn › NavigationAgent3D. Probar persecución alrededor de columnas y esquinas de puerta.
- [x] Actualizar el GDD
  [[gdd#overworld-layout]] › Blockout (7.2) cuenta la compensación; dejar lo nuevo.

**Prueba:** Con Debug › Visible Navigation, la navmesh se ve pegada al piso y no hay islas arriba de las paredes; los enemigos persiguen alrededor de columnas y por las puertas sin quedarse girando en una esquina; test_enemy_ai pasa.

**Notas:** -5c (2026-10-19), pasos 1-2 en e0682a06. Los 0.5 m: Recast deja cada superficie dos cell_height arriba del techo de la colisión (piso en 0 → 0.5, paredes en 2.6 → 3.0 con 0.25; con 0.1 → 0.2 y 2.8); no es la posición de la región ni agent_max_climb. Con cell_height 0.05 el piso queda en 0.1 (hay que poner navigation/3d/default_cell_height = 0.05 junto con el rehorneado). Islas: WallTops (src/world/nav/wall_tops.gd), un parser de geometría registrado por epiphany_tools (Bake del editor) y bake_overworld_nav.gd, pone una obstrucción proyectada en el techo de cada celda del GridMap cuya caja sube una altura de agente (paredes, columnas, acantilados, árboles). Prueba en copia (debug/tmp/nav/templo_scratch.tscn): 171 vértices todos en 0.1, camino de punta a punta en 0.1, ningún punto más cercano sobre 200 paredes cae arriba. Chullpa: quedan solo los tres pisos. Overworld: las islas a 2.7 son del Terreno/Terrazas, no del GridMap; ver después de 16.49.

-5c (2026-10-19), paso 3 sin el overworld en 278e9416: cell_height 0.05 en levels/nav/*_navmesh.tres y en las navmesh de los niveles de prueba, navigation/3d/default_cell_height 0.05; mazmorras, cuevas y levels/test.tscn rehorneados con la herramienta, pisos en 0.1. El .tres del overworld solo tiene cell_height 0.05 (para coincidir con el mapa); falta rehornearlo después de 16.49. Paso 4: con la navmesh nueva hace falta path_desired_distance 0.25 (con 0.5 y 1.0 el esqueleto da por alcanzada la esquina de la columna y se traba contra ella); pero 0.5 o menos deja trabados a los esqueletos de la pradera mientras el overworld siga a 0.5 m del piso. enemy.tscn y atoq.tscn siguen en 1.0; test_an_enemy_goes_around_a_column le pone 0.25 a su agente. Cuando se rehornee el overworld: 0.25 en enemy.tscn y atoq.tscn y sacar eso de la prueba.

-5c (2026-10-20), pasos 3-5: overworld rehorneado después de 16.49 con la herramienta (4931 vértices, 4858 a 0.1 m del piso de colisión y el resto entre 0 y 0.3 en pendientes, ninguno arriba de paredes o acantilados); path_desired_distance 0.25 en enemy.tscn y atoq.tscn, la prueba ya no se lo pone; GDD › Blockout al día. Suite 708/0.

**Referencias:** `gdd.md#overworld-layout`

**Archivos:** `src/entities/enemy.tscn`, `levels/overworld.tscn`, `levels/templo.tscn`, `levels/chullpa.tscn`, `levels/quenoa.tscn`, `levels/totora.tscn`, `levels/cumbre.tscn`

### 11.10 Warning de transform singular en la suite · Hecho

**Prioridad:** baja · **Etiquetas:** `tecnico`

La suite de tests tira un warning de transform singular. Encontrar de dónde sale y sacarlo, para que la suite quede limpia.

**Notas:** 2026-10-09: eran los StaticBody de los dos escudos del player. El AnimationTree arrancaba inactivo (se activaba al entrar a Idle) y, desde la segunda carga de escena, el primer cuadro fundía desde una pose con escala 0: la mano quedaba con escala cero y Jolt avisaba. Arreglo: el AnimationTree arranca activo en player.tscn. La suite quedó sin ningún aviso de transform singular.

### 11.11 HUD sin slots vacíos y reveal dentro de la sala · Hecho

**Prioridad:** baja · **Etiquetas:** `ui`

El HUD muestra los slots X/Y aunque no tengan ítem, y el acercamiento del reveal puede mostrar lo que hay fuera de la sala. Ocultar los slots vacíos y acotar el reveal a la sala.

- [x] Ocultar los slots X/Y sin ítem asignado
  Se oculta el Body; el slot guarda su lugar para que el otro botón no se corra.
- [x] Acotar el acercamiento del reveal a la sala
  TopDownCamera.reveal_focus: Room.clamp_focus con la vista escalada por reveal_zoom.

**Prueba:** Nueva partida: el HUD no muestra los slots X/Y hasta asignarles un ítem. Al pisar un interruptor con reveal, el acercamiento no muestra nada fuera de la sala.

### 11.12 Salas que ocupan varias celdas del mapa · Revisión

**Prioridad:** baja · **Responsable:** project-epiphany-72 · **Etiquetas:** `mazmorra`

Los tamaños de sala son libres desde el 2026-10-15 (viñeta configurable; cada sala se centra en cámara y tapa las otras, 11.178–11.180), así que lo de variar tamaños y la cámara ya está. Falta que el mapa lo acompañe: una sala más grande que el paso de la grilla se dibuja como una sola celda.

- [x] Salas que ocupan varias celdas del mapa
  Hoy cada Room tiene un solo `map_cell` y map_data.gd (`room_pitch`, `room_grid_point`) asume el mismo paso para todas. Sumar un tamaño en celdas a Room y que la pestaña Mapa y el minimapa las dibujen enteras.

**Prueba:** En una mazmorra con una sala que ocupa dos celdas, la pestaña Mapa y el minimapa la muestran entera con sus puertas, y las vecinas quedan en su lugar; test_map pasa.

**Notas:** Hecho (-72): Room.map_size (columnas, filas desde map_cell, por defecto 1×1) con map_rect()/map_center(). MapData mide el paso entre centros de sala; la pestaña Mapa dibuja la sala sobre todas sus celdas y huecos (el cursor la enmarca entera, las vecinas por centros); el minimapa muestra lo que toca las celdas de la actual +1, centra la actual aunque ocupe varias, pone los lados de puertas en la grilla absoluta y limita la flecha a la sala entera. Ningún nivel lo necesita hoy (no se tocaron .tscn; las mazmorras reales tienen salas uniformes). Tests: test_map y test_minimap › test_a_room_of_two_cells_is_drawn_whole.

**Referencias:** `gdd.md#mazmorra-layout`

**Archivos:** `src/world/room.gd`, `src/ui/menus/map_data.gd`

### 11.13 Modelos KayKit: esqueletos para los enemigos y Knight para el player · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`, `personajes`

Usar los packs KayKit de esqueletos y Adventurers: modelos de esqueleto para los enemigos y el Knight para el player, en vez de los modelos actuales.

- [x] Pack Skeletons reducido a assets/kaykit_skeletons (gltf/glb + textura + licencia); el Adventurers nuevo es idéntico a assets/kaykit_adventure
- [x] tools/build_character_models.gd → escenas Visuals en src/entities/models (Minion, Warrior, Rogue, Mage, Knight)
- [x] enemy.tscn con Minion, shield_skeleton con Warrior vía EntityConfig.model, player con Knight
- [x] Suite completa (182, solo el fallo conocido) y capturas de cerca y en el templo
- [x] GDD §10.1

**Notas:** Las animaciones de los packs nuevos (General, MovementBasic) son idénticas a las de kaykit_charanim: no hay nada extra. Los binds handslot.l/r pasan a hand.l/r porque el rig del proyecto no tiene esos huesos.

### 11.14 Puertas con interruptor cerradas al cargar partida · Hecho

**Prioridad:** alta · **Etiquetas:** `bug`, `guardado`

Al cargar partida, puertas, rejas y puentes que ya se habían abierto con un interruptor aparecen cerrados. Tienen que arrancar en el estado guardado de su interruptor.

- [x] Wiring emite settled al frame siguiente; Door/Gate/Bridge toman de ahí el estado inicial
- [x] EyeSwitch avisa activated cuando su flag se restaura en la misma escena
- [x] Test de regresión con pre_boss (falla sin el arreglo) y suite completa: 182, solo el fallo conocido

**Notas:** HubSeal está antes que PuzzleEye en temple.tscn: al cargar leía el ojo antes de que restaurara su flag y quedaba cerrado. Afectaba a cualquier puerta/reja/puente cuyo interruptor esté después en el árbol.

### 11.15 Íconos de ítems y equipo renderizados desde los modelos 3D · Hecho

**Prioridad:** media · **Etiquetas:** `ui`, `arte`

Generar los íconos de ítems y equipo renderizando los modelos 3D, para que el HUD y los menús muestren lo mismo que se ve en la mano del player en vez de SVG sueltos.

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

La letra de los prompts de input es calada en los SVG y toma el color de lo que hay detrás. Que se lean sobre cualquier fondo.

- [x] InputPrompts rellena con #0b0d10 lo calado de cada SVG (flood fill desde el borde, caché por ruta)
- [x] Capturas de HUD y pestañas de la pausa
- [x] Suite completa
- [x] GDD §10.1 (UI)

### 11.17 Pausa: páginas en un TabContainer y títulos en un TabBar · Hecho

**Prioridad:** baja · **Etiquetas:** `ui`

Pasar las páginas de la pausa a un `TabContainer` y los títulos a un `TabBar` del theme, en vez de las etiquetas a mano, y que un clic en una pestaña cambie de página.

- [x] Pages → TabContainer sin barra; Tabs → TabBar con variación PauseTabBar (reemplaza TabLabel/TabLabelSelected)
- [x] Clic en una pestaña cambia la página (test nuevo en test_map)
- [x] Capturas: igual que antes
- [x] Suite completa
- [x] GDD §9

### 11.18 Pared sur del templo: lámina de ladrillos sin colisión tapando la puerta sur · Hecho

**Prioridad:** alta · **Etiquetas:** `bug`, `camara`

En el templo, la pared sur deja una lámina de ladrillos sin colisión, con franjas y sombras, que tapa la puerta sur. Sacarla para que la pared sur quede como un zócalo bajo y la puerta se vea.

- [x] Encontrar qué dibuja las franjas
  Los ladrillos de la pared propia sobresalen ~7 cm de la celda; el corte empezaba 5 cm dentro de la sala y quedaba una lámina de 2 cm a toda altura.
- [x] Empezar el corte 0.3 m dentro de la sala
  TopDownCamera.SOUTH_WALL_RELIEF; test test_south_wall_cut_covers_the_brick_relief.

**Prueba:** En cualquier sala del templo, la pared sur queda como un zócalo bajo, sin franjas ni sombras de ladrillos, y la puerta sur se ve.

### 11.19 Pasos de puerta laterales del templo: losa del alto de la pared sin colisión · Hecho

**Prioridad:** alta · **Etiquetas:** `bug`, `mazmorra`

Reportado por Daniel el 2026-10-09: en los pasos de puerta laterales del templo aparece una losa del alto de la pared, sin colisión, cruzada en el paso. Sacarla.

**Notas:** Reportado por Daniel el 2026-10-09 (captura). Causa: las dos puertas laterales del templo, la (6, 24) y la (18, 24), tenían la pieza Puerta con orientación 0; el marco (3,1 m de alto, solo colisión de piso) quedaba cruzado en el paso. Se giraron 90° (orientación 16) y test_doorways_face_their_wall valida que cada marco siga a su pared.

### 11.20 Cueva con ojo de agua y cáusticas animadas · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Etiquetas:** `arte`, `overworld`, `items`

Una cueva en el overworld con un ojo de agua de shader propio y cáusticas animadas del mismo patrón, con su luz y ambiente; el agua llena la botella de agua bendita y se puede recargar, lo que da razón para volver.

- [x] Decidir qué hay en la cueva
  Abierto: recompensa, secreto, tablilla de historia, pieza de corazón, un ítem… Definirlo antes de diseñar la sala, y anotarlo en el GDD.
- [x] Entrada en el overworld y la sala de la cueva
  Cueva chica, una o dos salas; piezas propias en Blender (roca, estalactitas, cristales) en estilo Altiplano del Ojo.
- [x] Shader de agua propio (water.gdshader)
  Base: la idea de espuma procedural de 'Wind Waker Water' (NekotoArts, godotshaders.com, CC0, Godot 3) reescrita para 4.x y nuestro estilo: colores de la franja agua de la paleta y el tinte 0.72 de epiphany.tres; transparente con color según profundidad (depth texture), así se ve el fondo y las cáusticas; espuma en la orilla por profundidad; manchas de espuma con borde duro en coordenadas de mundo (sin costuras entre tiles); olas de vértice opcionales y apagadas en pozos chicos, con normales planas por cara para mantener el facetado.
- [x] Cáusticas: DrawableTexture2D + shader texture_blit como light_projector
  Como en ../caustics_demo (probado en 4.8-dev7): un SpotLight3D sobre el agua con sombra (CausticsProjector) regenera cada frame una DrawableTexture2D con blit_rect usando un material shader_type texture_blit, y la usa como light_projector; el PR #115653 hace que el atlas actualice solo esa región. Es luz, no pintura: respeta sombras (columnas, el player) y se suma a la iluminación. Atenuación radial para no ver el borde del projector. Limitación de dev7: texture_blit no compila con global uniform; los parámetros se copian a mano (set_wave_param). Medir el costo del blit y de la sombra del spot.
- [x] Luz y ambiente de la cueva
  Penumbra, el agua como fuente de luz suave que tiñe las cáusticas; sonido de goteo.
- [x] Agua y cáusticas del mismo patrón
  Como la variante Wind Waker de la demo: un .gdshaderinc con el patrón (wind_waker_pattern) lo incluyen el agua (spatial) y las cáusticas (texture_blit), así la espuma de la superficie y la luz del fondo se mueven juntas. Pasar el patrón a coordenadas de mundo (la demo usa el UV del mesh, con mesh_center/mesh_size). El agua es transparente y no recibe las cáusticas (o con cast_shadow apagado como en la demo); el fondo y las paredes cercanas sí. Un nodo WaterPool arma superficie + projector y expone tamaño y profundidad. Decal animado solo si el spot resulta caro.
- [x] Interactuar con el agua llena la botella
  Agua bendita: cura más que la poción (o cura y quita doom un rato). Viene de la ex 11.23.
- [x] Recargable
  Se puede volver a llenar; da razón para volver a la cueva.

**Prueba:** Entrar a la cueva desde el overworld: a través del agua se ve el fondo con cáusticas que se mueven al mismo ritmo que el brillo de la superficie, hay espuma en la orilla, sin costuras, cortes ni parpadeos; el estilo combina con el resto (paleta, facetado); el rendimiento no cae respecto del overworld. Con la botella vacía, interactuar con la vertiente: se llena; usarla cura según lo definido.

**Notas:** Skills: `disciplines:level-design`, `godot:godot-shaders`, `godot:godot-3d-essentials`. PR: https://github.com/godotengine/godot/pull/115653. Prototipo propio: /home/drod/Proyectos/Godot/caustics_demo (5 aguas comparadas, cada una con sus cáusticas; tecla 5 = Wind Waker).

**Referencias:** `gdd.md#overworld`, `gdd.md#arte`

**Relacionadas:** 12.13 Reajuste de estilo toon de todos los assets

### 11.21 Piezas de corazón · Hecho

**Prioridad:** media · **Etiquetas:** `items`, `overworld`

Piezas de corazón escondidas en el overworld: 4 juntan un contenedor nuevo. Premian explorar y le dan sentido a los secretos.

- [x] Ítem pieza de corazón
  4 piezas = 1 contenedor; contador en la pantalla de equipo; item get distinto para la 4ª.
- [x] Esconder 4–6 en el overworld
  Detrás de muros agrietados, arriba de andenes, en un puzzle chico, en la cueva del agua.

**Prueba:** Juntar 4 piezas: suma un corazón. El contador se guarda y se ve en equipo.

### 11.22 Tablillas de historia · Hecho

**Prioridad:** media · **Etiquetas:** `historia`, `overworld`

Tablillas de historia repartidas por el overworld y el templo que, leídas en cualquier orden, cuentan 'El Ojo despierta'; una o dos dan pistas de secretos.

- [x] Escribir 6–8 textos cortos
  Cuentan 'El Ojo despierta' (GDD §3, opción A) en orden suelto; uno o dos dan pistas de secretos.
- [x] Repartirlas en overworld y templo
  Con la tablilla existente; cada una con flag de leída.

**Prueba:** Leer todas las tablillas cuenta la historia completa sin contradicciones; las pistas llevan a un secreto real.

**Referencias:** `gdd.md#historia`

**Relacionadas:** 10.20 Intro / cutscene de apertura; 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker)

### 11.24 Más secretos en el overworld · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Etiquetas:** `overworld`, `puzzles`

Sumar 4 a 6 secretos chicos al overworld (cuevitas con cofre, pasto que esconde algo, rocas que se empujan, muros agrietados) con recompensas útiles, para que explorar valga la pena.

- [x] Lista de 4–6 secretos chicos
  Daniel (2026-10-13): 1) queñoa sola que, chocada con las sandalias, se sacude y suelta una pieza de corazón; 2) mata en el Claro/Arboleda que al cortarla destapa una escalera a una cuevita con cofre; 3) roca empujable en los Cerros que destapa un cofre chico; 4) repisa en la Quebrada a una celda, con la pluma, con cofre de flechas.
- [x] Armarlos
  Hecho: mata del Claro (-74, 27) con hoyo a levels/bush_cave.tscn (10 bombas); roca empujable en el nicho de los Cerros (-76, 4; 10 flechas); repisa de la Quebrada (-6, -34; pluma; 10 flechas); queñoa de la Pradera (-43, -13; sandalias; pieza de corazón). Tests en test_secrets y test_jump.
- [x] Recorrerlo (Daniel)

**Prueba:** Cada secreto se encuentra con las herramientas que el player tiene en ese momento y queda resuelto al cargar.

**Capturas:** `compass/images/m11-24-mapa.jpg`, `compass/images/m11-24-1.jpg`, `compass/images/m11-24-2.jpg`, `compass/images/m11-24-3.jpg`, `compass/images/m11-24-4.jpg`

### 11.25 Nuevos enemigos con los modelos existentes · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `enemigos`, `ia`

Enemigos nuevos con los modelos que ya hay: un arquero chullpa, esqueletos que disparen flechas y uno con punto débil, cada uno con telegraph legible y una contra clara.

- [x] Arquero chullpa
  Dispara de lejos; se bloquea con el escudo y se refleja con el espejo.
- [x] Enemigo con punto débil
  Solo por la espalda o solo con bombas.
- [x] Esqueleto arquero
  Pedido: esqueletos que disparen flechas. Mantiene distancia, telegraph con el tensado, la flecha se bloquea con el escudo.

**Prueba:** Los dos enemigos aparecen en overworld o templo, se leen sus telegraphs y tienen contra clara.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.26 Prueba de combate opcional · Revisión

**Prioridad:** baja · **Responsable:** project-epiphany-5c · **Etiquetas:** `combate`

Una sala de combate opcional: 3 oleadas mezclando enemigos con la puerta cerrada hasta terminar y una recompensa al final (pieza de corazón u otra; la cota reforzada ya la da el santuario después de D4 y el carcaj el Risco).

- [x] Sala de oleadas
  3 oleadas mezclando enemigos; la puerta se cierra hasta terminar.
- [x] Recompensa
  Pieza de corazón u otra cosa (ver el total de 11.124). La cota reforzada y el carcaj ya se consiguen en otro lado (santuario, 11.113 paso 5; Risco, 11.90 paso 5).

**Prueba:** Entrar, sobrevivir las 3 oleadas, la puerta abre y aparece la recompensa; no se repite al cargar.

**Notas:** Propuesta de -72 (2026-10-19), solo diseño, falta que Daniel la apruebe.
Ojo: el templo ya tiene sala de oleadas (la Combinada); esta es la versión del overworld, más temprana y chica.
Dónde: Necrópolis (hub este, acto 2, con arco), "la Huaca de los guerreros", chullpa grande hundida con escalera. Alternativa: el Cardonal, detrás de un muro agrietado.
Regla de ítems: en el acto 2 puede no haber gancho ni escudo espejo: nada de acorazados ni orbes que devolver.
Sala de 16×12 m con persianas, dos tarimas, cuatro columnas bajas (tapan flechas) y vasijas (corazones entre oleadas). WaveSpawner cierra al entrar.
Ola 1: 4 esqueletos (_quenoa o _templo), calienta combo y giro. Ola 2: 2 esqueletos con escudo + 2 arqueros en las tarimas (revés/estocada contra el escudo; arco o columnas contra los arqueros). Ola 3: Ojo Vigía mini (con flechas) + 2 esqueletos; si no se quiere repetir la Combinada, Momia mini + 2 atoq.
Al vencer: persianas abiertas y premio; flag ow_trial_waves.
Existe: WaveSpawner, WaveSpawn, persianas, enemigos y variantes, sub-jefes mini, Chest, Pickup, HeartPiece. Nuevo: el nivel de una sala (como bush_cave), la entrada (chullpa hundida) y una tablilla opcional.
Premio: a) pieza de corazón, b) bolsa de bombas grande (si no la da 11.27), c) otra botella vacía, d) 20 flechas y 10 bombas (pobre, no recomendado).

Daniel (2026-10-19): armar tal cual (Huaca de los guerreros en la Necrópolis, 3 oleadas); premio: pieza de corazón (16 en total).

-5c (2026-10-20): hecho en ff2deeb7 (nivel) y 5a9a493c (entrada). levels/huaca.tscn de 16×12 con look chullpa, persiana al sur, cuatro columnas bajas, dos tarimas de 0.6 m para los arqueros (se suben saltando con la pluma) y cuatro vasijas con corazones. Olas: 4 esqueletos / 2 con escudo + 2 arqueros en las tarimas / Ojo Vigía mini + 2 esqueletos. Al ganar aparece la pieza de corazón (ow_heart_piece_trial); ganada queda ganada (ow_trial_waves). Entrada: corona de chullpa enterrada en la Necrópolis nivel 1 (46, 2.6, -6), lugar elegido por -3e. Falta la tablilla opcional.

### 11.27 Mini-santuario de reflejos · Revisión

**Prioridad:** baja · **Responsable:** project-epiphany-72 · **Etiquetas:** `mazmorra`, `puzzles`

Un mini-santuario de 3–4 salas que se resuelven solo con el escudo espejo, cada una enseñando una variante del reflejo, con recompensa al final.

- [x] Diseñar 3–4 salas
  Todo con el escudo espejo: haces de luz, ojos-interruptor, espejos que giran.
- [x] Recompensa al final

**Prueba:** Se completa solo con el escudo espejo; cada sala enseña una variante del reflejo.

**Notas:** Propuesta de -72 (2026-10-19), solo diseño, falta que Daniel la apruebe.
Dónde: Cumbre, junto al Intihuatana (región de D4, con gancho; el escudo sale de ahí: sin vuelta atrás). Boca tallada en el risco con reja; un sol en la cornisa de enfrente: el escudo baja el rayo a un cristal junto a la boca y abre la reja (flag ow_reflex_door). Alternativa: Explanada del templo, junto al sello (examen antes de la última mazmorra, pero mezcla dos puzzles de luz en la misma pantalla).
Forma: nivel chico aparte (levels/reflejos.tscn), 4 salas de 14×12 m como en D4, en fila hacia el norte; sin llaves, mapa ni brújula; cada sala abre la siguiente; solo escudo espejo y espada.
Sala 1, El ángulo: el escudo manda el rayo hacia donde mira el player, también en diagonal. Sol por el este; cristal 1 (norte, oeste de la puerta) parado en el rayo mirando en diagonal; cristal 2 (esquina NE) con rebote en un espejo fijo y después en el escudo. Los dos abren la reja. Sin enemigos.
Sala 2, Orbes: el escudo también devuelve proyectiles. Dos torretas (revives) en cornisas oeste y este, abismo en el medio. Ojo 1 (pared norte, sobre piso firme) extiende un puente; ojo 2 (open_time 6 s, pared norte del otro lado) abre la reja 6 s: devolver y correr. Ojos solo en pared norte.
Sala 3, Giros: el player es un eslabón. Sol tras una persiana que abre 8 s un espadazo en una placa; M1 y M2 giran de un espadazo; rayo → M1 → escudo → M2 → cristal. Hay que planificar antes de abrir. Un esqueleto con escudo de molestia.
Sala 4, Corona: todo junto bajo presión. Dos arqueros en tarimas (sus flechas se devuelven con el escudo), una columna corta el rayo directo; girar un espejo y sostener el rayo con el escudo. Cristal (latch) → cofre grande. Flag ow_reflex_done.
Existe: LightSource, LightMirror, RotatingMirror, LightReceiver, EyeSwitch (open_time), Turret, Gate como persiana, FloorSwitch, Bridge, Room, esqueletos con escudo y arqueros _cumbre. Nuevo: el nivel, la boca (heredar de cumbre_entrada) y quizás placa con temporizador. Opcional: un prisma que parte el rayo.
Premio: a) pieza de corazón (si se va a 16, ver 11.124), b) bolsa de bombas grande (bomb_bag_big con _capacity_bonus), c) otra botella vacía. Recomienda a) si 16 piezas; si no b).

Daniel (2026-10-19): armar tal cual (Cumbre junto al Intihuatana, 4 salas); premio: pieza de corazón (16 en total).

Built (-72, 2026-10-20): levels/reflejos.tscn (58318ff1), four rooms (angle, orbs, turns with the new HitSwitch, crown with archers), heart piece in the big chest (ow_reflex_done). Mouth on the Cumbre's north cliff west of the condor (86349ea8): ReflexSun → ReflexCrystal (ow_reflex_door) → ReflexGate, ReflexDoor/Spawn_reflejos. Fix d46f9039: PlaceReflex (SHRINE) on the map, mouth in scenery, Glow deterministic=false, terrain JSON. test_reflejos.

### 11.28 Atajos que se abren al volver · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Etiquetas:** `overworld`

Uno o dos atajos que se abren desde adentro (puente o escalera) y quedan abiertos, para acortar el camino de vuelta al templo.

- [x] Uno o dos atajos de vuelta
  Daniel (2026-10-13): escalera de soga Cumbre → Explanada. Hecho: CumbreLadder en el borde oeste de la Cumbre (7.6, 5.2, -33), se descuelga desde arriba (flag ow_cumbre_ladder) y une la Cumbre con la orilla al pie, que por el norte de la Quebrada lleva a la Explanada. Test en test_secrets.
- [x] Recorrerlo (Daniel)

**Prueba:** Abrir el atajo desde adentro: queda abierto y acorta el recorrido al templo.

**Capturas:** `compass/images/m11-28-mapa.jpg`, `compass/images/m11-28-1.jpg`

**Relacionadas:** 11.170 Atajos: animación del player subiendo y bajando en vez del fundido

### 11.29 Overworld después del jefe · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** baja · **Etiquetas:** `overworld`, `audio`

Después de vencer al jefe, el overworld tiene que verse y sonar distinto (sin doom: luz, niebla y música calmas) y ofrecer algo nuevo que solo aparece entonces.

- [x] Amanecer tras el jefe final
  Daniel (2026-10-13): el jefe del templo (te_boss_defeated). El overworld ya no tiene doom; AfterTheEye pasa el sol a luz de amanecer, apaga el ojo de la fachada (TempleEyeGlow) y para los temblores. Valores de luz: arte.
- [x] Cima del templo
  Escalinata de una celda (X -48, Z -36) cerrada por SummitGate hasta te_boss_defeated; arriba, HeartPieceSummit. Test en test_secrets.
- [x] Recorrerlo (Daniel)

**Prueba:** Vencer al jefe y salir: el overworld se ve y suena distinto, y hay algo nuevo para encontrar.

**Capturas:** `compass/images/m11-29-mapa.jpg`, `compass/images/m11-29-1.jpg`, `compass/images/m11-29-2.jpg`, `compass/images/m11-29-3.jpg`

**Relacionadas:** 10.19 Fin de la demo

### 11.30 Ítem de D3: el gancho · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `items`

Un ítem post-MVP: gancho o algo que mueva objetos a distancia (GDD §6.1), con uso en combate y que abra lugares que antes no se podían.

- [x] Elegir el ítem
  Gancho. Decidido el 2026-10-11 para D2; el 2026-10-12 (11.90) pasa a ser el ítem de D3 (Laguna), y la pluma va a D2. Se engancha a postes y cofres y lleva al player; a enemigos livianos los trae; cruza abismos de 4 m; también quita la armadura del esqueleto acorazado (la bomba sigue sirviendo).
- [x] Comportamiento del gancho
  Hecho el 2026-10-13 (Daniel: si, me gusta). HookBehavior: el botón pasa al estado Hooking del player y dispara Hook (src/items/hookshot/hook.tscn), que sale recto 10 m (5 baldosas; era 8, se alargó para los cruces de 4 celdas de D3). En un HookPost (src/world/hook_post.tscn) o un cofre se clava y el player vuela hasta ahí a 14 m/s sin gravedad: cruza agua y huecos; a un poste llega siempre al lado, sobre piso. Con el gancho en un botón, los postes a su alcance se fijan con el targeting, aunque estén a otra altura (Daniel, por la Cumbre): la cadena va derecho y el player sube o baja a su piso. Trae vasijas (se rompen a los pies), rocas y recolectables; la vasija grande viene de a una celda. Golpea con el elemento hook: 1 de daño y aturde 1,2 s, le baja el escudo al esqueleto con escudo y le arranca la coraza al acorazado sin dañarlo. Contra paredes rebota. test_hookshot (10).
- [x] Probarlo en el banco de pruebas (Daniel)
  Escenario gancho (debug/scenarios/gancho.cfg): sandbox de ítems, zona GANCHO al sur: hueco de 6 m con un poste, isla con una vasija y una vasija grande, y otro poste para volver. Ajustar a ojo alcance, velocidades y aturdimiento.
- [x] Arte: modelo del gancho, del poste e ícono
  Hecho por arte (712c8029): lanzador, punta, eslabón de cadena de 0.16 m (la cadena lo repite, 0e28489a), poste con argolla e ícono.
- [x] D3, Santuario de Totora: plano y blockout
  Hecho el 2026-10-13: levels/totora.tscn (debug/tmp/build_totora.gd), 11 salas de 14 × 10 m en dos pisos, GDD §8d. El agua es celda vacía con Pit; los cruces del gancho miden 4 celdas (el salto largo cruza 3). Grafo data/dungeons/totora_graph.tres, test_totora (6), escenario totora. Diferencias con el plano: sin la vasija grande (se levanta con las manos), reja en lugar de puente en el Juncal, el acorazado en el Telar, el Mirador solo con postes.
- [x] Usos en el overworld (sesión del overworld)
  Hecho por el overworld (6910e214, a598979a): CumbrePost y RiscoPost en el borde, se suben fijándolos; test_overworld_hook.
- [x] Ala del gancho del templo
  Hecho el 2026-10-13: el abismo del Gancho pasa de 3 a 4 celdas (x 12..15 del grid; el salto largo cruzaba 3) y su GanchoPit se ensancha a 8 m; GanchoWestPost (22.5, 0, 34) y GanchoEastPost (31.5, 0, 38), a 0,5 m del borde y corridos de la línea de las puertas. Editado como texto (sin re-guardar la escena); las paredes no cambian, así que no hizo falta el refresh de la_walls. El acorazado y el ojo del ala ya estaban. test_templo (nuevo test del cruce).
- [x] Sub-jefe Amaru
  Hecho el 2026-10-13: src/entities/amaru/ (Amaru, AmaruPool), data/entities/amaru.tres. Asoma por uno de cuatro charcos (asomada, todo rebota), marca una línea 1 s, se lanza recta (2 de daño) y queda tirada 2,2 s, vulnerable a espada, bombas y vasijas; vuelve reptando al charco más cercano. Con media vida escupe un Projectile antes del lanzazo. 10 de vida, modelo primitivo. Reemplaza a la momia prestada en PisoBajo/AmaruFight; las vasijas del Pozo pasan a las esquinas. test_amaru (4).
- [x] Jefe Yacumama
  Hecho el 2026-10-13: src/entities/yacumama/ (Yacumama hereda de Amaru), data/entities/yacumama.tres, 14 de vida. Asoma por uno de cuatro charcos, escupe dos bolas (reflejables) y queda asomada 2,5 s; asomada solo cuenta el gancho, que la tira al piso a 2 m del player: 3 s tirada, le pega la espada; vuelve reptando. Con media vida, antes de escupir barre la sala con la cola desde su charco (hasta la pared; pega 2 en el piso, se salta con la pluma). El gancho le pega en el cuerpo: la punta va a 0,9 m y la argolla de la máscara queda como detalle del modelo. Reemplaza al ojo vigía prestado; las vasijas del Nido van a las cuatro esquinas. test_yacumama (4).
- [x] Entrada de D3 en el overworld (sesión del overworld)
  Hecho por el overworld (5e04f395): TotoraDoor en una choza provisoria de la isla de la Laguna, Spawn_totora afuera; las dos salidas de D3 vuelven ahí.
- [x] Arte: horneado LA de la totora
  Agregar totora a tools/la_walls.gd (kit propio de totora y agua) cuando arte pueda; los tests de test_totora ya son relativos a cada sala.
- [x] Recorrer D3 (Daniel)
  Escenario totora: pluma, arco, bombas y sandalias. Ajustar a ojo los cruces, el ojo con tiempo de los Tejedores (6 s) y la posición de los postes.

**Prueba:** El ítem tiene un uso en combate y abre al menos dos lugares que antes no se podían.

**Referencias:** `gdd.md#items-mvp`

**Capturas:** `compass/images/m11-30-mapa.jpg`, `compass/images/m11-30-1.jpg`, `compass/images/m11-30-2.jpg`

**Relacionadas:** 11.60 Mazmorra nueva de varios pisos

### 11.31 Sub-jefe del templo · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** baja · **Etiquetas:** `jefe`, `enemigos`

Un sub-jefe a mitad del templo: un chullpa guardián gigante con patrón propio que custodia el arco; al vencerlo aparece el cofre.

- [ ] Chullpa guardián gigante
  Custodia el arco a mitad del templo; patrón propio, una sola fase.
- [ ] Sala y recompensa
  Al vencerlo aparece el cofre del arco.

**Prueba:** Llegar al sub-jefe, vencerlo con espada y escudo, y obtener el arco; al cargar no reaparece.

**Notas:** Reemplazada por 11.113: el arco es de D2 (Ojo Vigía) y el sub-jefe del templo es La Mano

### 11.33 Combate: sacar lo tosco · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Etiquetas:** `combate`

Skills: `disciplines:game-feel`, `disciplines:input-systems`, `godot:godot-animation`.

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

**Notas:** Hecho: cancel_from/lunge en AttackData, golpe encadenable (Attacking→Attacking), giro al objetivo o stick, chispas al pegar, aviso rojo (HitFlash.warn) y recovery_time 0,4 s en BTAttack, feel.tres con valores. Sonido por superficie (Hurtbox.surface: carne, metal, piedra, nada; el enemigo pasa a metal cuando la coraza o el escudo frenan); pasto y vasijas ya no disparan hit-stop ni sacudida. Falta jugarlo (paso 1).

**Referencias:** `gdd.md#combate`

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión); 11.49 VFX de combate

### 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker) · Revisión

**Prioridad:** media · **Responsable:** project-epiphany-72 · **Etiquetas:** `combate`

Técnicas de espada al estilo Minish Cap y Wind Waker: combo de 3 golpes, giro cargado, contraataque y 1–2 técnicas extra que se aprenden en el mundo, sin chocar con fijar, bloquear y rodar.

- [x] Combo de 3 golpes
  Tajo, revés y estocada encadenados con el buffer; el tercero hace más daño y empuja. Animaciones de Rig_Medium (CombatMelee).
- [x] Ataque giratorio cargado
  Mantener ataque: la espada brilla (neón), al soltar gira 360°. Versión grande al cargar más (Great Spin).
- [x] Contraataque (parry de Wind Waker)
  Cuando un enemigo telegrafía, aparece un prompt corto: al apretarlo, el player salta por encima o rodea y pega por la espalda. Sirve también con las manos del jefe.
- [x] Técnicas extra a elegir
  Estocada en carrera (dash attack), salto con golpe (jump strike), rayo de espada con la vida llena (Minish Cap). Elegir 1–2 para la demo.
- [x] Cómo se aprenden
  Como los pergaminos de Minish Cap: algunas técnicas se enseñan en tablillas/santuarios del overworld (cruza con 11.22 y 11.24); el combo y el giro desde el inicio. Mostrarlas en la pantalla de equipo.
- [x] Input y tutorial
  Que no choquen con lock-on, bloqueo y rodar; prompt la primera vez que se aprende cada una; anotar en el mapa de input del GDD §4.3.

**Prueba:** Con el combate pulido (11.33): encadenar el combo de 3, cargar y soltar el giro, contraatacar a un chullpa en su telegraph y usar una técnica aprendida en una tablilla; ninguna se dispara sin querer al rodar, bloquear o fijar.

**Notas:** Hecho pasos 1 y 2 (-72, d68b55e1; 3–6 esperan a Daniel). Combo: MeleeBehavior = attack + combo[] + spin. sword_basic/golden: tajo → revés (sword_backhand, Slice_Horizontal, AttackType Backhand) → estocada (sword_thrust, Stab, ×1,5 daño, ×2 empuje, avance 4,5). Avanza si el golpe nuevo llega dentro de combo_window (0,45 s, export) desde que terminó o se cortó el anterior, contado en tiempo de juego (cuadros de física). Se reinicia fuera de la ventana, después de la estocada o si pasa por otro estado que no sea Idle/Moving. La estocada con guardia sigue siendo SWORD_STAB. Giro: nodo SwordCharge (charge_time 0,9, show_from 0,3, move_factor 0,55, exports) cuenta el ataque mantenido en Idle/Moving/Attacking, nunca cubriéndose ni rodando; la luz ChargeGlow anima en su AnimationPlayer (RESET/charging/charged). Al soltar con carga llena, estado Spinning (sword_spin, Melee_2H_Attack_Spinning, AttackType Spin, hitbox cilindro de 1,8 m, ×2 daño). test_combo (7) y test_items. Capturas en wt/design debug/tmp/design/combo_*.png. Great Spin (d1049ae2): SwordCharge.great_charge_time (2,2 s, export); al pasarlo ChargeAnim toca "great" (luz dorada, pulso más rápido); al soltar, Spinning usa MeleeBehavior.great_spin = sword_great_spin.tres (hitbox GreatSpin cilindro de 3 m, ×3 daño, ×2,5 empuje, 0,6 s de aturdida). Entre los dos umbrales, el giro normal; nunca cubriéndose ni rodando. Tests test_combo › test_holding_longer_charges_the_great_spin y test_the_great_spin_reaches_farther. Captura combo_7_great_charged.png. Nota de integración: el código de los pasos 1 y 2 sin el Great Spin quedó dentro del commit fbeb9d5b de main (un cherry-pick cortado por el lock del índice), con el mismo contenido que d68b55e1.

Daniel (2026-10-20) approved -72's proposal for steps 3–6 as written: counterattack (attack in a 0.35 s window while locked on, Roll+Slash / Jump+Slash, ×2 damage, 0.8 s stun, skips the shield guard), plunge attack in the air (×2, 1.2 m shockwave, presses STRIKE plates), sword beam at full health (6 m, 1 damage, never triggers puzzles). Learned at technique stones with a dummy: counterattack in the Pradera, plunge in the Arboleda (feather), beam in the Cumbre (hookshot posts); flags ow_tech_counter/plunge/beam. Técnicas panel in Equipo with a mockup first. No new buttons; first window at half speed via TimeScale &"counter_hint". GDD §4.3.

Daniel (2026-10-20, via -72, with the mockups Pause_Equipo_Tecnicas, Technique_Learned, HUD_Counter, Tutorial_Card and HUD_Practice_Chip on the canvas): a practice dummy at every technique stone; half speed in the counter window ALWAYS, with an option in Opciones to turn it off (not just the first time).

Step 3 counterattack (55931a63) and step 4 plunge (897b80e5) merged. Daniel (2026-10-20): STRIKE plates stay hammer-only; the plunge doesn't press them (-72 changes FloorSwitch). The boss hands can't be countered (they can't be locked on): pending Daniel's decision.

Merged (-72): beam 969bb550, Técnicas row in Equipo 6acb8973, technique stones + dummy + Técnica nueva screen 1276342c, hammer-only STRIKE plates a42845ed. Step 5 is missing: placing the stones in the overworld (Pradera, Arboleda, Cumbre).

Daniel (2026-10-20): the boss hands stay unlockable (not counterable) for now.

**Referencias:** `gdd.md#combate`, `gdd.md#input`

**Relacionadas:** 11.22 Tablillas de historia; 11.35 Saltar: ítem tipo Pluma de Roc

### 11.35 Saltar: ítem tipo Pluma de Roc · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `combate`, `movimiento`

Saltar con un ítem tipo Pluma de Roc (nada de salto libre), para que el gating por saltos empiece al conseguirlo: huecos de un tile, andenes bajos y esquivar ondas de choque del jefe.

- [x] Decidido: ítem tipo Pluma de Roc
  Nada de salto libre ni automático: se salta con un ítem que se consigue (Minish Cap), así el gating de saltos empieza cuando lo tenés. Anotado en GDD §4.2.
- [x] Estado Jumping en el player
  player/states/jumping.gd: height 0,68 (apex ≈0,71), speed 4, air_control 2; sombra %JumpShadow (Decal) que se achica al subir; Jump_Full_Short por el OneShot de ítems; polvo al saltar y al caer. Altura limitada por la cápsula: con más de ≈0,75 se apoya en el borde de una pirca.
- [x] Integración con combate
  La onda de las manos del jefe es un Hitbox ground_only: estar en el aire cuando llega alcanza. El golpe en el aire / caída con la espada queda para 11.34.
- [x] Integración con el mundo
  Abismo sin piso: el kit saca la colisión a Abismo/Pozo (9, 10); el que cae va a un Pit y vuelve a su respawn (Pit.respawn). Abismo del Risco ensanchado a 2 celdas (4 m), solo flechas; ojo a z −22, Spawn_risco a z −14. Pirca 0,9 no se salta, escalón 0,6 sí. Tests: test_jump (incluye test_the_crag_abyss_is_too_wide_and_falling_returns), test_abyss_has_no_floor_but_a_pit. Los lugares de salto del overworld pasan a 11.61 (después de 12.14).
- [x] Ítem y input
  data/items/feather.tres ("Pluma", JumpBehavior, USABLE), en la base de ítems; el botón despacha jump en vez de use_item. Malla e ícono de la sesión de assets: equipo/pluma.res y assets/ui/items/feather.png (pluma de cóndor). Textos ITEM_FEATHER_*.
- [x] Dónde se consigue y qué abre
  Templo, sala 10 'Sala de la pluma' (celda de mapa (2, 4), sale de la agrietada sin bombas): zanja de huecos que se rodea sin pluma hasta el cofre grande (d1_feather_chest) y se salta de vuelta; vasija de corazones arriba de un escalón. Se exige en la entrada del Puzzle (fila de huecos a 4 m de la puerta; el bloque ahora se empuja al oeste); escalón con vasija opcional en la antesala. Doom 0,45. Escenarios pre_boss y full_inventory con la pluma. Tests: test_room_10_feather_room, test_room_7_entrance_needs_the_feather, recorrido completo con el tramo de la pluma, test_doom. GDD §6.2 (regla: un ítem no abre nada en mazmorras anteriores; el overworld es hub) y §8. El overworld pasa a 11.61.

**Prueba:** Sin la pluma no se puede saltar. Con la pluma asignada: saltar un hueco de un tile y subir a un andén bajo; la sombra deja ver dónde cae. No se puede saltar una pirca ni un muro de sala. Saltar esquiva la onda de choque del golpe de las manos del jefe. En el templo: la pluma está en la sala 10 (debajo de la agrietada); sin ella se rodea la zanja hasta el cofre, con ella se salta de vuelta; la entrada del Puzzle pide saltar. En el Risco, el abismo (4 m) no se cruza saltando y caer devuelve al spawn.

**Notas:** Skills: `godot:godot-physics`, `disciplines:game-feel`, `disciplines:level-design`.

**Referencias:** `gdd.md#input`, `gdd.md#movimiento-combate`, `gdd.md#items-mvp`

**Relacionadas:** 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker); 11.61 Pluma en el overworld: lugares de salto

### 11.36 Mapa: más información y navegable · Hecho

**Prioridad:** media · **Etiquetas:** `ui`

El mapa de la pausa es hoy una foto fija con el marcador. Que dé más información y se pueda recorrer: niebla de exploración en el overworld, marcas de puertas, cofres y entradas, cursor con nombres y pines propios.

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

### 11.37 Minimapa en el HUD · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `ui`

Un minimapa chico en el HUD que muestre las salas alrededor en la mazmorra y el entorno del player en el overworld, con los mismos datos que la pestaña Mapa y que se pueda apagar.

- [x] Mockup HUD_Minimap
  Esquina libre del HUD (no choca con corazones, ítems ni la barra del jefe); tamaño chico, marco simple bronce.
- [x] Mazmorra
  Las salas alrededor de la actual (3×3), con puertas y el player con flecha de orientación; usa los mismos datos que la pestaña Mapa (Room.map_cell, DungeonState).
- [x] Overworld
  Recorte de la foto cenital alrededor del player, con la niebla de 11.36 (zonas sin visitar en sombra) y las marcas cercanas.
- [x] Cuándo se ve
  Opción en Opciones (encendido/apagado); se oculta en cutscenes, item get, diálogos y en la sala del jefe.

**Prueba:** Recorrer el templo: el minimapa sigue al player sala a sala y coincide con la pestaña Mapa. En el overworld muestra la zona y se destapa igual. Se apaga desde Opciones y no aparece durante el jefe ni en cutscenes.

**Notas:** Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`. Escena .tscn, nada armado por código.

**Referencias:** `gdd.md#ui`

**Relacionadas:** 11.36 Mapa: más información y navegable; 10.28 Playtest de revisión (lo que está en Revisión)

### 11.38 Silueta x-ray con fresnel · Hecho

**Prioridad:** media · **Etiquetas:** `camara`

Pedido por Daniel el 2026-10-10 (godotshaders stencil-based-silhouette y el custom x-ray de apples/godot-stencil-demo): la silueta del player gana fresnel, brilla en los bordes y es más transparente en el centro.

### 11.39 Luces estilo Wind Waker (volúmenes de stencil) · Hecho

**Prioridad:** media · **Etiquetas:** `arte`

Pedido por Daniel el 2026-10-10, como las Wind Waker lights de apples/godot-stencil-demo (el repo no tiene licencia: se reimplementa la técnica, sin copiar código). Esfera con 3 pasadas de stencil: marcar lo que queda delante, multiplicar color adentro, limpiar; prioridad propia por luz. Cuidar que no pise el stencil de la silueta del player (ref 1). Uso: antorchas del templo.

- [x] Componente WindWakerLight (escena + shaders propios)
- [x] Ordenar prioridades con la silueta del player
- [x] Ponerla en las antorchas del templo y revisar en capturas

### 11.40 Agujero en lo que tapa al player · Hecho

**Prioridad:** media · **Etiquetas:** `camara`

Pedido por Daniel el 2026-10-10.

- [x] Uniform global con la posición en pantalla y la profundidad del player
- [x] Recorte circular (con borde suave o dither) en los materiales que tapan
- [x] Decidir con Daniel si convive con la silueta o la reemplaza

**Notas:** Decidido: agujero contra paredes, silueta contra objetos; en el borde del mundo, silueta (el agujero mostraba el vacío). Uniform global player_hole desde TopDownCamera; player_hole.gdshaderinc en cutaway.gdshader y epiphany_wall.gdshader; variantes 'borde' del kit del overworld que OverworldMap pone al cargar.

### 11.41 Esqueleto con escudo: bloquear con el escudo delante · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Etiquetas:** `combate`, `enemigos`

El esqueleto con escudo tiene que bloquear con el escudo de verdad delante, en la misma pose que el player, y solo cuando lo tiene levantado mirando al player; que el bloqueo se lea con chispa, sonido y retroceso.

- [x] Pose del escudo al bloquear
  Mismo socket que el player: de frente, 20° hacia afuera, delante de la mano.
- [x] Bloquea cuando de verdad tiene el escudo arriba
  Que el bloqueo coincida con lo que se ve: escudo levantado mirando al player; si no, el golpe entra.
- [x] Se lee el bloqueo
  Chispa y sonido en el escudo, retroceso; capturas desde la cámara del juego.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.42 Arco que se tensa · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `items`, `arte`

Que el arco se tense mientras se mantiene el disparo: la cuerda se estira hacia la mano, las palas se doblan y la flecha queda en la cuerda; al soltar vuelve de golpe.

- [x] Arco con hueso o shape key de tensado (Blender, otra sesión)
  Cuerda que se estira hacia la mano derecha y palas que se doblan.
- [x] Tensado sigue a Ranged_Bow_Draw
  El tensado va de 0 a 1 mientras se mantiene; al soltar vuelve de golpe.
- [x] Flecha en la cuerda mientras se tensa

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.43 Bombas: tocar coloca, mantener apunta y tira · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `items`

Bombas con dos usos: tocar el botón la coloca a los pies como ahora y mantenerlo la levanta y apunta como el arco, para tirarla en parábola al soltar.

- [x] Tocar: coloca la bomba a los pies como ahora
- [x] Mantener: levanta la bomba y apunta como el arco
  Mira/arco de tiro en el piso; soltar la tira en parábola.
- [x] Mecha sigue corriendo mientras se apunta
- [x] Tests y GDD

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.44 Levantar y tirar objetos · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Etiquetas:** `items`, `interaccion`

Levantar y tirar objetos (vasijas, piedras, arbustos): se cargan caminando más lento y al tirarlos rompen y dañan enemigos; habilita puzzles como piedra sobre placa de presión.

- [x] Objetos levantables
  Vasijas, piedras, arbustos: componente Liftable con peso.
- [x] Estado Carrying
  Interactuar levanta (anim KayKit), se camina más lento, se tira con el mismo botón o se apoya.
- [x] Tirar: parábola, rompe y daña
  Al chocar se rompe (vasija suelta su loot) y daña enemigos.
- [x] Puzzles que lo usen
  Piedra sobre placa de presión, vasija para tapar un hueco. Se hace con los mini puzzles de 11.45 (stone.tscn ya aprieta placas).

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.45 Tutorial de controles y mini puzzle por ítem · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Etiquetas:** `ui`, `puzzles`

Enseñar los controles al empezar con tablitas en el claro del inicio y un mini puzzle al conseguir cada ítem, con los íconos de botón del dispositivo actual.

- [x] Tutorial de controles al empezar
  Carteles/tablitas en el claro del inicio: moverse, atacar, rodar, bloquear, fijar, interactuar; muestra el botón según el dispositivo.
- [x] Mini puzzle al conseguir cada ítem
  Levantar: piedra, placa y reja con cofre en el claro del inicio. Bombas, espejo y arco reusan lo que ya había al lado del cofre (muro de práctica, haz del santuario, sala de ojos) con su tablita de pista.
- [x] Tablitas con el ícono del botón
  El texto de la tablita usa los íconos de input actuales.
- [x] Tests y GDD

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.46 Jefe: game juice · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `jefe`, `feel`

Game juice para el jefe: cuerpo y ojo que reaccionan, anticipación y peso en las manos, impactos con hit-stop, grietas y vibración, y una muerte que se sienta como final.

- [x] Cuerpo vivo
  Balanceo de flotación, inclinación hacia la mano que ataca; parpadeos ocasionales, párpados entrecerrados al apuntar. No hay malla de propulsor: el cuerpo brilla en cada ataque.
- [x] Ojo que carga
  El iris pulsa la emisión (material override por instancia) mientras carga el orbe; la boca de horno se enciende en cada ataque. La pupila (shape keys rendija/dilatada) se dilata al cargar, se cierra en rendija al disparar y queda dilatada aturdida.
- [x] Anticipación y peso de las manos
  Antes del golpe sube de más, cierra el puño y tiembla; cae más rápido, squash al tocar el piso y rebote chico. Mismo criterio para el agarre y el barrido.
- [x] Impactos
  Hit-stop (~60 ms) en el golpe al piso y cuando el player le pega (Feel ya lo tiene); grietas que quedan en el piso y piedritas; vibración del control; sacudida direccional; la sombra crece y destella el último instante.
- [x] Mano aturdida
  Tambaleo mareado, el ojo de neón del dorso titila, chispas.
- [x] Fases y muerte
  Cambio de fase: párpados que se abren de golpe, destello, polvo del techo. Muerte en etapas: placas que se desprenden, neón que se apaga, explosiones chicas en las juntas, cámara lenta en el último golpe.

**Prueba:** Pelear contra el jefe de punta a punta: cada ataque se anticipa y se lee, los golpes al piso pesan (hit-stop, grietas, vibración), el ojo y el cuerpo reaccionan, y la muerte se siente como un final.

**Notas:** Skills: `disciplines:game-feel`, `godot:godot-animation`, `godot:godot-shaders`.

**Referencias:** `gdd.md#jefe`

**Relacionadas:** 11.47 Manos del jefe animadas (shape keys); 11.50 Audio del jefe

### 11.47 Manos del jefe animadas (shape keys) · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `jefe`, `arte`

Las manos del jefe alternan mallas sueltas (abierta, puño, garra). Hacer una malla por mano con shape keys, para que los dedos se cierren y abran de forma continua y las manos tengan gestos propios.

- [x] Una malla por mano con blend shapes
  En build_jefe.py, como el arco: base abierta y shape keys «puno» y «garra» (los dedos rotan por falange); reemplaza las tres mallas sueltas.
- [x] Transiciones en el código
  BossHand interpola los blend shapes en vez de alternar visibilidad (Open/Fist/Claw).
- [x] Gestos y movimiento propio
  Respiración en reposo, inclinación según la velocidad, apuntar hacia el objetivo, anticipaciones y reacciones por ataque, aturdida y caída; todo sobre la malla, sin tocar hitboxes ni tiempos.
- [x] jefe al pipeline glb
  build_jefe.py publica jefe.glb (epi.publish) para que el import guarde las mallas con sus blend shapes; se borran jefe.blend y las seis mallas sueltas (parte de 12.11).

**Prueba:** Los dedos se cierran y abren de forma continua; las manos respiran en reposo, se inclinan al moverse, abren antes de agarrar, aprietan al sostener, se crispan aturdidas y caen flojas; la pelea sigue igual.

**Notas:** Skills: `godot:godot-animation`.

**Referencias:** `gdd.md#jefe`

**Relacionadas:** 11.46 Jefe: game juice; 10.28 Playtest de revisión (lo que está en Revisión); 12.8 Personajes propios; 12.11 Migrar los .blend al pipeline glb

### 11.48 Pose de item get · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `personajes`, `feel`

Pose de item get: el player levanta el ítem con las dos manos y se ve el objeto arriba con un destello mientras está la caja.

- [x] Animación
  Las dos manos en alto con el objeto (como Carry, con IK horneado en build_carry_anims.py o un script hermano); entrada y salida cortas.
- [x] Integración
  La caja de item get muestra al player en la pose con el objeto arriba y un destello; sonido propio.

**Prueba:** Abrir un cofre grande: el player levanta el ítem con las dos manos, se ve el objeto arriba y vuelve a su pose al cerrar la caja.

**Notas:** Skills: `godot:godot-animation`, `disciplines:game-feel`.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.49 VFX de combate · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `feel`, `combate`

VFX de combate en el estilo del juego: estela de la espada y partículas low poly con la paleta para chispas, polvo al rodar, flechas y bombas, sin bajar los FPS.

- [x] Estela de la espada
  Trail en el filo durante la ventana de golpe (AttackData), en la paleta (hueso/neón).
- [x] Partículas en el estilo
  Una sola fuente de partículas low poly con colores de la paleta: chispas al rebotar, polvo al rodar, anillo de carga del giro, estela de la flecha, explosión de bomba estilizada.

**Prueba:** Pelear y usar los ítems: cada acción tiene su efecto, todos con el mismo estilo, y no bajan los FPS con varios enemigos.

**Notas:** Skills: `disciplines:game-feel`, `godot:godot-shaders`. Va con 11.33. Estelas con Trail3D nativo (4.8). El anillo de carga del giro queda para cuando exista el spin attack (post-MVP).

**Referencias:** `gdd.md#combate`

**Relacionadas:** 11.33 Combate: sacar lo tosco; 10.28 Playtest de revisión (lo que está en Revisión); 12.9 Efectos con malla; 12.13 Reajuste de estilo toon de todos los assets

### 11.50 Audio del jefe · Revisión

**Prioridad:** baja · **Responsable:** project-epiphany-5c · **Etiquetas:** `jefe`, `audio`

Audio propio para el jefe: voz mecánica, chirridos, carga del orbe y golpes con grave, y un tema de música con capas por fase en lugar del placeholder.

- [x] Voz propia
  Zumbido mecánico de fondo, chirrido de párpados, carga del orbe, rugido de fase, golpes con más grave.
- [x] Tema de música
  Reemplazar el placeholder (Music.boss_fight) por un tema propio, con capas por fase.

**Prueba:** La pelea tiene sonido propio y la música cambia con las fases.

**Notas:** -5c (2026-10-19), paso 1 en d2cadaf2: tools/audio/render_boss_sfx.py (numpy + ffmpeg libvorbis) renderiza assets/audio/sfx/boss/*.ogg: zumbido en loop (Body/Hum, se apaga en el clip de muerte), chirridos de párpados (method keys en los clips de Lids), carga del orbe y del rayo (pistas de audio en OrbMuzzle/ChargeSound, una aturdida las corta), rugido (Roar.sound = boss_roar; los demás jefes siguen con roar), golpes de las manos (boss_slam, también la Mano) y golpes al ojo (boss_eye_hit). test_boss_juice › test_the_boss_has_its_own_voice. Paso 2 en ebe2a064: tools/audio/render_boss_music.py, tres loops de 16 s (8 compases a 120 bpm, Re menor): boss_drums (bombo, tic, bajo) desde la presentación, boss_theme (quena y colchón) desde la fase 2, boss_fury (bajo saturado, redoblante, coro) en la 3; Music.hold_boss(owner, boss.phase), las arenas sin tema siguen con el placeholder. test_audio › test_the_final_boss_theme_adds_a_layer_per_phase. Falta que Daniel escuche voz y tema (previews en wt/art debug/tmp/boss_audio/preview.wav y theme_preview.wav): cualquier cambio es re-render.

**Referencias:** `gdd.md#jefe`

**Relacionadas:** 11.46 Jefe: game juice

### 11.51 Pared agrietada que se integre al muro · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `arte`

Feedback de playtest (overworld, cueva de las bombas): la pared agrietada se delata sola. Es más fina que el muro y deja ver lo que tapa, y es piedra gris en un entorno marrón/pasto. Tiene que leerse como 'pared agrietada' por las grietas, no por el tamaño ni el color. Ver src/world/cracked_wall.tscn y su instancia en levels/overworld.tscn.

- [x] Mismo grosor que el muro
  Que tape por completo lo que hay detrás: no se tiene que ver el pasillo a través.
- [x] Mismo material que el entorno
  Usar la tierra/roca marrón del muro que la rodea, con grietas visibles como única pista.
- [x] Revisar las demás paredes agrietadas
  Overworld y templo, con el mismo criterio.
- [x] Puertas con el mismo grosor que el muro
  Lo de la pared fina también pasa con las puertas: que ocupen todo el grosor del muro.
- [x] Rejas en cada borde
  En un paso con grosor, una reja en cada cara del muro en vez de una sola en el medio.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.52 Zonas tapadas hasta abrirlas · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `mundo`

Feedback de playtest: en el overworld se ve lo que hay detrás de una pared rompible o puerta que todavía no se abrió, sin haber estado nunca ahí. Un velo de tinta (ZoneVeil, hijo de la AreaZone) tapa la zona mientras no se visitó y sus bloqueos siguen cerrados; al romper/abrir uno se disuelve con dither desde ahí, sin frenar al jugador. El minimapa no descubre lo tapado. Rejas no: dejar ver el cofre es el anzuelo.

- [x] Velo (escena + shader con disolución)
  src/world/zone_veil.tscn: caja de tinta del tamaño de la zona, se disuelve desde el bloqueo en ~1,2 s.
- [x] Minimapa respeta el velo
  No pinta lo descubierto dentro de un velo; durante la disolución acompaña la animación.
- [x] Poner los velos en el overworld
  Gruta oculta (GrottoCrackedWall) y santuario (ShrineCrackedWall).
- [x] Tests
  Velo visible al empezar, se va al romper la pared, no vuelve al recargar; minimapa no descubre a través.
- [x] Revisión visual
  Captura antes, durante y después de romper la pared.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.53 Agujero de la cámara solo donde tiene sentido · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `camara`

Feedback de playtest: el agujero con dither alrededor del player se recorta en el follaje de los árboles al pasar por un sendero angosto del overworld, y ahí no tiene sentido. Revisar en qué materiales se aplica (player_hole.gdshaderinc) y limitarlo a paredes/acantilados que realmente tapan al player.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.54 El velo de zona tapa también las paredes que la rodean · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `camara`, `overworld`

Feedback de playtest (seguimiento de 11.52): con la gruta tapada se ve el borde de la pared de la sala contigua, la tapa de pasto del muro entre el claro del inicio y la gruta queda entre el velo negro y el sendero, y más abajo una franja ancha de pasto sobre el acantilado sur. El velo debería llegar hasta la cara de la pared que da al lado del jugador, para que del otro lado de la pared no se vea nada.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.58 Los enemigos muertos desaparecen después de un rato · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Etiquetas:** `combate`, `feel`

Feedback de playtest: hoy el cuerpo queda en el piso para siempre (Enemy.on_death_finished solo lo pasa a la capa de muertos y suelta el drop). Después de unos segundos tiene que irse con un efecto acorde (hundirse/desvanecerse con dither o deshacerse en polvo), sin llevarse el drop y sin romper lo que dependa de 'defeated' (salas que abren al limpiar, jefe).

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 11.59 Limpieza de assets sin uso · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `arte`

Assets propios y packs de terceros que ninguna escena, script ni builder referencia (barrido del 2026-10-11). Revisar a mano: abrir el juego y las escenas de prueba tras mover cada grupo fuera del proyecto, por si algo se carga con una ruta armada en runtime (falso positivo).

- [x] Mallas viejas del templo
  assets/epiphany/meshes/templo/: jefe_mano, jefe_ojo, jefe_parpado (el jefe usa meshes/jefe/*) y tablilla (la tablilla usa objetos/estela). Si se borran, sacarlas también de build_templo.py, que las sigue generando.
- [x] Mallas sueltas de objetos, equipo y lugares
  equipo/poncho; lugares/escombro_b, lugares/pedestal, lugares/santuario_pared, lugares/santuario_piso. Sacarlas también de su build_<kit>.py. objetos/corazon, bombas_x3 y orbe NO: son los modelos de 12.5 (pickups y orbe) que todavía no se conectaron.
- [x] Textura vieja del Knight
  assets/epiphany/textures/knight_texture.png
- [x] Packs KayKit sin uso (≈42M)
  Hecho (1ae3b5df): fuera dungeon, dungeon_remastered, skeletons, medieval; de kaykit_adventure queda solo Characters/gltf/Knight.glb y su textura (fuente del rig de build_personajes y make_template). gdd.md lo anota.
- [x] kenney_development-essentials (1.3M)
  Nada lo referencia.
- [x] Decidir los packs que son fuente
  Decidido (Daniel, 2026-10-13): se quedan los dos, kaykit_charanim (fuente de player/animation/libs) y kenney_fantasy-ui-borders (original de assets/ui/frames), para poder regenerar.
- [x] Recortar packs que se usan en parte
  Hecho (1ae3b5df): kenney_skyboxes solo skybox-morning; Prototype Textures solo las 8 del kit gris (src/tools/build_gray_kit.gd). kenney_input-prompts sin tocar.
- [x] Probar que nada se rompa
  Abrir el editor (sin dependencias rotas), correr los tests y recorrer overworld, templo y escenas de prueba.

**Relacionadas:** 16.26 Orden de carpetas y lo que entra en la build release

### 11.60 Mazmorra nueva de varios pisos · Revisión

**Prioridad:** media · **Etiquetas:** `mazmorra`, `ui`

Mazmorra con pisos (y sótano) apilados en la misma escena, en vez de rehacer el templo: la Chullpa, hoy D1 (pluma). Decidido el 2026-10-11: mazmorra nueva; el co-op está en pausa, así que no condiciona el diseño.

- [x] Diseño: cantidad de pisos, sótanos, recorrido e ítem
  Decidido el 2026-10-11 con el usuario: 3 pisos (sótano, planta baja, alto) de 2 × 2 salas apiladas; temática chullpa (torre funeraria); ítem gancho (11.30) al principio, después la pluma (paso 8). Recorrido sala por sala en GDD §8b (gdd#mazmorra-2). Caer por un hueco lleva a la sala de abajo.
- [x] Pisos en la escena
  Hecho: DungeonFloor (level, nombre) con su GridMap y sus salas, a 8 m; la cámara oculta los pisos de arriba de la sala actual. Blockout en levels/chullpa.tscn (GDD §8b).
- [x] Escaleras y caídas entre pisos
  Hecho: Stairs (sube/baja, fundido corto, todos los players al marcador de llegada); un hueco con sala abajo cae a esa sala (sin daño, la entrada se anota al aterrizar); donde no hay, Pit. Piso agrietado (cracked_floor.tscn) que se rompe con bomba.
- [x] Salas, guardado y mapa por piso
  Hecho: Room cuenta solo en la altura de su piso; visitadas, mapa y brújula de la mazmorra; mapa de pausa y minimapa muestran el piso de la sala actual y sus puertas. Tests en test_chullpa.
- [x] UI: selector de pisos
  Hecho (mockup aprobado el 2026-10-11): columna de pisos en la pestaña Mapa (MapFloorButton: código, nombre, estás acá, cofres y jefe con brújula), LT/RT o RePág/AvPág (acciones map_floor_up/down) o clic; el cursor mantiene la celda; etiqueta del piso sobre el minimapa. Tests en test_map.
- [x] Entrada desde el overworld
  Decidido por Daniel el 2026-10-13 (vía la sesión del overworld): la Chullpa (D1) va en los Cerros del oeste, cerca de la Cueva de las bombas, accesible desde el inicio con espada y bombas. La Arboleda pasa a ser una meseta a la que solo se entra con un salto de pluma (la Queñoa, D2, pide la pluma); la Necrópolis queda sin mazmorra. -eb lo arma en 7.10 y pone un Spawn 'chullpa' frente a la torre (el portal de salida ya apunta ahí).
- [ ] Recorrerla (Daniel)
  Con el escenario chullpa: escaleras, caer de 1SE a la cripta y la llave en B-SO, atajo del osario cayendo desde 2NO, bomba en 2SE sobre la isla (pluma), y con la pluma el abismo, el foso de la llave del jefe, la brújula y la pieza del Mirador.
- [x] Rehacer con la pluma como ítem
  Hecho el 2026-10-12: el cofre grande de la isla da la pluma (FeatherChest, flag ch_feather_chest; era d2_feather_chest antes del cambio de prefijo de 11.113). Las franjas dobles de huecos (abismo de 1NE, foso de la llave del jefe, pieza del Mirador) son ahora una fila de una baldosa: se cruzan con la pluma. La llave chica pasó a B-SO (se llega cayendo desde 1SE, sin ítems) y la brújula a 2NO (pluma). data/dungeons/chullpa_graph.tres pasa el test de alcanzabilidad; test_chullpa salta las cuatro filas. GDD §8b.
- [x] Jefe del Guardián que se vence saltando
  Hecho el 2026-10-13 (3872d817): Mallqui, el Ancestro, en B-NE. Es la MummyGuard a 1,6× (24 de vida): saltitos, salto alto con la sombra fija y trabado al caer (ahí se le pega). Su onda cruza toda la sala, así que solo se pasa saltando con la pluma; con media vida salta dos veces seguidas. Da contenedor de corazón y abre el portal al overworld. test_chullpa lo pelea. Falta: que Daniel lo pruebe y ajuste a ojo (velocidad de la onda, vida, tiempo trabado).
- [x] Más enemigos y un acertijo por piso
  Hecho el 2026-10-13 (e8f78362). Entrada: dos bloques en fila y una placa entre columnas abren la reja de la escalera al piso alto. Cripta (B-SE): dos oleadas al caer; vencidas aparece el cofre del mapa (Chest.switches). Cripta oscura (B-SO): tres columnas de pinchos en ola hacia la llave. Piso alto: las placas del Rellano. Esqueletos en Entrada y Osario, arqueros en 2NO y el Mausoleo. El Osario no lleva bloques: solo se llega cayendo y un bloque trabado encerraría al player. Falta: que Daniel lo recorra.
- [x] Sub-jefe que guarda la pluma, sin ítems
  Hecho el 2026-10-13 (Daniel aprobó la propuesta). Momia Guardiana (MummyGuard, src/entities/mummy_guard/; modelo provisorio de primitivas para arte) en 2SE: se acerca a saltitos, salta alto con la sombra siguiendo al player, cae con golpe y una onda corta que se esquiva alejándose, y queda trabada para la espada, bombas o vasijas. EyeFight pasa a ArenaFight (src/world/arena_fight.gd) y sirve para cualquier peleador. Vencida, su caída rompe el piso agrietado (CrackedWall con switches: las bombas ya no lo rompen) y se cae sobre la isla de la pluma, que es la sala contigua. Acertijo previo en 2SO sin arco: la puerta a 2SE la abren una placa de peso (vasija grande de 2NO) y una placa en un nicho detrás de un muro agrietado (bomba). La llave chica de B-SO abre ahora 2NO. Grafo con guard ch_mummy_defeated (pasa las reglas del molde); test_chullpa juega el acertijo y la pelea. GDD §8b. Falta recorrerla (paso 7) y el jefe saltando (paso 9), que sería la versión grande de la momia.

**Relacionadas:** 11.30 Ítem de D3: el gancho

### 11.61 Pluma en el overworld: lugares de salto · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Tamaño:** M · **Etiquetas:** `movimiento`, `nivel`

El overworld es el hub: la pluma (11.35, templo) tiene que abrir ahí cosas y caminos nuevos. 2–3 lugares que solo se alcanzan saltando (huecos de una baldosa, escalón de 0,6 m), sobre el terreno que elija 12.14.

- [x] Esperar el terreno de 12.14
  No tocar levels/overworld.tscn hasta que 12.14 elija (variantes 6, 8 o 9; la otra sesión recomienda 9, marching cubes). Ninguna trae una cornisa baja caminable: meseta a 2,6 m, lomas suaves de ±0,3 m (rampa, no escalón), estratos decorativos de 0,1–0,16 m. Los lugares de salto y la cornisa de la pieza son piezas propias, de menos de 0,75 m (escalón de 0,6).
- [x] Pieza de corazón de la pradera en una cornisa
  HeartPieceMeadow en (−8, 0,6, −6), arriba de un Escalón en la celda (−4, −3), contra el acantilado norte de la pradera; se sube desde el este. test_meadow_heart_piece_sits_on_a_step.
- [x] 1–2 atajos o recovecos más con salto
  Grieta de una baldosa de ancho en las celdas (6, −6) y (6, −5): abre el acantilado entre la entrada del templo y el Risco, atajo con la pluma; CliffGapPit devuelve del lado del templo. Dos de largo porque con una el acantilado del sur (2,6 m) la tapaba desde la cámara. test_cliff_gap_is_a_feather_shortcut.
- [x] Tests y GDD
  test_jump: test_meadow_heart_piece_sits_on_a_step, test_cliff_gap_is_a_feather_shortcut. GDD §6.1 (pieza de la pradera) y §7 (pluma en el overworld). Terreno, muros y navmesh regenerados con los pasos de 12.15.

**Prueba:** Sin la pluma, la pieza de corazón de la pradera y los otros lugares no se alcanzan; con la pluma, sí. Ningún lugar obliga a saltar una pirca o un muro.

**Bloqueada por:** 12.14 Prueba: overworld menos cuadrado; 12.15 Overworld orgánico con lomas (variante 6)

**Relacionadas:** 11.35 Saltar: ítem tipo Pluma de Roc

### 11.62 Las puertas con llave se abren sin animación · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `mundo`

Al abrir una puerta LOCKED o BOSS, `_persistent.value = true` dispara `flag_changed`, el handler llama a `open(false)` y deja `is_open`; el `open(true)` de la línea siguiente sale temprano. Toda puerta con llave se abre de golpe, sin sonido ni polvo.

- [x] Abrir antes de guardar el flag
  door.gd `try_unlock` (~l.144): llamar a `open(true)` antes de `_persistent.value = true`, o que el handler de `changed` ignore si ya `is_open`.
- [x] Test
  En test_doors: la puerta con llave pasa por la animación (no queda abierta en el mismo frame sin tween).

**Prueba:** Abrir una puerta con llave en el templo: se ve la animación, suena y levanta polvo; al recargar la sala sigue abierta.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/world/door.gd`, `tests/test_doors.gd`

### 11.63 Objetos que no se actualizan al cargar en la misma escena · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `guardado`

heart_piece, push_block y tablet leen su flag una sola vez en `_ready` y no usan `PersistentFlag` ni escuchan `GameState.loaded`. Al cargar una partida de la misma escena desde el menú, la escena no se recarga: se puede volver a coger un fragmento de corazón (corazón duplicado), o queda oculto uno que en esa partida no se cogió, y el bloque no vuelve a `solved_position`.

- [x] Fragmento de corazón con PersistentFlag
  Como Chest y CrackedWall: hijo PersistentFlag en la escena, reaccionar a `changed`.
- [x] Bloque empujable y tablilla
  push_block.gd ~l.43 y tablet.gd `is_read`: mismo patrón.
- [x] Test de carga en la misma escena
  Guardar, cambiar el estado, cargar sin cambiar de escena, comprobar.

**Prueba:** Coger un fragmento, cargar una partida vieja de la misma escena: el fragmento reaparece; cargar una donde ya estaba cogido: desaparece. Igual con el bloque empujable.

**Notas:** Sale de la revisión de código general del 2026-10-11. Hecho escuchando `GameState.loaded` (también lo emite `reset`) en vez de un PersistentFlag, sin tocar escenas: la pieza se oculta o reaparece y el bloque va a `solved_position` o a su inicio. La tablilla no tenía el bug: `is_read()` consulta GameState cada vez. El bloque es AnimatableBody3D con sync_to_physics: la posición nueva se ve tras un frame de física.

**Archivos:** `src/world/heart_piece.gd`, `src/world/push_block.gd`, `src/world/tablet.gd`

### 11.64 Cargar partida: no colgarse ni cambiar de slot si falla · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `guardado`

`_restore_player` llama a `change_scene_to_file(GameState.spawn_scene)` sin mirar el resultado y espera `scene_changed`: si el nivel guardado ya no existe (se renombraron niveles con el overworld nuevo), la pantalla queda negra para siempre y `loading` en true (que además apaga los reveal de cámara). `load_game` además cambia `current_slot` antes de leer, así que una carga fallida deja guardando en el slot equivocado.

- [x] Comprobar la escena antes de cambiar
  save_manager.gd `_restore_player`: `ResourceLoader.exists` y `change_scene_to_file(...) == OK` antes del await; si no, fallback a NEW_GAME_SCENE o error, y resetear `loading`. `travel_to` ya lo hace.
- [x] Slot solo tras leer OK
  `load_game`: pasar el slot a `_load_path` y asignar `current_slot` cuando `SaveCodec.read` devuelve OK.
- [x] Tests
  test_save_manager: escena inexistente y slot corrupto.

**Prueba:** Una partida con `spawn_scene` inexistente vuelve con error (o al inicio) sin colgarse; cargar un slot corrupto no cambia el slot activo.

**Notas:** Sale de la revisión de código general del 2026-10-11. Hecho: si la escena guardada no existe, la partida carga en el comienzo (NEW_GAME_SCENE, spawn start) con lo que tenía y lo deja en el log; si change_scene falla, no espera scene_changed. La ranura cambia solo tras leer OK (load_game y load_scenario pasan la ranura a _load_path).

**Archivos:** `src/save/save_manager.gd`, `tests/test_save_manager.gd`

### 11.65 El escudo se queda levantado tras un hit-stop o la pausa · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `combate`, `input`

`is_blocking` solo cambia con los eventos de pulsar/soltar en `_unhandled_input`. Durante `Feel.hit_stop` o la pausa el player está DISABLED y no recibe eventos: si soltás el bloqueo en ese momento, el escudo queda arriba (velocidad 2.0, sigue bloqueando). Además se activa en Dead, Spirit, Carrying y Grabbed (bloquear es una de las teclas de forcejeo del agarre, y entonces el escudo frena golpes frontales).

- [x] Leer el estado del botón, no los eventos
  state_machine.gd ~l.530: en `_update` calcular `controls.pressed(&"block")` solo en los estados que permiten bloquear y llamar a `set_guard` cuando cambia.
- [x] Test
  test_shield: soltar con el player deshabilitado y comprobar que baja al volver.

**Prueba:** Bloquear, recibir un golpe imbloqueable y soltar durante el congelado: el escudo baja. Agarrado por el jefe, forcejear no levanta el escudo.

**Notas:** Sale de la revisión de código general del 2026-10-11. Hecho: el escudo se calcula en cada tick de la HSM desde `controls.pressed(&"block")` y solo en Idle, Moving, Attacking, Hurt y Transition. Los tests ya no fuerzan `is_blocking` en el blackboard: usan `hold_block(player, on)` (test_case.gd), que aprieta la acción, y run_tests suelta todas las acciones entre tests.

**Archivos:** `player/state_machine.gd`, `tests/test_shield.gd`

**Relacionadas:** 14.11 Feel solo cosmético: hit-stop como estado de gameplay

### 11.66 Pausa, reveal, portal y muerte se pisan get_tree().paused · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `ui`

El reveal de cámara y `travel_to` ponen `paused` a mano, y `MenuStack._can_pause` solo mira `Players.any_alive()`: se puede abrir la pausa durante un reveal o un fade de portal, y al cerrarla se despausa a mitad del reveal (o el reveal termina y despausa con el menú abierto). El timer de muerte (`create_timer(delay)`) corre en pausa y el GameOver aparece encima del menú de pausa.

- [x] No pausar si el árbol ya está pausado
  menu_stack.gd `_can_pause`: `not get_tree().paused and Players.any_alive()`.
- [x] Timer de muerte respeta la pausa
  player/states/dead.gd ~l.13: `create_timer(delay, false)`.

**Prueba:** test_pause › test_no_pause_menu_while_something_else_paused_the_game y test_dying_while_paused_waits_for_the_game_to_resume (fallan sin el arreglo).

**Notas:** Sesión de bugs (-fd). MenuStack._can_pause no abre la pausa ni el mapa si el árbol ya está pausado (reveal de cámara, fundido de SceneFlow), así cerrar el menú no despausa a mitad de eso. El timer de Dead es pausable: el game over (o volverse espíritu) espera a que el juego siga.

**Archivos:** `src/ui/menus/menu_stack.gd`, `player/states/dead.gd`

### 11.67 El anillo de ítems se abre durante una cutscene · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `ui`, `input`

`item_ring` es PROCESS_MODE_ALWAYS y `_can_open` no mira si otro sistema ya capturó los controles; `_close` siempre pone `captured = false`. Mantener LB en una cutscene abre un anillo invisible con `time_scale = 0.05` (la cutscene va al 5%) y al soltar el player puede moverse en mitad de la cutscene.

- [x] Respetar la captura ajena
  item_ring.gd `_can_open`: `(visible or not player.controls.captured)`; en `_open` guardar el `captured` previo y restaurarlo en `_close`.

**Prueba:** test_item_ring › test_the_ring_does_not_open_while_a_cutscene_has_the_controls (falla sin el arreglo).

**Notas:** Sesión de bugs (-fd). ItemRing._can_open: cerrado no se abre si los controles ya están tomados (una cutscene); abierto sigue mientras se mantenga LB. Al abrir guarda si estaban tomados y al cerrar los deja así (_was_captured) en vez de soltarlos siempre.

**Archivos:** `src/ui/hud/item_ring.gd`

### 11.68 Barra del jefe en fase 3 y animaciones que siguen tras morir · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `jefe`

`bar_fraction` usa `phase() == 2`, así que en fase 3 la barra vuelve a la vida de las manos. Además las manos al colapsar solo matan `_motion` y siguen corriendo los tweens de ataque (hold, shake, windup, bounce), y un aturdimiento durante la carga del orbe es pisado por el tween `grow`.

- [x] Barra en fase 3
  boss.gd ~l.148: `phase() >= 2`.
- [x] Un tween de ataque por mano
  boss_hand.gd: guardar los tweens de ataque en `_attack_tween` y matarlo en `collapse()` y al salir de BUSY.
- [x] Cortar la carga al aturdir
  boss.gd: guardar `grow` en un miembro y `kill()` en `_stun_eye` y `_on_defeated`.

**Prueba:** test_boss › test_the_bar_shows_the_eye_in_phase_three, test_a_collapsing_hand_stops_its_windup y test_stunning_the_eye_cuts_the_orb_charge (fallan sin el arreglo).

**Notas:** Sesión de bugs (-fd). bar_fraction: phase() >= 2. BossHand: los avisos de ataque (sostener del golpe, sacudida del agarre, carga del barrido) van en _attack_tween, que se mata al salir de BUSY y en collapse(); el rebote tras el golpe al piso va aparte (_bounce, solo lo corta collapse) porque la mano se aturde antes de que termine. Boss: la carga del orbe es _charge_tween; _stun_eye y _on_defeated la cortan con _cut_charge(), que además libera _eye_attacking (si no, el BT esperaba para siempre).

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`

### 11.69 Cambios de física dentro de callbacks · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `combate`

Se agregan, reparentan o liberan cuerpos dentro de señales de física (durante el flush), lo que Jolt puede rechazar o aplicar un paso tarde: `enemy._break_armor` (RigidBody nuevo al romper la armadura desde `Hurtbox.hit`), `carrier.drop()` al recibir un golpe cargando algo (reparent de un RigidBody vía `_on_hit` → dispatch hurt), y `thrown_object` → `shatter()` en `body_entered`.

- [x] Diferir la armadura
  enemy.gd `_break_armor.call_deferred()`.
- [x] Diferir el golpe del player
  player.gd `_on_hit`: `movement_state.dispatch.call_deferred("hurt")` (o diferir el reparent en `Carrier._release`).
- [x] Diferir el estallido
  thrown_object.gd: `liftable.shatter.call_deferred()`.

**Prueba:** Preventivo: hoy no hay errores de flush en los logs, así que no hay test que falle sin el arreglo. Siguen pasando test_armored_skeleton, test_lift, test_bombs, test_big_pot, test_tutorial y test_player (suite completa sin fallas propias).

**Notas:** Sesión de bugs (-fd). Enemy: romper la coraza saca la malla del cuerpo y deja de estar acorazado en el mismo golpe (la lógica sigue inmediata); el RigidBody que vuela se crea diferido (_fling_armor). Player: el golpe pasa a Hurt en diferido (_hurt, revalida que no esté muerto ni agarrado), que es donde suelta lo que lleva. Diferir Carrier.drop() no sirve: el _release diferido soltaba lo que levantaba después. ThrownObject: estalla y se libera en diferido (_shatter).

**Archivos:** `src/entities/enemy.gd`, `player/player.gd`, `player/components/carrier.gd`, `src/world/thrown_object.gd`

### 11.70 Sala que se cierra después de que los players se fueron · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `mazmorra`

`room._lock_after_entering` espera 0.6 s y cierra las rejas sin comprobar que la cámara sigue en esa sala; wave_spawner hace lo mismo. Si los players salen enseguida (escalera, pozo, paso atrás) quedan rejas cerradas en una sala vacía, y tras un `reload_current_scene` las corrutinas siguen sobre instancias liberadas. Los 0.6 s dependen sin decirlo del `transition_time` (0.5) de la cámara.

- [x] Revalidar después del await
  room.gd ~l.91 y wave_spawner.gd ~l.62/76: `is_inside_tree()` y que la sala de la cámara siga siendo esta.

**Prueba:** test_doors › test_a_room_left_right_away_does_not_lock: entrar y salir enseguida no cierra la sala vacía, y recargar la escena en ese momento no deja corrutinas sobre la sala liberada (falla sin el arreglo).

**Notas:** Sesión de bugs (-fd). Room: el cierre va en un tween de la sala (muere con ella) tras lock_delay (export, 0,6 s: algo más que TopDownCamera.transition_time) y revalida con has_player() de 11.97 en vez de la cámara. WaveSpawner: la pausa entre oleadas también es un tween suyo (y ya no corre en pausa) y, entre enemigos, después de esperar un frame revisa que siga en el árbol.

**Archivos:** `src/world/room.gd`, `src/world/wave_spawner.gd`

### 11.71 Minimapa y mapa: cachear las consultas a la escena · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `rendimiento`, `ui`

El minimapa recorre la escena entera cada frame: en mazmorra `room_pitch` es O(salas²) por puerta, y `MapData.doors()` escanea todas las celdas del GridMap cada 0.5 s (tirón periódico); en overworld hace `find_children` de Portal, Tablet y AreaZone. El cursor del mapa reconstruye el panel de info (`_focus_zone`, con más `find_children` y `load`) cada frame mientras se mueve el stick.

- [x] Cachear en el minimapa
  minimap.gd `_bind()`: paso entre salas, puertas del kit, portales, tablillas y zonas; por frame solo `Door.is_open`.
- [x] Panel del mapa solo al cambiar de zona
  map_page.gd `_focus_zone`: salir si la zona es la misma; cachear zonas, tablillas y fragmentos en `_show_overworld`.

**Prueba:** Profiler: el minimapa no aparece entre los costos por frame; mover el cursor del mapa no genera nodos nuevos si la zona no cambió. Cubierto en test_minimap › test_dungeon_doors_are_read_once_and_follow_their_state y test_map › test_cursor_reads_what_is_missing_in_a_zone.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/ui/hud/minimap.gd`, `src/ui/menus/map_data.gd`, `src/ui/menus/map_page.gd`

### 11.72 Búsquedas de nodos y trabajo por frame innecesario · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `rendimiento`

Varias búsquedas por frame o trabajo en nodos ociosos, baratos uno por uno pero que suman.

- [x] Jefe
  boss.gd: `%Charge`, `$Body/Eye/Mesh`, `%UpperLid`/`%LowerLid` en `@onready`; `phase()` sin Dictionary nuevo. boss_hand.gd: índices de blend shapes resueltos en `_ready`.
- [x] DoomAmbience
  Cachear la cámara, salir si `level` ya llegó al objetivo; WorldEnvironment y sol por `@export`.
- [x] Room y FloorSwitch
  room.gd: `set_process(Engine.is_editor_hint())` y material del contorno cacheado; floor_switch.gd: apagar el physics_process de un ONCE resuelto.
- [x] Arquero
  bt_shoot_arrow.gd: el arco se busca una vez en `_setup()`, tipado.
- [x] Música
  music.gd: escuchar `MenuStack.changed` en vez de buscarlo cada frame.
- [x] Cámara
  top_down_camera.gd: `framed()` una vez por tick; exclude de rayos cacheado en joined/left; `DebugOverlay.watch` solo en debug.
- [x] Unirse a la partida
  players.gd: `preload` de la escena del player.

**Prueba:** Profiler en templo y overworld sin get_node/find_child por frame en estos scripts. Cubierto en test_wiring (el interruptor resuelto deja de procesar), test_rooms (Room sin _process en el juego) y test_audio › test_music_ducks_when_a_menu_opens.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review). DoomAmbience: `world_environment` y `sun` son @export; sin asignar los busca entre los hijos del nivel (temple/templo no se tocaron).

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`, `src/world/doom_ambience.gd`, `src/world/room.gd`, `src/world/floor_switch.gd`, `ai/tasks/bt_shoot_arrow.gd`, `src/audio/music.gd`, `src/tools/top_down_camera.gd`, `src/state/players.gd`

### 11.73 Opciones: no guardar a disco en cada tick del slider · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `rendimiento`, `ui`

Cada `value_changed` llama a `Settings.set_value`, que reaplica todo (buses, modo de ventana, escala, idioma) y escribe settings.cfg: arrastrar un slider de volumen escribe decenas de veces por segundo.

- [x] Aplicar solo la clave cambiada
  settings.gd: `_apply` por clave.
- [x] Guardar al soltar o al salir
  options_panel.gd: guardar en `drag_ended` o al cerrar la pantalla.

**Prueba:** Arrastrar un slider escribe settings.cfg una sola vez. Cubierto en test_options › test_a_slider_saves_when_released_not_on_every_step.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/settings/settings.gd`, `src/ui/menus/options_panel.gd`

### 11.74 Guardado: validar tipos, versionado y slots · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `guardado`

Los datos cargados no se validan por tipo: una clave con tipo inesperado (por un cambio propio del esquema) tira error en las asignaciones tipadas de `GameState.read_from` y en `SaveCodec.validate`. `_migrate` corre después de validar, no hace nada y no rechaza versiones más nuevas. La migración de slots 0-2→1-3 corre en cada arranque protegida solo por `.slots_v2` (si se pierde, corre los slots y pisa el 3; y abre el marcador sin mirar null). Un slot con solo `.bak` aparece vacío.

- [x] Helper tipado
  `_typed(cfg, sec, key, default)` que vuelve al default si `typeof` no coincide; usarlo en `read_from` y `validate`.
- [x] Migrar antes de validar
  save_manager: `_migrate` primero; rechazar `version > VERSION`.
- [x] Quitar la migración de slots
  Era de antes de publicar; no hay build pública.
- [x] has_save mira el .bak
  save_manager ~l.120.

**Prueba:** test_save_codec › test_a_key_of_the_wrong_type_falls_back_to_its_default; test_slots › test_a_slot_with_only_its_backup_is_not_empty y test_a_save_from_a_newer_version_is_refused (fallan con el código viejo).

**Notas:** Sesión de bugs (-fd). SaveCodec.typed(cfg, sección, clave, default): vuelve al default si el tipo no coincide (avisa con push_warning); int→float y String↔StringName pasan. GameState.read_from lee todo con eso (la posición solo si es Vector3, el inventario solo cantidades > 0) y validate también. _load_path: versión más nueva que SaveCodec.VERSION → ERR_FILE_UNRECOGNIZED sin tocar nada; _migrate corre antes de validate. Quitada migrate_slots (y .slots_v2, y su test). has_save y copy_slot cuentan una ranura con solo .bak. GDD al día.

**Archivos:** `src/save/save_manager.gd`, `src/save/save_codec.gd`, `src/state/game_state.gd`

### 11.75 AreaZone: id estable para guardar las zonas visitadas · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `guardado`, `overworld`

`GameState.visit_zone(name)` usa el nombre del nodo como clave: renombrar una zona (como en el overworld nuevo) borra su estado de visitada de las partidas y el ZoneVeil vuelve a tapar zonas ya visitadas.

- [x] Exportar un id
  area_zone.gd: `@export var id: StringName`, usado como clave (fallback al nombre si está vacío).
- [x] Rellenar los ids en el overworld
  Con los nombres actuales, para no perder las partidas existentes.

**Prueba:** Renombrar el nodo de una zona no cambia si figura como visitada.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/world/area_zone.gd`, `src/world/zone_veil.gd`, `levels/overworld.tscn`

### 11.76 Constantes en vez de strings sueltos · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `arquitectura`

Claves del blackboard (`"target"`, `"is_blocking"`, `"is_hit"`, `"stunned"`, …) en ~20 lugares, `ITEM_ACTIONS` / `[&"item_1", &"item_2"]` copiado en 8 archivos, grupos y métodos de `call_group` como literales, ids de ataque del jefe que tienen que coincidir con los .tres. Un typo devuelve el default o no hace nada, sin error.

- [x] Blackboard y acciones de ítem
  Constantes StringName en PlayerState (generic.gd) y en Enemy; una sola lista de acciones de ítem.
- [x] Grupos
  Constante `GROUP` en la clase dueña de cada grupo (hud, room_camera, enemies, doors, wave_spawners, chests), como ya tienen Room y SpawnPoint; `spawn_point` con `is PlayerCharacter`, `room.gd` con el spawner tipado.
- [x] Ataques del jefe
  Ids en constantes compartidas con los .tres.
- [x] Etiquetas de botón
  items_page.gd `BUTTON_NAMES` X/Y → icono de InputPrompts (en teclado no es X/Y).

**Prueba:** Buscar los literales: cada clave/acción/grupo aparece definida una sola vez. test_boss › test_attack_ids_match_the_code revisa que cada data/boss/attack_*.tres use un id de BossAttack.IDS; los tests siguen usando los grupos como literales (prueban el contrato).

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review). Claves: PlayerState.BB_* y Enemy.BB_*; acciones: PlayerCharacter.ITEM_ACTIONS; grupos: Hud/TopDownCamera/Enemy/Door/WaveSpawner/Chest.GROUP (Hud es class_name nuevo); ataques: BossAttack.SLAM… e IDS. Las etiquetas Asignar/Asignado ya no dicen X/Y: el botón va como ícono de InputPrompts.

### 11.77 Player: escudo como componente y PlayerControls sin nodo · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `arquitectura`, `combate`

player.gd tiene ~470 líneas y ~200 son del escudo (bloqueo, reflejo, escudo trasero, luz espejo, empuje). `PlayerControls.new()` + `add_child` rompe la regla de nodos en el .tscn y no usa nada de Node.

- [x] Componente Shield en player.tscn
  Como Aim y Carrier.
- [x] PlayerControls extiende RefCounted
  Quitar el add_child; input_buffer.gd lee `controls` tipado.

**Prueba:** El player se comporta igual (tests de escudo y controles verdes) y player.gd baja de ~300 líneas. player.gd: 494 → 308 líneas; test_shield › test_the_shield_is_a_component_and_controls_are_not_a_node.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `player/player.gd`, `player/player.tscn`, `player/components/controls.gd`, `player/components/input_buffer.gd`

### 11.78 Limpieza menor de la revisión de código · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `arquitectura`, `ui`

Detalles sueltos de la revisión, sin bug visible o con efecto de un frame.

- [x] Liberar con remove_child
  items_page.gd ~l.183/201 y equipment_page.gd ~l.118: `remove_child` antes de `queue_free` (hoy duplican un frame).
- [x] Pantallas con contrato UiScreen
  TextBox, ItemGet y LanguageSelect extienden UiScreen; MenuStack tipado como `Array[UiScreen]`.
- [x] Feel sin tocar MenuStack._stack
  `MenuStack.depth()`.
- [x] Tipos estáticos
  text_box.gd `body`, pause_menu.gd `extra`/`accept`, minimap.gd `_doors`, bt_* `bow`.
- [x] Código sin uso
  ItemModifier sin subclases; estado Spawning que dura un frame (arreglar o quitar).
- [x] Arena del jefe
  boss.gd no depende del orden de nodos en temple.tscn para el rect de la arena.
- [x] Varios
  spring.gd usa `by.health`; ToonToggle limpia `_saved` de nodos liberados.
- [x] Accesos por ruta a nodos del player
  player_panel.gd `get_node(^"InteractionDetector")`, boss `get_node(^"Hurtbox")` (ya existe `player.hurtbox`), input_buffer `get_parent().get(&"controls")`, equipment.gd `owner.…` → propiedades tipadas en PlayerCharacter o `@export var player`.

**Prueba:** Tests verdes; sin cambios visibles salvo el parpadeo de chips/corazones.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review). text_box `body` queda Variant explícito: es Label o RichTextLabel y no comparten clase con visible_characters. Paso 5: ItemModifier se quitó (ningún ítem lo usaba; solo sacaba una línea ext_resource de 19 .tres); el estado Spawning se quitó y el player arranca en Idle; SwordTrail arranca con emitting = false (antes ese cuadro de Spawning lo tapaba).

### 11.79 Los corazones se rellenan al cambiar de escena · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `combate`

El estado del player (vida actual incluida) es global, no de la escena. Hoy GameState solo guarda `max_health`: cada nivel instancia su player y `_ready` → `_sync_health` → `health.reset(GameState.max_health)`, así que entrar o salir de una mazmorra (portal, escalera) rellena todos los corazones. La vida actual de cada player vive en GameState, se mantiene entre escenas y se guarda en el save.

- [x] Vida actual por player en GameState
  Guardar la vida de cada player (por índice de player, no un único valor) antes del cambio de escena (`travel_to`) y restaurarla en `_ready` en vez de `reset` al máximo. Se rellena solo en partida nueva, respawn tras morir y contenedor de corazón (ver 13.10 para no revivir espíritus).
- [x] Invitados
  Los invitados que se re-spawnean al cambiar de escena también conservan la suya.
- [x] Guardar la vida actual en el save
  Decidido (usuario, 2026-10-11): el estado del player es global y no depende de la escena; la vida actual de cada player va en el save y se restaura al cargar. Validarla contra max_health al leer.
- [x] Test
  test_portal o test_player: bajar vida, viajar, comprobar.

**Prueba:** Entrar al templo con 2 corazones, salir al overworld: siguen 2. Guardar con 2 corazones y cargar: 2. Con dos players, cada uno conserva la suya. Morir/reaparecer y partida nueva empiezan llenos.

**Notas:** Revisión de arquitectura del 2026-10-11. Hecho: `GameState.player_health` (por slot, en la partida, se borra en reset). El player la escribe en cada `health.changed` y al aparecer o cargar hace `health.restore(max, GameState.health_of(slot))`. Si la vida guardada es 0 o no hay, vuelve llena: así 'guardar y salir' tras morir y el respawn arrancan llenos. Un contenedor de corazón sigue llenando la vida. Un compañero en espíritu que cambia de escena vuelve con la vida llena (pendiente para el co-op).

**Archivos:** `player/player.gd`, `src/state/game_state.gd`, `src/save/save_manager.gd`, `src/state/players.gd`

**Relacionadas:** 13.10 Un espíritu revive al coger un contenedor de corazón

### 11.80 BossArena tiene los flags y el premio de D1 fijos en el código · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `jefe`, `mazmorra`

`boss_arena.gd` tiene `DEFEATED_FLAG := &"d1_boss_defeated"`, `CONTAINER_FLAG := &"d1_heart_container"`, el contenedor y `ending.dialogue` como const. Reusar la arena en D2 marcaría derrotado al jefe de D1 y pondría su final.

- [x] Exports
  `defeated_flag`, `container_flag`, `reward: ItemData`, `ending: DialogueResource`; setearlos en templo.tscn.
- [x] Avisos en el editor
  `_get_configuration_warnings` con `PersistentFlag.warnings_for`.
- [x] Premio por DropTable
  `_spawn_reward` usa `DropTable.drop_at`/el helper de pickups en vez de su copia.

**Prueba:** tests/test_flags.gd

**Notas:** Hecho (fd, 2026-10-14): los flags ya eran exports desde el templo nuevo; ahora también reward (ItemData) y ending (DialogueResource), seteados en templo.tscn (temple.tscn ya no existe). BossArena es @tool y avisa si falta algún flag, el premio o el fin. El premio sale de Pickup.make, el mismo que usa DropTable. Test: test_flags › test_boss_arena_takes_its_flags_and_reward_from_the_scene.

**Archivos:** `src/entities/boss/boss_arena.gd`, `levels/templo.tscn`

### 11.81 Dungeon.id por defecto d1 y prefijos de flags fijos · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `mazmorra`, `guardado`

`Dungeon.id` vale `&"d1"` por defecto y temple.tscn depende de eso (no tiene `id =`). Una mazmorra nueva que olvide el id comparte llaves, mapa y brújula con D1 sin aviso. `PersistentFlag.PREFIXES` es una lista fija `ow_, d0_..d3_` y SaveCodec deriva la sección del prefijo: D4 requiere tocar código.

- [x] Id vacío por defecto + aviso
  dungeon.gd: `&""` y config warning; cada mazmorra con su id explícito (templo.tscn: te).
- [x] Prefijos por regex
  `^(ow|d\\d+)_` en PersistentFlag y SaveCodec.
- [x] Opcional: avisar prefijo distinto
  Un flag `dN_` en una escena cuyo Dungeon.id no es dN.

**Prueba:** tests/test_flags.gd

**Notas:** Hecho (fd, 2026-10-14): Dungeon.id sin valor por defecto, @tool, avisa vacío o con _; todas las mazmorras ya tenían id explícito (ch, qv, tt, cu, te, d0). La lista fija de prefijos se fue (le faltaban tt_ y cu_, que avisaban de más): en una mazmorra el flag tiene que empezar con su Dungeon.id; afuera (overworld, cuevas) vale cualquiera registrado, porque el overworld lee flags de mazmorras. SaveCodec ya derivaba la sección del prefijo sin lista. Tests: test_flags › test_every_level_flag_has_its_dungeon_prefix, test_a_dungeon_without_id_warns; test_persistent_flag.

**Archivos:** `src/world/dungeon.gd`, `levels/templo.tscn`, `src/save/save_codec.gd`

### 11.82 Daño que no pasa por el Hurtbox · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `combate`

El pozo (`pit.gd:26`) y el agarre del jefe (`boss_hand.gd` ~353) llaman a `health.damage` directo: no aplica la reducción de la túnica, ni feedback, y en M14 son entradas de daño extra. El tick del agarre (0.75 s) es menor que los i-frames del player (0.8 s): la mitad de los ticks se pierden. La explosión de la marca y el arrojadizo llaman a `Hurtbox.receive` a mano y saltan el filtro de equipo/`_already_hit`. `DamageInfo.new()` se arma a mano en 8 lugares con equipo/elemento distintos.

- [x] DamageInfo.make
  DamageInfo.make(amount, knockback, source, element): sin equipo en la firma (EntityConfig.Team como valor por defecto armaba un ciclo de dependencias); los que lo necesitan lo asignan después. Usada en los 8 lugares.
- [x] Pozo y agarre por Hurtbox
  DamageInfo.unavoidable: saltea el escudo y los i-frames (Health.damage(amount, ignore_invulnerability)). Pozo y apretón del agarre pasan por player.hurtbox.receive; el agarre no despacha hurt mientras is_grabbed. El pozo vuelve a la orilla de donde cayó (PlayerCharacter.last_ground); la quebrada es un solo Pit con marcadores en las dos orillas.
- [x] Marca con Hitbox
  BlastHitTemplate (Hitbox de equipo enemigo, cilindro de 1,1 m: con la cápsula del player da los 1,6 de la marca) se duplica en cada explosión y queda prendido BLAST_FRAMES cuadros: lastima a cualquier player adentro.

**Prueba:** Con túnica, el pozo y el agarre restan menos; el agarre resta en cada tick; la marca daña a cualquier player dentro vía Hitbox.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/world/pit.gd`, `src/entities/boss/boss_hand.gd`, `src/entities/boss/boss.gd`, `src/components/damage_info.gd`, `src/world/thrown_object.gd`

**Relacionadas:** 13.7 Enemigos y jefe con varios objetivos; 16.15 Daño por fuera del Hitbox, tres formas de mirar si toca el piso y dos ondas iguales

### 11.83 Un solo camino para spawnear proyectiles, bombas y pickups · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `arquitectura`

Instanciar → `current_scene.add_child` → `launch` está copiado en projectile_behavior, turret, boss y bt_shoot_arrow; bombas y la grieta del slam van a `current_scene`, pickups a `get_parent()` o a `self`. Hay tres raíces de spawn distintas, y M14 necesita una para el MultiplayerSpawner. Además WaveSpawner hace `as Enemy` y `.position`: una torreta en una oleada crashea.

- [x] Arreglar el cast de WaveSpawner
  Aceptar cualquier Node3D o tipar por una clase común; darle `signal defeated` a Turret.
- [x] Helper de disparo
  `Projectile.fire(scene, from, velocity, info)` junto a `launch`.
- [x] Nodo raíz de spawn en los niveles
  Un nodo en el .tscn (grupo o export) que usan el helper, `DropTable.drop_at` y PlaceBehavior.

**Prueba:** tests/test_spawns.gd

**Notas:** Hecho (fd, 2026-10-14): src/world/spawns.gd › Spawns.root(nodo): el nodo del grupo spawn_root del nivel o, si no hay, la escena actual. Lo usan Projectile.fire (torreta, jefe, Amaru, arquero, ítems de proyectil), PlaceBehavior (bombas), el gancho, DropTable.drop_at, el premio de BossArena y la grieta del golpe del jefe. Ningún nivel tiene todavía su nodo spawn_root: todo cae en la escena actual, que es lo mismo que antes; para M14 alcanza con agregar ese nodo al nivel. Los enemigos de las oleadas siguen colgando de la sala (los necesita para dormir/despertar). WaveSpawner acepta cualquier Node3D con defeated e is_dead; Turret emite defeated. Tests: test_spawns (raíz de spawn, torreta en una oleada).

**Archivos:** `src/world/wave_spawner.gd`, `src/entities/turret/turret.gd`, `src/items/behaviors/projectile_behavior.gd`, `src/items/behaviors/place_behavior.gd`, `ai/tasks/bt_shoot_arrow.gd`, `src/entities/boss/boss.gd`

### 11.84 Ítems: que la estrategia decida, no la máquina de estados · Revisión

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `items`, `arquitectura`

La lógica de ítems se escapa del ItemBehavior al FSM del player: `_try_item` pregunta `is JumpBehavior` y `hold_to_aim`; using_item duck-typea `hold_time` y `leaves` (este último redundante: ConsumableBehavior ya llama a `swap_item`); aiming_throw castea a PlaceBehavior; AimingItem es solo-arco (animaciones, BowPhase, yaw). Un segundo ítem de apuntar (gancho, bumerán) usaría las animaciones del arco. Los estados leen `GameState.inventory` en vez de `ctx.inventory`; `ItemUseContext.equipped` no se usa.

- [x] entry_event() en ItemBehavior
  Por defecto `&"use_item"`; Jump → `&"jump"`; hold_to_aim → `&"aim_item"`. Borrar JumpBehavior como etiqueta de tipo si queda vacía.
- [x] hold_time en la base
  0 = sin mantener; quitar el bloque `leaves`.
- [x] AimingItem genérico
  Animaciones y yaw desde exports del behavior.
- [x] ctx.inventory
  Los estados usan el contexto; quitar `equipped`.

**Prueba:** Agregar un ítem nuevo de apuntar es un .tres + su behavior, sin tocar state_machine.gd.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).
Hecho (2a69be2d): ItemBehavior.entry_event() (Jump/Dash/Hook lo pisan) y _try_item despacha eso; hold_time en la base (bomb_bag.tres 0.25); grupo Apuntar con aim_animation y aim_yaw_offset_deg (bow.tres: Ranged_Bow_Draw, 62°), AimingItem ya no sabe del arco; los estados leen ctx.inventory; ItemUseContext sin equipped. Test: test_items › test_items_choose_how_they_start.

**Archivos:** `player/state_machine.gd`, `player/states/using_item.gd`, `player/states/aiming_item.gd`, `player/states/aiming_throw.gd`, `src/items/behaviors/item_behavior.gd`

### 11.85 Combate y HSM: casos que fallan en silencio · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `combate`, `jefe`

Tres puntos que no dan error cuando algo no cuadra: (1) el ataque melee elige la animación con un bool (Slash/ShieldThrust) e ignora `AttackData.animation`, que solo se usa para la duración: un arma nueva desincroniza hitbox y animación; el combo de MeleeBehavior tiene una sola entrada y siempre se usa `get_attack(0)`. (2) Los ataques del jefe se despachan por id en `match` sin default: un .tres con id nuevo o mal escrito no hace nada (mano) o dispara un orbe (ojo). (3) Los estados interrumpibles por `transition` y `grabbed` están en dos listas a mano en state_machine.gd: un estado nuevo que falte se queda atrás en el cambio de sala.

- [x] Animación desde AttackData
  `@export var tree_state` en AttackData; MeleeBehavior con un solo `attack` o avanzar el combo de verdad.
- [x] Ids de ataque del jefe
  Enum en BossAttack o rama `_:` con push_error; caso explícito `&"orb"`.
- [x] Interrupciones con anystate
  `add_transition(anystate(), …, guard)` con un guard común, o `@export var interruptible` en PlayerState.

**Prueba:** tests/test_items.gd

**Notas:** Hecho (fd, 2026-10-14): (1) AttackData.tree_state (entrada de AttackType: Slash, ShieldThrust); attacking.gd la usa en vez de elegir por is_blocking; MeleeBehavior tiene un solo attack (el combo nunca avanzaba); test_items › test_player_attacks_play_their_own_animation revisa que la entrada exista y reproduzca la animación del AttackData. (2) BossHand.perform con rama _: push_error; Boss.perform_chosen con caso explícito ORB y push_error si no; test_boss › test_unknown_eye_attack_does_nothing. (3) PlayerState.follows_room_transition y can_be_grabbed (en player.tscn: no siguen el cruce Transition, Pushing, ItemGet, Grabbed, Dead, Spirit; no se agarran los mismos menos Pushing) con transiciones desde anystate; test_player › test_room_transition_and_grab_come_from_each_state.

**Archivos:** `player/states/attacking.gd`, `src/items/behaviors/melee_behavior.gd`, `src/combat/attack_data.gd`, `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`, `player/state_machine.gd`

### 11.86 GameState: escrituras con señal y carga sin emisiones parciales · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `arquitectura`, `guardado`

Hay campos de GameState que se escriben a pelo desde afuera (`room_entry` desde la cámara y boss_arena, `boss_rematch`, `spawn_point`, `map_revealed` desde el minimapa), sin señal ni setter. El progreso del overworld lo pinta el minimapa del HUD: sin HUD no se registra lo explorado. `set_flag` emite aunque el valor no cambie. Cargar emite `dungeon_changed` dos veces y `inventory.changed` por ítem antes de `loaded` (el HUD crea un DungeonState fantasma; el mapa se reconstruye 2-3 veces).

- [x] Setters para los campos sueltos
  `set_room_entry`, `set_spawn_point`, etc.
- [x] Revelar el mapa desde el mundo
  `GameState.reveal_at(xz)` dueño de la Image, llamado desde un nodo del overworld; el minimapa solo lee.
- [x] set_flag sin cambio no emite
  Salir si ya tiene ese valor.
- [x] Carga en bloque
  Guard `_bulk` en `read_from`/`_clear` que suprime las señales finas; solo `loaded`.

**Prueba:** tests/test_game_state.gd

**Notas:** Hecho (fd, 2026-10-14): (1) Los campos sueltos (room_entry, spawn_point, boss_rematch) quedan como propiedades: nadie necesita enterarse de sus cambios, así que un setter con señal no agrega nada; se revisa si M14 lo pide. (2) OverworldMap pinta GameState.map_revealed en su _physics_process (el mundo, no el HUD) y emite GameState.map_revealed_changed; el minimapa solo lee y actualiza su textura; GameState.ensure_map_revealed crea la imagen. (3) set_flag sale si el valor no cambia. (4) reset y read_from cargan en bloque (_bulk, Inventory.quiet): solo emiten loaded; el anillo de ítems y la vertiente se refrescan con loaded. Tests: test_game_state › test_set_flag_only_emits_on_change, test_reading_a_save_only_emits_loaded; test_minimap › test_the_world_reveals_the_map_without_a_hud.

**Archivos:** `src/state/game_state.gd`, `src/ui/hud/minimap.gd`, `src/tools/top_down_camera.gd`, `src/entities/boss/boss_arena.gd`, `src/world/spawn_point.gd`, `src/items/inventory.gd`

**Relacionadas:** 16.21 GameState: separar el estado de sesión y las piezas sueltas

### 11.87 Valores de ajuste al inspector · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Etiquetas:** `feel`, `combate`

Varios valores de juego están como const o en sitios compartidos y no se pueden tunear a ojo en el editor.

- [x] Jefe
  boss.gd: 24 const (EYE_STUN_TIME, ENRAGE_FRACTION, MARK_*, REPEAT_PENALTY, SAME_HAND_PENALTY); boss_hand.gd: SLAM_HEIGHT, GRAB_REACH, IMPACT_HIT_STOP, SLAM_OVERSHOOT/BOUNCE → `@export_group`. Lo cosmético (bob, parpadeo) puede quedar const.
- [x] Player
  carrying.gd CARRY_SPEED/THROW_DISTANCE/FLIGHT_TIME, aiming_item.gd LOCKED_SPEED, carrier.gd → `@export`. Mantener la multiplicación por `player.ground_speed` (agua poco profunda, 11169f5): moving, generic `move_locked` y carrying la aplican.
- [x] Timing de ataque de enemigos
  windup_time, windup_pose, recovery_time de bt_attack a AttackData; `attack` en EntityConfig; enemy_bt.tres deja de fijar skeleton_slash.
- [x] Vida inicial y HP por corazón
  player.tres `max_health` se ignora (manda NEW_GAME_MAX_HEALTH); HP_PER_HEART copiado en game_state, player_panel, equipment_page y un `/ 4` en slot_card → una sola fuente.
- [x] Opciones fuera de feel.tres
  settings.gd escribe `shake_enabled` en el recurso de diseño; que Feel lo lea de Settings.
- [x] Rangos y test de ítems
  `@export_range` en EntityConfig, ItemData, DropEntry; test_items compara archivos de data/items con la base en vez de ITEM_COUNT.

**Prueba:** Cada valor listado aparece en el inspector o en un .tres; cambiar el windup del esqueleto acorazado no cambia a los otros.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).
Hecho (ec556751): const → exports en el grupo Ajuste (boss, boss_hand, carrying, aiming_item, carrier); lo cosmético (bob, parpadeo) quedó const. AttackData tiene el grupo Aviso (windup_time, windup_pose, recovery_time) y EntityConfig.attack lo elige; el esqueleto acorazado usa armored_slash.tres. enemy_bt.tres conserva skeleton_slash como respaldo (lo pisa EntityConfig.attack). GameState.new_game_max_health() lee player.tres y HP_PER_HEART vive solo en GameState. Feel.shakes() lee la opción de Settings (feel.tres ya no tiene shake_enabled). Rangos en EntityConfig, ItemData y DropEntry; test_items compara data/items con la base.

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`, `player/states/carrying.gd`, `player/states/aiming_item.gd`, `player/components/carrier.gd`, `ai/tasks/bt_attack.gd`, `src/entities/enemy_bt.tres`, `src/state/game_state.gd`, `src/settings/settings.gd`, `tests/test_items.gd`

### 11.88 Niveles referenciados por ruta: saves y portales frágiles · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `guardado`, `mundo`

Los saves guardan `spawn_scene` como ruta `res://` y los portales `target_scene` como ruta + `target_spawn` sin validar (solo test_portal/test_spring prueban casos sueltos). Renombrar o mover un nivel rompe partidas viejas y portales sin aviso.

- [x] Test de todos los portales
  tests/test_portals.gd: instancia cada levels/*.tscn, y cada Portal que viaja apunta a una escena que existe y que tiene un SpawnPoint con su target_spawn. Encontró la salida de la Chullpa sin punto de llegada; hoy Spawn_chullpa está frente a la torre en los Cerros del oeste (1f791fc9, 93ee37e6).
- [x] Aviso en Portal
  Portal es @tool: aviso en el editor si viaja y target_scene está vacío o no existe; en el editor no corre su _ready.
- [x] uid en el save
  GameState guarda spawn_uid junto a spawn_scene y al cargar resuelve el uid (si no, la ruta). Chullpa, dungeon_test y sandbox_items no tenían uid: se lo puse (ResourceSaver.set_uid). test_portals exige uid en todo nivel con SpawnPoint; test_save_manager carga un save con ruta vieja por su uid.

**Prueba:** Un test recorre todos los portales de levels/ y comprueba escena y SpawnPoint; mover un nivel no rompe una partida guardada.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/world/portal.gd`, `src/save/save_manager.gd`, `src/state/game_state.gd`

### 11.90 Diseño de mazmorras, ítems y su reparto en el overworld · Revisión

**Prioridad:** alta · **Tamaño:** L · **Etiquetas:** `diseno`, `nivel`

Playtest del 2026-10-12: la primera mazmorra ya tiene varios softblocks, y la pluma estaba en la mazmorra del arco (si no se mira el mapa, su sala pasa desapercibida). Rediseñar qué ítem da cada mazmorra, cómo se enseña y prueba dentro de ella, y dónde gatea el overworld, respetando que un ítem de la mazmorra N no gatea nada de las anteriores. Cadena actual (11.113): D1 Chullpa (pluma), D2 Queñoa (arco), D3 Totora (gancho), D4 Cumbre (escudo espejo), templo del ojo al final.

- [x] Softblocks de D1
  Hecho el 2026-10-12 leyendo temple.tscn y sus scripts (grafo y tabla en el documento de diseño). El orden de llaves es seguro: la llave 1 solo alcanza la puerta este del hub. Softblock duro solo cargando en la misma escena (11.108); los menores en 11.109; el de co-op en 13.16. Falta recorrer la Chullpa cuando se rehaga.
- [x] Ítem por mazmorra
  Decidido con Daniel el 2026-10-12, cambiado en 11.113: D1 Chullpa (pluma), D2 Queñoa (arco), D3 Totora (gancho, 11.30), D4 Cumbre (escudo espejo); el templo del ojo es la última. Los guantes de fuerza quedan fuera. El disco solar queda como ítem opcional. Documento: https://claude.ai/code/artifact/4fce85f9-7f11-4285-9d2e-bb1d58b45b4e
- [x] Mudar la pluma a la Chullpa
  Hecho el 2026-10-12. Templo viejo: sin sala de la pluma (puerta tapiada), sin la fila de huecos del Puzzle ni el escalón de la Antesala. La isla de la Chullpa da la pluma (ch_feather_chest) y lo que pedía gancho pasa a pluma (11.60, paso 8). Con 11.113 la Chullpa pasó a ser D1. La pieza de la pradera y la angostura quedan para después de la Chullpa.
- [x] Armadura del esqueleto
  Hecho: se la quitan el gancho (sin dañarlo), la bomba y el martillazo (golpe fuerte); enemy.gd _armor_stops. Tests: test_hookshot, test_armored_skeleton.
- [x] Reparto en el overworld
  Arco: Quebrada, Necrópolis, carcaj del Risco. Pluma: Cardonal, angostura, pieza de la pradera, islotes de la Laguna (entrada a D3). Gancho: postes de la Cumbre (entrada a D4), Mirador, franja del Risco. Cada ítem abre 2–3 secretos en zonas ya visitadas.
- [x] Grafos llave-cerradura de D1 y D2
  Hecho: data/dungeons/d1_graph.tres y d2_graph.tres, los dos pasan test_dungeon_reach.
- [x] Test de alcanzabilidad
  Hecho: DungeonGraph (src/world/dungeon_graph/) por mazmorra en data/dungeons/; tests/dungeon_reach.gd lo cruza con la escena (cerraduras, interruptores, cofres, cobertura de puertas, rejas, cofres e interruptores, salas) y recorre todos los estados (zona, ítems, llaves, puertas abiertas). Falla si algo pide un ítem que nadie da o si hay un estado sin salida, con el camino. test_dungeon_reach: D1 pasa, más casos sintéticos (llave en la puerta equivocada, caída sin vuelta, ítem que falta). El overworld (7.9) queda para después.
- [x] D3 y D4 abiertas en el playtest
  Daniel (2026-10-15): D3 y D4 ya están terminadas o en los últimos detalles, así que no se bloquean; el primer playtest externo va con las cuatro. El sistema de actualizaciones (build nueva por itch o parches) queda para después.
- [x] GDD §6 y §7 al día

**Notas:** Sesión: diseño (-43), con Daniel; antes overworld (-74). Toca 11.35/11.61 (pluma en D1 y en el overworld), los angostos de la quebrada (7.9), 11.30 (gancho, pasa a D3), 11.31 (sub-jefe con el arco) y la armadura del esqueleto.

### 11.91 Puzzle del claro: la reja se abre con solo pisar las placas · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `puzzle`

En el overworld, la pantalla a la derecha del spawn tiene un mini puzzle de dos placas y bloques para abrir la reja del cofre. Pisar las placas alcanza para abrirla: tienen que mantenerla abierta los bloques, no el player.

- [x] Las placas abren solo con peso que se queda
- [x] Test

**Prueba:** test_grove_puzzle: pisar las dos placas no abre la reja ni la resuelve; un bloque en cada placa la abre, y al volver los bloques siguen sobre sus placas.

**Notas:** Sesión de bugs (-fd). GroveSwitchA/B estaban en ONCE (pisar una vez la dejaba resuelta); pasan a BLOCK, así el player solo las baja mientras está encima y un bloque las deja resueltas. Además el solved_position de los bloques apuntaba a (28,0,4)/(32,0,4), lejos de las placas: al volver a la escena aparecían fuera del claro; ahora es la posición de cada placa. Ojo co-op: dos players parados uno en cada placa la abren (la reja se queda abierta).

### 11.92 Agarrar un cuarto de corazón cura · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `items`

Playtest 2026-10-12: tomar una pieza de corazón no cura. Que cure (a quien la toma, como el corazón en co-op), y al completar el contenedor que llene como ya hace.

- [x] Curar al tomar la pieza
- [x] Test

**Prueba:** test_heart_pieces › test_piece_in_the_world_is_taken_once: tomar la pieza cura un corazón a quien la toma.

**Notas:** Sesión de bugs (-fd). La pieza (heart_piece.tscn) cura 4 de vida, lo mismo que un corazón suelto, solo a quien la toma; al completar el contenedor llena como antes (cambia la vida máxima).

### 11.93 Jefe: aflojar la fase 3 y el modelo que se hunde · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `jefe`, `bug`

Playtest 2026-10-12: el jefe anda bien en general; la tercera fase es demasiado dura y el modelo suele hundirse en el piso.

- [ ] Nerf de la fase 3
  Menos daño, ventanas más largas o menos ataques encadenados; a ojo con Daniel.
- [x] Que no se hunda en el piso

**Prueba:** test_boss › test_phase_two_opens_the_eye_with_a_tremor: aturdido queda apoyado sin hundirse en el piso; test_marks_keep_the_eye_busy_until_they_blast: mientras se cargan las marcas no encadena otro ataque.

**Notas:** Sesión de bugs (-fd). Hundido: lo más bajo del cuerpo queda 2,35 m bajo su origen; aturdido bajaba a 1,9 y, con el bamboleo, se metía 0,45–0,57 m en el piso (en cada aturdimiento, más seguido en la fase 3). Ahora BODY_HEIGHT_STUNNED = 2,4 y aturdido no se bambolea: queda apoyado (el hurtbox del ojo está fijo, el alcance de la espada no cambia; la caída se ve más corta, 0,2 m en vez de 0,7). Fase 3, primer pase: respiro entre rondas 0,5 → 0,8 s (como la fase 2) y las marcas tienen ocupado al ojo hasta que estallan (antes lo soltaban a los 0,4 s y otro ataque se encimaba con el estallido). Para revisar: probarlo a ojo con Daniel; si sigue duro, lo siguiente es MARK_DAMAGE 4 → 2 o menos peso para mark. De paso: test_overlay_shows_the_fight era inestable (apuntaba a un player de un test anterior y a veces ningún ataque puntuaba); ahora sin objetivo. Playtest 17/10: se seguían hundiendo las manos. Era la mano caída (DOWN): ladeada baja más que apoyada y quedaba 0,3 m dentro del piso. e61b2cbb: cae a DOWN_HEIGHT 0,77 en vez de 0,4; medido en pelea, lo más bajo queda entre 0,02 y 0,09 sobre el piso. test_boss mide el vértice más bajo de cada mano caída.

### 11.94 Arquero: dispara sin frenarse a buscar distancia · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `enemigos`, `ia`

Playtest 2026-10-12: el arquero corta su ataque para reacomodarse a distancia de rango. No hace falta: que dispare y se reacomode sin cancelar el ataque.

- [x] BT del arquero
- [x] Test

**Prueba:** test_archer › test_a_close_player_does_not_cancel_the_shot: con el player encima a mitad de tensar sigue tensando, dispara y después se aleja.

**Notas:** Sesión de bugs (-fd). La raíz del árbol es un DynamicSelector con Alejarse antes de Disparar: se reevalúa cada tick y, si el player se acercaba a mitad de tensar, Alejarse cortaba el tiro. Ahora ShootArrow pone `drawing` en el blackboard mientras tensa y KeepAway no arranca con eso en true; apenas suelta la flecha, puede alejarse durante la recuperación.

### 11.95 Botellas únicas: 4 en total, cualquier contenido · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `items`, `bug`

Las botellas no son un consumible apilable: son 4 en todo el juego, cada una un ítem propio que puede tener cualquier contenido. Bug visible: dos botellas con el mismo contenido cuentan como una sola.

- [x] Modelo de datos
  Cuatro ranuras de botella con su contenido, no un stack por contenido.
- [x] Llenar, vaciar y usar
- [x] UI de Ítems y save (con migración)
- [x] Tests

**Prueba:** Dos pociones son dos botellas; nunca más de cuatro; un contenido llena primero una vacía; beber vacía solo esa botella; las botellas se guardan y las partidas viejas pasan sus pociones a botellas (test_bottles).

**Notas:** Sesión de bugs (-68). Hecho: las ranuras son ítems `bottle_1`..`bottle_4` (data/items), que ocupan su casilla y se asignan a X/Y. `GameState.bottles` guarda botella → contenido y `GameState.item_for(id)` resuelve qué mostrar y usar. Los contenidos (vacía, poción, agua bendita) llevan `bottled = true` y no tienen casilla. `give` de un contenido llena la primera vacía o suma una botella. `ItemUseContext.source` le dice al consumible qué botella vaciar. La migración (`_migrate_bottles`) corre al leer la partida. Se quitó `replace_on_buttons`.

### 11.96 Todo el estado del player es global durante la partida · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `guardado`, `bug`

Playtest 2026-10-12: el estado del player tiene que ser global toda la partida y no reiniciar valores al cargar una escena. 11.79 resolvió la vida; revisar el resto de lo que el player arma en _ready o el nivel reinicia al cargar.

- [x] Inventario de lo que se reinicia al cambiar de escena
- [x] Pasarlo a GameState
- [x] Tests de viaje ida y vuelta

**Prueba:** test_player_health: vida, bendición, equipo, botones y botellas siguen tras cambiar de escena; cargar una partida no arrastra la bendición.

**Notas:** Sesión de bugs (-68). Repasé lo que guardan el player y sus componentes en el nodo. Inventario, equipo, botones, botellas y vida ya estaban en GameState; los ajustes de fijación y apuntado salen de Settings. Lo único que se perdía era la bendición del agua bendita: SaveManager.travel_to la guarda por slot (`GameState.player_ward`, no va en la partida) y el player nuevo la retoma y la consume. Quedan fuera a propósito: la orientación al llegar (la da el punto de aparición), lo que se lleva en brazos (se suelta al viajar) y, en co-op, un espíritu que cambia de escena vuelve lleno.

### 11.97 Mazmorra: solo está activa la sala del player · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `mazmorra`, `rendimiento`

Hoy todo lo de la mazmorra corre a la vez: por ejemplo la línea de pinchos está activa aunque el player esté en otra sala. Las trampas, enemigos y efectos solo procesan en las salas con algún player (y se reinician o pausan al salir).

- [x] Activar y dormir por sala
- [x] Trampas y enemigos lo respetan
- [x] Tests

**Prueba:** test_rooms › test_only_rooms_with_a_player_run: el esqueleto y unos pinchos de una sala se duermen cuando el player pasa a la otra y despiertan al volver.

**Notas:** Sesión de bugs (-fd). Cada Room sabe si tiene algún player adentro (`occupied`, mira todos los players: en co-op corre toda sala con alguno). Cuando cambia, lo del grupo `room_sleepers` que está en una sala sin players pasa a PROCESS_MODE_DISABLED (se pausa y sigue donde quedó al volver; sus colisiones salen de la física mientras tanto); fuera de toda sala (overworld) siempre corre, y sin ningún player también. Están en el grupo, desde su .tscn: enemy.tscn (todos los enemigos), turret.tscn y spike_trap.tscn. Las oleadas no hace falta: arrancan al entrar. El jefe tampoco: su pelea arranca con la arena.

### 11.98 La cámara muestra lo que se desbloquea · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `camara`, `feel`

Siempre que algo se desbloquea por una acción (puzzle resuelto, horda eliminada, interruptores activados) la cámara va a mostrar qué se abrió y vuelve, como en Zelda.

- [x] Toma de cámara reutilizable
  TopDownCamera.reveal_unlock(): pausa, paneo a lo que se abre y vuelta (sobre reveal()).
- [x] Puzzles, oleadas e interruptores la usan
- [x] Tests

**Notas:** Sesión: overworld (-74).

### 11.99 Torres de D1: cambio visual al activarse · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `mazmorra`, `arte`

Las torres que se activan al reflejarles el ataque de la torreta en D1 no cambian a la vista cuando quedan activas.

- [x] Estado activo visible (luz, emisión, sonido)
  Al activarse, la torre de ojo prende una piedra dorada arriba (se ve desde la cámara cenital aunque el ojo mire de costado) y una luz que ilumina alrededor. El sonido de reflejo ya estaba.

**Notas:** Sesión: arte (-77).

### 11.100 Qué se puede levantar se tiene que entender · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `arte`, `ui`

Playtest 2026-10-12: levantar y tirar funciona, pero no se entiende qué objeto se puede levantar y cuál no.

- [x] Lenguaje visual de lo levantable
  Lo levantable lleva un cordón de lana roja y crema con nudo y borlas (vasija en el cuello; piedra nueva piedra_levantable, más clara y redonda que la de empujar). Al alcance, contorno crema (Liftable.highlight) junto al prompt Levantar. Interactable.focused avisa cuando algún player lo tiene de foco.

**Notas:** Sesión: arte (-77).

### 11.101 Zonas tapadas sin cuadrados sin explorar · Hecho

**Terminada:** 2026-10-12 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`, `arte`

Playtest 2026-10-12: las zonas tapadas (11.52, 11.54) no deberían verse como un cuadrado sin explorar, ni en el minimapa ni en el overworld.

- [x] Overworld
  ZoneVeil pasa de caja de tinta negra a banco de niebla con mezcla alfa (sin dither): nubes claras que se mueven despacio y un borde que se deshace en jirones suaves (fringe 3 m); el interior de la zona sigue tapado y el recorte al abrir también es suave. covers() no cambia. Playtest: el dither se veía horrible.
- [x] Minimapa y mapa (descartado)
  Daniel (2026-10-12): el velo en el overworld queda horrible y hace demasiado evidente que hay algo oculto. Los secretos del overworld se esconden por diseño (7.10) y ZoneVeil queda para otros usos; la niebla en el minimapa y el mapa se probó y se deshizo.

**Notas:** Sesión: arte (-77) el overworld; overworld (-74) el minimapa.

### 11.102 Mapa: nombres de zona chicos y solo los que importan · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`

Playtest 2026-10-12: los nombres de zona en el mapa son muy grandes y no hace falta que cada área tenga nombre.

- [x] Mockup
  Artboard 'Pausa · Mapa (overworld) por regiones grandes (11.102)' en el canvas: 8 regiones, cuevas y mazmorras con nombre propio. Daniel: sí, y el HUD también por regiones; el Santuario lleva nombre.
- [x] Regiones grandes y lugares con nombre
  AreaZone.region_label y display_name compartido por región; MapPlace para mazmorras, cuevas y santuario; el HUD nombra la región al cambiar de región.

**Notas:** Sesión: overworld (-74). Ajustar el mockup del canvas primero.

### 11.103 El minimapa se transparenta con el player debajo · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`

Cuando el player está debajo del minimapa en pantalla, el minimapa se transparenta para no taparlo.

- [x] Transparencia según la posición en pantalla
- [x] Test

**Notas:** Sesión: overworld (-74). Con varios players: cualquiera de ellos.

### 11.104 Ítems de la mazmorra en la pantalla del mapa · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`, `mazmorra`

Los ítems conseguidos en la mazmorra (mapa, brújula, llave del jefe, llaves chicas) se ven en la pantalla del mapa.

- [x] Mockup
- [x] Pestaña Mapa
  Íconos en lugar de texto (pedido de Daniel): map_dungeon_item.tscn, 4 en una grilla bajo el título.

**Notas:** Sesión: overworld (-74). Mockup primero.

### 11.105 Repensar el tutorial · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-72 · **Etiquetas:** `diseno`, `ui`

Playtest 2026-10-12: las tablitas del claro (11.45) funcionan, pero no son la mejor forma de enseñar los controles. Buscar otra. 2026-10-13 (Daniel): un mini tutorial cada vez que aparece una mecánica nueva, empezando por agarrar un ítem: qué hace, con qué botón y una situación para probarlo enseguida. Ejemplo: con el arco Daniel se olvidó de que dispararle al ojo era una mecánica; el juego tiene que mostrarlo.

- [x] Propuesta
- [x] Listar las mecánicas nuevas y dónde aparecen por primera vez: cada ítem (pluma, arco, sandalias, gancho, escudo espejo, bombas, martillo) y sus usos no obvios (flecha al ojo, salto largo, reflejar el haz, martillazo a la placa STRIKE), además de levantar, empujar, placas, etc.
- [x] Mini tutorial al agarrar un ítem: después del item get, un aviso corto con el botón del dispositivo actual y la mecánica que abre (p. ej. arco: 'dispará a los ojos de piedra')
- [x] Una situación para probarlo enseguida, cerca de donde se consigue (el primer ojo justo después del sub-jefe, etc.), en la línea de 11.90
- [x] Revisar las tablitas del claro: cuáles quedan y cuáles reemplaza el mini tutorial

**Notas:** Con 11.90 (cada mazmorra enseña su ítem). Daniel 2026-10-13: queda para el final, porque va a involucrar bastante rediseño.

Daniel (2026-10-20) approved -72's proposal as written: tutorial card after the item get (QUÉ HACE / BOTÓN / PROBALO; scene on the MenuStack with a mockup first), HUD chip with the task until it's done once (flags tut_<mecánica>_done), 30 s idle hint marking the target with the item icon. start_controls, start_combat and start_lift tablets go away (in-context prompts); start_temple stays; the bomb cave tablet keeps only the story line. New: item-get texts for feather, sandals, hookshot and hammer; hammer and sandals get a nearby test.

Core merged (-72, 43217633): 'Cómo se usa' card after the item get (tut_<id>_shown), HUD chip until the task is done (tut_<id>_done), 30 s hint over the nearest unsolved target; feather, bow, bombs, hookshot, hammer, sandals and mirror shield; item get texts for feather/sandals/hookshot/hammer. Fixed in passing: TextBox's tokens didn't accept hyphens ({btn:z-lock}). Missing: removing start_controls/combat/lift with in-context prompts, and hammer/sandals tests on the overworld.

Done (-72): in-context prompts for walk/attack/lock on/guard/roll (95918e7b); start_controls/combat/lift tablets removed and the sandals practice tree in the Necrópolis (c815357b, a305a31a); the hammer is tried on the Mirador plate. The long jump went to 11.222.

### 11.106 Intro al día con el overworld nuevo · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `camara`

La intro (10.20) funciona, pero sus planos son del overworld viejo. Rehacer los planos sobre el layout D.

- [x] Planos nuevos
  Cámara, brillo y polvo corridos al templo (−48, −37,5) y al Claro (−48, 16); test de encuadre por plano.

**Notas:** Sesión: overworld (-74), después de 7.9 paso 4. Junto con 10.30.

### 11.107 Mejorar la ambientación · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** M · **Etiquetas:** `arte`, `audio`

Playtest 2026-10-12: hay que mejorar la ambientación del overworld y las mazmorras: luz, niebla, partículas, sonido ambiente.

- [x] Qué falta por zona (con Daniel)
  Daniel (2026-10-12): luz, niebla y partículas estuvieron bien; no hay que cambiarlas. El sonido anda; no se fijó si falta algo.
- [x] Escuchar el sonido ambiente por zona en el próximo playtest
  Anotar qué zona suena vacía o repetida; recién ahí agregar o cambiar.

**Notas:** Sesión: arte (-77). Definir con Daniel qué falta en cada zona.

### 11.108 Cargar en la misma escena desincroniza puertas y flags · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `bug`, `mazmorra`

Encontrado en el análisis de D1 (11.90, softblock S1). Cargar desde la pausa una partida de la misma escena, sin recargarla, vuelve los flags a falso pero el mundo no los sigue: FloorSwitch ignora el falso (floor_switch.gd:37-41), EyeSwitch se apaga sin emitir (eye_switch.gd:38-42), y LightReceiver, WaveSpawner y Bridge solo reaccionan a verdadero; rejas y puertas solo se mueven con Wiring.changed. Si se cruza una puerta que debería estar cerrada y se guarda ahí, al recargar se queda encerrado (ej.: Ojos sin arco con el puente bajo). Arreglo probable: recargar siempre la escena al cargar una partida (save_manager.gd:344).

- [x] SceneFlow.enter_saved_scene recarga siempre la escena, aunque sea la misma
  Mientras carga, traveling queda en verdadero para que el checkpoint donde aparece el player nuevo no pise el spawn_point de la partida (pasaba con bombs_only).
- [x] Test: cargar en la misma escena da una instancia nueva con el muro entero

**Relacionadas:** 16.7 Cargar partida: la escena vieja recibe el save nuevo antes de irse

### 11.109 Softblocks menores de D1 · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `mazmorra`

Del análisis de D1 (11.90, S2, S4, S5, S6, S7). Los cuartos del análisis son del templo viejo (levels/temple.tscn, hoy nivel de prueba): se arreglan los bugs genéricos en los scripts, que pegan también en templo.tscn, la Chullpa y la Queñoa. Los niveles los toca diseño (-43).

- [x] S2: un bloque no entra en una celda de puerta
  push_block.gd. Pega en VestibuleBlock (templo) y los bloques de entrada de la Chullpa.
- [x] S4: la torreta no muere antes de cumplir su función
  Una torreta que alimenta un ojo o un cristal (MirrorTurret → MirrorCrystal en templo) no puede quedar muerta: inmune a sus orbes o revive al salir de la sala.
- [x] S5: la espada no mueve cajas físicas
  CrackedBox solo existía en el templo viejo: se descarta; solo confirmar que la espada no empuja cuerpos físicos en otro lado.
- [x] S6: un bloque resuelto queda trabado en su placa
  Genérico: una vez resuelta la placa, el bloque no se empuja más.
- [x] S7: munición en el templo (diseño, -43)
  Hecho por -43 en templo.tscn: vasijas que siempre dan bombas o flechas (pot_bombs/pot_arrows) en el Arco, el Ojo del arco y la combinada; lo cubre test_templo.
- [x] Bomba sobre placa BLOCK
  Ya no pasa desde 11.110: BLOCK solo lo aprieta un PushBlock. El orbe al ojo de Ojos era del templo viejo: descartado.

**Prueba:** test_push_block › test_a_solved_block_stays_on_its_plate y test_a_block_does_not_go_into_a_doorway; test_turret › test_a_destroyed_turret_comes_back_when_you_leave_its_room.

**Notas:** Sesión de bugs (-fd), con -43 (diseño). S2: PushBlock.can_move no entra a una celda a menos de 1,5 m de una puerta (el hueco del muro), abierta o no. S6: resuelto (is_solved), el bloque no se mueve más. S4: Turret.revives (true por defecto): destruida, vuelve cuando el player sale de su sala (player_left); ser inmune a su orbe rompería los puzzles de reflejo. S5: la espada empuja cuerpos físicos a propósito (Hitbox._on_body_entered); en el juego solo hay cajas y rocas sueltas (overworld, cueva de bombas), ninguna trabada en un puzzle. S7 lo hizo -43 en templo.tscn. La bomba en placa BLOCK ya no aprieta desde 11.110. De paso: las tareas de IA que leen el objetivo del blackboard descartan un player ya liberado (salió en test_intro).

### 11.110 Tipos de placa de piso: bloque, peso y golpe fuerte · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `puzzles`

Playtest 2026-10-12: los puzzles de bloques solo se tienen que activar con los bloques; los que se activan con objetos o con un golpe fuerte son otros tipos de placa. Y la placa del santuario se veía apretada sin bloque encima.

- [x] BLOCK solo con bloques y modo WEIGHT para objetos
  FloorSwitch: BLOCK lo aprieta solo un PushBlock (ni el player ni lo arrojado); WEIGHT, un objeto apoyado o arrojado (o un bloque), no el player; los dos quedan resueltos con flag. Santuario y mazmorra gris pasan de ONCE a BLOCK; la placa de levantar del Claro a WEIGHT. Tests: test_wiring, test_grove_puzzle. GDD §11 (interruptores) y §5 (tutorial).
- [x] Placa del santuario apretada sin bloque
  ShrineBlock tenía solved_position del overworld viejo (−30, −16): al cargar con el puzzle resuelto el bloque aparecía lejos y la placa quedaba apretada sola. Ahora (−78, −32); test_solved_blocks_rest_on_their_switch revisa todos los niveles.
- [x] Que cada tipo se distinga a la vista
  Hoy las cuatro placas son iguales. Marca o color por tipo (bloque, peso, golpe fuerte); pasa por el arte.
- [x] Placa de golpe fuerte
  Hecho: martillo 11.191 (-43), mini jefe que lo da 11.192 (-eb), modo STRIKE 11.193 (-5d).
- [ ] Probarlo (Daniel)

**Notas:** Al sacar las capturas (2026-10-14) apareció que la placa del santuario seguía mal: ShrineBlock resuelto iba a (−78, −32), coordenadas del overworld, y la placa de shrine_cave está en (−6, 0); el test no revisaba shrine_cave. Ahora test_solved_blocks_rest_on_their_switch recorre todos los niveles, y encontró dos más corridos por el horneado LA: RamaBlock de la Queñoa (14, 10 → 16, 12) y VestibuleBlock del templo (44, 40 → 48, 48). Los tres van a su placa.

**Capturas:** `compass/images/m11-110-mapa.jpg`, `compass/images/m11-110-1.jpg`, `compass/images/m11-110-2.jpg`, `compass/images/m11-110-3.jpg`

### 11.111 Cactus, árboles y matas se cortan como el pasto · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** M · **Etiquetas:** `overworld`, `arte`

Playtest 2026-10-12: los cactus, árboles y similares deberían poder cortarse y funcionar como el pasto.

- [x] Escenas Breakable de cada planta y reparto en el overworld
  src/world/plants/*.tscn. Celdas del kit (Árbol, Queñoa chica, Cardón, Cardón brazos) sin malla ni colisión en el kit orgánico; decorate_levels.gd pone la escena en cada celda, en las 553 plantas que el terreno orgánico dejó en el piso jugable (tools/plantas_overworld.json) y en las piezas de planta de la decoración. Arriba de los riscos siguen en la malla. Terreno, kit, decoración y navmesh regenerados. 60 fps en la arboleda. Test test_overworld_plants_are_cut_like_grass. GDD §7.
- [x] Probarlo (Daniel): cortar un árbol abre paso, ¿hay alguno que no debería?
- [x] Animación al romperse
  Daniel: que tengan un poco de animación. Breakable.break_style: CUT (pasto y matas: saltan girando y se achican; el ichu deja la mata cortada), FELL (árboles y cardones: caen del lado contrario al golpe, polvo y rebote, se hunden; los árboles dejan tocón). Cuerpo y hurtbox se apagan en el acto. Tests en test_breakables.

**Capturas:** `compass/images/m11-111-mapa.jpg`, `compass/images/m11-111-1.jpg`, `compass/images/m11-111-2.jpg`

### 11.112 Fantasmas al esquivar · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `feel`

Daniel 2026-10-12: al dash/esquivar ponerle un efecto similar al trail de la espada, como el ghosting del dash de Mega Man Zero.

- [x] Copias de la pose que se desvanecen
  DodgeGhosts (player.tscn) congela la pose cada 0,06 s mientras dura el roll; afterimage.tscn + ghost.gdshader (rosa translúcido con borde claro, depth prepass para que se lea la silueta) se desvanece en 0,3 s. Test test_roll_leaves_ghosts_that_fade. GDD §2 (feel).
- [x] Probarlo (Daniel): color, cantidad, duración

### 11.113 El templo del ojo pasa a ser la última mazmorra · Revisión

**Prioridad:** alta · **Etiquetas:** `diseno`, `nivel`

Daniel (2026-10-12): el jefe del ojo se pensó como fin de demo, así que tiene sentido que sea el final del juego. El templo pasa a ser la última mazmorra, después de D4; el escudo espejo (ítem de D4) es lo que se consigue para entrar (el sello de luz). Cadena actual: D1 Chullpa (pluma), D2 Queñoa (arco), D3 Totora (gancho), D4 Cumbre (escudo espejo) y el templo del ojo al final (sin ítem). Hay que ampliar el templo para que use todos los ítems. Cambia la cadena de 11.90 y el reparto del overworld (7.10).

- [x] Cadena nueva de mazmorras e ítems (con Daniel)
  Decidido con Daniel el 2026-10-12 (D1 y D2 invertidos después, paso 9): D1 Chullpa (pluma), D2 Queñoa (arco), D3 Totora (gancho), D4 Cumbre (escudo espejo), y el templo del ojo como última mazmorra (usa todos los ítems, no da ítem). Los guantes de fuerza quedan fuera. Cada ítem lo guarda un sub-jefe basado en el jefe de su mazmorra, que se vence sin ese ítem; la segunda mitad de la mazmorra se resuelve con el ítem, combinado con los de mazmorras anteriores. GDD §6.2.
- [x] Dónde se consigue el escudo espejo y qué lo gatea
  Decidido: es el ítem de D4 (la Cumbre). El santuario del primer acto ya no lo da.
- [x] Ampliar el templo: salas que usen todos los ítems
  Diseño hecho el 2026-10-13 (Daniel: si): hub con cuatro alas, una por ítem (pluma, arco y bombas, gancho, escudo espejo); cada ala enciende un ojo del sello del hub, y los cuatro abren la antesala. Sub-jefe la Mano (un guantelete del jefe) guarda la sala combinada con la llave del jefe; el templo no da ítem. Salas de 14 × 12 m (cámara fija). Escena nueva levels/templo.tscn con flags te_; grafo de diseño data/dungeons/templo_graph.tres. GDD §8. Se construye en los pasos siguientes.
- [x] GDD §6 y §7, y el boceto de 7.10 al día
  Hecho el 2026-10-15: §6.1 (pluma, arco, escudo espejo con su mazmorra y sub-jefe; espada dorada; contenedor del santuario), §6.2 (árbol con nombres, sub-jefes y jefes; grafos y prefijos de las cinco), §7 (cadena de 7.1, boceto 7.10 nuevo con la forma real del overworld y las puertas, tabla de regiones, cadena, verificación del gating y curva de ritmo).
- [x] Qué es D1 (arco) y dónde está; qué da el santuario
  Hecho el 2026-10-12 (Daniel: sigue): La Queñoa Vigía en el claro de la Arboleda (boceto 7.10 v4). Blockout levels/quenoa.tscn: Raíces, Tronco y Copa de 2 × 2 salas, llaves, bloque, ojos, muros agrietados, sub-jefe como oleada que guarda el arco; d1_graph.tres con escena pasa el test y las reglas; test_quenoa (escaleras, caídas, reja del tronco, bloque); escenario quenoa. GDD §8c. Santuario (Daniel 2026-10-15): da la cota reforzada después de D4, con el cristal del escudo espejo; el contenedor que daba pasa al puzzle de bloques de la Arboleda (los dos cofres intercambian ítem, flags iguales).
- [x] Chequeo de grafos de diseño y reglas del molde
  Hecho: un DungeonGraph sin escena es de diseño (locked en los pasos, gives/key en los lugares) y test_dungeon_reach lo recorre igual; con escena, la escena tiene que coincidir con locked/key. Reglas: sin el ítem no se llega al objetivo; el ítem pide al sub-jefe (guard), que se vence sin él. tools/dungeon_graph_mermaid.gd lo dibuja. El grafo del templo pasa a temple_graph.tres.
- [x] D1: sub-jefe ojo vigía y jefe de los dos ojos
  Hecho el 2026-10-12. WatcherEye (src/entities/watcher_eye/): un ojo flotante que se abre, marca una línea en el piso y la barre con un rayo. Sub-jefe Ojo Vigía: después del barrido se tira sobre el player y queda enganchado en las raíces, y ahí le pegan espada, bomba o vasija. Jefe Los Ojos de la Queñoa: dos ojos, de a uno por vez; una flecha con el ojo abierto lo derriba para la espada, y el que queda se apura. EyeFight maneja la pelea como una oleada: cierra las puertas, intro, barra, se reinicia si el player sale, flag e interruptor. Con la regla de Daniel (salas sin obstáculos, cofre del ítem en una sala contigua que abre el sub-jefe), la guarida pasa a la sala SE con vasijas y el arco a la Cámara del arco (SO), detrás de una puerta que abre el sub-jefe. Contenedor de corazón y portal de salida. test_quenoa juega las dos peleas.
- [ ] D1: kit de árbol y recorrerla (Daniel)
  Arte hecho el 2026-10-13 (sesión de arte, 12.18 y 3b3aaa33): la Queñoa tiene el estilo LA (doble muro, cámara, kit) y las paredes sueltas dentro de las salas (nichos de cofres, reja de la escalera del tronco) son paredes bajas LA de 1,3 m con borde de hojas; la colisión no cambió. Rejas y puertas con una sola hoja en el medio del paso (e34db47f). Falta: recorrerla (Daniel) con el escenario quenoa (ahora es D2: trae bombas y pluma).
- [x] Invertir D1 y D2: la pluma primero
  Hecho el 2026-10-13 (Daniel: la pluma es mejor como primer ítem de mazmorra). La Chullpa es D1 (pluma) y la Queñoa D2 (arco); ninguna pedía el ítem de la otra. Grafos renombrados a chullpa_graph.tres y quenoa_graph.tres; la Chullpa trae solo bombas y la Queñoa bombas y pluma. Id y flags de la Chullpa pasan de d2 a ch (prefijo por mazmorra: ch_, qv_, d1_ el templo). Escenario chullpa sin arco ni pluma, quenoa con pluma. GDD §6.1, §6.2, §8b y §8c. Falta: §7 y el boceto de 7.10 (dónde está la Chullpa, qué gatea el camino a la Arboleda) con la sesión del overworld; la Queñoa no usa la pluma todavía.
- [x] D2: segunda mitad de la Queñoa con la pluma
  Hecho el 2026-10-13 (4ed4b97d, Daniel: si). Raíces: un ojo con tiempo (6 s) abre la reja RaicesGate, rodeada de huecos frente a la puerta a la Sala de los ojos: flecha, salto con la pluma y pasar antes de que se cierre; una placa del otro lado (qv_eyes_step) la deja abierta para volver. Sala de los ojos: el nicho de la llave del jefe queda tras una fila de huecos (bomba, arco y pluma). Grafo y test_quenoa al día. Falta: que Daniel lo recorra y ajuste el tiempo del ojo.
- [x] Templo: escena y salas (sin el ala del gancho)
  Hecho el 2026-10-13 (af952662): levels/templo.tscn con 14 salas de 14 × 10 m (jefe 22 × 10), armada con debug/tmp/build_templo.gd en el kit gris (arte le pone el estilo LA al final, 12.18 paso 3). Vestíbulo, alas de la pluma, del arco y del espejo, sello de los cuatro ojos, combinada y jefe con flags te_. El ala del gancho queda tapada por un abismo hasta 11.30. test_templo (7). Falta: la Mano (paso 12) y apuntar el grafo templo_graph.tres a la escena cuando esté completa.
- [x] Templo: la Mano, sub-jefe
  Hecho el 2026-10-13 (f8bad885, Daniel: si): HandGuard (src/entities/hand_guard/) es una copia de la mano del jefe (boss_hand.gd, 12 de vida) que pelea sola en una ArenaFight: golpe al piso, agarre y barrido, sin repetir el último; rebota todo mientras está lista y queda aturdida tras el golpe al piso, ahí entra la espada. ManoFight (te_hand_defeated, BOSS_TE_HAND) cierra HandDoor y al ganar abre la combinada. templo_graph.tres apunta ya a levels/templo.tscn y pasa test_dungeon_reach; test_templo (8). Falta: que Daniel la pruebe y ajuste vida y descanso.
- [x] Templo: ala del gancho (con 11.30)
  Hecho (ec19eb0b, 30a2703c): ala del gancho con Gancho y GanchoPit en levels/templo.tscn.
- [x] Templo: el portal del overworld al templo nuevo
  Hecho el 2026-10-13 (ca9d975d, Daniel: sigue): la puerta del templo del overworld (TempleDoor) lleva a levels/templo.tscn, spawn start en el vestíbulo; la mazmorra es te. levels/temple.tscn se borró después en 11.162 (072e1094). test_portal, test_overworld_run, test_temple_seal y test_coop_camera al día.

**Notas:** Sesión: diseño (-43 [a7e236]), con Daniel. Overworld (-eb) acomoda el boceto de 7.10 cuando esté la cadena.
Daniel (2026-10-14) confirma: el templo del ojo con manos es la última mazmorra.

### 11.114 Botellas en su propia fila de la pestaña Ítems · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`

Daniel (2026-10-12): las botellas tienen su fila fija, separada de los ítems comunes, en la misma pestaña.

- [x] Mockup Pause_Items: fila Botellas debajo de la grilla
- [x] items_page: grilla de 8 sin botellas y BottleGrid con bottle_1..4; el cursor de co-op recorre las dos
- [x] Tests: test_bottles_have_their_own_fixed_row y test_item_ring al día

### 11.115 Enemigos que deambulan mientras no te ven; centinelas con alerta y búsqueda · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-3e · **Etiquetas:** `ia`, `enemigos`

Daniel (2026-10-13): los enemigos que no te detectaron no se quedan quietos. Todos deambulan cerca de su lugar: caminan despacio a puntos al azar de la navmesh dentro de unos metros de donde empiezan, paran un rato y miran alrededor (reemplaza la rama Quieto de enemy_bt.tres; radio, velocidad y pausas en EntityConfig). Alerta y búsqueda solo para un tipo de enemigo nuevo: el centinela o guardia de una guarida de un grupo enemigo que no son monstruos. Al verte hace una pausa de alerta (un !) antes de atacar; si te pierde va a tu último lugar visto, mira alrededor y vuelve a su puesto. Descartados por ahora: rondas fijas y cono de visión.

- [x] Deambular cerca de su lugar para todos los enemigos
  Hecho el 2026-10-14 (-fd): ai/tasks/bt_wander.gd reemplaza la rama Quieto de enemy_bt.tres (ahora Deambular): punto al azar de la navmesh a wander_radius (3 m) de donde empezó, en su misma sala, caminando a wander_speed (1,2) con Walking_A; pausa wander_pause (1,5 a 3,5 s) con Idle_A. Ver al player lo corta (BTDynamicSelector). Si cae a otro nivel, su lugar pasa a ser donde cayó. Datos en EntityConfig. test_enemy_ai. Falta que Daniel lo vea y ajuste radio, velocidad y pausas.
- [x] Diseño del centinela: quién es el grupo enemigo no monstruo y cómo se ve
  Tipo de enemigo nuevo para guaridas (personaje humano o de una facción, no esqueleto). Lo decide Daniel con diseño y arte.
- [x] Alerta y búsqueda del centinela
  Hecho (-fd, 2026-10-15) con un guardia provisorio (src/entities/guard.tscn, esqueleto; guard_bt.tres): al verte se frena con un ! (bt_alert, 0,7 s) y después ataca o persigue; si te pierde corre a tu último lugar visto (FindPlayer guarda last_seen), mira a los lados (bt_search) y camina de vuelta a su puesto (Enemy.home) antes de calmarse. Cuando se decida el modelo (paso 2) se cambia la escena, no la IA.
- [x] Tests
  test_guard (alerta, persecución, búsqueda, vuelta y nueva alerta); deambular en test_enemy_ai.
- [x] Construir los Devotos del Ojo
  Enemigo con la IA del centinela (alerta y búsqueda), estocada de lanza con aviso largo pensada para el contraataque; guaridas con fogón y estandarte en el Cardonal y el Bañado. El modelo (poncho, máscara con epi.logo_eye, lanza) lo arma arte.

**Prueba:** test_camps (fogón, estandarte y dos Devotos a menos de 5 m de cada fuego, sobre piso caminable, a más de 15 m de los portales), test_devoto (alerta, búsqueda y vuelta; la estocada larga se puede contraatacar), test_guard, test_enemy_ai. A mano: caminar al Cardonal (28, 0, 25) y al Bañado (84, 0, 37).

**Notas:** 
Daniel (2026-10-14): deambular es para que los enemigos no parezcan objetos quietos (paso 1 vale para todos).

Daniel (2026-10-20) step 2: Devotos del Ojo. Humans on Rig_Medium, long burgundy-and-black poncho, hood, white mask with a single eye (epi.logo_eye), spear with a red ribbon; long-wind-up thrust built for the 11.34 counterattack; camps with a fire and a banner in the Cardonal and the Bañado; later variant: the slinger.

Paso 5 hecho (2026-10-20): enemigo -72 (devoto.tscn f6125106, modelo d1bf4927: estocada con 0,9 s de aviso, contraatacable); campamentos -3e (bd9b8735): Cardonal en (28, 0, 24.5–27), al sur de la ruta de test_walk_the_east_bank; Bañado en (84, 0, 35.5–38) con BanadoWater1 recortado 6 m al este; dos Devotos por fogón; terreno rearmado. Navmesh rehorneada por -25 (edfc2647). La decoración del Bañado no siguió al recorte: 11.227. Falta que Daniel lo vea.

### 11.116 Tests: un error de script cuenta como falla · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `tests`

Un SCRIPT ERROR corta la función del test pero el runner la cuenta como ok si ya había verificado algo (test_dungeon_reach dio 7/0 con el grafo cortado en el primer chequeo). Que todo error de script mientras corre un test lo marque FALLA y muestre el error.

- [x] Runner: los errores de script fallan el test
- [x] Repartir lo que destapó

**Prueba:** A mano: un test con una lectura sobre null después de un assert da FALLA y muestra 'error de script (1): archivo:línea mensaje'.

**Notas:** Sesión de bugs (-fd), pedido de Daniel vía -43. run_tests.gd registra un Logger (OS.add_logger) que junta los errores de tipo SCRIPT; cada error mientras corre un test (en el test o en el código del juego) lo marca FALLA con el primero y la cantidad. push_error y los errores del motor no cuentan. La suite completa destapó: dodge_ghosts.gd:53 (11.112, -eb: bake_mesh_from_current_skeleton_pose da null en headless) en 7 tests de player, lift, bombs, input e interaction; test_cave:46 y test_breakables:102 (overworld, -eb en 7.10); test_save_manager:23 (desde 14.9 cargar vuelve a entrar a la escena y el test leía el player viejo: arreglado acá). Aparte, sin error de script: templo.tscn sin uid (11.113, -43 [a7e236]) rompe test_portals. Después: arreglados acá dodge_ghosts.gd (salta la malla si el bake da null), bt_keep_away/bt_shoot_arrow (un player liberado deja de ser objetivo) y menu_stack.gd:74 (foco recordado ya liberado). test_boss › marks y test_audio › doom fallan a veces (pasan 3/3 solos).

### 11.117 Huecos a otro piso se ven distintos de los fosos · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `diseno`, `arte`, `nivel`

Daniel (2026-10-13): la mayoría no va a entender a la primera que hay que tirarse para bajar de piso, y no todos los huecos llevan a otro piso. Los que llevan a otro piso tienen que verse distintos: se ve la sala de abajo con blur y un poco oscurecida, con un haz de luz y polvo; los fosos quedan negros con niebla en el borde. Regla: un hueco sin Pit debajo cae al piso de abajo. Hoy los huecos a otro piso son: Chullpa, Sala de los saltos (al Osario) y Sala del cofre (a la Cripta); Queñoa, Nido (a la Rama) y Cámara del arco (al Tronco).

- [x] Regla y test: cada hueco cae a un piso o tiene Pit (diseño)
  Hecho el 2026-10-13 (cb8f4b78): DropHoles (src/world/drop_holes.gd, sin autoloads) lista los huecos sin Pit debajo. test_drop_holes: cada uno cae sobre el piso de abajo (piso firme o un foso, como el Mirador sobre el Abismo) y las salas son las del diseño: Chullpa Saltos, Sala del cofre, Mirador y Agrietada (bajo el piso agrietado); Queñoa Nido y Arco; el templo no tiene.
- [x] Aspecto: ventana con blur a la sala de abajo y fosos negros con niebla (arte)
  Hecho el 2026-10-13 (ff55af4a), por arte (-5d): la_walls crea una pieza gemela 'Hueco caída' por cada hueco, con el fondo cambiado por una ventana (ventana_caida.gdshader: la sala de abajo con blur y más oscura) y la pone en las celdas que da DropHoles.of_floor (vuelve a la de foso si un hueco deja de caer). CaidaLA (haz de luz cálido y polvo que cae) cada 6 m de hueco. Los fosos: fondo negro puro y niebla que se mueve en el borde (niebla_foso.gdshader). La piedrita que cae no está. Daniel ajusta a ojo.
- [x] Enseñarlo en la Chullpa: la primera caída (diseño)
  Hecho el 2026-10-13: en la Sala del cofre, al borde de los huecos, un esqueleto (SalaCofreEnemy1) que de un espadazo cae y aterriza vivo en la Cripta, y dos vasijas para tirar por el hueco. Se enseña sin texto; se ve del todo cuando arte abra la ventana del paso 2. test_chullpa lo cubre. GDD §8b.
- [x] Plano de las mazmorras: marcar los huecos a otro piso (diseño)
  Hecho el 2026-10-13: el plano (https://claude.ai/artifact/5KN21oAgw5LVR4oN1urFRp) marca con borde azul los huecos a otro piso, sobre la captura y en el esquema, con DropHoles.
- [x] Recorrido de Daniel

**Notas:** Sesión: diseño (-43 [a7e236]) con arte (-11 / -5d) para el aspecto.

### 11.118 Sandalias: correr manteniendo y salto largo con la pluma · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `diseno`, `items`

Daniel (2026-10-13): con la pluma de D1, los islotes llevaban a D3 sin el arco y la angostura abría el este sin el puente. Ítem nuevo, las sandalias (como las botas de Pegaso): se mantiene el botón, el player toma impulso medio segundo y corre recto hasta soltar o chocar; chocar sacude árboles y muros agrietados. Saltar con la pluma en plena carrera da el salto largo (Daniel: 3 celdas, 6 m, contra 1 celda, 2 m, de la pluma sola; nunca 4 celdas, el abismo del Risco). Se ganan en una mini quest de la Necrópolis que pide el arco (7.11). [[gdd#progresion-gating]]

- [x] Ítem sandalias (data/items, ícono, item get)
  Hecho el 2026-10-13 (b5c13e2b): data/items/sandals.tres (USABLE, DashBehavior), en item_database y con textos ITEM_SANDALS_*. Usa el ícono de la pluma hasta que arte haga el suyo y el modelo para el cofre (pedido a -5d).
- [x] Estado de carrera: mantener, impulso, correr recto, chocar
  Hecho el 2026-10-13 (b5c13e2b): estado Dashing. Mantener toma impulso 0,5 s en el lugar (el stick apunta), después corre recto a 9,5 m/s hasta soltar o chocar. El choque rebota, sacude el encuadre y manda a la Hurtbox de adelante un DamageInfo con elemento dash; árboles y muros agrietados se sacuden (ramas de -eb en Breakable y CrackedWall).
- [x] Salto largo: la pluma en plena carrera cruza 3 baldosas
  Hecho el 2026-10-13 (b5c13e2b). Daniel: la pluma cruza 1 baldosa y sandalias + pluma 3. Jumping sigue la dirección de la carrera a long_jump_speed 8, sin control en el aire: cruza 6 m y no 8.
- [x] Tests (carrera, choque, salto largo: 3 baldosas sí, 4 no)
  Hecho el 2026-10-13: test_sandals (8): carrera, cancelar, choque con dash, 3 baldosas sí y 4 no en cajas planas (b5c13e2b); y en el overworld (09271dbb) cruza la angostura y los dos huecos de la Laguna hasta la isla de D3, y cae en el abismo del Risco. long_jump_speed 8,6.
- [x] Recorrido de Daniel (velocidades: corrida 9,5 m/s, salto largo 8,6 m/s)

**Capturas:** `compass/images/m7-11-mapa.jpg`, `compass/images/m7-11-1.jpg`, `compass/images/m7-11-2.jpg`, `compass/images/m7-11-3.jpg`, `compass/images/m7-11-4.jpg`, `compass/images/m7-11-5.jpg`

### 11.119 Cargar partida: la escena vieja sigue corriendo mientras carga · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `guardado`

SceneFlow.enter_saved_scene no pausaba como travel_to: mientras el nivel nuevo carga en un hilo, la escena vieja sigue y un enemigo puede matar al player; el game over queda abierto en la partida recién cargada. Pasaba en los tests (test_save_manager dejaba el árbol pausado con GameOver y tiraba test_player y test_quenoa en el mismo proceso desde que el overworld tarda más en cargar).

**Prueba:** test_save_manager › test_missing_scene_loads_at_the_start_instead_of_hanging: en pausa mientras carga, sin game over al llegar.

**Notas:** Además: GameState.read_from ya no pide player/position con default null (Godot lo toma como sin default y tira ERROR).

### 11.120 Cofre con munición sin su contenedor: no la pierde · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `items`

Abrir un cofre con bombas sin la bolsa (o flechas sin el arco) gastaba el cofre y la munición quedaba sin uso. Ahora el cofre avisa qué falta ("No tenés una bolsa para llevar bombas") y queda cerrado con el contenido: GameState.missing_holder(item) busca el ítem cuyo behavior usa esa munición.

**Prueba:** test_chest › test_ammo_without_its_holder_stays_in_the_chest: sin bolsa no da bombas, abre el aviso y el cofre queda cerrado; con la bolsa, las da.

### 11.121 Secretos de flechas antes del arco · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `diseño`

SecretRockChest (Cerros, solo empujar), SecretRavineChest (Quebrada, bombas) y SecretLedgeChest (Quebrada, pluma) dan 10 flechas y se alcanzan antes del arco (D2). Con 11.120 el cofre no las pierde, pero el premio del secreto es 'no tenés arco'. Propuesta: roca y muro dan bombas o poción; la repisa queda en flechas o también cambia.

**Notas:** Daniel (2026-10-13): queda así. Desde 11.120 el cofre sigue cerrado y avisa que falta el arco; al volver con el arco da las flechas. Pociones y bombas descartadas (botellas máximo 4; hay cofres de bombas antes de la bolsa).

### 11.122 Cofre de bombas de la cueva de la mata en el inicio · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `bug`, `diseño`

BushCaveBush se corta con la espada desde el arranque y el cofre de bush_cave da 10 bombas: se llega antes de la Cueva de las bombas y aparece 'no tenés bolsa'. Cambiar el contenido o tapar el hoyo con algo que pida bombas.

**Notas:** Daniel (2026-10-13): queda así. La bolsa está en la cueva de las bombas (oeste de la Pradera, sin requisitos); si se llega antes a la cueva de la mata, el cofre queda cerrado (11.120) hasta volver con la bolsa.

### 11.123 Tablilla del Risco desactualizada · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`, `texto`

cliff_heart (overworld.dialogue) dice que el corazón se partió en cuatro: una pieza en el pasto alto, dos tras la piedra herida y una junto al carcaj. Ahora hay 6 piezas en el overworld (escalón de la Pradera, Cerros, Islote, queñoa, Risco, Cumbre); solo una tras muro agrietado y ninguna en el pasto. Reescribir la pista (y en.po).

**Notas:** Daniel (2026-10-13): muy temprano para fijar cuántas piezas hay; la tablilla se ajusta cuando el total esté cerrado.

Text approved with 11.124 (2026-10-20): "El corazón se partió en dieciséis. Tres duermen tras la piedra herida, cinco esperan en las salas de los antiguos, y el resto donde solo llega quien ya tiene cada herramienta." Apply it once the 16 pieces are placed.

Done (cacad828): cliff_heart in overworld.dialogue and en.po with the approved text.

### 11.124 Piezas de corazón: 13, no múltiplo de 4 · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `bug`, `diseño`

Overworld 8 + Gruta, Santuario, Chullpa, Queñoa y templo = 13 piezas con PIECES_PER_HEART = 4: tres contenedores y una pieza que nunca completa uno. Quitar una o agregar tres (o cambiar la regla).

**Notas:** Daniel (2026-10-13): de momento no importa; se revisa cuando se cierre el total de piezas.
2026-10-15 (-43, 11.190): con la pieza del templo el total es 13 (8 overworld + 5 mazmorras): una de más sobre 12. Quitar una o agregar tres.

Opciones de -72 (2026-10-19) con 11.27 y 11.26: hoy 13 piezas, 4 por contenedor. 1) Ir a 16: el santuario de reflejos y la prueba de combate dan una pieza cada uno (15) y falta una más (recomendada). 2) Ir a 12: ninguna da pieza (bolsa grande y botella) y se saca una de las que hay. 3) Mezcla: una da pieza (14) y faltan dos para 16, o se sacan dos.

Decisión de Daniel (2026-10-19): 16 piezas. El santuario de reflejos (11.27) y la prueba de combate (11.26) dan una pieza cada uno y falta una más en otro lado del overworld.

Daniel (2026-10-20): piece 16 at the Mirador with the hammer (STRIKE plate on the ledge lowers a niche's gate; HeartPieceMirador, ow_heart_piece_mirador). Total 16: 11 overworld (meadow, tree, hills, grotto, shrine, islet, cliff, mirador, summit, reflejos 11.27, huaca 11.26) + 5 dungeons (ch, qv, tt, cu, te).

### 11.125 Puzzle de bloques de la cota: probar empujando y ubicar región · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `test`, `diseño`

test_grove_puzzle teletransporta los bloques a las placas; no prueba que se llegue empujando (B: este y sur desde (-33,2); A: 4 m al sur). Además el puzzle (x -41..-31, z -5..4) está en la zona Pradera/Claro, no en la Arboleda que pide la pluma: confirmar que es donde se quería.

**Notas:** Hecho: test_grove_puzzle empuja los bloques caminando contra ellos (A dos celdas al sur; B una al este y una al sur) y verifica que cada uno llega a su placa. Ubicación: el puzzle no pide ningún ítem y da la cota, así que queda en la Pradera; 'Grove' es el nombre del mapa viejo. Playtest 15/10 (11.125): la placa de la piedra del Claro ahora se traba con solo pisarla (ONCE); la tablilla sigue enseñando a levantar y arrojar. En la Pradera el bloque B pasó a vasija grande (GroveBigPot) sobre una placa de peso con el ícono de la vasija; la otra placa ya tenía el ícono de bloque. La cota ya está en el santuario. test_tutorial, test_grove_puzzle, test_secrets.

**Capturas:** `compass/images/m11-125-mapa.jpg`, `compass/images/m11-125-1.jpg`

### 11.126 Push bloqueado: terreno del overworld pasa 100 MB · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Tamaño:** L · **Etiquetas:** `bug`, `arte`, `repo`

GitHub rechaza el push: assets/epiphany/terreno_organico.glb (hasta 334 MB) y assets/epiphany/meshes/terreno_organico/riscos.res (170 MB) pasan el límite de 100 MB por archivo. Hay 24 versiones en los ~360 commits sin pushear (desde 985d9e56, origin/main del 2026-10-11). Los dos salen de tools/blender/build_terreno_organico.py. Plan probable (Daniel): partir el terreno en chunks de menos de 100 MB y después limpiar las versiones grandes del historial sin pushear (git filter-repo; cambia los hashes, con las otras sesiones quietas).

- [x] Partir los archivos grandes en partes de menos de 100 MB
  Hecho (b658b129): terreno_organico.0..11.glb (15-72 MB) juntados en terreno_organico.tscn, paredes_la.<estilo>.glb (18-40 MB); epi.publish(part=...).
- [x] Limpiar del historial sin pushear las versiones de más de 100 MB
  Hecho el 2026-10-13: git filter-repo --refs main wt/* ^985d9e56 --invert-paths con terreno_organico.glb, paredes_la.glb y meshes/terreno_organico/riscos.res. Mismos commits (429) y mismos árboles en las puntas, nuevos hashes; ningún blob de más de 100 MB entre origin/main y main. Respaldo previo: /home/ssd_disk/epiphany-backup-pre-filter.git.
- [x] Pushear (Daniel)
  Hecho el 2026-10-13 por -5d a pedido de Daniel: en tandas de 40 commits de first-parent (git push origin <sha>:refs/heads/main), porque el push entero pasaba el límite de 2 GB por pack de GitHub. origin/main = 7cc1240d.

**Relacionadas:** 15.5 Comprimir mallas al importar

### 11.127 Etiqueta del piso tapa el minimapa · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `ui`

La etiqueta del piso (FloorTag, en mazmorras de varios pisos) tenía lugar para 34 px, pero con los márgenes de HudPill y el texto mide 49, y crecía hacia abajo sobre el minimapa. Ahora crece hacia arriba (grow_vertical = begin): el borde de abajo queda 6 px sobre el minimapa.

**Prueba:** test_minimap › test_the_floor_tag_sits_above_the_minimap: en la Chullpa la etiqueta se ve y termina arriba del minimapa.

### 11.128 Por atrás del santuario se salteaba el muro agrietado y el atajo · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `bug`, `overworld`

Daniel: entrando al santuario por la puerta de atrás se salía por la de abajo atravesando el muro agrietado de la Explanada sin romperlo. Además Spawn_atajo (x 11) quedaba del lado de adentro de la reja del atajo, así que el atajo no hacía falta abrirlo. Ahora shrine_cave tiene su propio muro agrietado en la boca de la salida (EntranceCrackedWall, mismo flag ow_shrine_cracked_wall: romper uno rompe el otro), y Spawn_atajo pasa a x 13,4, afuera de la reja. Todos los muros agrietados del juego (14) tienen flag y quedan rotos.

**Prueba:** test_shrine › test_the_back_door_skips_neither_the_shortcut_nor_the_cracked_wall: por atrás arranca afuera de la reja cerrada y no pasa; la salida está tapada por el muro de adentro; con el flag del muro de afuera, el de adentro está roto. test_overworld_run sigue pasando.

### 11.129 D4, Intihuatana de la Cumbre · Revisión

**Prioridad:** media · **Tamaño:** L · **Etiquetas:** `mazmorra`, `puzzles`

Mazmorra 4 (GDD §8e): el escudo espejo parte la Cumbre; el piso bajo sin él, el alto con él. Sub-jefe Kuntur joven, jefe Apu Kuntur. Plano aprobado por Daniel el 2026-10-13 (si, me gusta).

- [x] Plano
  Aprobado el 2026-10-13 (Daniel: si, me gusta). Doc de diseño actualizado (sección D4 y mapa).
- [x] Blockout
  Hecho el 2026-10-13: levels/cumbre.tscn (debug/tmp/design/build_cumbre.gd), 12 salas de 14 × 12 m en dos pisos y la Cima. Espejo que gira (src/world/light/rotating_mirror.tscn, gira 90° de un espadazo). Grafo data/dungeons/cumbre_graph.tres, flags cu_, nombres en es/en, escenario cumbre, test_cumbre (4). GDD §8e.
- [x] Sub-jefe Kuntur joven
  Hecho el 2026-10-15 (Daniel: los jefes me parecen bien): Kuntur (src/entities/kuntur/kuntur.tscn, 10 de vida). Picada que marca su sombra y lo deja clavado en la nieve (le pega todo); cada tercer ataque se posa y bate las alas, el viento empuja y una flecha lo voltea. Modelo provisorio de primitivas.
- [x] Jefe Apu Kuntur
  Hecho el 2026-10-15: apu_kuntur.tscn (hereda, apu, 20 de vida). Plumas reflejables (una devuelta lo voltea, las flechas rebotan) y picada; con media vida enciende SunWest y SunEast y se posa a cargar una ráfaga: un rayo devuelto con el escudo lo voltea (LightCatch). También en la revancha del templo (MirrorFight, con MirrorSunWest/East). test_kuntur (5), test_templo.
- [x] Entrada en el overworld (sesión del overworld)
  Hecho por el overworld: CumbreDoor en el risco norte de la Cumbre (39, 6.4, -45.2) y Spawn_cumbre (39, 5.2, -42.4); ExitPortal y BossExitPortal de cumbre.tscn van a target_spawn cumbre.
- [x] Horneado LA (arte)
  Hecho por arte (b07155ba, en main 69115da1): cumbre en LEVELS de la_walls con spread false, las salas quedan donde estaban (espejos, haces, postes y el hueco del Hueco sin mover). Si se edita el grid: la_walls.gd -- refresh cumbre, sin rehornear.
- [ ] Recorrerla (Daniel)
- [x] Modelo de arte de los cóndores (arte)
  Hecho (sesión de arte): 5520a17d modelos con build_kuntur.py (kuntur_cuerpo, ala_izq, ala_der y apu_kuntur_*), 5121afdc alas con plumas. kuntur.tscn: Body/Model, Muzzle, Roar, WingLeft/Wing, WingRight/Wing.

**Prueba:** test_cumbre, test_kuntur, test_dungeon_reach (cumbre_graph), test_walk_doors, test_drop_holes

**Capturas:** `compass/images/m11-129-mapa.jpg`, `compass/images/m11-129-1.jpg`

### 11.130 Bocas de cueva talladas en el risco · Hecho

**Terminada:** 2026-10-14 · **Responsable:** sesión del overworld

Daniel: las bocas de cueva del overworld (la entrada trasera de la ermita, la cueva de las bombas, el manantial) eran una caja marrón con una puerta negra pegada al risco. Pidió darles detalle como a las puertas, pero hecho con el terreno.

- [x] Bocas detrás de los muros agrietados: Gruta y Santuario
  Daniel 2026-10-14: rompió el muro agrietado y detrás quedó la muesca lisa del risco, sin boca de cueva. GrottoCrackedWall (-84,0,14 → GrottoDoor) y ShrineCrackedWall (-88,2.6,-22 → ShrineDoor) no tenían nodo *Mouth, así que cave_mouths() no las tallaba. Hecho (-eb): GrottoMouth (-83.97, 0, 14) y ShrineMouth (-88, 2.6, -23.55) en overworld.tscn, con Jambs como las demás; se tallan detrás del tapón de la pared y se ven al romperla. Probar: romper las paredes de la Gruta y del Santuario con una bomba.

**Prueba:** En el overworld, las tres bocas (y la de la Cumbre) son un vano trapezoidal en el risco con jambas y dintel del mismo risco y un túnel oscuro; se entra caminando y el portal lleva a la cueva. test_portals, test_cave, test_shrine, test_spring, test_overworld

**Notas:** build_terreno_organico.py › cave_mouths(): cada nodo *Mouth del overworld (exportado a terreno_overworld.json › mouths) se talla en riscos: se busca la cara del risco delante, se corta el vano (como paso_puerta del templo: 1.5 abajo, 1.2 arriba, 1.95 de alto), las aristas del borde se extruyen 1.6 m hacia adentro como túnel (noche) con fondo y piso oscuros, y el risco alrededor sale 0.18 m como jambas y dintel. Sin lomas delante ni dentro. Se quitó cueva_boca de las tres; SpringCaveMouth estaba girada hacia la montaña. De paso: el risco ya no pone baranda a 1.2 m de un poste del gancho (POSTS en el json), porque tapaba la vista desde abajo (fallaban los dos tests de test_overworld_hook).

**Capturas:** `compass/images/m11-130-mapa.jpg`, `compass/images/m11-130-1.jpg`, `compass/images/m11-130-2.jpg`, `compass/images/m11-130-3.jpg`, `compass/images/m11-130-4.jpg`, `compass/images/m11-130-20261013-221755.png`, `compass/images/m11-130-20261013-221902.png`, `compass/images/m11-130-20261014-034842.png`

**Relacionadas:** 11.166 Santuario con una sola entrada: su muro agrietado; 11.168 D4 (Cumbre): entrada exagerada como las otras mazmorras

### 11.131 Pozo junto a la Chullpa: caer sin bombas deja softlock · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-eb · **Etiquetas:** `bug`

Playtest 2026-10-13: en el overworld, al lado del primer nivel cerca de la cueva de las bombas, hay un pozo/foso con pared agrietada. Si el player cae ahí sin bombas no puede salir (softlock). Necesita una salida que no dependa de bombas (escalón, rampa, o que el pozo no sea accesible antes de tenerlas).

**Prueba:** Caminar sobre el nivel 1 hacia el sur, desde (-74, -8) hacia el nicho del corazón de los Cerros (al lado de la Cueva de las bombas): la baranda frena y no se cae. Tests: test_the_hills_niche_is_fenced_from_above, test_every_rail_faces_its_terrace.

**Notas:** Causa (compartida con 11.147): Piece.build recalcula las normales de las caras que no están en fixed, así que cada cuadrado suelto de la baranda quedaba mirando para cualquier lado. El colisionador importado choca solo de frente (backface_collision apagado), y por eso casi toda la baranda dejaba pasar desde la terraza. Se caía al nicho de HeartPieceHills, detrás de SecretHillsWall, en (-74, -4). railing() ahora arma cada cara mirando a su terraza y la marca fixed. Terreno, muros, decoración y navmesh regenerados.

**Capturas:** `compass/images/m11-131-20261013-223001.png`

**Relacionadas:** 11.147 Overworld: caer al sector de arriba (entre riscos, junto a la meseta clara) deja softlock

### 11.132 Cuevas: los enemigos se quedan quietos · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-fd · **Etiquetas:** `bug`

Playtest 2026-10-13: dentro de las cuevas del overworld los enemigos no se mueven ni atacan, quedan quietos en su lugar. Revisar si la IA (LimboAI) arranca en esas escenas (navmesh, activación por sala, process_mode).

**Prueba:** Entrar a la cueva de las bombas y a la gruta y acercarse a un enemigo: viene hacia el player. test_cave › test_cave_enemies_chase_the_player

**Notas:** Causa: las cinco cuevas del overworld no tenían NavigationRegion3D, así que el NavigationAgent3D de los enemigos nunca tenía camino. Cada cueva tiene ahora su navmesh (levels/nav/<cueva>_navmesh.tres, horneada con tools/bake_overworld_nav.gd -- <cueva>). El esqueleto de la cueva de las bombas arranca pegado a un pilar: desde la entrada no ve al player hasta que se le acerca (normal).

### 11.133 Vasija chica cargada no se ve con el x-ray · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

Playtest 2026-10-13: al levantar una vasija chica, cuando el player queda tapado y se ve con el x-ray (silueta), la vasija que lleva encima no aparece. El objeto cargado debería verse también con el x-ray.

**Prueba:** Levantar una vasija con el player detrás: no aparece la silueta; detrás de una pared sí. test_lift › test_in_reach_it_gets_an_outline, test_player › test_what_the_player_carries_has_the_silhouette

**Notas:** Playtest 2026-10-14: cargada ya se ve; faltaba que una vasija en el piso delante del player no lo pase a silueta. Hecho: los Liftable marcan el stencil como el cuerpo del player (src/feel/stencil_mark.tres, también debajo del contorno de alcance); en las manos el contorno ya no pisa el destello y la silueta del Carrier.

**Capturas:** `compass/images/m11-133-20261013-223150.png`, `compass/images/m11-133-20261014-143518.png`

### 11.134 Oclusión: reemplazar el agujero por cámara cenital sobre el player · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-eb · **Etiquetas:** `camara`, `mejora`

Playtest 2026-10-13 (mejora, no bug): cuando el player queda detrás de un acantilado/pared y hoy se aplica el agujero (dither alrededor del player), en vez de eso rotar la cámara hasta quedar encima del player (cenital) mientras dure la oclusión, y volver al ángulo normal al salir. No cambia la cámara del resto del juego: solo en los casos donde hoy se usa el agujero.

**Prueba:** tests/test_player_hole.gd

**Notas:** Si una pared tapa a un jugador, la cámara gira hasta quedar cenital sobre el foco y vuelve cuando deja de taparlo; ya no se abre el agujero. Después del playtest del 2026-10-14: solo las paredes la hacen subir (la roca del terreno y las paredes del kit, lo que antes se recortaba); detrás de árboles, cardones y objetos queda la silueta x-ray. El giro ahora es un resorte amortiguado de 1 s (overhead_time) y se queda arriba 0,6 s más (overhead_hold) después de que la pared deja de taparlo, así no sube y baja a cada paso. Las dos cosas se ajustan en el grupo Oclusión de TopDownCamera. Probar: caminar detrás de un acantilado alto y bordearlo; después, detrás de un árbol (no tiene que subir).

**Capturas:** `compass/images/m11-134-20261013-224604.png`, `compass/images/m11-134-20261014-021123.png`

**Relacionadas:** 11.165 La cámara cenital se activa en bordes y muros bajos de una sala

### 11.135 Al caer, el player se inclina hacia el piso · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-fd · **Etiquetas:** `bug`, `player`

Playtest 2026-10-13: cada vez que el player cae (por un borde), el modelo se inclina hacia adelante/abajo durante la caída. Debería caer parado (sin inclinar el cuerpo; revisar la animación/pose de caída o la rotación que se aplica en el aire).

**Capturas:** `compass/images/m11-135-20261013-224716.png`

### 11.136 Chullpa: la reja de la entrada queda fuera de la pared · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-43 · **Etiquetas:** `bug`, `chullpa`

Playtest 2026-10-13: en la sala de entrada de la primera mazmorra (Chullpa), la reja/puerta de barrotes aparece desplazada hacia afuera del hueco de la pared (flota junto a la abertura, en vez de estar dentro del marco). Revisar la posición de la puerta respecto a las paredes LA horneadas.

**Prueba:** tests/test_walk_doors.gd

**Notas:** Hecho: EntradaGate había quedado en la celda de piso delante del corte de la escalera (el horneado LA corre las paredes y no las rejas). Va en la boca del corte (x 2.9), dentro del marco; test_walk_doors y test_chullpa pasan.

**Capturas:** `compass/images/m11-136-20261013-224757.png`

**Relacionadas:** 11.144 Queñoa S1 (Raíces): reja fuera de la pared y puerta con llave detrás de una reja de puzzle

### 11.137 Chullpa: techos visibles, pared agrietada que no encaja y sala secreta a la vista · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-43 · **Etiquetas:** `bug`, `chullpa`

Playtest 2026-10-13, en la Chullpa (las tres cosas salen en la misma captura):
1) Se ven los "techos" (las tapas superiores de las paredes LA horneadas). No deberían verse.
2) La pared agrietada no encaja en el hueco de la pared: es un bloque que sobresale, con la cara de arriba negra.
3) Lo que esconde la pared agrietada (el nicho con el cofre/barril) se ve antes de romperla. Debería estar oculto y descubrirse al romper la pared.

**Notas:** 2) y 3) hechos (provisorio hasta 12.24): RellanoCrackedWall queda al ras de la pared LA y de su altura; una tapa del color de las crestas (NicheCap, hija de Wall) cubre el nicho y desaparece al romper el muro. 1) pasó a 11.156 (arte).
Daniel (2026-10-14): la parte de la pared agrietada se descarta: la D1 queda sin paredes agrietadas (11.177). Los techos visibles pasan a 12.32 (topes del color del muro).
Cerrada: reemplazada por 11.156, 11.177 y 12.32 (NicheCap y RellanoCrackedWall ya no están).
Sale de la sesión de playtest del 14 de octubre sin 'Anda': la reemplazan 11.177 y 12.32, que están en la del 15.

**Capturas:** `compass/images/m11-137-20261013-224905.png`, `compass/images/m11-137-20261014-143652.png`, `compass/images/m11-137-20261014-143745.png`

**Relacionadas:** 11.151 Totora 2P: se ve la sala del piso de abajo; 11.164 Lo que esconde una pared agrietada no se ve desde arriba; 11.175 Cámara de sala: centrar en lo que se ve de la sala, no en su rectángulo; 11.177 Chullpa sin pared agrietada (fuera el nicho del Rellano); 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la)

### 11.138 Chullpa sub-boss: asset para el cuadrado donde después se salta · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `chullpa`

Playtest 2026-10-13: en la sala del sub-boss (Guardian) de la primera mazmorra, el cuadrado del piso (el lugar por donde uno se tira después) es un placeholder: un cuadrado liso con una línea, sin sentido visual. Falta un asset que se lea como lo que es (losa/trampilla/hueco que se abre al vencer al guardián).

**Capturas:** `compass/images/m11-138-20261013-225004.png`

### 11.139 Chullpa: el cofre sobre la plataforma no se alcanza saltando · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `bug`, `chullpa`

Playtest 2026-10-13: en la Chullpa hay un cofre sobre una plataforma/pilar en un pozo, al lado de una sala con borde. No hay forma de llegar saltando (con la pluma) desde el borde: la distancia o la altura no da. Ajustar la plataforma o el borde para que el salto alcance.

**Prueba:** tests/test_chullpa.gd

**Notas:** Hecho: era la isla del cofre de la pluma (1SE), pensada para salir solo cayendo (huecos de 2 baldosas). La isla se ensancha una baldosa al este: de ese lado queda un hueco de 1 baldosa, que la pluma cruza en los dos sentidos. Sin pluma se sigue llegando solo cayendo desde 2SE. GDD §8b; test_chullpa test_the_feather_island_is_one_tile_from_the_east_floor. Playtest 15/10: la nota del playtest es anterior al arreglo de Daniel en el editor (4b3b4724, borde del techo y huecos de la isla): ahora la isla de 3x3 tiene huecos de 1 baldosa al oeste y al este, así que el lado izquierdo también se cruza con la pluma. Vuelve a revisión para probarla de nuevo.

**Capturas:** `compass/images/m11-139-20261013-225053.png`, `compass/images/m11-139-20261014-144014.png`

### 11.140 Overworld (Lagoon): z-fighting entre el pasto y el camino de tierra · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-eb · **Etiquetas:** `bug`, `overworld`

Playtest 2026-10-13: en la zona Lagoon, arriba de la escalera de piedra, el camino de tierra y el pasto se pisan (z-fighting): franjas de tierra que parpadean sobre el pasto. Separar las capas (offset/decal/render priority) o unificar el terreno.

**Prueba:** tests/test_overworld.gd

**Notas:** Los caminos de las terrazas altas quedan 2 cm sobre la tapa (PATH_LIFT en build_terreno_organico.py). Cuando el contorno del camino tocaba el borde, la tapa no le abría el agujero y las dos superficies quedaban en el mismo plano. Probar: Laguna, arriba de la escalera de piedra (-47, 23); la tierra no debe parpadear sobre el pasto.

**Capturas:** `compass/images/m11-140-20261013-225351.png`

### 11.141 Queñoa 2P (Canopy): símbolo azul sin sentido y puerta bloqueada invisible · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `bug`, `quenoa`

Playtest 2026-10-13: en la D2 (Queñoa), piso 2P "Canopy", hay en una pared un marco de bloques con un símbolo azul (parece un candado/asa) que no se entiende qué es. Identificar qué elemento es (¿puerta con llave, puerta de jefe, interruptor?) y darle un asset/lectura clara; si es un placeholder o algo sobrante, sacarlo.

- [x] Misma sala: hay una puerta bloqueada que no se ve (el player choca contra algo invisible en el hueco de la pared). La puerta tiene que verse.
- [x] Causa probable: la "puerta bloqueada" del oeste de la Copa es NidoCrackedWall (muro agrietado → Nido, se abre con bomba), instancia de cracked_wall_templo.tscn, y no se ve. Sin verla, la Queñoa parece imposible sin arco (playtest: 'todos los caminos bloqueados'). Hacerla visible con el estilo de la Queñoa.

**Prueba:** tests/test_quenoa.gd

**Notas:** Hecho. 1) El símbolo azul era el candado (SouthMark) que door.gd dibuja en el piso cuando la cámara recorta la pared sur; con las paredes LA el recorte (3.6) pasa la hoja (3 m) y además la estiraba x1.5. door.gd usa ahora el alto real de la hoja: si el recorte no la corta, ni la estira ni muestra el candado (test_doors). 2) NidoCrackedWall estaba en el medio del paso LA, tapado por el velo negro del grosor de pared: ahora tiene una cara en cada lado del paso (como las hojas de las puertas), con la malla clara de muro agrietado, y colisión/hurtbox que llenan el paso (test_quenoa). Después ese muro de dos caras se reemplazó por el muro agrietado LA de 12.24 (f269322c, 091f56e5).

**Capturas:** `compass/images/m11-141-20261013-225533.png`, `compass/images/m11-141-20261013-225603.png`, `compass/images/m11-141-20261013-225858.png`

**Relacionadas:** 11.145 Queñoa S1 (Sala de los ojos): placa que no hace nada, z-fighting en el cofre y símbolo raro en la puerta; 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la)

### 11.142 Mapa de pausa: LT/RT van rapidísimo; mover con las flechitas · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `ui`

Playtest 2026-10-13: en la pestaña Mapa del menú de pausa, LT y RT mueven el mapa rapidísimo y la velocidad depende del tipo de gatillo del gamepad (analógico/digital). Debería moverse con las flechitas (d-pad) en lugar de los gatillos, a una velocidad fija.

**Prueba:** Mapa de la Chullpa en pausa: LT, la cruceta o el stick izquierdo cambian un solo piso por apretón; izquierda/derecha pasan por todas las salas del piso. test_map › test_floor_selector_in_a_dungeon_with_floors

**Notas:** LT/RT son ejes del joystick ligados a map_floor_up/down (cambiar de piso en el mapa de una mazmorra); cada movimiento del gatillo pasado el umbral llegaba como apretado, así que un gatillo analógico saltaba varios pisos según el control. Ahora cuenta una vez por apretón hasta soltarlo. Pendiente con Daniel: si además quiere cambiar de piso con la cruceta.
Daniel (2026-10-14): la cruceta y el stick izquierdo arriba/abajo cambian de piso. Hecho (ff2a5f17): en mazmorras con pisos arriba/abajo (cruceta, stick, flechas) cambian de piso una vez por apretón, igual que LT/RT; izquierda/derecha recorren todas las salas del piso en orden de lectura; la ayuda y la columna de pisos muestran arriba/abajo. Con un solo piso el cursor sigue moviéndose en las cuatro direcciones.

### 11.143 Overworld: delineado/halo oscuro raro alrededor de árboles, cardones y bordes · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-eb · **Etiquetas:** `bug`, `overworld`, `render`

Playtest 2026-10-13: en el overworld (meseta con cardones y árboles, sobre un risco) aparece un delineado raro: un halo oscuro difuso alrededor de los árboles, cardones y el borde del risco, que no corresponde a una sombra. Revisar SSAO/SSIL, el outline o la niebla/tinte de profundidad (puede venir del cambio de altura entre terrazas).

**Prueba:** tests/test_overworld.gd

**Notas:** El halo era el AO de pantalla (sombra_la), que oscurecía hasta 5 m alrededor de árboles, cardones y bordes. sombra_la ahora exporta reach y max_radius; en el overworld reach = 1.5. El look de los demás niveles no cambia. Probar: meseta de cardones sobre el risco; queda la sombra de contacto, sin el halo difuso.

**Capturas:** `compass/images/m11-143-20261013-230021.png`

### 11.144 Queñoa S1 (Raíces): reja fuera de la pared y puerta con llave detrás de una reja de puzzle · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `bug`, `quenoa`, `diseño`

Playtest 2026-10-13, Queñoa piso S1 Roots, salida este de las Raíces a la Sala de los ojos:
1) La reja (RaicesGate, la que abre el ojo con tiempo) queda afuera del hueco de la pared, igual que la de la Chullpa (11.136).
2) Diseño: no tiene sentido que una puerta bloqueada por un puzzle (reja del ojo con tiempo + saltos con pluma) además pida llave. Elegir una sola cerradura: o la reja del puzzle o la puerta con llave, y mover la otra (actualizar quenoa_graph.tres y el GDD §8c; test_dungeon_reach).

**Prueba:** tests/test_quenoa.gd

**Notas:** Hecho (Daniel eligió quedarse con la reja del puzzle): RaicesLocked no está; RaicesGate pasa a la cara de las Raíces del paso LA (x 25.4), donde se ve y no queda afuera. La llave chica del nicho del primer ojo sobraba: ahora es un cofre con 10 flechas (RootArrowChest, flag qv_root_arrow_chest). Dos llaves para dos puertas. quenoa_graph, flag_registry, GDD §8c; test_dungeon_reach, test_walk_doors, test_quenoa.

**Capturas:** `compass/images/m11-144-20261013-230258.png`

**Relacionadas:** 11.136 Chullpa: la reja de la entrada queda fuera de la pared

### 11.145 Queñoa S1 (Sala de los ojos): placa que no hace nada, z-fighting en el cofre y símbolo raro en la puerta · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `bug`, `quenoa`

Playtest 2026-10-13, Queñoa piso S1, sala con los arbustos y el pozo (probablemente la Sala de los ojos):
1) La placa junto a la puerta oeste no hace nada visible. Si es OjosStep (deja abierta la reja de las Raíces para volver), el efecto pasa fuera de cámara: falta respuesta (sonido, cámara a la reja o que se vea), o no funciona.
2) z-fighting en el cofre de la esquina noreste.
3) Otra vez el símbolo raro (asa/candado) en el piso de la puerta sur, como en 11.141.

**Prueba:** tests/test_quenoa.gd

**Notas:** Hecho. 1) OjosStep sí abría la reja de las Raíces, pero fuera de cámara (la reja no se muestra porque también la abre el ojo con tiempo de su sala). Gate tiene reveal_from: la primera vez que se pisa la placa, la cámara muestra la reja abriéndose (test_quenoa). 2) El z-fighting era la tapa abierta del cofre de la llave del jefe contra la pared norte del nicho: el cofre va 0.15 m más al sur (sin tapar el paso de la reja, test_walk_doors). 3) El símbolo de la puerta sur es el mismo candado de 11.141, ya arreglado en door.gd.

**Capturas:** `compass/images/m11-145-20261013-230436.png`

**Relacionadas:** 11.141 Queñoa 2P (Canopy): símbolo azul sin sentido y puerta bloqueada invisible

### 11.146 Overworld: el ojo del puente a la Necrópolis no se ve ni se puede flechar · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-fd · **Etiquetas:** `bug`, `overworld`

Playtest 2026-10-13: con arco y pluma, junto al río no hay forma visible de llegar al otro lado para buscar las sandalias. Por diseño (GDD, cadena del overworld) se cruza con una flecha al ojo del puente de la quebrada, que baja/abre el puente a la Necrópolis. Revisar: que el ojo del puente exista y funcione, y que se vea/entienda desde donde llega el player (señalizarlo; quizá el player busca en otro tramo del río).

- [x] Confirmado: el ojo está en la terraza alta del otro lado del río, fuera de cuadro (hay que mover el stick derecho para verlo).
- [x] Está en altura y la flecha no le llega desde la orilla (la flecha viaja plana o no apunta hacia arriba). Bajar el ojo a la altura del player, ponerlo en la cara del risco, o que la flecha apunte a ojos en altura.
- [x] Que se vea desde la orilla sin mover la cámara (acercarlo al río o encuadrarlo).

**Prueba:** Desde la orilla oeste, tensar el arco mirando al este: el ojo al pie del risco entra en cuadro; una flecha lo prende y sube el puente. test_overworld (test_an_arrow_at_the_eye_raises_the_bridge_to_the_necropolis tira plano a 1 m)

**Notas:** Causa: el arco siempre tira plano a la altura del player (aim.get_direction aplana) y el ojo estaba en la terraza a 2.6 m; el test pasaba porque apuntaba la flecha directo al ojo. Además una mata de ichu (hurtbox de 1.2 m) en la llegada del puente frenaba la flecha. Ojo bajado al pie del risco (6, 0, -6), mata quitada de overworld_decor.tscn y plantas_overworld.json. Visibilidad: con el arco tensado la cámara se adelanta 3 m y el ojo entra en cuadro, al borde; parado sin apuntar todavía no se ve.

**Capturas:** `compass/images/m11-146-20261013-230751.png`, `compass/images/m11-146-20261013-231129.png`

### 11.147 Overworld: caer al sector de arriba (entre riscos, junto a la meseta clara) deja softlock · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-eb · **Etiquetas:** `bug`, `overworld`

Playtest 2026-10-13 (con sandalias y pluma): en la zona de la captura (tierra con cardones, al pie de los riscos escalonados y la terraza clara), si el player se cae al sector de arriba de la captura (el claro de tierra entre los riscos, arriba a la izquierda del enemigo) no puede salir: softlock. Igual que 11.131: todo pozo/terraza al que se pueda caer necesita salida sin ítems que el player pueda no tener.

**Prueba:** Bajar por la escalinata nueva desde la Necrópolis (x 63, z -14) a la zanja y volver a subir. Caminar por los bordes de la zanja desde arriba: la baranda frena. Tests: test_the_risco_low_corridor_has_stairs_up, test_every_rail_faces_its_terrace.

**Notas:** Misma causa que 11.131 (baranda al revés; arreglada en el builder). Además, la zanja de nivel 0 al pie de la terraza clara de la Necrópolis es el pasillo bajo del Risco, desde donde se engancha RiscoPost (HeartPieceCliff), y no tenía entrada ni salida. Le agregué una escalinata al sur hacia la Necrópolis en x 62-64, z -18 (celdas Escalón en el GridMap y dos piezas de Terrazas giradas 180°). GDD 7.1, Risco.

**Capturas:** `compass/images/m11-147-20261013-232715.png`

**Relacionadas:** 11.131 Pozo junto a la Chullpa: caer sin bombas deja softlock

### 11.148 Minimapa del overworld desactualizado (la quebrada sale como abismo negro) · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-eb · **Etiquetas:** `bug`, `overworld`, `ui`

Playtest 2026-10-13: en Ravine el minimapa (foto cenital del overworld) muestra la quebrada como un abismo negro, pero en el juego ahora es un río. La foto no se regeneró después de los últimos cambios de terreno. Regenerarla y, si se puede, que un test compare su fecha/huella con la del terreno para que no vuelva a quedar vieja.

- [x] Regenerar la foto cenital del overworld con el terreno actual (la quebrada como río).
- [x] Lo que se activa tiene que aparecer en el minimapa: el puente de la quebrada una vez subido (la foto es estática y se saca con el puente abajo). Dibujarlo encima como marca/overlay según su estado, igual con otros cambios persistentes (paredes rotas, etc.).

**Prueba:** tests/test_minimap.gd

**Notas:** La foto del minimapa es en vivo (OverworldMap fotografía el escenario en la capa 20). Faltaban el agua de la quebrada, las escalinatas, el puente, las rejas, la torre y las paredes rotas, y ahora están. Cuando cambia un flag persistente, la foto se vuelve a sacar a los 2 s, así que el puente subido o una pared rota aparecen solos. Probar: ver la quebrada en el minimapa, subir el puente y volver a mirarlo.

**Capturas:** `compass/images/m11-148-20261013-232758.png`, `compass/images/m11-148-20261013-232828.png`

### 11.149 Al entrar a una sala se puede caer al agua y reaparecer sobre el agua (softlock) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `totora`, `player`

Playtest 2026-10-13: en la Totora (D3), piso 1P Ground Floor, apenas se entra a la sala del este (la del estanque central con la isla, la reja con ojo y llave al norte y las matas de totora) por la puerta oeste, el player cae al agua y vuelve a caer infinitamente: softlock. Probable: el punto de reaparición de la caída al agua (la entrada de la sala) queda sobre el agua o la transición de sala empuja al player hacia el estanque, que empieza a ~1 celda de la puerta. Revisar el Pit/respawn de la sala y que la entrada tenga piso firme; agregar un test que entre por cada puerta de la Totora y no caiga.

- [x] Segundo caso: Totora 2P Upper Floor, sala oeste (pasarela angosta junto al estanque, entrando por la puerta este): apenas se entra uno se puede caer y reaparece arriba del agua, cae en bucle hasta perder.
- [x] Arreglo general: el punto de reaparición tras caer al agua/pozo tiene que estar sobre piso firme (validarlo al guardarlo, no la posición cruda al entrar a la sala).
- [x] Idea de Daniel: un cooldown al cruzar de sala, para el input del player y para los enemigos, así no se cae ni lo golpean apenas entra.
- [x] Test: entrar por cada puerta de cada mazmorra con agua/pozos, caer y comprobar que reaparece sobre piso.

**Prueba:** Totora 1P sala este y 2P sala oeste: entrar manteniendo el stick y caer al agua: vuelve a la puerta sobre piso, quieto medio segundo, y no vuelve a caer solo. test_room_entry (todas las puertas de las 5 mazmorras)

**Notas:** Causa general (no solo la Totora): GameState.room_entry se tomaba donde quedaba el player al terminar la transición de sala; si caía durante la caminata automática o la pasarela estaba a un paso del agua, la vuelta quedaba sobre el agua o bajo el piso y caía en bucle. Ahora: al cruzar se anota el umbral (last_ground) y al final solo se reemplaza pisando el piso de la sala; la caminata automática se frena en un borde; tras caer, 0.5 s sin caminar (cooldown de Daniel, en cuadros de física). test_room_entry encontró además casos en Queñoa (RaicesLocked), templo (CombinedDoor) y Cumbre.

### 11.150 Gancho: el targeting marca un poste de otra sala/piso · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `totora`, `items`

Playtest 2026-10-13, Totora: con el gancho, el targeting marca (rombo amarillo) algo que está arriba, en otra sala o piso, a través de la pared/techo. El targeting del gancho debería considerar solo objetivos de la sala actual (y del mismo piso), con línea de vista.

**Prueba:** Totora PisoBajo debajo de un poste de PisoAlto, con el gancho: no aparece el rombo. test_hookshot › test_posts_on_another_floor_cannot_be_targeted

**Notas:** Los postes se fijaban a cualquier altura dentro del alcance (10 m): desde un piso de la Totora se marcaban los del piso de arriba (8 m) a través del techo. Ahora un poste cuya sala está en otro piso que el del player no cuenta. Los cruces por una puerta del mismo piso siguen andando.

**Relacionadas:** 11.153 Totora: cruce con gancho a través de la puerta no se entiende; poner plataforma/poste en la propia sala

### 11.151 Totora 2P: se ve la sala del piso de abajo · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `bug`, `totora`, `render`

Playtest 2026-10-13, Totora (D3) 2P Upper Floor, sala sureste: debajo del borde sur de la sala se ve la sala del piso de abajo (su piso y paredes). Los otros pisos no deberían verse (ocultar/fundir los pisos que no son el actual, como en las otras mazmorras LA). En la misma captura: la pared agrietada del oeste sobresale como bloque verde (como 11.137).

**Notas:** Hecha la primera mitad, la máscara de cámara que oculta el piso de abajo (d5e0d9a5, 2751c841). Después 12.32 cambió cómo se ven los pisos de abajo: por los huecos se ve la sala de abajo más oscura (86d81aef). El bloque verde de la pared agrietada lo cubre el muro agrietado LA de 12.24 (f269322c, 091f56e5).

**Relacionadas:** 11.137 Chullpa: techos visibles, pared agrietada que no encaja y sala secreta a la vista; 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la)

### 11.152 Z-target: al activarlo, priorizar el enemigo más cercano · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `mejora`, `player`, `camara`

Playtest 2026-10-13: al apretar el z-target, el primer objetivo debería ser el enemigo más cercano al player (hoy elige por cercanía al centro de pantalla, targeting.gd › distancia proyectada al centro). Los enemigos tienen prioridad sobre postes/ojos.

**Prueba:** Con dos enemigos, uno pegado y otro lejos pero más al centro de la pantalla: el z-target fija al pegado. test_targeting › test_locking_picks_the_nearest_enemy

**Notas:** lock_best_target tomaba el más cercano al centro de pantalla; con la cámara de sala fija no suele ser el que está al lado. Ahora el enemigo más cercano al player; el más centrado solo si todos los candidatos son postes del gancho.

### 11.153 Totora: cruce con gancho a través de la puerta no se entiende; poner plataforma/poste en la propia sala · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseño`, `totora`

Playtest 2026-10-13, Totora (D3): en la sala del estanque grande con la puerta al norte sobre el agua, hay que usar el gancho hacia algo que está del otro lado de la puerta (en la otra sala), y no se entiende. Debería haber una plataforma (o poste visible) dentro de la propia sala, frente a la puerta, para que el cruce se lea. Relacionado con 11.150 (el targeting marca cosas de otras salas).

**Prueba:** tests/test_totora.gd

**Notas:** Hecho (Daniel eligió 'muelle seco'): el agua del Telar la cruza un muelle de totora hasta la puerta norte, y al Estanque se llega caminando; los postes que cruzaban la puerta (TelarPost, EstanquePost) no están. El gancho se estrena en el propio Estanque (franja oeste ↔ islote, 4 celdas, poste a la vista). Para que no haya softlock de llaves (la puerta de los Tejedores ahora se alcanza sin gancho), la llave chica del islote pasa a la esquina NO de la franja oeste: dos llaves y dos puertas antes del gancho. Grafo, GDD §8d y test_totora (test_the_telar_pier_walks_through_the_north_door_to_the_pond). Aparte: el cruce Gancho↔Balsas de PisoBajo también pasa por una puerta.

**Relacionadas:** 11.150 Gancho: el targeting marca un poste de otra sala/piso

### 11.154 Totora: no hay dónde reponer flechas cerca · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseño`, `totora`

Playtest 2026-10-13, Totora (D3): en la sala del estanque con ojos (interruptores de flecha), si el player se queda sin flechas no tiene un lugar cercano para reabastecerse. Poner vasijas/pasto que suelten flechas en o cerca de las salas que piden arco (y que el drop de flechas sea más probable cuando quedan pocas).

**Prueba:** tests/test_totora.gd

**Notas:** Hecho: dos vasijas de flechas (data/drops/pot_arrows.tres, 5 flechas si tiene el arco) en cada sala de Totora con un ojo: Juncal (esquina SO, cerca de donde se le tira al ojo) y Tejedores (franja este, de donde se tira por encima del agua). Y en cualquier DropTable las filas de munición (flechas, bombas) pesan 4 veces más con un cuarto o menos de lo que entra (drop_table.gd). Tests: test_totora test_every_eye_room_has_an_arrow_pot, test_drops test_arrows_drop_more_often_when_the_quiver_runs_low.

### 11.155 Chullpa: la momia aparece en vez de saltar hacia el player; onda expansiva con shader vistoso · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-43 · **Etiquetas:** `bug`, `chullpa`, `jefe`

Playtest 2026-10-13: en la pelea de la momia (MummyGuard), cuando 'salta' no se ve que siga al player: simplemente aparece en el punto de caída. Debería verse el salto (arco hacia la marca) siguiendo al player mientras apunta. Además, Daniel quiere que la onda expansiva del aterrizaje sea un shader vistoso (anillo con distorsión/brillo) en lugar del efecto actual.

- [x] El salto se ve: la momia viaja en arco hasta la marca (que sigue al player hasta fijarse).
- [x] Onda expansiva del aterrizaje con un shader vistoso (anillo que se expande, distorsión/brillo).

### 11.156 Chullpa: se ven los techos (crestas) de las paredes LA horneadas · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-5d · **Etiquetas:** `bug`, `chullpa`, `arte`

Separada de 11.137 (punto 1). Playtest 2026-10-13: en la Chullpa se ven las tapas superiores de las paredes LA horneadas (la_walls) y no deberían verse. Es del look de la_walls, va con 11.151 (Totora 2P: se ve la sala de abajo).

**Notas:** Hecho (-5d, 4aa49f97): borde_oscuro pinta de negro toda superficie a altura de cresta fuera del interior de la sala y los topes planos dentro; la_walls pasa un uniform interior (piso de la sala sin las filas que son casi todo pared). Chullpa refrescada.
Cerrada: la reemplaza 12.32 (los velos BordeOscuro y su shader se fueron, 86d81aef; los topes van del color del muro).
Sale de la sesión de playtest del 14 de octubre sin 'Anda': la reemplazan 11.177 y 12.32, que están en la del 15.

**Relacionadas:** 12.32 Look LA: topes de pared del color del muro y viñeta borrosa en vez del velo negro; desenfoque solo cerca de la cámara

### 11.157 Mazmorras: los tiles del GridMap no se alinean con la grilla del editor · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `herramientas`

Daniel 2026-10-14: las piezas de los kits LA quedan corridas media celda de la grilla del editor. Causa: los GridMap de las mazmorras tienen cell_center_x/z = false y las mallas de los kits están centradas en su origen (−1..1), así la grilla pasa por el medio de los tiles. En el juego anda porque el código usa la misma convención. Arreglo: cell_center = true y correr cada GridMap −1 m en x y z (nada se mueve en el mundo), o mover el origen de las mallas; revisar la_walls, decorate_levels y los generadores que usan map_to_local. Las cinco mazmorras de una vez.

**Notas:** Hecho: los GridMap de mazmorras, cuevas y niveles de prueba centran la celda (cell_center x/z) y quedan 1 m atrás en x y z; nada se mueve en el mundo. El overworld queda como estaba (otro generador, lo lleva -eb). Ojo: con esto la_walls refresh mide bien la puerta (antes el punto de adelante caía en la propia celda Puerta y siempre daba 4 m); en la Totora TejedoresLocked y AmaruLocked pasarían a 2 m al volver a correr refresh; el refresh ya se aplicó en 761d59a4 (AmaruLocked, TejedoresLocked, GanchoDoor y BossDoor pasan a 2 m).

### 11.158 Piso LA: patrón de tablones raro · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `render`

Daniel 2026-10-14 (captura del piso de tablones, Queñoa/Totora): el patrón del piso se ve raro. piso_la.gdshader dibuja los tablones en espacio de mundo: cada fila arranca en un desfase al azar (las juntas no alternan), plank_length 1.7 no divide la celda de 2 m (el patrón no calza con los tiles) y crack_amount dibuja arcos oscuros sueltos sobre algunos tablones. Propuesta: filas alternadas a medio tablón, largos que dividan 2 m (1 o 2 m) y sacar o rehacer los arcos.

### 11.159 Overworld con el arte de las mazmorras: brillo LA y más detalle en el piso · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-5d · **Etiquetas:** `arte`, `overworld`, `render`

Daniel 2026-10-14 (por -5d): el overworld tiene que compartir el arte de las mazmorras. Brillo: el look BrilloLA (lo eligió tras comparar overworld base vs brillo vs Chullpa). Piso: más detalle, hoy se ve plano. Plan: epiphany_outdoor.gdshader con palette_surface brillo y patrón de piso por swatch (losas, textura de tierra, variación de tono del pasto), más BrilloLA y glow en overworld.tscn. Coordinar con -eb antes de tocar overworld.tscn; prototipo en debug/tmp.

### 11.160 Ojos de la Queñoa: los párpados siempre se abren y cierran animados · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `combate`, `jefe`

Daniel 2026-10-14: ayuda visual en el combate. Al clavarse tras el salto, al ser derribado y al levantarse los párpados del WatcherEye saltaban de golpe; ahora todo cambio de párpados es una animación desde donde están (LID_SNAP 0,15 s para los rápidos, 0,3 s al cerrar). Test: test_the_warden_gets_stuck_in_the_roots_and_falls_to_the_sword.

### 11.161 Jefe final: la puerta norte de la sala queda escondida · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `bug`, `templo`, `diseño`

Playtest 2026-10-14 (probando la pelea del jefe final, 12.26): en la sala de ladrillos rojos con antorchas, la puerta del centro de la pared norte (hueco oscuro con el emblema del ojo) queda hundida en la pared y casi no se ve; Daniel: 'la puerta está escondida'. Revisar si es la salida del jefe, el portal o la puerta de entrada, y que se lea a simple vista.

**Prueba:** Cargar el escenario pre_boss: arranca en la Antesala del templo nuevo, la puerta del jefe al norte se ve y se abre con la llave del jefe.

**Notas:** La sala de la captura es la Antesala del templo viejo (levels/temple.tscn, flags d1_): el escenario pre_boss todavía cargaba ese nivel, que ya no está en el juego (el overworld lleva a levels/templo.tscn). En el templo actual la puerta del jefe (BossDoor, Antesala → Jefe) se ve bien: marco dorado, ojo y candado. Arreglo: pre_boss ahora carga templo.tscn en la Antesala con todos los ítems, la llave del jefe y las flags te_ de todo lo anterior al jefe (puerta del jefe cerrada). boss_key_door_locked pasó a templo.tscn y dungeon_no_bow se borró en 11.162, con el templo viejo.

**Capturas:** `compass/images/m11-161-20261014-023958.png`

### 11.162 Retirar el templo viejo (levels/temple.tscn) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `limpieza`, `templo`

Daniel 2026-10-14: lo obsoleto se borra. El juego usa templo.tscn; temple.tscn (flags d1_) solo confunde (11.161: un escenario de debug lo cargaba y Daniel vio su antesala). Pasar al templo actual o a otro nivel lo que todavía lo usa y borrarlo, con lo que solo sirve a él.

- [x] Escenarios de debug: boss_key_door_locked y dungeon_no_bow al templo actual
- [x] Tests que lo cargan: boss, coop_hud, doom, enemy_ai, jump, minimap, overworld, player_hole, players, portal, render_budget, spike_trap, tablet (al templo actual o a otro nivel)
- [x] test_temple.gd: pasar lo que siga valiendo a test_templo y borrar el resto
- [x] Borrar levels/temple.tscn, data/dungeons/temple_graph.tres y lo que solo lo usa (revisar tools/build_temple_kit.gd, vary_temple.gd, toon_preview.gd y decorate_levels.gd); actualizar gdd.md
- [x] Suite completa en verde

**Prueba:** tests/test_templo.gd, test_boss.gd, test_doom.gd, test_portal.gd, test_slots.gd, test_map.gd, test_audio.gd (suite completa: 506 tests)

**Notas:** Hecho (2026-10-14). Borrados: levels/temple.tscn, data/dungeons/temple_graph.tres, data/kits/temple_kit.tres, levels/decor/temple_decor.tscn, levels/nav/temple_navmesh.tres, tests/test_temple.gd y 23 flags d1_ del registro.
Pasado al templo: la sala del Jefe crece a 22 x 14 m (la pelea de 12.26 no entraba en 22 x 10), doom por sala (0.1 en Pluma a 0.9 en la Antesala), autoguardado al entrar a la Antesala, las cuatro tablillas del doom (flags te_tablet_*), y de test_temple la puerta del jefe con su llave y morir ante el jefe (vuelve a la antesala con la puerta abierta).
Escenarios: nuevo templo.cfg (vestíbulo); boss_key_door_locked al templo; dungeon_no_bow borrado.
Arregla lo que rompió 11.161 (boss, temple, slots, map, audio). El cartel de piso del minimapa solo sale en mazmorras de más de un piso.
El test de paredes de hueco pasa a la chullpa y mira las piezas orientadas: el Hueco suelto del kit LA tiene las paredes hundidas en los cuatro lados.
Quedan sin uso (no borro arte): las mallas de la decoración vieja (escombros, estandarte, venas_doom, vasija_pedazos). La tablilla bow_hint queda para la Queñoa.

### 11.163 Borrar las mallas de la decoración del templo viejo · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `limpieza`, `arte`

Tras 11.162 (templo viejo borrado) quedaron sin uso las mallas de su decoración: escombros, estandarte, venas_doom, vasija_pedazos. Confirmar que nada las usa (ni builders de Blender) y borrarlas con su pieza en el build. La tablilla bow_hint queda (la usa la Queñoa).

### 11.164 Lo que esconde una pared agrietada no se ve desde arriba · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-43 · **Etiquetas:** `bug`, `chullpa`

Daniel 2026-10-14 (playtest, Chullpa, Rellano): la pared agrietada ya llena el hueco (12.24), pero el nicho de atrás no tiene techo y la cámara cenital ve el cofre por encima del muro. Era el punto 3 de 11.137, resuelto con una tapa provisoria (NicheCap) que se sacó en 5eee5740 al llegar los tapones de 12.24. Regla para mazmorras y overworld: lo que esconde una pared agrietada lleva techo (del color de las crestas o del terreno) y el techo desaparece al romperse la pared.

- [x] Chullpa: techo sobre el nicho del Rellano en covers de su pared
- [x] Revisar las demás paredes agrietadas (Queñoa, Totora, Cumbre, templo) con el mismo criterio
- [x] Test: el nicho está tapado antes y destapado después de romper la pared
- [x] Overworld: techos sobre las muescas de risco y nichos detrás de paredes agrietadas (-eb)
- [x] CrackedWall.covers: oculta los techos al romperse
- [x] Overworld: arriba de la tapa no hay pared invisible (-eb)
  Hecho (-eb): build_terreno_organico.py › _unfence_niches() saca la baranda alrededor de los nichos encerrados, y cada tapa lleva un piso (Lid/Floor, una caja a la altura de la terraza). CrackedWall ahora también apaga sus covers al romperse (process_mode DISABLED), así que el piso se va con la tapa: rota la pared, se puede caer al nicho y se sale por la pared rota (no queda un piso invisible sobre un hueco visible). Test: test_overworld › test_the_hills_niche_is_walked_over_until_the_wall_breaks.

**Prueba:** tests/test_cracked_wall.gd (test_dungeon_niches_are_roofed, test_the_landing_niche_roof_goes_when_the_wall_breaks)

**Notas:** CrackedWall.covers (fd): lista de nodos que se ven mientras la pared está entera y se ocultan al romperse (también al cargar rota). Cada nivel pone su techo y lo agrega a covers. Mazmorras: -43; overworld: -eb. Overworld (-eb): build_terreno_organico.py › niche_lids() genera una tapa (tapa_<pared>.res, del color de la tapa de la terraza y 2 cm sobre ella) sobre las celdas bajas encerradas detrás de cada pared agrietada: Cerros, Cardonal, Mirador, Quebrada y Cumbre. Gruta y Santuario dan a una boca de cueva, no a un nicho, y no llevan tapa. Cada tapa es el nodo Lid de su pared y está en sus covers. Test: test_overworld › test_cracked_wall_niches_are_roofed_until_the_wall_breaks.
Mazmorras (-43): la_walls refresh arma el techo (<Pared>NicheRoof, hermano de la pared, en sus covers). Cubre el piso encerrado detrás de la pared cuando está en la misma sala que el frente; si atrás hay un paso u otra sala, no lleva (la máscara de sala ya lo tapa). El techo llega hasta donde empiezan las crestas de las paredes que lo rodean y pasa por encima del paso de la propia pared: con la cámara en perspectiva, sin eso se veía el piso del nicho por el borde (el cofre del Rellano, el ojo de Combined). Usa el material de las paredes con la UV de la cresta, así que el velo de 11.156 lo oscurece igual que a las crestas. Con techo: Chullpa Rellano, Queñoa Ojos y templo Combined. Sin techo: Queñoa Nido y templo Arco (dan a un paso), Totora Garita y Cumbre Grieta (dan a otra sala). Al hacerse en el refresh, ya no se pierde cuando se vuelve a correr (lo que pasó con NicheCap en 5eee5740).

**Capturas:** `compass/images/m11-164-20261014-033804.png`, `compass/images/m11-164-20261014-034700.png`, `compass/images/m11-164-20261014-041025.png`

**Relacionadas:** 11.137 Chullpa: techos visibles, pared agrietada que no encaja y sala secreta a la vista; 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la); 12.29 Muro agrietado LA de cueva (muro_agrietado_cueva_la)

### 11.165 La cámara cenital se activa en bordes y muros bajos de una sala · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-fd · **Etiquetas:** `bug`, `camara`

Daniel 2026-10-14 (cueva de las bombas): acercándose a la pared de la sala o parándose delante de un muro bajo, la cámara sube a cenital (11.134). En una sala no tiene que pasar: está hecha para verse entera desde su cámara fija. Hecho: TopDownCamera solo busca oclusión cuando no hay sala (overworld); test_player_hole › test_rooms_never_turn_the_camera_overhead (busca en la cueva un lugar donde una pared lo taparía y comprueba que no sube).

**Prueba:** tests/test_player_hole.gd

**Relacionadas:** 11.134 Oclusión: reemplazar el agujero por cámara cenital sobre el player

### 11.166 Santuario con una sola entrada: su muro agrietado · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-5d · **Etiquetas:** `overworld`, `diseno`

Daniel 2026-10-14 (playtest de 11.130: no tiene sentido entrar a la ermita y que esté bloqueada solo por dentro): la cueva del santuario tiene una sola entrada, el muro agrietado del overworld. Se van la salida trasera y el atajo.

- [x] shrine_cave: sin ShortcutGate, ShrineSwitch, ShrineBlock, BackPortal, Spawn_atajo ni EntranceCrackedWall; pasillo este tapiado; sin ow_shrine_switch; GDD (-5d, wt/art cebb8223)
- [x] Overworld: sin ShrineBackMouth, ShrineBackDoor ni Spawn_atajo; terreno, decor y navmesh (-eb)

**Relacionadas:** 11.130 Bocas de cueva talladas en el risco; 12.29 Muro agrietado LA de cueva (muro_agrietado_cueva_la)

### 11.167 Totora: caer al agua y perder deja al player cayendo al vacío antes de "You Fell" · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `totora`, `player`

Daniel (playtest de 12.19): en la Totora, si el player cae al agua y pierde, se lo ve caer al vacío y recién después aparece la pantalla de 'You Fell'. Al caer al agua tendría que hundirse/salpicar y reaparecer (o la pantalla al instante), sin ver la caída por debajo del nivel.

**Prueba:** tests/test_totora.gd

**Notas:** Pit._fall devolvía antes de llevarlo a la orilla si el daño lo mataba, y el estado Dead seguía aplicando gravedad 1,8 s (bajaba a y −119). Ahora lo lleva a la orilla igual: muere parado ahí y en co-op el espíritu arranca en piso. Vale para todos los pozos y aguas.

**Relacionadas:** 12.41 Totora (D3) en estilo Link's Awakening y su entrada

### 11.168 D4 (Cumbre): entrada exagerada como las otras mazmorras · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-eb · **Etiquetas:** `overworld`, `arte`

Daniel (playtest de 11.130 y 7.9): la entrada de la D4 en el overworld parece una cueva normal. Tiene que tener una entrada exagerada que se lea como mazmorra, como la Chullpa, la Queñoa y la Totora (torre, árbol, choza).

**Prueba:** test_overworld › test_the_condor_frames_the_cumbre_door_and_lets_the_player_in: del Spawn_cumbre se entra a la Cumbre por la portada.

**Notas:** Modelo (-5d, 26e73e96): un cóndor de piedra gigante tallado en el risco (como el Templo del Cóndor de Machu Picchu) sobre una portada inca de doble jamba; src/world/cumbre_entrada.tscn, colisión en jambas, cuerpo y alas, nada sobre la puerta. Colocado (-eb, 53593416): CumbreCondor en (39, 5.2, -44.8), 1,2 m delante de la boca para que la portada salga de la roca. Falta: que Daniel lo vea en juego.

**Relacionadas:** 11.130 Bocas de cueva talladas en el risco

### 11.169 Galería de trampas: la pluma no salta por encima de los pinchos · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-43 · **Etiquetas:** `diseno`, `player`, `mazmorra`

Daniel (playtest de 11.5): saltando con la pluma los pinchos igual llegan al player. O la pluma salta más alto o los pinchos son más bajos / el hurtbox no alcanza en el aire. Cuidado: el alto del salto (player/states/jumping.gd) lo usan todos los huecos y tests de salto.

**Prueba:** tests/test_jump.gd › test_jumping_over_raised_spikes_is_safe_but_landing_on_them_hurts

**Notas:** Hecho (2026-10-14): no toqué el alto del salto ni los pinchos. Los pinchos ahora son ground_only, como la onda del golpe del jefe: en el aire no lastiman (como en LA). Nuevo hits_on_landing en Hitbox: si el player cae encima de pinchos levantados, lastiman al tocar el piso. ground_only solo perdona a players en el aire; los enemigos se pinchan igual que antes. Por qué no las otras opciones: la caja de los pinchos llega a 0.8 m y el salto sube 0.68, y achicarlos no alcanzaba, porque el salto no dura lo suficiente para cruzar la caja más el radio de la cápsula del player.

**Relacionadas:** 11.5 Galería de trampas: pinchos

### 11.170 Atajos: animación del player subiendo y bajando en vez del fundido · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `overworld`, `animacion`

Daniel (playtest de 11.28): los atajos andan, pero al usarlos hay un fundido. Debería verse al player subiendo y bajando (escalera de soga, rope_ladder).

**Prueba:** test_secrets: la escalera de soga se sube y se baja con la animación, sin fundido

**Notas:** Hecho (-5d, ecb1de13): estado Climbing que sigue los marcadores Lip/RungTop/RungBottom de la escalera de soga con la animación Carry/Climb; Top y Bottom solo arrancan cerca de su punta (antes al desenrollar arriba disparaba Bottom). test_secrets sube y baja.

**Relacionadas:** 11.28 Atajos que se abren al volver

### 11.171 Mapa del overworld: el cursor vuelve al player al moverlo hacia un lado · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `ui`

Playtest 2026-10-14: en la pestaña Mapa del overworld el cursor se queda pegado: hacia algún lado siempre vuelve sobre el ícono del player.

**Prueba:** test_map › test_the_overworld_cursor_stays_put_when_the_map_resizes

**Notas:** Causa: el mapa y el panel de al lado comparten fila; un nombre largo agranda el panel, la foto se achica y al rehacerse (resized) ponía el cursor sobre el player. Ahora conserva su punto del mundo (aabc388a).

### 11.172 Viaje rápido: el foco no va al botón y A abre la pregunta una y otra vez · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `ui`

Playtest 2026-10-14: al elegir un portal en el mapa, el foco no pasa al botón de confirmar y cada A abre otra confirmación de viaje.

**Prueba:** test_map › test_travel_portals_light_up_and_the_map_travels: A con el control confirma y no abre otra pregunta

**Notas:** Causa: las páginas Mapa, Ítems y Equipo tenían process_mode ALWAYS (resto de antes de MenuStack), así que tapadas por la pregunta seguían leyendo A. Sacado de las tres (aabc388a).

### 11.173 Esqueleto invisible en una mazmorra · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `enemigos`

Playtest 2026-10-14: en la planta baja (1P) de una mazmorra hay un esqueleto que no se ve.

**Prueba:** test_chullpa › test_an_enemy_that_falls_to_the_floor_below_stays_visible

**Notas:** Causa probable: un enemigo que cae por un hueco al piso de abajo seguía siendo hijo de su piso, y los pisos de arriba del player se ocultan. Ahora al aterrizar pasa al piso de su altura (02ccb681). Si vuelve a pasar: anotar mazmorra y sala.

### 11.174 Overworld (Cumbre): el gancho choca contra una pared invisible · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-eb · **Etiquetas:** `bug`, `overworld`, `items`

Playtest 2026-10-14: en la zona nevada, junto a la cornisa con el poste del gancho (franja verde entre riscos), el gancho choca contra una pared invisible antes de llegar al poste.

**Prueba:** test_overworld_hook › test_the_hookshot_crosses_the_invisible_rail_from_the_far_edge

**Notas:** Causa (-eb, a2924bd2): la baranda invisible del terreno (1,6 m en cada borde caminable, sin malla) frenaba el gancho tirado desde la nieve de la Cumbre al RiscoPost por encima del pasillo bajo. Ahora la baranda está en el grupo walk_guard: el gancho y las flechas la atraviesan, a los que caminan los sigue frenando.

### 11.175 Cámara de sala: centrar en lo que se ve de la sala, no en su rectángulo · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-fd · **Etiquetas:** `camara`, `bug`

Playtest 2026-10-14 (11.137, Chullpa): en salas que no llenan su rectángulo (pasillos, salas en L) la cámara se centra en la caja entera de la sala y deja mucho negro. Debería encuadrar la parte de la sala que tiene piso (las celdas usadas del GridMap dentro de la sala).

**Notas:** 2026-10-15 (-fd): measured every room in chullpa, quenoa, totora, cumbre and templo against the GridMap cells of its floor. Since 11.178/11.179 (rooms centered and sized to the camera) every room fills its box; the original problem (Chullpa corridors and L rooms) no longer exists. Only two rooms have a box larger than their cells, Totora's Gancho (south 4 m) and Balsas (between the rafts), and that empty part is water (the Agua mesh, not GridMap): the hookshot crossing and the rafts. Framing by cells would cut it out, so it was not changed. Proposal: close the card.

**Relacionadas:** 11.137 Chullpa: techos visibles, pared agrietada que no encaja y sala secreta a la vista

### 11.176 Chullpa: llave chica y sótano obligatorios, llave del jefe con vuelta atrás · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `mazmorra`, `chullpa`

Daniel 2026-10-14: en la Chullpa se salteaba el 90% (la vasija de la placa está en el Rellano, así que la puerta con llave, la llave chica y todo el sótano eran opcionales, y la llave del jefe estaba al lado del jefe). Regla: la llave del jefe pide vuelta atrás. Aprobado: la puerta a la Momia pasa a ser la de la llave chica (sótano obligatorio); la vasija en la placa abre 2NO; brújula de este lado de los huecos de 2NO y llave del jefe del otro (con la pluma); el Mausoleo queda sin huecos (Daniel: sala sin huecos).

- [x] Puerta a la Momia con llave; la placa de la vasija abre 2NO
- [x] 2NO: brújula de este lado, llave del jefe del otro lado de los huecos
- [x] Mausoleo sin huecos (sin cofre)
- [x] Grafo, test_dungeon_reach avisa salas con llave/acertijo que no hacen falta
- [x] Tests (chullpa, drop_holes, walk_doors, map) y GDD §8b

**Prueba:** tests/test_chullpa.gd (test_the_mummy_door_takes_the_crypt_key, test_the_boss_key_waits_across_the_leaps_holes, test_pushing_the_pot_onto_the_plate_opens_the_leaps_room), tests/test_dungeon_reach.gd (test_optional_keys_and_a_boss_key_before_the_item_break_the_mold)

**Notas:** Hecho (2026-10-14). Camino nuevo: Entrada → caer por 1SE → Cripta (oleadas, mapa) → Cripta oscura (pinchos, llave chica) → escalera de mano → bloques → Rellano → puerta con llave → Momia → pluma → volver al Rellano → vasija en la placa → 2NO, huecos con la pluma → llave del jefe → 1NE → Mausoleo → jefe. AgrietadaDoor pasa a puerta con llave (ch_mummy_locked_door, ex ch_leaps_locked_door) y SaltosLocked pasa a SaltosDoor, de interruptor (RellanoWeight). La brújula está de este lado de los huecos de 2NO y la llave del jefe del otro. El Mausoleo queda sin huecos, sin MausoleoPit y sin cofre. El molde de test_dungeon_reach suma dos reglas, que hoy cumplen las cinco mazmorras: cada llave chica hace falta para llegar al jefe, y la llave del jefe pide el ítem. Escena armada con un script (debug/tmp/design/chullpa_1176.gd) y la_walls refresh sobre main con 11.156.

### 11.177 Chullpa sin pared agrietada (fuera el nicho del Rellano) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `chullpa`, `diseno`

Daniel (2026-10-14): en la D1 no hay paredes agrietadas. Sacar RellanoCrackedWall, su nicho y el cofre de 5 bombas (flag ch_landing_niche_chest). Reemplaza la parte de la pared agrietada de 11.137.

**Prueba:** tests/test_chullpa.gd, tests/test_cracked_wall.gd, tests/test_dungeon_reach.gd

**Notas:** Sin RellanoCrackedWall, nicho, cofre de 5 bombas (ch_landing_niche_chest) ni RellanoBombPot; la pared oeste del Rellano sigue recta. Spot del grafo y flag quitados, GDD 8b. Regla: en mazmorras un muro agrietado abre una sala entera, nunca un nicho.
2026-10-14 (-43, 4b3b4724): cambios de Daniel en el editor (borde de una celda de pared alrededor de cada piso, huecos de pasillo a los lados de la isla) pasados al grid sin el ruido del guardado; la escalera de la cripta sale en la mitad oeste del Salón del Cofre (32, 22), que llega a la entrada: antes salía en la mitad este y sin pluma quedabas trabado. la_walls solo poda paredes a más de 2 celdas de un piso.
Daniel: ¿por qué hay escalera abajo y nada arriba? (-43, 5a85d8f4): la escalera de la cripta es de ida y vuelta; el Salón del Cofre tiene una bajada en su pared norte (SalaCofreStairs) a FromChestHall en la cripta.

**Relacionadas:** 11.137 Chullpa: techos visibles, pared agrietada que no encaja y sala secreta a la vista

### 11.178 Totora: cada sala centrada en cámara y tapando las otras · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `mazmorra`

Daniel (2026-10-14, ajustado el 2026-10-15): cada sala de la Totora se centra en cámara y tapa las otras. Los tamaños son libres (viñeta y cámara configurables); ya no hace falta 14 × ≥22.

- [x] Captura de cada sala con la cámara del nivel
- [x] Ajustar camera_offset/fov o AmbienteSala (viñeta) donde se ve otra sala o queda descentrada
  Revisadas todas: cada sala queda centrada y las otras tapadas; no hizo falta tocar cámara ni viñeta.

**Notas:** Daniel (2026-10-15): como en 11.179, con la viñeta y la cámara configurables ya no hace falta 14 × ≥22; las salas pueden medir distinto, pero cada una se centra en cámara y tapa las otras. Pasa de rediseño a revisión.

### 11.179 Cumbre: cada sala centrada en cámara y tapando las otras · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `mazmorra`

Daniel (2026-10-14, ajustado el 2026-10-15): cada sala de la Cumbre se centra en cámara y tapa las otras. Los tamaños son libres (viñeta y cámara configurables); ya no hace falta 14 × ≥22.

- [x] Captura de cada sala con la cámara del nivel
- [x] Ajustar camera_offset/fov o AmbienteSala (viñeta) donde se ve otra sala o queda descentrada
  Revisadas todas: cada sala queda centrada y las otras tapadas; no hizo falta tocar cámara ni viñeta.

**Notas:** Con el nuevo sistema configurable de la viñeta y camara, ya no es necesario. Eso si, cada sala debe poder centrarse en camara y ocultar las otras salas. Por consecuencia, permite salas con diferentes tamaños como se hace con el templo donde la sala del jefe final tiene un tamaño diferente

### 11.180 Templo: salas rearmadas (22 × 14) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** L · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `mazmorra`

Daniel (2026-10-14; regla que se dejó el 2026-10-15, ahora los tamaños son libres): todas las salas de las mazmorras miden 14 de alto y al menos 22 de ancho, como la Chullpa y la Queñoa. Templo tiene salas de 14 × 10 / 14 × 12 y hay que rediseñarla.

**Notas:** Hecho en 9dfa381a: las 14 salas del templo pasan a 22 × 14 en la misma grilla, con paredes dobles y reborde; contenido corrido con su sala; navmesh rehorneado; la cámara y la viñeta del nivel toman los valores que Daniel puso para la sala del jefe. El contenido de las alas se rearma en 11.182.
Desde el 2026-10-15 el tamaño de sala es libre (viñeta configurable, cada sala centrada en cámara): 22 × 14 queda como el tamaño elegido para el templo, no como regla.

**Relacionadas:** 11.181 Paredes agrietadas: abren una sala, nunca un nicho (Queñoa y templo)

### 11.181 Paredes agrietadas: abren una sala, nunca un nicho (Queñoa y templo) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `mazmorra`

Daniel (2026-10-14): en las mazmorras una pared agrietada siempre abre una sala entera, de cualquier tipo (puede hasta ser necesaria para terminar la mazmorra), nunca un nicho con cofre. Hoy son nichos OjosCrackedWall en la Queñoa y CombinedCrackedWall en el templo: pasarlos a salas. La del templo va con el rediseño 11.180.

- [x] Templo: CombinedCrackedWall
  Ya no está: salió con la Combinada de oleadas (11.183).
- [x] Queñoa: OjosCrackedWall
  Sale el muro y su techo tapanicho (OjosNicheRoof) y el flag qv_hidden_cracked_wall: el ojo queda a la vista en su nicho de la pared norte. La llave del jefe pide arco y pluma. Sin cambio de grilla.
- [x] Test: toda pared agrietada de mazmorra separa dos salas
  test_cracked_wall: test_dungeon_cracked_walls_open_whole_rooms reemplaza al de los techos de nicho (11.164); la Chullpa sin ninguna. Falla con la Queñoa de antes.

**Prueba:** test_cracked_wall (test_dungeon_cracked_walls_open_whole_rooms), test_quenoa, test_dungeon_reach

**Relacionadas:** 11.180 Templo: salas rearmadas (22 × 14)

### 11.182 Templo boss-rush: un jefe anterior por ala · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** L · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `templo`, `jefe`

Daniel (2026-10-14): el templo, como mazmorra final, es un boss-rush: cada una de las cuatro alas (pluma, arco, gancho, espejo) termina con la revancha de un jefe anterior (Mallqui de la Chullpa, Ojos de la Queñoa, jefe de la Totora, jefe de la Cumbre), y ganarla enciende el ojo del sello del hub. Decidir qué jefe va en qué ala y si reemplaza o acompaña al puzzle del ala. Ojo: el jefe de la Cumbre es hoy un placeholder prestado (11.129). La Mano sigue de sub-jefe de la combinada.

- [x] Salas 14×≥22 (con 11.180); las Ojo pasan a arenas 22×14 sin obstáculos, vasijas en las esquinas
- [x] Mini puzzles: pluma huecos+pinchos corto; arco dos ojos-interruptor tras un abismo; gancho abismo de 4 con postes; espejo una torreta y el cristal
  Resolverlo abre la puerta de la arena y queda abierta (si perdés no se repite). Se sacan el haz del Ojo del espejo, el acorazado del Ojo del gancho y los muros agrietados entre salas; la brújula pasa a la sala de la pluma.
- [x] Revanchas: Mallqui, Ojos de la Queñoa, Yacumama, Apu Kuntur
  Media vida desde el arranque (ArenaFight.rematch), así ya pelean con la conducta de media vida; varios, apurados. Sin contenedor; morir vuelve a la entrada de la sala.
- [x] Pieza de llave del jefe por revancha (item get, HUD/ítems 1/4..4/4); 4 piezas = llave del jefe; enciende el ojo del ala
- [x] La Mano y la Combinada opcionales; la Combinada da la espada mejorada (tarjeta aparte)
- [x] Grafo del templo y test_dungeon_reach: el objetivo pide las 4 piezas; molde sin item/guard de llave
- [x] GDD §8 templo

**Notas:** Diseño acordado con Daniel (2026-10-14). Cada ala son dos salas: un mini puzzle corto con el ítem del ala, que abre la arena, y la revancha. Pluma: Mallqui; Arco: los Ojos de la Queñoa; Gancho: Yacumama; Espejo: Apu Kuntur (placeholder hasta 11.129). Cada revancha ganada da una pieza de la llave del jefe (item get) y enciende el ojo del ala en el sello; con las 4 piezas se arma la llave del jefe. El sello sigue abriendo la Antesala. La Mano y la Combinada quedan opcionales, con premio: espada mejorada (Daniel eligió la opción 1). Parte 1 en 7e75dd5d (piezas, HUD, rematch). Parte 2: las BossFight de las cuatro mazmorras copiadas a las salas Ojo, con su puerta; las revanchas de la pluma y del arco hacen aparecer las llaves chicas; brújula del otro lado de los huecos de la Pluma; los ojos sobre el abismo pasan al Arco y abren BowDoor; fuera el muro agrietado, el acorazado, el haz y los ojos-placa.

### 11.183 Espada mejorada (premio de la Combinada del templo) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `templo`, `items`

Daniel (2026-10-14) la eligió como premio de la Combinada (opcional) del templo en vez de una botella o un contenedor de corazón (11.182). Doble daño, estela del tajo dorada, quizás elemento luz que le pega más fuerte al Ojo. Necesita modelo o paleta para la espada (arte, -5d).

- [x] Ítem sword_golden: doble daño, se equipa sola, item get
- [x] Estela dorada y chispas doradas al pegar (ItemData.trail / hit_burst)
- [x] Combinada: tres oleadas variadas con sub-jefes mini (Momia, Vigía); vencidas aparece el cofre grande con la espada
  Daniel 2026-10-14: la sala combinada pasa a oleadas. WaveSpawner suelta sub-jefes (peleadores de ArenaFight) y cierra puertas que no son persianas (doors).
- [x] Modelo de la espada dorada (-5d) e ícono
  Hasta entonces, la espada común con material dorado (assets/items/sword/sword_golden.tscn) y el ícono de la común.

### 11.184 Risco: la franja del gancho no tiene bajada · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-5d · **Etiquetas:** `bug`, `overworld`

Daniel (2026-10-14, captura): arriba de la franja norte del Risco (nivel 2, x 70-88, z -38..-32, con RiscoPost y el ojo) no hay forma de bajar. Se sube solo con el gancho desde el pasillo bajo; al sur el RiscoPit, al norte y este la montaña, al oeste 5,2 m de caída al pasillo con la baranda invisible. La única salida es tirarse al abismo.

- [x] Poste del gancho en el borde de la Cumbre, frente a la franja
  Daniel (2026-10-14): alcanza con el poste, es barato; sin salto.
- [x] Test: desde la franja se vuelve sin caer al abismo

### 11.185 Crash intermitente al viajar: propagate_notification desde el hilo de carga · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-fd · **Etiquetas:** `bug`

En algunas corridas de la suite completa, un worker muere con signal 11 justo después de 'ERROR: /root: The caller thread can't call the function propagate_notification() on this node' durante SceneFlow.travel_to (carga con load_threaded_request). Última vez el 2026-10-15, viajando overworld → shrine_cave (test_cave/test_portal); log en debug/tmp/fd/crash_propagate_2026-10-15.log. Pasa de vez en cuando (la corrida siguiente da 546/0). En el código del juego no hay set_locale ni propagate_notification durante la carga: falta encontrar qué recurso, al cargarse en el hilo, le avisa al árbol. Puede pasar también jugando.

- [x] Reproducirlo con un bucle de viajes (overworld ↔ cuevas) y aislar el recurso
- [x] Arreglar la causa o cargar ese recurso en el hilo principal

**Notas:** 2026-10-15 (-fd), with the symbols build (11.188), crash caught in a run with --jobs=6: signal 11 in AudioServer::_mix_step (audio_server.cpp:243), audio thread (AudioDriverDummy), StringName::hash() on a bus name already freed. The propagate_notification error is a consequence: Godot's crash handler sends NOTIFICATION_CRASH to the SceneTree from the thread that crashed. Cause: every volume_db change makes AudioServer swap the playback's bus_details and free the old one 2 main-thread frames later (graveyard in _cleanup_lists); at headless test speed (hundreds of fps) the mixer can still be using the old one. music.gd set the volume of its 5 layers every frame even without changes. Fix: only set it when it changes. Engine race (could be reported upstream).

### 11.186 Cumbre: la reja de la llave del jefe tapa la puerta de las Torretas · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `bug`, `diseno`, `mazmorra`

Daniel (2026-10-15, captura): en PisoCornisa, la puerta sur de las Torretas (Paso LA ns, celda (6,7)) desemboca justo en la celda de BossKeyGate (12,0,16), que está girada a lo largo del paso y se ve atravesada en la puerta. Es la del nicho de BossKeyChest (14,0,16), que abre SolReceiver. Viene del blockout (4f360313) y nunca se rediseñó. Hay que separar el nicho de la llegada desde la puerta: que la reja cierre el nicho y no el paso.

- [x] Nicho de la llave del jefe aparte de la puerta, con su reja de frente
  El cofre grande pasa a la esquina noroeste (2,0,16), con su reja al este (4,0,16) y los muros de basalto que ya estaban debajo; los dos muros del nicho viejo (celdas 6,9 y 7,9) quedan piso. Navmesh rehorneado.
- [x] Test: de la puerta de las Torretas se entra al Ojo del Sol sin chocar la reja

**Prueba:** test_cumbre (test_the_door_from_the_turrets_lands_in_the_sun_eye_room_clear_of_the_boss_key_gate)

### 11.188 Build de Godot 4.8-dev7 con símbolos para diagnosticar el crash 11.185 · Hecho

**Terminada:** 2026-10-15 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-fd · **Etiquetas:** `bug`

El crash 11.185 pasa en un hilo del WorkerThreadPool que lee un StringName ya liberado (parece la búsqueda de un grupo de un nodo, HashMap en node+0x1e8), después del error de propagate_notification sobre /root. El binario oficial viene sin símbolos, así que el backtrace no dice qué parte del motor es. Hace falta compilar el mismo commit (c971f93e7) con debug_symbols=yes (y si se puede dev_build o sanitizers) y correr la suite en bucle hasta que se repita.

- [x] Compilar Godot c971f93e7 (editor, linux) con debug_symbols=yes
- [x] Correr la suite completa en bucle con ese binario hasta reproducir el crash
- [x] Con el backtrace legible, identificar la causa y seguir en 11.185

**Notas:** 2026-10-15 (-fd): built c971f93e7 (editor, debug_symbols=yes) at /home/ssd_disk/godot-c971 (worktree of godot-master), registered as 4.8-dev7-symbols in godot-select (symlink). 40 full suite runs (--jobs=3) in wt/bugs with that build, ~2.3 h: no crash. The only failures were test_input › test_shift_locks_and_wheel_switches (4 of 40), caused by test_chest leaving an item-get box on the way (fixed in main). The next loop with more load (--jobs=6) caught the crash: the audio mixer reading a freed bus name; fixed in 11.185 (2b38925b).

### 11.189 D4: backtracking de la llave del jefe · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `mazmorra`

Daniel (2026-10-15): la llave del jefe de la Cumbre va al nicho del Atrio (escudo + sol); atajo de un solo sentido de la Antesala a la Llegada; las vasijas del Atrio pasan al nicho del Ojo del Sol. Regla boss-key-backtracking. Con rim y navmesh si cambia la grilla.

**Notas:** Hecho el 2026-10-15 (b482f682): la llave del jefe pasa al nicho SO del Atrio, tras la reja que abre el cristal con el escudo; el nicho del Ojo del Sol guarda las vasijas; la Antesala tiene una placa (cu_antesala_step) que abre una puerta nueva a la Llegada y la deja abierta: de vuelta del Atrio se sube por Nido, Cámara y escalera. Grilla: una celda de pared interna de la cornisa pasa a paso (el rim no cambia); navmesh rebakeada. test_cumbre al día. Falta: que Daniel la recorra.

### 11.190 Templo: una pieza de corazón · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-aa · **Etiquetas:** `diseno`, `templo`

Daniel (2026-10-15): agregar una pieza de corazón en el templo del ojo. Ver con 11.124 (piezas de corazón: 13, no múltiplo de 4).

**Notas:** Hecho el 2026-10-15 (2e11c8c2): en el ala del gancho, contra la pared norte, el abismo se abre a 6 celdas y queda un islote de 2 × 2 con la pieza (te_heart_piece). Se llega con el salto largo (2 celdas de cada lado; la pluma sola no alcanza) y se vuelve igual. Grilla: 8 celdas internas (el rim no cambia), Pit más ancho, navmesh rebakeada. test_sandals hace el salto de ida y vuelta. Con esta quedan 13 piezas (11.124: sobra una). Falta: que Daniel la pruebe.

### 11.191 Martillo: ítem de golpe fuerte · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `items`, `diseno`, `combate`

Daniel (2026-10-15): un evento de mini jefe en el overworld, en una zona después de D2, hace aparecer el martillo. Definir el ítem: ItemData, el golpe fuerte (qué HitBox/AttackData lo marca como golpe fuerte, para que la placa STRIKE lea lo mismo), qué rompe o activa, su lugar en la cadena (después de D2: sirve en D3+ y el overworld, nunca gatea D1/D2) y GDD §6. Modelo listo: assets/epiphany/meshes/equipo/martillo.res (-5d).

- [x] Congelar al golpeado un instante
  Daniel (2026-10-15): quien recibe el martillazo (no la onda) queda aturdido un par de cuadros. HammerStrike.stun_time 0,1 s con Feel.hit_stop; test_hammer.

**Notas:** Hecho el 2026-10-15 (a124b61b): data/items/hammer.tres (id hammer, ítem de botón, 1 corazón de daño). StrikeBehavior: animación Melee_2H_Attack_Chop; en use_at clava src/items/hammer/hammer_strike.tscn (una Hitbox de 1,1 m de radio, 3 cuadros, polvo y temblor) a 1,2 m hacia donde mira el player, y el martillo se ve en la mano del arma mientras dura (assets/items/hammer/hammer.tscn, para ajustar a ojo). Golpe fuerte: DamageInfo.strong, que pone Hitbox.strong o AttackData.strong; lo leen Breakable.needs_strong (la espada rebota), las guardias de escudo y las corazas (como la bomba); la placa STRIKE (11.193) también (19adbaeb). Ícono, textos es/en, GDD §6.1, test_hammer. El mini jefe que lo da ya está (11.192). Falta solo que Daniel lo pruebe (momento del impacto, pose en la mano).

### 11.192 Overworld: mini jefe después de D2 que da el martillo · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-5d · **Etiquetas:** `overworld`, `enemigos`, `jefe`

Daniel (2026-10-15): evento de mini jefe con un par de monstruos en una zona del overworld a la que solo se llega después de D2; al vencerlo aparece el martillo (cofre o pedestal). ArenaFight/WaveSpawner con flag. Depende del ítem de 11.191. Si el mini jefe necesita modelo propio, va a -5d.

- [ ] Probarlo (Daniel)
- [x] No se apaga al alejarse; un golpe de lejos la empieza
  Hecho (7fcfda89): en el overworld la pelea ya no se resetea al salir de la zona (solo en salas de mazmorra); una flecha u otro golpe a un luchador la arranca. test_centinela.
- [x] Anillo de fuego que encierra la pelea
  Hecho (2a8c2b07): FireRing se cierra cuando hay un player adentro y ninguno sobre la pared; se abre al ganar o resetear. Shader anillo_fuego.
- [x] Golpe de la maza legible y Centinela sólido
  Hecho por -eb (2b187bf1): aviso antes de cargar, marca en el piso que sigue y se traba parpadeando, silbido; cuerpo sólido (AnimatableBody3D). Tiempos en 'Aviso del golpe'.

**Notas:** Hecho (198dca6c, 4470c9cb, 90e12cd9): el mini jefe es el Centinela del Bañado, en la playa del Bañado (HammerFight en ~(60, 0, 24)), con huancas de escolta; se mudó ahí desde la Necrópolis. Al vencerlo aparece el martillo.

### 11.193 Placa de golpe fuerte (modo STRIKE) · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `puzzles`, `arte`

Modo STRIKE de FloorSwitch con sus mallas (interruptor_golpe_marco/placa, ya hechas). Lee el mismo marcador de golpe fuerte que defina 11.191. Cierra el paso 4 de 11.110.

### 11.194 Jefe final: rayo del ojo con las dos manos fuera de juego · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `jefe`, `combate`

Fases 2 y 3: si las dos manos están aturdidas o caídas, el ojo suma el barrido de rayo del Ojo Vigía (línea marcada, carga, barrido) alternando con el orbe. El aturdimiento y la derrota lo cortan. data/boss/attack_laser.tres; exports del grupo Rayo en boss.gd; test en test_boss.

### 11.195 Overworld: entrada de la guarida de los guardias, del otro lado del agua (placeholder) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-5d · **Etiquetas:** `overworld`, `diseno`

Daniel (2026-10-15): más adelante se implementan las aletas para nadar; la guarida de los guardias (11.115) va en la orilla sur del lago grande, a la que solo se llega nadando. Por ahora: entrada de cueva decorativa (sin transición) y un poco de terreno para salir del agua antes de entrar. Captura de Daniel: debug/tmp/fd/guarida_orilla.png.

### 11.196 Overworld: enemigo de montaña en la zona de D4 (atoq, zorro andino en manada) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `overworld`, `enemigos`, `ia`

Daniel (2026-10-15): la zona de D4 (la explanada frente a la puerta del cóndor) está muy vacía; hace falta un enemigo de montaña. Propuesta -fd: atoq, el zorro andino (animal de la puna y el pícaro de los mitos), en manadas de 2-3 que te rodean y se turnan para tirarse a morder y retroceder; huyen con poca vida. Captura: debug/tmp/fd/cumbre_explanada.png.

- [x] IA y ficha (diseño, -43)
  Hecho el 2026-10-15 (dddfe14e): src/entities/atoq/atoq.tscn es un Enemy con el modelo de -5d y la biblioteca Atoq (ficha data/entities/atoq.tres: 6 de vida, 5 m/s, mordisco data/attacks/atoq_bite.tres con salto). Árbol atoq_bt.tres: aúlla al verte, te rodea a 3,5 m (bt_circle), muerden de a uno (bt_pack_turn + PackTurns: un turno por objetivo; bt_dart_bite corre, avisa, salta y se aleja, y después descansa 2–3,5 s), con un tercio de vida huye a 8 m (bt_flee) y sin ver a nadie deambula (bt_wander). test_atoq. Para ponerlos: instanciar atoq.tscn en el nivel (no agregarlo encima del player y moverlo después: Jolt lo despide).
- [x] Modelo y animaciones (arte, -5d)
  Hecho (-5d): 11fbebc4 modelo y biblioteca Atoq (idle, walk, run, bite, howl, hit, death); 7873a32b pelo con resortes como la trenza.
- [x] Ponerlos en la zona de D4 (overworld, -eb)
  Dos o tres manadas en la explanada y el camino a la puerta del cóndor, sin cortar el paso.
- [ ] Probarlo (Daniel)

### 11.197 Terreno del overworld: colisión simplificada (la carga congela la ventana 3,4 s) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-5d · **Etiquetas:** `optimizacion`, `overworld`, `arte`

Daniel (2026-10-15): la pantalla de carga congela la ventana (no responde al resize). Medido: la carga en hilo tarda ~1 s, pero agregar el overworld al árbol bloquea 3,4 s y es casi todo el Terreno: sus 25 CollisionShape3D son la malla visual (~2,4 M triángulos) y Jolt las arma en el hilo principal. Sin cuerpos, 0 ms. Arreglo: mallas de colisión simplificadas (~10× menos) en el import de terreno_organico; también aliviana la física en juego.

- [ ] Después de las zonas que pidió Daniel
  Daniel (2026-10-15): va a -d6 apenas termine las zonas.

### 11.198 Jefe final: más golpes al piso y lo alcanza detrás · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `jefe`, `combate`

Daniel (2026-10-15): aumentar las veces que las manos golpean el piso; detrás del jefe no lo puede atacar. Hecho (7a183320): cada golpe al piso es una tanda de slam_count (3) que sigue al player, aturdida recién después del último; el área del jefe cubre toda la sala (antes empezaba 1 m delante del cuerpo y todo lo de atrás quedaba en el borde). test_boss.

- [x] Las manos casi nunca golpeaban el piso
  Daniel (2026-10-15): fases 1 y 2, varios minutos esquivando, ningún golpe al piso. El golpe solo puntuaba a ~5 m del reposo de la mano y el barrido ganaba siempre la lista corta. Hecho (081692a0): distancia ideal 0-12 m, caída 8. test_the_hands_slam_wherever_the_player_dodges.
- [x] Detrás del ojo, el orbe chocaba contra el propio jefe
  Hecho (8c6061e7): los proyectiles ignoran los cuerpos de quien los disparó. test_the_orb_goes_through_the_boss_own_body.

### 11.199 Mazmorras: no hacer zoom a lo que se abre en otra sala · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `camara`, `mazmorra`

Daniel (2026-10-15): al resolver algo que abre una puerta en otra sala (p. ej. las 4 piezas de la llave del jefe del templo) la cámara iba a la puerta, que está oculta. Hecho (0478f030): TopDownCamera.reveal solo corre la acción si el objetivo está en salas sin player (Room.contains con margen para las puertas entre dos salas). test_wiring.

**Notas:**  Playtest 17/10: en el templo seguía. Las puertas del templo están en el hueco entre dos salas, fuera de las dos, y un objetivo sin sala contaba como visible. 4200a3b5: el objetivo es de las salas más cercanas (Room.distance_to), así una puerta solo se muestra si hay player en una de las dos que une; sin salas (overworld) siempre. test_templo.

### 11.200 Enemigos de sala de mazmorra no sueltan la persecución · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `ia`, `enemigos`

Daniel (2026-10-15): dentro de una sala no tiene sentido que el enemigo deje de perseguir una vez que empezó. Hecho (6ec22d03): FindPlayer sigue al objetivo mientras comparten la sala de origen del enemigo (Enemy.shares_room), aunque esté lejos o fuera de vista. En el overworld se pierde como antes. test_enemy_ai.

### 11.201 Autosave en la ranura de la partida · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `guardado`, `bug`

Daniel (2026-10-15): el autosave no guardaba sobre la partida (iba a la ranura Auto; la del jugador solo cambiaba al guardar a mano o salir). Opción 1 elegida: el autosave escribe en la ranura que se juega. Una Auto vieja sigue cargando y se borra con el próximo autosave de esa partida. Hecho (8b4aa0c2). test_slots.

### 11.202 Errores del log de la build 0.2 (playtest) · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

Lo que salió en el log de Daniel con la build de Linux y lo que apareció al arreglarlo.

- [x] Lluvia de global_shader_parameters_instance_allocate al cargar el overworld
  Hecho (e152171b): floor_earth de epiphany_outdoor pasa a uniform común; la fachada del templo usa epiphany_outdoor_losas.tres. Verificado en la build: 0 errores.
- [x] Martillazo y explosión agregaban efectos con la escena ocupada
  Hecho (65a8b172): los Feel de su _ready van diferidos.
- [x] Hitbox borraba Areas que no son Hurtbox de un TypedArray
  Hecho (65a8b172).
- [x] Blackboard: long_jump no encontrado en cada salto
  Hecho (65a8b172): se lee sin quejarse.
- [x] Cuelgue de la suite: Centinela y ArenaFight seguían fuera del árbol
  Hecho (8fd92be0, 81efb290).
- [x] El mapa contaba como abiertos los cofres ocultos tras switches
  Hecho (94f6c803): Chest.is_opened (su flag) en mapa y minimapa; venía del arreglo del cofre de las sandalias.
- [x] El validador de partidas no contaba el carcaj grande
  Hecho (f4263e4a): SaveCodec.validate suma las mejoras de capacidad; escenario templo_video al día (martillo, Centinela vencido) y revisado por test_save_codec.
- [x] Crash al cerrar (corrupted size vs. prev_size)
  No volvió en las corridas con la build beta1 (0.2.1392). Al salir quedan avisos sin costo: música y click del menú sonando, StringNames de LimboAI.
- [x] skeleton_updated: desconexiones inexistentes en Skeleton3D
  Del motor desde 4.8-beta1; nada nuestro usa esa señal. Reportar a Godot si sigue.
- [ ] look_at() failed: origen y destino en el mismo punto (16 veces)
  Pendiente: buscar quién.
- [x] Basis sin normalizar en aim.gd (rotar al apuntar)
  Hecho (081692a0): slerp entre bases ortonormalizadas.

### 11.203 Aprovechar las novedades de Godot 4.8 · Revisión

**Responsable:** project-epiphany-cb

PRs de 4.8 que Daniel eligió: 118045 y 115426 (luz) activados; 113970, 121122 y 115653 se usan donde corresponda.

- [x] Sombras de contacto (#118045) y AO multi-rebote (#115426)
  Hecho (26c38004): ajustes de proyecto + Sun del overworld con contact shadows + SSAO en su Environment. GPU 1080p overworld: 7.8 → 8.6 ms. Falta decidir si van también a las mazmorras.
- [x] Consultas de física sin asignar memoria (#113970)
  Hecho (887c7caf): las de cada frame (rayos de la cámara, haz de luz, ondas, gancho, vista de enemigos y del fijado) usan *_into con resultados reusados. Las de una vez quedan igual.
- [x] Decals con DrawableTexture (#115653)
  Ya en uso: CausticsDecal dibuja una DrawableTexture2D y en 4.8 el atlas se actualiza en cada blit. Usarlo para decals animados nuevos (grieta del golpe, sombras de nubes si va por decal).
- [x] get_velocity_at_position en RigidBody3D (#121122)
  Sin caso hoy: los cuerpos (vasijas, bombas) vuelan sin girar, así que equivale a linear_velocity. Usarlo cuando haya cuerpos que giran y empujan/dañan por el punto de contacto (rocas rodantes, plataformas que giran).
- [x] Shader baker y tirones de pipelines (Linux)
  Medido (2026-10-16, build debug, RX 580): overworld listo ~5,2 s con caché vacía vs ~2,6 s caliente; el baker en Linux ahorra ~0,15 s (ruido): el costo es el driver armando pipelines. El primer proyectil tiraba 48 ms; con pipeline_warmup.tscn (4e745df1) ningún efecto compila al aparecer. tools/pipeline_probe.gd mide. El baker encontró abyss_mist roto (f3335aef).
- [x] Medir el baker en Windows (D3D12)
  Medido (2026-10-16, RX 580, 3 corridas): overworld listo con caché vacía D3D12 10,3 s sin baker → 8,1 s con baker (-21 %), Vulkan sin baker 8,2 s; caliente todos ~2,7 s. Baker activado en el preset Windows (release). El bake de D3D12 solo sale exportando desde Windows: la release de Windows se exporta allá. Debug sigue sin baker. LimboAI: debug usa la dll editor, release la template_release.

**Relacionadas:** 15.1 Warm-up: variantes que faltan en Windows; 15.2 Pico suelto de sparks_gold; 15.4 Contact shadows y SSAO en mazmorras

### 11.204 Jefe final: manos al cambiar de fase, aturdido, golpes y rayo · Hecho

**Terminada:** 2026-10-17 · **Responsable:** project-epiphany-cb

Pedido de Daniel (2026-10-16) tras pelear con el jefe final.

- [x] Las manos no se reiniciaban al cambiar de fase (quedaban en el piso)
  Hecho (82b7934a): al entrar a la fase 3, BossHand.reset corta ataque, aturdida o caída, suelta al player y la vuelve al reposo con la vida llena. Los ataques a medio esperar se cortan con un contador de corrida. test_the_third_phase_brings_every_hand_back, test_a_reset_cuts_a_slam_in_the_middle.
- [x] Aturdido, el ojo quedaba en blanco
  Hecho (82b7934a): miraba casi al piso y desde la cámara se veía solo el blanco. Ahora el cuerpo cae para atrás con rebote y la mirada baja a medias entre la cámara y el frente, meciéndose: se ve la pupila dilatada, caída. test_the_stunned_eye_droops_but_shows_its_pupil (con cámara propia, 5f8bda31).
- [x] Cada golpe: el ojo cambia de color y se mueve
  Hecho (82b7934a): tinte rojo (HitFlash.hold) y tirones al azar solo del globo del ojo (Body/Eye/Mesh); párpados y cuerpo quietos. test_each_hit_tints_and_jolts_only_the_eye.
- [x] Shader del rayo, como la onda pero rojo
  Hecho (82b7934a): laser.gdshader, núcleo casi blanco, halo rojo que late y se ensancha, chispas que corren hacia la punta; el mismo shader en modo disc para la quemadura del piso. Radio del haz 0,26.
- [x] El grito del jefe final no se saltea
  Hecho (dd212b4f): ni la intro ni las presentaciones de fase, aunque sea revancha o ya se haya visto. Los subjefes (ArenaFight) siguen salteables.
- [x] Las manos desaparecen como el ojo al vencerlo
  Hecho (dd212b4f): BossHand.vanish, el neón se apaga titilando, tiemblan con estallidos y se hunden achicándose, al mismo tiempo que el ojo. test_the_hands_go_away_like_the_eye_when_the_boss_dies.

### 11.205 Escudo siempre en la mano; la guardia es Z · Hecho

**Terminada:** 2026-10-17 · **Etiquetas:** `combate`

Pedido de Daniel (2026-10-16): el escudo va siempre en la mano y solo bloquea mientras se mantiene el Z-target, con blanco o sin él. Se saca el botón de bloquear (RT, click derecho) y el escudo de la espalda. Con Z el player camina lento. Atacar cubriéndose da una estocada con la espada en vez del golpe de escudo.

**Notas:** Hecho (cb, 2026-10-16, d6417d81): Z (z-lock) levanta la guardia; en modo alternar, mientras hay un blanco fijado. Sin acción block ni escudo en la espalda: lo de atrás pega siempre. Estocada: sword_stab.tres (Melee_1H_Attack_Stab, hitbox 0,22–0,42, cancel 0,5, lunge 3, aturde 1,2 s y baja guardias). El escudo solo sale de la mano mientras sostiene el arco. Diagramas de controles sin la fila de bloquear; textos de escudos y CONTROLS_LOCK actualizados. Para revisar jugando: velocidad con Z, ritmo de la estocada (la animación dura 1,6 s), RT libre.

### 11.213 Guardián mano: reiniciar la pelea no corta el ataque · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): HandGuard.reset llama hand.regenerate, que no saca a la mano de BUSY: si caés por un pozo a mitad del golpe termina el combo. Sin verificar.

**Notas:** Hecho (-e0): HandGuard.reset ahora llama _interrupt() y hand.reset() (antes hand.regenerate()): _drop_everything sube _run, mata los tweens del golpe y suelta al player, y recién después regenera. Con regenerate sola la mano seguía BUSY y el combo caía aunque el player hubiera caído por un pozo. test_arena_fighter › test_resetting_the_hand_guard_cuts_its_attack: reset a mitad del golpe → striking false, no queda aturdida, vuelve a READY (falla sin el arreglo).

### 11.214 Jefe final: elige a un player al empezar y no cambia · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`, `co-op`

Revisión con patrones (2026-10-19): boss.gd fija target en start_fight; si ese player muere o se va, el jefe ataca el cuerpo o deja de atacar. Las manos leen target después de awaits sin validar. Sin verificar.

**Notas:** Regla aprobada por Daniel (2026-10-19) y hecha (-e0): pick_target() en cada choose_attack mantiene el objetivo salvo que muera, salga de la arena u otro esté RETARGET_MARGIN = 3 m más cerca del ojo; quien pega al ojo aturdido es el próximo (_aggro, la flecha cuenta por su tirador); la segunda mano del combo va al otro player vivo; sin nadie vivo en la arena no ataca. Las manos dejan de seguir un target liberado. test_boss_coop (5 pruebas, dos players reales): margen 2 m vs 3,5 m, aggro, segunda mano, arena vacía, muere el objetivo → va al otro. Playtest en co-op: el jefe no debe alternar entre dos pegados.

### 11.215 Usar un ítem se come el empujón del golpe · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-72 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): El tween de velocidad de using_item.gd sigue después del estado. Sin verificar.

**Notas:** Hecho (-72): using_item.gd guarda el tween de frenado (_brake) y lo mata en _exit; antes seguía 0.15 s escribiendo velocity = 0 sobre el empujón de Hurt. Transition no tiene ese patrón y no hay otros tweens de velocity en player/ ni src/. test_item_use › test_a_hit_right_after_pressing_an_item_still_pushes_back: aprieta X con la poción, recibe un golpe enseguida, pasa a Hurt y se aleja > 0,5 m; sin el arreglo se movía 0,00 m.

### 11.216 Guardado: datos inválidos y escena que no carga · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-72 · **Etiquetas:** `bug`, `guardado`

Revisión con patrones (2026-10-19): Escena que existe pero no carga deja pantalla vacía (verificado). Equipo con ítem renombrado deja sin espada; max_health 0; settings.cfg sin chequeo de tipos ni escritura atómica; sin guardia de reentrada al cargar durante un viaje.

**Prueba:** tests/test_save_manager.gd, tests/test_slots.gd, tests/test_options.gd

**Notas:** Hecho (b6fd8a52, -72): 1) enter_saved_scene devuelve bool: si la escena no existe o no carga, va al inicio del overworld; si tampoco, al título; enter_save devuelve ERR_CANT_OPEN y _load_path lo devuelve (y deja loading en false). new_game no sigue con la intro si no entró. 2) read_from: equipo con ítem inexistente o de otra categoría vuelve al del equipo inicial (y lo agrega al inventario); botella fuera de bottle_1..4 se descarta; contenido inexistente o sin líquido queda bottle_empty; max_health al menos HP_PER_HEART. 3) Settings: SaveCodec.typed al leer; guarda a .tmp, borra y renombra, devuelve el Error y lo loguea; si quedó solo el .tmp lo lee. 4) SceneFlow.is_busy() (cargando una partida, volviendo al título, o en un viaje salvo la acción de with_fade, que es la carga misma): _load_path, enter_save y quit_to_title devuelven ERR_BUSY. Tests: test_save_manager (escena que no carga, segunda carga en medio de otra), test_slots (equipo/botellas/corazones reparados), test_options (opciones tipadas y escritura atómica).

### 11.217 Co-op: P2 en una cinemática y time_scale con dos dueños · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-72 · **Etiquetas:** `bug`, `co-op`

Revisión con patrones (2026-10-19): Un player que entra durante una cinemática camina libre. El anillo de ítems y Feel.freeze escriben Engine.time_scale sin dueño. TextBox hace pop de la pantalla de arriba, no de sí mismo (latente).

**Notas:** Hecho (-72): (1) Cinemática: un player que entra mientras tiene los controles (Players.joined) queda captured=true y se suelta en _restore como el resto; _game_camera() tipado TopDownCamera (se fue el call(&"snap_to_target") que quedaba de 16.34). (2) TimeScale (src/flow/time_scale.gd), estático como Pause: hold(reason, scale)/release/is_held/clear, gana el más lento. Feel.freeze toma &"freeze" (no se repite si ya está), el anillo de ítems en solitario toma &"item_ring"; SceneFlow._go_to_title llama TimeScale.clear() junto a Pause.clear(). Nadie más escribe Engine.time_scale en src. (3) TextBox: finished → MenuStack.close(box), cierra esa pantalla y lo que tenga encima, y nada si ya no está (antes hacía pop de lo de arriba). Tests: test_feel › test_overlapping_slowdowns_keep_the_slowest, test_intro › test_a_player_joining_mid_cutscene_waits_with_the_others, test_text_box › test_a_finished_box_only_closes_itself. 50 archivos, 321 pruebas, 0 fallos.

### 11.206 Sub-jefes: las esperas siguen después de un reinicio · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): _interrupt no cancela las esperas de ArenaFighter._wait (no van a _tweens). La cola de la Yacumama barre invisible 1,8 s si la enganchás mientras sube; el Amaru aparece en otro charco si salís de la sala con él bajo el agua. Arreglo de raíz: _wait con _new_tween.

**Prueba:** tests/test_arena_fighter.gd

**Notas:** Hecho (3dd2834a): _wait pasa por _new_tween, así _interrupt corta las esperas pendientes. Para probar: enganchar a la Yacumama con media vida mientras sube la cola (no barre); salir de la sala con el Amaru bajo el agua y volver (está en su charco de inicio).

### 11.207 Agua del Bañado: entre áreas contiguas se camina a velocidad normal · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): shallow_water.gd pone ground_speed = 1.0 al salir de un área aunque el player ya esté en la de al lado (las cuatro BanadoWater se tocan).

**Prueba:** tests/test_shallow_water.gd

**Notas:** Hecho (69866ffd): al salir de un agua se mantiene la velocidad de otra en la que siga. Para probar: cruzar el Bañado de un área a la otra.

### 11.208 Salir por la escalera no avisa que dejaste la sala · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): TopDownCamera.reset_room() olvida la sala sin player_left: bloques trabados no se reacomodan, torretas no reviven, ArenaFight no se reinicia. Chullpa, Queñoa, Cumbre, Totora.

**Prueba:** tests/test_chullpa.gd

**Notas:** Hecho (2b35ffab): la escalera llama TopDownCamera.leave_room, que avisa player_left. La reaparición sigue con reset_room. Para probar: trabar un bloque, salir por la escalera y volver; romper una torreta, subir y bajar.

### 11.209 Morir cargando algo saca el cuerpo en un callback de física · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): health.died llega desde area_entered y el estado de carga suelta el objeto con reparent ahí mismo. La herida normal ya se difiere; la muerte no.

**Notas:** Hecho (a83f1cf0): health.died con CONNECT_DEFERRED. Sin test (es la misma solución que la herida). Para probar: morir con una vasija o una bomba en las manos; no debe salir error en el log.

### 11.210 Hit-stop y aturdido del martillo no frenan a jefes con hurtbox anidado · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`, `combate`

Revisión con patrones (2026-10-19): Congelan hurtbox.get_parent(): en momia, Amaru, guardián mano y jefe es un Node3D interno, no la entidad.

**Prueba:** tests/test_arena_fighter.gd

**Notas:** Hecho (1377bb4d, el cambio de player.gd quedó en a83f1cf0): Hurtbox.entity() da la raíz de su escena. Para probar: espadazo a la momia o al Amaru; los dos se frenan un instante.

### 11.211 Pelea de sala: se puede ganar dos veces · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): Si una bomba mata al último sub-jefe y al último escolta en el mismo cuadro, _on_defeated corre dos veces y _win no se cuida: doble autoguardado y aviso.

**Notas:** No es un bug: cada muerte emite defeated en el momento, así que el chequeo de 'no queda ninguno' pasa una sola vez (en la última). Probado matando al centinela y sus huancas en el mismo cuadro: una sola victoria. Sin cambios; cerrar si estás de acuerdo.

### 11.212 Vasija grande apoyada queda fuera de su piso · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`

Revisión con patrones (2026-10-19): Liftable la reparenta a current_scene al apoyarla: deja de estar bajo su DungeonFloor y puede verse flotando sobre la planta baja (RellanoPot de Chullpa). Usar Spawns.root / volver al padre original.

**Prueba:** tests/test_big_pot.gd

**Notas:** Hecho (160141b6): Liftable recuerda su padre al levantarse y vuelve ahí al apoyarse. Para probar: en Chullpa, cargar la vasija grande del Rellano, apoyarla y bajar al piso de abajo (no se ve flotando).

### 11.218 Copiar una ranura pierde su respaldo · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-72 · **Etiquetas:** `bug`, `guardado`

Auditoría con patrones de diseño (-72, 2026-10-19): save_manager.gd:135 copy_slot copia solo el archivo principal (o el .bak si falta), nunca los dos: si el original está corrupto, la copia no tiene .bak del que recuperarse. Arreglo: copiar también slot_path(from)+'.bak' si existe.

**Prueba:** tests/test_slots.gd

**Notas:** Hecho por -72 (6cabd3b5): copy_slot copia la partida y su .bak a .copy y renombra solo cuando están los dos; si falla una copia limpia los temporales y deja el destino como estaba. Para probar: copiar una ranura en el menú y cargar la copia.

### 11.219 Cámara: el canal de agua tras el labio sur se ve negro · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-72 · **Etiquetas:** `bug`, `camara`

Revisión de Totora con paredes dobles (12.41, 2026-10-19). Desde Gancho, el canal de agua del cruce del gancho hacia Balsas, que atraviesa la pared doble sur, se ve como un hueco negro. Desde Balsas se ve bien. No es el nivel: en top_down_camera._mask_around, detrás del labio sur de la sala, la tira 5 tapa hasta piso − 0.3 (cc571214, 11.151 d5e0d9a5, para que no asome el piso de abajo) y el agua está a −0.35, así que queda bajo la máscara. Pasa en toda puerta sur de toda mazmorra; con agua se lee como agujero. Arreglo posible: excepción de cámara (no bajar la tira 5 en celdas con agua, o que la sala vea su canal). Toca la cámara de todos los niveles: coordinar con 16.54. Capturas: debug/tmp/design/tot_Gancho.png y tot_Balsas.png en wt/design.

**Notas:** Hecho (-72): la tira 5 (SouthUnder, bajo la pared sur de la sala) tapa desde piso − 0.5 (const SOUTH_UNDER_DEPTH) en vez de − 0.3, el 'justo bajo el piso' de 11.151. El agua a −0.35 queda sobre la máscara y el piso de abajo (8 m más bajo, sus paredes hasta −2.6 como mucho) sigue tapado. Detrás del labio (tira 4) sigue negro a propósito, como el pasillo de una puerta sur: el canal se lee como una puerta (agua por la pared propia de Gancho, después negro). Capturas antes/después en wt/design debug/tmp/design: tot_Gancho.png (hueco negro) y tot2_Gancho.png (se ve el canal); Balsas igual (tot2_Balsas.png). Test: test_totora › test_the_water_channel_under_the_south_wall_is_not_masked.

### 11.220 Tests: test_arena_fighter falla a veces junto a test_centinela y test_audio · Revisión

**Responsable:** project-epiphany-e0

Visto 2026-10-19 (-e0): en main, --jobs=1 --only=test_arena_fighter.gd,test_centinela.gd,test_audio.gd falla 1 de 3 corridas: test_tweens_wait_stops_with_the_pause_not_with_the_node (no termina sin pausa), test_starting_mid_roar_leaves_the_rest_pose y test_an_interrupt_drops_the_pending_waits (las esperas no avanzan). Solo, test_arena_fighter pasa siempre. Sospecha: algo de la corrida anterior deja el árbol en pausa o time_scale en 0 (Pause.hold / hit-stop sin liberar).

**Notas:** Hecho (-e0): el orden de los archivos en un proceso cambia según los tiempos; cuando test_centinela corría antes, su nivel seguía cargado y sus cuadros largos hacían que el timer de 0,2 s venciera antes que un tween de 0,05 s en el mismo cuadro (los timers se procesan primero). No era una pausa colgada (lo verifiqué registrando Pause/time_scale después de cada test). TestCase.use_empty_scene() saca el nivel que quedó; lo usan test_arena_fighter y test_boss._spawn. 8 de 8 corridas sin fallos (antes 1 de 3 fallaba).

### 11.221 Jefe: las manos rompen si cambia la escena a mitad de un golpe · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `bug`, `jefe`

Visto por -5c (2026-10-19) en 11.9: boss_hand.gd esperaba get_tree().physics_frame en un bucle; si la escena cambia a mitad de un golpe, get_tree() es null y tira error.

**Notas:** Hecho (-e0): las esperas por cuadro de las manos pasan por _physics_frame(), que devuelve false si la mano ya no está en el árbol; un cambio de escena a mitad de golpe, agarre, barrido o reset termina la corrutina en vez de esperar sobre un árbol null. test_boss › test_leaving_the_tree_mid_slam_ends_quietly (falla sin el arreglo en boss_hand.gd:350).

### 11.222 Salto largo de prueba con las sandalias · Revisión

**Responsable:** project-epiphany-3e

De 11.105 (propuesta aprobada por Daniel): cerca de donde se consiguen las sandalias (Necrópolis), un hueco de 3 celdas que solo se cruza con el salto largo (pluma en carrera con sandalias), con 10 flechas del otro lado. Pide GridMap y terreno, así que va por el overworld (-3e): rearmar el terreno y rehornear la navmesh (-5c) si cambian las celdas.

**Prueba:** test_sandals › test_the_necropolis_pillar_takes_a_long_jump_there_and_back, test_a_running_feather_jump_falls_short_of_the_necropolis_pillar. A mano: sandalias + pluma en carrera desde el borde sur de la Necrópolis hasta el pilar del cofre.

**Notas:** -3e (wt/overworld 1da09005, main 13c32d16): el hueco del borde este quedó descartado porque caía sobre el nicho del Mirador (11.124). Ahora es una bahía en el borde sur de la meseta de la Necrópolis (celdas x 14–21, z 1–5, a nivel 0, abierta al Cardonal) con un pilar de nivel 1 a 3 celdas (17–18, z 4–6) y LongJumpChest arriba (10 flechas, ow_long_jump_chest). Errar cae al piso de la bahía, con escalera al lado: sin abismo. El borde de arriba (16–18, 0) y el norte del pilar (17–18, 4) son Andén borde (v) para que la baranda no corte la carrera. Hueco real ≈5,7 m (bordes orgánicos redondeados) contra 6,59 m del salto largo; ida y vuelta con ≈5,3 m de carrera aterrizan 0,9 y 1,2 m pasado el borde. Se sacaron a mano CardonChico12/13/16 de overworld_decor.tscn; un marcador LongJumpGap aleja las plantas de la línea. decorate_levels.gd no se volvió a correr (reescribe ≈3300 líneas y rompe test_walk_every_zone en la Pradera). Falta la navmesh (-25).

### 11.223 Opciones en dos pestañas: Juego y Video · Revisión

**Responsable:** project-epiphany-72

Daniel (2026-10-20) eligió la propuesta A del canvas (fila 'Opciones · Video con lugar para crecer'): pestañas Juego (Controles+Idioma | Audio) y Video (Pantalla | Gráficos) con LB/RB, lugar para ~4 filas más por columna. Video ya no entraba a 720p (8 filas).

**Notas:** Done (-72, fce7ace1): TabBar Juego | Video with LB/RB (device prompts), Video = Pantalla | Gráficos; nodes named after the Settings keys; test_options covers switching tabs and focus.

### 11.224 Golpe en picada legible: salto más alto y espada clavada en el piso · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** design

Daniel (2026-10-20): el golpe en picada (11.34 paso 4) no se entiende y se siente frame perfect. Hoy solo sale por encima de 0,2 m del salto de 0,68 m de la pluma; antes cae al ataque normal. Atacar en cualquier momento del salto de la pluma (desde que deja el piso) tiene que clavarlo. Al entrar sube un salto extra (≈+1 m) con la espada en alto, frena arriba un instante y cae rápido con la espada hacia abajo. Al tocar el piso la espada queda clavada ≈0,4–0,5 s y se arranca. La onda (×2, 1,2 m) sale en el impacto, con polvo, sacudida y sonido. Animación autorada (AnimationPlayer) en lugar de Melee_2H_Attack_Chop. Alturas y tiempos exportados en player.tscn para afinar a ojo. Encargado a diseño (-88).

**Prueba:** test_plunge (6): test_it_rises_hangs_drops_and_the_sword_stays_stuck (clavada entre 0,4 y 0,5 s reales), test_an_early_press_also_plunges. A mano: pluma + ow_tech_plunge (piedra de la Arboleda) y atacar apenas despega.

**Notas:** -88 (wt/design-fix 708d9ea2, main e82f5bee): can_plunge solo pide haber despegado y ow_tech_plunge. Sube rise_height (1 m) con la espada en alto, frena mientras la espada gira hacia abajo, cae a fall_speed; en el impacto onda ×2 de 1,2 m, polvo, Feel.shake y hit_stone; la espada queda clavada stuck_time y la saca (pull_time). Poses Carry/Plunge_Rise, _Fall, _Stuck, _Pull horneadas en build_carry_anims.py (IK al mango) en lugar de Melee_2H_Attack_Chop. Exports en el nodo Plunging de player.tscn: rise_height, hang_time, fall_speed, stuck_time, pull_time, shake. GDD 4.2 y TECH_PLUNGE_DESC/tech_plunge_1 (es/en).
Bug de antes que encontró: el HSM del player corre dos veces por cuadro de física (LimboHSM update_mode PHYSICS por defecto + movement_state.update(delta) en player.gd). Los valores del picado están pensados para eso: hang 0,24 / stuck 0,9 / pull 0,7 ≈ 0,12 / 0,45 / 0,35 s reales, fall 9 ≈ 18 m/s.

### 11.225 Escudo del player: en el brazo, no arrastrándolo · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** design

Daniel (2026-10-20): el escudo parece que lo lleva arrastrando. Referencias (Link de Minish Cap y de A Link Between Worlds): sin cubrirse, el escudo va en el antebrazo izquierdo, delante del cuerpo a la altura del pecho o la cintura, con el borde de abajo bien lejos del piso; al cubrirse, el brazo sube y se adelanta y el escudo tapa torso y cabeza de frente a la amenaza. Hoy es ShieldSocket (Marker3D en Hand_L de player.tscn) con transform a mano, y al cubrirse Melee_Blocking. Revisar quieto, caminando, corriendo, rodando y atacando. Encargado a diseño (-88).

**Prueba:** test_shield › test_the_shield_rides_in_front_and_rises_to_block (mira al frente, va delante, borde a más de 0,25 m del piso, sube al cubrirse), test_the_shield_arm_lets_go_without_the_shield_in_hand. Capturas antes/después (idle, carrera, rodar, ataque, bloqueo quieto y caminando) en epiphany-wt/design/debug/tmp/design/escudo_antes_despues.png.

**Notas:** -88 (wt/design-fix faeb5450, main 3ce8872a): sin cubrirse, ShieldSocket a mitad del antebrazo izquierdo, cara al frente (≈35° a la izquierda), borde lejos del piso; pose nueva Carry/Shield_Hold (build_carry_anims.py). Al cubrirse Carry/Shield_Block reemplaza a Melee_Blocking: antebrazo parado delante del pecho, tapa torso y mentón (con el brazo chibi no llega a toda la cabeza). AnimationTree: ShieldArm (Blend2 filtrado al brazo izquierdo) sobre moverse y atacar; ShieldRoll al rodar con la pose de base para que el OneShot de Dodge conserve su duración; Guard arriba de Attack. Equipment apaga las capas sin escudo en la mano (arco). Arreglos de paso: SwordBeam ignora los cuerpos de quien lo tira (el StaticBody del escudo lo deshacía); el fantasma del rodar en test_player mide el AABB entero.

### 11.226 HSM del player corre dos veces por cuadro · Revisión

**Prioridad:** alta · **Tamaño:** L · **Responsable:** project-epiphany-25

Encontrado por -88 en 11.224 y medido (120 updates en 60 cuadros): MovementState (LimboHSM) tiene update_mode PHYSICS por defecto y además player.gd llama a movement_state.update(delta) en _physics_process. Todos los _update de estados, la gravedad de state_machine y move_and_slide corren dos veces: velocidades al doble, timers a la mitad, gravedad efectiva ×4 en el player. Daniel (2026-10-20): arreglarlo con la misma sensación. MovementState en MANUAL y convertir los valores del player para que juegue igual que hoy en unidades reales, con un test que compare arcos y duraciones antes y después. Encargado a -25.

**Prueba:** tests/test_player_timing.gd: duraciones (±1 cuadro) y distancias (±5 cm) de caminar, rodar, salto, salto largo, dash y rebote, combo, giro, golpe recibido, contra, picado, gancho, levantar y tirar, poción, arco, item get, cruce de sala, agarre, trepar y empujar bloque, medidas en main antes del arreglo. A mano: que el player se sienta igual que antes.

**Notas:** -25 (wt/art-hsm feb42d0a, main fea8c637): MovementState en MANUAL con un solo update. Valores en unidades reales: velocidades ×2 (caminar 10, rodar 16, salto 8 / largo 17,2, dash 19, gancho 28…), duraciones ×0,5, tasas exp y pasos move_toward ×2, embestidas de la espada ×2 en data/attacks, gravedad ×4 por PlayerCharacter.gravity_scale / fall_gravity(). Esperas atadas al largo de una animación usan PlayerState.ANIM_PART = 0,5, como antes. La gravedad y el despacho de input pasaron a PlayerStateMachine.read_input() antes de update(): LimboHSM difiere un dispatch hecho dentro de su update y con un solo update el estado nuevo actuaba un cuadro tarde. El salto le resta un cuarto de cuadro de gravedad para conservar el arco (cima 0,71 m, salto largo 6,59 m en el aire).
Para Daniel: escapar del agarre son 4 apretadas reales (eran 8 en el código, cada una contaba doble) y ahora se ve el meneo del agarre. Cosas que el doble update escondía y se conservaron: el knockback del player es 2× el de un enemigo (Hurt.knockback_scale 2), los iframes del rodar duran más que el rodar (iframes_to 1,4), Dead aplica gravedad dos veces (los 8g de antes). test_jump: los pinches pasaron de 1,5 a 1,7 m.

### 11.227 Decoración del overworld que se pueda volver a correr · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-3e

-3e en 11.222: tools/decorate_levels.gd no se corre en cada rearmado del terreno, porque una pasada completa reescribe ≈3300 líneas de decor y rompe test_walk_every_zone en la Pradera. Por eso la decoración no siguió al recorte de BanadoWater1 (11.115), y los cardones del salto largo se sacaron a mano. Hacer que la pasada sea determinista y estable (misma semilla y orden, que solo cambie lo que toca el terreno nuevo), que respete los caminos de test_walk_every_zone y marcadores como LongJumpGap, y correrla una vez para el Bañado. Encargado a -3e.

**Prueba:** test_overworld › test_the_decor_plants_match_the_terrain_plants (Decor/Plantas igual a tools/plantas_overworld.json a su altura, salvo portales y arenas; con la decoración vieja daba 13 faltantes y 8 de más), test_walk_every_zone. Dos corridas seguidas de decorate_levels.gd dejan el mismo archivo.

**Notas:** -3e (wt/overworld 6c3d7f25, main 03b3b430): decorate_levels.gd arranca de la decoración anterior: una pieza que sigue sobre piso y lejos de los nodos jugables se queda donde estaba aunque su zona se haya movido; solo se vuelve a ubicar lo que desapareció, con un RNG sembrado por celda (jitter, giro, prioridad) para que un cambio local no reordene la zona. Lo que vuelve a salir (misma malla en el mismo x,z) conserva nombre, posición en el archivo y unique_id, y su transform exacto si el terreno nuevo lo mueve menos de 5 cm. Idempotente; `-- --fresh` rearma de cero. La corrida completa vieja rompía test_walk_every_zone porque Zone_start se había corrido al este y una pasada de cero ponía piezas nuevas en la ruta del claro. Corrida de puesta al día (143 líneas en vez de ≈3300): 9 plantas en la orilla recortada del Bañado, 2 menos en el campamento del Cardonal, la bahía del salto largo limpia, 4 yaretas menos en la Cumbre, grupos de zona vacíos al día. La decoración no entra en la navmesh: no hace falta rehornear.

### 11.228 Combo: el segundo golpe arranca donde termina el primero · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** design

Daniel (2026-10-20): en el combo, la animación del segundo ataque tiene que arrancar donde termina el primero. Hoy el 1 es sword_slash (Melee_1H_Attack_Slice_Diagonal) y el 2 es sword_backhand (Melee_1H_Attack_Slice_Horizontal), que arranca desde su propia guardia: el brazo vuelve atrás antes de pegar. El revés tiene que salir de la pose final del diagonal (espada abajo y cruzada) y volver en sentido contrario, y lo mismo revisar del 2 al 3 (sword_stab). Animación autorada (bake como las Carry/Plunge_* o recorte o espejado del clip), sin tocar los tiempos del golpe ni los de 11.226. Encargado a diseño (-88).

**Prueba:** test_combo, test_player_timing (combo sigue en 42/64/78 cuadros), test_animation_players, test_items. Capturas antes/después de 1→2 y 2→3 en epiphany-wt/design/debug/tmp/design/combo_golpe1a2_antes_despues.png y combo_golpe2a3_antes_despues.png. A mano: encadenar los tres golpes.

**Notas:** -88 (wt/design-fix 6641f184, main 23d408c3): Slice_Diagonal y Slice_Horizontal de KayKit barren los dos de izquierda a derecha, así que el revés volvía a cargar a la izquierda y la espada pasaba de golpe por la guardia. Clips nuevos en player/animation/libs/Combo.res, armados por tools/build_combo_library.gd sampleando CombatMelee: Combo/Backhand arranca en la pose del tajo en su cancel_from (0,55, espada abajo a la derecha), sube por ese lado y barre de derecha a izquierda, pasa sobre el hombro izquierdo y vuelve a la guardia; Combo/Thrust arranca en el revés encadenado (0,45, espada arriba a la izquierda) y entra en la carga de Stab. Mismas duraciones que los de KayKit: no cambian las ventanas de AttackData ni de cancelación. sword_thrust usa una entrada nueva "Thrust" en AttackType; Stab queda para la estocada de escudo.

## M12 — Assets propios (Blender)  (34/39, 7 en revisión)

Rehacer en Blender todos los assets con un mismo estilo, empezando por el overworld, que hoy sigue con el kit gris.

**Hecho cuando:**
- El overworld no usa piezas del kit gris ni de KayKit.
- Templo, interactivos, ítems y personajes comparten la misma paleta y el mismo estilo.

### 12.1 Guía de estilo: paleta, escala y pieza de prueba · Hecho

**Prioridad:** alta · **Etiquetas:** `arte`

Fijar la guía de estilo de los assets propios antes de modelar: una textura de paleta única con los colores de [[gdd#arte]], la escala respecto al Knight y la grilla, y una pieza de prueba que importe bien en Godot y se recorte con el shader de la pared sur.

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

### 12.2 Terreno del overworld · Revisión

**Prioridad:** alta · **Responsable:** project-epiphany-25 · **Etiquetas:** `arte`

Modelar en Blender el terreno del overworld (pasto, caminos, piso de plaza, acantilados con sus aberturas, escalones, abismo, cercos y borde del mundo) y armar con eso el kit del GridMap, para reemplazar el kit gris sin perder colisiones ni navegación.

- [x] Pasto: base + 3–4 variantes
  Florcitas, piedritas, manchas de tierra.
- [x] Camino de tierra: recto, curva, T, cruce, final, borde con pasto
  Cubierto por tierra + tierra_borde/esquina/esquina_int (vary_overworld.gd elige pieza y giro por vecinos), más las variantes de la tierra.
- [x] Piso de piedra de la plaza: base + rota + musgo
- [x] Acantilado: recto, esquina ext/int, final, tope con pasto
  Cubierto por las celdas de andén y risco (cada celda tiene las cuatro caras y su tope de pasto), con Andén/Risco borde para el borde del mundo.
- [x] Aberturas en acantilado de 1 y 3 celdas
  Cubierto: las aberturas son celdas libres en la pared; las de 1 celda llevan cracked_wall_risco o reja.
- [x] Escalones y rampa (tierra y piedra)
  Escalón: muro de piedra con lajas encastradas arriba. Escalinata en estilo LA sin muros: bloques macizos de piedra redondeados hasta el piso, costado escalonado; el último escalón queda bajo el pasto (sin z-fighting). Las escenas escalinata_* sin choques de costado. No hace falta rampa.
- [x] Abismo: borde recto, esquinas, fondo oscuro/niebla
  Hecho: abismo, abismo_borde/esquina/pasillo/punta/pozo en build_terreno_overworld.py (paredes de roca de 3 m con bandas pasto → acantilado → gris → casi negro, fondo oscuro). vary_overworld.gd elige la pieza y el giro según los vecinos; test_abyss_walls_face_the_ground. La niebla del fondo queda para Godot si hace falta.
- [x] Cerco: recto, esquina, final, poste, roto
  Hecho: pirca, pirca_esquina, pirca_final (hasta el borde de la celda), pirca_poste y pirca_rota. vary_overworld.gd elige la pieza y el giro según dónde sigue la pirca; test_fence_ends_have_a_post.
- [x] Borde del mundo (árboles densos / acantilado alto)
  Hecho: meseta (monte, monte_ichu/piedras/flores + queñoas y cardones arriba) alrededor de la grilla, hasta donde ve la cámara; al sur solo baja. Sin colisión. +200 draw calls, mismo frame.
- [x] Kit del overworld para el GridMap
  Como build_temple_kit.gd: mismos ítems, colisiones y navegación que el kit gris, mallas nuevas.
- [x] Bordes de arriba estilizados
  La tapa de pasto de andenes, riscos y meseta es una caja plana: borde irregular que sobresale y cuelga, como el resto de los assets.
- [x] Viento en la vegetación
  Hecho: material epiphany_wind.tres (vertex shader) en ichu, flores, tola y queñoas; se mece más arriba en el degradé de la franja, onda en el sentido del viento.
- [x] Sombras de nubes
  Hecho: cloud_shadows.gdshaderinc (ruido en mundo, deriva) en los materiales de afuera; global cloud_shadows que prendía el nodo CloudShadows. 2026-10-16 (abd73bf4, arte -39, Daniel aprobó la fuerte): no se notaban (nubes de 13 m en una vista de 18 × 10 m, solo en el terreno, el player quedaba iluminado, y el multiplicador de albedo oscurecía también lo que ya estaba en sombra). Pasan a NubesLA (src/world/look/nubes_la.gd), un CompositorEffect entre sombra_la y tono_la: ruido en mundo desde la profundidad sobre toda la escena HDR, solo en lo iluminado (máscara de luminancia 0.04–0.2), tinte frío, fuerza 0.4, 9 m, bordes 0.4–0.62, deriva (0.5, 0.2) m/s; calibrado con las sombras de contacto y SSAO de 4.8. Se borró el sistema viejo. Nubes visibles o bruma: solo como efecto de zona (Cumbre, Quebrada), si se piden. Pendiente si Daniel lo quiere: apagarlas en los zooms de revelación.
- [x] Cara del risco y topes con detalle
  Hecho: risco en seis estratos que salen y entran (topes risco, risco_ichu, risco_flores por hash; viento en wind.gdshaderinc). 2026-10-13 (0867d75a, arte -11): las caras de risco del terreno orgánico pasan a bloques redondeados como en LA (ladrillos metidos abajo, bloques grandes, labio claro arriba; tapa de pasto sin puntas). Pircas igual (492ba44d): piedras grandes y tapa clara. Look LA (tono_la + sombra_la, Linear) en overworld.tscn (678bd9fa). Tope de Acantilado y Andén borde 960 (1dd0f4fb).
- [x] Camino con detalle
  Hecho: tierra_manchas, tierra_guijarros, tierra_huellas (pisadas de llama) y tierra_pasto (matitas que se mecen); vary_overworld.gd las reparte en la tierra junto con tierra_piedras (54 % de las celdas con algo).
- [x] Niebla en el abismo
  Hecho: dos capas (abyss_mist.gdshader, ruido que se corre) como segunda superficie de las celdas de abismo del kit; más espesa abajo.
- [x] Hojas que caen
  Hecho: falling_leaves.tscn (GPUParticles3D, 4 hojas que giran y el viento corre) bajo la copa de cada árbol jugable (Árbol, Queñoa chica); las pone decorate_levels.gd en Decor/Hojas.
- [x] Polvo en el aire
  Hecho: dust_motes.tscn (GPUParticles3D, 40 motas aditivas que flotan) colgado de TopDownCamera en overworld.tscn, delante de la cámara a la altura del player.

**Prueba:** Capturas antes/después desde la cámara del juego en 12 zonas, con nubes congeladas y en pausa: solo difieren el viento del pasto, un enemigo que camina y un corrimiento de 1 px de la cámara en una zona (el primer intento perdía el lecho del río y dejaba líneas finas sobre el agua; arreglado). Suite 773/773 en main después de --import, test_map y test_player_hole incluidos (a3925d15).

**Notas:** 2026-10-21: Daniel pidió retomar el pendiente del playtest (sacar las mallas que el player nunca ve, como el piso del terreno apilado donde no se puede llegar). Hecho por -25 (wt/art 50395f49 → main a3925d15):
- build_terreno_organico.py saca de la malla visual toda cara que la cámara no puede ver nunca. Prueba por vértice: el player parado en cada celda caminable, con la cámara que sigue y la cenital, raycast contra el terreno. Las caras con un borde de más de 1 m se muestrean también por dentro (si no, desaparecía el lecho del río, que tiene las esquinas bajo el pasto y el medio visible a través del agua).
- La colisión se arma del bloque entero: hash de la geometría de colisión idéntico antes y después. El layout no cambia; decorate_levels sin diff; SEAM_OFFSET igual.
- Caras visuales 2,64 M → 2,03 M (−23 %). Triángulos en cuadro por zona (escritorio, cuadro en pausa) −1 a −12 %; casos del benchmark: inicio −2,7 %, arboleda −1,6 %, cardonal −1 %, bañado −9 %, cumbre −11 %. Draws casi igual.
- El build del terreno ahora tarda ~29 min (antes unos pocos).

**Referencias:** `gdd.md#overworld-layout`

**Capturas:** `compass/images/m12-02-20261017-033438.png`, `compass/images/m12-02-20261017-033541.png`

**Bloquea a:** 12.3 Lugares del overworld

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.4 Decorar el overworld

### 12.3 Lugares del overworld · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `arte`, `puzzles`

Modelar las piezas propias de cada lugar del overworld (claro del inicio, cuevas, santuario, puzzle de luz, entrada y sello del templo, risco del ojo), para que cada zona de [[gdd#overworld-layout]] se reconozca por cómo se ve.

- [x] Hito del claro del inicio
  Piedra tallada, fogata o similar.
- [x] Kit de cueva: boca, piso y pared de roca, estalagmitas
  Para la cueva de las bombas y la gruta oculta.
- [x] Muro agrietado de exterior + escombros
  Ladrillo gris con musgo, que no se confunda con el acantilado. cracked_wall.tscn.
- [x] Kit de santuario: piso, paredes, columnas, pedestal
- [x] Puzzle de luz: fuente, espejo fijo 45°, cristal receptor
  src/world/light/.
- [x] Reja, bloque empujable e interruptor de piso de exterior
  gate.tscn, push_block.tscn, floor_switch.tscn.
- [x] Entrada del templo: fachada, escalinata, columnas
  La pieza más importante del overworld.
- [x] Sello violeta con el ojo
  temple_seal.tscn.
- [x] Risco del ojo: cornisa, ojo-interruptor, puente, nicho del carcaj
  Hecho: ojo (ojo_pilar/ojo_globo) y puente ya propios; nuevos cornisa_ojo (estrado de lajas con borde escalonado y mojones bajo el pilar), nicho_carcaj (lajas del nicho) y estela_carcaj (flecha dorada en relieve detrás del cofre). Los pone decorate_levels.gd (props de Zone_risco, pegados a CliffEye y QuiverChest).
- [x] Portal de salida del jefe: disco y anillo
  warp_portal.tscn. Opcional.

**Prueba:** Cada zona de [[gdd#overworld-layout]] tiene sus piezas propias y se reconoce sin el nombre de zona.

**Referencias:** `gdd.md#overworld-layout`

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba; 12.2 Terreno del overworld

**Relacionadas:** 11.4 Decorar el overworld

### 12.4 Vegetación y props del overworld · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `arte`

Modelar la vegetación y los props del overworld (árboles, pasto cortable, vasijas, rocas y cajas físicas, tablillas, decoración) con el estilo propio, para que reemplacen los de KayKit sin cambiar cómo se rompen o se mueven.

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
- [x] Decoración: arbustos, flores, hongos, tronco caído, tocón
  Hecho: tronco caído, cardón chico, ichu, piedras (11.4) y ahora tocón de queñoa, yareta (cojín verde de la puna, en vez de arbustos), macizo de flores y hongos, repartidos por decorate_levels.gd.
- [x] Fondo: nubes y colinas lejanas
  Cubierto sin KayKit: la cámara cenital no ve el horizonte; el fondo es la meseta del borde del mundo (12.2 paso 9) y las nubes pasan como sombras (12.2 paso 13).

**Prueba:** Pasto, vasijas, rocas y cajas usan los modelos nuevos y se rompen o mueven como antes.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.4 Decorar el overworld

### 12.5 Interactivos y pickups · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Etiquetas:** `arte`

Modelar cofres, pickups, bomba, flecha, orbe, llaves, mapa, brújula y contenedor de corazón con el estilo propio, y regenerar desde esos modelos los íconos que hoy son SVG planos.

- [x] Cofre chico de madera (tapa aparte)
- [x] Cofre grande dorado (tapa aparte)
- [x] Pickups: corazón, flechas ×5, bombas ×3
  Hecho: Pickup muestra ItemData.pickup_mesh (flechas_x5, bombas_x3) o heart_mesh (corazon) girando en vez del ícono; sin malla sigue el Sprite3D (pieza de corazón). test_pickup_models.
- [x] Bomba con mecha y flecha
- [x] Orbe (proyectil reflejable)
  Hecho: projectile.tscn usa orbe.res con epiphany_glow.tres (paleta sin sombreado, núcleo doom saturado, púas de sello).
- [x] Llave chica, llave del jefe
- [x] Mapa, brújula, contenedor de corazón
  Hoy son SVG planos; con modelo, todos los íconos salen de render_item_icons.gd.

**Prueba:** Cofres, pickups, bomba, flecha y orbe usan los modelos nuevos; los íconos se regeneran con render_item_icons.gd.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

### 12.6 Equipo y objetos del inventario · Hecho

**Prioridad:** media · **Etiquetas:** `arte`

Modelar el equipo y los objetos del inventario (espada, escudos, cota reforzada, arco y carcaj, bolsa de bombas, botella) con el estilo propio, para que se vean en la mano, en la preview de Equipo y en los íconos.

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

### 12.7 Kit del templo propio · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Etiquetas:** `arte`, `mazmorra`

Armar el kit propio del templo (piso, paredes, puertas por tipo, piezas de puzzle, torreta, antorchas, decoración, doom y sala del jefe) para que `temple_kit.tres` deje de usar piezas KayKit, sin romper el corte de la pared sur.

- [x] Piso + variantes (roto, yuyos, grieta del doom)
- [x] Pared a celda 2×2: recta, esquina, final, con antorcha
  Hecho: la pared es un cubo de piedra encastrada con banda arriba, así que recta, esquina y final salen de la misma pieza; la antorcha es wall_torch.tscn. vary_temple.gd reparte pared_nicho y pared_ojo en las paredes que miran a la cámara, lejos de lo que ya cuelga.
- [x] Columna y escalón
- [x] Abismo interior con borde
  Hecho: hueco y hueco_borde/esquina/pasillo/punta/pozo en build_templo.py (hiladas de piedra del templo de 3 m que se oscurecen, borde claro). tools/vary_temple.gd elige pieza y giro por vecinos (tools/grid_pieces.gd, compartido con vary_overworld); test_pit_walls_face_the_ground.
- [x] Pasos de puerta + puertas por tipo
  Normal, con cerradura, persiana, de interruptor y del jefe (grande, con el ojo). door.tscn.
- [x] Piezas de puzzle versión templo
  Muro agrietado, reja, bloque, interruptor, ojo-interruptor, cristal, espejo, fuente de luz.
- [x] Torreta / ojo menor
  src/entities/turret/.
- [x] Antorcha de pared y brasero
  wall_torch.tscn.
- [x] Decoración: estandartes, escombros, vasijas, tablilla, ojo tallado
- [x] Doom: grietas, venas rojas, polvo
- [x] Sala del jefe: piso de arena y pilares

**Prueba:** temple_kit.tres arma el templo con las piezas nuevas y el corte de la pared sur sigue andando.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.3 Decorar las salas del templo

### 12.8 Personajes propios · Hecho

**Prioridad:** baja · **Etiquetas:** `arte`, `personajes`

Modelar los personajes propios (player, esqueletos y jefe) con los mismos nombres de huesos que el `Rig_Medium` de KayKit, para que usen las animaciones de `player/animation/libs/` sin retarget.

- [x] Player
  Mismos nombres de huesos que el Rig_Medium de KayKit, para no perder las animaciones.
- [x] Esqueleto
- [x] Esqueleto con escudo
- [x] Jefe: ojo + dos manos animadas
  Hecho en 11.47: ojo + una malla por mano con shape keys de curvado (sin rig de huesos).

**Prueba:** Los modelos nuevos usan las animaciones de player/animation/libs/ sin retarget.

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.47 Manos del jefe animadas (shape keys); 12.13 Reajuste de estilo toon de todos los assets

### 12.9 Efectos con malla · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Etiquetas:** `arte`

Hacer con malla los efectos que lo piden (haz de luz, polvo y hojas, explosión, anillo del portal), con la paleta y el estilo de los assets propios.

- [x] Haz de luz
  Hecho: halo aditivo (light_glow.gdshader como material_overlay de cada tramo y de la punta): infla el tubo en metros de mundo, brilla al centro, se apaga en el borde y titila leve; toma el color del haz.
- [x] Polvo y hojas
  Hecho en 12.2 con partículas: falling_leaves.tscn bajo los árboles y dust_motes.tscn colgado de la cámara.
- [x] Explosión
  Hecho: objetos/explosion (núcleo facetado y 14 puntas, claro adentro y naranja en las puntas) en explosion.tscn con epiphany_fx.tres (paleta transparente sin sombreado); gira al azar cada vez.
- [x] Anillo del portal
  Ya estaba: warp_portal.tscn usa portal_disco y portal_anillo (12.3 paso 10).

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.49 VFX de combate; 12.13 Reajuste de estilo toon de todos los assets

### 12.10 Pipeline Blender→Godot: glb publicado + plugin de import · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** alta · **Etiquetas:** `arte`, `herramientas`

Cambiar el pipeline Blender→Godot a publicar `.glb` con un plugin de import que asigne el material de paleta y convierta custom properties en colisiones, sockets y spring bones, para que Godot importe solo el `.glb` y los builds no necesiten Blender.

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

### 12.11 Migrar los .blend al pipeline glb · Hecho

**Terminada:** 2026-10-11 · **Prioridad:** media · **Etiquetas:** `arte`, `herramientas`

Pasar todos los `.blend` (props, equipo, templo, kits y personajes) al pipeline glb de 12.10 y retirar los scripts headless viejos, para que los builds funcionen sin Blender.

- [x] Props y equipo (objetos, equipo, naturaleza, lugares)
  El jefe ya pasó al pipeline en 11.47.
- [x] Templo y kits (build_temple_kit / build_overworld_kit)
- [x] Personajes (jugador, chullpas) y carry
  El carry ya era glb (build_carry_anims.py exporta anim/carry.glb). build_character_models.gd queda: corre en Godot sin Blender y lee el glb.
- [x] Retirar scripts headless viejos y verificar builds sin Blender

**Notas:** Después de validar 12.10: pasar objetos, equipo, lugares, templo, naturaleza, jefe, terreno y personajes a glb; retirar extract_epiphany_meshes y build_character_models; los kits leen del glb.

**Bloqueada por:** 12.10 Pipeline Blender→Godot: glb publicado + plugin de import

**Relacionadas:** 11.47 Manos del jefe animadas (shape keys)

### 12.12 Estilo toon (Wind Waker) + personaje cyber-shinobi · Pausado

**Prioridad:** media · **Etiquetas:** `arte`, `personajes`

Probar un look tipo Wind Waker con cel shading: shader toon en Godot y un personaje cyber-shinobi armado en Blender y publicado por el pipeline glb, para comparar en el templo contra el jugador actual y decidir el rumbo de estilo.

- [x] Prueba de estilo en Blender (estilo_toon.py)
  Hecha: renders en docs/estilo/. El blockout de piezas epi se descartó (se veía cuadrado/viejo; suavizarlo lo volvía un globo).
- [x] Shader cel en Godot
  Hecho: src/shaders/toon/toon.gdshaderinc (light() de 2 tonos: corte por ángulo y por sombra proyectada, energías de luz y sombra, rim opcional; luces puntuales/spot suman sin corte para no umbralizar antorchas ni cáusticas) + toon_palette.gdshader y epiphany_toon.tres. La sombra es el color por la relación oscuro/claro de su tira de paleta (sombras de color). Falta incluirlo en cutaway y epiphany_wall y aplicarlo al personaje (12.13 paso 1).
- [x] Personaje al pipeline glb
  Hecho: tools/blender/build_shinobi.py (era estilo_toon.py) pinta con UVs de la paleta, une todo en una malla, pesos automáticos del cuerpo, huesos spring en cintas de los rodetes y colas de la faja, sockets SableSocket/PistolaSocket, y publica assets/epiphany/personaje_shinobi.glb. Escena de prueba: levels/test_shinobi.tscn (←/→ animación, ↑/↓ girar, 4 toon). ~23k tris (ver paso 7). Pendiente: springs en mechones laterales; colgarlo del jugador cuando termine 13.1.
- [ ] Cara como textura con expresiones
  Pasar las calcomanías a una textura de cara (o atlas) para cambiar expresión y parpadear, como Wind Waker.
- [ ] Sable de energía y pistola
  Empuñadura + hoja emisiva con trail; pistola simple.
- [ ] Paleta alternativa cyber + emisión
- [ ] Revisar polígonos
  Contar tris del personaje (co-op: hasta 4 en pantalla) y bajar subdivisión o resolución de curvas si hace falta.
- [ ] Render A/B en el templo
  El personaje toon con el shader en el templo actual, contra el jugador de ahora.
- [ ] Jugador estilo ZX (en pausa)
  Intento del 2026-10-11, sin aprobar: tools/blender/build_jugador.py arma el diseño del jugador actual (casco con chakana, discos, aletas, trenza, peto, hombreras, brazales, cinturón con faldones, botas con suela de neón) con la estética de los modelos ZX de referencia (temp/, solo referencia, no se usan): 1,55 m y ~4,5 cabezas medidas, cara calibrada al perfil de referencia, casco desplazado desde la cabeza, traje continuo por skin modifier, textura propia assets/epiphany/jugador_colores.png. Feedback: 'es un avance pero sigue sin gustarme' (antes: cara rara, casco de karting, piernas sueltas, botas de lego, ya corregidos). Pendiente: manos, hombreras y peto menos cuadrados, ~24k tris, rig humanoide y animaciones. Comparar con: blender -b -P build_jugador.py -- <salida.blend>.

**Notas:** Rumbo elegido 2026-10-10: look tipo Wind Waker HD con cel shading (no low-poly de piezas ni anime realista). Proporciones chibi, así que sirve el Rig_Medium y las animaciones de KayKit. Prueba en tools/blender/estilo_toon.py, ahora build_shinobi.py (renders de referencia en docs/estilo/): cuerpo continuo con Skin modifier + subdivisión y pesos automáticos; pelo en mechones de curvas NURBS afinadas con rulo; cara de calcomanías proyectadas (ojo, iris, pupila, brillo, párpado, cejas, rubor, boca); mangas y pollera con pliegues senoidales; cel shading de 2 tonos con sombra de color. Las tiras de la paleta ya tienen tono claro y oscuro: sirven como lit/shade del shader. El setting andino tampoco es definitivo (cyber-shinobi estilo Megaman Zero: sables de energía y pistolas). Diseño: pelo negro con rulos y rodetes con kunais, ojos rojos, capucha y mangas anchas con ribete emisivo, faja roja tipo obi, delantal crema, pollera, medias con liga roja, botas.
Después (8cfecf85): los restyles toon se descartaron y el player del juego volvió al modelo anterior; el shinobi queda guardado para más adelante y el setting sigue sin decidir. El co-op está en pausa (el presupuesto de "hasta 4 en pantalla" del paso 7 no apura). En pausa.

**Bloquea a:** 12.13 Reajuste de estilo toon de todos los assets

**Relacionadas:** 12.10 Pipeline Blender→Godot: glb publicado + plugin de import

### 12.13 Reajuste de estilo toon de todos los assets · Pausado

**Prioridad:** media · **Etiquetas:** `arte`

Con el estilo toon de 12.12, aplicar el shader cel a todo el material de paleta, recorrer el mundo y ajustar paleta, vegetación, terreno, templo, personajes, objetos y efectos para que todo conviva con el personaje nuevo.

- [ ] Aplicar el shader cel de 12.12 a todo el material de paleta y recorrer el mundo
  Herramienta: tools/toon_preview.gd (capturas base/toon en el jugador y cada Spawn* del overworld y el templo). Primera recorrida 2026-10-10: con el shader el mundo ya lee toon (follaje en dos tonos, sombras de color más suaves). Falta: pasar epiphany.tres al toon e incluir toon.gdshaderinc en cutaway y epiphany_wall (avisar a la otra sesión: cambia el look de todo), afinar energías por nivel y la lista de qué remodelar.
- [ ] Ajustar la paleta para sombras de color
  Las tiras ya tienen tono claro y oscuro: llevar el oscuro a sombras saturadas y frías tipo WW, no grises.
- [ ] Vegetación
  Copas en masas redondeadas y blandas, pasto y matas (12.4).
- [ ] Terreno y lugares
  Suavizar bordes y siluetas donde lo pida el shader (12.2, 12.3).
- [ ] Templo y restos de KayKit
  Terminar el kit propio (12.7) y sacar las piezas KayKit dungeon que queden.
- [ ] Personajes: jugador, chullpas y jefe
  Acá va el restyle de personajes (12.8 queda cerrada con los modelos actuales); depende de lo que se decida en 12.12.
- [ ] Objetos, equipo e íconos
  Remodelar lo que haga falta y re-renderizar los íconos del inventario (tools/render_item_icons.gd, 11.15).
- [ ] Pasar al toon los efectos de 12.9 y 11.49
  Humo en espirales, líneas de viento, explosiones cartoon, golpes (con 12.9 y 11.49).

**Notas:** Con el estilo Wind Waker elegido (12.12), todo el juego tiene que convivir con el personaje nuevo. Primero se mide cuánto resuelve el shader: todas las piezas epi comparten el material de paleta (data/kits/materials/epiphany.tres), así que el cel shading se prueba en el mundo entero de una vez. Recién ahí se decide qué hay que remodelar. Lo que siga siendo KayKit va a desentonar más.
En pausa: depende del rumbo toon de 12.12, que se descartó (8cfecf85).

**Bloqueada por:** 12.12 Estilo toon (Wind Waker) + personaje cyber-shinobi

**Relacionadas:** 11.20 Cueva con ojo de agua y cáusticas animadas; 12.9 Efectos con malla; 11.49 VFX de combate; 12.8 Personajes propios

### 12.14 Prueba: overworld menos cuadrado · Hecho

**Terminada:** 2026-10-11

Probar en una misma zona chica de prueba tres formas de que el overworld no se vea cuadriculado, y combinaciones, para elegir mirando: A) grilla con diagonales, curvas y niveles de altura (rampas/escalinatas); B) grilla abajo con mallas modeladas que tapan los bordes rectos; C) terreno esculpido libre sin grilla.

- [x] Zona de prueba común (mismo diseño para todas)
- [x] A: diagonales, curvas y niveles
- [x] B: grilla + mallas modeladas encima
- [x] C: terreno esculpido libre
- [x] Combinaciones (A+B, ...)
- [x] Capturas lado a lado y elección del usuario
  Página: https://claude.ai/artifact/DeQ6YbE2gQqyQwRMFux2KH. Escena: levels/pruebas_terreno.tscn (1–9). Elegida la 6 (B+C · Orgánico con lomas) para el MVP; la 9 (marching cubes en Godot) gustó más pero le faltan correcciones: queda en 12.16 para después del MVP.

**Notas:** Pedido del usuario después de 12.2 paso 6 (rampa): elegir con pruebas antes de cambiar el overworld real. No tocar levels/overworld.tscn hasta elegir.

**Bloquea a:** 11.61 Pluma en el overworld: lugares de salto

### 12.15 Overworld orgánico con lomas (variante 6) · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Etiquetas:** `arte`

Pasar el overworld real al estilo de la variante 6 de 12.14: bordes de andenes, riscos, abismo y camino con contornos orgánicos (no siguen la grilla) y el pasto con lomas suaves, sin perder colisiones, navegación ni los lugares de 12.3.

- [x] Generador desde el GridMap
  tools/export_terreno_overworld.gd → tools/terreno_overworld.json → tools/blender/build_terreno_organico.py → assets/epiphany/terreno_organico.glb (rocas, suelo con colisión, plantas juntadas por pedazo).
- [x] Vista previa aprobada por el usuario
  Fila ★ en https://claude.ai/artifact/DeQ6YbE2gQqyQwRMFux2KH.
- [x] Meterlo en el overworld
  Celdas de terreno vacías (mallas vacías, sin colisión), piezas que quedan sin su piso, terreno en navmesh_source y re-bake, terreno en scenery del mapa.
- [x] Decoración sobre el terreno
  decorate_levels.gd lee las paredes de overworld_kit.tres (mismos ids); la decoración sale igual y el piso es plano alrededor.
- [x] Tests del overworld al día
  Al día (ede155e de la otra sesión): test_player_hole mira los materiales de Terreno, test_abyss_walls_face_the_ground nuevo. Suite completa pasa.

**Bloquea a:** 11.61 Pluma en el overworld: lugares de salto

### 12.16 Terreno con marching cubes en Godot (después del MVP) · Pendiente

**Prioridad:** baja · **Etiquetas:** `arte`, `herramientas`

La variante 9 de 12.14 (volumen + marching cubes armado en Godot con tools/build_prueba_mc.gd y data/kits/shaders/terreno_mc.gdshader) gustó más que la 6, pero le faltan un par de correcciones. Retomarla cuando termine el MVP.

- [ ] Preguntar al usuario qué corregir de la 9

### 12.17 Estilos por mazmorra · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Etiquetas:** `arte`, `mazmorra`

Cada mazmorra con su propio estilo sobre el mismo kit (mismas piezas y colisiones): piedra, muro, remate, piso, columnas y relieve. D1 Templo (piedra lavanda, chakana, ojos), D2 Chullpa (piedra de campo con barro, cornisa, nichos con cráneos, tierra apisonada), D3 Laguna (bloques grises con musgo, ondas, charcos), D4 Cumbre (basalto, nieve y carámbanos, soles de oro, escarcha). tools/blender/build_templo.py -- <estilo> publica templo_<estilo>.glb.

- [x] Prueba: la misma sala en los cuatro estilos
  diorama.py -- <png> templo templo_<estilo>.
- [x] Elección y ajustes del usuario
  Aprobados los cuatro estilos el 2026-10-11. El usuario pide lo mismo para la zona del overworld de cada mazmorra (consultado con la otra sesión, dueña de 7.9).
- [x] Kit de cada mazmorra en Godot
  build_temple_kit.gd -- <estilo> arma chullpa_kit, laguna_kit y cumbre_kit (mismos ítems y colisiones que temple_kit). levels/chullpa.tscn usa chullpa_kit. Laguna y Cumbre todavía no tienen escena.
- [x] Luz y ambiente por mazmorra
  Hecho el 2026-10-13 (d5384189), arte -11: LOOKS en la_walls.gd (ambiente, luz del lado de la cámara, foco de sala y polvo), se aplica en bake y en cada refresh. Chullpa cálida y polvorienta (polvo_chullpa.tscn), Queñoa fría y húmeda (polvo_quenoa.tscn). Las escenas de polvo se ajustan a ojo en el editor; los colores, en LOOKS.
- [x] Props por estilo
  Hecho el 2026-10-13, arte -11. Queñoa: brasero_quenoa (muñón de tronco colgado de la pared) y vasijas mate burilado (pot_quenoa.tscn) en 70d206ae; puertas de tablones atados con soga y musgo (ccee04af). Chullpa: brasero de piedra y aríbalo de antes, puertas de losas de piedra con escalonado y cobre (ccee04af). Todo lo pone la_walls LOOKS en cada refresh, menos las vasijas (por escena). Estandartes: el modelo existe en cada kit de estilo pero no hay ninguno puesto; ponerlos es de diseño.
- [x] Estilo del terreno del overworld por región
  AreaZone.terrain_style (necropolis, laguna, cumbre, explanada, cardonal, quebrada); el build pinta suelo, riscos y abismo por región con borde ondulado y cambia la decoración. Puestos en overworld.tscn: Templo explanada, Quebrada, Necrópolis + Mirador, Cumbre + Risco, Laguna + Bañado, Cardonal. Falta que el usuario lo vea.
- [x] Paredes y piso propios de cada mazmorra
  Hecho el 2026-10-13 (6552966a), arte -11, pedido de Daniel. Chullpa: pirca de piedra de campo con juntas de barro, cornisa de barro con ichu, piso de tierra apisonada con losas sueltas. Queñoa: madera del tronco por dentro (vetas y nudos), musgo y hojas arriba, piso de tablones. Cada una con su kit (chullpa_la_kit / quenoa_la_kit). Los números del piso y la veta están en LOOKS de la_walls.gd para ajustarlos a ojo. Entradas del overworld vestidas en 472ad964.

### 12.40 Estilo Link's Awakening en las mazmorras reales: cámara y assets nuevos · En curso

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `arte`, `mazmorra`, `camara`

Daniel (2026-10-13): la Chullpa real tiene la cámara vieja; el test LA (debug/la/chullpa_la.tscn) ya tiene la cámara de Link's Awakening, paredes, puertas y props nuevos. Llevar eso a las mazmorras jugables cuando la sesión de arte tenga los assets nuevos. El juego no cambia: no se mueven nodos de juego (puertas, placas, cofres, peleas, huecos, escaleras).

- [x] Chullpa: cámara LA y kit nuevo
  Hecho el 2026-10-13 (15b5a3e8, antes e8966e9b mueve el look a src/world/look). tools/la_walls.gd -- bake duplica las paredes entre salas en levels/chullpa.tscn (cada sala con la suya; marcadores, escaleras y portal se corren con su sala), pone las paredes LA, la cámara LA, luz por sala, piso, brillo y fuego; -- refresh vuelve a elegir piezas después de editar. El mapa lee los pasos LA. Navmesh rehecho; test_chullpa, test_dungeon_reach y test_map pasan.
- [x] Queñoa: kit de árbol en estilo LA
  Hecho el 2026-10-13: bake con nueve formas nuevas (bf4d88b3); paredes bajas de 1,3 m con borde de hojas en nichos y reja del tronco (3b3aaa33, 11.113 paso 8); cofres en nicho mirando a la entrada y reja del tronco en la boca de la escalera (6566b7d6). El kit guarda los números de pieza al agregar formas. Navmesh rehecho; test_quenoa pasa.
- [x] Templo del ojo en estilo LA
  Hecho el 2026-10-13 (d5df3c44), después del rediseño de diseño (-43). Estilo propio: sillares lavanda en hiladas con cornisa dorada, crestas de piedra clara, puertas de losa con metal dorado, piso de lajas frías (templo_la_kit) y luz violeta tenue. El bake separa las salas por las paredes dobles: SpawnStart pasa a (44, 0, 52), test_portal lo sigue. test_templo, test_walk_doors, test_dungeon_reach, test_drop_holes, test_portal, test_overworld_run, test_temple_seal y test_coop_camera pasan.
- [x] Puertas LA al ras de la pared
  Hecho el 2026-10-13 con Daniel en el recorrido (una puerta con llave parecía abierta). Puerta cerrada llena el paso, una hoja en cada cara (f25bdf02); hojas de madera de 3 m con bandas de hierro, cerradura, ojo de jefe/interruptor y persiana, inclinadas como su pared, bajan 3,2 m al abrir (3d08a58d). door.gd gana leaf_meshes y sink. El velo oscuro de los pasos ya no tapa al player (stencil).
- [x] Bloque empujable y placa en estilo LA
  Hecho el 2026-10-13 (d3f537ad; Daniel: el azul se veía raro). Piedra cálida con chakana; placa de madera con ojo dorado en marco de piedra. Mismos tamaños y colisión.
- [x] Look final: el actual sin viñeta (reemplazado por 12.32)
  Hecho el 2026-10-13 (9db90fc3). Comparado con Daniel contra la curva real de LA (RenderDoc) y un intermedio; eligió el actual sin viñeta. La marca de bake pasa a BrilloLA. Después 12.32 trajo la viñeta borrosa, ajustable por nivel y por sala.
- [ ] Recorrerlas (Daniel)
  En curso con Daniel: lo que salga del recorrido (paredes, puertas, props) lo arregla la sesión de arte con la-walls refresh; diseño (-43) hace el jefe de la Chullpa en B-NE y avisa antes si necesita tocar paredes.

**Notas:** Sesión: arte (-11). Diseño (-43) revisa que el juego no cambie.

**Relacionadas:** 12.30 Templo: salas que se vean bien para grabar

### 12.41 Totora (D3) en estilo Link's Awakening y su entrada · Revisión

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `arte`, `mazmorra`

Diseño (-43) armó levels/totora.tscn en el kit gris (a8d40e91, GDD §8d): dos pisos de 3×2 salas de 7×5 celdas, agua profunda (celdas vacías con Pit y agua water_la a -0.35). Estilo propio de agua y totora, como Chullpa, Queñoa y templo. Regla de juego: cada cruce del gancho son 4 celdas de agua con el HookPost 0.5 m pasada la orilla; test_totora es relativo a la sala. Overworld (-eb, 5e04f395): TotoraHut es un CSGBox3D provisorio en la isla de la Laguna; vestirlo de santuario de juncos sin mover TotoraDoor, avisando a -eb antes de tocar overworld.tscn.

- [x] Estilo de la Totora: paredes, piso, puertas y luz (LOOKS en la_walls)
  Hecho el 2026-10-13 (41357968, wt/art). build_paredes_la: estilo totora (atados apilados amarrados con soga, musgo húmedo al pie, juncos y totoras en flor arriba; puertas de atados parados con soga oscura). LOOKS totora: luz fresca de lago, piso de estera de totora (totora_la_kit).
- [x] Bake y refresh de levels/totora.tscn, con los cruces del gancho intactos
  Hecho el 2026-10-13 (41357968). Sin separar las salas: la pared de 2 m que comparten sale entera con cara a cada lado, así los cruces del gancho siguen de 4 celdas y test_totora no cambia. El agua honda cuenta como piso (LOOKS water). Las puertas en pared fina tienen paso de 2 m (también el templo). test_totora, test_amaru, test_walk_doors, test_dungeon_reach, test_hookshot y otros pasan.
- [x] Santuario de totora en la isla (TotoraHut)
  Modelo hecho (41357968): src/world/totora_entrada.tscn, choza de los uros sobre balsa, techo con borla roja, columnas con cabeza de puma, aguayo y totoras; mismo colisionador que TotoraHut. Puesta en el overworld (d171669b).
- [ ] Recorrerla (Daniel)
- [x] Paredes dobles entre salas, como Chullpa, Queñoa y Cumbre (playtest)
  Playtest 2026-10-19: las puertas sobresalían y se veía la pared de la sala siguiente, y la pared quebrable no tenía pieza. Arreglado en 9b628eb7: la_walls spread (modo nuevo para niveles ya hechos) + refresh; puertas de 4 m y pared quebrable de pared doble. El cruce Gancho↔Balsas quedaba a 11 m (alcance 10): muelle de una celda bajo GanchoPost. Revisado por diseño (-72). El canal negro visto desde Gancho es de la cámara: 11.219.

**Capturas:** `compass/images/m12-19-20261013-232857.png`, `compass/images/m12-19-20261013-233009.png`, `compass/images/m12-19-20261013-233439.png`

**Relacionadas:** 11.167 Totora: caer al agua y perder deja al player cayendo al vacío antes de "You Fell"

### 12.20 Arte de la pantalla de título: logo y fondo del overworld · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** media · **Tamaño:** M · **Etiquetas:** `arte`, `ui`

La pantalla de título (src/ui/title/title_screen.tscn) sigue con arte provisorio: Background es un ColorRect, el título es un Label y hay un ojo dibujado por código (title_eye.gd). Idea de Daniel: un logo propio y, de fondo, un paneo lento del overworld, desenfocado, detrás del menú.

- [x] Logo: wordmark de Epiphany con el motivo del ojo; exportar en PNG con alfa (y versión clara/oscura si hace falta)
- [x] Fondo: paneo lento del overworld con una cámara sobre un recorrido (Path3D), en un SubViewport desenfocado detrás del menú. Medir la carga: si cargar el overworld entero demora el título, usar una versión liviana o un video pregrabado
  Primero como video pregrabado (flyover.ogv, 88 s). Daniel (2026-10-14) pidió el overworld en vivo: TitleFlyover (src/ui/title/title_flyover.tscn/.gd, b719c800) lo carga en un hilo sin Player, HUD ni TopDownCamera, en un SubViewport a media resolución bajo title_blur, y recorre las tomas de Shots (vista general intercalada con templo, laguna, Queñoa, Chullpa y Cumbre). Al arrancar tapa el título la pantalla de carga de SceneFlow hasta que está listo (~0,8 s de carga y ~3,6 s del _ready del overworld). Sigue corriendo mientras otras pantallas tapan el título. flyover.ogv se borró.
- [x] Integrar en title_screen.tscn (nodos en la escena, no por código) y decidir si el ojo de title_eye.gd queda o lo reemplaza el logo
- [x] Actualizar el mockup de la pantalla de título en el canvas de diseño

### 12.21 Ojo interruptor: la pupila sigue al player y se parece al ojo del jefe final · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `arte`, `detalle`

El ojo de los interruptores de flecha (src/world/eye_switch.tscn: ojo_pilar + ojo_globo, p. ej. CliffEye, RavineEye, los ojos de la Necrópolis) tiene la pupila fija. La pupila tiene que seguir al player más cercano (girar el globo o mover la pupila, con límite de ángulo) y el ojo tiene que parecerse más al del jefe final (El Ojo con manos, src/entities/boss): iris, color y brillo.

- [x] Rediseñar ojo_globo con la forma del ojo del jefe final (iris, pupila separada, brillo)
- [x] La pupila mira al player más cercano en eye_switch.gd, suave y con límite de ángulo; quieta cuando el ojo está apagado o ya resuelto
- [ ] Probar que siga funcionando como blanco de flecha (test_secrets, test_overworld)

**Relacionadas:** 12.23 Ojos de la Queñoa y Ojo Vigía: modelo propio parecido al ojo del jefe final, más simple

### 12.22 Splash con el logo y la paleta del theme · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** baja · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `arte`, `ui`

Daniel aprobó el logo de 12.20 y lo quiere también en el splash. El boot splash de Godot pasa a mostrar assets/ui/logo/epiphany_splash.png (el logo a 600 px, sin estirar) sobre el mismo fondo oscuro de la pantalla de título (Color(0.043, 0.051, 0.063)), así el paso del splash al título no se nota.

### 12.23 Ojos de la Queñoa y Ojo Vigía: modelo propio parecido al ojo del jefe final, más simple · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`

Playtest 2026-10-13: el jefe de la Queñoa (Eyes of the Queñoa) y el sub-jefe (Ojo Vigía) hoy son esferas lisas marrones (WatcherEye, placeholder). Deberían parecerse al ojo del jefe final pero más simples (párpado, iris/pupila, venas o raíces de la corteza). Ver también 12.21 (ojo interruptor).

**Capturas:** `compass/images/m12-23-20261013-230533.png`

**Relacionadas:** 12.21 Ojo interruptor: la pupila sigue al player y se parece al ojo del jefe final

### 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`

Pedido de -43 (playtest 2026-10-13): las paredes agrietadas de las mazmorras LA usan cracked_wall_templo y no encajan (sobresalen, cara de arriba negra, o no se ven). Hace falta un tapón que llene el paso LA: alto y ancho como el corte, inclinado como la pared, con la veta de su pared y grietas en las dos caras. la_walls lo coloca como las hojas de puerta. Estilos: chullpa, quenoa, totora, cumbre. Cuando estén las mallas, -43 cambia las instancias y revisa la colisión. -11 (-5d) elige el orden con Daniel frente a 12.23 y 11.138.

**Relacionadas:** 11.141 Queñoa 2P (Canopy): símbolo azul sin sentido y puerta bloqueada invisible; 11.137 Chullpa: techos visibles, pared agrietada que no encaja y sala secreta a la vista; 11.151 Totora 2P: se ve la sala del piso de abajo; 11.164 Lo que esconde una pared agrietada no se ve desde arriba; 12.29 Muro agrietado LA de cueva (muro_agrietado_cueva_la)

### 12.25 El ojo del logo en game over, selección de idioma y carga · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `arte`, `ui`

Daniel 2026-10-14: con el logo en el menú principal, el ojo del logo va en el resto de lugares que usaban el ojo dibujado por código, pero solo el ojo. Hecho: art/logo/epiphany_eye.svg (solo el ojo: almendra, iris, pupila y contorno dorado, sin rayos, lágrimas ni letras) → assets/ui/logo/epiphany_eye.png; Eye de game_over, language_select y la carga (scene_flow) son TextureRect con esa textura. Game over y selección de idioma lo muestran tenue (alfa 0,35); el de carga parpadea achicando la escala. Se borraron title_eye.gd y loading_eye.gd. Test: test_every_eye_is_the_logo_eye.

### 12.26 Jefe final (Ojo): rediseño completo del look · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** media · **Tamaño:** L · **Responsable:** project-epiphany-5d · **Etiquetas:** `arte`, `jefe`

Daniel 2026-10-14 (por -5d): los ojos de la Queñoa (12.23) quedaron mucho mejor que el jefe final, así que se rediseña el look entero del jefe: cuerpo, ojo, párpados y manos. Primero bocetos de concepto para Daniel. El gameplay y la estructura de boss.gd no cambian: Body, Eye con las shape keys rendija/dilatada, Upper/LowerLid, manos con las shape keys GRIP y los anchors. 12.21 (ojo interruptor parecido al ojo del jefe) va después de esta.

- [x] Bocetos de concepto para Daniel
- [x] Forma 1 (fases 1-2): máscara de oro (boceto 3) en build_jefe.py: cuerpo, ojo con shape keys rendija/dilatada, párpados, manos con GRIP
- [x] Forma 2 (fase 3): ojo orgánico corrupto (boceto 2: nudo de corteza con raíces, hueso y venas rojas), mismas piezas y shape keys
- [x] Transformación en boss.tscn (AnimationPlayer): el ojo grita, la máscara se agrieta y estalla, aparece la forma 2
- [x] boss.gd: en _on_phase3_entered reproduce la transformación con el jefe invulnerable y en pausa mientras dura

**Notas:** Daniel 2026-10-14: dos formas. Fases 1-2 máscara de oro (boceto 3); al entrar a la fase 3, cinemática corta (grito, la máscara se agrieta y estalla) y queda el ojo orgánico corrupto (boceto 2) para la fase 3. Lo hace -5d entero, boss.gd incluido.

### 12.27 VFX mágicos con shaders y partículas (sin texturas) · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** L · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `vfx`

Daniel 2026-10-14 (por -5d), con referencias suyas (esferas de energía, anillos de fuego, círculos mágicos). Todo con shaders y partículas, sin texturas.

- [x] Portales: anillo brillante o círculo mágico con un pilar de luz
- [x] Orbe del jefe: esfera de energía en vez de la bola brillante simple
- [x] Otros efectos brillantes donde encajen

**Notas:** Hecho: portales (círculo mágico, pilar de luz, motas), proyectiles del jefe/torreta/Amaru como esfera de energía con estela, pulsos en las manos del jefe y La Mano, fase 3 en rojo, anillo de fuego de la bomba, círculo de la bendición. El tajo de espada (demo_tajo.tscn + sword_trail.gdshader) queda aparcado por Daniel: fue banco de pruebas para ataques elementales (12.28).

### 12.28 Ataques elementales · Pausado

**Prioridad:** baja · **Tamaño:** L · **Etiquetas:** `arte`, `vfx`, `combate`

Aparcado por Daniel (2026-10-14). El banco de pruebas del tajo de 12.27 sirve de punto de partida: src/world/vfx/demo_tajo.tscn y sword_trail.gdshader (medialuna aditiva, ancha en la hoja, borde interno deshilachado, fade al dejar de emitir). La versión original de Daniel del shader y la demo está en debug/tmp/fd/daniel_demo/ (sin versionar).

**Relacionadas:** 16.15 Daño por fuera del Hitbox, tres formas de mirar si toca el piso y dos ondas iguales

### 12.29 Muro agrietado LA de cueva (muro_agrietado_cueva_la) · Hecho

**Terminada:** 2026-10-14 · **Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-5d · **Etiquetas:** `arte`, `bug`

Daniel 2026-10-14 (playtest, cueva de las bombas): el muro de práctica (CavePracticeWall) sigue siendo el cracked_wall.tscn de siempre, un bloque con tapa de pasto verde que sobresale de la pared de roca de la cueva. 12.24 hizo los tapones LA de chullpa, quenoa, totora y cumbre; las cuevas pasaron al look LA (cueva, 7298dfb5) después y quedaron sin el suyo. Falta el estilo cueva: tapón que llene el paso LA con la roca oscura y la cresta gris de la cueva, grietas en las dos caras, colocado por la_walls como en las mazmorras. Usos: bomb_cave (CavePracticeWall) y shrine_cave. Lo que esconde va tapado con covers (11.164).

- [x] Malla muro_agrietado_cueva_la (las medidas de paso que usen las cuevas)
- [x] la_walls: bomb_cave y shrine_cave usan el tapón de cueva
- [x] Techo en covers sobre lo que esconde cada uno (11.164)

**Capturas:** `compass/images/m12-29-20261014-034608.png`

**Relacionadas:** 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la); 11.164 Lo que esconde una pared agrietada no se ve desde arriba; 11.166 Santuario con una sola entrada: su muro agrietado

### 12.30 Templo: salas que se vean bien para grabar · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `templo`

Daniel (2026-10-14) quiere grabar el templo completo y así no se puede: 1) cada puerta tiene alrededor una U de cubitos grises sueltos (resto del kit gris), fuera de estilo; 2) las puertas este y oeste dan a un vacío ocre plano y el corte de la pared muestra dientes negros fuera de la sala; 3) en las esquinas de arriba las puntas de las paredes inclinadas sobresalen en tiras; 4) abajo una franja oscura tapa la pared sur. Recorrer todas las salas del templo con el escenario templo_video y dejarlas al nivel de la Chullpa y la Queñoa.

**Prueba:** Grabar el templo con el escenario templo_video: las salas llenan la pantalla y afuera es negro. test_templo, test_coop_camera, test_camera

**Notas:** Hecho (-5d, d6a17c4f/0e2d6d34): cámara del templo a 25, velo con reach (negro pasado el grosor de pared), pasos de puerta en piedra lavanda oscura y umbrales lavanda. Quedan astillas de la pared vecina junto a las puertas este/oeste y en las esquinas, y Mano y Jefe con su encuadre propio. test_templo pasa (una falla anterior era import viejo en main).
2026-10-15: el templo se rearmó en salas de 22 × 14 (9dfa381a, 11.180) con cámara y viñeta nuevas (91b21efd); la cámara a 25 y las astillas junto a las puertas este/oeste son del layout viejo. Falta volver a recorrerlo con templo_video y rehacer la lista de lo que queda.

**Capturas:** `compass/images/m12-30-20261014-153143.png`

**Relacionadas:** 12.40 Estilo Link's Awakening en las mazmorras reales: cámara y assets nuevos

### 12.31 Chullpa: jefe final momia con aspecto propio · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `chullpa`, `jefe`

Daniel (2026-10-14): en la Chullpa hay que acomodar el jefe final de la momia para que no sea simplemente la del sub-jefe pero más grande. Hoy el jefe es el modelo del sub-jefe escalado; necesita su propio aspecto (modelo, silueta, detalles) que se lea como jefe.

**Prueba:** test_chullpa; en juego, el jefe de la Chullpa es Mallqui, no la momia del sub-jefe agrandada

**Notas:** Daniel (2026-10-14): prioridad, va a grabar la Chullpa. Hecho (-5d, 17350524): el jefe ya tenía modelo propio, Mallqui (mantos rojo y azul, máscara de oro, corona de sol), pero un refresh de la_walls perdió el override de la malla. Ahora el jefe instancia src/entities/mummy_guard/mallqui.tscn (heredada de mummy_guard con mallqui.res), así sobrevive a los refresh. Juego y mummy_guardian.tres sin cambios.

### 12.32 Look LA: topes de pared del color del muro y viñeta borrosa en vez del velo negro; desenfoque solo cerca de la cámara · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-aa · **Etiquetas:** `arte`, `render`, `mazmorra`

Daniel (2026-10-14): en todas las mazmorras LA los topes de las paredes se ven del color del tile de la pared, no negros: se va el velo negro (borde_oscuro, 11.156). Lo de más allá lo tapa una viñeta borrosa en el borde de la pantalla. Menos desenfoque: solo lo muy alto o muy cerca de la cámara (DOF de enfoque_la). Toca la_walls, borde_oscuro y enfoque_la.

**Prueba:** tests/test_quenoa.gd, tests/test_chullpa.gd, tests/test_camera.gd, tests/test_coop_camera.gd

**Notas:** Sin velos (BordeOscuro y borde_oscuro.gdshader fuera). Viñeta TonoLA y cámara: valores por nivel, y la viñeta también por sala (frame_sides/top/bottom, grupo Viñeta de AmbienteSala, a48ac690), que Daniel ajusta a ojo. la_walls saca paredes de relleno que no dan a piso. Desde el 2026-10-15 los tamaños de sala son libres (a72b6573): cada sala se centra en cámara y tapa las otras. DOF solo cerca de la cámara (9 m), sin desenfoque lejano. Huecos de caída más oscuros con niebla negra. _look reaplica el resto en cada refresh, sin pisar la viñeta ni la cámara (76336916). Chullpa: Rellano 22x14, isla de la Sala del Cofre 3x3.

**Relacionadas:** 11.156 Chullpa: se ven los techos (crestas) de las paredes LA horneadas

### 12.33 Templo: la Mano sub-jefe con modelo propio · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `templo`, `jefe`

Daniel (2026-10-14): la Mano suelta (HandGuard, sub-jefe del templo) usa hoy el mismo modelo que las manos del jefe final; quiere un modelo diferente para que no sea idéntica. Mismas animaciones/ataques (golpe al piso, agarre, barrido), colisión y hitbox sin cambios.

### 12.34 Templo: paleta más dorada, como el jefe final, menos celeste · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `templo`

Daniel (2026-10-14): que el color del templo se parezca más al dorado del jefe final y no tanto al celeste actual (kit templo_la, piso, luces/ambiente del nivel). Respetar sus valores de TonoLA/AmbienteSala; si hace falta refresh, avisar a -fd antes (regla del reborde y navmesh).

### 12.35 Totora: el hueco de salida de los Tejedores tiene que leerse como caída · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `mazmorra`

Daniel (2026-10-15, captura): el hueco de caída al lado del cofre de la llave del jefe (PisoAlto, celda (2,1), CaidaLA44 en (4,0,2)) se ve como un cuadrado negro y parece que falta un bloque. Es la salida de una vía del rincón: la reja la baja el ojo con tiempo y se vuelve a cerrar con la llave adentro. Daniel eligió dejar el hueco como salida, pero que se lea: borde y caída visibles, no un cuadrado negro.

- [x] El hueco de los Tejedores se lee como caída desde la cámara del nivel
- [x] Revisar los otros CaidaLA (Chullpa, Queñoa, Cumbre) con el mismo criterio
  Chullpa y Queñoa bien; Cumbre (12,12) y (13,12) de PisoCornisa sin paredes a propósito (precipicio).

### 12.36 Totora: los charcos de Amaru y Yacumama, de agua · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `mazmorra`, `jefe`

Daniel (2026-10-15, captura de la sala del jefe): los cuatro círculos por donde salen las anguilas tienen que ser agua. Hoy son src/entities/amaru/amaru_pool.tscn, un disco plano azul oscuro (placeholder de 349898f5), en el Pozo (AmaruFight), en el Jefe (BossFight) y en el templo (revancha). Ojo: water_la.gdshader colorea por profundidad, así que un disco sobre las tablas sale transparente; hace falta un fondo o un ajuste propio.

- [x] Charco de agua que se lea desde la cámara del nivel, en Totora y en el templo

### 12.37 Rejas con el estilo de cada mazmorra · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `mazmorra`

Daniel (2026-10-15): la reja de la Cumbre tiene los bosses de la Chullpa. Todas las mazmorras usan src/world/gate.tscn con el modelo de la Chullpa. Hace falta una reja por estilo (Queñoa, Totora, Cumbre, templo), como los kits LA, sin cambiar el tamaño ni la colisión.

- [x] Reja por estilo y cada nivel usando la suya
- [x] Puerta del jefe de la Cumbre propia
  Según -43: puerta_jefe_cumbre_la.res (108579 B) es la de la Chullpa renombrada (108580 B), con los mismos bosses; BossDoor de PisoCornisa (46,0,20). La persiana es la misma malla en las cuatro (¿a propósito?).
- [ ] Puerta del jefe del templo propia
  puerta_jefe_templo_la.res (108579 B) es también la de la Chullpa renombrada (108580 B); el paso 2 solo arregló la de la Cumbre (fbebee83).

### 12.38 Cóndores de la D4: modelo de arte · Hecho

**Terminada:** 2026-10-17 · **Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-dd · **Etiquetas:** `arte`, `jefe`

Pedido de -43 (11.129 paso 8) y de Daniel: Kuntur joven y Apu Kuntur con modelo de cóndor en lugar de las primitivas. Hecho por -5d en 5520a17d (build_kuntur.py): Kuntur negro con collar blanco y banda en el ala, cabeza roja con cresta; Apu Kuntur con sol de oro en la frente, pectoral y alas de oro. Las alas tienen el origen en el hombro; los nodos del script no cambian.

### 12.39 Enemigos comunes estilizados según el theme de cada mazmorra · Revisión

**Prioridad:** media · **Tamaño:** L · **Responsable:** project-epiphany-5c · **Etiquetas:** `arte`, `enemigos`, `mazmorra`

Daniel (2026-10-15): es hora de que los enemigos normales de las mazmorras vayan con el theme de cada una. Hoy esqueleto, escudo, arquero y acorazado comparten un único modelo (models/chullpa.tscn) con armas genéricas (sword_1h, bow, shield_round) en todas las mazmorras, cuevas y el overworld. Una variante por mazmorra (Chullpa, Queñoa, Totora, Cumbre, Templo) con el mismo rig y animaciones, como .tscn heredados (no overrides en las instancias: el refresh LA los pierde). Primero propuestas para que Daniel elija; después se cambian las instancias de cada nivel.

- [x] Modelos, armas y corazas por mazmorra (arte, -5d)
  Hecho, aprobado por Daniel: b19ba666 (guerrero_<mazmorra>, armas, 20 escenas en src/entities/guerreros/<tipo>_<mazmorra>.tscn), ae1ed827 (armadura_<mazmorra>). test_guerreros.
- [x] Cambiar las instancias de cada mazmorra (diseño, -43)
  Hecho el 2026-10-15 (27f82209): en cada mazmorra los ext_resource de esqueleto, escudo, arquero y acorazado apuntan a guerreros/<tipo>_<mazmorra>.tscn, así cambian todas las instancias y los spawns de oleadas (cripta de la Chullpa, Combinada del templo) sin overrides. test_dungeon_enemies falla si un refresh vuelve a las escenas base.
- [x] Overworld y cuevas con la variante de su zona (-5d)
  Daniel (2026-10-15): variantes. Cada enemigo del overworld y cada cueva toma la variante de la mazmorra de su región: Cerros → chullpa, Arboleda → quenoa, Laguna y Bañado → totora, Cumbre → cumbre, Necrópolis y explanada del templo → templo. Los guardias del templo ya están (569c5621).
  Hecho el 2026-10-15 (296a3287, ya en main; faltaba tildarlo): esqueletos de Pradera y Arboleda quenoa, guardias del Risco, Mirador y la explanada templo, bomb_cave y grotto_cave chullpa (sus entradas están en los Cerros y el Primer Claro, junto a los Cerros). shrine_cave, bush_cave y spring_cave no tienen guerreros. Ningún enemigo del overworld cae en Cerros, Laguna, Bañado ni Cumbre. test_dungeon_enemies ahora cubre el overworld y las cuevas (17644498).
- [ ] Probarlo (Daniel)

**Relacionadas:** 16.17 Configs de enemigos clonadas por mazmorra

## M16 — Salud del código  (56/56, 56 en revisión)

Arreglar los bugs y la deuda técnica que salieron del análisis del 2026-10-16 (cinco revisiones con las skills: arquitectura, code review, comunicación, patrones y datos), antes de seguir sumando sub-jefes, mazmorras y el co-op. Lo de rendimiento va a M15; las suposiciones de un solo player, a M13.

**Hecho cuando:**
- Los bugs confirmados del análisis tienen arreglo y test que falla sin él.
- Cargar partida, pausar y cambiar de escena tienen un solo dueño cada uno y no se pisan.
- Un sub-jefe nuevo, un ítem nuevo o un cambio de formato del save no obligan a copiar código ni a tocar varios archivos a mano.
- Los tests barren carpetas enteras (escenarios, flags de niveles, data, grafos) en vez de listas fijas.

### 16.1 Jefe final: el rayo del ojo pega una sola vez por pelea · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`Hitbox._already_hit` solo se limpia en el setter de `active_attack` (hitbox.gd:20-23). `_sweep_laser` prende `%LaserSpot` sin limpiarlo (boss.gd:460) y `_end_laser` solo lo apaga: después del primer golpe el player queda en la lista toda la pelea y los barridos siguientes lo atraviesan. Los demás que prenden `monitoring` a mano (Ojo Vigía, Kuntur, Amaru, Momia, pinchos) dependen de acordarse de poner `active_attack = null`. BossHand guarda un AttackRunner que solo usa como registro de hitboxes y arma el AttackData de la onda en código.

- [x] Test: el segundo barrido del rayo también pega
  test_boss hoy solo mira visible/monitoring.
- [x] Hitbox.activate(attack) y deactivate()
  Limpian la lista y prenden/apagan monitoring; los usan AttackRunner, BossHand, sub-jefes, pinchos y el rayo.
- [x] Onda de la mano a un .tres
  boss_hand.gd:102,141; sacar el AttackRunner si ya no hace falta.

**Prueba:** El rayo pega en cada barrido que toca al player (con sus i-frames); test_boss lo cubre.

**Notas:** wt/bugs cf83a4d5. Hitbox.activate/deactivate en todos los que prendían monitoring a mano; la onda de la mano en data/boss/hand_shockwave.tres. BossHand sigue usando AttackRunner como registro de hitboxes.

**Relacionadas:** 16.15 Daño por fuera del Hitbox, tres formas de mirar si toca el piso y dos ondas iguales

### 16.2 Co-op: un contenedor de corazón revive al Espíritu con la vida llena · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `co-op`

`_on_max_health_changed` llama a `health.reset(max)` (player.gd:282), que llena la vida en cualquier estado. Si el otro player es Espíritu (o está en el Dead de 1,8 s), queda con `is_dead == false`: la IA lo vuelve a buscar, su Hurtbox sigue activo y el próximo golpe lo saca de Spirit por anystate→Hurt sin pasar por `revive()`.

- [x] Test con dos players
  Uno Espíritu, el otro agarra un contenedor: sigue Espíritu con 0 HP.
- [x] Subir el máximo sin curar a los muertos
  Algo como `health.restore(max, current)` cuando is_dead o Espíritu.
- [x] Hurt no sale de Dead ni de Spirit
  Guardia en el anystate→Hurt de state_machine.gd:19.

**Prueba:** Co-op: con el otro en Espíritu, agarrar un contenedor de corazón: el Espíritu sigue Espíritu (no revive lleno) y el vivo se llena.

**Notas:** wt/bugs 574da08e. El vivo se llena; el caído queda en 0 con el máximo nuevo.

### 16.3 Templo: el grafo pide `mirror_shield`, que no existe · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `tests`

templo_graph.tres:153, 159, 186 y 195 usan `mirror_shield`; el ítem es `shield_mirror`. El test de alcanzabilidad pasa porque el mismo grafo lo trae en `brings`: el `_tokens()` de dungeon_reach.gd solo mira que alguien del grafo dé cada token.

- [x] Corregir el id en el grafo del templo
- [x] Test: cada token es un id de ItemDatabase o de FlagRegistry
  needs, brings, item, guard y goal; los tokens sintéticos (ch_rellano_pot) con prefijo o lista explícita.
- [ ] Opcional: brings sale de los item de los grafos anteriores
  Hoy se copia a mano.

**Prueba:** Templo: llegar al cuarto que pide el escudo espejo con el escudo espejo y que se pueda pasar.

**Notas:** wt/bugs 0abf56af. Derivar brings de los grafos anteriores quedó sin hacer (opcional).

**Relacionadas:** 16.22 Tests que barren carpetas en vez de listas fijas

### 16.4 Intro del título: no esconde los velos del overworld · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`title_flyover.gd:57` busca el grupo `zone_veil`; ZoneVeil se agrega a `zone_veils` (zone_veil.gd:29). El vuelo del título nunca los esconde y nada avisa. Otros grupos que siguen como texto suelto: `bombs`, `targetable`, `walk_guard`.

- [x] ZoneVeil.GROUP y usarlo en los tres lados
  zone_veil, title_flyover y overworld_map.
- [x] Constantes para bombs, targetable y walk_guard

**Prueba:** Pantalla de título: durante el vuelo sobre el overworld no se ven los velos de las zonas.

**Notas:** wt/bugs 97bfef35. test_groups: todo grupo buscado por nombre literal lo agrega algún script o escena.

### 16.5 Partida o escenario con botones de ítem mal formados crashea · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`item_buttons.assign(...)` (game_state.gd:399) acepta un array de cualquier largo y después se indexa [0] y [1] (player.gd, `assign_button`). `SaveCodec.validate` no lo mira, y los escenarios se editan a mano o desde el Save Inspector. Tampoco valida equipo (id, categoría, que lo tengas), botellas, `current_dungeon`, las secciones `dungeon_*` ni el tipo de cada flag contra su default.

- [x] read_from: botones a largo 2 y sin ids que no tenés
- [x] Flags con el tipo de su default
  game_state.gd:407 lee cualquier Variant.
- [x] validate: equipo, botones, botellas y mazmorras
  Sigue siendo aviso, no bloquea.

**Prueba:** Abrir un escenario editado a mano o desde el Save Inspector con botones de ítem raros: no crashea, el Save Inspector lo marca.

**Notas:** wt/bugs 757407ae. read_from es conservador (no exige que tengas el ítem); validate sí lo avisa. Todos los escenarios validan salvo boss_key_door_locked (a propósito).

### 16.6 Corrutinas que esperan un tween matado no vuelven nunca · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`Tween.kill()` no emite `finished`. El jefe espera `grow.finished` y `_laser_tween.finished` (boss.gd:453,467,504) y `_cut_charge` los mata: el `if not _eye_attacking: return` nunca corre. BossHand `_move` espera `_motion.finished` y `_drop_everything`/`collapse` lo matan: si se corta el primer `_move` de `_hold`, el lambda de `escaped` queda conectado al player para siempre (una fuga por agarre interrumpido).

- [x] Esperar algo que siempre llega
  Señal propia de interrupción o el token de turno como Kuntur.
- [x] Test: interrumpir un agarre no deja conexiones en escaped

**Prueba:** Jefe final: aturdir el ojo a mitad del rayo y cortar un agarre de la mano: la pelea sigue normal después.

**Notas:** c05390ff: Tweens.ended(tween) vuelve también si lo matan; _move/_return_to_rest devuelven bool y los que llaman cortan. test_boss: cortar un agarre no deja nada, aturdir el ojo a mitad del rayo termina la corrutina.

**Relacionadas:** 16.13 Clase base ArenaFighter para los sub-jefes

### 16.7 Cargar partida: la escena vieja recibe el save nuevo antes de irse · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `refactor`

`SaveManager._load_path` hace `GameState.read_from` (emite `loaded`) y recién después `SceneFlow.enter_saved_scene`, que igual recarga la escena (11.108). Mientras tanto la escena vieja, despausada, reacciona: PersistentFlag reemite, rejas y switches se mueven y algunos vuelven a escribir flags (wave_spawner.gd:104, floor_switch.gd:96/106, eye_switch.gd:79). `SaveManager.loading` existe para eso pero solo lo mira la cámara. SaveManager y SceneFlow además se llaman entre sí; `dungeon_changed` se emite dos veces al recargar una mazmorra.

- [x] Sacar la escena vieja antes de leer el save
  Pausar y descargarla detrás del fundido.
- [ ] SceneFlow es dueño de cargar y entrar; SaveManager solo lee y escribe
  La ubicación entra como parámetro.
- [x] current_dungeon se pone una vez por cambio de escena
  No en _enter_tree/_exit_tree de Dungeon.
- [x] Test: cargar no dispara changed en nodos de la escena vieja

**Prueba:** En una mazmorra con rejas y switches, cargar otra partida desde el menú: la sala vieja no se mueve ni suena antes del fundido y la nueva aparece con sus rejas como quedaron.

**Notas:** 2ab62f68: SceneFlow.enter_save saca la escena vieja (remove_child + queue_free) antes de read_from; _sync_dungeon una vez por cambio de escena; Music mantiene las capas sin escena. Paso 2 a medias: la carga ya es de SceneFlow, pero SaveManager todavía llama a SceneFlow.location().

**Relacionadas:** 11.108 Cargar en la misma escena desincroniza puertas y flags

### 16.8 Pausa con dueños: menús, transiciones y reveal no se despausan entre sí · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `refactor`

`get_tree().paused` lo escriben MenuStack (push pausa, pop siempre despausa), SceneFlow y la cámara (reveal); gana el último. Un TextBox o el Game Over que se cierran durante un reveal despausan el mundo a mitad del paneo; GameOver hace pop y después `respawn()` funde 0,4 s con el mundo corriendo.

- [x] Pause.hold(motivo) / release(motivo)
  paused = hay algún motivo; MenuStack, SceneFlow y la cámara piden el suyo.
- [x] Test: cerrar un menú durante un reveal no despausa

**Prueba:** Abrir y cerrar el menú o un cartel durante el paneo de una puerta revelada o en el fundido de una transición: el mundo no arranca antes de tiempo. Game Over → continuar funde sin que nada se mueva.

**Notas:** 7de6965d: Pause.hold/release/clear con motivos (menu, travel, reveal); nadie más escribe tree.paused (test_pause lo revisa).

### 16.9 Cambios de escena y fundidos que se pisan · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`travel_to` pone `traveling` pero no lo mira; `respawn`, `new_game`, `with_fade`, `quit_to_title`, el portal de viaje rápido y las escaleras no lo ponen ni lo miran. `_fade` crea un tween nuevo sin matar el anterior (scene_flow.gd:413). `respawn` corre despausado y sin el calentado de pipelines. `new_game` escribe el mismo archivo dos veces (save_game + autosave).

- [x] Una guardia al principio de cada transición pública
- [x] Un solo tween de fundido
- [x] respawn por el mismo camino que _change_scene
  Pone traveling, pausa y calienta pipelines.
- [x] new_game guarda una vez
  Y sacar `auto_slot()`, que ya devuelve current_slot.

**Prueba:** Morir y entrar a una escalera o portal al mismo tiempo, o tocar dos salidas seguidas: una sola transición, sin fundidos que se cortan. Partida nueva arranca normal.

**Notas:** 177feb58: SceneFlow.traveling es un contador (begin/end_transition), guardias en with_fade/travel_to/respawn, un solo _fade_tween, respawn por _change_scene, new_game guarda una vez.

### 16.10 Un golpe corta la transición entre salas o el levantar un ítem · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`, `refactor`

`anystate() -> Hurt` (state_machine.gd:19) no tiene guardia, a diferencia de transition y grabbed. Transition no da i-frames: un proyectil de la sala anterior frena la entrada en la puerta y `_lock_after_entering` puede cerrar la reja encima. En ItemGet saltea el cartel aunque el ítem ya se dio. Relacionado: las capacidades de cada estado se miran por nombre o ruta de nodo (player.gd:199,213,252) en vez de flags como `follows_room_transition`.

- [x] Export can_be_hurt en PlayerState
  O i-frames en Transition._enter.
- [x] can_interact y can_guard como exports
  Reemplazan `_guard_states` y los `name in [...]`.
- [x] Idle y Moving usan set_locked_legs de la base

**Prueba:** Recibir un proyectil justo al cruzar una puerta: termina de cruzar y la reja no se cierra encima. Que te peguen mientras levantás un ítem: el cartel sale igual.

**Notas:** 0a5415d9: PlayerState.can_be_hurt/can_interact/can_guard y blocks_room_transition(); test_player cubre un golpe a mitad del cruce.

### 16.11 Estado estático que sobrevive al cambio de escena · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`AreaZone._current` (area_zone.gd:8) queda apuntando a una zona liberada y se lee su display_name. `Room._waking` (room.gd:60) se limpia solo dentro de un call_deferred: si la sala que lo pidió se libera antes, queda en true y las salas dejan de despertar y dormir sus nodos en todas las escenas siguientes.

- [x] _current con is_instance_valid y limpio en tree_exiting
- [x] La agenda de despertar en un dueño por escena
  La cámara, no un static de clase.

**Notas:** c10b855d: Room._wake_rooms estático (la agenda no depende de la sala que la pidió); AreaZone olvida la zona al salir del árbol. El test de AreaZone también pasa con el código viejo.

### 16.12 Timers del árbol que reanudan corrutinas de nodos ya liberados · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-cb · **Etiquetas:** `bug`

`get_tree().create_timer(...)` sobrevive al cambio de escena: enemy.gd:364 (corpse_time), dead.gd:13, kuntur, watcher_eye, amaru, mummy_guard, centinela, boss_hand y boss_arena. Si el player muere a mitad de un patrón o viaja a los 4 s de matar algo, cada uno imprime "Resumed function after await, but class instance is gone", ruido que tapa errores reales.

- [x] Esperas atadas al nodo
  Un helper `_wait(t)` con tween_interval del propio nodo (va en ArenaFighter, 16.13).
- [x] Test: viajar con patrones a medias no deja errores en el log

**Notas:** 72ddc8a8: Tweens.wait(nodo, s) para con la pausa como un timer del árbol pero muere con el nodo; reemplaza create_timer en sub-jefes, cadáver de enemigo, Dead del player, jefe, mano, BossArena, ArenaFight y EyeSwitch. test_arena_fighter.

**Relacionadas:** 16.13 Clase base ArenaFighter para los sub-jefes

### 16.13 Clase base ArenaFighter para los sub-jefes · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `refactor`

Centinela, Ojo Vigía, Kuntur, Amaru y la Momia repiten las mismas señales y campos (arena, may_attack, peers, pace), `start`/`reset`/`_interrupt`, `_wait`, `_new_tween`/`_tween_to`, `_clamp_to_arena`, el `_on_hit` de rebotar si no es vulnerable y el token `_turn`. ArenaFight los encuentra con `has_signal(&"attack_finished")` y los guarda en un Array sin tipo; WaveSpawner repite el cableado; `Room.enemies_inside` usa `enemy.get(&"is_dead")`. Cada sub-jefe nuevo (D3, D4, templo) copia todo otra vez.

- [x] ArenaFighter extends Node3D con lo compartido
  Un solo nivel de herencia; `_on_hit` plantilla con is_vulnerable() y _on_hit_vulnerable().
- [x] Pasar los cinco sub-jefes
  Sin reescribir a LimboHSM; las corrutinas quedan.
- [x] _fighters: Array[ArenaFighter] en ArenaFight y WaveSpawner

**Prueba:** Pelear contra Centinela, Ojo Vigía, Kuntur, Amaru, la Momia y la mano guardiana: atacan por turno, rebotan con chispas fuera de su momento vulnerable, mueren y la arena se abre.

**Notas:** 72ddc8a8: ArenaFighter (@abstract) es la base de los seis (también HandGuard): señales, arena, pace, may_attack, peers, _turn, start, _interrupt/_on_interrupt, _on_hit con _react_to, tweens y _clamp_to_arena. ArenaFight y WaveSpawner con Array[ArenaFighter]. Room.enemies_inside sigue con get(is_dead) (mezcla enemigos comunes).

**Relacionadas:** 16.6 Corrutinas que esperan un tween matado no vuelven nunca; 16.12 Timers del árbol que reanudan corrutinas de nodos ya liberados

### 16.14 Peleas de jefe: música, barra del HUD y premio con un solo camino · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-cb · **Etiquetas:** `refactor`

`Music.boss_fight` es un bool global que prenden y apagan ArenaFight y BossArena (7 lugares): una arena que termina apaga la música de otra. Music además lee la escena, la mazmorra y la sala de la cámara cada frame. La barra del jefe se llama con `call_group(Hud.GROUP, "show_boss")` sin tipo y el HUD espera display_name, bar_changed, bar_fraction() y phase() (por eso ArenaFight.phase() devuelve 0). "Aparece el premio y su flag se marca al agarrarlo" está dos veces. BossArena tiene su propio rematch (GameState.boss_rematch vs ArenaFight.rematch).

- [x] Music.hold_boss(dueño) / release_boss(dueño)
  Un set que suelta al dueño en tree_exiting.
- [ ] La cámara emite room_changed y Music se suscribe
  Sin polling.
- [x] Contrato tipado para la barra del jefe
- [x] Helper compartido del premio
- [ ] Un solo origen para el rematch

**Prueba:** En un sub-jefe y el jefe: la música de pelea entra y sale al terminar, también al irse de la sala a mitad; la barra del HUD aparece con nombre y baja; el premio sale una sola vez (volver a la sala no lo repite).

**Notas:** 60fc771f: Music.hold_boss/release_boss con dueños (se suelta en tree_exiting); BossBar tipado para el HUD (ArenaFight sin phase()); Pickup.offer_once para el premio; arreglado que la barra mostrada justo después de esconderla se iba por el fundido viejo. Sin hacer, a propósito: room_changed (el doom cambia dentro de la sala, ej. BossArena calma la sala, así que Music igual tiene que leerlo; el costo es una búsqueda por grupo) y un solo rematch (ArenaFight.rematch es 'revancha a media vida' del diseño y GameState.boss_rematch es volver a pelear el jefe final: son dos cosas distintas).

### 16.15 Daño por fuera del Hitbox, tres formas de mirar si toca el piso y dos ondas iguales · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`

Siguen llamando a `hurtbox.receive()` a mano: mummy_guard, yacumama, ground_waves, boss_hand, pit, thrown_object, dashing y hook, cada uno armando el equipo a su manera. "Está en el piso" se mira tres veces: Hitbox castea el padre a PlayerCharacter (un componente que asume quién es su dueño), GroundWaves a CharacterBody3D y la Momia/Yacumama recorren Players.alive() (sus ondas no tocan escoltas). El anillo de la Momia es una copia de GroundWaves. Los elementos (`explosive`, `blast`, `dash`, `spikes`, Hook.ELEMENT) y los `hit_burst` son texto libre, también en `protects_against` de los .tres.

- [x] Hurtbox.is_grounded()
  El cuerpo dueño por export; lo usan Hitbox y GroundWaves.
- [x] La Momia usa un GroundWaves
  Con un `pulse(centro, radio, daño)`.
- [x] Elementos como constantes
  Con @export_enum en protects_against; antes de los ataques elementales (12.28).

**Prueba:** Momia: sus ondas te pegan en el piso y no si saltás con la pluma. Pinchos y explosiones pegan; la túnica o escudo que protege de algo sigue protegiendo.

**Notas:** 1628aa2c: Hurtbox.is_grounded() lee un body exportado (el del player apunta al player; sin body cuenta como en el piso, porque un enemigo quieto da is_on_floor() false). La Momia usa GroundWaves.pulse(centro, radio, daño, empuje) solo contra el equipo del player; sus wave_* quedan como el ajuste que pisan Chullpa y Templo. DamageInfo.PHYSICAL/EXPLOSIVE/BLAST/DASH/HOOK/SPIKES; en vez de @export_enum, test_items revisa que protects_against use elementos conocidos. Los receive() a mano siguen (Hurtbox.receive es la API).

**Relacionadas:** 11.82 Daño que no pasa por el Hurtbox; 12.28 Ataques elementales; 16.1 Jefe final: el rayo del ojo pega una sola vez por pelea

### 16.16 Formato del save con dueño y migraciones por versión · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`

Las claves del save están escritas a mano en GameState.write_to/read_from, slot_summary (SWORD, SHIELD, bow, bomb_bag fijos), SaveCodec.validate (prefijo dungeon_, _boss_door) y unos 45 literales del Save Inspector; un campo olvidado falla en silencio porque `typed()` devuelve el default. `SaveCodec.VERSION` sigue en 1 y `_migrate` está vacío; la migración real de botellas corre en cada carga sin mirar versión y la del slot 0 está en SaveManager. El Save Inspector lee sin migrar: con VERSION 2 abriría un save viejo y lo guardaría como 2 sin migrar. Una flag o un ítem renombrado se descartan y la partida pierde ese progreso.

- [x] SaveKeys: una constante por sección y clave
  La usan GameState, SaveCodec, slot_summary y el Inspector.
- [x] DungeonState se escribe y lee solo
- [x] SaveCodec.migrate(cfg, desde) estático
  Lo llaman _load_path y el Inspector; botellas y slot 0 como pasos de la versión 2.
- [x] Tablas de renombres de flags e ítems
- [ ] Sacar AUTO_SLOT de la UI cuando no queden saves viejos
  file_select, slot_card, system_page y el Inspector.

**Prueba:** Cargar un save de antes de hoy que tenga pociones o botellas vacías: carga sin avisos, las botellas aparecen con su contenido y el progreso (flags, ítems) es el mismo. Guardar y volver a cargar.

**Notas:** 9773d09e: SaveKeys; DungeonState.write_to/read_from; SaveCodec.migrate(cfg) estático con VERSION 2 (botellas a nivel archivo), FLAG_RENAMES/ITEM_RENAMES, el Save Inspector migra al abrir; tampering se mira antes de migrar. Paso 5 queda: AUTO_SLOT sigue hasta que no queden saves viejos. La 'migración' del slot 0 es de archivos (origin), no del cfg, y quedó en SaveManager.

### 16.17 Configs de enemigos clonadas por mazmorra · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `datos`

20 .tres de `data/entities/` ({skeleton, archer_skeleton, armored_skeleton, shield_skeleton}_{chullpa, cumbre, quenoa, templo, totora}) son iguales a su base salvo `model`. Cambiar la vida o la velocidad de un tipo son seis archivos que se van a desfasar. Las variantes .tscn ya existen. En `Enemy._swap_model` el Visuals viejo solo se `queue_free()` y las búsquedas siguientes todavía lo recorren.

- [x] Un EntityConfig por tipo; el modelo en la variante de escena
  Coordinar con 12.39 (arte, en curso).
- [x] _swap_model busca solo en el modelo nuevo
- [x] test_guerreros mira que las variantes compartan config

**Prueba:** Esqueletos, escudo, arquero y acorazado en Chullpa, Queñoa, Templo, Totora y Cumbre: cada uno con el cuerpo de su mazmorra, misma vida y daño que antes, sueltan lo de siempre.

**Notas:** 28eab75d: sin los 20 .tres por mazmorra; cada variante de guerreros/ usa la config de su tipo y Enemy.visuals con el cuerpo de su mazmorra (gana sobre config.model). _swap_model saca el Visuals viejo del árbol enseguida. -2a dio el OK (12.39 no toca esos archivos).

**Relacionadas:** 12.39 Enemigos comunes estilizados según el theme de cada mazmorra

### 16.18 Lo que hace un ítem al agarrarlo, por datos y no por id · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `datos`

`GameState.give` hace match por small_key, boss_key, boss_key_piece, dungeon_map, compass, heart_container y heart_piece (game_state.gd:217-230); slot_summary, NEW_GAME_EQUIPMENT, item_get.gd:45 y los chips de items_page también tienen ids fijos. La regla de capacidad de munición está en inventory.gd y otra vez en save_codec.gd.

- [x] ItemData.on_get (enum o estrategia)
  INVENTARIO, LLAVE, LLAVE DEL JEFE, CORAZÓN…
- [x] show_in_slot_summary en ItemData
- [x] Equipo de partida nueva en un .tres
- [x] Una sola función de capacidad

**Prueba:** Agarrar llave chica, llave del jefe, mapa, brújula, contenedor y pieza de corazón y un ítem nuevo: cada uno hace lo suyo (contador, minimapa, vida) y muestra su cartel. Partida nueva: espada, escudo de madera y túnica.

**Notas:** 51e51746: ItemData.OnGet (enum) en GameState.give y en los textos de ItemGet; show_in_slot_summary (arco, bolsa de bombas); ItemDatabase.new_game_equipment; ItemDatabase.capacity para Inventory y SaveCodec. Los chips de items_page siguen buscando íconos por id (no es una regla, es una búsqueda).

### 16.19 Wiring como componente en la escena · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`

Door y Gate repiten los handlers changed/settled con reveal, abrir y cerrar (door.gd:97-110, gate.gd:40-51); Bridge, CrackedWall y Chest repiten los exports switches/condition/reveal. Door (tipo switch) y Gate tienen el mismo `_fill_depth` y tween de hundirse. Los switches se reconocen por `active` + `activated` sin clase común.

- [ ] Nodo SwitchInput en el .tscn
  Dueño de switches, condition, stays_open y reveal_on_open; emite satisfied(animate)/unsatisfied.
- [ ] Barrera que se hunde compartida entre Gate y Door
  Opcional.

**Prueba:** Puertas y rejas con switches (de piso, ojo, antorcha): se abren al cumplir, las que no quedan abiertas se cierran al soltar, la que se revela hace el paneo solo la primera vez, y entrar a una sala con el switch ya cumplido la muestra abierta sin animar.

**Notas:** e5441dc1: Wiring.drive(target, open, close) es lo compartido de Door y Gate (revelar la primera vez, abrir, cerrar si no stays_open, abrir sin animar si arranca cumplida; ignora un target liberado). Sin nodo SwitchInput a propósito: los switches están en cada instancia de los niveles y el refresh de la_walls pierde los overrides de hijos en instancias. La barrera que se hunde compartida (opcional) no se hizo.

### 16.20 Behavior trees: reacciones de muerte, golpe y aturdido copiadas · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`

Las ramas is_dead→Death_A→on_death_finished, is_hit→Hit_A y stunned→Hit_B son iguales en enemy_bt, archer_bt y guard_bt, y atoq_bt las tiene con otras animaciones. Enemy._on_damaged/_on_died además de poner el flag del blackboard hacen `bt_player.restart()`: parece doble control con el selector dinámico.

- [x] Un BTSubtree de reacciones
  Animaciones como parámetros del blackboard.
- [x] Ver si el restart() hace falta

**Prueba:** Pegarle a un esqueleto (se sacude), aturdirlo dos veces seguidas (con escudo o bumerán), matarlo (animación de muerte completa): lo mismo con arquero y guardia.

**Notas:** 1150b37b: reactions_bt (BTSubtree) con Muerto/Golpeado/Aturdido para enemy_bt, archer_bt y guard_bt; los flags se limpian con Enemy.clear_reaction porque un BTSetVar dentro del subtree escribe en su propio scope. Atoq queda con sus ramas (otras animaciones). El restart() se queda: arranca la reacción en el mismo frame.

### 16.21 GameState: separar el estado de sesión y las piezas sueltas · Revisión

**Prioridad:** baja · **Tamaño:** L · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`

game_state.gd (473 líneas) tiene inventario, equipo, botones (con los de invitados), botellas, corazones, mazmorras, el mapa revelado, spawn y respawn, tiempo de juego e intros del jefe; `_process` lee Players. `room_entry` lo escriben la cámara, boss_arena y SceneFlow, y `boss_rematch` y `seen_boss_intros` no se guardan: la regla "estado del player global y en el save" queda mezclada con estado de sesión. GameState emite `inventory.changed` desde afuera para las botellas. Sigue a 11.86.

- [x] Session/Respawn propiedad de SceneFlow
  room_entry, boss_rematch, seen_boss_intros.
- [ ] ItemButtons, Bottles y MapProgress como RefCounted con su write/read
- [x] Las botellas emiten su propia señal
- [x] El tiempo de juego lo empuja la escena

**Prueba:** Llenar una botella en la fuente: el aro del HUD, el panel del player y la página de ítems la muestran llena. Morir y reaparecer en la entrada de la sala; perder contra un jefe y que la revancha y la intro ya vista se respeten; cargar partida y que todo eso se olvide. El tiempo de juego avanza.

**Notas:** 876b4303: SceneFlow.session (Session: room_entry, boss_rematch, seen_boss_intros) se limpia con la nueva señal GameState.cleared; las botellas emiten GameState.bottle_changed; el tiempo de juego lo suma Players. ItemButtons, Bottles y MapProgress como RefCounted no se hizo: GameState queda como lo que guarda el save y partirlo más no saca acoplamiento.

**Relacionadas:** 11.86 GameState: escrituras con señal y carga sin emisiones parciales

### 16.22 Tests que barren carpetas en vez de listas fijas · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `tests`

test_save_codec.gd:91 revisa 11 de los 20 escenarios firmados (faltan cumbre, quenoa, totora, gancho, chullpa_la, test_flags y los nuevos), así que la regla de "al sacar flags, correr test_save_codec" no cubre todo. test_flags mira 4 propiedades de flag (flag, solved_flag, defeated_flag, container_flag) y no reward_flag, reveal_flag ni required_flag, ni que estén registradas (en release el assert de set_flag no existe). test_attacks_load cubre 3 de 5 ataques y los configs solo player y test_box de 42; los AttackData del jefe no se revisan.

- [x] Escenarios: todos los .cfg de la carpeta
  Con lista de los que son inconsistentes a propósito.
- [x] Flags de niveles: toda propiedad que termine en _flag, y registrada
- [x] Ataques y configs: toda la carpeta
  active_from < active_to <= cancel_from; drops que resuelven.
- [ ] data/ sin ext_resource sin uid
  Y resave único de los que faltan.

**Notas:** e1b84b84: test_save_codec barre todos los escenarios (menos los inconsistentes a propósito, listados) y exige firma; test_data_sweep barre flags de niveles, ataques y configs. Los ~227 ext_resource sin uid de data/ necesitan un resave desde el editor.

**Relacionadas:** 16.3 Templo: el grafo pide `mirror_shield`, que no existe

### 16.23 Registros de flags e ítems: índice, ruta única y duplicados · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `datos`

`res://data/flag_registry.tres` está escrito en 5 lugares y la base de ítems en 3. `FlagRegistry._find` recorre las ~171 definiciones en cada get_flag/has. ItemDatabase no chequea duplicados y su caché @tool no se entera si se edita un id. `FlagDefinition.default_value` es Variant pero las 171 son bool. Las mazmorras (ch, qv, tt, cu, te) solo existen en el nodo Dungeon de cada nivel; DungeonGraph no tiene id y su `scene` es una ruta en texto.

- [x] const PATH en cada registro
- [x] Índice en FlagRegistry con chequeo de duplicados
  Igual en ItemDatabase.
- [x] Flags solo bool, o tipo con @export_enum
- [ ] Opcional: registro DungeonData
  id, escena por uid, grafo, prefijo y nombre; lo usan Dungeon y validate.

**Notas:** 8b91ea50: FlagRegistry.PATH e ItemDatabase.PATH, índice por id en runtime (lineal en el editor para ver ids editados), Registries.duplicates chequeado en test_flags, FlagDefinition.default_value bool. DungeonData (opcional) no se hizo.

### 16.24 Players.joined sale antes del _ready del player · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `bug`, `co-op`

El player se registra en `_enter_tree` (player.gd:53) y `joined` se emite ahí, cuando health, equipment y targeting todavía son null. Los que escuchan hoy sobreviven porque difieren o solo limpian una caché; reparentar un player emitiría left + joined.

- [x] Registrar en _ready o emitir diferido
  Documentar que joined = player listo.

**Prueba:** Co-op: un invitado se une en medio de una sala: aparece con su vida, equipo y apuntado, y el HUD lo muestra.

**Notas:** 9f51bd9c: el player se registra al entrar al árbol pero joined espera su ready. test_coop_state cubre un invitado que se une.

### 16.25 Nombres: una regla de idioma y archivos huérfanos · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-25 · **Etiquetas:** `refactor`

Se mezclan español e inglés en identificadores y archivos: AmbientePreset/AmbienteZoom, anillo_fuego.gdshader, sello_cima.tscn junto a temple_seal.tscn, data/ambientes junto a data/materials. `player/player.tres` es un VisualShader que nadie usa y se confunde con data/entities/player.tres. El autoload Items va por uid y los otros 13 por ruta.

- [x] Regla: código en inglés, lugares como nombres propios en español
  Anotarla en el GDD.
- [ ] Renombrar desde el editor
  Puente, para que se actualicen uids y rutas.
- [x] Borrar player/player.tres

**Decisiones:**
- ✓ Renombres: AmbientePreset/AmbienteZoom → AmbiencePreset/AmbienceZoom, data/ambientes → data/ambiences, los dos anillo_fuego → fire_ring (llamas) y explosion_ring (anillo de la bomba), sello_cima → summit_gate; la propiedad `ambiente` de Room queda igual
  Por qué: Regla del GDD §11.1 (código en inglés). Renombrar la propiedad de Room obligaba a reescribirla en todos los niveles.
  Descartado: Renombrar también Room.ambiente.

**Prueba:** Suite completa en main 773/773 (8de3d784).

**Notas:** 40e4d76d: la regla está en gdd.md §11.1 y player/player.tres se borró.
Renombres (-25, en el mismo commit que 16.26, main 8de3d784): AmbiencePreset/AmbienceZoom y test_ambience_preset, data/ambiences, src/world/look/fire_ring.gdshader (llamas del FireRing), src/world/vfx/explosion_ring.gdshader (anillo de la bomba), summit_gate.tscn (en el overworld la instancia ya se llamaba SummitGate). El autoload Items pasa a ruta como los otros 13. La propiedad `ambiente` de Room queda igual (renombrarla reescribía todos los niveles).

### 16.27 Probar GUT para los tests (con nuestro runner por procesos arriba) · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-25 · **Etiquetas:** `tests`

Daniel (2026-10-14): se puede probar, pero otro día. 1) Ver si GUT corre en 4.8-dev con un par de archivos. 2) Si anda, migrar la clase base (assert_eq/assert_true, misma API) y dejar run_tests.gd repartiendo procesos sobre GUT, para no perder las corridas en paralelo, el user:// por proceso y el ritmo de --fixed-fps 60. 3) Aparte de GUT: un timeout por archivo en run_tests.gd que mate un worker colgado y lo marque como falla (se encontraron workers de test_chullpa/test_templo colgados 4 horas).

**Decisiones:**
- ✓ ¿Pasamos los tests a GUT 9.7.1 (prueba de -25 en wt/gut-trial, eb15796d)?
  Por qué: 773/0 con GUT; mismo API de asserts; en paralelo como hoy (--jobs=2: 252 s contra 264 s del runner propio; 4 jobs 145 s). Suma addons/gut (plugin sin activar) y un aviso de versión inofensivo.
  Descartado: Seguir con el runner propio (tests/run_tests.gd), que ya anda igual de rápido.
  Respuesta: si GUT trae beneficios por sobre lo que ya tenemos, si.
- ✓ No adoptar GUT por ahora; la prueba queda en la rama wt/gut-trial (eb15796d) por si más adelante hace falta
  Por qué: Con la condición de Daniel ("si trae beneficios"), no los trae hoy: la velocidad es la misma (252 contra 264 s con 2 procesos, dentro del ruido), nuestro runner sigue haciendo el trabajo pesado arriba (procesos, user:// por worker, --fixed-fps, timeout de colgados) y lo único nuevo sería lo que no usamos (dobles/spies, tests parametrizados, el panel de GUT en el editor, JUnit para CI). A cambio suma un addon de terceros que no lista 4.8 y una capa más que mantener.
  Descartado: Adoptarlo ya para tener dobles y el panel del editor; adoptarlo cuando haya CI que lea JUnit.

**Prueba:** Suite con GUT en wt/gut-trial: 773/0. Main sigue con el runner propio.

**Notas:** Point 3 done (9d94ec88): run_tests.gd kills a worker that goes 300 s without finishing a test and counts it as a failure, naming the last test.
Puntos 1–2 (-25, rama wt/gut-trial eb15796d): GUT 9.7.1 en addons/gut (plugin sin activar), misma API de asserts; run_tests.gd sigue repartiendo archivos en procesos, un gut_cmdln por worker con --fixed-fps 60; saves/settings/tmp por worker vía variables EPI_TEST_* (GUT rechaza argumentos desconocidos); resultados leídos del JUnit XML; test_case.gd sigue fallando un test con error de script o sin asserts. 773/0; --jobs=2 252 s contra 264 s del runner propio; 4 jobs 145 s. Sin llamadas de red; el aviso "GUT 0.0.0 is now available" es ruido (versions.json no lista 4.8).
Arreglo aparte mergeado (541b7c10): test_boss_juice arranca con escena vacía (fallaba según el orden).
Daniel: "si GUT trae beneficios por sobre lo que ya tenemos, si" → -ae: no los trae hoy, no se adopta (decisión 2, para revisar). La rama queda para cuando hagan falta dobles o CI con JUnit.

### 16.26 Orden de carpetas y lo que entra en la build release · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-25 · **Etiquetas:** `refactor`, `build`

La cámara de juego (505 líneas) y target_indicator están en src/tools/ junto a scripts de build; un EditorScript en src/debug/; Log y DebugOverlay (autoloads de runtime) en un addon, y DebugOverlay arma su Label por código; los BT entre src/entities/ y data/boss/; las escenas de prueba (test*, prueba_mc_godot, pruebas_terreno, sandbox_items, test_shinobi) en levels/ se exportan porque el filtro solo excluye tests/*; `player/animation/new_animation_node_state_machine.tres` con nombre por defecto; Feel cargado antes que MenuStack (por eso lo busca diferido).

- [ ] Escenas de prueba a levels/test/
  Y excluir la carpeta en export_presets.cfg.
- [ ] Cámara a src/camera/
  Mover desde el editor (puente) para que se actualicen uids y rutas.
- [ ] Scripts de build a tools/
  Los de src/tools/ que corren headless.
- [ ] BT junto a su entidad o en data/ai/
- [ ] Debug runtime a src/debug/
  Log y DebugOverlay; el overlay como .tscn.
- [x] Orden de autoloads
  MenuStack antes que Feel; conectar `MenuStack.changed` directo.
- [ ] Renombrar el .tres por defecto
- [x] Excluir tools/, src/tools/build_*, debug/ y los niveles de prueba del release
  export_presets.cfg solo saca tests/*, *.md y debug/scenarios/*; entran levels/test*, prueba_mc_godot, pruebas_terreno, ejemplo_ambiente, debug/la/ y los scripts de build.
- [x] Sacar el autoload ToonToggle
  El toon está rechazado y precarga epiphany_toon.tres en release; test_shinobi lo agrega solo si lo necesita.
- [x] test_export mira las exclusiones
- [ ] Partir src/world en puzzles/, dungeon/, props/ y overworld/
  114 archivos sueltos; mover desde el editor.

**Decisiones:**
- ✓ Mapa de carpetas: cámara a src/camera/, BT del jefe junto al jefe y los de enemigos en data/ai/, Log y DebugOverlay a src/debug/, escenas de prueba a levels/test/; new_animation_node_state_machine.tres borrado en vez de renombrado
  Por qué: Plan de -25 aprobado por -ae; el .tres de la máquina de estados no lo usaba nada desde el primer commit. Partir src/world queda para cuando -88 y -8f no tengan cambios ahí.
  Descartado: BT de enemigos en carpetas por entidad (archer_skeleton no tiene carpeta propia y tres BT son compartidos).

**Prueba:** --import y suite completa en main: 773/773 (8de3d784). test_export (exclusiones nuevas), test_save_codec (escenarios re-firmados). grep de rutas viejas en todo el árbol: solo historia en compass/docs.

**Notas:** ce108f6c: los presets release (Linux, Windows, macOS, Web) excluyen debug/, tools/, src/tools/build_*, profile_scenes, render_music y los niveles de prueba por nombre; test_export lo mira y chequea que título, overworld y SceneFlow no dependan de nada excluido. ToonToggle ya no es autoload (nodo en test_shinobi). MenuStack carga antes que Feel.
Movimientos (-25, bfe4a974 → main 8de3d784, con 16.25), en disco con el editor cerrado porque el editor no tiene API para mover: los .uid viajan con su archivo, las líneas uid= quedan, todas las rutas res:// reescritas (escenas, recursos, scripts, shaders, project.godot, export_presets, tests, tools, debug/scenarios, gdd.md).
- levels/test/: test*, test_rooms, test_shinobi, test_targeting, prueba_mc_godot, pruebas_terreno, ejemplo_ambiente, sandbox_items, dungeon_test. Exclusión release: tests/*, *.md, debug/*, tools/*, levels/test/*.
- src/camera/: top_down_camera, camera_reveal, camera_occlusion, room_mask, target_indicator.
- tools/: build_gray_kit, profile_scenes, render_feel_sfx, render_music y resource_converter (EditorScript).
- BT: boss_phase1-3_bt a src/entities/boss/; enemy, reactions, guard y archer a data/ai/.
- src/debug/: Log, log_sink, debug_overlay (lo del editor queda en el addon).
- new_animation_node_state_machine.tres y su _playback borrados (sin uso).
- 5 escenarios re-firmados (dungeon_test, full_inventory, gancho, test_flags, test_rooms).
- Partir src/world: pendiente, cuando -88 y -8f no tengan cambios ahí.
- El primer arranque después del merge loguea errores de la caché de uids de .godot; -ae corrió --import dos veces en main y el segundo sale limpio.

**Archivos:** `export_presets.cfg`, `project.godot`

**Relacionadas:** 11.59 Limpieza de assets sin uso

### 16.28 Animaciones a AnimationPlayer: HUD y UI · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `animacion`

Daniel (2026-10-17): lo animado por código pasa a AnimationPlayer (AnimationTree cuando hay estados o mezclas), para verlo y ajustarlo en el editor. Los tweens quedan solo para destinos calculados en runtime y esperas. HUD: nombre de zona, cartel de guardado, barra del jefe (entrar y salir); sacudida del slot del panel; pop del corazón; flecha del cuadro de texto; indicador de objetivo (bob y giro).

**Notas:** f436841e: nombre de zona, cartel de guardado y barra del jefe con su AnimationPlayer cada uno en hud.tscn; sacudida del slot (hud_item_slot.tscn), pop del corazón (heart_icon.tscn), flecha del cuadro de texto e indicador de objetivo en clips en bucle. Quedan en código: la vida de la barra del jefe (sigue un valor), el fundido de SceneFlow (duración por llamada) y el giro del modelo en Equipo.

### 16.29 Animaciones a AnimationPlayer: props del mundo · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `animacion`

Daniel (2026-10-17): lo animado por código pasa a AnimationPlayer (AnimationTree cuando hay estados o mezclas), para verlo y ajustarlo en el editor. Los tweens quedan solo para destinos calculados en runtime y esperas. Puerta, reja, puente, cofre, pinchos, pared agrietada, escalera de soga, anillo de fuego y rompibles (sacudida, corte, caída). Reja y puente animan su raíz: pasar a un hijo. sink/drop se cambian por instancia (puerta sink 3.2 en 30 instancias): llave normalizada 0..1 multiplicada por el export.

**Notas:** c2af15d3: puerta, reja (y sello del templo), puente, tapa del cofre, pinchos (asomar, subir, bajar), sacudida de la pared agrietada, escalera de soga y anillo de fuego en clips de su escena. Puerta, reja y puente animan un 0..1 (openness/height) que multiplica su sink/drop: los valores por instancia siguen valiendo. Clips.run corre un clip en la duración de cada instancia, para adelante o para atrás desde donde esté. Quedan en código los rompibles (pasto y plantas se instancian por cientos y la caída sigue al golpe), el bloque empujable y el espejo giratorio (destino calculado).

### 16.30 Animaciones a AnimationPlayer: efectos de feel · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `animacion`

Daniel (2026-10-17): lo animado por código pasa a AnimationPlayer (AnimationTree cuando hay estados o mezclas), para verlo y ajustarlo en el editor. Los tweens quedan solo para destinos calculados en runtime y esperas. Teletransporte (salida y llegada), anillo del rugido, onda de choque, explosión, giro y parpadeo de los pickups, luz del ItemGet, flotar del Espíritu. Opcional: parpadeo de antorchas y stencil light.

**Notas:** 27aa401a: teletransporte en dos clips (depart, arrive) con la silueta y visibilidad del player por propiedades que reenvían, esfera, rayo y luz, y sonido y temblor como method tracks; anillo del rugido con grow/travel 0..1 que escalan size y reach de cada jefe; onda de choque y explosión (flash, bola de fuego, anillo) en clips; pickups giran y parpadean con clips; luz del ItemGet y flotar del Espíritu en player.tscn. Quedan en código: hit flash y afterimage (la duración la pide quien llama), el parpadeo de la mecha de la bomba (se acelera) y el parpadeo de antorchas. El tamaño de la bola de fuego ahora está en el clip (2.2, el radio de la explosión).

### 16.31 Animaciones a AnimationPlayer: sub-jefes · Revisión

**Prioridad:** media · **Tamaño:** L · **Responsable:** project-epiphany-17 · **Etiquetas:** `refactor`, `animacion`

Daniel (2026-10-17): lo animado por código pasa a AnimationPlayer (AnimationTree cuando hay estados o mezclas), para verlo y ajustarlo en el editor. Los tweens quedan solo para destinos calculados en runtime y esperas. Primero un helper en ArenaFighter para clips con speed_scale = pace. Momia, Ojo Vigía (open exportado), Amaru/Yacumama, Centinela, Kuntur (alas en AnimationTree), torreta y hundirse del enemigo al morir. Las alturas que cambian por instancia (hover_height, leap_height, rise_height) se normalizan antes. Los movimientos de la raíz hacia el player o puntos de la arena quedan en código.

**Prueba:** tests/test_arena_fighter.gd, test_centinela.gd, test_kuntur.gd, test_quenoa.gd

**Notas:** Hecho en main (35dc0a89..4b6842bb). Momia, Ojo Vigía, Amaru/Yacumama, Centinela, Kuntur, torreta y el hundirse del enemigo usan clips en %Moves (ArenaFighter._clip: speed_scale = pace, estirado a la duración de la instancia). Alturas por instancia normalizadas (lift, hover/rise, submerge, tail_up, squash, sunk). Alas del Kuntur: un AnimationPlayer %Wings con un clip por pose y cruce con play(pose, blend) en vez de AnimationTree (cada cambio trae su tiempo de mezcla). Centinela: aim_lock y warn_lead pasaron a ser llamadas del clip windup. Todos los AnimationPlayers nuevos con deterministic = false y cortes con stop(true). Para probar: pelear cada sub-jefe y mirar rugido, saltos, temblor trabado y muerte; Kuntur: alas en cada ataque.

### 16.32 Animaciones a AnimationPlayer: jefe final (ojo y manos) · Revisión

**Prioridad:** baja · **Tamaño:** L · **Responsable:** project-epiphany-5c · **Etiquetas:** `refactor`, `animacion`

Daniel (2026-10-17): lo animado por código pasa a AnimationPlayer (AnimationTree cuando hay estados o mezclas), para verlo y ajustarlo en el editor. Los tweens quedan solo para destinos calculados en runtime y esperas. Ojo: blink, roar, awaken, carga del láser y del orbe, relax, flare, sacudida, muerte; marcas y blasts en sus plantillas; flotar y aturdido en AnimationTree. Manos: un AnimationPlayer por mano para aturdida, desaparecer, colapsar, onda, aviso del agarre, flex. El resorte de _animate queda en código. Tocar boss.tscn solo cuando Daniel no tenga cambios sin commitear ahí.

**Notas:** -5c (2026-10-19): done in 34cb4107. Eye: clips on Lids (roar, awaken, scream, death), Blink, Charging (orb_charge, laser_charge, relax), Glow, Flare and Pupil, driven by eye_shine, body_shine, charging and sink. Float and stunned live in the Float AnimationTree (closed, open, stunned, with xfade and curves). Marks and blasts: an Anim player in their templates. Hands (boss and hand guard): Anim (stunned, grab_warn, collapse, vanish, flex) and Wave, from shared libraries boss_hand_anim.tres and boss_hand_wave.tres. Still in code: the jolt when the eye is hit (random rotations), the hit tint, the _animate spring, the slam/sweep moves and the laser (runtime targets). 673/0.

### 16.33 Mezclas del player en el AnimationTree, no con tweens · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-5c · **Etiquetas:** `refactor`, `animacion`

Daniel (2026-10-17): lo animado por código pasa a AnimationPlayer (AnimationTree cuando hay estados o mezclas), para verlo y ajustarlo en el editor. Los tweens quedan solo para destinos calculados en runtime y esperas. carrier, shield y aiming_item tweenean blend_amount del AnimationTree: pasar a Transition con xfade_time.

**Notas:** Hecho en wt/art (4e7ad654). Carry pasó a Transition (Off/On, xfade 0,12; su estado inicial guardado en el árbol, si no la cadena de abajo no corre). Guardia y arco no pueden ser Transition: Transition ignora los filtros (FILTER_IGNORE en el código de Godot) y los dos mezclan solo el torso; pasaron a OneShot con fadein/fadeout, disparados y apagados como UseItem. Melee_Blocking y Ranged_Bow_Draw sostienen su último cuadro con un timeline propio largo, así el OneShot no termina solo. test_shield: la guardia mueve el brazo del escudo y no las piernas.

### 16.34 call_group al HUD y a la cámara: acceso tipado y señales · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-72 · **Etiquetas:** `refactor`

Revisión con patrones (2026-10-19): 15 llamadas con nombre de método fallan en silencio si se renombra. Cámara: TopDownCamera.current(tree) tipado. HUD: tres señales tipadas (anuncio de zona, mostrar/ocultar barra del jefe). Sin EventBus completo.

**Notas:** Hecho (-72): TopDownCamera.current(tree) (estático, tipado) reemplaza los call_group a la cámara en stairs, pit y scene_flow._place_at_spawn, y los get_first_node_in_group (music, cutscene, room, doom_ambience, map_data, scene_flow.location, 4 tests). En la cámara solo cambió el punto de acceso; 16.54 no tiene nada que limpiar. HUD: Hud.events (clase interna Events, static var) con tres señales tipadas: area_announced(text), boss_shown(bar: BossBar), boss_hidden. Cada Hud las conecta en _ready; al liberarse, Godot lo desconecta. Emisores: room, area_zone, arena_fight, boss_arena. No queda call_group en src. Test: test_hud › test_events_reach_the_hud.

### 16.35 Nodos creados por código: pasto, overlay y buses de audio · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-e0 · **Etiquetas:** `refactor`

Revisión con patrones (2026-10-19): GrassPatch instancia el pasto en _ready; DebugOverlay crea su Label; Feel y Settings crean buses de audio (falta default_bus_layout.tres).

**Notas:** Hecho (-e0): default_bus_layout.tres con Music, SFX, UI y Ambience; Settings y Feel ya no agregan buses por código (Settings.BUSES se fue). DebugOverlay es debug_overlay.tscn con su Label, autoload de la escena (y el plugin lo registra así). Ojo: un autoload .tscn no tiene tipo estático, por eso aim.gd tipa var debug: bool. GrassPatch sigue plantando en _ready a propósito: es un componente de ubicación con semilla (3 parches) y hornearlo reescribiría overworld.tscn.

### 16.36 Sonidos de Feel: pool, límite y síntesis al arrancar · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-e0 · **Etiquetas:** `refactor`, `audio`

Revisión con patrones (2026-10-19): Cada sfx crea un player nuevo sin límite: N sonidos iguales en el mismo cuadro saturan. Feel sintetiza ~10 s al arrancar que después reemplaza con .ogg. Los sonidos de UI salen del input crudo.

**Notas:** Hecho (-e0): Feel.sfx corta en MAX_SAME_PER_FRAME = 3 copias del mismo sonido por cuadro y MAX_VOICES = 24 sonidos del mundo a la vez (corta el más viejo). Los reproductores siguen en la escena (no un pool bajo Feel): así se pausan y se van con el nivel como hoy, y test_boss mide el temblor de la intro en el nivel. Las recetas de síntesis solo corren para los sonidos sin .ogg (antes ~10 s al arrancar que se tiraban). El sonido de aceptar sale del pressed del botón con foco, no del ui_accept crudo; el de volver sigue en ui_cancel con foco. test_audio › test_sounds_in_one_frame_are_capped.

### 16.37 Componentes que asumen su padre y la guardia copiada · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `refactor`

Revisión con patrones (2026-10-19): input_buffer, equipment, carrier, zone_veil, enfoque_la usan get_parent/owner; la guardia del escudo se apaga a mano en 5 estados (usar active_state_changed). doom_ambience: cadena de clases en vez de grupo.

**Notas:** Hecho (-e0): InputBuffer y Equipment exportan player (y Equipment visuals), Carrier exporta thrower, conectados en player.tscn. EnfoqueLA lee la cámara del viewport en vez de su padre (sin rehornear niveles). ZoneVeil queda para 16.44 (-3e, quizás se borra). La guardia se sincroniza en active_state_changed de la máquina del player: los 5 estados que la bajaban a mano ya no lo hacen. doom_ambience.is_legible queda con la cadena de clases a propósito: un grupo obligaría a etiquetar cada pickup/rompible puesto en niveles guardados por el editor y los drops creados por código, y is ya cubre las subclases. test_shield › test_dodging_lowers_the_guard_at_once.

### 16.38 Rendimiento: trabajo por cuadro sin cambios · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-e0 · **Etiquetas:** `refactor`, `rendimiento`

Revisión con patrones (2026-10-19): Minimapa (redibuja y escanea grupos cada cuadro), Room.has_player por tick, Targeting._sync_posts, Music.targets, overworld_map._reveal. Después de los assets.

**Notas:** Done (7dbbba82): the minimap redraws only when something changes (plus every 0.25 s) and counts floors once; Room.has_player looks up the camera once per physics frame; _sync_posts exits without the hookshot; OverworldMap reads the veils once. Music.targets left alone: it's cheap.

### 16.39 Spawns.root salteado, Dungeon como hijo directo y checksum sin uso · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `refactor`

Revisión con patrones (2026-10-19): carrier, bomb, dodge_ghosts, liftable usan current_scene; SceneFlow busca Dungeon/AreaZone solo entre hijos directos; save_tampered se escribe y nadie lo lee.

**Notas:** Hecho (-e0): carrier, bomb, dodge_ghosts y liftable cuelgan/reparentan bajo Spawns.root en vez de current_scene. Dungeon entra a un grupo y Dungeon.current(tree) devuelve la de la escena actual (la anterior puede seguir en el grupo un cuadro al cambiar), así SceneFlow (id de la mazmorra y ubicación de la ranura) no necesita que sea hija directa; las zonas salen de AreaZone.GROUP. GameState.save_tampered (se escribía y nadie lo leía) se fue; la carga lo sigue registrando en el log. 157 pruebas relacionadas, 0 fallos.

### 16.40 AnimationPlayers que faltan con deterministic = false · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-5c · **Etiquetas:** `refactor`, `animacion`

Revisión de 16.28-16.31 de la sesión de arte (2026-10-19): Sin deterministic = false (cambiar de clip resetea lo que el nuevo no anima): cutscene.tscn, scene_flow, warp_portal, travel_portal, temple_eye_glow, centinela_model; boss.tscn va con 16.32.

**Notas:** Hecho en wt/art (c5525be4). deterministic = false en cutscene (y su Outro), scene_flow, warp_portal, travel_portal, temple_eye_glow, centinela_model y también atoq (mismo caso que el centinela). Ninguno de estos tenía un cambio de clip que se rompiera hoy (los modelos animan los mismos huesos en todos sus clips y el resto tiene un solo clip), así que en vez de un test de un caso inventado, test_animation_players barre src, levels y player: falla si un AnimationPlayer no lo tiene. Los que alimentan un AnimationTree quedan afuera (los mezcla el árbol); boss.tscn espera a 16.32.

### 16.41 Clips que arrancan de claves fijas en vez del valor actual · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-5c · **Etiquetas:** `animacion`

Revisión de 16.28-16.31 de la sesión de arte (2026-10-19): Nombre de zona re-mostrado salta el alfa a 0 (hud.gd:157); ocultar la barra del jefe durante su entrada salta a 1; el volteo del ojo vigía arranca los párpados en 1; el temblor de la momia arranca en -0.2; el salto de la momia sube en 0.33 s con aim_time 0.9 (chullpa, templo). El pop del corazón perdió el rebote y el anillo del rugido pasó a ease-in. heart_piece.gd:27 tapa Pickup.shown.

**Notas:** Hecho en wt/art (05b03a42). HUD: _restart arranca el clip donde su alfa ya vale lo que tiene el nodo (re-mostrar el nombre de zona o esconder la barra del jefe a mitad no salta); test_hud lo cubre. Ojo vigía: knock captura los párpados (update capture). Momia: stuck arranca de 0; leap sube en 0,4 s y la sombra crece en aim_time en su propio AnimationPlayer (%Aim). Pop del corazón con rebote (0,97 a los 0,11 s). Anillo del rugido: fundido lineal como el tween. heart_piece: la variable local ya no tapa Pickup.shown.

### 16.42 Animaciones que siguen en código · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-5c · **Etiquetas:** `refactor`, `animacion`

Revisión de 16.28-16.31 de la sesión de arte (2026-10-19): Parpadeo de la bendición (blessing.gd:29), titileo de stencil_light (:42), rebotes y alturas fijas del Kuntur (kuntur.gd:197-374), fundido de barras de la cinemática (cutscene.gd:107), radio del velo de zona (zone_veil.gd:76), cámara del título (title_flyover.gd, PathFollow3D). demo_tajo queda aparcada.

**Notas:** Hecho en wt/art (46929781). Kuntur: alturas fijas y rebotes en %Height (clips de una clave con captura; play_with_capture con la curva espejada, porque la captura la aplica al revés); hover_height y posiciones siguen en tween (destinos del momento). Cinemática: barras y texto en el clip settle de %Outro; la cámara sigue en tween hacia la de juego. ZoneVeil: clip reveal 0..1 escalado a la esquina más lejana, con hide al final. Bendición: clip blink en loop. StencilLight: clip flicker en loop (los dos senos, período exacto 20π/7 s) con arranque al azar; torch_flicker queda en código como se decidió en 27aa401a. Título: un clip flight en loop horneado desde las tomas viejas (Shots se borró; las tomas se editan en el clip).

### 16.43 Mapa explorado del overworld se borra si cambia world_rect · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`, `bug`

Revisión de arquitectura del overworld (-3e, 2026-10-19): GameState.ensure_map_revealed (game_state.gd:114) recrea map_revealed vacío si cambia el tamaño, y el origen del rect no se guarda: agrandar world_rect borra el mapa explorado de cada partida, y entrar a levels/test.tscn (otro OverworldMap) también. Arreglo: reveal por id de mapa, guardar el rect y recortar/remapear en vez de borrar.

**Prueba:** tests/test_minimap.gd

**Notas:** Hecho por -3e (c6a2764b): lo descubierto va por id de mapa con su origen (GameState.map_reveals / map_reveal_origins, SaveKeys.REVEALS); si cambia world_rect se remapea; las partidas viejas migran a "overworld". Para probar: cargar una partida vieja con el mapa explorado y abrir el mapa.

### 16.44 ZoneVeil sin uso pero consultado cada cuadro · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`

Revisión de arquitectura del overworld (-3e, 2026-10-19): Ningún nivel instancia zone_veil.tscn y overworld_map._reveal() hace get_nodes_in_group(ZoneVeil.GROUP) + filter cada cuadro (title_flyover también). Arreglo: borrar ZoneVeil y sus ramas o cachear. Si se borra, sale el velo de 16.42 y el _reveal de 16.38.

**Notas:** Daniel (2026-10-20): ZoneVeil stays (the GDD has the gruta and the santuario covered).

### 16.45 Regiones del overworld como recurso ZoneRegion · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`

Revisión de arquitectura del overworld (-3e, 2026-10-19): Una región hoy es 'zonas con el mismo display_name', una clave de traducción usada como identidad (map_page.gd 420, 438, 552, 595; el chequeo del HUD de AreaZone; el respaldo de persecución). region_label y chase_region sueltos en 34 zonas. Arreglo: un .tres ZoneRegion por región (id, display_name, grupo de persecución, etiqueta del mapa).

### 16.46 Test: las zonas del overworld cubren el mapa sin pisarse · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`, `tests`

Revisión de arquitectura del overworld (-3e, 2026-10-19): Nada verifica que los 34 rects de AreaZone no se superpongan ni dejen celdas caminables sin cubrir (se chequeaba con scripts temporales). Agregarlo a test_overworld.

### 16.47 Test: terreno_overworld.json coincide con el nivel · Revisión

**Prioridad:** media · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`, `tests`

Revisión de arquitectura del overworld (-3e, 2026-10-19): El nivel y tools/terreno_overworld.json se desfasan sin aviso (un punto pasó de -38.4 a -37.5 sin rebuild). Arreglo: un test que corre el export en memoria y lo compara con el JSON commiteado (= hace falta rebuild del terreno).

**Notas:** Hecho (-3e): export_terreno_overworld.gd tiene un build(level, forced) estático que devuelve el dict; la CLI escribe el mismo archivo. test_overworld › test_the_terrain_json_matches_the_level compara un export en memoria con el JSON commiteado y dice la clave y el primer índice distinto (con el JSON viejo falla en fixed[305], SummitStairsUp que movió 11.29). JSON regenerado, terreno NO rehecho: el build de Blender no es determinista (ver 16.51).

### 16.48 El export del terreno elige nodos por convenciones de nombre · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`, `arte`

Revisión de arquitectura del overworld (-3e, 2026-10-19): export_terreno_overworld.gd depende del prefijo Zone_, el sufijo Mouth, scene_file_path exacto, wade_speed por duck typing y una lista IGNORED; build_terreno_organico.py nombra muros muro_<NodoGodot> que overworld.tscn referencia. Renombrar un nodo cambia el terreno o deja una malla huérfana. Arreglo: elegir por grupo/script y dar a las paredes agrietadas un id exportado estable.

**Notas:** Hecho (-3e): el export del terreno elige nodos por clase y grupo, no por nombre. _is(node, "Clase") sin tipar (corre con --script) mira la clase de Godot o el global_name del script y sus bases. IGNORED es una lista de clases (AreaZone, ShallowWater, PlayerCharacter, OverworldMap y tipos del motor) en vez del prefijo Zone_ y el duck typing de wade_speed. CrackedWall, HookPost y EyeSwitch por clase; las 7 bocas de cueva en el grupo cave_mouths en vez del sufijo Mouth; CrackedWall.terrain_id con los nombres actuales (los .res muro_/tapa_ no cambian). JSON regenerado idéntico byte a byte. test_every_cracked_wall_has_its_terrain_rock. overworld.tscn: solo agregados.

### 16.49 El grupo de la baranda del terreno depende de la tira donde cae · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`

Revisión de arquitectura del overworld (-3e, 2026-10-19): terreno_organico.tscn pone walk_guard con un override en Parte5/baranda; si un rebuild la mueve a otra tira se pierde sin aviso. Arreglo: propiedad custom desde Blender aplicada por epi_scene_import.

### 16.50 TerrainStyleArea.style como enum; el build falla con estilo desconocido · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `overworld`, `arte`

Revisión de arquitectura del overworld (-3e, 2026-10-19): Un typo en style cae en silencio al terreno por defecto (STYLES.get(style, {})). Arreglo: @export_enum con las claves de STYLES y que Python falle con un estilo desconocido.

### 16.51 Build del terreno determinista · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `arte`

Revisión de arquitectura del overworld (-3e, 2026-10-19): Reconstruir build_terreno_organico.py reescribe muros_organicos.glb y plantas_overworld.json con ruido de ~1 mm y deja diffs ruidosos. Encontrar el origen y redondear o fijar semilla.

**Notas:** -3e, 2026-10-19 (16.47): el ruido es mayor que ~1 mm. Dos builds desde el mismo terreno_overworld.json dan distinta cantidad de vértices en 11 de las 12 tiras de terreno_organico (solo .0 sale igual), y muros_organicos.glb mueve hasta 2,7 m por índice. Por eso en 16.47 se regeneró el JSON sin rehacer los glb. Hasta arreglarlo, que el JSON coincida con el nivel no prueba que los glb estén al día.

Follow-up 2156b5d6 (-3e): the fixed faces were losing their mark in the canonical sort and recalc_face_normals flipped them (0.11 of the area facing up); fixed, two builds identical again.

### 16.52 Escoltas de ArenaFight pierden sus overrides de instancia · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `overworld`, `combate`

Revisión de arquitectura del overworld (-3e, 2026-10-19): arena_fight.gd:55-58,168-172 libera las escoltas puestas a mano y las recrea con load(scene_file_path), conservando solo el transform; se conectan con connect(&"defeated") y is_dead por duck typing. Arreglo: duplicate() del nodo original, o PackedScene + Marker3D con señal tipada.

**Notas:** Hecho (-e0): las escoltas puestas a mano se empaquetan (PackedScene.pack) en _enter_tree de ArenaFight, antes de entrar al árbol y de su _ready, así cada pelea las instancia como están en el nivel (con los overrides de sus hijos) en vez de recargar su escena; tipadas Enemy y conectadas a defeated. No sirvió duplicate() (crashea la 4.8 beta con una instancia suelta ya lista) ni empaquetar después de _ready (guarda estado de runtime). test_centinela › test_escorts_keep_their_instance_overrides (falla sin el arreglo).

### 16.53 Limpiezas menores del overworld · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-e0 · **Etiquetas:** `overworld`

Revisión de arquitectura del overworld (-3e, 2026-10-19): collision_layer/mask/monitorable a mano en 7 scripts de sensores (area_zone, tremor_zone, pit, portal, travel_portal, shallow_water, stairs) → en el .tscn o constantes de capa; bounds() repetido (area_zone, arena_area, room) → un helper; ArenaArea sondea players cada cuadro → señales de Area3D; constantes de eye_switch y look-at repetido con eye_follow → exportar y compartir; brillo_la.gd cambia materiales en cada node_added → paleta brillante .tres al importar; enfoque_la.gd consulta un grupo cada cuadro → cachear (se cruza con 16.37).

**Notas:** Hecho (-e0): PhysicsLayers (src/world/physics_layers.gd) nombra las capas del proyecto y PhysicsLayers.sensor(area) arma los 7 sensores (area_zone, tremor_zone, pit, portal, travel_portal, shallow_water, stairs) en vez de escribir layer/mask/monitorable a mano; los números copiados de hurtbox/object/interactable apuntan ahí. BoxBounds.xz es el único bounds() de Room, AreaZone y ArenaArea. EyeSwitch exporta look_range, look_limit_deg y look_speed (grupo Mirada); EyeFollow mueve un iris y EyeSwitch gira el ojo, no comparten mirada. Quedan para 16.38 (después de los assets): el sondeo de ArenaArea, el grupo que consulta enfoque_la por cuadro y los materiales de brillo_la por node_added. 331 pruebas relacionadas, 0 fallos.

### 16.54 TopDownCamera hace demasiado · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-72 · **Etiquetas:** `refactor`

Auditoría con patrones de diseño (-72, 2026-10-19): top_down_camera.gd tiene 813 líneas y 8 @export_group (lock-on, look, apuntado, reveals, cinemática, salas, oclusión, co-op); diseño y arte editan los reveals en el mismo archivo (pasó con AmbienteZoom). Arreglo: Reveal y Occlusion como nodos hijos en la escena de la cámara. Coordinar con arte.

**Notas:** Hecho (-72): escena nueva src/tools/top_down_camera.tscn: raíz TopDownCamera e hijos Reveal (CameraReveal: pan_time, look = zoom.tres, tone_time, hold, zoom; hace el reveal, el salteo y SKIP_ACTIONS) y Occlusion (CameraOcclusion: overhead_time, overhead_hold; rayos, resorte de arriba, player_hole). Cada parte con sus exports; el ajuste de AmbienteZoom va en Reveal.look. La cámara baja de 825 a ~630 líneas y mantiene su API pública. Los 17 niveles instancian la escena (el de test_targeting se llama Camera); solo cambió el encabezado y la línea del script; ningún nivel sobreescribía reveal_*/overhead_*. Prueba de refresh en chullpa: overrides y EnfoqueLA/Polvo sobreviven al repack (ahí salió el bug current=Callable, arreglado en 80b84b1a con TopDownCamera.find). test_camera › test_every_level_instances_the_camera_scene. gdd actualizado.

### 16.55 Enemy carga la defensa de dos variantes · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-72 · **Etiquetas:** `refactor`

Auditoría con patrones de diseño (-72, 2026-10-19): enemy.gd:231-325 (guardia _guard_stops; coraza _armor_stops/_break_armor/_fling_armor) solo lo usan shield_skeleton y armored_skeleton, y conoce Hook.ELEMENT (enemy.gd:292), una clase de ítem. Arreglo: componentes Guard y Armor (Node) con @export, el elemento como propiedad de la coraza. No es la guardia del player de 16.37.

**Notas:** Hecho (-72): escudo y coraza son componentes de escena con @export. EnemyGuard (enemy_guard.gd, nodo Guard en shield_skeleton.tscn: body, pose, angle_deg, break_time; señal blocked(push)) y EnemyArmor (enemy_armor.gd, nodo ArmorPlate en armored_skeleton.tscn: body, mesh, torn_by = &"hook"; señal broken). El elemento es propiedad de la coraza: enemy.gd ya no conoce Hook.ELEMENT ni ARMOR_PIECE. Enemy exporta guard/armor y mantiene is_guarding/shield_up/is_armored/recoil. EntityConfig pierde guards_front/guard_angle_deg/guard_break_time/armored (fuera de los 3 .tres). Las 8 variantes de guerreros y el huanca heredan los nodos. gdd actualizado. 66 archivos de tests, 432 pruebas, 0 fallos.

### 16.56 Pantallas tipadas por convención · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-72 · **Etiquetas:** `refactor`

Auditoría con patrones de diseño (-72, 2026-10-19): menu_stack.gd:50/74/120 y pause_menu.gd:37/49 usan has_method(&"screen_covered"/"screen_uncovered"/"focus_default"/"cancel"): un typo en una pantalla se ignora en silencio. Arreglo: clase base MenuScreen (extends Control) con virtuales vacías.

**Prueba:** tests/test_ui_scenes.gd

**Notas:** Hecho (-72): ya existía UiScreen (src/ui/ui_screen.gd) con las virtuales y la pila tipada; los has_method eran por la raíz y las pestañas. La pantalla de título pasa a extender UiScreen y MenuStack tipa _base/set_base/covered/uncovered/_focus como UiScreen, sin has_method. Las cuatro pestañas del menú de pausa extienden PausePage (src/ui/menus/pause_page.gd: focus_default con el primer control enfocable como antes, cancel false) y pause_menu las llama tipadas. No queda has_method en src/ui. test_ui_scenes › test_every_screen_on_the_stack_is_a_ui_screen: cada script que hace MenuStack.push está en PUSHED (si se agrega uno nuevo, falla hasta sumarlo), cada escena empujada y el título tienen UiScreen de raíz, y cada pestaña es PausePage.

## M13 — Co-op local (estilo Four Swords)  (1/17)

Dos jugadores en la misma pantalla recorren el overworld y el templo juntos, con progreso compartido y puzzles que aprovechan a los dos.

**Hecho cuando:**
- Dos controles juegan una partida de punta a punta (overworld, templo y jefe) sin bugs de cámara ni de salas.
- Hay al menos tres puzzles que piden a los dos jugadores.
- Un solo jugador puede seguir jugando como siempre.

### 13.1 Código listo para varios players · Pausado

**Prioridad:** alta · **Etiquetas:** `coop`, `arquitectura`

Preparar el código para más de un player: un registro `Players` con señales que reemplace las referencias al grupo "player" y los `get_first_node_in_group`, para que ningún sistema asuma un solo jugador y el co-op tenga dónde apoyarse.

- [x] Registro de players
  Un autoload o nodo `Players` con la lista y señales (joined/left); reemplaza las ~40 referencias al grupo "player" y los get_first_node_in_group.
- [x] Regla para lo nuevo
  Desde ahora ningún sistema asume un solo player (anotado en GDD §13).
- [x] Tests
  Los tests existentes pasan con 1 player; uno nuevo instancia 2 y revisa que salas, HUD e IA no se rompan.

**Prueba:** Con 1 player el juego es idéntico; instanciar un segundo player no tira errores en overworld ni templo.

**Notas:** Skills: `godot:godot-nodes-scenes`, `disciplines:input-systems`, `disciplines:camera-systems`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 13.2 Input por jugador y unirse a la partida; 13.3 Cámara y salas para dos; 13.4 Reglas del co-op; 13.5 HUD de dos jugadores; 13.6 Player 2 con su color; 13.7 Enemigos y jefe con varios objetivos; 13.8 Puzzles cooperativos

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 13.2 Input por jugador y unirse a la partida · Pausado

**Prioridad:** alta · **Etiquetas:** `coop`, `input`

Que cada player lea su propio control (teclado+mouse cuenta como uno) con su buffer, apuntado y targeting, y que un segundo control pueda sumarse o salir con Start en cualquier momento sin cortar la partida.

- [x] Acciones por dispositivo
  Cada player lee su control (device id); InputBuffer, Aim y Targeting pasan a ser del player. Teclado+mouse cuenta como un dispositivo.
- [x] Unirse / salir
  Start en un segundo control suma al P2 en cualquier momento; salir lo saca sin cortar la partida.
- [x] Prompts por jugador
  InputPrompts muestra los botones del control de cada uno.

**Prueba:** Con dos controles, cada uno mueve solo a su player; el P2 entra y sale con Start sin pausar el juego.

**Notas:** Skills: `godot:godot-nodes-scenes`, `disciplines:input-systems`, `disciplines:camera-systems`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.2 Players en red

**Bloqueada por:** 13.1 Código listo para varios players

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 13.3 Cámara y salas para dos · Pausado

**Prioridad:** alta · **Etiquetas:** `coop`, `camara`

Que la cámara encuadre a los dos players y los frene si se alejan, y que los cambios de sala y de escena lleven a los dos juntos, para que nunca quede uno fuera de cuadro ni en otra sala.

- [x] Encuadre de los dos
  Reusar el encuadre del lock-on: la cámara mantiene a ambos; si se alejan demasiado, un borde invisible los frena.
- [x] Cambio de sala
  Estilo Four Swords: al cruzar uno la puerta, el otro es llevado con él (o hace falta que estén los dos). Decidir y anotar.
- [x] Escenas
  Overworld ↔ templo llevan a los dos al spawn.

**Prueba:** Recorrer el templo de punta a punta con dos players: nunca queda uno fuera de cuadro ni en otra sala.

**Notas:** Skills: `godot:godot-nodes-scenes`, `disciplines:input-systems`, `disciplines:camera-systems`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.3 Mundo sincronizado

**Bloqueada por:** 13.1 Código listo para varios players

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 13.4 Reglas del co-op · Pausado

**Prioridad:** media · **Etiquetas:** `coop`, `diseño`

Definir y aplicar las reglas del co-op: corazones por player, revivir al caído y game over solo si caen los dos; inventario, equipo y progreso compartidos con X/Y por jugador; y anotarlas en el GDD.

- [x] Vida, muerte y revivir
  Cada uno con sus corazones; el caído queda como burbuja/espíritu y revive al tocarlo o en la sala siguiente. Game over solo si caen los dos.
- [x] Inventario y equipo
  Inventario, munición, equipo y progreso compartidos (GameState); cada uno asigna sus X/Y (buttons_of(slot)); la pestaña Ítems asigna para el control que toca.
- [x] Drops
  Corazones al que lo toca; rupias no hay.
- [x] Anotar en el GDD
  Sección de co-op con las reglas.

**Prueba:** Morir con uno solo no termina la partida y se puede revivir; con los dos, game over.

**Notas:** Skills: `disciplines:game-ui-ux`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión); 13.9 Anillo de ítems por player

### 13.5 HUD de dos jugadores · Pausado

**Prioridad:** media · **Etiquetas:** `coop`, `ui`

Que el HUD muestre los corazones e ítems de cada player, con el P2 en la otra esquina y su color, instanciando un panel por player que aparece y desaparece cuando entra o sale.

- [x] Mockup
  Corazones e ítems del P2 en la otra esquina, con su color.
- [x] Escenas
  El HUD instancia un panel por player (nada armado por código).

**Prueba:** Con dos players, cada uno ve sus corazones e ítems; al salir el P2 su panel desaparece.

**Notas:** Skills: `disciplines:game-ui-ux`, `godot:godot-ui-control`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 13.6 Player 2 con su color · Pausado

**Prioridad:** media · **Etiquetas:** `coop`, `arte`

Darle al P2 su propia variante de paleta (otra tela y otro neón, como los Links de colores de Four Swords), también con la cota reforzada, para distinguir a los dos jugadores de un vistazo.

- [ ] Variante de paleta
  Una entrada en VARIANTS (epiphany_palette.py) para el P2: otra tela y otro neón, como los Links de colores de Four Swords.
- [ ] Combinar con las armaduras
  Que la cota reforzada también tenga su versión P2.
- [ ] Colores de player en un solo .tres
  Hoy están en `hud.gd` (`player_colors`) y items_page los busca con `get_first_node_in_group(&"hud")` (sin HUD el cursor sale blanco). Un recurso exportado donde se necesite, también para el modelo. (Revisión de arquitectura 2026-10-11.)

**Prueba:** P1 y P2 se distinguen de un vistazo con cualquier armadura.

**Notas:** Skills: `disciplines:create-game-assets`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 13.7 Enemigos y jefe con varios objetivos · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `ia`

Que enemigos y jefe sepan elegir entre varios players (el más cercano o el último que les pegó, con histéresis) y que la dificultad escale con dos, sin cambiar nada al jugar solo.

- [ ] Elegir objetivo
  Los BT de LimboAI eligen al más cercano o al último que les pegó; cambian con histéresis.
- [ ] Jefe
  Las manos pueden ir cada una por un player; balance de vida con 2. Hoy boss.gd elige `target` una sola vez en `start_fight` (l.134) y no vuelve a elegir: volver a elegir con `Players.nearest` en `choose_attack`; la explosión de la marca (l.344-353) recorre `Players.alive()`; el agarre (boss_hand.gd l.315) prueba a todos los vivos. El daño pasa por el hurtbox tipado del player, no `get_node(^"Hurtbox")` ni `health.damage` directo (revisión de código 2026-10-11).
- [ ] Escalado
  Un poco más de vida o enemigos con dos players.

**Prueba:** Con dos players, los enemigos se reparten y el jefe ataca a los dos; con uno, igual que siempre.

**Notas:** Skills: `disciplines:game-ai`.

**Referencias:** `gdd.md#fuera-mvp`

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`

**Bloqueada por:** 13.1 Código listo para varios players

**Relacionadas:** 11.82 Daño que no pasa por el Hurtbox; 13.13 Referencias colgadas cuando un invitado se va

### 13.8 Puzzles cooperativos · Pendiente

**Prioridad:** media · **Etiquetas:** `coop`, `puzzles`

Revisar que los puzzles actuales no se rompan ni queden triviales con dos y sumar al menos tres que pidan a los dos jugadores (interruptores dobles, escudo espejo más flecha, cajas entre dos), con alternativa para jugar solo.

- [ ] Revisar los puzzles actuales
  Que no se rompan ni queden triviales con dos (bloques, interruptores, haces).
- [ ] Puzzles para dos
  Interruptores dobles, uno sostiene el escudo espejo mientras el otro tira la flecha, cajas que se empujan entre dos. En solo, una alternativa (bloque o tiempo).

**Prueba:** Hay al menos tres puzzles que piden a los dos; en solo siguen siendo resolubles.

**Notas:** Skills: `disciplines:level-design`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 13.1 Código listo para varios players

### 13.9 Anillo de ítems por player · Pausado

**Prioridad:** media · **Etiquetas:** `coop`, `ui`, `input`

Mockups D en el canvas (Coop_Ring, Solo_Ring): mantener la cruceta abre un anillo con los ítems al lado del panel de cada player; cruceta o stick elige, X/Y lo asigna, un toque ←/→ cambia rápido. Cada player conserva X e Y. Un ítem lo lleva uno solo (el que tiene otro se ve apagado con su etiqueta). En co-op no pausa; jugando solo el mundo casi se detiene. La pestaña Ítems del menú de pausa queda para jugar solo; en co-op solo muestra quién lleva qué.

- [x] Anillo en el HUD
  Escena del anillo por player en el HUD, desde el mockup Coop_Ring; se abre manteniendo LB (teclado: F) y se elige con el stick o WASD.
- [x] Ítems con dueño
  GameState sabe qué player lleva cada ítem en sus X/Y; asignar uno que tiene otro no se puede (apagado con su etiqueta).
- [x] Tiempo
  Solo: Engine.time_scale casi a cero mientras está abierto (mockup Solo_Ring); co-op: sin pausa.
- [x] Pestaña Ítems en co-op
  Solo lectura: quién lleva qué; asignar queda para el anillo.
- [x] Tests y GDD
- [x] Toggle para probar
  Tecla 5 (debug): en co-op, anillo por player o menú compartido con un cursor por player (Settings coop_item_menu).

**Relacionadas:** 13.4 Reglas del co-op; 10.28 Playtest de revisión (lo que está en Revisión)

### 13.10 Un espíritu revive al coger un contenedor de corazón · Pendiente

**Prioridad:** alta · **Tamaño:** S · **Etiquetas:** `bug`, `coop`

`max_health_changed` y `loaded` llaman a `health.reset(full)` en todos los players, también en Dead/Spirit: el espíritu queda vivo, `Players.nearest()` se devuelve a sí mismo y revive solo en 1 s; mientras, los enemigos persiguen al espíritu invisible.

- [ ] No resetear a un muerto
  player.gd `_on_max_health_changed` / `_sync_health`: si `is_dead`, solo actualizar `max_health`.
- [ ] Test
  test_coop_rules.

**Prueba:** Con P2 en espíritu, P1 coge un contenedor: P2 sigue siendo espíritu y solo revive con P1 cerca.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `player/player.gd`, `tests/test_coop_rules.gd`

**Relacionadas:** 11.79 Los corazones se rellenan al cambiar de escena

### 13.11 Estado de un player que se cuela en el otro · Hecho

**Terminada:** 2026-10-13 · **Prioridad:** alta · **Tamaño:** M · **Responsable:** Claude · **Etiquetas:** `bug`, `coop`

Cosas que todavía son de todos o de P1: el `tree_root` del AnimationTree es un sub-recurso compartido y jumping/pushing/using_item cambian `ItemAnim` (la animación de uno se mete en el otro); `Feel.rumble` siempre vibra el pad 0; el apuntado con ratón depende de `InputDevice.current` global; `tremor_zone` usa un solo bool `_inside`; el tope de bombas cuenta las de todos; el banner de zona (`AreaZone._current` estático) cambia cuando cruza cualquiera.

- [x] AnimationTree por instancia
  `resource_local_to_scene` en el sub-recurso o `tree_root.duplicate(true)` en `player._ready`.
- [x] Vibración por pad
  `Feel.rumble(amount, device := -1)`: el player pasa su pad; eventos del mundo vibran todos los pads asignados.
- [x] Apuntado con ratón
  aim.gd ~l.54: quitar el chequeo de `InputDevice.current`, ya se sigue por player con `controls.owns()`.
- [x] Zona de temblor
  Contar players adentro o `get_overlapping_bodies().any(...)`.
- [x] Bombas por player
  place_behavior.gd: contar solo las de `ctx.user`.

**Prueba:** test_coop_state: árbol de animación por player, tope de bombas por player, el temblor sigue con alguno adentro, el apuntado con ratón no depende del último dispositivo de nadie y el banner de zona sigue al que manda (fallan los cinco sin el arreglo). La vibración por pad no tiene test: headless no hay gamepads.

**Notas:** Sesión de bugs (-fd). player._ready duplica tree_root del AnimationTree (sin tocar player.tscn). Feel.rumble/shake reciben los pads del player (controls.joypads); vacío = todos los conectados (algo del mundo o un player que usa cualquier pad); el player pasa los suyos al recibir, dar y bloquear golpes. aim.mouse_aims ya no mira InputDevice.current (el seguimiento por player con controls.owns() alcanzaba). TremorZone cuenta players adentro. PlaceBehavior marca la bomba con placed_by y el tope cuenta solo las del que la pone. AreaZone: el banner cambia solo cuando cruza Players.lead() (la cámara es compartida).

**Archivos:** `player/player.tscn`, `player/states/jumping.gd`, `player/states/pushing.gd`, `player/states/using_item.gd`, `src/feel/feel.gd`, `player/components/aim.gd`, `src/world/tremor_zone.gd`, `src/items/behaviors/place_behavior.gd`, `src/world/area_zone.gd`

### 13.12 El pad del invitado maneja los menús de P1 · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `coop`, `ui`

En el menú de ítems compartido, el `_input` del invitado solo se traga `ui_accept`: su B cierra la pausa de todos y LB/RB cambian la pestaña de P1 (`ui_cancel` está ligado a cualquier pad). Además los tokens `{item:...}` del text box usan los botones de P1 y equipment_page dibuja solo los corazones del líder.

- [ ] Tragar las acciones del invitado
  items_page.gd ~l.83: también `ui_cancel`, `ui_tab_left`, `ui_tab_right`; o MenuStack ignora pads con `slot_of_pad > 0`.
- [ ] Tokens del text box por dueño
  text_box.gd ~l.199: `GameState.owner_of(id)` + `buttons_of(slot)` + `InputPrompts.icon_for(action, player)`.

**Prueba:** El invitado aprieta B y LB/RB en el menú de ítems: solo afecta a su cursor; un cartel con `{item:bow}` muestra el botón de quien tiene el arco.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/ui/menus/items_page.gd`, `src/ui/menus/menu_stack.gd`, `src/ui/text_box/text_box.gd`, `src/ui/menus/equipment_page.gd`

### 13.13 Referencias colgadas cuando un invitado se va · Pendiente

**Prioridad:** alta · **Tamaño:** S · **Etiquetas:** `bug`, `coop`

`Players.leave` hace `queue_free` del invitado, pero lo siguen usando: las manos del jefe en `_slam`/`_grab`/`_hold` (l.231, 315, 345, 355) tras cada await; los blackboards de los enemigos guardan `target` y los bt_* lo asignan a una variable tipada antes del `is_instance_valid` (error cada tick); la cámara en `_change_floor` espera que `crosser` aterrice.

- [ ] Manos del jefe
  `if not is_instance_valid(target): return` tras cada await; proteger el `disconnect`.
- [ ] Tareas de LimboAI
  Leer `target` sin tipo, validar y después castear; o limpiar `target` en `Players.left`.
- [ ] Cámara
  top_down_camera.gd `_change_floor`: `is_instance_valid(crosser)` en el loop y en `_remember_entry`.

**Prueba:** Con P2 como objetivo del jefe agarrado o en caída entre pisos, P2 se va con Start: sin errores y el juego sigue con P1.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/entities/boss/boss_hand.gd`, `ai/tasks/bt_find_player.gd`, `src/tools/top_down_camera.gd`

**Relacionadas:** 13.7 Enemigos y jefe con varios objetivos

### 13.14 Las salas las decide un nodo del mundo, no la cámara · Pendiente

**Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `coop`, `arquitectura`, `camara`

`top_down_camera.gd` detecta en qué sala están los players y desde ahí llama a `room.mark_entered()` (visita, autosave, rejas, oleadas, reset de bloques), emite `Room.player_left`, revive espíritus, teletransporta rezagados, los mantiene en pantalla y escribe `GameState.room_entry`. Una escena sin esa cámara (tests headless, cutscene con otra cámara) no tiene progresión de salas, y en online cada cliente lo haría por su cuenta (oleadas y autosaves duplicados).

- [ ] RoomTracker en la escena de la mazmorra
  Nodo en el .tscn (bajo Dungeon) con `_update_room`/`enter_room`, bring-along, correa de pantalla y `room_entry`; emite `room_changed(previous, room, crosser)`.
- [ ] La cámara escucha
  Solo pan y encuadre; `reveal` pasa a ser un pedido que la cámara puede atender.
- [ ] Tests
  test_rooms y test_coop_camera sin depender de la cámara para la lógica.

**Prueba:** Con la cámara quitada, entrar a una sala la marca visitada y arranca la oleada; la cámara solo encuadra.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/tools/top_down_camera.gd`, `src/world/room.gd`, `src/world/door.gd`, `src/world/gate.gd`, `src/entities/boss/boss_arena.gd`

**Relacionadas:** 14.1 Arquitectura de red

### 13.15 Playtest de co-op · Pendiente

**Prioridad:** alta · **Etiquetas:** `playtest`, `coop`

Los pasos de co-op del playtest de revisión (10.28), aparte: hacen falta dos controles. Al confirmar un paso, la tarea vinculada pasa a Hecho.

- [ ] Co-op (13.1, 13.2)
  Dos controles: Start en el segundo suma al P2 sin pausar, cada uno mueve el suyo; mantener Start 1,5 s lo saca.
- [ ] Co-op: cámara y salas (13.3)
  Dos controles en el templo: la cámara mira a los dos y no los deja separarse más que la pantalla; al cruzar uno una puerta, el otro aparece a su lado y entran juntos; overworld ↔ templo llegan juntos.
- [ ] Co-op: HUD de dos (13.5)
  Con dos controles: P1 arriba a la izquierda y P2 a la derecha, cada uno con sus corazones, sus X/Y con los botones de su control y su prompt; en mazmorra las llaves al medio; al salir el P2 vuelve el HUD de uno.
- [ ] Co-op: reglas (13.4)
  Con dos controles: que caiga uno; queda un espíritu que te sigue; parate encima un segundo y revive con un corazón (o cruzá a otra sala). Si caen los dos, game over. En la pestaña Ítems, con el control del P2, asigná X/Y: cambian solo los suyos. Un corazón cura solo al que lo agarra.
- [ ] Co-op: elegir ítems (13.9)
  Solo: mantené LB (o F): el mundo casi se frena, elegí con el stick y poné con X/Y; al soltar sigue. Co-op: cada uno abre su anillo sin pausar; lo que lleva el otro se ve apagado con su etiqueta. Tecla 5: pasa al menú compartido; en Ítems el P2 mueve su cursor con su control y asigna con X/Y. Decidí cuál queda.
- [ ] Co-op: colores (13.6)
  Con dos controles: el P2 tiene otra tela y otro neón, también con la cota reforzada; los dos se distinguen de un vistazo.

### 13.16 Co-op: la puerta del vestíbulo de D1 se cierra con P2 afuera · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `coop`

Del análisis de D1 (11.90, S3). P2 aprieta la placa BLOCK del vestíbulo, P1 entra al hub y la cámara arrastra a P2 (top_down_camera.gd): la puerta (stays_open=false) se cierra, el bloque se resetea y nada del lado del hub la reabre. Encaja con 13.8 (puzzles co-op con alternativa solo).

### 13.17 Suposiciones de un solo player fuera de la UI · Pendiente

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `co-op`

Del análisis del 2026-10-16. Solo el lead dispara los nombres de zona (area_zone.gd:28) y el sonido del temblor sale en su posición (tremor_zone.gd:40); text_box.gd:200 e items_page.gd:233 leen los botones de P1 en vez de `buttons_of(slot)`; los monitores de rendimiento solo miran al lead; `write_to` guarda la vida de los invitados aunque son de sesión.

- [ ] Disparadores del mundo con el cuerpo que entró o Players.nearest
- [ ] UI con el slot del player que actúa
- [ ] Guardar solo la vida del slot 0 o documentar por qué no

## M14 — Co-op online  (0/13)

Llevar el co-op local a la red: host autoritativo, dos jugadores en distintas máquinas, con el combate igual de preciso.

**Hecho cuando:**
- Dos máquinas juegan juntas el templo entero con 100 ms de latencia sin desincronizar puertas, cofres, puzzles ni el jefe.
- El combate se siente igual que en local para el host y casi igual para el cliente.

### 14.1 Arquitectura de red · Pendiente

**Prioridad:** alta · **Etiquetas:** `online`, `arquitectura`

Decidir la arquitectura de red del co-op online (host autoritativo con ENet y Steam más adelante) y dejar anotado en el GDD qué corre en el host y qué en el cliente.

- [ ] Decidir
  Host autoritativo con ENet (MultiplayerAPI de Godot) y transporte Steam más adelante; el host corre IA, física, puzzles y guardado.
- [ ] Anotar en el GDD

**Prueba:** Documento corto con la arquitectura elegida, qué corre en el host y qué en el cliente.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.2 Players en red; 14.3 Mundo sincronizado; 14.4 Combate en red; 14.5 Lobby y conexión; 14.6 Guardado en co-op; 14.7 Modo arena: hasta 8 jugadores peleando entre sí

**Relacionadas:** 13.14 Las salas las decide un nodo del mundo, no la cámara; 14.8 Escena raíz de gameplay que persiste entre niveles; 14.9 SceneFlow: flujo de escenas aparte de SaveManager y pantalla de carga; 14.10 El gameplay emite intenciones y la UI escucha; 14.12 Identidad del player independiente del pad; 14.13 Frame de input por tick en Controls

### 14.2 Players en red · Pendiente

**Prioridad:** alta · **Etiquetas:** `online`

Que el cliente mande su input al host, que simula y devuelve el estado, con predicción del propio player para que con 100 ms de latencia se mueva sin retraso ni tirones.

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

Sincronizar en red los objetos con estado (puertas, cofres, interruptores, oleadas, drops, bombas, cajas físicas) y los cambios de escena y sala, simulados por el host, para que el templo no se desincronice.

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

Que el combate del cliente se sienta como en local: golpes validados en el host con compensación de latencia, bloqueo y parry con margen, y hit-stop y flash mostrados al instante.

- [ ] Golpes del cliente
  Hitboxes validadas en el host con compensación de latencia; bloqueo y parry con margen.
- [ ] Feedback local
  Hit-stop y flash se muestran al instante en el cliente.

**Prueba:** Pelear contra chullpas y el jefe como cliente con 100 ms: los golpes se sienten y no hay daño fantasma.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloquea a:** 14.7 Modo arena: hasta 8 jugadores peleando entre sí

**Bloqueada por:** 14.1 Arquitectura de red

### 14.5 Lobby y conexión · Pendiente

**Prioridad:** media · **Etiquetas:** `online`, `ui`

Poder crear una partida y unirse (por IP o código en debug, invitación de Steam en release) y manejar las desconexiones: si cae el cliente el host sigue solo, si cae el host el cliente vuelve al título con aviso.

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

Definir el guardado del co-op online: solo guarda el host y el cliente participa en su partida; decidir qué se lleva el cliente, sin perder ni duplicar progreso.

- [ ] Solo el host guarda
  El cliente participa en la partida del host; decidir qué se lleva el cliente (nada, o una copia).

**Prueba:** Terminar una sesión online, recargarla en el host: el progreso está y no se duplica nada.

**Notas:** Skills: `godot:godot-multiplayer`, `disciplines:physics-tuning`.

**Referencias:** `gdd.md#fuera-mvp`

**Bloqueada por:** 14.1 Arquitectura de red

### 14.7 Modo arena: hasta 8 jugadores peleando entre sí · Pendiente

**Prioridad:** media · **Etiquetas:** `online`, `pruebas`

Decidido 2026-10-11: para probar el online, un modo arena aparte donde hasta 8 jugadores se pelean entre sí (daño entre players, una sala cerrada, reaparecer al morir). Sirve para medir hasta dónde aguanta la red (latencia, ancho de banda, sincronización del combate) con más jugadores que el co-op; la meta del co-op online sigue siendo 4 y el local, 2 por ahora.

**Bloqueada por:** 14.1 Arquitectura de red; 14.4 Combate en red

### 14.8 Escena raíz de gameplay que persiste entre niveles · Pendiente

**Prioridad:** alta · **Tamaño:** L · **Etiquetas:** `online`, `arquitectura`

Cada nivel trae su Player, cámara y HUD; P1 viene instanciado en el .tscn y los invitados se crean en runtime: dos formas de crear players y todo se destruye en cada cambio de escena. El MultiplayerSpawner de M14 necesita un padre estable y un único camino de spawn; además la cámara y el HUD se configuran distinto en cada nivel.

- [ ] Cámara como escena propia
  Primer paso chico: un camera.tscn instanciado en cada nivel en vez de un Camera3D con script y overrides.
- [ ] gameplay.tscn
  Players, cámara, HUD y un LevelContainer; los niveles solo traen mundo y SpawnPoints.
- [ ] Un solo camino de spawn
  P1 se crea igual que los invitados.

**Prueba:** Cambiar de nivel no destruye players, cámara ni HUD; P1 e invitados se crean por el mismo camino.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/state/players.gd`, `src/save/save_manager.gd`

**Relacionadas:** 14.1 Arquitectura de red

### 14.9 SceneFlow: flujo de escenas aparte de SaveManager y pantalla de carga · Pausado

**Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `online`, `arquitectura`

SaveManager además de slots y codec hace `travel_to`, `respawn`, `new_game` (con intro), `quit_to_title`, `with_fade`, ubicar players, `location()` y escenarios de debug. Es el autoload que en M14 tiene que pasar a 'el servidor decide el cambio de escena', y está mezclado con archivos.

- [x] Autoload SceneFlow
  Viaje, respawn, partida nueva, salir, ubicar players y fades (Fader puede integrarse para no sumar autoloads).
- [x] SaveManager: slots y capturar/aplicar
- [x] Pantalla de carga
  Daniel (2026-10-12): alcanza con el ojo y un Cargando animado en la esquina inferior derecha. Mockup Loading rehecho así (aprobado). SceneFlow: si la carga en hilo tarda más de 0,25 s, negro con el ojo que parpadea y Cargando… (puntos animados) abajo a la derecha; mínimo 0,6 s. Sin destino ni barra: Portal.destination_kind/destination y las claves LOADING_* se quitaron (la salida de la Chullpa la limpia su sesión).

**Prueba:** SaveManager solo guarda/carga; los tests de viaje y respawn pasan contra SceneFlow.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/save/save_manager.gd`, `src/ui/fader.tscn`, `project.godot`

**Relacionadas:** 14.1 Arquitectura de red

### 14.10 El gameplay emite intenciones y la UI escucha · Pendiente

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `online`, `arquitectura`, `ui`

El estado Dead de un player abre GameOver (decide el fin de la partida por todos); item_get.gd empuja su pantalla y pausa el juego compartido desde un estado del player; area_zone, room y boss_arena hacen `call_group(&"hud", …)`. En online el game over es decisión del servidor y los carteles son presentación por cliente.

- [ ] Señales de intención
  `Players.all_dead`, `GameState.item_received(player, item)`, `area_entered(name)` en Room/AreaZone.
- [ ] Listener de flujo/HUD
  Abre GameOver, ItemGet y el cartel de zona.

**Prueba:** dead.gd e item_get.gd no referencian escenas de UI; la UI se abre desde listeners.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `player/states/dead.gd`, `player/states/item_get.gd`, `src/world/area_zone.gd`, `src/world/room.gd`, `src/entities/boss/boss_arena.gd`

**Relacionadas:** 14.1 Arquitectura de red

### 14.11 Feel solo cosmético: hit-stop como estado de gameplay · Pendiente

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `online`, `feel`

`Feel.hit_stop` pone `PROCESS_MODE_DISABLED` a nodos de gameplay y `freeze` cambia `Engine.time_scale`. En online cada proceso congelaría por su cuenta, y deshabilitar nodos hace perder eventos de input (causa de fondo de 11.65).

- [ ] Hit-stop como flag
  La entidad lo respeta en su propia física (local en M13, replicado u omitido en M14).
- [ ] freeze solo presentación
  Animación, VFX y cámara.

**Prueba:** Durante un hit-stop el player sigue recibiendo input; los tests no dependen del timing del freeze.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/feel/feel.gd`, `player/player.gd`, `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`

**Relacionadas:** 11.65 El escudo se queda levantado tras un hit-stop o la pausa

### 14.12 Identidad del player independiente del pad · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `online`, `coop`, `input`

`slot` significa a la vez 'quién' y 'qué pad'; `GameState.guest_buttons` va por `controls.slot`; los nodos se llaman `Player%d`. Players mezcla la lista con asignar joypads, mantener Start para irse, eventos de pausa sintéticos y un toggle de debug. `Players.joined/left` en realidad significan 'entró/salió del árbol': saltan antes del `_ready` del player y en cada cambio de escena.

- [ ] player_index propio
  Lo pone el registro; el estado por player se indexa por él.
- [ ] Input local aparte
  Mapeo de pads y unirse/irse en un nodo LocalJoin (o en Controls).
- [ ] Señales de sesión
  Renombrar a registered/unregistered o emitir tras `ready`; agregar `guest_joined(slot)`/`guest_left(slot)` desde join/leave.

**Prueba:** Cambiar el pad de un player no cambia su índice ni su estado guardado; `guest_joined` salta una vez por invitado.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/state/players.gd`, `src/state/game_state.gd`, `player/components/controls.gd`

**Relacionadas:** 14.1 Arquitectura de red

### 14.13 Frame de input por tick en Controls · Pendiente

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `online`, `input`

Unas acciones se leen por polling, otras por eventos (`_unhandled_input` del bloqueo, input_buffer, targeting y aim), y el targeting depende de `camera.unproject_position` local. M14 necesita snapshots de input por tick que el servidor pueda aplicar.

- [ ] Controls arma un frame por tick
  Botones pressed/just_pressed más la intención de cambiar objetivo.
- [ ] Consumidores leen del frame
  state_machine, input_buffer, targeting, aim; el objetivo elegido es parte del input.

**Prueba:** El FSM, el buffer y el targeting leen solo del frame de Controls; se puede reproducir una partida corta a partir de los frames grabados.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `player/components/controls.gd`, `player/state_machine.gd`, `player/components/input_buffer.gd`, `player/components/targeting.gd`, `player/components/aim.gd`

**Relacionadas:** 14.1 Arquitectura de red

## M15 — Optimización  (21/29, 21 en revisión)

Que el juego arranque rápido y corra estable a 60 FPS en la máquina más floja de los playtesters, en Linux y Windows, sin tirones al aparecer efectos.

**Hecho cuando:**
- Primer arranque (caché vacía) hasta el overworld jugable en menos de 5 s en Windows D3D12.
- Ningún efecto compila pipelines al aparecer ni tira un frame de más de 25 ms con caché caliente.
- Build release a 60 FPS p95 en la máquina más floja en overworld, mazmorra y jefe.

### 15.1 Warm-up: variantes que faltan en Windows · Pendiente

**Responsable:** project-epiphany-e0

En Windows (D3D12 y Vulkan, con baker y caché caliente) explosion compila +7 especializaciones al aparecer, projectile +2 y roar_ring +1 (peor frame ~18 ms). En Linux el warm-up las cubre. Medido con tools/pipeline_probe.gd y measure_shaders.ps1 (11.203).

- [ ] Ver qué especializaciones faltan
  Probablemente dependen de las luces/sombras activas en el momento del disparo (omni con sombra, contact shadows).
- [ ] Cubrirlas en pipeline_warmup.tscn
  Por ejemplo, una luz con sombra cerca de los efectos durante los dos cuadros.
- [ ] Volver a medir en Windows
  measure_shaders.ps1 -SkipExport; cero compilaciones al aparecer.

**Relacionadas:** 11.203 Aprovechar las novedades de Godot 4.8

### 15.2 Pico suelto de sparks_gold · Pendiente

**Responsable:** project-epiphany-5c

Con caché caliente: 85,7 ms (D3D12 sin baker) y 63,6 ms (Vulkan) sin compilar pipelines; en frío 19,5 ms. No parece shaders: revisar instanciado, partículas o algo que se crea en vez de reusarse.

- [ ] Reproducir y perfilar
  pipeline_probe + profiler de Godot en el cuadro del pico.
- [ ] Arreglar (pool, preload o lo que se mida)

**Notas:** -5c (2026-10-20): en Linux no se reproduce. Vulkan, RX 580, carpeta de usuario y caché de Mesa aisladas: en frío y en tres corridas en caliente sparks_gold da ≤ 20 ms, igual que sparks y el cuadro sin efecto (sparks_gold es igual a sparks salvo color y cantidad, CPUParticles3D). En Windows el pico salió solo en la primera corrida en caliente después de las frías, con los dos drivers: apunta a algo de ese momento (caché de pipelines que se guarda, disco), no al efecto. pipeline_probe ahora hace dos pasadas con un tramo sin efecto antes de cada uno y los ms desde el arranque; falta correrlo en Windows (measure_shaders.ps1) para ver si el pico sigue al efecto o al momento.

**Relacionadas:** 11.203 Aprovechar las novedades de Godot 4.8

### 15.3 Sombras ajustadas a la cámara fija · Revisión

**Responsable:** project-epiphany-5c

La cámara es cenital y fija por sala: la sombra direccional puede tener distancia máxima corta y 1-2 cascadas en vez de 4. Suele ser de lo más barato en GPU.

- [x] Medir el costo actual de sombras
  Overworld y una sala de mazmorra, GPU 1080p en RX 580.
- [x] Ajustar distancia, cascadas y resolución del atlas
  Que no se note el corte en el borde de pantalla ni en las salas grandes.
- [x] Revisar luces omni/spot con sombra
  Cuántas proyectan sombra a la vez en las peores salas.

**Notas:** -5c (2026-10-20): overworld 1080p, RX 580, GPU: sombra del sol 2.4 ms (13.9 con, 11.5 sin). Ya estaba en 2 cascadas y 32 m; 24/40 m y 1/2/4 cascadas cambian ±0.3 ms (la cámara está a ~20 m, no se puede acortar mucho). Lo que ahorra es el atlas y el filtro: 2048 + filtro muy bajo, 0.6 ms (13.8 → 13.2), apenas más borrosa. Daniel (2026-10-20): que sea una opción. Opciones › Video › Sombras: Altas (por defecto, como antes) / Bajas. Mazmorras sin sombras; la única luz omni/spot con sombra es el foco de cáusticas del agua (water_pool).

### 15.4 Contact shadows y SSAO en mazmorras · Revisión

**Responsable:** project-epiphany-5c

En el overworld (11.203) costaron ~0,8 ms GPU (7,8 → 8,6 ms). Falta decidir si van en las mazmorras: medir por sala y comparar a ojo.

- [x] Medir costo por sala
- [x] Decidir con Daniel por cómo se ve

**Notas:** -5c (2026-10-20): Chullpa sala por sala a 1080p en la RX 580: base 9,9 ms de GPU, SSAO +0,5, sombra del sol (con contact shadows) +0,5, las dos +0,9; casi igual en todas las salas. Daniel eligió las dos (ssao_sol) y que sea configurable: las mazmorras, la Huaca y Reflejos las traen prendidas; Opciones › Video › Sombras suma Apagadas (sin sombra del sol) y hay un tilde nuevo, Sombra en las esquinas (SSAO). Las cuevas siguen sin nada.

**Relacionadas:** 11.203 Aprovechar las novedades de Godot 4.8

### 15.5 Comprimir mallas al importar · Revisión

**Responsable:** project-epiphany-5c

Los terreno_organico pesan 15-72 MB cada uno. Comprimir atributos de vértice achica RAM, VRAM, .pck, tiempo de carga y el repo (ver 11.126). Va después de terminar los assets.

- [ ] Medir tamaño y carga actuales
- [ ] Activar compresión de mallas en el import
  Revisar que no se vean artefactos en el terreno ni en los colores por vértice.
- [ ] Volver a medir

**Decisiones:**
- ✓ ¿Comprimimos también las mallas de los kits de paredes LA (≈200 MB de .tres)?
  Por qué: Bajaría VRAM y peso del repo como pasó con meshes/ (637 → 449 MB), pero reescribe los niveles en el próximo refresh de la_walls.
  Descartado: Dejarlos sin comprimir.
  Respuesta: Comprimir

**Prueba:** Peso de assets/epiphany/meshes antes y después; VRAM y carga del overworld a 1080p en la RX 580; capturas antes/después en inicio, chullpa, quenoa, templo, cumbre y totora sin rendijas ni cambios de sombreado. Suite completa.

**Notas:** -5c (2026-10-20): hoy meshes/ pesa 642 MB (terreno_organico 369, paredes_la 221). Ninguna malla estaba comprimida: con tangentes generadas, gltf_document.cpp apaga ARRAY_FLAG_COMPRESS_ATTRIBUTES para toda la malla si una sola tangente no es perpendicular a su normal. Ningún material nuestro usa tangentes ni normal maps.
Hecho (-25, wt/art 4c1a6809, main 5d661304): meshes/ensure_tangents=false en 64 .glb.import de assets/epiphany. meshes/ 637 → 449 MB (terreno_organico 368 → 262, paredes_la 220 → 150), 1057 .res reescritos. Overworld 1080p RX 580: VRAM 753 → 647 MB; carga en caliente ≈1,2 s sin cambio medible. Los personajes con skin siguen sin comprimir (Godot no comprime mallas con skin). Mazmorras sin cambio (VRAM 1133 MB, chullpa ≈2,4 s): los *_la_kit.tres traen sus propias mallas sin comprimir hechas por la_walls con SurfaceTool.commit(). Capturas antes/después: solo difieren viento y partículas.
Posible seguimiento, no hecho: pasar Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES en los commit de los kits de la_walls (≈200 MB de .tres de texto); reescribe los niveles en el próximo refresh, así que lo decide Daniel.

**Relacionadas:** 11.126 Push bloqueado: terreno del overworld pasa 100 MB

### 15.6 Arranque hasta el menú · En curso

**Responsable:** project-epiphany-e0

Medir qué se carga antes del primer cuadro: autoloads, preloads grandes, recursos del menú. Bajar lo que no haga falta en el arranque.

- [ ] Medir el tiempo hasta el primer cuadro y hasta el menú
  Linux y Windows, caché vacía y caliente.
- [x] Mover a carga diferida lo que no haga falta

**Notas:** Linux measured (8a6d7311, warm cache): windowed Vulkan ~2.25 s to the first title frame, ~1.3 s of which is renderer start-up; autoloads ~200 ms (DialogueManager 78 ms, from the addon, can't be deferred); title 19 ms. Deferred: intro and pipeline warm-up (-39 ms); Feel no longer synthesizes (15.12). Still pending: Windows and a cold cache (Windows session, with measure_shaders.ps1 or by timing the build).

**Relacionadas:** 15.12 Feel sintetiza sonidos al arrancar y tira la mitad

### 15.7 Escala de resolución 3D en Ajustes · Revisión

**Responsable:** project-epiphany-e0

Red de seguridad para GPUs integradas y Mac, donde no podemos medir: opción de escala 3D (FSR) en Ajustes, guardada con el resto de la configuración. La UI se dibuja a resolución completa.

- [x] Opción en la pantalla de Ajustes
  Según el diseño de los mockups de UI.
- [x] Aplicarla y guardarla
  scaling_3d_mode/scale del viewport.

**Notas:** Done (da28b91a): Opciones › Video › Resolución 3D (100/85/70/50%), under Sombras, same row style as the others (checked with a capture at 720p: it fits). FSR below 100, UI at full resolution. Settings.render_scale.

### 15.8 Medir la build release en la máquina más floja · Pendiente

**Responsable:** project-epiphany-e0

Pendiente de 10.8: hasta ahora todo se midió en debug con la RX 580. Medir release en la máquina más floja de los playtesters: overworld, mazmorra, jefe y arranque.

- [ ] Elegir la máquina y armar la build
- [ ] Medir con profile_scenes y pipeline_probe
- [ ] Pasar lo que falle a tarjetas de este hito

**Relacionadas:** 10.8 Pasada de rendimiento

### 17.2 LOD de decor y plantas, y terreno en bloques más chicos · Revisión

**Responsable:** project-epiphany-25

Pasos 2 y 3 de 15.9, estacionados por Daniel (2026-10-20) hasta después de los assets: con el arreglo del shader el overworld va a 6–7,7 ms de GPU y esto ganaría como mucho 1 ms (resto: iluminación/sombras del suelo 1–3,4 ms, decor ~1,1, riscos <1, plantas ~0,1).

- [x] Rangos de visibilidad/LOD en decor y plantas
- [x] Terreno en bloques más chicos que se descarten fuera de cámara

**Prueba:** Suite 768/768 en main después de cada paso. Capturas antes/después en debug/tmp/lod/opciones/ (antes_despues_Arboleda.png, antes_despues_Banado.png; agua_nubes.png muestra que las manchas del agua del bañado son lenteja de agua tapada por la sombra de una nube). Triángulos Mobile por caso del benchmark.

**Notas:** 2026-10-20: pasa a M15 por lo medido en teléfonos (17.3). En el Moto G23 (Mali-G52) el overworld dibujaba 2,2 M de triángulos y 599 draw calls con sombras, 158 ms de GPU por cuadro, 7,5 FPS. Encargado a -25.

Paso 2, terreno en bloques (f304ebee): cada franja X son 8 bloques de ~19×14 m (riscos_k_j / suelo_k_j, cada uno con su colisión); los cortes van a floor(...) + 0,37 m en X y Z (SEAM_OFFSET en build_terreno_organico.py) para que nada colocado en coordenadas redondas caiga sobre una costura (el primer intento, 214708cc, dejaba PortalNecropolis sobre la costura z = -2 y test_map fallaba). Triángulos (PC, Mobile 1600×720): inicio 2,14 → 0,62 M, arboleda 1,97 → 0,75, cardonal 1,55 → 0,28, bañado 1,21 → 0,54, cumbre 1,62 → 0,65. G23: GPU 96/110/82/101/120 ms (antes 158).

Paso 1, plantas (06a3ac12): Daniel eligió queñoa media + pasto sin sombra entre las opciones simuladas (hoja en debug/tmp/lod/opciones/opciones_plantas.png). quenoa_grande 4584 → 1782 triángulos, quenoa_chica 3456 → 1308, en el decor y en las montañas. Las plantas horneadas del terreno se separan en arboles_* (con sombra) y plantas_* (sin sombra; epi_scene_import respeta el extra "shadow"); pasto, flores, tola, yareta, hongos e ichu_cortado sin sombra. naturaleza.glb reconstruido (no se rehacía desde el 10-13): las demás mallas pasan a la triangulación determinista de 16.51, mismas formas. 78 mallas de chunks viejos borradas; el glb de terreno más grande baja de 72 a 32 MB. Triángulos Mobile (miles): inicio 618 → 422, arboleda 749 → 475, cardonal 276 → 224, bañado 515 → 305, cumbre 646 → 451; ~20 % menos draw calls. La quenoa_grande.res sin commitear de Daniel (re-guardado del editor de la malla vieja) quedó en un stash de main. LOD automático y rangos de visibilidad descartados: con la cámara cenital no actúan, y el LOD automático de la queñoa pierde los troncos.

### 15.9 Overworld: optimizar el dibujado (después de los assets) · Revisión

**Prioridad:** baja · **Tamaño:** M · **Responsable:** project-epiphany-3e · **Etiquetas:** `optimizacion`, `overworld`

Daniel (2026-10-15) preguntó por el texture streaming de Godot 4.8: descartado, el proyecto tiene 3422 PNG que suman ~5 MB (paleta y colores por vértice). Lo que pesa en el overworld es la geometría (terreno_organico.0..11 de 15-72 MB, paredes LA, decor, plantas) y la cantidad de mallas por cuadro. Va después de terminar los assets, junto con 11.126 y 11.59.

- [x] Medir con el profiler: vértices, draw calls, sombras

**Notas:** -3e (7d7987f8): GPU in the overworld was the outdoor shader's detail (7–10 of 12–15 ms), not geometry. The bevel now uses the analytic gradient (one Voronoi per pixel instead of four): start 12.9→6.5 ms, cardonal 14.7→6.2, arboleda 9.8→6.4. Steps 2 (decor/plant LOD) and 3 (smaller chunks) would win ≤1 ms: -3e suggests dropping them or parking them until the assets are done; that's Daniel's call.

Daniel (2026-10-20): park steps 2 and 3 → 17.2 (m17-01).

### 15.10 Salas y targeting: dejar de consultar todo cada frame · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `rendimiento`

Cada Room llama a `has_player()` en cada frame de física (get_first_node_in_group de la cámara, Players.all.any con lambda, contains que sube por DungeonFloor.of); las cerradas además `enemies_inside()` y `waves_running()` (barrido de grupo + filter). `Targeting._sync_posts` corre cada frame aunque no tengas el gancho: hook_reach, grupo de postes y `_room_of` que recorre todas las salas, dos veces por poste.

- [x] Room reacciona al cambio de sala de la cámara
  Y a Enemy.defeated / WaveSpawner para las cerradas.
- [x] _sync_posts sale si no hay alcance
  Usa camera.room para la sala del player.

**Notas:** Done (335c775d with 7dbbba82 from 16.38). Instead of events, a lighter version: has_player looks up the camera once per physics frame for every room and loops without a lambda; a locked room checks enemies/waves every 6 ticks (LOCK_CHECK_TICKS). Hooking up Enemy.defeated/WaveSpawner would also need falls, pits and despawns: not worth it for this cost. _sync_posts returns without reach and only looks up rooms when a post is in reach (it doesn't use camera.room: in co-op each player has their own room).

### 15.11 Memoria que se pide y se tira en cada frame · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `rendimiento`

`Players.alive()` arma un array con filter en cada llamada y `nearest()` lo llama por frame (Kuntur, Spirit, cada Pickup; Pickup además `get_overlapping_bodies().has(player)` por frame). Cada Hitbox hace `_airborne.duplicate()` cada frame aunque esté vacío. Los DebugOverlay.watch del player y del jefe arman strings, snappedf y `State.keys()` cada frame también en release.

- [x] nearest sin array intermedio; Pickup por body_entered
- [x] Hitbox sin physics_process con _airborne vacío
- [x] watch solo con el overlay visible
  Y el blackboard del jefe con el enum en int.

**Notas:** Done (335c775d). Pickup: any player touching it can pick it up (before only the nearest could), which is better in co-op. A Hitbox only sleeps if it is plain Hitbox: Projectile, HammerStrike and Explosion use their own _physics_process. The boss blackboard keeps hand_left/right as BossHand.State (int); the overlay shows the name.

### 15.12 Feel sintetiza sonidos al arrancar y tira la mitad · Revisión

**Prioridad:** baja · **Tamaño:** S · **Responsable:** project-epiphany-e0 · **Etiquetas:** `rendimiento`, `audio`

feel.gd:59-83 genera unos 22 sonidos en `_ready` (~10 s de audio a 22050 Hz, ~220k llamadas a lambdas) en cada arranque y en cada proceso de tests; después reemplaza 11 por samples grabados que carga todos de una listando la carpeta. La lista de sonidos es un Dictionary en código.

- [x] Renderizar los sintetizados a .wav una vez
  Como render_music.gd.
- [x] Banco de sfx en un .tres con carga perezosa
  StringName → Array[AudioStream].

**Notas:** 81c780e9: src/tools/render_feel_sfx.gd renders the 11 sounds without a recording to assets/audio/sfx/synth/*.wav (only once, re-run it if a recipe changes). The bank stayed as the SAMPLES const with lazy loading (Feel.streams_of), not a .tres: a .tres would add a file without changing the behavior. The 11 recipes that already had .ogg samples were deleted.

**Relacionadas:** 15.6 Arranque hasta el menú

### 15.13 El mapa del overworld se vuelve a fotografiar con cualquier flag · Revisión

**Prioridad:** alta · **Tamaño:** S · **Responsable:** project-epiphany-3e · **Etiquetas:** `optimizacion`, `overworld`

Revisión de arquitectura del overworld (-3e, 2026-10-19): overworld_map.gd:106 corre snapshot() (copia el GridMap, renderiza un SubViewport de 4000×1920) 2 s después de CUALQUIER flag_changed, cofres y corazones incluidos. Arreglo: solo con flags que cambian el trazado (puente, paredes agrietadas), por lista o señal layout_changed.

**Prueba:** tests/test_minimap.gd

**Notas:** Hecho por -3e (4869886c): la foto del mapa se rehace solo con flags del trazado (scenery y sus interruptores, como el ojo del puente), no con cofres ni corazones.

### 15.13 Overworld activo por zona · Revisión

**Prioridad:** alta · **Tamaño:** L · **Responsable:** project-epiphany-3e

Medido en el Moto Edge 30 Fusion (17.3, 2026-10-20): el overworld entero corre siempre: 9040 nodos, 1406 Area3D con monitoring (573 hurtboxes de pasto, 239 de flores, 127 de árboles, 94 tolas, 63 queñoas, 60 cardones…), 456 StaticBody3D, 199 partículas emitiendo (127 árboles, 63 queñoas) y 22 enemigos con BT y física estén donde estén. Physics ≈15 ms y process 12–25 ms por cuadro en el teléfono. Daniel: debería ir por chunks. Que solo la zona del player y sus vecinas tengan física, IA, animación y partículas activas (usar las Zone_* que ya existen o VisibleOnScreenEnabler3D), y que las hurtboxes de vegetación no monitoreen. Medir con el benchmark (15.14). Encargado a -3e.

**Prueba:** test_active_zones (los enemigos lejanos duermen y despiertan, las hojas lejanas paran, un 2.º player mantiene despierta su zona). Suite completa 768/768 en main (dfda1275). En el teléfono: tools/bench.sh android <serial> --build y comparar con python3 tools/bench_report.py nuevo.json debug/tmp/bench/motorola_edge_30_fusion_20261020_2300.json.

**Notas:** Nodo ActiveZones en overworld.tscn (src/world/active_zones.gd): una zona despierta cuando cualquier player de Players.all está a menos de reach = 22 m; los enemigos de zonas dormidas quedan en process_mode DISABLED (sin cuerpo, IA ni animación) y solo se despiertan los que durmió ActiveZones. Las hojas (GPUParticles3D de Decor) van en chunks de 16 m y dejan de emitir lejos de todo player. Las hurtboxes de vegetación ya eran solo monitorables (78 monitorean, 1333 no). PC headless, en el inicio: physics 5.1–5.8 → 2.3–2.7 ms, process 1.2–1.6 → 0.6–0.9 ms, BTPlayers activos 22 → 4, partículas 199 → 67. Arreglo aparte: test_every_region_is_reachable_except_the_item_gated espera hasta 60 cuadros al mapa de navegación en vez de 10 fijos. Mergeado en main dfda1275 (-ae); la resave de Daniel de overworld.tscn se mantuvo con el nodo agregado. Falta la medición en el teléfono (15.14).

### 15.14 Escena benchmark automática (PC y Android) · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-e0

Daniel (2026-10-20): una escena benchmark que mida sola, sin input. Recorre casos fijos (overworld en varias zonas, una mazmorra, el jefe) moviendo al player por un camino, en variantes de calidad (100 % con sombras, 50 % sin sombras, materiales planos para ver cuánto cuestan los shaders) y anota por cuadro frame, process, physics, render CPU y GPU, draw calls, triángulos, objetos y memoria de video: promedio, p50, p95, peor. Sale como JSON y líneas BENCH en el log. Un script lo exporta, instala y corre en un teléfono por adb (o en PC en ventana) y junta el resultado. Encargado a -e0.

**Prueba:** PC: tools/bench.sh desktop (ventana en la pantalla 1, sin foco). Teléfono: tools/bench.sh android <serial> --build (exporta el preset "Android (benchmark)", instala, corre y baja el JSON a debug/tmp/bench/). Comparar dos corridas: python3 tools/bench_report.py nuevo.json viejo.json. Corrió entero en el Edge 30 Fusion (24 corridas, ~6 min).

**Notas:** Mergeado en main 6b0232cc. Autoload Benchmark (src/debug/benchmark/benchmark.tscn): inerte salvo --benchmark o el feature "benchmark". Casos (BenchCase, hijos de Cases): overworld inicio, arboleda, cardonal, bañado, cumbre, templo hub, chullpa, antesala; el player camina en círculo apoyado en el piso, invulnerable. Variantes (BenchVariant): Alta; Baja = 50 %, sin sombras ni SSAO; Plana = StandardMaterial3D en toda la geometría. Vsync y tope de fps apagados. En Android hizo falta: import_etc2_astc (se reimportan las texturas), las libs Android de LimboAI 1.8.1 y el preset "Android (benchmark)" con features benchmark,plain_saves e include_filter de debug/scenarios/*.cfg (los intent extras no pasan args). bench.sh no corre si dev.asteroids.game está abierto (el G23 es compartido).

Primeras corridas (debug, antes de 15.13):
- Edge 30 Fusion (Adreno 660, 1600×720): overworld 20–30 fps (GPU 30–41 ms, process 22–46, physics 11–13); Baja 24–31; Plana 27–38. Templo hub 7 fps (GPU 135 ms), Chullpa 13 (GPU 74, 2,44 M tris), Antesala 14; en mazmorras Plana empeora → 15.16.
- Moto G23 (Mali-G52): overworld ~4 fps (GPU 88–136 ms, physics 28–41); en el templo hub un cuadro de 11,8 s y Vulkan pierde el device (fence -4), el juego se cierra.

### 15.15 Efectos LA en el renderer Mobile · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** design

En Android (renderer Mobile) los CompositorEffect de src/world/look (tono_la, nubes_la, sombra_la y los que escriben el color) fallan todos los cuadros: el color buffer de Mobile no tiene TEXTURE_USAGE_STORAGE_BIT, así que uniform_set_create falla y loguean ≈15 errores con backtrace por cuadro, carísimo en el teléfono. Hacer que funcionen en Mobile (copiar a una textura de storage y volver, o pasar a un pase de raster/shader de pantalla) o, si alguno no se puede, apagarlo ahí con un reemplazo que mantenga el look (tono y viñeta sobre todo). SSAO tampoco existe en Mobile. Encargado a -88.

**Prueba:** Con --rendering-method mobile en overworld y chullpa: 0 errores STORAGE_BIT (antes 369 y 244 por corrida). Forward+ antes/después: 0,01–0,02 % de píxeles distintos (animación). Mobile después contra Forward+: 0,2–0,5 %. Capturas en epiphany-wt/design/debug/tmp/design/mobile_look_overworld.png y mobile_look_chullpa.png. test_player_hole, test_overworld_run.

**Notas:** -88 (wt/design-fix a0b333df, main a95d293f): en Mobile la capa de color es RGB10A2 con usage 515 (sampling, color e input attachment): sin STORAGE ni CAN_COPY, así que texture_copy tampoco sirve; en Forward+ es 523 (con STORAGE). Helper nuevo src/world/look/look_color.gd: cada efecto pide look.begin(buffers, view) y llama look.end(). Con STORAGE devuelve la capa misma (camino de siempre); sin STORAGE un compute la samplea ×2 (el luminance multiplier de Mobile) a una rgba16f propia, el efecto corre ahí y un triángulo fullscreen la devuelve ÷2. Decide por el bit de STORAGE, no por el nombre del renderer. brillo, caida y enfoque no son CompositorEffect. Sin MSAA en el proyecto; con MSAA no está probado. En el teléfono suma una copia de entrada y una de salida por efecto (tres en el overworld): medir en el G23 con el benchmark (15.14).

### 15.16 Mazmorras: costo de GPU en mobile · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-3e · **Etiquetas:** `optimizacion`

Benchmark 15.14 en el Moto Edge 30 Fusion (debug/tmp/bench/motorola_edge_30_fusion_20261020_2300.json, en wt/bugs): las mazmorras cuestan más GPU que el overworld. Templo hub 7 fps (GPU 135 ms), Chullpa 13 fps (GPU 74 ms, 2.44 M tris), Antesala 14 fps (GPU 69 ms); el overworld va a 20–30 fps. Con materiales planos (variante Plana) las mazmorras empeoran (6–9 fps), así que no son los shaders de material: sospechosos son las luces (antorchas/omni por sala), los efectos LA de pantalla (TonoLA, SombraLA, NubesLA, viñeta borrosa) o que las salas ocultas sigan llegando a la GPU (2.4 M tris con una sola sala a la vista). Medir qué es (PC con el benchmark y Godot profiler/RenderDoc, luego tools/bench.sh android ZY22GLQFZW) y bajar el costo sin cambiar el look en Forward+.

**Decisiones:**
- ✓ 15.16 se cierra con tapas, LODs y piso Mobile; el costo por píxel de las mazmorras sigue en otra tarjeta (15.23) después del cuelgue del G23
  Por qué: El cuelgue del teléfono base era más urgente; las mazmorras en el G23 siguen a 3–6 fps en Alta y el perfil Bajo (50 %) las divide por ~2.
  Descartado: Seguir en 15.16 con cutaway, niebla de pozos y luces.

**Notas:** Atribución en el Edge (GPU ms, templo hub / chullpa / antesala): Alta 57/64/66; sin GridMaps 17/19/18 (paredes LA + piso ≈ 40 ms); sin luces puntuales −10–15; sin efectos LA −5; sin sondas −3. Al 50 % de resolución también baja a la mitad: triángulos de 5–7 k por celda de 2 m que además gastan fragmentos (quads 2×2).
- Tapas bakeadas a textura (37af5104): la tapa de cada pieza de pared (mosaico plano de 40×40 a y=3) pasa a un quad de 2 triángulos con textura nearest (tools/la_caps.gd, la_walls caps). Triángulos en el Edge: templo 1,33 M → 0,71 M, chullpa 2,68 M → 1,13 M, antesala 1,47 M → 0,75 M. GPU contra la corrida de las 23:00: Baja 59→33 / 42→30 / 36→26 ms, Plana 92→48 / 106→47 / 104→53 ms. Capturas Forward+ iguales (solo píxeles sueltos en bordes del mosaico del rim). Las caras traseras de la pared n quedan: el cutaway las dibuja como tapa en el corte.
- LODs de paredes (3bea4d28, tools/la_lods.gd): templo 0,72 M → 0,15 M triángulos, pero 0–3 ms de GPU: las mazmorras ya no están limitadas por triángulos. Toggle lods en BenchVariant (7db2e6c5).
- Piso en Mobile en una sola pasada de Voronoi (75364c10): piso_la.gdshader llama una vez a cells() con la normal del bisel analítica y un segundo paso 3×3; Forward+ compila el código de antes byte a byte y los parámetros siguen vivos (snow/ice). G23: antesala 223–229 → 143–147 ms (−35 %); chullpa demasiado ruidosa para leer (265–400 ms, ~3 fps).
- Corrección (-8f, 2026-10-21): el device lost del G23 no era del templo sino de la primera carga del overworld (OverworldInicio, antes de cualquier caso de mazmorra) → 15.21. Con luces, sondas o efectos apagados (uno por corrida) los 8 casos terminan, TemploHub incluido: 2,8–3,2 fps (GPU 304–344 ms, 0,15 M triángulos); antesala ~8 fps. Ojo: los tiempos absolutos del G23 de esas corridas son de un contexto que ya había perdido el device; las diferencias A/B intercaladas (piso −80 ms en antesala) sí fueron consistentes.
- Queda en el G23: mazmorras a 3–8 fps a 720p nativo, costo por píxel; el perfil Bajo (50 %, 15.19) lo divide por ~2. Seguir con costo por píxel (cutaway, niebla de pozos, luces) iría en otra tarjeta después de 15.21.
- Esconder los pisos de abajo: descartado por ahora, por los huecos se ve la sala de abajo; volver con occluders.
- Las kits regeneradas mantienen los parámetros snow/ice de Daniel en templo_la_kit.

### 15.17 Overworld: costo de los shaders en mobile · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

Daniel sospecha que pesa que todo sea shader en vez de texturas. Benchmark 15.14 en el Edge 30 Fusion: en el overworld la variante Plana (StandardMaterial3D en toda la geometría) baja la GPU de 30–41 ms a 20–27 ms, o sea ~30 % es costo de material; en el G23 el overworld va a ~4 fps con GPU 88–136 ms. Medir qué materiales pesan (terreno, pasto/plantas con viento, agua, riscos, decor: aplanar de a uno en el benchmark o con un BenchVariant nuevo) y darles una variante barata en el renderer Mobile (menos muestras, sin ruido procedural por píxel, bakear a textura lo que hoy se calcula) sin cambiar el look en Forward+. Medir con tools/bench.sh android ZY22GLQFZW --build. No toca las paredes LA (15.16) ni LOD/terreno en bloques (17.2).

**Prueba:** Capturas Mobile antes/después (inicio, cardonal, explanada del templo) iguales de estilo; Forward+ compila el código de antes (capturas iguales salvo ~0,01 % de píxeles por animación). Teléfono: tools/bench.sh android ZY22GLQFZW --build, variantes SinDetalle, SinViento, PlanaOutdoor, PlanaAgua, PlanaRiscos y SinLook intercalando Alta. Suite 768/768 en main.

**Notas:** Edge 30 Fusion, overworld (5 casos), GPU por cuadro; corridas con Alta intercalada porque el teléfono se calienta (Alta sube de ~30 a ~42 ms en 10 min).
- 15.13 (inicio de corrida fría): 36,3 → 29,5 ms de GPU (~20 → ~30 fps) contra la base de las 23:00.
- Detalle del suelo bakeado en Mobile (38b2312a): epiphany_outdoor lee dos texturas de mundo que se repiten cada 28 m (assets/epiphany/outdoor_detail_a/b.png, uniforms globales en project.godot; se rehacen con tools/bake_outdoor_detail.gd en ventana) en lugar del Voronoi y los ruidos por píxel. Ahorra 7–12 ms (A/B en la misma build). Forward+ sin cambios (#if CURRENT_RENDERER == RENDERER_MOBILE).
- Queda: efectos LA ~14 ms (→ 15.18), riscos ~2 ms, agua 1–4 ms, viento ~0.
- La variante Plana de 15.14 no aplanaba los GridMap (6270 celdas): arreglado en a7ae7797 (copia plana de la MeshLibrary). Nuevas variantes en a7ae7797: flat_shaders/flat_except, parameters, cases. El export de Android perdía BenchVariant.cases (PackedStringArray): pasa a Array[StringName] en 3ccd7c4f.
- Variante Mobile del agua (sin mipmaps de pantalla, 1 lectura de profundidad): capturas iguales; no se commitea porque no se mostró el ahorro ≥ 1 ms. En el G23 el agua cuesta ~15 ms en el bañado aun con ella; el costo es la copia de pantalla/profundidad en sí. Daniel (2026-10-21): el agua en mobile queda como está, sin la versión simple sin fundido en la orilla ni refracción.
Mergeado en main por -ae.

### 15.18 Efectos LA en Mobile: menos pasadas de pantalla · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

Medido por -88 en el Edge 30 Fusion (15.17, variante SinLook): en el overworld los efectos LA cuestan ~14 ms de GPU por cuadro (26,4 ms sin ellos contra ~40 con ellos), más que cualquier material. En Mobile cada efecto (TonoLA, NubesLA, SombraLA) copia el color a una textura rgba16f y lo vuelve a escribir (look_color.gd, 15.15): 6 pasadas de pantalla completa extra más las del AO, nubes y tono. Compartir una sola copia entre los tres (entra una vez, sale una vez) y, si se puede, juntar tono y nubes en una pasada. Forward+ sin cambios. Medir con tools/bench.sh android ZY22GLQFZW --build intercalando Alta entre variantes (el Edge se calienta en corridas largas).

**Decisiones:**
- ✓ Se mergeó la copia de color compartida de los efectos LA aunque en el G23 no se midió ganancia
  Por qué: Son 4 pasadas de pantalla completa menos por cuadro con el look idéntico; en el G23 el ruido (±10–15 ms) tapa la diferencia.
  Descartado: No mergearlo hasta mostrar ≥ 1 ms.

**Prueba:** Capturas Mobile y Forward+ iguales a la versión anterior (0,01–0,02 % de píxeles, animación). Contador temporal: 1 copia de entrada (sombra) + 1 de salida (tono) por cuadro. test_player_hole, test_overworld_run y suite completa en main.

**Notas:** look_color.gd (a56e3151, -88): los tres efectos LA comparten una sola copia del color en Mobile por cuadro: el color entra una vez (sombra) y sale una vez (tono), 2 pasadas de pantalla completa en vez de 6 en el overworld y 2 en vez de 4 en mazmorras. Un efecto deja el color en la textura compartida solo si en el cuadro anterior otro efecto lo siguió en el mismo punto y capa; si llega otra capa mientras hay una retenida, la vuelca primero. Lo peor que puede pasar es un cuadro sin efectos al cambiar el compositor; nunca pasa un color viejo.
Moto G23, intercalado (inicio/cardonal/bañado), GPU ms: copias compartidas 123,7 / 120,8 contra vecinos 129,4 / 126,5 / 115,5 / 124,2: sin diferencia medible en el G23 (ruido ±10–15 ms, limitado por otra cosa). Se mergea igual: son 4 pasadas de pantalla menos y el look es idéntico. Juntar tono y nubes en una pasada: no, ahorraría otra pasada y eso no se nota en el G23. El Edge no se usa más (teléfono de Daniel).

### 15.19 Perfiles de calidad (automático la primera vez, elegible en Opciones) · Revisión

**Prioridad:** alta · **Tamaño:** L · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

Daniel (2026-10-21): perfiles según el rendimiento del equipo, con uno para equipos modestos, y que se pueda cambiar en Opciones si alguien con mejor equipo quiere uno más alto.
- Perfiles Bajo / Medio / Alto como datos (un Resource por perfil en data/quality/): render_scale, sombras (incluidas las de plantas), SSAO, intensidad de los efectos LA, tope de fps. Se ajustan sin tocar código.
- Automático la primera vez que arranca: renderer Mobile → Bajo o Medio; PC → Alto. Calibración breve (~2 s con una escena fija, reusando el benchmark de 15.14): si el cuadro tarda demasiado baja un escalón. Decide una sola vez y lo guarda en settings.cfg; nunca vuelve a cambiar solo lo que eligió el jugador.
- Opciones: fila "Perfil" (Bajo / Medio / Alto) en la pantalla de opciones existente, según el canvas de mockups. Si el jugador toca una opción gráfica suelta, el perfil pasa a "Personalizado" y respeta lo suyo.
- Qué lleva Bajo sale de medir en el Moto G23 (Mali-G52), que quedó limitado por relleno (cardonal 0,29 M triángulos y 82 ms de GPU; overworld 7,6–11,6 fps en Alta): la combinación más barata que llegue a ~30 fps (render_scale 50–70 %, sombras más baratas o sin sombras de plantas, sin SSAO, efectos LA reducidos). Los defaults actuales de PC pasan a ser Alto.
- El agua en mobile queda como está (decisión de Daniel).

**Decisiones:**
- ✓ ¿Agregamos la fila Perfil (Bajo / Medio / Alto / Personalizado) al canvas de mockups, en Options_Tabs_Video?
  Por qué: El juego ya la tiene arriba de "Tope de cuadros", con el mismo estilo etiqueta + select; el canvas no la muestra y la regla es construir la UI desde el canvas.
  Descartado: Dejar el canvas como está y aceptar la diferencia.
  Respuesta: no veo por qué no

**Prueba:** tests/test_options.gd (perfiles, Personalizado, calibración por decide()). Suite 773/773 en main (4bc8849a). En ventana: Forward+ → Alto (6,7 ms), Mobile → Medio (2,6 ms); al reabrir no vuelve a calibrar. Benchmark en el G23 con las perillas de 28464b4f.

**Notas:** Mergeado en main por -ae (28464b4f perillas del benchmark, 697b9912 perfiles + calibración, b69d0225 fila Perfil en Opciones, 4bc8849a las sombras de plantas también apagan los arboles_* horneados de 17.2).
- Datos: data/quality/{bajo,medio,alto}.tres (QualityProfile): render_scale, sombras del sol, sombras de plantas (escenas de plantas, Decor y los 94 arboles_* del terreno), SSAO, efectos LA (2 todos / 1 sin nubes / 0 tampoco AO), tope de fps.
- Bajo: 50 %, sin sol, sin sombras de plantas, sin SSAO, efectos LA, 30 fps. Medio: 70 %, sol bajo, sin sombras de plantas, sin SSAO, 60 fps. Alto: los defaults de PC de hoy.
- Primera vez: perfil de la plataforma (Mobile → Medio, PC → Alto); detrás de la pantalla de carga el título mide 2 s la GPU del flyover a tamaño completo con la escala del perfil; si pasa 1,2× el cuadro de 30 fps (Mobile) o 60 fps (PC) baja un escalón. Se decide una vez y queda en settings.cfg. Un settings.cfg viejo no se calibra: conserva sus valores y queda en el perfil que coincide o en Personalizado.
- Opciones: Video > Gráficos empieza con Perfil; elegir uno mueve todas las filas gráficas; tocar una fila suelta muestra Personalizado (en la lista pero no elegible).
- Canvas de mockups: Daniel aprobó sumar la fila (decisión 1). Options_Tabs_Video (versión 43 del canvas) tiene Perfil arriba de "Tope de cuadros" (Bajo / Medio / Alto / Personalizado deshabilitado) y Resolución 3D suma 50 %, como el juego.
- G23 (inicio/cardonal/bañado): Bajo ~33 ms de GPU pero ~22 fps, porque el process de CPU tarda 35–53 ms → 15.20. Escala 70 → ~42 ms de GPU; 100 → ~59 ms. Cualquier sombra del sol a 50 % (incluso ortogonal de 20 m, atlas 1024, sin plantas) cuesta 46–58 ms: Bajo va sin sol. El AO LA cuesta ~1 ms y queda en Bajo.
- La calibración mide solo GPU; en el G23 el límite es la CPU.

### 15.20 CPU por cuadro del overworld en el G23 · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

Medido por -88 en el Moto G23 con el perfil Bajo (15.19): la GPU baja a ~33 ms pero el juego va a ~22 fps porque el proceso de CPU tarda 35–53 ms por cuadro. En el teléfono base los 30 fps no se alcanzan solo con calidad gráfica: el límite es la CPU. Perfilar qué se lleva el process en el overworld (scripts por cuadro, IA de los enemigos despiertos, partículas por CPU, física, animación, UI/HUD, señales) con el profiler de Godot o mediciones en el benchmark, y bajarlo sin cambiar el comportamiento. Medir en el G23 con tools/bench.sh android ZY22HH6Q99 (compartido con Asteroids; el Edge no se usa).

**Decisiones:**
- ! 15.20 se cierra con el overworld a ~30 fps en Bajo; no se cachea FindPlayer y el resto pasa a la GPU (15.25) · sin revisar
  Por qué: Con la CPU arreglada el límite que queda es la GPU cuando el teléfono se calienta (26–28 ms); cachear FindPlayer ahorra poco de los ~2 ms por paso de los enemigos.
  Descartado: Seguir en 15.20 con FindPlayer por tick y el costo de LimboAI + move_and_slide de los enemigos.

**Prueba:** G23 con tools/bench.sh android ZY22HH6Q99 --build, perfil Bajo, A/B intercalado. Suite 773/773 en main después de --import (2b8073c5).

**Notas:** Parte 1 (-88, wt/design-fix 3563683d → main fb8a31d8):
- Causa: NavigationAgent3D.set_target_position siempre pide un camino nuevo aunque el punto sea el mismo. Deambular, buscar, huir, perseguir y la mordida de la jauría lo asignaban en cada tick del BT, así que cada enemigo que se movía recalculaba el camino completo sobre la navmesh del overworld en cada paso de física.
- Arreglo: Enemy.path_to asigna el destino solo si se corrió más de 0,25 m (un destino fijo, una sola vez) o si el agente ya terminó; conserva el comportamiento de hoy en el último metro.
- Benchmark: dos nodos BenchMarker miden por cuadro los scripts de _process, los de _physics_process sumados sobre los pasos y la cantidad de pasos. El "process" de Performance incluye la sincronización y el dibujo del RenderingServer: los "35–53 ms de process" de la descripción no eran tiempo de scripts.
- G23, perfil Bajo: scripts de física por paso 6,3–8,0 → 4,8–6,0 ms; inicio, cardonal y bañado llegan a 29–30 fps (antes ~22) cuando la GPU queda debajo de ~25 ms.
Parte 2 (-88, 4583ab71 + f4c5b3c8 → main e1b97904 + 2b8073c5):
- Diagnóstico en el G23 (Bajo, por paso): scripts 4,1–5,7 ms; motor (Jolt + flush, el hueco entre el fin de los scripts y el próximo paso) 2,6–3,1 ms; navegación ~0,05 ms. Sin monitoring de áreas el motor baja a ~1,4 ms; sin enemigos los scripts bajan a ~3,1 ms (los enemigos cuestan ~2 ms por paso: BT de LimboAI + move_and_slide). Los "~8 ms de Jolt" de antes eran el paso más largo del cuadro, no el promedio.
- En escritorio las AreaZone eran ~60 % del costo del monitoring; los ~1250 hurtboxes de vegetación salen gratis (monitorables sin monitoring, máscara 0, estáticos).
- Arreglo: el cuerpo del player también está en la capa PLAYER (collision_layer 3) y las AreaZone enmascaran solo PLAYER; con LEVEL en la máscara Jolt filtraba en cada paso los pares contra todos los estáticos bajo cada zona. Ninguna máscara tiene el bit 2 sin el 1 (revisado por -88 y -ae), así que nada deja de ver ni empieza a ver al player. ActiveZones precalcula sus listas de alcance y cachea la zona de cada enemigo.
- A/B en el G23 (Nuevo/Viejo ×2, inicio/cardonal/bañado): motor por paso 2,05–2,42 contra 2,62–3,02 ms (−0,5 ms por paso, ~−1 ms por cuadro).
- Estado: el overworld va a ~30 fps estables en Bajo; con el teléfono caliente (GPU 26–28 ms) entra un tercer paso de física y cae a ~22. El límite pasa a ser la GPU (→ 15.25).
- Benchmark: columnas physics_engine y navigation, variantes de diagnóstico monitoring_off y enemies_off.
- No hecho: cachear FindPlayer por tick (se evalúa 3 veces por tick en el BTDynamicSelector de guard_bt); ganancia chica.

### 15.21 G23: trabajo de GPU de más de 3 s al cargar el overworld (device lost) · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-8f · **Etiquetas:** `optimizacion`

Hallado por -8f bisecando 15.16 en el Moto G23 (Mali-G52): el VK_ERROR_DEVICE_LOST no es del templo, es de la primera carga del overworld. Unos segundos después de cargar start.cfg (OverworldInicio) una entrega a la GPU pasa el timeout de 3 s del fence del driver Mali y el driver resetea la GPU ("Fence: waitForever ... fence didn't signal in 3000 ms", QUEUE_BUFFER_TIMEOUT, luego "Couldn't wait for Vulkan fence (VkResult error -4)" cada ~0,5 s). La app sigue y termina el benchmark, pero todo lo medido después corre en un contexto perdido, y en un jugador real es un cuelgue. Sospechas sin probar: la primera actualización de las ReflectionProbe (6 caras × escena entera) o el primer cuadro del overworld con todo visible (~2 M triángulos). Bisecar arrancando la corrida en un caso de mazmorra y con las sondas en update_mode always/apagadas en Mobile; arreglar sin cambiar el look en Forward+. Medir con tools/bench.sh android ZY22HH6Q99 --build (compartido con Asteroids; el Edge no se usa).

**Decisiones:**
- ✓ En celulares las partículas de ambiente (hojas, polvo, polvo de los pozos) arrancan vacías y se llenan en los primeros segundos
  Por qué: Simular varios segundos de golpe en el primer cuadro colgaba la GPU del G23 (device lost); en PC siguen arrancando llenas.
  Descartado: Repartir la simulación inicial en varios cuadros (más complejo); menos emisores de hojas.

**Prueba:** G23: tools/bench.sh android ZY22HH6Q99 --build con solo Alta desde OverworldInicio; logcat sin "Couldn't wait for Vulkan fence (VkResult error -4)". PC Mobile: GPU del primer cuadro tras la carga sin pico. Suite 773/773 en main.

**Notas:** Causa (-8f): el preprocess de los GPUParticles3D en el primer cuadro después de una carga. El overworld tiene ~200 emisores falling_leaves en los árboles con preprocess de 3 s (sin fixed_fps son 90 pasos de cómputo cada uno), más dust_motes (7 s) y el polvo de los pozos de caida_la (9 s): miles de dispatches en una sola entrega.
Arreglo (6bf8a8da, mergeado por -ae): src/world/mobile_particles.gd pone preprocess = 0 en _enter_tree solo en el renderer Mobile; va en falling_leaves.tscn, dust_motes.tscn y el Polvo de caida_la.tscn. En el teléfono las hojas y el polvo se llenan en los primeros segundos. Forward+ conserva el preprocess y se ve igual.
PC, renderer Mobile, 1600×720, GPU del primer cuadro tras la carga: overworld 26,6 → 6,1 ms (mediana 1,9), chullpa 28,9 → sin pico, templo 23,1 → sin pico.
G23 (main + 6bf8a8da, solo Alta, 8 casos desde OverworldInicio; debug/tmp/ow2/draw/g23_verify_15-21_3e.json): 0 VkResult -4 (antes cada ~0,5 s después de la primera carga). Primeros números del G23 con el contexto vivo, GPU: inicio 75 ms (11,5 fps), arboleda 86, cardonal 75, bañado 90, cumbre 105 (8,2 fps), templo hub 315 (3,1 fps), chullpa 327 (2,9 fps), antesala 146 (6,4 fps). Primera carga del overworld 36,5 s.
Queda (→ 15.22): durante la primera carga del overworld una entrega sigue pasando los 3 s del fence de Mali; esta vez el driver no reseteó.

### 15.22 G23: la primera carga del overworld todavía traba la GPU más de 3 s · En curso

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-8f · **Etiquetas:** `optimizacion`

Resto de 15.21 (-8f, 2026-10-21): con el preprocess de partículas apagado en Mobile ya no se pierde el device, pero durante la primera carga del overworld (antes de "Partida cargada start.cfg") el logcat del G23 sigue mostrando "Fence: waitForever: waiting for GPU completion ... didn't signal in 3000 ms" en el timeline de mali, de nuestro proceso y de surfaceflinger. Esta vez el driver no reseteó, pero está al borde. En PC el costo que queda del primer cuadro es 6 ms, así que es algo propio de Mali o de la carga. Sospechas: subida de texturas/VRAM (588 MB en el overworld), el bake de radiancia del cielo, o el cuadro de la pantalla de carga mientras se instancia la escena. Además la primera carga tarda 36,5 s. Bisecar en el G23 y bajar esa entrega por debajo de ~1 s sin cambiar el look en Forward+. Medir con tools/bench.sh android ZY22HH6Q99 --build (compartido con Asteroids y con -88 en 15.20; el Edge no se usa).

### 15.23 G23: templo hub y chullpa a 3 fps (costo por píxel por sala) · Revisión

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-25 · **Etiquetas:** `optimizacion`

Sigue de 15.16. Con el contexto vivo (15.21), Alta en el G23 a 720p: templo hub 315 ms de GPU (3,1 fps) y chullpa 327 ms (2,9 fps) contra antesala 146 ms (6,4 fps), con triángulos ya bajos (tapas bakeadas y LODs). La diferencia entre salas apunta a algo propio de esas salas: luces puntuales por sala, cutaway de paredes, niebla de pozos, sondas, efectos LA. Medir por sala con los toggles del benchmark (lights, probes, effects, gridmaps, flat_shaders) y bajar el costo por píxel en Mobile sin cambiar el look en Forward+. Medir con tools/bench.sh android ZY22HH6Q99 --build.

**Decisiones:**
- ? ¿En el perfil Bajo apagamos las luces puntuales de las mazmorras (antorchas, brillo de pozos) y dejamos solo la luz de la sala? · pregunta abierta
  Por qué: En la antesala del G23 ahorra ~10 ms de GPU (116 → 107 ms en Alta); la sombra del sol ya está apagada en Bajo. Cambia el look: las salas quedan más parejas, sin los círculos de luz de las antorchas.
  Descartado: Dejarlas en todos los perfiles; apagarlas solo en el renderer Mobile; dejar una sola luz por sala.
- ! La profundidad de campo de las mazmorras se prende solo durante los zooms de la cámara y con un jefe alto a la vista (enfoque_la), en todos los renderers · sin revisar
  Por qué: En las salas normales no cambia nada en pantalla (el desenfoque lejano está apagado en los niveles LA y el cercano cae a ~29 m de la cámara, donde no hay nada), pero la pasada corre cada cuadro: 8–16 ms de GPU en el G23. Mismo look que hoy, el costo solo en esos momentos.
  Descartado: Apagarla en Mobile o en el perfil Bajo (cambia los primeros planos y los jefes altos); la versión barata (bokeh calidad 0, forma caja) recupera solo la mitad.

**Prueba:** Pasos 1 y 2: capturas Forward+ sin cambios de pared. Paso 3: las 61 salas en Forward+ en pausa con el desenfoque prendido contra apagado al nivel del ruido (hub 93 contra 91 px, antesala 76 contra 87, Pluma 76 contra 83); revelación cuadro a cuadro: prende en el cuadro 1, sigue en la ida y la vuelta, apaga con revealing=false; capturas a mitad de revelación código viejo contra nuevo 1,1–3 k px contra 0,9–1,4 k entre dos corridas del nuevo (polvo, corazón del HUD, una llama). Suite 773/773 en main después de --import (473791ef).

**Notas:** OJO (15.26): en el G23, cambiar el shader de un material en tiempo de ejecución (BenchVariant.swap_shader, flat_materials) arruina la medición: la variante cambiada mide casi lo mismo que sin luces puntuales (las paredes pierden las omni o caen en otro pipeline). Solo valen las corridas planas (el APK con el cambio, sin cambiar shaders) y las variantes que tocan parámetros o propiedades.
Paso 1 (-25, wt/art-hsm 07c90f8a → main 0a99ef0f): los seis kits LA usan cutaway_la.gdshader, el cutaway sin sus dos discard (el código común pasa a cutaway.gdshaderinc). En los niveles LA los discard nunca corrían: el corte de la pared sur de la cámara apunta a wall/column/epiphany_stone.tres y el kit tiene copias la_walls._glossy (cut_area queda en cero), y el agujero del player está cerrado desde 11.134. Pero en Mali un shader que PUEDE descartar pierde early-Z y forward pixel kill. la_walls._glossy asigna cutaway_la, así que un refresh lo mantiene; el kit gris y los materiales viejos conservan el corte.
- Confirmado con corridas planas en Alta: chullpa 223–260 → 145–153 ms, templo hub 136–142 → 117,6 ms. (El A/B original con swap_shader daba números parecidos, pero no vale por lo de arriba.)
- Lo que queda sigue siendo el GridMap: piso y resto de las paredes.
Paso 2 (-25, wt/art 4547624f → main 105bc19c): las paredes LA cullean las caras traseras (cutaway_la, cull_disabled → cull_back) en los dos renderers; la cámara fija nunca las ve. Capturas sala por sala con el juego en pausa, A-B-A: las diferencias A-B son del tamaño de A-A (animación), ninguna de pared. Ganancia SIN CONFIRMAR: el 124–136 → 116 de la antesala salió de una variante con swap_shader; la corrida plana en Alta después del merge dio 122,4 ms. Ganancia chica o nula; se queda porque no cambia el look ni empeora.
Paso 3 (-25, wt/art 52aa3eac → main 473791ef): la profundidad de campo cuesta 8–16 ms en el G23 y en las salas normales no se ve (el desenfoque lejano está apagado en los niveles LA y el cercano cae a ~29 m de la cámara). enfoque_la prende dof_blur_near_enabled solo durante una revelación (cam.revealing) o con un jefe enfoque_alto en cuadro (3 m de margen en la línea pies-cabeza) y en la sala de la cámara; el chequeo de sala hace falta porque el Mallqui de la chullpa está en el Sótano, debajo de otras salas, y con cámara cenital caía en cuadro desde salas que no lo muestran. Durante un cambio de sala no se mira la sala. Queda prendida en 15 de 61 salas (intros de jefes, ojos) y en templo_Pluma por el Mallqui; aun ahí prendida contra apagada no cambia la imagen. Perillas de benchmark dof, dof_quality, dof_shape (dof=false pone los atributos en null, sin cambiar shaders: medición válida). G23: templo hub 117,6 → 102,6–104,2 ms, antesala 122,4 → ~109 ms (igual que sin DOF).
Abierto para Daniel (decisión 1): apagar las luces puntuales en Bajo (−10 ms en la antesala en Alta; en Bajo −10 a −24 ms en chullpa, queñoa, totora y cumbre, 15.26). Siguiente: las mazmorras en el perfil Bajo (15.26).

### 15.24 Comprimir las mallas de los kits de paredes LA · Revisión

**Prioridad:** media · **Tamaño:** M · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

Seguimiento de 15.5, Daniel (2026-10-21): "Comprimir". Los *_la_kit.tres traen sus propias mallas sin comprimir (≈200 MB de .tres de texto) porque la_walls las arma con SurfaceTool.commit() sin flags. Pasar Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES (sin tangentes, como en 15.5) al commit de las piezas, tapas (15.16) y LODs, y regenerar los kits. Si se puede, regenerar solo los kits sin refresh de niveles; si hace falta refresh: rebasear sobre main justo antes, respetar los guardados del editor de Daniel (memorias refresh-editor-saved-levels, refresh-drops-instance-overrides, level-rim-and-editor-navmesh) y avisar. Medir peso de los .tres, VRAM y carga de chullpa/templo a 1080p (antes VRAM 1133 MB, chullpa ≈2,4 s) y capturas antes/después en Forward+ y Mobile sin rendijas ni cambios de sombreado.

**Prueba:** Capturas antes/después en Forward+ y Mobile: solo cambian el polvo, las llamas de las antorchas y el fundido del título de la sala; sin huecos ni cambios de sombreado. Suite completa en main 773/773 (78dc0a87).

**Notas:** -88 (wt/design-fix 3dafe6cf → main 78dc0a87): la_walls guarda todas las mallas del kit con ARRAY_FLAG_COMPRESS_ATTRIBUTES (tools/la_compress.gd), sin tangentes y con los mismos buffers de índices de LOD; bake, refresh y caps ya escriben comprimido. El modo nuevo `compress` comprimió los 6 kits en el lugar sin refrescar ni tocar ningún nivel: mismos ids de ítem, materiales, parámetros de shader, índices y LODs; error máximo 0,11 mm en posiciones y 0,4° en normales.
- *_la_kit.tres: 134,6 → 84,7 MB.
- 1080p escritorio, carga en caliente / VRAM, antes → después: chullpa Forward+ 3,27 s / 1174 MB → 3,21 s / 1168 MB; templo Forward+ 4,67 s / 1171 MB → 3,99 s / 1164 MB; chullpa Mobile 3,20 s / 609 MB → 2,74 s / 603 MB; templo Mobile 4,27 s / 619 MB → 3,99 s / 611 MB. Las mallas ocupan 6–8 MB menos de buffers; el resto de la VRAM son texturas.

### 15.25 G23: GPU del overworld en Bajo para sostener 30 fps con el teléfono caliente · Pausado

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

Sigue de 15.20 (-88, 2026-10-21): con la CPU arreglada el overworld va a ~30 fps en Bajo, pero cuando el G23 se calienta la GPU sube a 26–28 ms, entra un tercer paso de física por cuadro y cae a ~22 fps. Bajar la GPU del overworld en el perfil Bajo (y en Mobile en general) a ~20 ms para que aguante caliente: medir qué queda por pasada (detalle bakeado del suelo de 15.17, agua, efectos LA, plantas, decor, sombras) con los toggles del benchmark en corridas largas que calienten el teléfono, y recortar sin cambiar el look en Forward+. Medir con tools/bench.sh android ZY22HH6Q99 --build (APK por worktree desde bfaf4138; compartido con -8f y -25; el Edge no se usa).

**Decisiones:**
- ? ¿El perfil Bajo puede apagar el glow (brillo alrededor de luces y zonas claras)? · pregunta abierta
  Por qué: En el G23 ahorra ~1,2 ms de GPU por cuadro, parte del margen que falta para que el overworld no caiga al estado lento (cuadro 45 ms). Cambia el look solo en Bajo; Medio, Alto y Forward+ quedan igual.
  Descartado: Dejar el glow en todos los perfiles y buscar el margen en el agua y la geometría.

**Notas:** Hallazgos parciales (-88, G23, perfil Bajo, corridas intercalando Base):
- No es calor: el G23 tiene dos estados estables, bueno (cuadro 33 ms, GPU 22–24 ms) y malo (cuadro 45 ms, GPU 27–30 ms, también suben los scripts por paso). Después de 20 min la última Base estaba igual de bien que la primera. Puede que esos dos estados sean presión de memoria (ver 15.27).
- No es la física: con tope de 2 pasos por cuadro no cambia (29,1 contra 29,2 fps en 7 pares) y una corrida con tope cayó igual al estado malo. Lo dispara la GPU (el governor baja relojes cuando cae la tasa): hay que ganar margen de GPU.
- Por pasada (--gpu-profile, Base, por cuadro): geometría opaca ~12–14 ms (Mali reparte mal los timestamps entre "Setup Sky" y "Render Opaque"); transparentes + efectos LA 4,5–6; canvas 2,3; glow 1,5; tonemap 1,4; partículas 0,4.
- La resolución pesa poco (escala 25 baja ~3 ms); con la cámara sin ver nada (cull_mask 0, 255 triángulos) la GPU sigue en 13–16 ms: costo fijo de pipeline.
- Válidos (variantes de propiedad o visibilidad): glow ~1,2 ms (glow_enabled = false); efectos LA juntos ~1,5–2 (nubes ~0,5–1, AO ~0,7, tono ~0,3; compositor null o effect.enabled); decor, FSR contra bilineal, GridMap, luces puntuales ocultas, radiancia/modo de proceso del cielo ~0.
- Por visibilidad (relativo, dentro de una corrida con el teléfono degradado): sin terreno −5 a −8 ms; sin agua −6 a −9 (a velocidad normal ~−3 a −4,5, confirma por un método válido lo que daba PlanaAgua); sin terrazas −2 a −4.
- NO VÁLIDOS hasta volver a medir (salían de flat_materials, que cambia materiales en tiempo de ejecución; en el G23 eso mezcla un efecto de pipeline, ver 15.26): todo plano ~3–4 ms y el reparto fijo/post/geometría/materiales que usaba Plana.
- 15.20 no se ve afectado (la máscara de zonas fue A/B por código; monitoring_off y enemies_off son propiedades).
- EN PAUSA: 2026-10-21 a la tarde el G23 quedó ~1,8× más lento en todas las pasadas por falta de memoria (kswapd al 97 %, swap; el juego usa ~1,5 GB). Los números absolutos contra los de la mañana y las A/B entre corridas separadas no valen hasta que se resuelva. -88 sigue con 15.27; después: la variante Mobile del agua de 15.17 como A/B limpia con dos APK.
- Perillas nuevas del benchmark (sin commitear todavía): glow, fsr, hidden, camera_cull, max_physics_steps, sky_process_mode, sky_radiance y la columna slow (fracción de cuadros de más de 40 ms); la variante swap_shader del agua se sacó.
- La cola del G23 se trabó dos veces porque el servidor adb heredaba el fd del lock de bench.sh; arreglado en main 41050f83 (-88).

### 15.26 G23: las mazmorras en el perfil Bajo · En curso

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-25 · **Etiquetas:** `optimizacion`

Sigue de 15.23, que midió en Alta (templo hub ~103 ms, antesala ~109, chullpa ~145 ms de GPU en el G23 después de cutaway sin discard, cull_back y DOF solo cuando se ve). El jugador del G23 va a estar en Bajo (15.19: 50 %, sin sol, sin SSAO, 30 fps). Medir las tres mazmorras de referencia y el resto de los casos de mazmorra en Bajo, ver cuánto falta para 30 fps y qué domina (GridMap: paredes y piso LA ≈ 75 ms en Alta; luces puntuales; efectos LA) y bajarlo sin cambiar el look en Forward+. Lo que cambie el look (por ejemplo las luces puntuales, pregunta abierta en 15.23) va como pregunta a Daniel. Medir con tools/bench.sh android ZY22HH6Q99 --build (compartido con -88 y -8f; el Edge no se usa).

**Prueba:** Paso 1: 61 salas en Forward+ y 5 en Mobile en pausa iguales al nivel del ruido. Suite 773/773 en main después de --import (6a8bfac0). Corridas planas en Bajo con el cambio en el APK: sin ganancia.

**Notas:** Punto de partida en Bajo (G23, GPU p50, moto_g23_20261021_1336/1347): hub ~43, chullpa ~62, antesala ~43, queñoa ~54, totora ~52, cumbre ~70 ms. Sin GridMap 24–39 ms; sin luces puntuales −10 a −24 ms en chullpa, queñoa, totora y cumbre (pregunta abierta en 15.23); efectos LA y sondas ~0; LOD más agresivo (2–4 px) y octantes más chicos (2/4) no ganan nada.
HALLAZGO ABIERTO: en el G23, el mismo shader asignado en tiempo de ejecución cuesta ~20 ms menos que el que viene de cargar el nivel, con la misma imagen. Bajo, GPU p50 chullpa / totora / cumbre: Baja 65,6–60,1 / 51,5 / 70,7–73,0; BajaCopia (cutaway_la cambiado por una copia idéntica en otro archivo) 53,7–52,8 / 43,9–43,0 / 48,1–50,8; BajaSinLuces 46,6 / 40,7 / 47,5. Cambiar al mismo objeto Shader no hace nada (Godot lo ignora). Capturas en el teléfono (CumbreLargo, 24 s por variante, recorte de la sala): Baja contra Baja 8,5 k px (media 0,005), Baja contra BajaCopia 5,8 k px (0,0035, ruido de nieve y partículas), Baja contra SinLuces 249 k px (0,09, más azul, sin luz cálida de antorchas); GPU en la misma corrida Baja 73,8, BajaCopia 52,2, SinLuces 51,7. O sea que las paredes cambiadas NO pierden las luces: los materiales del nivel parecen quedar en un pipeline lento (ubershader o de reserva) y el reasignado se compila especializado. Si se confirma son ~20 ms por nivel sin cambiar el look. -25 mide si cambiar a la copia y volver al original a los 0,3 s también sale rápido (sería recrear el material, no el archivo). Mientras tanto, las ganancias medidas con swap_shader/flat_materials mezclan este efecto con el del cambio: no cuentan como ganancia del cambio.
Paso 1 (-25, wt/art a9fd318b → main 6a8bfac0): cutaway_la define CUTAWAY_LA (posición y normal de mundo desde el fragmento, sin varyings). Sin ganancia propia: las corridas planas con el cambio en el APK dan lo mismo que antes. -25 lo revierte en su próximo commit.
El benchmark suma los casos Queñoa, Totora y Cumbre (spawn, radio 1,5).
Siguiente: explicar el hallazgo de pipeline; después el piso procedural (piso_la) y lo que queda de las paredes, con corridas planas.

### 15.27 G23: memoria del juego (1,5 GB con swap en un teléfono de 4 GB) · En curso

**Prioridad:** alta · **Tamaño:** M · **Responsable:** project-epiphany-88 · **Etiquetas:** `optimizacion`

2026-10-21 a la tarde el G23 corre ~1,8× más lento que a la mañana en todas las pasadas (Base en Bajo GPU 36–44 contra 22–24 ms; canvas 4,3 contra 2,3; tonemap 2,7 contra 1,4) sin calor (thermal 0, GPU 45–53 °C). El teléfono está sin memoria: 55–113 MB libres de 3,8 GB, kswapd0 al 97 % de CPU, load average ~17. El mayor consumidor es el juego: com.example.projectepiphany 1,62 GB PSS, VmRSS 1,12 GB + 378 MB de swap durante una corrida de benchmark (Chullpa y Cumbre). Medir la memoria del juego en Mobile por caso (overworld, cada mazmorra, después de cambiar de nivel): Performance MEMORY_STATIC, RENDERING_INFO_VIDEO_MEM_USED/TEXTURE_MEM_USED/BUFFER_MEM_USED, y el PSS del proceso; ver si crece entre casos (algo que no se libera al cambiar de nivel) y qué domina (kits LA embebidos, texturas, mallas, audio). Bajarla para que el G23 no swapee sin cambiar el look en Forward+; lo que cambie el look va como pregunta a Daniel. Sumar la memoria como columna del benchmark. Las corridas con el teléfono degradado valen solo en relativo dentro de la misma corrida.

## M17 — Después de la demo  (0/2)

Lo que sale de M11 para después de la demo: rejugabilidad y extras.

### 11.32 Modo difícil o contrarreloj · Pendiente

**Prioridad:** baja · **Etiquetas:** `rejugabilidad`

Un modo extra que se desbloquea al terminar el juego, difícil (más daño, menos drops) o contrarreloj, para darle rejugabilidad.

- [ ] Elegir uno
  Difícil: más daño y menos drops. Contrarreloj: tiempo total al final.
- [ ] Desbloquear al terminar

**Prueba:** Tras los créditos aparece la opción; una partida en ese modo cambia lo prometido.

### 17.3 Probar en mobile · En curso

**Prioridad:** baja · **Etiquetas:** `build`

Daniel (2026-10-20): algo para testear después. Ver qué pide que el juego corra en un teléfono: preset de export Android (y iOS si hace falta), si alcanza el renderer Mobile o hay que bajar a Compatibility (shaders propios, viento, SSAO, sombras), rendimiento y memoria en un equipo medio, y controles táctiles (stick virtual, botones de ataque, ítems y Z-target) o un gamepad por Bluetooth. También la UI chica en pantalla de teléfono y las zonas seguras.

**Notas:** Daniel (2026-10-20): equipos para probar. Baseline: Moto G23 (MediaTek Helio G85, GPU Mali-G52, pantalla 720p): el objetivo de rendimiento se mide en este. También el Moto Edge 30 Fusion de Daniel (Snapdragon 888+, Adreno 660, 1080p), como gama alta. Por ahora el G23 lo usa otro proyecto: arrancar con el Edge 30 y pasar al G23 cuando se libere.

## Listas

### Assets de audio  (3/6)

- [x] Kenney Impact Sounds (CC0) — golpes, daño, bloqueo, macetas, reflejo · assets/audio/sfx/kenney_impact-sounds
- [x] Kenney RPG Audio (CC0) — cortes, rodada, puertas, clics · assets/audio/sfx/kenney_rpg-audio
- [x] Kenney Interface Sounds (CC0) — rechazo, levantar, sonidos de menú · assets/audio/sfx/kenney_interface-sounds
- [ ] Música de verdad para overworld y templo (hoy: capas sintetizadas por src/tools/render_music.gd)
- [ ] SFX de explosión, secreto, curación y temblor (hoy sintetizados en Feel)
- [ ] Pasos (footsteps) y ambiente del templo (Kenney Impact Sounds trae pasos; falta el evento)

## Playtest

### Revisión: lo listo para probar  (27/27 probadas)

1. [x] 11.130 Bocas de cueva talladas en el risco · Hecho · anda — Falló (pared de la cueva de la bomba, ermita bloqueada solo por dentro, D4 como cueva común); se arregló en 12.29, 11.166 y 11.168, que andan.
2. [x] 11.125 Puzzle de bloques de la cota: probar empujando y ubicar región · Hecho · anda — De andar anda, pero el 1 no se entiende que la piedra se puede levantar. Aparte es rarisimo tener que tirarla y apuntarle para que caiga sobre el boton. Este debería ser de presion de los que alcanza con que pisa el player.
   El 2 sería mas reconocible si el icono del plate sea el mismo que tienen los bloques, ademas uno se puede cambiar por el de la vasija y poner una vasija grande reemplazando uno de los bloques. Y la cota reforzada debería estar en otro lado, puede ser una recompensa de mitad de la ultima dungeon
3. [x] 11.111 Cactus, árboles y matas se cortan como el pasto · Hecho · anda
4. [x] 7.11 Overworld: huecos de salto largo y mini quest de las sandalias · Hecho · anda
5. [x] 11.118 Sandalias: correr manteniendo y salto largo con la pluma · Hecho · anda
6. [x] 11.24 Más secretos en el overworld · Hecho · anda
7. [ ] 12.41 Totora (D3) en estilo Link's Awakening y su entrada · Revisión · **falla** — Todas las puerta sobresalen y se ven la pared de la sala siguente
   si me caigo al agua y pierdo, el player cae al vacio y luego aparece la pantalla de "You Fell"
   no hay asset correcto para la pared quebrable
8. [x] 11.30 Ítem de D3: el gancho · Hecho · anda
9. [x] 11.28 Atajos que se abren al volver · Hecho · anda — anda, pero no debería hacer un fade. Debería haber una animacion del player subiendo y bajando
10. [x] 11.46 Jefe: game juice · Hecho · anda
11. [x] 11.29 Overworld después del jefe · Hecho · anda
12. [x] 7.9 Rediseño del overworld como hub de varias mazmorras · Hecho · anda — La D4 parece mas una cueva que una dungeon
13. [x] 7.10 Overworld con forma de Zelda 2D, no cuadrado · Hecho · anda
14. [ ] 12.40 Estilo Link's Awakening en las mazmorras reales: cámara y assets nuevos · En curso · **falla** — Hay cosas que no tienen estilo
15. [x] 11.117 Huecos a otro piso se ven distintos de los fosos · Hecho · anda
16. [x] 11.5 Galería de trampas: pinchos · Revisión · anda — Anda, pero el cofre detrás de los pinchos es una llave obligatoria para avanzar y se necesita antes de la pluma. Por lo que es imposible abrir el cofre sin hacerse daño.
17. [x] 11.98 La cámara muestra lo que se desbloquea · Hecho · anda
18. [x] 11.112 Fantasmas al esquivar · Hecho · anda
19. [x] 11.102 Mapa: nombres de zona chicos y solo los que importan · Hecho · anda
20. [x] 11.103 El minimapa se transparenta con el player debajo · Hecho · anda
21. [x] 11.104 Ítems de la mazmorra en la pantalla del mapa · Hecho · anda
22. [x] 11.114 Botellas en su propia fila de la pestaña Ítems · Hecho · anda
23. [x] 11.106 Intro al día con el overworld nuevo · Hecho · anda
24. [x] 11.107 Mejorar la ambientación · Hecho · anda
25. [x] 10.19 Fin de la demo · Hecho · anda
26. [x] 10.24 Tope de FPS · Hecho · anda
27. [x] 10.25 Sombras del sol acordes a la cámara cenital · Hecho · anda

### Overworld: laguna, halos, minimapa y cámara  (4/4 probadas)

1. [x] 11.140 Overworld (Lagoon): z-fighting entre el pasto y el camino de tierra · Hecho · anda
2. [x] 11.143 Overworld: delineado/halo oscuro raro alrededor de árboles, cardones y bordes · Hecho · anda
3. [x] 11.148 Minimapa del overworld desactualizado (la quebrada sale como abismo negro) · Hecho · anda — Es un poco tosco como aparece en el minimapa, pero es detalle menor.
4. [x] 11.134 Oclusión: reemplazar el agujero por cámara cenital sobre el player · Hecho · anda — Funciona, pero solo debería ser para las paredes. No para objetos/plantas, para eso está el x-ray. Y el movimiento es un poco nauseabundo.

### Revisión del 14 de octubre: overworld, mazmorras y sistemas  (50/60 probadas)

1. [x] 11.168 D4 (Cumbre): entrada exagerada como las otras mazmorras · Hecho · anda
2. [x] 11.130 Bocas de cueva talladas en el risco · Hecho · anda — Falló (pared de la cueva de la bomba, ermita bloqueada solo por dentro, D4 como cueva común); se arregló en 12.29, 11.166 y 11.168, que andan.
3. [x] 11.166 Santuario con una sola entrada: su muro agrietado · Hecho · anda
4. [x] 11.146 Overworld: el ojo del puente a la Necrópolis no se ve ni se puede flechar · Hecho · anda
5. [x] 11.147 Overworld: caer al sector de arriba (entre riscos, junto a la meseta clara) deja softlock · Hecho · anda
6. [x] 11.131 Pozo junto a la Chullpa: caer sin bombas deja softlock · Hecho · anda
7. [x] 11.159 Overworld con el arte de las mazmorras: brillo LA y más detalle en el piso · Hecho · anda
8. [x] 11.165 La cámara cenital se activa en bordes y muros bajos de una sala · Hecho · anda
9. [x] 11.29 Overworld después del jefe · Hecho · anda
10. [x] 12.29 Muro agrietado LA de cueva (muro_agrietado_cueva_la) · Hecho · anda
11. [x] 11.132 Cuevas: los enemigos se quedan quietos · Hecho · anda
12. [x] 11.133 Vasija chica cargada no se ve con el x-ray · Hecho · anda — Mejor, pero no tiene que haber x-ray cuando se levanta algo
13. [x] 11.135 Al caer, el player se inclina hacia el piso · Hecho · anda
14. [x] 11.164 Lo que esconde una pared agrietada no se ve desde arriba · Hecho · anda
15. [x] 11.136 Chullpa: la reja de la entrada queda fuera de la pared · Hecho · anda
16. [x] 11.139 Chullpa: el cofre sobre la plataforma no se alcanza saltando · Hecho · anda — se ve horrendo y no soluciona el mismo problema del lado izquierdo
17. [x] 11.138 Chullpa sub-boss: asset para el cuadrado donde después se salta · Hecho · anda
18. [x] 11.155 Chullpa: la momia aparece en vez de saltar hacia el player; onda expansiva con shader vistoso · Hecho · anda
19. [x] 11.169 Galería de trampas: la pluma no salta por encima de los pinchos · Hecho · anda — necesita un poco de fine-tuning, por ahi invisibilidad por 2-4 frames al saltar y aterrizar
20. [x] 11.141 Queñoa 2P (Canopy): símbolo azul sin sentido y puerta bloqueada invisible · Hecho · anda
21. [ ] 11.144 Queñoa S1 (Raíces): reja fuera de la pared y puerta con llave detrás de una reja de puzzle · Revisión
22. [ ] 11.145 Queñoa S1 (Sala de los ojos): placa que no hace nada, z-fighting en el cofre y símbolo raro en la puerta · Revisión · **falla**
23. [x] 11.160 Ojos de la Queñoa: los párpados siempre se abren y cierran animados · Hecho · anda
24. [x] 12.23 Ojos de la Queñoa y Ojo Vigía: modelo propio parecido al ojo del jefe final, más simple · Hecho · anda
25. [x] 11.149 Al entrar a una sala se puede caer al agua y reaparecer sobre el agua (softlock) · Hecho · anda
26. [x] 11.150 Gancho: el targeting marca un poste de otra sala/piso · Hecho · anda
27. [ ] 11.151 Totora 2P: se ve la sala del piso de abajo · Revisión
28. [ ] 11.153 Totora: cruce con gancho a través de la puerta no se entiende; poner plataforma/poste en la propia sala · Revisión · **falla**
29. [ ] 11.154 Totora: no hay dónde reponer flechas cerca · Revisión
30. [x] 11.167 Totora: caer al agua y perder deja al player cayendo al vacío antes de "You Fell" · Hecho · anda
31. [x] 11.161 Jefe final: la puerta norte de la sala queda escondida · Hecho · anda
32. [x] 11.162 Retirar el templo viejo (levels/temple.tscn) · Hecho · anda
33. [ ] 11.93 Jefe: aflojar la fase 3 y el modelo que se hunde · Revisión · **falla** — Se siguen hundiendo un poco las manos
34. [x] 11.152 Z-target: al activarlo, priorizar el enemigo más cercano · Hecho · anda
35. [x] 11.142 Mapa de pausa: LT/RT van rapidísimo; mover con las flechitas · Hecho · anda
36. [x] 11.158 Piso LA: patrón de tablones raro · Hecho · anda
37. [x] 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la) · Hecho · anda
38. [x] 12.21 Ojo interruptor: la pupila sigue al player y se parece al ojo del jefe final · Hecho · anda
39. [x] 11.157 Mazmorras: los tiles del GridMap no se alinean con la grilla del editor · Hecho · anda
40. [x] 12.25 El ojo del logo en game over, selección de idioma y carga · Hecho · anda
41. [x] 12.27 VFX mágicos con shaders y partículas (sin texturas) · Hecho · anda
42. [x] 10.19 Fin de la demo · Hecho · anda
43. [x] 11.108 Cargar en la misma escena desincroniza puertas y flags · Hecho · anda
44. [x] 11.88 Niveles referenciados por ruta: saves y portales frágiles · Hecho · anda
45. [x] 11.75 AreaZone: id estable para guardar las zonas visitadas · Hecho · anda
46. [x] 11.80 BossArena tiene los flags y el premio de D1 fijos en el código · Hecho · anda
47. [ ] 11.81 Dungeon.id por defecto d1 y prefijos de flags fijos · Revisión
48. [ ] 11.82 Daño que no pasa por el Hurtbox · Revisión
49. [ ] 11.83 Un solo camino para spawnear proyectiles, bombas y pickups · Revisión
50. [ ] 11.84 Ítems: que la estrategia decida, no la máquina de estados · Revisión
51. [ ] 11.85 Combate y HSM: casos que fallan en silencio · Revisión
52. [ ] 11.86 GameState: escrituras con señal y carga sin emisiones parciales · Revisión
53. [x] 11.87 Valores de ajuste al inspector · Hecho · anda
54. [x] 10.23 Tests en paralelo · Hecho · anda — Verificada en 10.28 (paso 15): ~16 s, estable.
55. [ ] 10.27 Nodos creados por código pasan a sus .tscn · Revisión
56. [x] 11.171 Mapa del overworld: el cursor vuelve al player al moverlo hacia un lado · Hecho · anda
57. [x] 11.172 Viaje rápido: el foco no va al botón y A abre la pregunta una y otra vez · Hecho · anda
58. [x] 11.173 Esqueleto invisible en una mazmorra · Hecho · anda
59. [x] 11.170 Atajos: animación del player subiendo y bajando en vez del fundido · Hecho · anda
60. [x] 11.174 Overworld (Cumbre): el gancho choca contra una pared invisible · Hecho · anda

### Revisión del 15 de octubre: ruta completa  (63/86 probadas)

1. [x] 11.192 Overworld: mini jefe después de D2 que da el martillo · Hecho · anda — No se entiende cuando el mini jefe va a usar el martillo y se desactiva a poca distancia. Debería mantenerse activado, y si uno le hace daño (con una flecha por ejemplo) se activa la pelea y te empieza a seguir.
2. [ ] 11.191 Martillo: ítem de golpe fuerte · Revisión · **falla** — No falla como tal, solo que las animaciones no pareciera que golpea el martillo contra el piso y con el player no hace el mismo efecto de shockwave que el boss
3. [ ] 11.193 Placa de golpe fuerte (modo STRIKE) · Revisión
4. [x] 11.196 Overworld: enemigo de montaña en la zona de D4 (atoq, zorro andino en manada) · Hecho · anda
5. [x] 11.195 Overworld: entrada de la guarida de los guardias, del otro lado del agua (placeholder) · Hecho · anda
6. [x] 11.184 Risco: la franja del gancho no tiene bajada · Hecho · anda
7. [x] 11.174 Overworld (Cumbre): el gancho choca contra una pared invisible · Hecho · anda
8. [x] 11.131 Pozo junto a la Chullpa: caer sin bombas deja softlock · Hecho · anda
9. [x] 11.171 Mapa del overworld: el cursor vuelve al player al moverlo hacia un lado · Hecho · anda
10. [x] 11.172 Viaje rápido: el foco no va al botón y A abre la pregunta una y otra vez · Hecho · anda
11. [x] 12.2 Terreno del overworld · Revisión · anda — Anda, pero hay meshes que el player no ve. Por lo que no deberían estar. Un ejemplo es en el terreno apilado, tienen piso cuando es innacesible. El diseño y layout del overworld está bien, solo falta eliminar esas partes que no se ven nunca
12. [x] 11.133 Vasija chica cargada no se ve con el x-ray · Hecho · anda — Mejor, pero no tiene que haber x-ray cuando se levanta algo
13. [x] 11.170 Atajos: animación del player subiendo y bajando en vez del fundido · Hecho · anda
14. [x] 11.88 Niveles referenciados por ruta: saves y portales frágiles · Hecho · anda
15. [x] 11.75 AreaZone: id estable para guardar las zonas visitadas · Hecho · anda
16. [x] 11.176 Chullpa: llave chica y sótano obligatorios, llave del jefe con vuelta atrás · Hecho · anda
17. [x] 11.177 Chullpa sin pared agrietada (fuera el nicho del Rellano) · Hecho · anda
18. [x] 11.139 Chullpa: el cofre sobre la plataforma no se alcanza saltando · Hecho · anda — se ve horrendo y no soluciona el mismo problema del lado izquierdo
19. [x] 11.138 Chullpa sub-boss: asset para el cuadrado donde después se salta · Hecho · anda
20. [x] 12.31 Chullpa: jefe final momia con aspecto propio · Hecho · anda
21. [x] 11.5 Galería de trampas: pinchos · Revisión · anda — Anda, pero el cofre detrás de los pinchos es una llave obligatoria para avanzar y se necesita antes de la pluma. Por lo que es imposible abrir el cofre sin hacerse daño.
22. [x] 11.173 Esqueleto invisible en una mazmorra · Hecho · anda
23. [x] 11.141 Queñoa 2P (Canopy): símbolo azul sin sentido y puerta bloqueada invisible · Hecho · anda
24. [ ] 11.144 Queñoa S1 (Raíces): reja fuera de la pared y puerta con llave detrás de una reja de puzzle · Revisión
25. [ ] 11.145 Queñoa S1 (Sala de los ojos): placa que no hace nada, z-fighting en el cofre y símbolo raro en la puerta · Revisión · **falla**
26. [x] 11.160 Ojos de la Queñoa: los párpados siempre se abren y cierran animados · Hecho · anda
27. [x] 12.23 Ojos de la Queñoa y Ojo Vigía: modelo propio parecido al ojo del jefe final, más simple · Hecho · anda
28. [x] 12.21 Ojo interruptor: la pupila sigue al player y se parece al ojo del jefe final · Hecho · anda
29. [x] 11.181 Paredes agrietadas: abren una sala, nunca un nicho (Queñoa y templo) · Hecho · anda
30. [ ] 11.178 Totora: cada sala centrada en cámara y tapando las otras · Revisión
31. [x] 11.149 Al entrar a una sala se puede caer al agua y reaparecer sobre el agua (softlock) · Hecho · anda
32. [x] 11.150 Gancho: el targeting marca un poste de otra sala/piso · Hecho · anda
33. [ ] 11.151 Totora 2P: se ve la sala del piso de abajo · Revisión
34. [ ] 11.153 Totora: cruce con gancho a través de la puerta no se entiende; poner plataforma/poste en la propia sala · Revisión · **falla**
35. [ ] 11.154 Totora: no hay dónde reponer flechas cerca · Revisión
36. [x] 11.167 Totora: caer al agua y perder deja al player cayendo al vacío antes de "You Fell" · Hecho · anda
37. [ ] 12.35 Totora: el hueco de salida de los Tejedores tiene que leerse como caída · Revisión
38. [ ] 12.36 Totora: los charcos de Amaru y Yacumama, de agua · Revisión
39. [ ] 11.179 Cumbre: cada sala centrada en cámara y tapando las otras · Revisión
40. [ ] 11.186 Cumbre: la reja de la llave del jefe tapa la puerta de las Torretas · Revisión
41. [ ] 11.189 D4: backtracking de la llave del jefe · Revisión
42. [x] 12.38 Cóndores de la D4: modelo de arte · Hecho · anda
43. [ ] 11.113 El templo del ojo pasa a ser la última mazmorra · Revisión
44. [x] 11.180 Templo: salas rearmadas (22 × 14) · Hecho · anda
45. [x] 11.182 Templo boss-rush: un jefe anterior por ala · Hecho · anda
46. [x] 11.183 Espada mejorada (premio de la Combinada del templo) · Hecho · anda
47. [x] 11.190 Templo: una pieza de corazón · Hecho · anda
48. [x] 11.161 Jefe final: la puerta norte de la sala queda escondida · Hecho · anda
49. [ ] 11.93 Jefe: aflojar la fase 3 y el modelo que se hunde · Revisión · **falla** — Se siguen hundiendo un poco las manos
50. [x] 11.194 Jefe final: rayo del ojo con las dos manos fuera de juego · Hecho · anda
51. [x] 12.30 Templo: salas que se vean bien para grabar · Hecho · anda
52. [x] 12.33 Templo: la Mano sub-jefe con modelo propio · Hecho · anda
53. [x] 12.34 Templo: paleta más dorada, como el jefe final, menos celeste · Hecho · anda
54. [x] 10.19 Fin de la demo · Hecho · anda
55. [ ] 11.90 Diseño de mazmorras, ítems y su reparto en el overworld · Revisión · **falla** — No falla. Hay que hacer una revision completa de las dungeons. El overworld está bastante bien, pero habria que revisarlo tambien.
56. [x] 12.24 Muros agrietados LA por estilo (muro_agrietado_<estilo>_la) · Hecho · anda
57. [ ] 12.37 Rejas con el estilo de cada mazmorra · Revisión
58. [ ] 12.32 Look LA: topes de pared del color del muro y viñeta borrosa en vez del velo negro; desenfoque solo cerca de la cámara · Revisión
59. [x] 11.157 Mazmorras: los tiles del GridMap no se alinean con la grilla del editor · Hecho · anda
60. [x] 11.158 Piso LA: patrón de tablones raro · Hecho · anda
61. [x] 12.27 VFX mágicos con shaders y partículas (sin texturas) · Hecho · anda
62. [x] 12.25 El ojo del logo en game over, selección de idioma y carga · Hecho · anda
63. [x] 11.152 Z-target: al activarlo, priorizar el enemigo más cercano · Hecho · anda
64. [x] 11.142 Mapa de pausa: LT/RT van rapidísimo; mover con las flechitas · Hecho · anda
65. [x] 11.108 Cargar en la misma escena desincroniza puertas y flags · Hecho · anda
66. [x] 11.162 Retirar el templo viejo (levels/temple.tscn) · Hecho · anda
67. [x] 11.163 Borrar las mallas de la decoración del templo viejo · Hecho · anda
68. [x] 11.59 Limpieza de assets sin uso · Hecho · anda
69. [x] 11.125 Puzzle de bloques de la cota: probar empujando y ubicar región · Hecho · anda — De andar anda, pero el 1 no se entiende que la piedra se puede levantar. Aparte es rarisimo tener que tirarla y apuntarle para que caiga sobre el boton. Este debería ser de presion de los que alcanza con que pisa el player.
   El 2 sería mas reconocible si el icono del plate sea el mismo que tienen los bloques, ademas uno se puede cambiar por el de la vasija y poner una vasija grande reemplazando uno de los bloques. Y la cota reforzada debería estar en otro lado, puede ser una recompensa de mitad de la ultima dungeon
70. [x] 11.80 BossArena tiene los flags y el premio de D1 fijos en el código · Hecho · anda
71. [ ] 11.81 Dungeon.id por defecto d1 y prefijos de flags fijos · Revisión
72. [ ] 11.82 Daño que no pasa por el Hurtbox · Revisión
73. [ ] 11.83 Un solo camino para spawnear proyectiles, bombas y pickups · Revisión
74. [ ] 11.84 Ítems: que la estrategia decida, no la máquina de estados · Revisión
75. [ ] 11.85 Combate y HSM: casos que fallan en silencio · Revisión
76. [ ] 11.86 GameState: escrituras con señal y carga sin emisiones parciales · Revisión
77. [x] 11.87 Valores de ajuste al inspector · Hecho · anda
78. [ ] 10.27 Nodos creados por código pasan a sus .tscn · Revisión
79. [ ] 11.198 Jefe final: más golpes al piso y lo alcanza detrás · Revisión
80. [ ] 11.199 Mazmorras: no hacer zoom a lo que se abre en otra sala · Revisión · **falla** — En el templo sigue pasando.
81. [x] 11.200 Enemigos de sala de mazmorra no sueltan la persecución · Hecho · anda
82. [ ] 11.201 Autosave en la ranura de la partida · Revisión
83. [x] 11.205 Escudo siempre en la mano; la guardia es Z · Hecho · anda
84. [x] 11.204 Jefe final: manos al cambiar de fase, aturdido, golpes y rayo · Hecho · anda
85. [ ] 11.202 Errores del log de la build 0.2 (playtest) · Revisión
86. [x] 11.197 Terreno del overworld: colisión simplificada (la carga congela la ventana 3,4 s) · Hecho · anda

### M16: salud del código  (0/20 probadas)

1. [ ] 16.16 Formato del save con dueño y migraciones por versión · Revisión
2. [ ] 16.7 Cargar partida: la escena vieja recibe el save nuevo antes de irse · Revisión
3. [ ] 16.5 Partida o escenario con botones de ítem mal formados crashea · Revisión
4. [ ] 16.18 Lo que hace un ítem al agarrarlo, por datos y no por id · Revisión
5. [ ] 16.21 GameState: separar el estado de sesión y las piezas sueltas · Revisión
6. [ ] 16.19 Wiring como componente en la escena · Revisión
7. [ ] 16.17 Configs de enemigos clonadas por mazmorra · Revisión
8. [ ] 16.20 Behavior trees: reacciones de muerte, golpe y aturdido copiadas · Revisión
9. [ ] 16.15 Daño por fuera del Hitbox, tres formas de mirar si toca el piso y dos ondas iguales · Revisión
10. [ ] 16.13 Clase base ArenaFighter para los sub-jefes · Revisión
11. [ ] 16.14 Peleas de jefe: música, barra del HUD y premio con un solo camino · Revisión
12. [ ] 16.1 Jefe final: el rayo del ojo pega una sola vez por pelea · Revisión
13. [ ] 16.3 Templo: el grafo pide `mirror_shield`, que no existe · Revisión
14. [ ] 16.8 Pausa con dueños: menús, transiciones y reveal no se despausan entre sí · Revisión
15. [ ] 16.9 Cambios de escena y fundidos que se pisan · Revisión
16. [ ] 16.10 Un golpe corta la transición entre salas o el levantar un ítem · Revisión
17. [ ] 16.6 Corrutinas que esperan un tween matado no vuelven nunca · Revisión
18. [ ] 16.4 Intro del título: no esconde los velos del overworld · Revisión
19. [ ] 16.2 Co-op: un contenedor de corazón revive al Espíritu con la vida llena · Revisión
20. [ ] 16.24 Players.joined sale antes del _ready del player · Revisión
