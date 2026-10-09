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

**Cámara por sala (6.1, corregida el 2026-10-08), como el remake de Link's Awakening:** la cámara sigue siempre al player y se frena recién cuando el borde de la pantalla llega a la pared: el ancho se mide en la fila del player, abajo hasta el piso sur y arriba hasta el tope de la pared norte (`wall_height`). Si la sala es más chica que la pantalla en un eje, queda fija y centrada en pantalla. Todo lo de fuera de la sala actual queda en negro (una máscara a la altura de las paredes, `mask_margin` afuera para no tapar las paredes), así nunca se ve qué hay detrás de las puertas; durante el deslizamiento la máscara abarca las dos salas. La cámara usa FOV 40 y `offset` (0, 17.4, 10.0) en todo el juego, overworld incluido (alejada el 2026-10-09): una pantalla abarca ≈ 26 × 14.5 m en la fila del player, así que una sala del templo (22 × 14 m) se ve entera, con las puertas laterales y la sur, y queda fija. **Pared sur recortada:** las paredes y columnas del kit usan `data/kits/shaders/cutaway.gdshader`; al entrar a una sala la cámara le pasa el rectángulo de su pared sur y todo lo que está ahí por encima de `south_wall_cut` (0.4 m) se descarta. Lo que queda se pinta de un oscuro plano (emisión, sin luz), como un zócalo, así la puerta sur se ve de frente. Las colisiones no cambian.

### 4.2 Movimiento y combate
<!-- id: movimiento-combate -->

- Movimiento libre analógico (8+ direcciones), rotación suave del modelo.
- **Lock-on (Z-target)**: mantener o alternar (configurable, ya implementado). Con objetivo fijado el player strafea y la cámara encuadra a ambos.
- **Cambio de objetivo**: con objetivo fijado, el stick derecho **apunta**: pasado 0.7 (`look_*`), se fija el candidato que está en esa dirección desde el player (cono de ±60°; en empate, el más cercano), sin importar cuál estaba fijado. Barrer el stick va cambiando de objetivo; solo cambia si el nuevo está claramente mejor alineado (`point_hysteresis`). Candidatos: en pantalla, en rango y a la vista (las paredes tapan, los enemigos no). La rueda del mouse salta al vecino de la izquierda o la derecha; sin vecino no pasa nada, salvo con `Targeting.wrap_around` (apagado, a decidir jugando). Un objetivo que muere o sale de rango se suelta tras 0,5 s; en modo alternar salta al siguiente. Teclado y mouse: a definir (§4.3).
- **Apuntado libre**: analógico derecho o mouse (rayo cámara → plano del suelo). Lo consumen arco, bombas lanzadas y cualquier ítem a distancia.

### 4.3 Mapa de input
<!-- id: input -->

| Acción (`InputMap`) | Gamepad (Xbox · índice en Godot) | Teclado y mouse | Uso |
|---|---|---|---|
| `move_*` | Stick izquierdo | WASD | Moverse. Al tensar el arco, apuntar |
| `attack` | A · botón 0 | Click izquierdo | Espada |
| `interact` | B · botón 1 | E | Abrir, leer, empujar (acción contextual) |
| `dodge` | RB · botón 10 | Espacio | Rodar. En gamepad queda al lado de la guardia: cubrirse y esquivar con el mismo dedo |
| `item_1` / `item_2` | X · botón 2 / Y · botón 3 | Q / R | Ítems asignados. Los que se mantienen (arco): sin objetivo fijado, mientras se tensa el player se planta y **el stick izquierdo apunta** (como Ocarina of Time), porque el pulgar derecho no puede mantener X/Y y mover el stick derecho a la vez. Con objetivo fijado la flecha va al objetivo y el stick izquierdo camina en strafe. El stick derecho y el mouse también apuntan |
| `block` | RT · eje 5 | Click derecho | Guardia |
| `z-lock` | LT · eje 4 | Shift izquierdo | Fijar objetivo |
| `look_left` / `look_right` / `look_up` / `look_down` | Stick derecho · ejes 2 y 3 | Mouse (lo lee `Aim`) | Una sola dirección para dos usos. Sin objetivo fijado: apuntar (zona muerta normal). Con objetivo fijado: cambiar de objetivo cuando cruza 0.7 (el mismo `look_*` leído con otro umbral). Remapear `look_*` mueve los dos usos juntos |
| `target_prev` / `target_next` | — (el stick derecho) | Rueda arriba / abajo | Cambiar de objetivo con teclado y mouse |
| `pause` | Start · botón 6 | Tab o Esc | Menú de pausa (inventario) |
| `map` | Back · botón 4 | M | Mapa |
| `ui_tab_left` / `ui_tab_right` | LB · botón 9 / RB · botón 10 | Q / E | Pestañas de los menús. Prefijo `ui_` porque son de otro contexto: con el juego pausado no chocan con `dodge`, `item_1` ni `interact` |
| `debug_overlay` / `debug_quickload` / `debug_quicksave` | — | 1 / 2 / 3 | Solo en debug. Provisorias: el teclado de desarrollo no tiene teclas F |

Las teclas se mapean por posición física (`physical_keycode`): WASD queda en el mismo lugar en cualquier distribución. El autoload `InputDevice` avisa con `input_device_changed` cuando el jugador pasa de gamepad a teclado/mouse o al revés. El remapeo es post-MVP.

## 5. Combate
<!-- id: combate -->

- **Vida:** corazones; **1 corazón = 4 HP** (permite daño de ¼). Inicio: 3 corazones. El HUD dibuja cuartos.
- **Recibir daño:** retroceso + ≈0.8 s de invulnerabilidad con parpadeo. Al llegar a 0: game over → continuar desde la entrada de la sala / último punto de reaparición.
- **Espada:** combo corto (hoy: slash). Stab cargado / spin attack: post-MVP.
- **Escudo:** mientras se bloquea, el golpe se anula si viene **de frente** (cono de ±60°). Con escudo espejo, los proyectiles bloqueados se reflejan hacia donde mira el player (o hacia el objetivo fijado).
- **Qué frena cada escudo** (`ItemData.protects_against`, contra `DamageInfo.element`; vacío = `physical`): la madera frena daño físico (espadas, flechas, orbes) pero no explosiones ni fuego, que pasan aunque se bloquee de frente. El espejo frena lo físico y **refleja siempre** los proyectiles reflejables que intercepta.
- **Escudo en la espalda:** sin bloquear, frena los proyectiles que llegan por detrás (cono de ±45°, `back_shield_angle_deg`) si son de un tipo que protege; el espejo los devuelve a quien los tiró. Los golpes cuerpo a cuerpo por la espalda no se frenan.
- **Golpe de escudo:** atacar mientras se bloquea (ya existe, `ShieldThrust`): aturde / empuja.
- **Esquiva (roll):** i-frames cortos, usa las animaciones `Dodge_*` de KayKit.
- **Enemigos (MVP):** 3 arquetipos + jefe:
  - *Esqueleto* — melee básico, enseña bloqueo.
  - *Esqueleto con escudo* — bloquea de frente; obliga a flanquear, usar bombas o golpe de escudo. (`src/entities/shield_skeleton.tscn`: `EntityConfig.guards_front` frena golpes y proyectiles dentro de `guard_angle_deg`, las explosiones pasan; un golpe que aturde, como el golpe de escudo, le baja la guardia `guard_break_time`; `turn_speed` lo hace girar lento, así se le puede rodar a la espalda.)
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
| Túnica | Equipo | Pasivo | Inicio | Armadura base: el Knight con su gris de siempre |
| Cota reforzada | Equipo | Pasivo (−25% daño) | Overworld: cofre secreto (puzzle de bloques) | Armadura dorada con ribetes rojos, traje violeta y neón magenta: el cuerpo usa la paleta alternativa `palette_reforzada.png` (`data/materials/armor_reforzada.tres`) |
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

