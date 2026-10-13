# Tareas — Project Epiphany

> Export de `compass/`, que es la fuente de verdad. No editar: los cambios se hacen en `compass/` o con `scompass`, y este archivo se regenera.
> Generado: 2026-10-13

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

## M7 — Overworld  (8/10)

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

### 7.9 Rediseño del overworld como hub de varias mazmorras · En curso

**Prioridad:** alta · **Etiquetas:** `overworld`, `nivel`

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
- [ ] Recorrerlo (Daniel)
- [x] Viaje rápido: mockup de la pantalla
  Artboard 'Pausa · Mapa (overworld nuevo) con portales de viaje' (Pause_Map_Travel) en https://claude.ai/artifact/UuD7d42rAXuYTBcMd9iZJy. Aprobado por Daniel.
- [x] Viaje rápido: portales y viaje desde el Mapa
  travel_portal.tscn ×6 en overworld.tscn (ow_portal_<id>); Mapa: marcas, cursor que se engancha, tarjeta y X Viajar con travel_dialog; interactuar en un portal abre el Mapa. test_travel_portals_light_up_and_the_map_travels. Playtest 2026-10-12 'no puedo teletransportarme': el diálogo arrancaba en Cancelar (A cancelaba); ahora arranca en Viajar como el mockup (ConfirmDialog.confirm_first). El portal del Claro estaba pegado a la tablilla de controles y E podía leerla: se mudó a (−51, 17); el test pide que ningún portal tenga otro interactuable a menos de 3 m.
- [x] Laguna de agua real y Bañado de agua baja
  Daniel (2026-10-11): la Laguna con el agua de la cueva de la vertiente (water.gdshader: espuma en la orilla, color por profundidad) sobre el hueco; cascada en el acantilado norte donde termina la quebrada; caer al agua salpica y vuelve a la orilla (no se nada); la isla de D3 con el gancho. El Bañado, agua baja que se camina.
- [ ] Que todo se pueda alcanzar y cruzar
  Playtest 2026-10-12: áreas imposibles de alcanzar o cruzar. test_every_region_is_reachable_except_the_item_gated (navmesh + link del puente): con el puente se llega a todas las zonas menos la Cumbre y la isla de la Laguna (gancho) y las franjas de la Quebrada (angostura y bajadas, 11.90). Falta que Daniel diga qué lugares puntuales no pudo cruzar.
- [x] Mapa: A viaja, X pone pin
  Daniel (2026-10-12): era contraintuitivo que el viaje fuera con X. Mockups Pause_Map_Travel, Pause_Map_Regions y Pause_Map_Overworld al día; map_page: ui_accept viaja (si hay portal enganchado), item_1 pone o quita pin; barra de ayudas en el orden del mockup.

### 7.10 Overworld con forma de Zelda 2D, no cuadrado · En curso

**Prioridad:** alta · **Etiquetas:** `overworld`, `nivel`

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
- [ ] Tests y escenarios al día
  Al día: test_enemy_ai, test_breakables, test_player_hole, test_title, test_game_over, test_intro (tomas de la intro reubicadas) y test_push_block. Faltan los de posiciones (test_map, test_portal, test_shrine, test_zone_veil, test_heart_pieces, test_overworld, test_overworld_run, test_grove_puzzle, test_temple_seal) y los de puzzles que el layout nuevo todavía no tiene: abismo de 4 m del risco, angostura, escalón de la pradera, ojo del abismo, haz del espejo del templo, piezas de corazón escondidas y postes del gancho. Los secretos de la pluma van antes que los del arco.
- [ ] Recorrerlo (Daniel)

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

## M10 — Terminación  (21/30)

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

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

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

**Bloquea a:** 10.10 Publicar en itch.io y playtest

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

**Bloqueada por:** 10.9 Build para playtesters

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

### 10.19 Fin de la demo · Revisión

**Prioridad:** media · **Etiquetas:** `ui`

Al vencer al jefe el portal es la única salida, y entrar abre un diálogo de fin de demo con opciones (seguir jugando, revancha contra el jefe o volver al menú), apoyado en respuestas nuevas en el `TextBox`. Sin pantalla de créditos.

- [x] Quitar el final al tomar el contenedor
  Hoy Ending.open() salta al tomar el contenedor de corazón (boss_arena.gd _on_reward_taken). Sacarlo de ahí: tomar el contenedor es solo el item get.
- [x] Vencer no reabre la puerta: el portal es la única salida
  Sacar door.open() de _on_death_finished y que _already_won (cargar la partida en la arena) también la deje cerrada. No se vuelve a la sala anterior.
- [x] El portal del jefe dispara el fin de la demo
  Al entrar al BossExitPortal (required_flag d1_boss_defeated) se abre la pantalla de fin en vez de viajar directo. Guardar checkpoint antes, así el progreso del jefe queda.
- [x] Respuestas en el TextBox: diálogos con opciones
  Hoy TextBox ignora line.responses. Al terminar una línea con respuestas, mostrar la lista dentro del globo (nodos en text_box.tscn, no por código), navegable con gamepad/teclado, foco en la primera; elegir sigue con response.next_id. Respuestas con condición ocultas. Sirve para cualquier NPC o cartel con preguntas.
- [x] Diálogo de fin de demo: seguir, revancha o menú
  data/dialogue/ending.dialogue (es/en en translations): "Fin de la demo, gracias por jugar" con respuestas Seguir jugando (cierra y completa el viaje del portal al overworld, ver 11.29), Volver a retar al jefe y Volver al menú principal (guarda y quit_to_title, vía mutation o señal). Reemplaza la pantalla Ending actual.
- [x] Revancha contra el jefe
  Recarga la arena con el jefe vivo aunque d1_boss_defeated esté en true (modo revancha en BossArena, no se borra el flag ni se guarda nada a mitad). Puerta cerrada e intro como siempre; morir reinicia la revancha. Al ganar no reaparece el contenedor (d1_heart_container) y el portal vuelve a abrir el diálogo de fin.
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

### 10.23 Tests en paralelo · Revisión

**Prioridad:** media · **Etiquetas:** `herramientas`

La suite de tests tarda unos 9 minutos en serie. Correrla en varios procesos headless en paralelo, cada uno con su `user://` aislado, para que termine en menos de la mitad del tiempo con los mismos resultados.

- [x] Runner en paralelo
  run_tests.gd reparte los archivos test_*.gd en N procesos headless (por defecto, los núcleos disponibles, máx. 4), balanceados por la duración de la última corrida; junta resultados y sale con 1 si algo falla.
- [x] Aislar user://
  Cada proceso con su carpeta de partidas y de opciones (test_saves_<n>, test_settings_<n>.cfg) para que no se pisen.
- [x] Medir y documentar
  Comparar contra la corrida en serie (~9 min); README/gdd con el comando y cómo correr un solo archivo.

**Prueba:** Correr la suite completa: termina en menos de la mitad del tiempo en serie, con los mismos resultados, y dos corridas seguidas dan lo mismo.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.24 Tope de FPS · Revisión

**Prioridad:** alta · **Etiquetas:** `rendimiento`

Medido 2026-10-11: con monitor de 200 Hz y vsync sin tope el juego dibuja 200 FPS aunque cada cuadro le cueste ~1,2 ms a la GPU (RX 580: 82 W promedio, picos de 120 W, contra 68 W con tope 60). Engine.max_fps 60 por defecto y opción en el menú (30/60/120/sin límite) armada en la escena de opciones.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.25 Sombras del sol acordes a la cámara cenital · Revisión

**Prioridad:** media · **Etiquetas:** `rendimiento`

El Sun de overworld y temple usa el default de Godot (PSSM de 4 cascadas hasta 100 m): la geometría se vuelve a dibujar por cada cascada y el overworld llega a ~900 mil triángulos por cuadro con 418 mil en escena. Probar 2 cascadas (u ortogonal) con distancia máxima acorde a la cámara; comparar capturas antes/después.

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión)

### 10.26 Paredes del GridMap más livianas · Revisión

**Prioridad:** baja · **Etiquetas:** `rendimiento`, `arte`

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
  10.23 verificada (~16 s, estable). 10.8 la reemplazan 10.24–10.26: en Opciones, Tope de FPS (30/60/120/sin tope) cambia al instante y se guarda; las sombras del sol y las paredes se ven igual que antes, sin tirones.
- [x] Cuerpos (11.58)
  Un enemigo muerto queda 4 s, se hunde en el piso con polvo y desaparece; lo que soltó queda; las salas y oleadas siguen abriendo al morir el último.
- [ ] Controles y pestaña Sistema (10.29)
  Opciones → Ver controles: el diagrama del control que estés usando; Y (o T) cambia entre gamepad y teclado. Pausa → Sistema: a la derecha los controles; Guardar pisa la partida cargada (pregunta antes); Cargar te deja elegir el último checkpoint o el guardado; volver al título pregunta. Los botones tienen recuadro.
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
  Pistas Camera:position y Camera:rotation de la animación play (cortes a los 6, 14 y 20 s; ~25 s en total). Que los textos INTRO_1–4 alcancen a leerse.
- [ ] Brillo rojo de la entrada del templo
  Pista TempleGlow:light_energy (pico 16, a pleno sol se nota poco) y posición/alcance del OmniLight TempleGlow.
- [ ] Temblor y polvo
  Pista de métodos: tremor(0.6/0.35/0.5) y dust en TempleDust/ClearingDust; en Cutscene: trauma_decay y max_shake.
- [ ] Qué se ve en los planos
  En el prado y la llegada al templo aparecen esqueletos del overworld, y en el primer plano el borde vacío del mapa a la izquierda: decidir si se reencuadra, se ocultan durante la intro o queda así.
- [ ] Vuelta a la cámara de juego y salteo
  settle_time (1,2 s) y skip_hold (0,8 s) en Cutscene.

**Prueba:** Partida nueva desde el título: la intro se lee cómoda, el templo se ve encenderse, el temblor se siente sin marear y lo que se ve en cada plano es intencional.

**Relacionadas:** 10.20 Intro / cutscene de apertura

## M11 — Pulido: contenido y feel  (52/111)

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

Pinchos de piso a ritmo para la sala 3: avisan asomando, suben de golpe, lastiman a player y enemigos (el escudo no los frena) y bajan; en ola para cruzarlos con timing.

- [x] Piezas pinchos y pinchos_base
  build_templo.py: marco de hierro con nueve agujeros apoyado sobre el piso (no lo reemplaza) y nueve púas con el origen a ras del piso.
- [x] SpikeTrap
  src/world/spike_trap.tscn: period, up_time, offset, warn_time; Hitbox hits_all con elemento spikes; period 0 = siempre arriba.
- [x] Ola en la Galería
  GallerySpikes: columnas x=2 y x=4, z 42–54, offset 0.3 s por fila; la decoración las esquiva.
- [x] Tests y GDD
  tests/test_spike_trap.gd; fila de la sala 3 en el GDD.

**Prueba:** En la Galería, cruzar las dos columnas de pinchos: se ve venir cada fila (asoma y tintinea), siempre queda un paso, pinchan al player y al esqueleto, y el puzzle de la torreta sigue igual.

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

### 11.9 Navmesh sobre el piso · Pendiente

**Prioridad:** baja · **Etiquetas:** `ia`