### 7.1 Layout
<!-- id: overworld-layout -->

Decidido el 2026-10-08. 8 zonas de ≈ 24 × 16 m (una "pantalla" con la cámara, que abarca ≈ 26 × 14.5 m) en una grilla de 3 × 3 sin la esquina sureste. La cámara sigue libre; las zonas se distinguen por el terreno y el nombre de área del HUD.

```
            OESTE                 CENTRO                  ESTE
       ┌──────────────────┬──────────────────┬──────────────────┐
 NORTE │ SANTUARIO        │ ENTRADA TEMPLO   │ RISCO DEL OJO    │
       │ escudo espejo    │ sello de luz     │ ojo-interruptor  │
       │                  │                  │ → CARCAJ         │
       │      ══atajo══►  │                  │                  │
       ├───▲muro agriet.──┼────────▲─────────┼────────▲─────────┤
 MEDIO │ CUEVA            │ PRADERA (hub)    │ ARBOLEDA         │
       │ BOMBAS           │                  │ → COTA           │
       ├──────────────────┼────────▲─────────┼──────────────────┘
  SUR  │ GRUTA OCULTA     │ INICIO           │
       │ → BOTELLA        │                  │
       └──────────────────┴──────────────────┘
```

| Zona | Contenido | Combate | Se entra | Ritmo |
|---|---|---|---|---|
| **Inicio** (S) | Punto de inicio, tablilla de tutorial (controles, objetivo: el templo) | — | Libre | Calma |
| **Pradera** (C, hub) | Pasto, vasijas, tablilla de lore. **Desde acá se ve el templo sellado** (cebo y referencia del mapa mental) | Esqueletos | Libre desde Inicio | Combate |
| **Cueva** (O) | Cofre de la **bolsa de bombas**; adentro, un muro agrietado de práctica con una vasija de corazones detrás (enseñar en un lugar seguro) | 1–2 esqueletos | Libre desde la Pradera | Combate → descubrimiento |
| **Gruta oculta** (SO) | Muro agrietado desde el Inicio; cofre con **botella + poción**; tablilla que da una pista | — | Bombas | Recompensa |
| **Santuario** (NO) | Muro agrietado desde la Cueva. Puzzle de luz que **enseña** a reflejar el haz con el escudo (en sala chica, sin presión); cofre grande del **escudo espejo** | — | Bombas | Descubrimiento |
| **Entrada al templo** (N) | Fuente de luz y sello: hay que pararse donde corresponde y reflejar el haz con el escudo espejo (la **prueba** de lo aprendido) → abre la mazmorra | Torreta opcional | Libre desde la Pradera (el sello se ve antes de poder abrirlo) | Prueba |
| **Arboleda** (E) | Puzzle de bloques por grilla → cofre de la **cota reforzada** | Esqueleto | Libre desde la Pradera | Descanso / opcional |
| **Risco del ojo** (NE) | Ojo-interruptor alto, del otro lado de un abismo; **se ve desde el principio**, solo se activa con flechas → baja un puente o una reja al cofre del **carcaj grande** | — | Libre desde la Arboleda; el cofre, con el arco | Post-mazmorra |

**Atajos:** del Santuario a la Entrada del templo hay una reja que **solo se abre desde adentro** del Santuario (palanca o interruptor), así la vuelta con el escudo es corta y no se puede saltear el muro agrietado.

**Verificación del gating** (camino crítico y qué bloquea cada cosa):

| Para llegar a… | Hace falta | Dónde se consigue | ¿Se consigue antes sin lo que bloquea? |
|---|---|---|---|
| Bombas | — | Cueva, libre | Sí |
| Santuario / escudo espejo | Bombas (muro agrietado) | Cueva | El atajo solo abre desde adentro → no hay otra entrada |
| Mazmorra | Escudo espejo (sello) | Santuario | El escudo de madera no refleja; no hay otro espejo |
| Botella (opcional) | Bombas | Cueva | — |
| Cota (opcional) | Nada (empujar bloques) | Arboleda | — |
| Carcaj (post-mazmorra) | Arco | Mazmorra | El ojo solo reacciona a proyectiles; las bombas no llegan al otro lado del abismo |

**Vuelta:** del templo a la Pradera hay camino directo (S); el Inicio y el Santuario tienen `SpawnPoint` de checkpoint.

**Curva de ritmo:** calma (Inicio) → combate (Pradera) → combate y descubrimiento (Cueva: bombas) → recompensa opcional (Gruta) → descubrimiento (Santuario: escudo espejo) → prueba (sello) → mazmorra → vuelta tranquila con el arco al Risco (carcaj).

**Blockout (7.2):** `levels/overworld.tscn`, un `GridMap` con el kit gris más sus piezas de exterior (Pasto, Acantilado, Cerco, Árbol, Abismo). Zonas de 11 × 7 celdas de interior separadas por acantilados de una celda; aberturas de 3 celdas donde el paso es libre y de 1 celda donde hay gating (ahí van el muro agrietado o la reja de 7.4, 7.5 y 7.7). Cada zona tiene un `AreaZone` (el HUD muestra su nombre al entrar desde otra zona) y un `SpawnPoint` con el id de la zona (`start` y `santuario` son checkpoints). El abismo frena al player (colisión hasta 0.6 m) pero las flechas pasan por arriba. Cajas y rocas: `src/world/physics_box.tscn` y `physics_rock.tscn`. La navmesh se hornea desde el grupo `navmesh_source` (el `GridMap`); si cambia el terreno, botón *Bake* del `NavigationRegion3D`. La navmesh queda 0.5 m sobre el piso, así que el `NavigationAgent3D` del enemigo usa `path_desired_distance` 1.0 (con 0.5 se trababa en las esquinas: nunca daba por alcanzado el punto). Los enemigos ven al player a 12 m (`EntityConfig.vision_range`, antes 8): con la cámara que muestra la sala entera, a 8 m se quedaban quietos estando en pantalla. `test_enemy_ai` revisa que ningún enemigo del overworld o del templo aparezca encimado con paredes o cercos. El mapa de pausa usa una foto cenital ortográfica (`assets/ui/maps/overworld.png`).

**Cambio de escena (7.3):** un `Portal` (Area3D con `target_scene` y `target_spawn`) llama a `SaveManager.travel_to()`: pausa, fundido, carga en segundo plano con `ResourceLoader.load_threaded_request` (la imagen no se congela), cambio de escena, el player en el `SpawnPoint` pedido con la cámara enganchada encima (`TopDownCamera.snap_to_target`), autosave en `SaveManager.autosave_slot` y fundido de vuelta. `current_dungeon` lo pone y lo saca el nodo `Dungeon` de cada escena; el estado de cada mazmorra vive en `GameState.dungeons`, así que entrar y salir no lo pierde. El punto de llegada va siempre afuera del portal de la otra escena. Por ahora la puerta del templo lleva a la mazmorra gris (`dungeon_test`); en M8 apunta al templo. **Portal de salida del jefe:** `src/world/warp_portal.tscn` (un `Portal` con disco, anillo y haz dorados) en el centro de la sala del jefe lleva al overworld, a `Spawn_templo` (la entrada del templo). `Portal.required_flag` lo deja oculto y sin detectar hasta que el flag sea verdadero; por ahora no tiene flag (todavía no hay jefe) y en 9.6 se le pone `d1_boss_defeated`.

**Cueva de las bombas (7.4):** el cofre (`ow_cave_bombs_chest`) da la bolsa con bombas y la tablilla de al lado enseña a ponerlas (`data/dialogue/overworld.dialogue`, cue `cave_bombs`). En la esquina suroeste, un recoveco tapado por un muro agrietado de práctica (`ow_cave_practice_wall`) guarda una vasija de corazones: se prueba la bomba enseguida y sin riesgo. El muro del paso al Santuario (`ow_shrine_cracked_wall`) queda a la vista desde la entrada de la cueva. Pendiente de pulido: las paredes altas del recoveco tapan al player cuando pasa justo detrás.

**Santuario (7.5):** detrás del muro agrietado. Desafío corto: un bloque al interruptor (`ow_shrine_switch`) baja la reja del recoveco norte, donde está el cofre grande del escudo espejo (`ow_shrine_mirror_chest`; `equip_on_get` hace que se equipe solo aunque haya otro escudo, y su *item get* explica el reflejo). Haz de práctica: la fuente de la esquina noreste apunta al sur; bloqueando en diagonal (girando con el stick derecho o el mouse) el espejo lo manda al oeste, al cristal (`ow_shrine_shortcut`, con latch), que abre la reja del atajo a la Entrada del templo: solo se abre desde adentro. Las rejas (`Gate`) y los cristales con flag quedan como estaban al cargar la partida. Escenario `bombs_only`: inventario inicial + bombas, en la cueva.

**Sello del templo (7.6):** la fuente del oeste apunta al sur, a un espejo fijo a 45° que manda el haz al este, cruzando la plaza. Atajándolo con el escudo espejo (bloqueo en diagonal, girando con el stick derecho o el mouse) va al norte, al cristal del sello (`ow_temple_seal_open`, con latch). `TempleSeal` (una `Gate` con el ojo) se hunde con sacudida fuerte, retumbo y polvo: el primer momento de *doom*. `TremorZone` cubre la entrada del templo: mientras el player está ahí, cada 6 s una sacudida suave con retumbo grave. Escenario `pre_temple`: todo lo del overworld hasta el escudo espejo, en la entrada del templo.

**Secretos (7.7):** *Gruta oculta*: muro agrietado desde el claro del inicio (`ow_grotto_cracked_wall`), cofre con la poción en botella (`ow_grotto_chest`) y tablilla que adelanta el ojo del risco (cue `grotto_hint`). *Arboleda*: dos bloques en dos interruptores (`ow_grove_switch_a/b`) bajan la reja del recoveco noreste con la cota reforzada (`ow_grove_chest`; no se equipa sola, así se usa la pantalla Equipo). *Risco del ojo*: el `EyeSwitch` de la cornisa (`ow_cliff_eye`) solo reacciona a proyectiles y abre el nicho del carcaj grande (`ow_cliff_quiver_chest`, +20 flechas de capacidad).

**Escenarios (7.8):** `start` (inventario inicial, en el claro del inicio; el overworld es la escena principal del juego), `bombs_only` (con bombas, en la cueva) y `pre_temple` (con el escudo espejo, en la entrada del templo). `tests/test_overworld_run.gd` juega `start` de corrido hasta entrar al templo y volver a salir.

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

### 8.1 Layout
<!-- id: mazmorra-layout -->