La navmesh horneada del GridMap queda 0.5 m sobre el piso (y hay islas sueltas arriba de paredes y acantilados, a 3 m). Por eso el `NavigationAgent3D` de los enemigos necesita `path_desired_distance` 1.0 para no trabarse en las esquinas. Bajarla al piso y sacar la compensación.

- [ ] Encontrar de dónde salen los 0.5 m
  El piso del kit gris tiene el techo de la colisión en y = 0, pero los vértices quedan en 0.5 (overworld y templo). Revisar cell_size/cell_height del NavigationMesh contra los del mapa de navegación (Project Settings › navigation), agent_max_climb y la posición del NavigationRegion3D.
- [ ] Sacar las islas arriba de paredes y acantilados
  Hay polígonos a y = 3 sobre Pared y Acantilado. Un enemigo nunca llega ahí, pero ensucian el mapa y algún punto aleatorio o el más cercano puede caer arriba. Opciones: filter_baking_aabb, agent_max_climb o colisión de pared sin techo transitable.
- [ ] Rehornear overworld, templo y niveles de prueba
  Botón Bake de cada NavigationRegion3D (levels/overworld.tscn, temple.tscn, test.tscn, dungeon_test.tscn, test_rooms.tscn).
- [ ] Volver `path_desired_distance` a 0.5 si ya no se traban
  src/entities/enemy.tscn › NavigationAgent3D. Probar persecución alrededor de columnas y esquinas de puerta.