Decidido el 2026-10-08 con la metodología de [[gdd#overworld-layout]] (artículo "The Ultimate Methodology of creating Zelda-Like Dungeon Level"): hub con "lados primero, centro al final", candado y llave con ramas obligatorias, y el ítem clave (arco) a mitad de camino para volver a salas ya vistas con algo nuevo.

```
                 ┌───────────┐
                 │ 9 JEFE    │
                 └─────▲─────┘
                    [JEFE]
┌───────────┐    ┌─────┴─────┐    ┌───────────┐
│ 7 PUZZLE  │    │ 8 ANTESALA│    │ 5 ARENA   │
│ llave jefe│    │ vasijas,  │    │ oleadas → │
│ + abre el │    │ tablilla  │    │ ARCO      │
│ sello del │    └─────▲─────┘    └─────▲─────┘
│ hub       │      [SELLO]          [GRIETA]
└─────▲─────┘          │                │
   [LLAVE]             │                │
┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
│ 6 OJOS    │    │ 2 HUB     │    │ 4 AGRIET. │
│ brújula + │    │ esqueletos│◄───┤ bombas →  │
│ llave 2   │    │           │LLAVE  MAPA    │
└─────▲─────┘    └─────▲─────┘    └───────────┘
   [OJO→flecha]        │
┌─────┴─────┐          │
│ 3 GALERÍA ├─[PERSIANA]┘
│ torreta → │    ┌─────┴─────┐
│ llave 1   │    │ 1 VESTÍB. │  ← entrada desde el overworld
└───────────┘    │ bloque →  │
                 │ interrup. │
                 └───────────┘
```

| Puerta | Tipo | Se abre con |
|---|---|---|
| Vestíbulo → Hub | Interruptor | Bloque por grilla en el interruptor del vestíbulo |
| Hub → Galería (O) | Persiana | Vencer a los esqueletos del hub |
| Hub → Sala agrietada (E) | Con llave | Llave 1 (Galería) |
| Agrietada → Arena (N) | Muro agrietado | Bomba |
| Galería → Ojos (N) | Interruptor | Ojo sobre la puerta: **solo con flecha** (vuelta a una sala vista con el arco) |
| Ojos → Puzzle (N) | Con llave | Llave 2 (Ojos) |
| Hub → Antesala (N) | Sellada (interruptor) | Resolver el puzzle combinado: se ve cerrada desde el principio |
| Antesala → Jefe (N) | Del jefe | Llave del jefe (Puzzle) |

**Llaves:** 2 llaves chicas y 2 puertas con llave. La llave 1 solo puede gastarse en la puerta este del hub, porque la otra puerta con llave (Ojos → Puzzle) queda detrás del arco, que está detrás de la puerta este. La llave 2 aparece recién en Ojos. En ningún orden quedan menos llaves que puertas.

**Arco a mitad de camino:** sin arco se recorren Vestíbulo, Hub, Galería, Agrietada y Arena (5 de 9). Con el arco se vuelve a la Galería, cuyo ojo sobre la puerta norte se vio desde el principio (cebo), y empieza la segunda mitad: Ojos y Puzzle giran alrededor de las flechas, combinadas con bloques y el escudo espejo.

**Munición:** las vasijas sueltan flechas y bombas (solo si ya se tiene el arco o la bolsa); hay vasijas en el hub y en la antesala.

**Curva de tensión y *doom*:** calma (Vestíbulo) → combate (Hub) → puzzle con presión (Galería) → puzzle (Agrietada) → clímax de la primera mitad (Arena, oleadas) → descubrimiento con el arco (Ojos) → prueba combinada (Puzzle) → respiro antes del jefe (Antesala) → Jefe. El *doom* de cada sala es la columna de la tabla de arriba.

**Construcción:** `levels/temple.tscn` (id `d1`, flags `d1_*`, diálogos en `data/dialogue/temple.dialogue`) con el kit gris: 9 salas de 11 × 7 celdas (22 × 14 m, apenas más que una pantalla) con paredes compartidas y la puerta en el centro de cada pared; la sala (cx, cz) del mapa tiene su centro en (24 cx, 16 cz) m. La puerta del templo del overworld lleva al vestíbulo (spawn `start`) y la salida sur vuelve al spawn `templo`. *Vestíbulo:* bloque → interruptor (`d1_vestibule_switch`) → puerta al hub. *Hub:* dos esqueletos cierran la persiana oeste hasta vencerlos; este con llave (`d1_hub_locked_door`); norte, el sello; vasijas con munición. *Galería:* una torreta al norte; bloqueando en diagonal con el escudo espejo, el orbe entra de frente y sale hacia el ojo del noroeste (`d1_gallery_eye`), que baja la reja del nicho con la llave 1. El ojo sobre la puerta norte (`d1_ojos_door_eye`) solo se despierta con flecha. *Sala agrietada:* una pared cruza la sala con un hueco tapado por una caja liviana (masa 0.3): el player no la empuja, una bomba la vuela. Del otro lado, el mapa (`d1_map_chest`) y el muro agrietado hacia la arena (`d1_arena_cracked_wall`). Si la caja queda trabando la salida, otra bomba la saca (las vasijas dan bombas). *Arena:* `WaveSpawner` (cada hijo es una oleada; sus `WaveSpawn` dicen qué enemigo y dónde) arranca al entrar y retiene cerrada la persiana entre oleadas (`Room.waves_running`). Dos oleadas: dos esqueletos; después el esqueleto con escudo y dos esqueletos. Al ganar (`d1_arena_cleared`) baja la reja del cofre grande del arco (`d1_chest_bow`, trae 10 flechas). Morir a mitad recarga la sala y las oleadas empiezan de cero. *Sala de ojos:* un hueco (pieza Hueco del kit, sin colisión) cruza la sala; caer lastima medio corazón y devuelve a la entrada de la sala (`Pit`). Del otro lado, dos ojos que solo despiertan con flecha: el oeste (`d1_ojos_eye_a`) abre el nicho de la brújula, el este (`d1_ojos_eye_b`) sube un `Bridge` sobre el hueco; cruzando, la llave 2 y la puerta con llave al puzzle. *Sala del puzzle*, en secuencia: 1) el bloque al interruptor baja la reja que corta el haz; 2) atajando el haz con el escudo espejo se enciende el cristal, que baja la reja delante del ojo; 3) una flecha al ojo (`d1_puzzle_eye`) abre el nicho de la llave del jefe y el sello del hub. *Antesala:* cuatro vasijas de corazones, una tablilla que anticipa al jefe (cue `antechamber`: flechas y reflejo) y la puerta del jefe (`d1_boss_door`; la llave del jefe no se gasta). Checkpoint: la cámara no anota la entrada de la sala del jefe (`Room.boss_room`), así que morir ahí devuelve a la antesala. *Guarida del ojo:* sala vacía; el jefe es M9.

**Doom (10.6):** cada `Room` tiene `doom` (0..1): Vestíbulo 0, Hub 0.15, Galería 0.3, Agrietada 0.4, Arena 0.55, Ojos 0.65, Puzzle 0.75, Antesala 0.9, Jefe 1. `DoomAmbience` (un nodo en la escena del templo) lo sigue suavizado: la luz ambiente y el sol viran de frío a rojo, sube una niebla rojiza, cae polvo alrededor de la cámara, el piso se agrieta (decals generados, más cuanto más doom; el vestíbulo queda intacto) y desde 0.3 el templo tiembla cada vez más seguido (de cada ~14 s a cada ~4 s) con retumbo. La música suma capas con el mismo valor (10.5).

**Escenarios y recorrido (8.8):** `dungeon_no_bow` (en el hub, con escudo espejo y bombas), `pre_boss` (en la antesala, todo resuelto y la llave del jefe) y `boss_key_door_locked` (inconsistente a propósito: la puerta del jefe abierta sin la llave; `SaveCodec.validate` lo marca). `tests/test_temple.gd › test_full_run_from_the_entrance_to_the_boss_door` recorre de la entrada a la puerta del jefe desde un único estado inicial e imprime el tiempo por tramo (simulado, sin pelear de verdad); el recorrido real queda para la prueba a mano.

**Softlocks revisados:** *munición*: las vasijas sueltan flechas y bombas solo si se tiene el arco o la bolsa, y vuelven al recargar la escena (salir y entrar al templo); hacen falta 2 bombas y 4 flechas. *Bloques*: los que no están resueltos vuelven a su lugar al salir de la sala (el del vestíbulo, saliendo al overworld). *Caja de la sala agrietada*: si cae trabando la salida, otra bomba la saca (las vasijas de esa mitad dan bombas). *Puertas*: las persianas solo encierran al entrar a su sala y se abren al vencer; las puertas con llave se abren desde el lado por el que se llega y no hay otro camino. *Hueco*: caer devuelve a la entrada de la sala.

**Kit gris y medidas (6.7):** las salas se arman con un `GridMap` sobre `data/kits/gray_kit.tres` (lo genera `src/tools/build_gray_kit.gd` con las texturas de prototipo de Kenney): Piso, Pared, Columna, Escalón y Puerta (piso + dintel; la `Door` va en el medio de esa celda). Celdas de 2 m centradas en (2i, 2k), piso en y = 0, paredes de 2.6 m y una celda de grosor; la cámara de esas escenas usa `mask_margin` = 2 para que se vean las paredes enteras. Una sala de una pantalla tiene 7 × 5 celdas de interior (14 × 10 m); las más grandes se recorren. El bloque de empuje usa la misma grilla.

**Mazmorra gris de prueba** (`levels/dungeon_test.tscn`, id `d0`, flags `d0_*`, escenario `dungeon_test`): un mini candado-y-llave. Vestíbulo: bloque → interruptor abre la puerta oeste; la puerta norte tiene llave. Sala de guardia (dos pantallas de ancho, lateral): la persiana se cierra con dos esqueletos y el cofre del fondo tiene la llave chica. Cámara sellada: cofre grande con la brújula.

## 9. Jefe — El Ojo con manos
<!-- id: jefe -->

Modelo propio basado en el Gigante de la jam LD56: calabaza de piedra flotante con juntas de hierro, boca de horno, un ojo enorme de iris neón entre dos párpados de hierro y dos guanteletes que flotan sueltos. Sin esqueleto: son piezas separadas (`assets/epiphany/jefe.blend`, `tools/blender/build_jefe.py`) que mueve el código; las manos tienen tres poses (abierta para el golpe, puño, garra para el agarre) y en el dorso un ojo de neón que marca dónde pegar.

- **Fase 1 — Manos:** golpes y agarres telegrafiados. Bloquear o rodar. Tras un golpe al piso, la mano queda aturdida → ventana para espadazos. Aturdir ambas manos → fase 2.
- **Fase 2 — El Ojo:** el ojo se abre. **Flecha al ojo** = cae aturdido → ventana de espadazos. El ojo dispara orbes: se pueden **reflejar con el escudo espejo** como alternativa para aturdirlo. Las manos se regeneran y siguen presionando.
- **Fase 3 (si da el tiempo):** el ojo "marca" el piso antes de golpes de área; combina patrones.
- Barra de vida del jefe en el HUD.

## 10. UI
<!-- id: ui -->

*Mockups de todas las pantallas: artifact "Epiphany UI Mockups".*

Las páginas de la pausa son hijas de un `TabContainer` sin barra propia (`%Pages`); los títulos van en un `TabBar` (`%Tabs`, variación `PauseTabBar`) entre los prompts de Q/E, que también cambia de página con el mouse.

| Pantalla | Contenido |
|---|---|
| **Título** | Escena principal del juego (`src/ui/title/title_screen.tscn`, mockup Main): Continuar, Nueva partida, Opciones, Salir; en debug, "Cargar escenario" lista `debug/scenarios/`. `--scenario=` y `next_scenario.txt` se siguen respetando. Piezas reutilizables: `MenuItem` (escena sin script: el ▶ es el ícono de la variación del tema, transparente salvo con foco o hover) y `HintBar` (pistas de botones del dispositivo actual). |
| **HUD** | Corazones (¼), llaves chicas + llave del jefe (solo en mazmorra), botones de ítem X/Y con munición, indicador de acción contextual (A/B: *Abrir*, *Empujar*, *Leer*), barra del jefe, nombre de la zona al entrar. |
| **Caja de texto** | Tablillas e *item get*. El texto vive en archivos `.dialogue` de **Dialogue Manager** (Nathan Hoad); el globo es nuestra `TextBox` con los estilos de los mockups (piedra para tablillas, dorado para *item get*), no la UI del plugin. Se integró aunque no haya NPCs, para tener el sistema andando antes de que haya muchos textos (decisión del 2026-10-08, elegido sobre Dialogic por ser liviano y dejar la UI propia). |
| **Item get** | Animación con el ítem en alto + nombre + descripción corta. |
| **Pausa › Equipo** | Espada, escudo, armadura (con ranuras bloqueadas para lo no conseguido), stats, preview del modelo. |
| **Pausa › Ítems** | Grilla de ítems secundarios; asignar a X/Y; descripción; munición. |
| **Pausa › Mapa** | Mapa de la mazmorra (salas visitadas; con mapa: todas; con brújula: cofres y jefe); overworld: mapa simple. La grilla sale de `Room.map_cell`; título y piso, del nodo `Dungeon`. En el overworld, un nodo `OverworldMap` en la escena da la imagen (foto cenital ortográfica) y el rectángulo XZ que cubre. Abre directo con la acción `map`. |
| **Opciones** | Autoload `Settings` (`user://settings.cfg`, aparte de la partida; se aplica al arrancar). Mockup Options en `OptionsPanel`: fijar objetivo mantener/alternar, apuntar con el mouse, sensibilidad del stick derecho (multiplica el giro al apuntar y con el haz), cambio de objetivo con flick, vibración (la dispara `Feel.shake`), volúmenes de Música/Efectos/Ambiente (buses Music, SFX, UI, Ambience), pantalla completa, temblor de cámara y escala de la interfaz. Desde el título (pantalla propia) y desde la pausa (pestaña Sistema, con Guardar y salir al título). |
| **Game over** | `GameOver` (mockup GameOver, "CAÍSTE"): al morir, en vez del fundido automático. Continuar (desde la entrada de la sala en mazmorra, o el último punto de control en el overworld), Guardar y salir (guarda en el punto de reaparición, no donde cayó) y Salir sin guardar. Es modal: atrás y pausa no la cierran. |
| **Selección de partida** | `FileSelect` (`file_select.tscn`, mockup FileSelect): tres `SlotCard` (corazones, ubicación, ítems, tiempo jugado; la vacía ofrece Nueva partida), Copiar y Borrar como modos de la misma pantalla; reemplazar o borrar pide un `ConfirmDialog` con el foco en Cancelar. |
| **Debug (solo editor/debug)** | Overlay de valores en vivo (tecla `1`), cargar/guardar rápido (teclas `2`/`3`), pestaña Log en el debugger del editor. Ver §11.9. |

**Máquina de estados de la UI.** Toda la UI son escenas `.tscn` (nada armado por código: los scripts solo llenan datos y reaccionan; lo repetido, como ranuras, pistas o filas, es su propia escena chica; los estilos son variaciones de `src/ui/theme.tres`); `test_ui_scenes` falla si un script de `src/ui` crea Controls o StyleBoxes con `.new()`). Las pantallas extienden `UiScreen` y se abren con `MenuStack.push()`, un autómata de pila: solo la de arriba recibe input y foco; las de abajo quedan desactivadas (y ocultas, salvo que la nueva tenga `hides_below = false`, como los diálogos). Atrás llama primero a `cancel()` de la pantalla (para subestados como Copiar/Borrar) y si no, la cierra, salvo que sea `modal` (game over); pausa y mapa solo cierran las que tienen `closes_with_pause` (el menú de pausa). El título es el estado raíz (`MenuStack.set_base`): queda desactivado mientras haya algo encima y recupera el foco donde estaba.

**Audio (10.5):** buses Master / Music / SFX / UI / Ambience (los crea `Settings`; volúmenes desde Opciones). *SFX:* `Feel` toma varias muestras por evento de los packs CC0 de Kenney (`assets/audio/sfx/`, con su licencia; lista en `compass/lists/assets-de-audio`) y las varía en tono y volumen; explosión, secreto, curación y temblor siguen sintetizados. La interfaz suena sola en el bus UI (moverse, aceptar, volver, abrir y cerrar menús). *Música:* placeholder en capas (`src/tools/render_music.gd` las renderiza a `assets/audio/music/`, loops exactos de 8 s) que el autoload `Music` mezcla: calma en el overworld; en el templo, la base oscura y, según `Room.doom` de la sala, pulso (≥ 0.15), murmullo (≥ 0.45) y latido (≥ 0.7). Con un menú, *item get* o caja de texto abierta, baja 8 dB.

---

### 10.1 Dirección de arte
<!-- id: arte -->

Decidido el 2026-10-09: **KayKit + prototipo, pulido.** Personajes y armas de KayKit Adventurers; props de KayKit Dungeon Remastered (CC0, `assets/kaykit_dungeon/`: cofres, muros agrietados, antorchas); el terreno es el kit gris (`GridMap` con texturas de prototipo de Kenney, teñidas). **Ampliado el 2026-10-09 (M11):** el pack completo de KayKit Dungeon Remastered 1.0 (CC0, 203 modelos en `assets/kaykit_dungeon_remastered/`: pisos de 2 y 4 m, paredes de 4 × 4 × 1 m, arcos, estandartes, barriles, cajas, velas, escombros, mesas, pinchos) y la decoración de KayKit Medieval Hexagon 1.0 (CC0, `assets/kaykit_medieval/nature` y `props`: árboles, rocas, colinas, cajas, carpas, banderas). Bajados de los repos públicos de KayKit-Game-Assets en GitHub; licencia junto a cada pack.