- [ ] Actualizar el GDD
  [[gdd#overworld-layout]] › Blockout (7.2) cuenta la compensación; dejar lo nuevo.

**Prueba:** Con Debug › Visible Navigation, la navmesh se ve pegada al piso y no hay islas arriba de las paredes; los enemigos persiguen alrededor de columnas y por las puertas sin quedarse girando en una esquina; test_enemy_ai pasa.

**Referencias:** `gdd.md#overworld-layout`

**Archivos:** `src/entities/enemy.tscn`, `levels/overworld.tscn`, `levels/temple.tscn`

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

### 11.12 Tamaños de sala variados · Pendiente

**Prioridad:** baja · **Etiquetas:** `mazmorra`

Las 9 salas del templo miden todas 11 × 7 celdas (una pantalla), y eso lo vuelve monótono. Variar el tamaño según lo que pasa en cada una (una sala grande de dos pantallas donde haya combate o puzzle amplio, salas chicas de paso o de recompensa), como propone la guía de diseño de mazmorras en docs/.

- [ ] Elegir qué salas cambian y a qué tamaño
  Candidatas: arena de oleadas o sala de ojos más grandes (dos pantallas, la cámara se desplaza dentro); antesala o nichos más chicos. Mirar docs/the-ultimate-methodology-of-creating-zelda-like-dungeon-leve.md. Decidirlo con Daniel antes de tocar el nivel.
- [ ] Salas que ocupan varias celdas del mapa
  Hoy cada Room tiene un solo `map_cell` y map_data.gd (`room_pitch`, `room_grid_point`) asume el mismo paso para todas. Sumar un tamaño en celdas a Room y que la pestaña Mapa y el minimapa las dibujen enteras.
- [ ] Cámara en salas grandes y chicas
  top_down_camera.gd ya limita el foco a `Room.bounds()` y desplaza si la sala es más grande que la vista; comprobar la transición entre salas de distinto tamaño (`_mask_around` con merge) y que una sala chica quede centrada.
- [ ] Rearmar el templo
  GridMap, Room (CollisionShape3D), puertas en el centro de cada pared, spawns, decoración y velo; rehornear la navmesh. La regla de centros (24 cx, 16 cz) deja de valer: actualizar [[gdd#mazmorra-layout]].
- [ ] Tests de puertas y enemigos
  test_doorways_face_their_wall y test_enemies_do_not_spawn_inside_walls siguen pasando.

**Prueba:** Recorrer el templo: al menos una sala grande donde la cámara se desplaza sin saltos y una chica que se ve centrada; las transiciones entre salas de distinto tamaño son limpias; el mapa y el minimapa muestran cada sala con su tamaño; los tests pasan.

**Referencias:** `gdd.md#mazmorra-layout`, `gdd.md#camara`

**Archivos:** `src/world/room.gd`, `src/ui/menus/map_data.gd`, `src/tools/top_down_camera.gd`, `levels/temple.tscn`

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

### 11.20 Cueva con ojo de agua y cáusticas animadas · Revisión

**Prioridad:** media · **Etiquetas:** `arte`, `overworld`, `items`

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

### 11.24 Más secretos en el overworld · Pendiente

**Prioridad:** baja · **Etiquetas:** `overworld`, `puzzles`

Sumar 4 a 6 secretos chicos al overworld (cuevitas con cofre, pasto que esconde algo, rocas que se empujan, muros agrietados) con recompensas útiles, para que explorar valga la pena.

- [ ] Lista de 4–6 secretos chicos
  Cuevitas con cofre, pasto que esconde algo, roca que se empuja, muro agrietado extra.
- [ ] Armarlos
  Recompensas: flechas, bombas, piezas de corazón.

**Prueba:** Cada secreto se encuentra con las herramientas que el player tiene en ese momento y queda resuelto al cargar.

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

### 11.26 Prueba de combate opcional · Pendiente

**Prioridad:** baja · **Etiquetas:** `combate`

Una sala de combate opcional: 3 oleadas mezclando enemigos con la puerta cerrada hasta terminar y una recompensa al final (cota reforzada, carcaj o pieza de corazón).

- [ ] Sala de oleadas
  3 oleadas mezclando enemigos; la puerta se cierra hasta terminar.
- [ ] Recompensa
  Cota reforzada, carcaj o pieza de corazón.

**Prueba:** Entrar, sobrevivir las 3 oleadas, la puerta abre y aparece la recompensa; no se repite al cargar.

### 11.27 Mini-santuario de reflejos · Pendiente

**Prioridad:** baja · **Etiquetas:** `mazmorra`, `puzzles`

Un mini-santuario de 3–4 salas que se resuelven solo con el escudo espejo, cada una enseñando una variante del reflejo, con recompensa al final.

- [ ] Diseñar 3–4 salas
  Todo con el escudo espejo: haces de luz, ojos-interruptor, espejos que giran.
- [ ] Recompensa al final

**Prueba:** Se completa solo con el escudo espejo; cada sala enseña una variante del reflejo.

### 11.28 Atajos que se abren al volver · Pendiente

**Prioridad:** baja · **Etiquetas:** `overworld`

Uno o dos atajos que se abren desde adentro (puente o escalera) y quedan abiertos, para acortar el camino de vuelta al templo.

- [ ] Uno o dos atajos de vuelta
  Puente o escalera que se despliega desde el lado de adentro; flag persistente.

**Prueba:** Abrir el atajo desde adentro: queda abierto y acorta el recorrido al templo.

### 11.29 Overworld después del jefe · Pendiente

**Prioridad:** baja · **Etiquetas:** `overworld`, `audio`

Después de vencer al jefe, el overworld tiene que verse y sonar distinto (sin doom: luz, niebla y música calmas) y ofrecer algo nuevo que solo aparece entonces.

- [ ] Sin doom
  Luz, niebla y música calmas tras d1_boss_defeated.
- [ ] Algo nuevo accesible
  Una zona o secreto que solo aparece después.

**Prueba:** Vencer al jefe y salir: el overworld se ve y suena distinto, y hay algo nuevo para encontrar.

**Relacionadas:** 10.19 Fin de la demo

### 11.30 Ítem post-MVP: gancho o telequinesis · Pendiente

**Prioridad:** baja · **Etiquetas:** `items`

Un ítem post-MVP: gancho o algo que mueva objetos a distancia (GDD §6.1), con uso en combate y que abra lugares que antes no se podían.

- [x] Elegir el ítem
  Gancho. Decidido el 2026-10-11 para D2; el 2026-10-12 (11.90) pasa a ser el ítem de D3 (Laguna), y la pluma va a D2. Se engancha a postes y cofres y lleva al player; a enemigos livianos los trae; cruza abismos de 4 m; también quita la armadura del esqueleto acorazado (la bomba sigue sirviendo).
- [ ] Comportamiento y puzzles
  ItemBehavior nuevo + 2–3 usos en el mundo.

**Prueba:** El ítem tiene un uso en combate y abre al menos dos lugares que antes no se podían.

**Referencias:** `gdd.md#items-mvp`

**Relacionadas:** 11.60 Mazmorra nueva de varios pisos

### 11.31 Sub-jefe del templo · Pendiente

**Prioridad:** baja · **Etiquetas:** `jefe`, `enemigos`

Un sub-jefe a mitad del templo: un chullpa guardián gigante con patrón propio que custodia el arco; al vencerlo aparece el cofre.

- [ ] Chullpa guardián gigante
  Custodia el arco a mitad del templo; patrón propio, una sola fase.
- [ ] Sala y recompensa
  Al vencerlo aparece el cofre del arco.

**Prueba:** Llegar al sub-jefe, vencerlo con espada y escudo, y obtener el arco; al cargar no reaparece.

### 11.32 Modo difícil o contrarreloj · Pendiente

**Prioridad:** baja · **Etiquetas:** `rejugabilidad`

Un modo extra que se desbloquea al terminar el juego, difícil (más daño, menos drops) o contrarreloj, para darle rejugabilidad.

- [ ] Elegir uno
  Difícil: más daño y menos drops. Contrarreloj: tiempo total al final.
- [ ] Desbloquear al terminar

**Prueba:** Tras los créditos aparece la opción; una partida en ese modo cambia lo prometido.

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

**Bloquea a:** 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker)

**Relacionadas:** 10.28 Playtest de revisión (lo que está en Revisión); 11.49 VFX de combate

### 11.34 Combos y técnicas especiales (Minish Cap / Wind Waker) · Pendiente

**Prioridad:** media · **Etiquetas:** `combate`

Técnicas de espada al estilo Minish Cap y Wind Waker: combo de 3 golpes, giro cargado, contraataque y 1–2 técnicas extra que se aprenden en el mundo, sin chocar con fijar, bloquear y rodar.

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

### 11.46 Jefe: game juice · Revisión

**Prioridad:** alta · **Etiquetas:** `jefe`, `feel`

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

### 11.50 Audio del jefe · Pendiente

**Prioridad:** baja · **Etiquetas:** `jefe`, `audio`

Audio propio para el jefe: voz mecánica, chirridos, carga del orbe y golpes con grave, y un tema de música con capas por fase en lugar del placeholder.

- [ ] Voz propia
  Zumbido mecánico de fondo, chirrido de párpados, carga del orbe, rugido de fase, golpes con más grave.
- [ ] Tema de música
  Reemplazar el placeholder (Music.boss_fight) por un tema propio, con capas por fase.

**Prueba:** La pelea tiene sonido propio y la música cambia con las fases.

**Notas:** Skills: `disciplines:audio-design`, `godot:godot-audio`.

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

### 11.59 Limpieza de assets sin uso · Pendiente

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `arte`

Assets propios y packs de terceros que ninguna escena, script ni builder referencia (barrido del 2026-10-11). Revisar a mano: abrir el juego y las escenas de prueba tras mover cada grupo fuera del proyecto, por si algo se carga con una ruta armada en runtime (falso positivo).

- [ ] Mallas viejas del templo
  assets/epiphany/meshes/templo/: jefe_mano, jefe_ojo, jefe_parpado (el jefe usa meshes/jefe/*) y tablilla (la tablilla usa objetos/estela). Si se borran, sacarlas también de build_templo.py, que las sigue generando.
- [ ] Mallas sueltas de objetos, equipo y lugares
  equipo/poncho; lugares/escombro_b, lugares/pedestal, lugares/santuario_pared, lugares/santuario_piso. Sacarlas también de su build_<kit>.py. objetos/corazon, bombas_x3 y orbe NO: son los modelos de 12.5 (pickups y orbe) que todavía no se conectaron.
- [ ] Textura vieja del Knight
  assets/epiphany/textures/knight_texture.png
- [ ] Packs KayKit sin uso (≈42M)
  kaykit_adventure (24M), kaykit_dungeon_remastered (14M), kaykit_skeletons (1.8M), kaykit_medieval (1.6M), kaykit_dungeon (1M): nada los referencia. Ojo: gdd.md §10 todavía los nombra (templo y personajes KayKit), corregir esos párrafos si se van.
- [ ] kenney_development-essentials (1.3M)
  Nada lo referencia.
- [ ] Decidir los packs que son fuente
  kaykit_charanim (56M): solo es la fuente de player/animation/libs/*.res (ya extraídas). kenney_fantasy-ui-borders (1.6M): original de assets/ui/frames/ (tools/build_ui_frames.sh). Sacarlos del repo o dejarlos para poder regenerar.
- [ ] Recortar packs que se usan en parte
  kenney_skyboxes: solo skybox-morning.png (5M el pack). Prototype Textures: solo 8 de 107 (kit gris, data/kits/materials/*.tres). kenney_input-prompts (23M) se usa por rutas armadas en src/ui/input_prompts.gd: no recortar sin revisar qué nombres pide.
- [ ] Probar que nada se rompa
  Abrir el editor (sin dependencias rotas), correr los tests y recorrer overworld, templo y escenas de prueba.

### 11.60 Mazmorra nueva de varios pisos · En curso

**Prioridad:** media · **Etiquetas:** `mazmorra`, `ui`

Segunda mazmorra con pisos (y quizás sótanos) apilados en la misma escena, en vez de rehacer el templo. Decidido el 2026-10-11: mazmorra nueva; el co-op está en pausa, así que no condiciona el diseño. Cantidad de pisos por definir (Daniel revisa los documentos de diseño).

- [x] Diseño: cantidad de pisos, sótanos, recorrido e ítem
  Decidido el 2026-10-11 con el usuario: 3 pisos (sótano, planta baja, alto) de 2 × 2 salas apiladas; temática chullpa (torre funeraria); ítem gancho (11.30); recorrido sala por sala en GDD §8b (gdd#mazmorra-2). Caer por un hueco lleva a la sala de abajo; el cofre del gancho se alcanza tirándose desde 2SE (Torre de Hera).
- [x] Pisos en la escena
  Hecho: DungeonFloor (level, nombre) con su GridMap y sus salas, a 8 m; la cámara oculta los pisos de arriba de la sala actual. Blockout en levels/chullpa.tscn (GDD §8b).
- [x] Escaleras y caídas entre pisos
  Hecho: Stairs (sube/baja, fundido corto, todos los players al marcador de llegada); un hueco con sala abajo cae a esa sala (sin daño, la entrada se anota al aterrizar); donde no hay, Pit. Piso agrietado (cracked_floor.tscn) que se rompe con bomba.
- [x] Salas, guardado y mapa por piso
  Hecho: Room cuenta solo en la altura de su piso; visitadas, mapa y brújula de la mazmorra; mapa de pausa y minimapa muestran el piso de la sala actual y sus puertas. Tests en test_chullpa.
- [x] UI: selector de pisos
  Hecho (mockup aprobado el 2026-10-11): columna de pisos en la pestaña Mapa (MapFloorButton: código, nombre, estás acá, cofres y jefe con brújula), LT/RT o RePág/AvPág (acciones map_floor_up/down) o clic; el cursor mantiene la celda; etiqueta del piso sobre el minimapa. Tests en test_map.
- [ ] Entrada desde el overworld
  Decidido por Daniel el 2026-10-13 (vía la sesión del overworld): la Chullpa (D1) va en los Cerros del oeste, cerca de la Cueva de las bombas, accesible desde el inicio con espada y bombas. La Arboleda pasa a ser una meseta a la que solo se entra con un salto de pluma (la Queñoa, D2, pide la pluma); la Necrópolis queda sin mazmorra. -eb lo arma en 7.10 y pone un Spawn 'chullpa' frente a la torre (el portal de salida ya apunta ahí).
- [ ] Recorrerla (Daniel)
  Con el escenario chullpa: escaleras, caer de 1SE a la cripta y la llave en B-SO, atajo del osario cayendo desde 2NO, bomba en 2SE sobre la isla (pluma), y con la pluma el abismo, el foso de la llave del jefe, la brújula y la pieza del Mirador.
- [x] Rehacer con la pluma como ítem
  Hecho el 2026-10-12: el cofre grande de la isla da la pluma (FeatherChest, flag d2_feather_chest). Las franjas dobles de huecos (abismo de 1NE, foso de la llave del jefe, pieza del Mirador) son ahora una fila de una baldosa: se cruzan con la pluma. La llave chica pasó a B-SO (se llega cayendo desde 1SE, sin ítems) y la brújula a 2NO (pluma). data/dungeons/d2_graph.tres pasa el test de alcanzabilidad; test_chullpa salta las cuatro filas. GDD §8b.
- [ ] Jefe del Guardián que se vence saltando
  Sala B-NE, hoy vacía. En chullpa_graph.tres el objetivo ch_boss_defeated pide la pluma.
- [ ] Más enemigos y un acertijo por piso
- [x] Sub-jefe que guarda la pluma, sin ítems
  Hecho el 2026-10-13 (Daniel aprobó la propuesta). Momia Guardiana (MummyGuard, src/entities/mummy_guard/; modelo provisorio de primitivas para arte) en 2SE: se acerca a saltitos, salta alto con la sombra siguiendo al player, cae con golpe y una onda corta que se esquiva alejándose, y queda trabada para la espada, bombas o vasijas. EyeFight pasa a ArenaFight (src/world/arena_fight.gd) y sirve para cualquier peleador. Vencida, su caída rompe el piso agrietado (CrackedWall con switches: las bombas ya no lo rompen) y se cae sobre la isla de la pluma, que es la sala contigua. Acertijo previo en 2SO sin arco: la puerta a 2SE la abren una placa de peso (vasija grande de 2NO) y una placa en un nicho detrás de un muro agrietado (bomba). La llave chica de B-SO abre ahora 2NO. Grafo con guard ch_mummy_defeated (pasa las reglas del molde); test_chullpa juega el acertijo y la pelea. GDD §8b. Falta recorrerla (paso 7) y el jefe saltando (paso 9), que sería la versión grande de la momia.

**Relacionadas:** 11.30 Ítem post-MVP: gancho o telequinesis

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

### 11.66 Pausa, reveal, portal y muerte se pisan get_tree().paused · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `ui`

El reveal de cámara y `travel_to` ponen `paused` a mano, y `MenuStack._can_pause` solo mira `Players.any_alive()`: se puede abrir la pausa durante un reveal o un fade de portal, y al cerrarla se despausa a mitad del reveal (o el reveal termina y despausa con el menú abierto). El timer de muerte (`create_timer(delay)`) corre en pausa y el GameOver aparece encima del menú de pausa.

- [ ] No pausar si el árbol ya está pausado
  menu_stack.gd `_can_pause`: `not get_tree().paused and Players.any_alive()`.
- [ ] Timer de muerte respeta la pausa
  player/states/dead.gd ~l.13: `create_timer(delay, false)`.

**Prueba:** Abrir la pausa durante un reveal o al cruzar un portal no hace nada; morir y pausar enseguida no muestra el GameOver hasta despausar.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/ui/menus/menu_stack.gd`, `player/states/dead.gd`

### 11.67 El anillo de ítems se abre durante una cutscene · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `ui`, `input`

`item_ring` es PROCESS_MODE_ALWAYS y `_can_open` no mira si otro sistema ya capturó los controles; `_close` siempre pone `captured = false`. Mantener LB en una cutscene abre un anillo invisible con `time_scale = 0.05` (la cutscene va al 5%) y al soltar el player puede moverse en mitad de la cutscene.

- [ ] Respetar la captura ajena
  item_ring.gd `_can_open`: `(visible or not player.controls.captured)`; en `_open` guardar el `captured` previo y restaurarlo en `_close`.

**Prueba:** Durante una cutscene, LB no hace nada; si el anillo estaba abierto al empezar, al cerrarlo el player sigue capturado.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/ui/hud/item_ring.gd`

### 11.68 Barra del jefe en fase 3 y animaciones que siguen tras morir · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `jefe`

`bar_fraction` usa `phase() == 2`, así que en fase 3 la barra vuelve a la vida de las manos. Además las manos al colapsar solo matan `_motion` y siguen corriendo los tweens de ataque (hold, shake, windup, bounce), y un aturdimiento durante la carga del orbe es pisado por el tween `grow`.

- [ ] Barra en fase 3
  boss.gd ~l.148: `phase() >= 2`.
- [ ] Un tween de ataque por mano
  boss_hand.gd: guardar los tweens de ataque en `_attack_tween` y matarlo en `collapse()` y al salir de BUSY.
- [ ] Cortar la carga al aturdir
  boss.gd: guardar `grow` en un miembro y `kill()` en `_stun_eye` y `_on_defeated`.

**Prueba:** En fase 3 la barra baja con los golpes al ojo; el jefe muerto durante un ataque cae quieto; aturdido durante la carga, el ojo no sigue pulsando.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`

### 11.69 Cambios de física dentro de callbacks · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `combate`

Se agregan, reparentan o liberan cuerpos dentro de señales de física (durante el flush), lo que Jolt puede rechazar o aplicar un paso tarde: `enemy._break_armor` (RigidBody nuevo al romper la armadura desde `Hurtbox.hit`), `carrier.drop()` al recibir un golpe cargando algo (reparent de un RigidBody vía `_on_hit` → dispatch hurt), y `thrown_object` → `shatter()` en `body_entered`.

- [ ] Diferir la armadura
  enemy.gd `_break_armor.call_deferred()`.
- [ ] Diferir el golpe del player
  player.gd `_on_hit`: `movement_state.dispatch.call_deferred("hurt")` (o diferir el reparent en `Carrier._release`).
- [ ] Diferir el estallido
  thrown_object.gd: `liftable.shatter.call_deferred()`.

**Prueba:** Romper armadura con una bomba, recibir un golpe cargando una vasija y estrellar una vasija: sin errores ni avisos de física en la salida.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/entities/enemy.gd`, `player/player.gd`, `player/components/carrier.gd`, `src/world/thrown_object.gd`

### 11.70 Sala que se cierra después de que los players se fueron · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `mazmorra`

`room._lock_after_entering` espera 0.6 s y cierra las rejas sin comprobar que la cámara sigue en esa sala; wave_spawner hace lo mismo. Si los players salen enseguida (escalera, pozo, paso atrás) quedan rejas cerradas en una sala vacía, y tras un `reload_current_scene` las corrutinas siguen sobre instancias liberadas. Los 0.6 s dependen sin decirlo del `transition_time` (0.5) de la cámara.

- [ ] Revalidar después del await
  room.gd ~l.91 y wave_spawner.gd ~l.62/76: `is_inside_tree()` y que la sala de la cámara siga siendo esta.

**Prueba:** Entrar a una sala de oleadas y salir en menos de medio segundo: no se cierra; tras morir y reaparecer no hay errores en la salida.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/world/room.gd`, `src/world/wave_spawner.gd`

### 11.71 Minimapa y mapa: cachear las consultas a la escena · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `rendimiento`, `ui`

El minimapa recorre la escena entera cada frame: en mazmorra `room_pitch` es O(salas²) por puerta, y `MapData.doors()` escanea todas las celdas del GridMap cada 0.5 s (tirón periódico); en overworld hace `find_children` de Portal, Tablet y AreaZone. El cursor del mapa reconstruye el panel de info (`_focus_zone`, con más `find_children` y `load`) cada frame mientras se mueve el stick.

- [ ] Cachear en el minimapa
  minimap.gd `_bind()`: paso entre salas, puertas del kit, portales, tablillas y zonas; por frame solo `Door.is_open`.
- [ ] Panel del mapa solo al cambiar de zona
  map_page.gd `_focus_zone`: salir si la zona es la misma; cachear zonas, tablillas y fragmentos en `_show_overworld`.

**Prueba:** Profiler: el minimapa no aparece entre los costos por frame; mover el cursor del mapa no genera nodos nuevos si la zona no cambió.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/ui/hud/minimap.gd`, `src/ui/menus/map_data.gd`, `src/ui/menus/map_page.gd`

### 11.72 Búsquedas de nodos y trabajo por frame innecesario · Pendiente

**Prioridad:** baja · **Tamaño:** M · **Etiquetas:** `rendimiento`

Varias búsquedas por frame o trabajo en nodos ociosos, baratos uno por uno pero que suman.

- [ ] Jefe
  boss.gd: `%Charge`, `$Body/Eye/Mesh`, `%UpperLid`/`%LowerLid` en `@onready`; `phase()` sin Dictionary nuevo. boss_hand.gd: índices de blend shapes resueltos en `_ready`.
- [ ] DoomAmbience
  Cachear la cámara, salir si `level` ya llegó al objetivo; WorldEnvironment y sol por `@export`.
- [ ] Room y FloorSwitch
  room.gd: `set_process(Engine.is_editor_hint())` y material del contorno cacheado; floor_switch.gd: apagar el physics_process de un ONCE resuelto.
- [ ] Arquero
  bt_shoot_arrow.gd: el arco se busca una vez en `_setup()`, tipado.
- [ ] Música
  music.gd: escuchar `MenuStack.changed` en vez de buscarlo cada frame.
- [ ] Cámara
  top_down_camera.gd: `framed()` una vez por tick; exclude de rayos cacheado en joined/left; `DebugOverlay.watch` solo en debug.
- [ ] Unirse a la partida
  players.gd: `preload` de la escena del player.

**Prueba:** Profiler en templo y overworld sin get_node/find_child por frame en estos scripts.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`, `src/world/doom_ambience.gd`, `src/world/room.gd`, `src/world/floor_switch.gd`, `ai/tasks/bt_shoot_arrow.gd`, `src/audio/music.gd`, `src/tools/top_down_camera.gd`, `src/state/players.gd`

### 11.73 Opciones: no guardar a disco en cada tick del slider · Pendiente

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `rendimiento`, `ui`

Cada `value_changed` llama a `Settings.set_value`, que reaplica todo (buses, modo de ventana, escala, idioma) y escribe settings.cfg: arrastrar un slider de volumen escribe decenas de veces por segundo.

- [ ] Aplicar solo la clave cambiada
  settings.gd: `_apply` por clave.
- [ ] Guardar al soltar o al salir
  options_panel.gd: guardar en `drag_ended` o al cerrar la pantalla.

**Prueba:** Arrastrar un slider escribe settings.cfg una sola vez.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/settings/settings.gd`, `src/ui/menus/options_panel.gd`

### 11.74 Guardado: validar tipos, versionado y slots · Pendiente

**Prioridad:** baja · **Tamaño:** M · **Etiquetas:** `guardado`

Los datos cargados no se validan por tipo: una clave con tipo inesperado (por un cambio propio del esquema) tira error en las asignaciones tipadas de `GameState.read_from` y en `SaveCodec.validate`. `_migrate` corre después de validar, no hace nada y no rechaza versiones más nuevas. La migración de slots 0-2→1-3 corre en cada arranque protegida solo por `.slots_v2` (si se pierde, corre los slots y pisa el 3; y abre el marcador sin mirar null). Un slot con solo `.bak` aparece vacío.

- [ ] Helper tipado
  `_typed(cfg, sec, key, default)` que vuelve al default si `typeof` no coincide; usarlo en `read_from` y `validate`.
- [ ] Migrar antes de validar
  save_manager: `_migrate` primero; rechazar `version > VERSION`.
- [ ] Quitar la migración de slots
  Era de antes de publicar; no hay build pública.
- [ ] has_save mira el .bak
  save_manager ~l.120.

**Prueba:** Una partida con un campo de tipo erróneo carga con el valor por defecto; una de versión futura se rechaza con mensaje; sin la migración de slots los tests pasan.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/save/save_manager.gd`, `src/save/save_codec.gd`, `src/state/game_state.gd`

### 11.75 AreaZone: id estable para guardar las zonas visitadas · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `guardado`, `overworld`

`GameState.visit_zone(name)` usa el nombre del nodo como clave: renombrar una zona (como en el overworld nuevo) borra su estado de visitada de las partidas y el ZoneVeil vuelve a tapar zonas ya visitadas.

- [ ] Exportar un id
  area_zone.gd: `@export var id: StringName`, usado como clave (fallback al nombre si está vacío).
- [ ] Rellenar los ids en el overworld
  Con los nombres actuales, para no perder las partidas existentes.

**Prueba:** Renombrar el nodo de una zona no cambia si figura como visitada.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `src/world/area_zone.gd`, `src/world/zone_veil.gd`, `levels/overworld.tscn`

### 11.76 Constantes en vez de strings sueltos · Pendiente

**Prioridad:** baja · **Tamaño:** M · **Etiquetas:** `arquitectura`

Claves del blackboard (`"target"`, `"is_blocking"`, `"is_hit"`, `"stunned"`, …) en ~20 lugares, `ITEM_ACTIONS` / `[&"item_1", &"item_2"]` copiado en 8 archivos, grupos y métodos de `call_group` como literales, ids de ataque del jefe que tienen que coincidir con los .tres. Un typo devuelve el default o no hace nada, sin error.

- [ ] Blackboard y acciones de ítem
  Constantes StringName en PlayerState (generic.gd) y en Enemy; una sola lista de acciones de ítem.
- [ ] Grupos
  Constante `GROUP` en la clase dueña de cada grupo (hud, room_camera, enemies, doors, wave_spawners, chests), como ya tienen Room y SpawnPoint; `spawn_point` con `is PlayerCharacter`, `room.gd` con el spawner tipado.
- [ ] Ataques del jefe
  Ids en constantes compartidas con los .tres.
- [ ] Etiquetas de botón
  items_page.gd `BUTTON_NAMES` X/Y → icono de InputPrompts (en teclado no es X/Y).

**Prueba:** Buscar los literales: cada clave/acción/grupo aparece definida una sola vez.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

### 11.77 Player: escudo como componente y PlayerControls sin nodo · Pendiente

**Prioridad:** baja · **Tamaño:** M · **Etiquetas:** `arquitectura`, `combate`

player.gd tiene ~470 líneas y ~200 son del escudo (bloqueo, reflejo, escudo trasero, luz espejo, empuje). `PlayerControls.new()` + `add_child` rompe la regla de nodos en el .tscn y no usa nada de Node.

- [ ] Componente Shield en player.tscn
  Como Aim y Carrier.
- [ ] PlayerControls extiende RefCounted
  Quitar el add_child; input_buffer.gd lee `controls` tipado.

**Prueba:** El player se comporta igual (tests de escudo y controles verdes) y player.gd baja de ~300 líneas.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

**Archivos:** `player/player.gd`, `player/player.tscn`, `player/components/controls.gd`, `player/components/input_buffer.gd`

### 11.78 Limpieza menor de la revisión de código · Pendiente

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `arquitectura`, `ui`

Detalles sueltos de la revisión, sin bug visible o con efecto de un frame.

- [ ] Liberar con remove_child
  items_page.gd ~l.183/201 y equipment_page.gd ~l.118: `remove_child` antes de `queue_free` (hoy duplican un frame).
- [ ] Pantallas con contrato UiScreen
  TextBox, ItemGet y LanguageSelect extienden UiScreen; MenuStack tipado como `Array[UiScreen]`.
- [ ] Feel sin tocar MenuStack._stack
  `MenuStack.depth()`.
- [ ] Tipos estáticos
  text_box.gd `body`, pause_menu.gd `extra`/`accept`, minimap.gd `_doors`, bt_* `bow`.
- [ ] Código sin uso
  ItemModifier sin subclases; estado Spawning que dura un frame (arreglar o quitar).
- [ ] Arena del jefe
  boss.gd no depende del orden de nodos en temple.tscn para el rect de la arena.
- [ ] Varios
  spring.gd usa `by.health`; ToonToggle limpia `_saved` de nodos liberados.
- [ ] Accesos por ruta a nodos del player
  player_panel.gd `get_node(^"InteractionDetector")`, boss `get_node(^"Hurtbox")` (ya existe `player.hurtbox`), input_buffer `get_parent().get(&"controls")`, equipment.gd `owner.…` → propiedades tipadas en PlayerCharacter o `@export var player`.

**Prueba:** Tests verdes; sin cambios visibles salvo el parpadeo de chips/corazones.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

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

### 11.80 BossArena tiene los flags y el premio de D1 fijos en el código · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `jefe`, `mazmorra`

`boss_arena.gd` tiene `DEFEATED_FLAG := &"d1_boss_defeated"`, `CONTAINER_FLAG := &"d1_heart_container"`, el contenedor y `ending.dialogue` como const. Reusar la arena en D2 marcaría derrotado al jefe de D1 y pondría su final.

- [ ] Exports
  `defeated_flag`, `container_flag`, `reward: ItemData`, `ending: DialogueResource`; setearlos en temple.tscn.
- [ ] Avisos en el editor
  `_get_configuration_warnings` con `PersistentFlag.warnings_for`.
- [ ] Premio por DropTable
  `_spawn_reward` usa `DropTable.drop_at`/el helper de pickups en vez de su copia.

**Prueba:** Una BossArena con los exports vacíos muestra aviso en el editor; temple sigue igual; una arena de D2 usa sus propios flags.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/entities/boss/boss_arena.gd`, `levels/temple.tscn`

### 11.81 Dungeon.id por defecto d1 y prefijos de flags fijos · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `mazmorra`, `guardado`

`Dungeon.id` vale `&"d1"` por defecto y temple.tscn depende de eso (no tiene `id =`). Una mazmorra nueva que olvide el id comparte llaves, mapa y brújula con D1 sin aviso. `PersistentFlag.PREFIXES` es una lista fija `ow_, d0_..d3_` y SaveCodec deriva la sección del prefijo: D4 requiere tocar código.

- [ ] Id vacío por defecto + aviso
  dungeon.gd: `&""` y config warning; poner `id = &"d1"` en temple.tscn.
- [ ] Prefijos por regex
  `^(ow|d\\d+)_` en PersistentFlag y SaveCodec.
- [ ] Opcional: avisar prefijo distinto
  Un flag `dN_` en una escena cuyo Dungeon.id no es dN.

**Prueba:** Un Dungeon sin id muestra aviso; temple tiene `id = &"d1"` explícito; un flag `d4_x` valida sin tocar código.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/world/dungeon.gd`, `levels/temple.tscn`, `src/save/save_codec.gd`

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

**Relacionadas:** 13.7 Enemigos y jefe con varios objetivos

### 11.83 Un solo camino para spawnear proyectiles, bombas y pickups · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `arquitectura`

Instanciar → `current_scene.add_child` → `launch` está copiado en projectile_behavior, turret, boss y bt_shoot_arrow; bombas y la grieta del slam van a `current_scene`, pickups a `get_parent()` o a `self`. Hay tres raíces de spawn distintas, y M14 necesita una para el MultiplayerSpawner. Además WaveSpawner hace `as Enemy` y `.position`: una torreta en una oleada crashea.

- [ ] Arreglar el cast de WaveSpawner
  Aceptar cualquier Node3D o tipar por una clase común; darle `signal defeated` a Turret.
- [ ] Helper de disparo
  `Projectile.fire(scene, from, velocity, info)` junto a `launch`.
- [ ] Nodo raíz de spawn en los niveles
  Un nodo en el .tscn (grupo o export) que usan el helper, `DropTable.drop_at` y PlaceBehavior.

**Prueba:** Una torreta dentro de un WaveSpawn funciona; todos los objetos de runtime cuelgan del mismo nodo raíz de spawn.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/world/wave_spawner.gd`, `src/entities/turret/turret.gd`, `src/items/behaviors/projectile_behavior.gd`, `src/items/behaviors/place_behavior.gd`, `ai/tasks/bt_shoot_arrow.gd`, `src/entities/boss/boss.gd`

### 11.84 Ítems: que la estrategia decida, no la máquina de estados · Pendiente

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `items`, `arquitectura`

La lógica de ítems se escapa del ItemBehavior al FSM del player: `_try_item` pregunta `is JumpBehavior` y `hold_to_aim`; using_item duck-typea `hold_time` y `leaves` (este último redundante: ConsumableBehavior ya llama a `swap_item`); aiming_throw castea a PlaceBehavior; AimingItem es solo-arco (animaciones, BowPhase, yaw). Un segundo ítem de apuntar (gancho, bumerán) usaría las animaciones del arco. Los estados leen `GameState.inventory` en vez de `ctx.inventory`; `ItemUseContext.equipped` no se usa.

- [ ] entry_event() en ItemBehavior
  Por defecto `&"use_item"`; Jump → `&"jump"`; hold_to_aim → `&"aim_item"`. Borrar JumpBehavior como etiqueta de tipo si queda vacía.
- [ ] hold_time en la base
  0 = sin mantener; quitar el bloque `leaves`.
- [ ] AimingItem genérico
  Animaciones y yaw desde exports del behavior.
- [ ] ctx.inventory
  Los estados usan el contexto; quitar `equipped`.

**Prueba:** Agregar un ítem nuevo de apuntar es un .tres + su behavior, sin tocar state_machine.gd.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `player/state_machine.gd`, `player/states/using_item.gd`, `player/states/aiming_item.gd`, `player/states/aiming_throw.gd`, `src/items/behaviors/item_behavior.gd`

### 11.85 Combate y HSM: casos que fallan en silencio · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `combate`, `jefe`

Tres puntos que no dan error cuando algo no cuadra: (1) el ataque melee elige la animación con un bool (Slash/ShieldThrust) e ignora `AttackData.animation`, que solo se usa para la duración: un arma nueva desincroniza hitbox y animación; el combo de MeleeBehavior tiene una sola entrada y siempre se usa `get_attack(0)`. (2) Los ataques del jefe se despachan por id en `match` sin default: un .tres con id nuevo o mal escrito no hace nada (mano) o dispara un orbe (ojo). (3) Los estados interrumpibles por `transition` y `grabbed` están en dos listas a mano en state_machine.gd: un estado nuevo que falte se queda atrás en el cambio de sala.

- [ ] Animación desde AttackData
  `@export var tree_state` en AttackData; MeleeBehavior con un solo `attack` o avanzar el combo de verdad.
- [ ] Ids de ataque del jefe
  Enum en BossAttack o rama `_:` con push_error; caso explícito `&"orb"`.
- [ ] Interrupciones con anystate
  `add_transition(anystate(), …, guard)` con un guard común, o `@export var interruptible` en PlayerState.

**Prueba:** Un BossAttack con id desconocido da push_error; un estado nuevo del player sigue la transición de sala sin tocar listas.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `player/states/attacking.gd`, `src/items/behaviors/melee_behavior.gd`, `src/combat/attack_data.gd`, `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`, `player/state_machine.gd`

### 11.86 GameState: escrituras con señal y carga sin emisiones parciales · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `arquitectura`, `guardado`

Hay campos de GameState que se escriben a pelo desde afuera (`room_entry` desde la cámara y boss_arena, `boss_rematch`, `spawn_point`, `map_revealed` desde el minimapa), sin señal ni setter. El progreso del overworld lo pinta el minimapa del HUD: sin HUD no se registra lo explorado. `set_flag` emite aunque el valor no cambie. Cargar emite `dungeon_changed` dos veces y `inventory.changed` por ítem antes de `loaded` (el HUD crea un DungeonState fantasma; el mapa se reconstruye 2-3 veces).

- [ ] Setters para los campos sueltos
  `set_room_entry`, `set_spawn_point`, etc.
- [ ] Revelar el mapa desde el mundo
  `GameState.reveal_at(xz)` dueño de la Image, llamado desde un nodo del overworld; el minimapa solo lee.
- [ ] set_flag sin cambio no emite
  Salir si ya tiene ese valor.
- [ ] Carga en bloque
  Guard `_bulk` en `read_from`/`_clear` que suprime las señales finas; solo `loaded`.

**Prueba:** Sin HUD, caminar el overworld revela el mapa; cargar una partida emite `loaded` y nada intermedio.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/state/game_state.gd`, `src/ui/hud/minimap.gd`, `src/tools/top_down_camera.gd`, `src/entities/boss/boss_arena.gd`, `src/world/spawn_point.gd`, `src/items/inventory.gd`

### 11.87 Valores de ajuste al inspector · Pendiente

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `feel`, `combate`

Varios valores de juego están como const o en sitios compartidos y no se pueden tunear a ojo en el editor.

- [ ] Jefe
  boss.gd: 24 const (EYE_STUN_TIME, ENRAGE_FRACTION, MARK_*, REPEAT_PENALTY, SAME_HAND_PENALTY); boss_hand.gd: SLAM_HEIGHT, GRAB_REACH, IMPACT_HIT_STOP, SLAM_OVERSHOOT/BOUNCE → `@export_group`. Lo cosmético (bob, parpadeo) puede quedar const.
- [ ] Player
  carrying.gd CARRY_SPEED/THROW_DISTANCE/FLIGHT_TIME, aiming_item.gd LOCKED_SPEED, carrier.gd → `@export`. Mantener la multiplicación por `player.ground_speed` (agua poco profunda, 11169f5): moving, generic `move_locked` y carrying la aplican.
- [ ] Timing de ataque de enemigos
  windup_time, windup_pose, recovery_time de bt_attack a AttackData; `attack` en EntityConfig; enemy_bt.tres deja de fijar skeleton_slash.
- [ ] Vida inicial y HP por corazón
  player.tres `max_health` se ignora (manda NEW_GAME_MAX_HEALTH); HP_PER_HEART copiado en game_state, player_panel, equipment_page y un `/ 4` en slot_card → una sola fuente.
- [ ] Opciones fuera de feel.tres
  settings.gd escribe `shake_enabled` en el recurso de diseño; que Feel lo lea de Settings.
- [ ] Rangos y test de ítems
  `@export_range` en EntityConfig, ItemData, DropEntry; test_items compara archivos de data/items con la base en vez de ITEM_COUNT.

**Prueba:** Cada valor listado aparece en el inspector o en un .tres; cambiar el windup del esqueleto acorazado no cambia a los otros.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/entities/boss/boss.gd`, `src/entities/boss/boss_hand.gd`, `player/states/carrying.gd`, `player/states/aiming_item.gd`, `player/components/carrier.gd`, `ai/tasks/bt_attack.gd`, `src/entities/enemy_bt.tres`, `src/state/game_state.gd`, `src/settings/settings.gd`, `tests/test_items.gd`

### 11.88 Niveles referenciados por ruta: saves y portales frágiles · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `guardado`, `mundo`

Los saves guardan `spawn_scene` como ruta `res://` y los portales `target_scene` como ruta + `target_spawn` sin validar (solo test_portal/test_spring prueban casos sueltos). Renombrar o mover un nivel rompe partidas viejas y portales sin aviso.

- [x] Test de todos los portales
  tests/test_portals.gd: instancia cada levels/*.tscn, y cada Portal que viaja apunta a una escena que existe y que tiene un SpawnPoint con su target_spawn. Encontró la salida de la Chullpa sin punto de llegada: Spawn_chullpa provisorio en la Necrópolis (la entrada de verdad es 7.9 paso 4).
- [x] Aviso en Portal
  Portal es @tool: aviso en el editor si viaja y target_scene está vacío o no existe; en el editor no corre su _ready.
- [x] uid en el save
  GameState guarda spawn_uid junto a spawn_scene y al cargar resuelve el uid (si no, la ruta). Chullpa, dungeon_test y sandbox_items no tenían uid: se lo puse (ResourceSaver.set_uid). test_portals exige uid en todo nivel con SpawnPoint; test_save_manager carga un save con ruta vieja por su uid.

**Prueba:** Un test recorre todos los portales de levels/ y comprueba escena y SpawnPoint; mover un nivel no rompe una partida guardada.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `src/world/portal.gd`, `src/save/save_manager.gd`, `src/state/game_state.gd`

### 11.89 Orden de carpetas y escenas de prueba en la build · Pendiente

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `herramientas`

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
- [ ] Orden de autoloads
  MenuStack antes que Feel; conectar `MenuStack.changed` directo.
- [ ] Renombrar el .tres por defecto

**Prueba:** El export no incluye escenas de prueba; tests verdes tras mover.

**Notas:** Sale de la revisión de arquitectura del 2026-10-11 (skills godot-architecture, godot-patterns, godot-communication, godot-data-driven).

**Archivos:** `export_presets.cfg`, `project.godot`

### 11.90 Diseño de mazmorras, ítems y su reparto en el overworld · En curso

**Prioridad:** alta · **Tamaño:** L · **Etiquetas:** `diseno`, `nivel`

Playtest del 2026-10-12: la primera mazmorra ya tiene varios softblocks, y la pluma está en D1 cuando debería ser de D2 (si no se mira el mapa, su sala pasa desapercibida). D1 tiene el arco como su ítem. Rediseñar qué ítem da cada mazmorra, cómo se enseña y prueba dentro de ella, y dónde gatea el overworld, respetando que un ítem de la mazmorra N no gatea nada de las anteriores.

- [x] Softblocks de D1
  Hecho el 2026-10-12 leyendo temple.tscn y sus scripts (grafo y tabla en el documento de diseño). El orden de llaves es seguro: la llave 1 solo alcanza la puerta este del hub. Softblock duro solo cargando en la misma escena (11.108); los menores en 11.109; el de co-op en 13.16. Falta recorrer la Chullpa cuando se rehaga.
- [x] Ítem por mazmorra
  Decidido con Daniel el 2026-10-12, cambiado en 11.113: D1 arco (mazmorra nueva), D2 pluma, D3 gancho (11.30), D4 escudo espejo; el templo del ojo es la última. Los guantes de fuerza quedan fuera. El disco solar queda como ítem opcional. Documento: https://claude.ai/code/artifact/4fce85f9-7f11-4285-9d2e-bb1d58b45b4e
- [x] Mudar la pluma a D2
  Hecho el 2026-10-12. D1: sin sala de la pluma (puerta tapiada), sin la fila de huecos del Puzzle ni el escalón de la Antesala; navmesh del templo horneada de nuevo. D2: la isla de la Chullpa da la pluma y lo que pedía gancho pasa a pluma (11.60, paso 8). La pieza de la pradera y la angostura quedan para después de D2.
- [ ] Armadura del esqueleto
  Decidido: se quita con el gancho o con la bomba (las dos). Se implementa junto con el gancho (11.30), que ahora es de D3.
- [x] Reparto en el overworld
  Arco: Quebrada, Necrópolis, carcaj del Risco. Pluma: Cardonal, angostura, pieza de la pradera, islotes de la Laguna (entrada a D3). Gancho: postes de la Cumbre (entrada a D4), Mirador, franja del Risco. Cada ítem abre 2–3 secretos en zonas ya visitadas.
- [x] Grafos llave-cerradura de D1 y D2
  Hecho: data/dungeons/d1_graph.tres y d2_graph.tres, los dos pasan test_dungeon_reach.
- [x] Test de alcanzabilidad
  Hecho: DungeonGraph (src/world/dungeon_graph/) por mazmorra en data/dungeons/; tests/dungeon_reach.gd lo cruza con la escena (cerraduras, interruptores, cofres, cobertura de puertas, rejas, cofres e interruptores, salas) y recorre todos los estados (zona, ítems, llaves, puertas abiertas). Falla si algo pide un ítem que nadie da o si hay un estado sin salida, con el camino. test_dungeon_reach: D1 pasa, más casos sintéticos (llave en la puerta equivocada, caída sin vuelta, ítem que falta). El overworld (7.9) queda para después.
- [ ] D3 y D4 visibles pero bloqueadas
  Primer playtest externo con D1 y D2. D3 y D4 se ven en el overworld pero están cerradas y llegan como actualización: diseñar el bloqueo y el sistema de updates o parches.
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

**Prioridad:** media · **Tamaño:** S · **Responsable:** Claude · **Etiquetas:** `jefe`, `bug`

Playtest 2026-10-12: el jefe anda bien en general; la tercera fase es demasiado dura y el modelo suele hundirse en el piso.

- [ ] Nerf de la fase 3
  Menos daño, ventanas más largas o menos ataques encadenados; a ojo con Daniel.
- [x] Que no se hunda en el piso

**Prueba:** test_boss › test_phase_two_opens_the_eye_with_a_tremor: aturdido queda apoyado sin hundirse en el piso; test_marks_keep_the_eye_busy_until_they_blast: mientras se cargan las marcas no encadena otro ataque.

**Notas:** Sesión de bugs (-fd). Hundido: lo más bajo del cuerpo queda 2,35 m bajo su origen; aturdido bajaba a 1,9 y, con el bamboleo, se metía 0,45–0,57 m en el piso (en cada aturdimiento, más seguido en la fase 3). Ahora BODY_HEIGHT_STUNNED = 2,4 y aturdido no se bambolea: queda apoyado (el hurtbox del ojo está fijo, el alcance de la espada no cambia; la caída se ve más corta, 0,2 m en vez de 0,7). Fase 3, primer pase: respiro entre rondas 0,5 → 0,8 s (como la fase 2) y las marcas tienen ocupado al ojo hasta que estallan (antes lo soltaban a los 0,4 s y otro ataque se encimaba con el estallido). Para revisar: probarlo a ojo con Daniel; si sigue duro, lo siguiente es MARK_DAMAGE 4 → 2 o menos peso para mark. De paso: test_overlay_shows_the_fight era inestable (apuntaba a un player de un test anterior y a veces ningún ataque puntuaba); ahora sin objetivo.

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

### 11.98 La cámara muestra lo que se desbloquea · Revisión

**Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `camara`, `feel`

Siempre que algo se desbloquea por una acción (puzzle resuelto, horda eliminada, interruptores activados) la cámara va a mostrar qué se abrió y vuelve, como en Zelda.

- [x] Toma de cámara reutilizable
  TopDownCamera.reveal_unlock(): pausa, paneo a lo que se abre y vuelta (sobre reveal()).
- [x] Puzzles, oleadas e interruptores la usan
- [x] Tests

**Notas:** Sesión: overworld (-74).

### 11.99 Torres de D1: cambio visual al activarse · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `mazmorra`, `arte`

Las torres que se activan al reflejarles el ataque de la torreta en D1 no cambian a la vista cuando quedan activas.

- [x] Estado activo visible (luz, emisión, sonido)
  Al activarse, la torre de ojo prende una piedra dorada arriba (se ve desde la cámara cenital aunque el ojo mire de costado) y una luz que ilumina alrededor. El sonido de reflejo ya estaba.

**Notas:** Sesión: arte (-77).

### 11.100 Qué se puede levantar se tiene que entender · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `arte`, `ui`

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

### 11.102 Mapa: nombres de zona chicos y solo los que importan · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`

Playtest 2026-10-12: los nombres de zona en el mapa son muy grandes y no hace falta que cada área tenga nombre.

- [x] Mockup
  Artboard 'Pausa · Mapa (overworld) por regiones grandes (11.102)' en el canvas: 8 regiones, cuevas y mazmorras con nombre propio. Daniel: sí, y el HUD también por regiones; el Santuario lleva nombre.
- [x] Regiones grandes y lugares con nombre
  AreaZone.region_label y display_name compartido por región; MapPlace para mazmorras, cuevas y santuario; el HUD nombra la región al cambiar de región.

**Notas:** Sesión: overworld (-74). Ajustar el mockup del canvas primero.

### 11.103 El minimapa se transparenta con el player debajo · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`

Cuando el player está debajo del minimapa en pantalla, el minimapa se transparenta para no taparlo.

- [x] Transparencia según la posición en pantalla
- [x] Test

**Notas:** Sesión: overworld (-74). Con varios players: cualquiera de ellos.

### 11.104 Ítems de la mazmorra en la pantalla del mapa · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`, `mazmorra`

Los ítems conseguidos en la mazmorra (mapa, brújula, llave del jefe, llaves chicas) se ven en la pantalla del mapa.

- [x] Mockup
- [x] Pestaña Mapa
  Íconos en lugar de texto (pedido de Daniel): map_dungeon_item.tscn, 4 en una grilla bajo el título.

**Notas:** Sesión: overworld (-74). Mockup primero.

### 11.105 Repensar el tutorial · Pendiente

**Prioridad:** baja · **Tamaño:** M · **Etiquetas:** `diseno`, `ui`

Playtest 2026-10-12: las tablitas del claro (11.45) funcionan, pero no son la mejor forma de enseñar los controles. Buscar otra.

- [ ] Propuesta

**Notas:** Con 11.90 (cada mazmorra enseña su ítem).

### 11.106 Intro al día con el overworld nuevo · Revisión

**Prioridad:** baja · **Tamaño:** S · **Etiquetas:** `camara`

La intro (10.20) funciona, pero sus planos son del overworld viejo. Rehacer los planos sobre el layout D.

- [x] Planos nuevos
  Cámara, brillo y polvo corridos al templo (−48, −37,5) y al Claro (−48, 16); test de encuadre por plano.

**Notas:** Sesión: overworld (-74), después de 7.9 paso 4. Junto con 10.30.

### 11.107 Mejorar la ambientación · Revisión

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `arte`, `audio`

Playtest 2026-10-12: hay que mejorar la ambientación del overworld y las mazmorras: luz, niebla, partículas, sonido ambiente.

- [x] Qué falta por zona (con Daniel)
  Daniel (2026-10-12): luz, niebla y partículas estuvieron bien; no hay que cambiarlas. El sonido anda; no se fijó si falta algo.
- [ ] Escuchar el sonido ambiente por zona en el próximo playtest
  Anotar qué zona suena vacía o repetida; recién ahí agregar o cambiar.

**Notas:** Sesión: arte (-77). Definir con Daniel qué falta en cada zona.

### 11.108 Cargar en la misma escena desincroniza puertas y flags · Revisión

**Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `bug`, `mazmorra`

Encontrado en el análisis de D1 (11.90, softblock S1). Cargar desde la pausa una partida de la misma escena, sin recargarla, vuelve los flags a falso pero el mundo no los sigue: FloorSwitch ignora el falso (floor_switch.gd:37-41), EyeSwitch se apaga sin emitir (eye_switch.gd:38-42), y LightReceiver, WaveSpawner y Bridge solo reaccionan a verdadero; rejas y puertas solo se mueven con Wiring.changed. Si se cruza una puerta que debería estar cerrada y se guarda ahí, al recargar se queda encerrado (ej.: Ojos sin arco con el puente bajo). Arreglo probable: recargar siempre la escena al cargar una partida (save_manager.gd:344).

- [x] SceneFlow.enter_saved_scene recarga siempre la escena, aunque sea la misma
  Mientras carga, traveling queda en verdadero para que el checkpoint donde aparece el player nuevo no pise el spawn_point de la partida (pasaba con bombs_only).
- [x] Test: cargar en la misma escena da una instancia nueva con el muro entero

### 11.109 Softblocks menores de D1 · Pendiente

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `bug`, `mazmorra`

Del análisis de D1 (11.90, S2, S4, S5, S6, S7). Confirmar en el juego y arreglar lo que trabe.

- [ ] S2: bloque en la salida del vestíbulo
  Antes de resolver la placa, empujar VestibuleBlock al hueco de la salida (24,72) tapa la salida con la puerta norte cerrada; el bloque solo se resetea al salir de la sala o recargar (push_block.gd:41-42, 103-112). Probar; si traba, que el bloque no entre en celdas de puerta.
- [ ] S4: matar la torreta antes del ojo
  GalleryTurret es la única fuente de proyectiles antes del arco; si muere antes de despertar GalleryEye no hay llave 1 hasta salir y volver. Opciones: torreta invulnerable a sus orbes, o que reviva al salir de la sala.
- [ ] S5: caja de la Agrietada y espada
  CrackedBox vuelve al hueco en cada recarga y del lado norte casi no salen bombas. La espada probablemente la mueve (hitbox mask 24 incluye la capa 9): confirmar; si se mueve, el puzzle se salta.
- [ ] S6: bloque resuelto del Puzzle corta el haz
  PuzzleBlock se puede seguir empujando y tapa el haz (capa 9 vs máscara 1 del haz, light_beam.gd:28). Trabarlo en la placa una vez resuelto.
- [ ] S7: munición en el templo
  Solo al azar (vasijas 5 %, esqueletos 10 %); las vasijas de la Antesala y de la Pluma solo dan corazones, aunque GDD §8.1 dice que dan munición. Mínimo real: 1 bomba y 2 flechas (el GDD dice 2 y 4). Poner fuentes fijas cerca de cada uso o corregir el GDD.
- [ ] Sin confirmar: orbe al ojo de Ojos, bomba en placa
  El orbe sin reflejar podría despertar OjosDoorEye (se entra sin arco); una bomba (capa 8) sobre una placa BLOCK (máscara 1|8) probablemente la traba y salta el puzzle de bloque.

### 11.110 Tipos de placa de piso: bloque, peso y golpe fuerte · En curso

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `puzzles`

Playtest 2026-10-12: los puzzles de bloques solo se tienen que activar con los bloques; los que se activan con objetos o con un golpe fuerte son otros tipos de placa. Y la placa del santuario se veía apretada sin bloque encima.

- [x] BLOCK solo con bloques y modo WEIGHT para objetos
  FloorSwitch: BLOCK lo aprieta solo un PushBlock (ni el player ni lo arrojado); WEIGHT, un objeto apoyado o arrojado (o un bloque), no el player; los dos quedan resueltos con flag. Santuario y mazmorra gris pasan de ONCE a BLOCK; la placa de levantar del Claro a WEIGHT. Tests: test_wiring, test_grove_puzzle. GDD §11 (interruptores) y §5 (tutorial).
- [x] Placa del santuario apretada sin bloque
  ShrineBlock tenía solved_position del overworld viejo (−30, −16): al cargar con el puzzle resuelto el bloque aparecía lejos y la placa quedaba apretada sola. Ahora (−78, −32); test_solved_blocks_rest_on_their_switch revisa todos los niveles.
- [ ] Que cada tipo se distinga a la vista
  Hoy las cuatro placas son iguales. Marca o color por tipo (bloque, peso, golpe fuerte); pasa por el arte.
- [ ] Placa de golpe fuerte
  Se activa con un golpe fuerte (¿martillo / golpe cargado?); espera el ítem que lo dé (11.90).
- [ ] Probarlo (Daniel)

### 11.111 Cactus, árboles y matas se cortan como el pasto · Revisión

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `overworld`, `arte`

Playtest 2026-10-12: los cactus, árboles y similares deberían poder cortarse y funcionar como el pasto.

- [x] Escenas Breakable de cada planta y reparto en el overworld
  src/world/plants/*.tscn. Celdas del kit (Árbol, Queñoa chica, Cardón, Cardón brazos) sin malla ni colisión en el kit orgánico; decorate_levels.gd pone la escena en cada celda, en las 553 plantas que el terreno orgánico dejó en el piso jugable (tools/plantas_overworld.json) y en las piezas de planta de la decoración. Arriba de los riscos siguen en la malla. Terreno, kit, decoración y navmesh regenerados. 60 fps en la arboleda. Test test_overworld_plants_are_cut_like_grass. GDD §7.
- [ ] Probarlo (Daniel): cortar un árbol abre paso, ¿hay alguno que no debería?
- [x] Animación al romperse
  Daniel: que tengan un poco de animación. Breakable.break_style: CUT (pasto y matas: saltan girando y se achican; el ichu deja la mata cortada), FELL (árboles y cardones: caen del lado contrario al golpe, polvo y rebote, se hunden; los árboles dejan tocón). Cuerpo y hurtbox se apagan en el acto. Tests en test_breakables.

### 11.112 Fantasmas al esquivar · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `feel`

Daniel 2026-10-12: al dash/esquivar ponerle un efecto similar al trail de la espada, como el ghosting del dash de Mega Man Zero.

- [x] Copias de la pose que se desvanecen
  DodgeGhosts (player.tscn) congela la pose cada 0,06 s mientras dura el roll; afterimage.tscn + ghost.gdshader (rosa translúcido con borde claro, depth prepass para que se lea la silueta) se desvanece en 0,3 s. Test test_roll_leaves_ghosts_that_fade. GDD §2 (feel).
- [ ] Probarlo (Daniel): color, cantidad, duración

### 11.113 El templo del ojo pasa a ser la última mazmorra · Pendiente

**Prioridad:** alta · **Etiquetas:** `diseno`, `nivel`

Daniel (2026-10-12): el jefe del ojo se pensó como fin de demo, así que tiene sentido que sea el final del juego. El templo (hoy D1) pasa a ser D4, la última; el escudo espejo pasa a ser lo que se consigue para entrar a la última mazmorra (el sello de luz). Hay que ampliar el templo para que use todos los ítems. Cambia la cadena de 11.90 (qué es D1 ahora, de dónde sale el arco, qué pasa con la mazmorra de la Cumbre) y el reparto del overworld (7.10).

- [x] Cadena nueva de mazmorras e ítems (con Daniel)
  Decidido con Daniel el 2026-10-12: D1 arco (mazmorra nueva), D2 pluma (Chullpa), D3 gancho, D4 escudo espejo, y el templo del ojo como última mazmorra (usa todos los ítems). Los guantes de fuerza quedan fuera. Cada ítem lo guarda un sub-jefe basado en el jefe de su mazmorra, que se vence sin ese ítem; la segunda mitad de la mazmorra se resuelve con el ítem, combinado con los de mazmorras anteriores (ej.: en D2 una torre pide un flechazo para activar el puzzle previo al sub-jefe de la pluma). Falta: qué es D1 y dónde está; qué da el santuario. GDD §6.2.
- [x] Dónde se consigue el escudo espejo y qué lo gatea
  Decidido: es el ítem de D4 (la Cumbre). El santuario del primer acto ya no lo da.
- [ ] Ampliar el templo: salas que usen todos los ítems
- [ ] GDD §6 y §7, y el boceto de 7.10 al día
- [ ] Qué es D1 (arco) y dónde está; qué da el santuario
  Hecho el 2026-10-12 (Daniel: sigue): La Queñoa Vigía en el claro de la Arboleda (boceto 7.10 v4). Blockout levels/quenoa.tscn: Raíces, Tronco y Copa de 2 × 2 salas, llaves, bloque, ojos, muros agrietados, sub-jefe como oleada que guarda el arco; d1_graph.tres con escena pasa el test y las reglas; test_quenoa (escaleras, caídas, reja del tronco, bloque); escenario quenoa. GDD §8c. Falta: qué da el santuario; puerta en el overworld (7.10).
- [x] Chequeo de grafos de diseño y reglas del molde
  Hecho: un DungeonGraph sin escena es de diseño (locked en los pasos, gives/key en los lugares) y test_dungeon_reach lo recorre igual; con escena, la escena tiene que coincidir con locked/key. Reglas: sin el ítem no se llega al objetivo; el ítem pide al sub-jefe (guard), que se vence sin él. tools/dungeon_graph_mermaid.gd lo dibuja. El grafo del templo pasa a temple_graph.tres.
- [x] D1: sub-jefe ojo vigía y jefe de los dos ojos
  Hecho el 2026-10-12. WatcherEye (src/entities/watcher_eye/): un ojo flotante que se abre, marca una línea en el piso y la barre con un rayo. Sub-jefe Ojo Vigía: después del barrido se tira sobre el player y queda enganchado en las raíces, y ahí le pegan espada, bomba o vasija. Jefe Los Ojos de la Queñoa: dos ojos, de a uno por vez; una flecha con el ojo abierto lo derriba para la espada, y el que queda se apura. EyeFight maneja la pelea como una oleada: cierra las puertas, intro, barra, se reinicia si el player sale, flag e interruptor. Con la regla de Daniel (salas sin obstáculos, cofre del ítem en una sala contigua que abre el sub-jefe), la guarida pasa a la sala SE con vasijas y el arco a la Cámara del arco (SO), detrás de una puerta que abre el sub-jefe. Contenedor de corazón y portal de salida. test_quenoa juega las dos peleas.
- [ ] D1: kit de árbol y recorrerla (Daniel)
  Hoy usa el kit de la Chullpa. Arte (Daniel, 2026-10-12): las paredes sueltas dentro de una sala (nichos de cofres, reja de la escalera del tronco) se ven como bloques macizos con la tapa cortada; hacen falta piezas de nicho o pared baja propias del kit. Recorrerla con el escenario quenoa.
- [x] Invertir D1 y D2: la pluma primero
  Hecho el 2026-10-13 (Daniel: la pluma es mejor como primer ítem de mazmorra). La Chullpa es D1 (pluma) y la Queñoa D2 (arco); ninguna pedía el ítem de la otra. Grafos renombrados a chullpa_graph.tres y quenoa_graph.tres; la Chullpa trae solo bombas y la Queñoa bombas y pluma. Id y flags de la Chullpa pasan de d2 a ch (prefijo por mazmorra: ch_, qv_, d1_ el templo). Escenario chullpa sin arco ni pluma, quenoa con pluma. GDD §6.1, §6.2, §8b y §8c. Falta: §7 y el boceto de 7.10 (dónde está la Chullpa, qué gatea el camino a la Arboleda) con la sesión del overworld; la Queñoa no usa la pluma todavía.

**Notas:** Sesión: diseño (-43 [a7e236]), con Daniel. Overworld (-eb) acomoda el boceto de 7.10 cuando esté la cadena.

### 11.114 Botellas en su propia fila de la pestaña Ítems · Revisión

**Prioridad:** media · **Tamaño:** S · **Etiquetas:** `ui`

Daniel (2026-10-12): las botellas tienen su fila fija, separada de los ítems comunes, en la misma pestaña.

- [x] Mockup Pause_Items: fila Botellas debajo de la grilla
- [x] items_page: grilla de 8 sin botellas y BottleGrid con bottle_1..4; el cursor de co-op recorre las dos
- [x] Tests: test_bottles_have_their_own_fixed_row y test_item_ring al día

### Enemigos que deambulan mientras no te ven; centinelas con alerta y búsqueda · Pendiente

**Prioridad:** alta · **Etiquetas:** `ia`, `enemigos`

Daniel (2026-10-13): los enemigos que no te detectaron no se quedan quietos. Todos deambulan cerca de su lugar: caminan despacio a puntos al azar de la navmesh dentro de unos metros de donde empiezan, paran un rato y miran alrededor (reemplaza la rama Quieto de enemy_bt.tres; radio, velocidad y pausas en EntityConfig). Alerta y búsqueda solo para un tipo de enemigo nuevo: el centinela o guardia de una guarida de un grupo enemigo que no son monstruos. Al verte hace una pausa de alerta (un !) antes de atacar; si te pierde va a tu último lugar visto, mira alrededor y vuelve a su puesto. Descartados por ahora: rondas fijas y cono de visión.

- [ ] Deambular cerca de su lugar para todos los enemigos
  Rama nueva en enemy_bt.tres en lugar de Quieto: punto al azar de la navmesh dentro de wander_radius del lugar de inicio, caminar a wander_speed, pausa y mirar alrededor. Datos en EntityConfig. Que no salgan de su zona ni se tiren a un abismo.
- [ ] Diseño del centinela: quién es el grupo enemigo no monstruo y cómo se ve
  Tipo de enemigo nuevo para guaridas (personaje humano o de una facción, no esqueleto). Lo decide Daniel con diseño y arte.
- [ ] Alerta y búsqueda del centinela
  Al verte: pausa de alerta con un ! antes de atacar. Si te pierde: va al último lugar visto, mira alrededor y vuelve a su puesto.
- [ ] Tests
  Deambula sin salirse del radio ni trabarse; el centinela alerta, persigue, busca y vuelve.

## M12 — Assets propios (Blender)  (6/18)

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

### 12.2 Terreno del overworld · En curso

**Prioridad:** alta · **Etiquetas:** `arte`

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
- [ ] Escalones y rampa (tierra y piedra)
  Escalón: muro de piedra con lajas encastradas arriba (hecho). La escalinata está en el .blend pero no en el kit, y el overworld no tiene ningún desnivel que pida rampa: falta decidir si hacen falta.
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
  Hecho: cloud_shadows.gdshaderinc (ruido en mundo, deriva) en los materiales de afuera (epiphany_outdoor/wind/wall: kit del overworld, lugares, naturaleza); global cloud_shadows que prende el nodo CloudShadows de overworld.tscn (fuerza, tamaño, deriva exportados). Personajes y templo sin nubes.
- [x] Cara del risco y topes con detalle
  Hecho: risco en seis estratos que salen y entran (repisas con musgo, abajo oscuro, una veta sutil en tierra); topes risco (piedras), risco_ichu y risco_flores, que vary_overworld.gd reparte por hash. Viento en wind.gdshaderinc, también en las paredes con agujero (epiphany_wall_wind.tres). Los andenes quedan lisos: Acantilado está en 944/950.
- [x] Camino con detalle
  Hecho: tierra_manchas, tierra_guijarros, tierra_huellas (pisadas de llama) y tierra_pasto (matitas que se mecen); vary_overworld.gd las reparte en la tierra junto con tierra_piedras (54 % de las celdas con algo).
- [x] Niebla en el abismo
  Hecho: dos capas (abyss_mist.gdshader, ruido que se corre) como segunda superficie de las celdas de abismo del kit; más espesa abajo.
- [x] Hojas que caen
  Hecho: falling_leaves.tscn (GPUParticles3D, 4 hojas que giran y el viento corre) bajo la copa de cada árbol jugable (Árbol, Queñoa chica); las pone decorate_levels.gd en Decor/Hojas.
- [x] Polvo en el aire
  Hecho: dust_motes.tscn (GPUParticles3D, 40 motas aditivas que flotan) colgado de TopDownCamera en overworld.tscn, delante de la cámara a la altura del player.

**Prueba:** El GridMap del overworld usa solo estas piezas y la navmesh y las colisiones siguen andando.

**Referencias:** `gdd.md#overworld-layout`

**Bloquea a:** 12.3 Lugares del overworld

**Bloqueada por:** 12.1 Guía de estilo: paleta, escala y pieza de prueba

**Relacionadas:** 11.4 Decorar el overworld

### 12.3 Lugares del overworld · Revisión

**Prioridad:** alta · **Etiquetas:** `arte`, `puzzles`

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

### 12.4 Vegetación y props del overworld · Revisión

**Prioridad:** alta · **Etiquetas:** `arte`

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

### 12.5 Interactivos y pickups · Revisión

**Prioridad:** media · **Etiquetas:** `arte`

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

### 12.7 Kit del templo propio · Revisión

**Prioridad:** baja · **Etiquetas:** `arte`, `mazmorra`

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

### 12.9 Efectos con malla · Revisión

**Prioridad:** baja · **Etiquetas:** `arte`

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

### 12.12 Estilo toon (Wind Waker) + personaje cyber-shinobi · En curso

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

**Bloquea a:** 12.13 Reajuste de estilo toon de todos los assets

**Relacionadas:** 12.10 Pipeline Blender→Godot: glb publicado + plugin de import

### 12.13 Reajuste de estilo toon de todos los assets · Pendiente

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

### 12.15 Overworld orgánico con lomas (variante 6) · Revisión

**Prioridad:** alta · **Etiquetas:** `arte`

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

### 12.17 Estilos por mazmorra · En curso

**Prioridad:** media · **Etiquetas:** `arte`, `mazmorra`

Cada mazmorra con su propio estilo sobre el mismo kit (mismas piezas y colisiones): piedra, muro, remate, piso, columnas y relieve. D1 Templo (piedra lavanda, chakana, ojos), D2 Chullpa (piedra de campo con barro, cornisa, nichos con cráneos, tierra apisonada), D3 Laguna (bloques grises con musgo, ondas, charcos), D4 Cumbre (basalto, nieve y carámbanos, soles de oro, escarcha). tools/blender/build_templo.py -- <estilo> publica templo_<estilo>.glb.

- [x] Prueba: la misma sala en los cuatro estilos
  diorama.py -- <png> templo templo_<estilo>.
- [x] Elección y ajustes del usuario
  Aprobados los cuatro estilos el 2026-10-11. El usuario pide lo mismo para la zona del overworld de cada mazmorra (consultado con la otra sesión, dueña de 7.9).
- [x] Kit de cada mazmorra en Godot
  build_temple_kit.gd -- <estilo> arma chullpa_kit, laguna_kit y cumbre_kit (mismos ítems y colisiones que temple_kit). levels/chullpa.tscn usa chullpa_kit. Laguna y Cumbre todavía no tienen escena.
- [ ] Luz y ambiente por mazmorra
  WorldEnvironment y luces: cálida y polvorienta (chullpa), fría y húmeda (laguna), blanca y ventosa (cumbre).
- [ ] Props por estilo
  Braseros, estandartes, puertas y vasijas con la piedra y los motivos de cada mazmorra.
- [x] Estilo del terreno del overworld por región
  AreaZone.terrain_style (necropolis, laguna, cumbre, explanada, cardonal, quebrada); el build pinta suelo, riscos y abismo por región con borde ondulado y cambia la decoración. Puestos en overworld.tscn: Templo explanada, Quebrada, Necrópolis + Mirador, Cumbre + Risco, Laguna + Bañado, Cardonal. Falta que el usuario lo vea.

### Estilo Link's Awakening en las mazmorras reales: cámara y assets nuevos · Pendiente

**Prioridad:** media · **Tamaño:** M · **Etiquetas:** `arte`, `mazmorra`, `camara`

Daniel (2026-10-13): la Chullpa real tiene la cámara vieja; el test LA (debug/la/chullpa_la.tscn) ya tiene la cámara de Link's Awakening, paredes, puertas y props nuevos. Llevar eso a las mazmorras jugables cuando la sesión de arte tenga los assets nuevos. El juego no cambia: no se mueven nodos de juego (puertas, placas, cofres, peleas, huecos, escaleras).

- [ ] Chullpa: cámara LA y kit nuevo
  La escena jugable levels/chullpa.tscn toma la cámara (pitch, fov, distancia, tilt-shift, luces por sala) y el kit del test LA. Correr test_chullpa, test_dungeon_reach y test_map.
- [ ] Queñoa: kit de árbol en estilo LA
  Junto con 11.113 paso 8 (piezas de nicho y pared baja propias del árbol).
- [ ] Templo del ojo en estilo LA
- [ ] Recorrerlas (Daniel)

**Notas:** Sesión: arte (-11). Diseño (-43) revisa que el juego no cambie.

## M13 — Co-op local (estilo Four Swords)  (0/16)

Dos jugadores en la misma pantalla recorren el overworld y el templo juntos, con progreso compartido y puzzles que aprovechan a los dos.

**Hecho cuando:**
- Dos controles juegan una partida de punta a punta (overworld, templo y jefe) sin bugs de cámara ni de salas.
- Hay al menos tres puzzles que piden a los dos jugadores.
- Un solo jugador puede seguir jugando como siempre.

### 13.1 Código listo para varios players · Revisión

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

### 13.2 Input por jugador y unirse a la partida · Revisión

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

### 13.3 Cámara y salas para dos · Revisión

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

### 13.4 Reglas del co-op · Revisión

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

### 13.5 HUD de dos jugadores · Revisión

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

### 13.6 Player 2 con su color · Revisión

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

### 13.9 Anillo de ítems por player · Revisión

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

### 13.11 Estado de un player que se cuela en el otro · Pendiente

**Prioridad:** alta · **Tamaño:** M · **Etiquetas:** `bug`, `coop`

Cosas que todavía son de todos o de P1: el `tree_root` del AnimationTree es un sub-recurso compartido y jumping/pushing/using_item cambian `ItemAnim` (la animación de uno se mete en el otro); `Feel.rumble` siempre vibra el pad 0; el apuntado con ratón depende de `InputDevice.current` global; `tremor_zone` usa un solo bool `_inside`; el tope de bombas cuenta las de todos; el banner de zona (`AreaZone._current` estático) cambia cuando cruza cualquiera.

- [ ] AnimationTree por instancia
  `resource_local_to_scene` en el sub-recurso o `tree_root.duplicate(true)` en `player._ready`.
- [ ] Vibración por pad
  `Feel.rumble(amount, device := -1)`: el player pasa su pad; eventos del mundo vibran todos los pads asignados.
- [ ] Apuntado con ratón
  aim.gd ~l.54: quitar el chequeo de `InputDevice.current`, ya se sigue por player con `controls.owns()`.
- [ ] Zona de temblor
  Contar players adentro o `get_overlapping_bodies().any(...)`.
- [ ] Bombas por player
  place_behavior.gd: contar solo las de `ctx.user`.

**Prueba:** Con dos players: P1 salta mientras P2 usa un ítem y cada uno ve su animación; un golpe a P2 vibra solo su pad; cada uno puede tener sus bombas.

**Notas:** Sale de la revisión de código general del 2026-10-11 (skill godot-code-review).

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

### 14.9 SceneFlow: flujo de escenas aparte de SaveManager y pantalla de carga · Revisión

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

## Listas

### Assets de audio  (3/6)

- [x] Kenney Impact Sounds (CC0) — golpes, daño, bloqueo, macetas, reflejo · assets/audio/sfx/kenney_impact-sounds
- [x] Kenney RPG Audio (CC0) — cortes, rodada, puertas, clics · assets/audio/sfx/kenney_rpg-audio
- [x] Kenney Interface Sounds (CC0) — rechazo, levantar, sonidos de menú · assets/audio/sfx/kenney_interface-sounds
- [ ] Música de verdad para overworld y templo (hoy: capas sintetizadas por src/tools/render_music.gd)
- [ ] SFX de explosión, secreto, curación y temblor (hoy sintetizados en Feel)
- [ ] Pasos (footsteps) y ambiente del templo (Kenney Impact Sounds trae pasos; falta el evento)