**Paleta del mundo.**

| Zona | Base | Acentos |
|---|---|---|
| Overworld | Pasto verde apagado `#7aa86b`, acantilado arena `#947a61`, piso de piedra gris | Naranja de las columnas/rocas, madera de cofres |
| Templo | Piedra gris fría (luz ambiente `#8c85a6`) | Antorchas cálidas `#ffad61`; con el *doom*, todo vira a rojo `#cc4d40` con niebla `#401410` |
| Interactivos | Cofres de madera con herrajes (grandes: dorados), muros agrietados de ladrillo gris con musgo (se distinguen del acantilado), puertas de color por tipo, cristales celestes, sello violeta con el ojo | — |

**Kit del templo** (M11): `data/kits/temple_kit.tres`, que arma `tools/build_temple_kit.gd` a partir del kit gris. Los ítems, las colisiones y la navegación son los mismos; cambian las mallas KayKit. Piso: `floor_tile_small`, más cuatro variantes (rota A/B y yuyos A/B, ítems 11–14) repartidas en ~15 % de las celdas. Pared: cuatro `wall_half` estiradas a la celda de 2 × 2 m. Columna: `pillar`. Paso de puerta: con dintel. Las piedras usan `kaykit_stone.tres`, que es el shader de corte con `use_uv`, para que el muro sur se siga recortando. Para cambiar una pieza se edita el script y se vuelve a correr (`godot --headless --path . --script res://tools/build_temple_kit.gd`). El overworld sigue con el kit gris.

**Personajes** (M11): el player es el Knight de KayKit Adventurers, y los enemigos son de KayKit Skeletons 1.1 (CC0, `assets/kaykit_skeletons/`): el esqueleto común es el Minion y el de escudo, el Warrior. Todos usan el Rig_Medium, así que comparten el Skeleton3D y las librerías de animación de `player/animation/libs/`; los packs no traen animaciones nuevas. `tools/build_character_models.gd` arma una escena `Visuals` por personaje en `src/entities/models/` (mallas, piel y material; los cascos y capuchas van en BoneAttachment3D con esqueleto externo), y esa escena se instancia bajo el `ModelController`. Para otro modelo en un enemigo, `EntityConfig.model` reemplaza el `Visuals` de la escena al arrancar. Rogue y Mage están listos para cuando haya más tipos de enemigo.

**Assets propios (M12, desde el 2026-10-09).** Todo se rehace en Blender con el estilo de KayKit: low poly, una sola textura de paleta y sin texturas pintadas. **Identidad: Altiplano del Ojo** (elegida el 2026-10-09, para que no parezca un clon de Zelda): fantasía con raíces andinas. Terrazas (andenes) de piedra encastrada en vez de acantilados lisos, pircas de piedra seca en vez de cercos de madera, queñoas, cardones, matas de ichu y tola; caminos de tierra y lajas; puertas y nichos trapezoidales, escalonado de chakana y ojos tallados en el templo; metal de cobre verde. Las piezas se generan por script: `tools/blender/epi/` (primitivas low poly, pintado con la paleta) y un `build_<kit>.py` por kit (`blender -b -P tools/blender/build_<kit>.py`), que escribe `assets/epiphany/<kit>.blend`; para cambiar una pieza se edita el script y se regenera. `tools/blender/diorama.py` arma una escena chica con los kits y la renderiza con la cámara del juego, para revisarlos. `assets/epiphany/palette.png` tiene 8 × 4 franjas de 128 × 256 px, cada una un degradé de claro (arriba) a oscuro (abajo): terreno (pasto, follaje, tierra, acantilado, roca naranja, piedra, piedra del templo, musgo), materiales (madera, madera oscura, hierro, dorado, cristal, sello, doom, ladrillo), tela y vida (hueso, piel, telas roja y azul, agua, flores, fuego) y grises. Los colores se cambian en `tools/blender/epiphany_palette.py` y la textura se rehace con `blender -b -P tools/blender/make_palette.py`. Ese mismo archivo es un addon de Blender (Vista 3D › N › Epiphany, enlazado desde `~/.config/blender/5.2/scripts/addons/`): pone las caras elegidas en una franja, con degradé por altura o tono fijo, y les asigna el material `paleta`. **Medidas:** Z arriba, una celda va de −1 a 1 en X e Y con el origen al centro, el piso arriba en Z = 0 y la losa hasta −0.5; escalón hasta 0.6, cerco 0.9, pared y acantilado 2.6. El frente de las piezas mira a −Y en Blender, que en Godot es +Z, hacia la cámara. El Knight mide ≈2.5 m (chibi). Las piezas que tilean no llevan bisel en los bordes que tocan a la vecina. **Flujo:** se parte de `tools/blender/plantilla.blend` (la arma `make_template.py`: material, Knight y cajas de las alturas en la colección `referencias`, que no se renderiza) y se guarda como `.blend` en `assets/epiphany/`; Godot lo importa directo con Blender. `importer_defaults/scene` pone `blender/nodes/visible` en *Renderable*, así que las referencias no se importan, y la paleta llega como `palette.png`, sin copias. Godot headless no puede importar un `.blend` con el editor abierto (los dos usan el puerto de Blender): lo importa el editor. Kits: `terreno_overworld`, `naturaleza`, `lugares`, `objetos`, `equipo`, `templo` y `personaje_*` (jugador, chullpa y chullpa guardián, pesados con huesos rígidos al Rig_Medium de KayKit, así siguen andando las animaciones). **Integración:** `tools/extract_epiphany_meshes.gd` guarda cada pieza como `assets/epiphany/meshes/<kit>/<pieza>.res` con el material compartido `data/kits/materials/epiphany.tres` (la paleta con tinte 0.72, para que no se lave con el sol); las escenas de `src/world`, ítems, flecha, bomba y torreta usan esas mallas. Los GridMap: `tools/build_overworld_kit.gd` (`overworld_kit.tres`, mismos ids y colisiones que el kit gris más variantes desde el 11) y `tools/build_temple_kit.gd` (paredes con `epiphany_stone.tres`, el cutaway con la paleta); `tools/vary_overworld.gd` reparte en el overworld variantes de pasto, tierra, andenes, pircas y árboles con un hash de la celda y pone bordes de tierra donde el pasto toca el camino. Las puertas eligen la hoja por tipo (madera, llave, persiana, interruptor, jefe). `tools/build_character_models.gd` arma `src/entities/models/{jugador,chullpa,chullpa_guardian}.tscn`; cada armadura puede tener su paleta completa: `VARIANTS` en `epiphany_palette.py` cambia franjas enteras (con su degradé) y `make_palette.py` escribe `palette_<variante>.png` y su emisión; el `body_material` de la armadura las usa. Las franjas de `EMISSIVE` (neón y doom) brillan por `palette_emission.png`. Los íconos de ítems se renderizan de las mismas piezas (`tools/render_item_icons.gd`). Después de regenerar un `.blend`: importar (`godot --headless --path . --import`, con el editor cerrado) y correr el extractor y los builders que lo usan.

**Materiales.** Sin PBR fino: albedo + textura de prototipo en triplanar de mundo (una textura por celda de 2 m), rugosidad alta. Lo que se puede usar o romper tiene que leerse distinto del escenario: otro material (KayKit), otro color o un brillo.

**UI.** La que fijan los mockups: fondo `#0b0d10`, paneles `#151920`, bordes `#3a4250`, dorado `#d9a441` para foco y títulos, texto `#efe6d2`, secundario `#a79f8e`, peligro `#d0503a`. Títulos en Cinzel, texto en Alegreya Sans. Íconos de ítems renderizados desde sus modelos 3D (decidido el 2026-10-09): `tools/render_item_icons.gd` (con ventana, no headless) saca un PNG de 256 px con fondo transparente y contorno oscuro por ítem, en una vista de tres cuartos, a `assets/ui/items/`. Los modelos son los de KayKit (Adventurers, Dungeon Remastered) y los del propio equipo; las armaduras son el torso del Knight con su `body_material`. El mapa, la brújula y el contenedor de corazón no tienen modelo y siguen con su SVG plano. Botones con los prompts de Kenney según el dispositivo; la letra viene calada en el SVG y `InputPrompts` la rellena con el fondo `#0b0d10` al cargarla, para que no se vea lo que hay detrás. **Marcos** (decidido el 2026-10-09): los de *Fantasy UI Borders* de Kenney (CC0), teñidos con esta paleta por `tools/build_ui_frames.sh` en `assets/ui/frames/` (el pack original queda en `assets/kenney_fantasy-ui-borders/`, fuera de la importación). Marco doble dorado para la pausa, los diálogos y el *item get*; doble gris para las tarjetas; piedra para las tablillas; simple bronce `#6b5a3a` para botones, casillas y ranuras, que pasan a dorado con el foco; los sliders son la doble línea del pack (bronce, dorado lo lleno) con un rombo dorado de perilla, como los radios; casillas marcadas con un cuadrado dorado; la ranura de partida vacía es solo el borde. Un único divisor ornamentado: bajo las pestañas de la pausa y a los lados del nombre de la zona.

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
  dialogue/*.dialogue       # textos de Dialogue Manager (tablillas, item get); claves de traducción [ID:…]
  drops/*.tres              # un DropTable por fuente (skeleton, pot, grass)
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
@export var body_material: Material           ## Armaduras: material del cuerpo del player (null = el del modelo)


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

@export var ammo: ItemData                     ## null = munición infinita
@export_range(0.0, 1.0) var use_at := 0.5      ## Momento de use() en la animación, como AttackData


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

@export var projectile_scene: PackedScene
@export var speed: float = 20.0
# hold_to_aim (en ItemBehavior) = true para el arco: el estado AimingItem tensa (Ranged_Bow_Draw),
# apunta en loop (Ranged_Bow_Aiming_Idle) con el torso mientras el player strafea, y al soltar
# (Ranged_Bow_Release) llama a use(). El arco se sostiene en la mano del escudo (Equipment.hold).


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	return ammo == null or ctx.inventory.has(ammo.id)


func use(ctx: ItemUseContext, item: ItemData) -> void:
	if ammo:
		ctx.inventory.remove(ammo.id)
	var info := item.make_damage(ctx.user)
	info.team = ctx.user.config.team
	var projectile: Projectile = projectile_scene.instantiate()
	ctx.user.get_tree().current_scene.add_child(projectile)
	projectile.launch(ctx.origin, ctx.direction * speed, info)
```

```gdscript
# src/items/behaviors/consumable_behavior.gd
class_name ConsumableBehavior
extends ItemBehavior

@export var heal: int = 0                       ## HP; negativo = toda la vida
@export var leaves: ItemData                   ## Botella vacía al tomar la poción


func can_use(ctx: ItemUseContext, _item: ItemData) -> bool:
	var health: Health = ctx.user.get_node(^"Health")
	return heal == 0 or not health.is_full()


func use(ctx: ItemUseContext, item: ItemData) -> void:
	var health: Health = ctx.user.get_node(^"Health")
	health.heal(health.max_health if heal < 0 else heal)
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
@export var max_health: int = 8 ## HP (1 corazón = 4)
@export var target_height: float = 1.0 ## Dónde apunta el lock-on / indicador
@export var knockback_resistance: float = 0.0 ## 0 = recibe todo, 1 = inamovible
@export var attack_damage: int = 2 ## Daño base de sus ataques (sin arma equipada)
@export var attack_knockback: float = 6.0


func has(feature: Feature) -> bool:
	return (features & feature) != 0


func apply_to(entity: Node) -> void:
	for feature in _GROUPS:
		if has(feature):
			entity.add_to_group(_GROUPS[feature])


func make_damage(source: Node3D) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = attack_damage
	info.knockback = attack_knockback
	info.source = source
	info.team = team
	return info
```

Cada tipo de enemigo tiene su `.tres` (`data/entities/skeleton.tres`) compartido por todas sus instancias. Llamar `config.apply_to(self)` en `_ready` mantiene funcionando el `TargetDetector` actual (grupo `targetable`).

```gdscript
# src/components/damage_info.gd
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
	for hitbox in hitboxes.values():
		if hitbox:
			hitbox.set_deferred(&"monitoring", false)


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


func is_active() -> bool:
	var hitbox: Hitbox = hitboxes.get(current.hitbox) if current else null
	return hitbox != null and hitbox.active_attack != null


func _physics_process(delta: float) -> void:
	_elapsed += delta * _speed
	var t := _elapsed / _length
	_set_active(t >= current.active_from and t < current.active_to)
	if t >= 1.0:
		stop()


func _set_active(active: bool) -> void:
	var hitbox: Hitbox = hitboxes.get(current.hitbox)
	if hitbox == null or (hitbox.active_attack != null) == active:
		return
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
	shooter = info.source
	_damage = info
	_damage.source = self          # el bloqueo direccional mira de dónde viene el proyectil
	team = info.team
	damage_factory = func() -> DamageInfo: return _damage
	look_at(from + velocity)
	landed.connect(func(_h: Hurtbox) -> void: queue_free())


func reflect(direction: Vector3, new_team: EntityConfig.Team) -> void:
	velocity = direction.normalized() * velocity.length()
	team = new_team
	_damage.team = new_team


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
```

Contra el mundo (`body_entered` de estáticos; los `CharacterBody3D` se ignoran porque los resuelve su `Hurtbox`) se rompe con partículas o, si tiene `stick_time` (flechas), se clava. Velocidad tope 24 m/s: a 60 Hz son 0,4 m por paso, menos que cualquier `Hurtbox` o pared, así que no hace falta CCD. Sin pool: 30 orbes por segundo instanciados, reflejados y destruidos no pasan de 5 ms por frame.

### 11.4 Player refactorizado
<!-- id: player -->

```
Player (CharacterBody3D)            player.gd: orquesta, ya no contiene lógica de lock-on
├─ ModelController (Skeleton, AnimationTree, Hand_R, Hand_L, BackShield)
│  └─ Hitboxes/Front (Hitbox)       gira con el modelo; más con nombre si hacen falta (spin, slam)
├─ Health                           max_health <- GameState.max_health
├─ Hurtbox
├─ AttackRunner                     ventanas de golpe desde AttackData
├─ Equipment                        instancia equip_scene de GameState.equipment en los encajes
│                                   (Marker3D WeaponSocket / ShieldSocket en Hand_R, Hand_L y BackShield)
├─ Targeting                        lock-on + cambio de objetivo (sale de state_machine.gd)
├─ Aim                              dirección de apuntado unificada
├─ InteractionDetector (Area3D)     elige el Interactable más cercano de frente
└─ MovementState (LimboHSM)         Spawning, Idle, Moving, Attacking, UsingItem, Dodging,
                                    Hurt, Transition (puertas), ItemGet
```

Los modelos en la mano son `EquippedItem` (`src/items/equipped_item.gd`): solo el modelo y su `ItemData`, sin hitbox. El daño del jugador sale del arma equipada (`ItemData.make_damage`); sin arma, de su `EntityConfig`. `Targeting` sincroniza el objetivo con la variable `target` del blackboard, que leen los estados.

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
@export var map_cell: Vector2i           ## Celda en la pantalla de mapa (y crece hacia abajo)
@export var boss_room := false           ## Con brújula, el mapa marca el ojo del jefe


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

Las puertas `SHUTTER` las abre la sala (al limpiar enemigos) y las `SWITCH` sus interruptores. **Interruptores:** `FloorSwitch`, `EyeSwitch` y `LightReceiver` comparten la interfaz `active` + señales `activated`/`deactivated`. Las puertas y rejas exportan `switches: Array[NodePath]` y una condición (`ALL`/`ANY`); el helper `Wiring` los escucha y avisa cuando la condición se cumple o deja de cumplirse, así que se cablea en el editor, sin código por sala. **Modos de `FloorSwitch`:** `HOLD` (activo mientras haya algo encima), `ONCE` (queda activado con lo primero que lo pise) y `BLOCK` (el player lo activa solo mientras está parado; un bloque lo deja resuelto y guarda el flag). Se elige por puzzle; el Vestíbulo y el Puzzle del templo usan `BLOCK`, con la puerta y la reja en `stays_open = false` para que se cierren al bajarse. `Gate` también tiene `stays_open` y `close()`. **Mostrar lo activado:** `Door` y `Gate` exportan `reveal_on_open` (opcional, apagado por defecto: no conviene si el interruptor acciona algo en otra sala). La primera vez que sus interruptores los abren, `TopDownCamera.reveal()` pausa el juego, se acerca al objetivo (`reveal_zoom` 0.6 del offset, `reveal_pan_time` 0.6 s), lo abre, espera `reveal_hold` (0.9 s) y vuelve al player. No se dispara al cargar una partida (`SaveManager.loading`) ni con el juego ya en pausa. La puerta del Vestíbulo y la reja del Puzzle lo usan. **Bloques por grilla**: `AnimatableBody3D` que se mueve 1 celda con tween al empujar ≈0.3 s contra él; los `RigidBody3D` quedan para objetos físicos (bombas, rocas, enemigos livianos).

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

**Convención de nombres:** `ow_*` para el overworld y `dN_*` para la mazmorra N (`d1_chest_bow`; `d0_*` es la mazmorra gris de prueba), seguido de qué es y dónde. Todo flag vive en `data/flag_registry.tres`; `PersistentFlag` (y los objetos que exportan `flag`, como cofres y tablillas) muestran una advertencia en el editor si el flag no está registrado o no sigue la convención.

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

**Ranuras y autosave (10.2):** 3 ranuras (`SaveManager.SLOTS`, `user://saves/slot_N.cfg`). `current_slot` es la de la partida en curso: el autosave y el guardado rápido de debug van ahí. Se guarda solo al cambiar de escena, al abrir un cofre grande y al entrar a la antesala (`Room.autosave_on_enter`); el HUD muestra "Guardado". Cada partida guarda `play_time` (segundos jugados con player en escena y sin pausa) y `location` (mazmorra · sala, o la zona del overworld) para la pantalla de ranuras. Un guardado cortado a mitad se recupera del `.bak`. Selección de partida (mockup FileSelect): Continuar abre la pantalla con la ranura más reciente elegida y Nueva partida con la primera vacía; Copiar y Borrar (con confirmación, foco en Cancelar).

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
2. **Editar** en pestañas armadas desde los datos (mockup en el canvas de UI, fila "Herramientas de editor"): Partida (corazones, escena, posición), Equipo (desplegables por categoría, botones X/Y), Inventario (todos los ítems de `ItemDatabase` con contador o interruptor, buscador), Flags (todas las de `FlagRegistry`), Mazmorras (llaves, mapa, brújula, llave del jefe, grilla de salas visitadas) y Texto (el `.cfg` crudo).
3. **Validar en vivo** con `SaveCodec.validate`: píldora "Válida" / "N problemas"; lo inválido en rojo con "Quitar". Se puede guardar igual (escenarios imposibles a propósito).
4. **Guardar** la partida o **como escenario** (en `res://`, sin `.bak`).
5. **Jugar:** escribe lo que hay en el dock en `user://debug/inspector_play.cfg`, deja esa ruta en `user://debug/next_scenario.txt` y lanza la escena principal. `SaveManager` lo consume al arrancar.

Código: `addons/epiphany_tools/save_inspector/` (`save_inspector.gd` + una pestaña por script en `tabs/`).

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

### 11.x Rendimiento
<!-- id: rendimiento -->

**Presupuesto (10.8):** 60 FPS (16,6 ms por cuadro, p95) en la máquina más floja de los playtesters. `src/tools/profile_scenes.gd` (en ventana: `godot --path . --resolution 1280x720 --script res://src/tools/profile_scenes.gd`) mide las escenas más pesadas. El 2026-10-09, en la máquina de desarrollo (Radeon RX 580, 32 hilos) y build de editor: pradera con pasto y esqueletos ≈ 5 ms medio / 7 ms p95; arena con oleadas ≈ 5 / 8 ms (peor 10 ms); antesala con todo el *doom* ≈ 5 / 6 ms; 360–450 draw calls. Arreglo: las oleadas instancian un enemigo por cuadro (antes, un tirón de 26 ms al aparecer). Pendiente: medir en build release (10.9) y la pelea del jefe (M9). `Performance.TIME_PROCESS` es el cuadro entero, no solo los scripts.

### 11.x Builds
<!-- id: builds -->

**Export (10.9):** presets Linux y Windows (release: sin `debug/scenarios/` ni `tests/`, partidas cifradas) y sus variantes `(debug)` (con escenarios y `plain_saves`: partidas en texto). `tools/build.sh` exporta los dos de release (o los de debug con `--debug`) a `builds/` (ignorado por git) y anota la versión de git. Antes de correrlo hacen falta las plantillas de export de Godot 4.8-dev7 y las bibliotecas `template_release` de LimboAI (Linux y Windows); el script avisa si falta algo. La clave de guardado (`SaveCodec._PASS`) ya no es la de ejemplo; cambiarla invalida los checksums, así que los escenarios se volvieron a firmar.

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
- [x] Layout exacto de la mazmorra (§8.1) y del overworld (§7.1).
- [x] Ranuras de guardado: 3 (decidido el 2026-10-09).
- [x] Arte: KayKit + texturas de prototipo, pulido con paleta propia (decidido el 2026-10-09, §10.1).
- [ ] Rig del jefe: importarlo al repo y verificar compatibilidad con el AnimationTree actual.
