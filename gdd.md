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

**Tablillas (11.22):** cuentan la opción A en orden suelto; cada una tiene su flag de leída (`ow_tablet_*`, `d1_tablet_*`). Textos en `data/dialogue/overworld.dialogue` y `temple.dialogue`.

| Dónde | Cue | Qué cuenta |
|---|---|---|
| Claro del inicio | `start_temple` | Los antiguos levantaron el templo al norte; si la tierra tiembla, ir hacia él (objetivo) |
| Pradera | `meadow_two_suns` | El cielo tenía dos soles; uno bajó a mirarnos: el Ojo, que seca lo que mira |
| Santuario | `shrine_mirror` | No pudieron cerrarle el párpado: le devolvieron su luz con un espejo y se durmió mirándose |
| Arboleda | `grove_last` | Cada generación renovaba el sello; los que escribieron fueron los últimos |
| Risco del ojo | `cliff_heart` | **Pista:** el corazón partido en cuatro y dónde están las piezas |
| Cueva | `cave_bombs` | Cómo usar las bombas |
| Gruta | `grotto_hint` | **Pista:** el ojo de piedra del risco despierta con lo que vuela |
| Vestíbulo | `temple_entrance` | El templo no guarda a un dios sino una puerta cerrada |
| Hub | `hub_promise` | El sello es una promesa: mientras alguien vuelva, el Ojo duerme; hace mucho que nadie vuelve |
| Sala de ojos | `eyes_servants` | **Pista:** sus ojos menores se ciegan desde lejos (flechas) |
| Antesala | `antechamber` | El guardián: lo que vuela lo hace parpadear, lo que brilla se le devuelve |

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

**Cámara por sala (6.1, corregida el 2026-10-08), como el remake de Link's Awakening:** la cámara sigue siempre al player y se frena recién cuando el borde de la pantalla llega a la pared: el ancho se mide en la fila del player, abajo hasta el piso sur y arriba hasta el tope de la pared norte (`wall_height`). Si la sala es más chica que la pantalla en un eje, queda fija y centrada en pantalla. Todo lo de fuera de la sala actual queda en negro (una máscara a la altura de las paredes, `mask_margin` afuera para no tapar las paredes), así nunca se ve qué hay detrás de las puertas; durante el deslizamiento la máscara abarca las dos salas. La cámara usa FOV 40 y `offset` (0, 17.4, 10.0) en todo el juego, overworld incluido (alejada el 2026-10-09): una pantalla abarca ≈ 26 × 14.5 m en la fila del player, así que una sala del templo (22 × 14 m) se ve entera, con las puertas laterales y la sur, y queda fija. **Pared sur recortada:** las paredes y columnas del kit usan `data/kits/shaders/cutaway.gdshader`; al entrar a una sala la cámara le pasa el rectángulo de su pared sur y todo lo que está ahí por encima de `south_wall_cut` (0.4 m) se descarta; el rectángulo empieza `SOUTH_WALL_RELIEF` (0.3 m) dentro de la sala, porque los ladrillos de la pared del templo sobresalen de su celda (sin ese margen quedaba una lámina de ladrillos a toda altura, sin colisión, tapando la puerta sur). Lo que queda se pinta de un oscuro plano (emisión, sin luz), como un zócalo, así la puerta sur se ve de frente. Las colisiones no cambian. **Silueta del player (11.8):** donde algo tapa al player (el jefe, un dintel, la máscara de fuera de la sala), se dibuja su silueta dorada estilo x-ray (11.38): fresnel, brilla en los bordes y en el centro queda al 25 %, así se leen los brazos y el arma encimados. La pasada del destello de daño (`hit_flash.gdshader`, que ya cubre todas sus mallas) marca el stencil donde el player se ve; una pasada más, `src/feel/occluded_silhouette.gdshader`, con `render_priority` uno más alto (así va después del destello de todas las mallas), se dibuja sin prueba de profundidad solo donde el stencil no está marcado. La vista previa del equipo copia el modelo sin overlays. **Agujero en las paredes (11.40):** contra paredes, en vez de la silueta, se recorta un círculo (radio 1,4 m, borde con dither) alrededor del player en lo que esté más cerca de la cámara que él y por encima de sus pies + 0,3 m (el piso y el zócalo quedan). `TopDownCamera` pasa sus pies en la uniform global `player_hole` (w = 1 si hay player); el código vive en `data/kits/shaders/player_hole.gdshaderinc` y lo usan `cutaway.gdshader` (paredes y columnas del templo) y `epiphany_wall.gdshader` (`epiphany_wall.tres`: la paleta con el agujero, para Pared, Acantilado y Risco del overworld). En el borde del mundo el agujero mostraría el vacío: el kit tiene variantes "borde" sin agujero y `OverworldMap` cambia a ellas, al cargar, las paredes sin nada del lado de la cámara (al sur); ahí queda la silueta. Contra objetos (el jefe, bloques, árboles), la silueta. **Luces Wind Waker (11.39):** `StencilLight` (`src/feel/stencil_light/`) aclara con borde duro todo lo que queda dentro de una esfera, sin luz real: la cara de adelante marca en el stencil (ref 2) lo que está delante, la de atrás multiplica el color donde la escena queda dentro, y una última pasada limpia el stencil. Cada luz toma tres prioridades propias entre −127 y −1, así sus pasadas no se mezclan y todas terminan antes que el destello y la silueta del player. Técnica tomada de apples/godot-stencil-demo (sin copiar código: el repo no tiene licencia). Las antorchas del templo tienen una (`Glow`, radio 3 m, corrida 1,2 m hacia la sala para que el charco se vea en el piso) que titila con la antorcha; la `OmniLight3D` sigue para el sombreado. Así el cuerpo no se tapa a sí mismo. Es por player (va en su `HitFlash`): los enemigos no tienen silueta.

### 4.2 Movimiento y combate
<!-- id: movimiento-combate -->

- Movimiento libre analógico (8+ direcciones), rotación suave del modelo.
- **Lock-on (Z-target)**: mantener o alternar (configurable, ya implementado). Con objetivo fijado el player strafea y la cámara encuadra a ambos.
- **Cambio de objetivo**: con objetivo fijado, el stick derecho **apunta**: pasado 0.7 (`look_*`), se fija el candidato que está en esa dirección desde el player (cono de ±60°; en empate, el más cercano), sin importar cuál estaba fijado. Barrer el stick va cambiando de objetivo; solo cambia si el nuevo está claramente mejor alineado (`point_hysteresis`). Candidatos: en pantalla, en rango y a la vista (las paredes tapan, los enemigos no). La rueda del mouse salta al vecino de la izquierda o la derecha; sin vecino no pasa nada, salvo con `Targeting.wrap_around` (apagado, a decidir jugando). El rango es el radio del cilindro de `TargetDetector` (6 m), la única fuente: se edita en el editor y `Targeting.targeting_range` lo lee. Un objetivo que muere o sale de rango se suelta tras 0,5 s; en modo alternar salta al siguiente. Teclado y mouse: a definir (§4.3).
- **Apuntado libre**: stick izquierdo mientras se tensa o se sostiene la bomba, o mouse (rayo cámara → plano del suelo). Lo consumen arco, bombas lanzadas y cualquier ítem a distancia.
- **Salto**: no hay salto libre. Se salta con un ítem tipo **Pluma de Roc** (Minish Cap), que se usa desde la pantalla de Ítems como cualquier otro: arco fijo, sombra en el piso para leer dónde cae, esquiva golpes bajos y permite golpes en el aire. Abre gating propio (huecos de un tile, andenes bajos); nunca pasa pircas ni muros de sala. Dónde se consigue: a decidir (tarea 11.35). **Hecho (11.35):** ítem `feather` ("Pluma", `JumpBehavior`), asignable a X/Y; el botón entra al estado `Jumping` del player (sin pasar por UsingItem). Arco fijo: `height` 0,68 m (llega a ≈0,71), `speed` 4 m/s con el stick a fondo y `air_control` bajo; ≈0,75 s en el aire, cruza ≈3 m. Por encima de un escalón (0,6) y de la onda del golpe de las manos (hasta 0,55), por debajo de lo que dejaría apoyar la cápsula en una pirca (su fondo redondeado toma como piso una esquina hasta ≈0,15 m sobre los pies: con más de 0,75 quedaría parado en el borde de una pirca de 0,9). Sombra: `%JumpShadow` (Decal en player.tscn) en el piso de donde saltó, se achica al subir. Animación `MovementBasic/Jump_Full_Short` por el OneShot de ítems. La onda de las manos es un `Hitbox` con `ground_only`: no le pega a quien está en el aire. `test_jump` cubre el salto, el hueco de 2 m, la pirca, el escalón y la onda. El golpe en el aire queda para 11.34.

### 4.3 Mapa de input
<!-- id: input -->

| Acción (`InputMap`) | Gamepad (Xbox · índice en Godot) | Teclado y mouse | Uso |
|---|---|---|---|
| `move_*` | Stick izquierdo | WASD | Moverse. Al tensar el arco, apuntar |
| `attack` | A · botón 0 | Click izquierdo | Espada |
| `interact` | B · botón 1 | E | Abrir, leer, empujar (acción contextual) |
| `dodge` | RB · botón 10 | Espacio | Rodar. En gamepad queda al lado de la guardia: cubrirse y esquivar con el mismo dedo |
| `item_1` / `item_2` | X · botón 2 / Y · botón 3 | Q / R | Ítems asignados. Los que se mantienen (arco): sin objetivo fijado, mientras se tensa el player se planta y **el stick izquierdo apunta** (como Ocarina of Time), porque el pulgar derecho no puede mantener X/Y y mover el stick derecho a la vez. Con objetivo fijado la flecha va al objetivo y el stick izquierdo camina en strafe. Con teclado y mouse apunta el mouse |
| `block` | RT · eje 5 | Click derecho | Guardia |
| `z-lock` | LT · eje 4 | Shift izquierdo | Fijar objetivo |
| `look_left` / `look_right` / `look_up` / `look_down` | Stick derecho · ejes 2 y 3 | — | Sin objetivo fijado: **mirar**, corre la cámara hasta `TopDownCamera.look_distance` (5 m) para estudiar la zona y los puzzles; al soltar vuelve. Con objetivo fijado: cambiar de objetivo cuando cruza 0.7. Cubriéndose con el escudo espejo mientras ataja un haz: gira al player para dirigir el reflejo (la cámara no se mueve). No apunta ítems: el mouse apunta solo si se movió después del último uso del gamepad (`Aim.mouse_aims`) |
| `target_prev` / `target_next` | — (el stick derecho) | Rueda arriba / abajo | Cambiar de objetivo con teclado y mouse |
| `pause` | Start · botón 6 | Tab o Esc | Menú de pausa (inventario) |
| `map` | Back · botón 4 | M | Mapa |
| `ui_tab_left` / `ui_tab_right` | LB · botón 9 / RB · botón 10 | Q / E | Pestañas de los menús. Prefijo `ui_` porque son de otro contexto: con el juego pausado no chocan con `dodge`, `item_1` ni `interact` |
| `debug_overlay` / `debug_quickload` / `debug_quicksave` / `debug_toon` | — | 1 / 2 / 3 / 4 | Solo en debug. Provisorias: el teclado de desarrollo no tiene teclas F. `debug_toon` alterna el cel shading (12.13) |

Las teclas se mapean por posición física (`physical_keycode`): WASD queda en el mismo lugar en cualquier distribución. El autoload `InputDevice` avisa con `input_device_changed` cuando el jugador pasa de gamepad a teclado/mouse o al revés. El remapeo es post-MVP.

## 5. Combate
<!-- id: combate -->

- **Vida:** corazones; **1 corazón = 4 HP** (permite daño de ¼). Inicio: 3 corazones. El HUD dibuja cuartos.
- **Recibir daño:** retroceso + ≈0.8 s de invulnerabilidad con parpadeo. Al llegar a 0: game over → continuar desde la entrada de la sala / último punto de reaparición.
- **Espada:** combo corto (hoy: slash). Stab cargado / spin attack: post-MVP.
- **Escudo:** mientras se bloquea, el golpe se anula si viene **de frente** (cono de ±60°). Con escudo espejo, los proyectiles bloqueados se reflejan hacia donde mira el player (o hacia el objetivo fijado).
- **Qué frena cada escudo** (`ItemData.protects_against`, contra `DamageInfo.element`; vacío = `physical`): la madera frena daño físico (espadas, flechas, orbes) pero no explosiones ni fuego, que pasan aunque se bloquee de frente. El espejo frena lo físico y **refleja siempre** los proyectiles reflejables que intercepta.
- **Retroceso al bloquear (Daniel, 2026-10-13):** un golpe cuerpo a cuerpo bloqueado corta el ataque del enemigo, lo empuja un poco y lo deja quieto 0,45 s (`Shield.block_recoil`, `Enemy.recoil`), sin el aturdimiento largo del árbol. Abre una ventana para pegarle aunque tenga escudo, sin buscarle la espalda ni medir su ataque. Los proyectiles bloqueados no lo provocan.
- **Escudo en la espalda:** sin bloquear, frena los proyectiles que llegan por detrás (cono de ±45°, `back_shield_angle_deg`) si son de un tipo que protege; el espejo los devuelve a quien los tiró. Los golpes cuerpo a cuerpo por la espalda no se frenan.
- **Golpe de escudo:** atacar mientras se bloquea (ya existe, `ShieldThrust`): aturde / empuja.
- **Esquiva (roll):** i-frames cortos, usa las animaciones `Dodge_*` de KayKit.
- **Respuesta del golpe** (`AttackData`, estado `Attacking`): al arrancar gira hacia el objetivo fijado o hacia el stick y da un paso (`lunge`, se frena con `lunge_damping` = 12). Desde `cancel_from` se corta con otro golpe (vuelve a entrar en `Attacking`), rodar, cubrirse o moverse; el InputBuffer (0,15 s) guarda lo que se apretó antes. Espada (`sword_slash.tres`, animación de 1 s): hitbox 0,22–0,45, `cancel_from` 0,55, `lunge` 3,5 m/s. Golpe de escudo: `cancel_from` 0,6, `lunge` 2.
- **Fantasmas al esquivar (11.112):** como el dash de Mega Man Zero, el roll deja cada 0,06 s una copia congelada de la pose (`DodgeGhosts` en el player: `bake_mesh_from_current_skeleton_pose` de cada malla del modelo, juntadas en una) con `src/feel/afterimage.tscn`, que se desvanece en 0,3 s (`ghost.gdshader`: color translúcido con borde claro; `data/materials/dodge_ghost.tres`). Intervalo, duración y color se ajustan en la escena.
- **Impacto** (`data/feel.tres`): hit-stop 0,06 s al pegar y 0,08 al recibir; sacudida 0,25 / 0,5 / 0,15 (pegar / recibir / bloquear); flash blanco 0,12 s; chispas en el golpe (`sparks_on_hit`). **Superficie (11.33):** cada `Hurtbox` dice qué toca la espada (`surface`): carne (esqueletos, chullpas, ojo del jefe; golpe seco), metal (manos del jefe; coraza o escudo de un enemigo cuando frena el golpe; chapa), piedra (torretas, ojos-interruptor, muro agrietado; picada) o nada (pasto y vasijas: suenan ellos, sin hit-stop ni sacudida). Sonidos `hit_<superficie>` en `Feel` (Kenney Impact Sounds).
- **VFX de combate** (11.49): la espada deja una estela celeste mientras la hitbox está activa (`AttackData.trail`; un `Trail3D` de Godot 4.8 colgado de la mano, ajustado a la hoja con las mallas del arma); las flechas, una estela blanca fina (`Trail3D` en billboard) que se apaga al clavarse. Todas las partículas salen de `Feel.burst` (`sparks`, `dust`, `shards`, `leaves`, `explosion`): octaedros low poly sin sombreado, con colores de la paleta, que se achican al morir; una plantilla por tipo que se duplica. La explosión suma un anillo a ras del piso. El anillo de carga queda para el spin attack (post-MVP).
- **Enemigos legibles:** durante el aviso (`BTAttack.windup_time`, 0,45 s) el enemigo se tiñe de rojo cada vez más (`HitFlash.warn`, `warn_color` / `warn_strength` 0,6 en feel.tres) y después del golpe queda quieto `recovery_time` (0,4 s): la ventana para contraatacar. Golpearlo durante el aviso lo interrumpe.
- **Enemigos (MVP):** 3 arquetipos + jefe:
  - *Esqueleto* — melee básico, enseña bloqueo.
  - *Esqueleto con escudo* — bloquea de frente; obliga a flanquear, usar bombas o golpe de escudo. (`src/entities/shield_skeleton.tscn`: `EntityConfig.guards_front` frena golpes y proyectiles dentro de `guard_angle_deg`, las explosiones pasan; un golpe que aturde, como el golpe de escudo, le baja la guardia `guard_break_time`; `turn_speed` lo hace girar lento, así se le puede rodar a la espalda. El escudo se ve levantado delante (nodo `GuardPose` con `PoseOverlay`, un SkeletonModifier3D que pone el brazo izquierdo de `Melee_Blocking` encima de la animación) y solo frena mientras está arriba: al atacar lo baja, y ese golpe entra de frente. Al bloquear retrocede un poco.)
  - *Torreta / ojo menor* — dispara orbes reflejables.
  - *Esqueleto arquero* (11.25) — mantiene distancia y tira flechas; se bloquean con el escudo y el espejo las devuelve. (`src/entities/archer_skeleton.tscn`, árbol `archer_bt.tres`: si el player se acerca a menos de 3,5 m retrocede (`BTKeepAway`); a rango (`attack_range` 9 m) tensa 1 s con el aviso rojo y el arco tensándose (`BTShootArrow`, mismo `BowModel` que el player), tira una flecha a 13 m/s y se queda quieto 0,7 s. Poca vida (6): se lo castiga cerrando distancia.)
  - *Esqueleto acorazado* (11.25) — solo con bombas: la coraza hace rebotar espada y flechas con chispas, de frente y de espalda. La primera explosión se la vuela (la pieza sale despedida y desaparece), lo aturde y desde ahí recibe daño normal. (`src/entities/armored_skeleton.tscn`: `EntityConfig.armored` y el nodo `Armor` pegado al hueso `chest`; `Enemy.is_armored`. Más vida (10) y resistente al empuje.)
- **Cuerpos (11.58):** al terminar de morir el enemigo suelta su drop y queda en el piso `corpse_time` (4 s); después se hunde `sink_depth` (0,9 m) en `sink_time` (1 s) con una nube de polvo y se libera. Las salas y las oleadas ya cuentan los vivos (`is_dead`), así que no cambia cuándo se abren.
- **Dónde hay enemigos (11.6):** overworld — pradera 3 esqueletos; gruta 2; cueva 1 + 1 acorazado entre el cofre de las bombas y el muro de práctica; explanada del templo 1 + 1 con escudo + 1 arquero; risco 1 + 1 con escudo + 1 arquero; arboleda 1; el inicio queda tranquilo. Templo — hub 2 (cierran la persiana), galería 1 junto a la torreta, sala agrietada 1 con escudo (ahí hay bombas para romperle la guardia), sala de ojos 1 del lado de la entrada (un golpe lo puede tirar al hueco), arena por oleadas. `test_enemies_do_not_spawn_inside_walls` revisa que ninguno quede encimado con la grilla.

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
| Bolsa de bombas + bombas | Ítems | Tocar: colocar; mantener: levantar, apuntar y tirar | Overworld: cueva | Muros agrietados, daño en área, empujar objetos físicos |
| Botella (+ poción) | Ítems | Consumible | Overworld: secreto opcional | Cura; deja la botella vacía |
| Agua bendita | Ítems | Consumible (en botella) | Overworld: vertiente de la gruta, se rellena siempre | 20 s de bendición: el daño entra a la mitad; deja la botella vacía |
| **Arco + flechas** | Ítems | Proyectil | **Mazmorra (ítem de la mazmorra)** | Interruptores de ojo lejanos, punto débil del jefe |
| **Sandalias** | Ítems | Mantener: tomar impulso y correr recto hasta soltar o chocar (como las botas de Pegaso); chocar sacude árboles y muros agrietados | Overworld: mini quest en la Necrópolis, que pide el arco | Con la pluma en plena carrera, salto largo: cruza huecos de 3 celdas (6 m) contra 1 celda (2 m) de la pluma sola (Daniel); islotes de la Laguna y angostura |
| **Gancho** | Ítems | Dispara una cadena recta de 10 m (5 baldosas: un cruce que pide el gancho mide 4 celdas, una más de lo que cruza el salto largo, y el poste va en la celda siguiente). En un poste (`HookPost`) o un cofre se clava y lleva al player a 14 m/s sin gravedad, por encima de agua y huecos; a un poste llega siempre al lado, sobre piso. Con el gancho en un botón, los postes a su alcance (10 m en 3D) se fijan como objetivo aunque estén más arriba o más abajo: la cadena va derecho al poste fijado y el player sube o baja a su piso, al lado del poste (el borde del desnivel no lo frena; el poste va al filo, a la vista desde abajo). Solo los postes se fijan así. Trae vasijas (se rompen a los pies), rocas y recolectables; la vasija grande viene de a una celda. Golpea con el elemento `hook`: 1 de daño y aturde 1,2 s, baja el escudo y arranca la coraza sin dañar. Contra paredes rebota | **D3, Santuario de Totora** (isla de la Laguna), guardado por el sub-jefe Amaru | Postes de la Quebrada hacia la Cumbre (D4), franja del Risco, segunda mitad de D3, ala del gancho del templo, desarmar acorazados |
| Carcaj grande | Mejora | Pasivo (+max flechas) | Overworld, **post-mazmorra** (requiere arco) | Muestra el backtracking |
| Llaves chicas, llave del jefe, mapa, brújula | Mazmorra | — | Mazmorra | Estructura de mazmorra |
| Contenedor de corazón | Mejora | +1 corazón | Tras el jefe | Recompensa |
| Pieza de corazón (×4) | Mejora | 4 piezas = +1 corazón | Overworld: arriba de un escalón de la pradera (con la pluma), fondo de la gruta (bombas), rincón del santuario (bombas), junto al cofre del carcaj (post-mazmorra) | Premia explorar |

**Piezas de corazón (11.21):** `GameState.give` las guarda en el inventario (se guardan con la partida) y cada 4 suma un corazón y descuenta las 4. En el mundo son `HeartPiece` (`src/world/heart_piece.tscn`, un `Pickup` con item get y un flag `ow_heart_piece_*` para no volver). El item get dice cuántas lleva (cues `heart_piece_1..3` de `item_get.dialogue`) y la que completa el corazón usa `heart_piece_full` con el ícono del contenedor. La pantalla de Equipo muestra "Piezas de corazón" con un corazón en cuartos (`HeartPieceIcon`) y "n / 4".

**Recolectables** (vasijas, pasto, enemigos): corazón, flechas ×5, bombas ×3. No hay moneda.

**Un ítem por mazmorra (11.90, decidido el 2026-10-12; orden de D1 y D2 cambiado el 2026-10-13):** D1 pluma (la Chullpa; salto, §4.2), D2 arco (la Queñoa Vigía), D3 gancho (11.30), D4 escudo espejo; el templo del ojo es la última. La pluma va primero porque es mejor para el gameplay como primer ítem de mazmorra (Daniel). El disco solar (un haz de luz que se apunta como el arco) queda como ítem opcional, en una mini-mazmorra o escondido en el overworld. La armadura del esqueleto acorazado se quita con el gancho o con la bomba. Documento de diseño: https://claude.ai/code/artifact/4fce85f9-7f11-4285-9d2e-bb1d58b45b4e

**Post-MVP:** espada con elemento (fuego/rayo), spin attack.

### 6.2 Progresión (gating)
<!-- id: progresion-gating -->

```
Inicio (espada + escudo de madera)
  └─ Pradera: enemigos, pasto, tablilla
      └─ Cueva ──► BOMBAS
          └─ CHULLPA (D1, Cerros) ──► sub-jefe ──► PLUMA ──► segunda mitad con la pluma ──► JEFE
              └─ Abismo de la cornisa del claro, pieza de la pradera (pluma) ──► QUEÑOA VIGÍA (D2, Arboleda) ──► sub-jefe ──► ARCO ──► JEFE
                  └─ Flecha al ojo del puente de la quebrada ──► Necrópolis ──► mini quest (arco) ──► SANDALIAS
                      └─ Dash + pluma: islotes de la Laguna ──► D3 ──► GANCHO; angostura (atajo Arboleda ↔ Cardonal)
                          └─ Postes ──► Cumbre ──► D4 ──► ESCUDO ESPEJO
                              └─ Sello del templo (reflejar haz de luz) ──► TEMPLO DEL OJO (última) ──► EL OJO CON MANOS
Opcionales: secretos de bombas, flechas y poción (muros agrietados), cota reforzada (puzzle de bloques), carcaj grande (arco), contenedor del santuario (escudo espejo), disco solar (por ubicar)
```

**Sandalias y salto largo (2026-10-13, Daniel):** con la pluma de D1, los islotes de la Laguna llevaban a D3 sin el arco, y la angostura abría el este sin el puente. Ahora los dos pasos piden el salto largo: dash de las sandalias + pluma. Daniel fijó las distancias: la pluma sola cruza una celda (2 m) y con las sandalias tres (6 m), así que la angostura y los dos huecos de los islotes (muelle → islote → isla de D3) miden tres celdas. Las sandalias se ganan en una mini quest de la Necrópolis, del otro lado del puente, que usa el arco: en el corral de pirca hay tres chullpas (`NecroTomb1..3`, `src/world/chullpa_tumba.tscn`, provisorias), cada una con un ojo que se apaga a los 8 s; con los tres prendidos a la vez aparece el cofre grande (`SandalsChest`, flag `ow_sandals_chest`). Test: `test_the_three_chullpa_eyes_raise_the_sandals_chest`. El abismo del Risco pasa a cuatro celdas (8 m) y el ojo se corre al norte: ni el salto largo lo cruza, así el carcaj sigue pidiendo flechas.

Es el orden decidido en 11.90 y cambiado en 11.113 (2026-10-12, Daniel): el templo del ojo pasa a ser la última mazmorra, porque su jefe se pensó como final, y se amplía para que use todos los ítems. El escudo espejo es el ítem de D4 y abre el sello; el templo se ve desde el principio en la Explanada con el sello cerrado. Los guantes de fuerza quedan fuera. El santuario ya no da el escudo espejo. El 2026-10-13 se invirtieron D1 y D2: la Chullpa (pluma) es la primera y la Queñoa (arco) la segunda; ninguna de las dos pedía el ítem de la otra. El santuario da un contenedor de corazón después de D4; la Chullpa está en los Cerros y a la Arboleda se entra con la pluma (7.10).

**Ítem y sub-jefe (11.113):** el ítem de cada mazmorra lo guarda un sub-jefe basado en el jefe de esa mazmorra, que se vence sin ese ítem (con los anteriores, sí). La segunda mitad de la mazmorra se resuelve con el ítem, y los ítems de mazmorras anteriores se combinan con él para abrirla. Por ejemplo, en la Queñoa (D2) la segunda mitad combina el arco con los saltos de la pluma.

**Molde de cada mazmorra (11.90):** prueba en el overworld → mazmorra con una mecánica que la recorre entera → ítem a mitad, guardado por un sub-jefe → el jefe se vence con ese ítem → el ítem abre la zona siguiente del overworld y 2–3 secretos en zonas ya visitadas. Cada mazmorra se diseña primero como grafo llave-cerradura (`DungeonGraph` en `data/dungeons/`: zonas, pasos y qué pide cada lugar), y `test_dungeon_reach` lo cruza con la escena (tipo de puerta, interruptores de cada reja, contenido de los cofres, que no falte ninguna puerta, reja, cofre o interruptor) y recorre todos los órdenes de juego: falla si algo pide un ítem que nadie da o si hay un estado desde el que ya no se llega al objetivo, y muestra el camino hasta ahí. Un grafo sin escena es de diseño: las cerraduras (`locked`, `needs`) y lo que da cada lugar (`gives`, `key`) se declaran en él y se prueba antes de construir; con escena, la escena tiene que coincidir. El test también revisa el molde: sin el ítem (`item`) no se llega al objetivo, y el ítem pide vencer al sub-jefe (`guard`), que se vence sin él. `tools/dungeon_graph_mermaid.gd -- <grafo>` lo dibuja como diagrama Mermaid. La Chullpa (`chullpa_graph.tres`), la Queñoa (`quenoa_graph.tres`) y el templo (`temple_graph.tres`) tienen el suyo. Cada mazmorra tiene un prefijo propio para su id y sus flags, que no depende de su número: `ch_` la Chullpa, `qv_` la Queñoa, `d1_` el templo (de cuando era D1).

**Alcance por entregas:** el primer playtest externo lleva D1 y D2. D3, D4 y el templo se ven en el overworld pero están cerrados y llegan después como actualización (sirve para probar un sistema de parches).

Regla: un ítem que se consigue en una mazmorra no desbloquea nada nuevo en las mazmorras anteriores. Por ejemplo, si la pluma saliera de la segunda mazmorra, la primera no tendría ningún cofre que pida la pluma. Lo que el ítem abre está en su propia mazmorra, en las siguientes o en el overworld. El overworld funciona como un hub: cada ítem nuevo de una mazmorra o una cueva debería abrir ahí cosas o caminos nuevos.

## 7. Overworld (MVP)
<!-- id: overworld -->

Un hub de unas 31 "pantallas" de tamaño Link's Awakening (24 × 16 m), sin transiciones de sala: cámara de seguimiento libre. Lleva a cuatro mazmorras, y cada ítem nuevo abre algo afuera (§6.2). Objetos físicos (cajas, rocas) para mecánicas de empuje y explosión.

### 7.1 Layout
<!-- id: overworld-layout -->

**Forma Zelda 2D (7.10, 2026-10-12/13; donde contradice lo de abajo, manda esto):** 100 × 48 celdas (200 × 96 m) con terreno continuo, generado por `debug/tmp/ow2/layout.py` (celda (x, y) → mundo (2(x − 50), nivel · 2,6, 2(y − 24))). Terrazas reales de 2,6 m (niveles 0, 1 y 2): se sube por escalinatas y se baja por saltos. Cadena: **D1 Chullpa** en los Cerros (espada y bombas; da la pluma) → **D2 Queñoa** en la Arboleda, que se alcanza cruzando con la pluma un abismo de una celda (da el arco) → D3 (gancho) → D4 (escudo espejo) → el templo, último. Gruta, Santuario y Cueva de las bombas son cuevas interiores; afuera solo se ve la boca o la grieta en la cara del risco.
- *Santuario:* queda para después de D4. El bloque al interruptor (`ow_shrine_switch`) abre el atajo al andén del templo; el cristal (`ow_shrine_crystal`), que solo prende el escudo espejo, baja la reja del cofre con un contenedor de corazón (`ow_shrine_chest`). Entrando por el atajo se queda del lado de afuera de su reja, y por dentro la salida a la Explanada tiene el mismo muro agrietado que afuera (`EntranceCrackedWall`, mismo flag `ow_shrine_cracked_wall`): romper uno deja roto el otro.
- *Risco:* una escalinata sube a la cornisa (nivel 2). Frente a ella hay un abismo de 8 m (cuatro celdas, `RiscoPit`), más de lo que cruza el salto largo. Del otro lado, el ojo (`CliffEye`) abre con una flecha el nicho con el carcaj grande. La pieza de corazón (`HeartPieceCliff`) está del lado del ojo: se sube desde el pasillo bajo con el gancho, apuntando al poste del borde (`RiscoPost`).
- *Piezas de corazón:*
  - Pradera: sobre un escalón de 0,6 m (`MeadowStep`), con la pluma.
  - Risco.
  - Islotes de la Laguna: `HeartPieceIslet`.
  - Cerros: detrás de un muro agrietado.
  - Pradera: la queñoa que se sacude con las sandalias (ver abajo).
- *Secretos:* muescas en la cara de un risco tapadas por un muro agrietado, con un cofre atrás. No hay rupias en el juego, así que los cofres traen esto:
  - Cumbre: 5 bombas.
  - Quebrada: 10 flechas.
  - Mirador: una poción con su botella.
  - Cardonal: 5 bombas.
- *Secretos chicos (11.24):* cada uno con otra herramienta.
  - Claro: una mata más grande tapa un hoyo con escalera (`BushCaveBush`); cortada, baja a `levels/bush_cave.tscn` con un cofre de 10 bombas (`ow_secret_bush_chest`).
  - Cerros: una roca empujable (`SecretRockBlock`) tapa un nicho de una celda; corrida a un costado deja el cofre de 10 flechas (`ow_secret_rock_chest`). No guarda dónde quedó: al volver está otra vez en su lugar.
  - Quebrada: una repisa a una celda de la orilla oeste, con la pluma, con 10 flechas (`ow_secret_ledge_chest`).
  - Pradera: una queñoa sola (`SecretTree`) que ningún golpe voltea; el choque de las sandalias la sacude y cae una pieza de corazón (`HeartPieceTree`, `ow_heart_piece_tree`).
- *Atajo de la Cumbre (11.28):* una escalera de soga (`CumbreLadder`, `src/world/rope_ladder.tscn`) enrollada en el borde oeste de la Cumbre (7.6, -33). Se descuelga desde arriba (`ow_cumbre_ladder`) y desde entonces se sube y se baja entre la Cumbre y la orilla que lleva por el norte de la Quebrada a la Explanada, sin el gancho.
- *Después del jefe final (11.29):* `AfterTheEye` aplica `te_boss_defeated` al entrar, al vencerlo y al cargar: el sol pasa a luz de amanecer (`dawn_color`, `dawn_energy`), se apaga el brillo rojo del ojo de la fachada (`TempleEyeGlow`), paran los temblores del templo y se abre la reja (`SummitGate`) de una escalinata de la Explanada a la cima de la montaña del templo, con una pieza de corazón (`HeartPieceSummit`, `ow_heart_piece_summit`).

**Rediseño (7.9), decidido el 2026-10-11:** variante D, *la mezcla*, de la propuesta https://claude.ai/artifact/8N6Sst4jMsTDTgKLWdqm4B. Toma la referencia del análisis del Light World de *A Link to the Past* (*Overworld Overload*, partes 1 y 2):
- regiones núcleo con una mazmorra o un ítem importante, unidas por zonas de conexión que también tienen secretos y peleas;
- paredes de terreno irregulares (riscos, andenes, agua, bosque) en vez de rectángulos de grilla;
- puertas de ítem de dos clases: unas abren una región nueva y otras solo acortan un camino;
- casi todo se puede pisar;
- cada mazmorra se ve antes de poder entrar.

7 × 5 pantallas (168 × 80 m). Una quebrada (abismo) corre de norte a sur y parte el mapa en dos actos. El **oeste** es el primer acto y tiene lo que ya existía. El **este** se abre con lo que da el templo; desde la Pradera se ve la torre de la Chullpa en la otra orilla. Cada orilla es un anillo chico alrededor de su hub, así se puede dar la vuelta sin repetir camino. El este tiene además tres niveles: Cardonal y Bañado abajo, Necrópolis en el medio, Cumbre y Risco arriba. Se sube por escalinatas y se baja por saltos de una sola vía, que cierran bucles.

```
        OESTE (1er acto)                QUEBRADA     ESTE (2º acto)                   NIVEL
   ┌──────────┬─────────────────────┬──────────┬─────────────────────┬──────────┐
   │SANTUARIO │ EXPLANADA ◆   [D1]  ├══gancho══┤ CUMBRE ◆      [D4]  │ RISCO    │ alto
   │esc.espejo│ templo, sello de luz│  abismo  │ guantes de fuerza   │ carcaj   │
   ├──B───────┼─────────────────────┤          ├─────────────────────┤          │
   │ CERROS   │ PRADERA ◆           ├═══arco═══┤ NECRÓPOLIS ◆  [D2]  │ MIRADOR  │ medio
   │ bombas   │ hub del oeste       │ (puente) │ hub del este        │ corazón  │
   │          │                     │          │ la Chullpa          │          │
   ├──────────┼──────────┬──────────┤          ├──▼──────────────────┴──▼───────┤
   │ GRUTA  B │ CLARO ◆  │ ARBOLEDA ├══pluma═══┤ CARDONAL                       │ bajo
   │ botella  │ inicio   │ cota     │(angostura)│ secretos                       │
   ├──────────┼──────────┴──────────┴──────────┴──────────┬─────────────────────┤
   │VERTIENTE │ LAGUNA (islotes: pluma)              [D3] │ BAÑADO ◆            │ bajo
   └──────────┴───────────────────────────────────────────┴─────────────────────┘
   ◆ portal de viaje   B muro agrietado   ▼ bajada de una sola vía
```

| Región | Contenido | Se entra | Acto |
|---|---|---|---|
| **Claro del inicio** | Spawn, tablillas de controles y de combate, puzzle de levantar (como hoy). Portal | Libre | 1 |
| **Pradera** (hub oeste) | Pasto, vasijas, tablilla de lore; se ven el templo sellado y la torre del otro lado de la quebrada. Portal | Libre | 1 |
| **Cerros** | Cueva de las bombas con su muro de práctica | Libre | 1 |
| **Santuario** | Puzzle de luz y cofre del escudo espejo; la reja de adentro abre el atajo a la Explanada | Bombas | 1 |
| **Explanada del templo** | Sello de luz → **D1 Templo**. Portal. Del lado este, el cruce con postes a la Cumbre | Libre (el sello, con el escudo espejo) | 1 |
| **Gruta** | Poción en botella, tablilla | Bombas, desde el Claro | 1 |
| **Vertiente** | Boca de la cueva del agua bendita (11.20) | Desde la Gruta | 1 |
| **Arboleda** | Puzzle de bloques → cota reforzada. Al este, la angostura de la quebrada | Libre | 1 |
| **Quebrada** | Abismo de norte a sur. Puente levadizo (Pradera ↔ Necrópolis) que baja el ojo de la otra orilla con una flecha; angostura (Arboleda ↔ Cardonal) que se salta con la pluma; postes (Explanada ↔ Cumbre) para el gancho | Caer devuelve a la orilla | — |
| **Necrópolis** (hub este) | **D2 Chullpa**. Portal | Arco (puente) | 2 |
| **Risco del ojo** | Ojo-interruptor → carcaj grande; franja que pide el gancho | Desde el Mirador | 2 |
| **Mirador** | Pieza de corazón; bajada de una vía al Cardonal | Desde la Necrópolis | 2 |
| **Cardonal** | Secretos; escalinata a la Necrópolis y bajada de una vía desde ella | Pluma (angostura) o desde la Necrópolis | 2 |
| **Bañado** | Orilla este de la Laguna. Portal | Desde el Cardonal | 2 |
| **Laguna** | Agua entre las dos orillas; islotes hasta la isla de **D3** | Pluma (islotes) | 3 |
| **Cumbre** | **D4**: la región se alcanza con el gancho (ítem de D3), desde la franja al pie del risco apuntando al poste del borde (`CumbrePost`; los postes se apuntan aunque estén a otra altura). La entrada al Intihuatana es una boca tallada en el risco norte (`CumbreDoor`, vuelta a `Spawn_cumbre`). Portal | Gancho | 4 |

**Cadena de mazmorras (11.90):** D1 Templo (escudo espejo para entrar; da el arco) → arco → D2 Chullpa (da la pluma) → pluma → D3 Laguna (da el gancho) → gancho → D4 Cumbre (da los guantes de fuerza). Para el primer playtest externo, D3 y D4 se ven pero están cerradas.

**Verificación del gating:**

| Para llegar a… | Hace falta | Dónde se consigue | ¿Hay otra forma? |
|---|---|---|---|
| Bombas | — | Cerros, libre | — |
| Santuario / escudo espejo | Bombas | Cerros | La reja del atajo solo abre desde adentro |
| D1 | Escudo espejo (sello) | Santuario | El escudo de madera no refleja |
| Este (Necrópolis, D2) | Arco (puente) | D1 | La angostura pide la pluma, que es de D2: queda como atajo; la quebrada es más ancha que un salto en el resto |
| Laguna, isla de D3 | Pluma (islotes) | D2 | El agua no se cruza nadando |
| Cumbre, D4 | Gancho (postes) | D3 | Desde el Risco no hay paso |
| Carcaj | Arco | D1 | El ojo solo reacciona a proyectiles |

**Viaje rápido (7.9):** seis portales (Claro, Pradera, Explanada, Necrópolis, Bañado, Cumbre), al lado de un hub o de la puerta de una mazmorra. Se prenden al pasar (flag por portal). El destino se elige en la pestaña Mapa del menú de pausa o parado en un portal; el viaje hace un fundido corto y lleva a todos los players. **Hecho (mockup Pause_Map_Travel):** `src/world/travel_portal.tscn` (`TravelPortal`: `id`, `display_name`; flag `ow_portal_<id>`, apagado gris, prendido celeste con haz y luz) bajo `TravelPortals` en `overworld.tscn`; su hijo `Arrival` es el `SpawnPoint` `portal_<id>`. Parado en uno prendido, *Viajar* abre el Mapa (`MenuStack.open_map()`). En el Mapa los prendidos se marcan, el cursor se engancha a 14 px de uno y la tarjeta dice "Portal: <región>" con lo que falta de la región; si es la región del player, "Ya estás en esta región"; si no, X (o el botón *Viajar*) pregunta (`travel_dialog.tscn`, variante de `ConfirmDialog` con ícono y "Viajan todos los jugadores") y `TravelPortal.travel()` usa `SceneFlow.travel_to` a la misma escena. El subtítulo suma "N de 6 portales". Los checkpoints (`SpawnPoint`) no se toman mientras dura un viaje: antes el player, que aparece un instante donde está en la escena, pisaba `Spawn_start` y pisaba el punto de llegada.

**Curva de ritmo:** calma (Claro) → combate (Pradera) → descubrimiento (Cerros: bombas) → recompensa opcional (Gruta, Vertiente) → descubrimiento (Santuario) → prueba (sello) → D1 → el mundo se abre (puente) → hub nuevo con la torre a la vista → D2 → la pluma abre el Cardonal y los islotes de la Laguna → D3 → el gancho abre la Cumbre → D4.

**Pendiente de mudar (7.9):** los párrafos que siguen describen cada lugar tal como quedó en el overworld de 3 × 3; el contenido se muda entero a su región nueva. La grieta de la pluma entre la Explanada y el Risco desaparece (ahora el Risco está del otro lado de la quebrada); su lugar lo toma la angostura.

**Blockout del layout D (7.9):** el `GridMap` de `levels/overworld.tscn` es de 7 × 5 pantallas de 12 × 8 celdas (24 × 16 m) con las paredes compartidas; la pantalla (c, r) tiene su centro en la celda ((c − 3) · 12, (r − 2) · 8). Cada lugar viejo se mudó entero con su contenido (celdas y nodos): Cerros, Santuario, Pradera y Explanada corridos (−48, −16) m, Claro y Gruta (−48, 0), Arboleda (−48, +16) y Risco (+48, −16). Las regiones nuevas son pantallas lisas con su `AreaZone` (Quebrada, Cumbre, Necrópolis, Mirador, Cardonal, Laguna, Bañado, Vertiente). La quebrada (un `Pit` entero, con marcadores en las dos orillas) y el agua de la laguna (un `Pit` por lado) son Abismo: el que cae vuelve al marcador (`Pit.respawn` y sus hijos) más cercano a donde pisó suelo por última vez (`PlayerCharacter.last_ground`), o sea a la orilla de la que cayó. El daño del pozo pasa por el `Hurtbox` como `DamageInfo.unavoidable` (sin escudo ni i-frames, con la reducción de la armadura y el feedback de siempre). Los escalones de una vía (Necrópolis → Cardonal, Mirador → Cardonal) son tiras de Escalón; el nodo que baja de un salto va con el paso 4. La angostura es de tres celdas de Abismo: solo el salto largo (7.10/7.11). El rectángulo del mapa (`OverworldMap.world_rect`) es (−85, −41, 170, 82). Las rutas a pie de cada orilla están en `test_overworld`.

**Puente y Chullpa (7.9):** el puente Pradera ↔ Necrópolis es un `Bridge` (`RavineBridge`, el del templo agrandado a 13 × 6 m) que sube del fondo de la quebrada cuando una flecha le pega al ojo de la otra orilla (`RavineEye`, flag `ow_ravine_bridge_eye`, en la Necrópolis frente al paso). Sube desde abajo en vez de bajar de pie, así nada tapa el tiro al ojo. La Chullpa es por ahora una torre provisoria (`ChullpaTower`, un cilindro con su puerta oscura) en el norte de la Necrópolis; su `Portal` (`ChullpaDoor`) lleva al `start` de `levels/chullpa.tscn`, y la salida de la mazmorra vuelve a `Spawn_chullpa`, delante de la puerta. Los postes del gancho, el salto de una vía y las puertas de D3 y D4 esperan el diseño de mazmorras e ítems (11.90). Tests: `test_an_arrow_at_the_eye_raises_the_bridge_to_the_necropolis`, `test_the_chullpa_door_leads_into_the_dungeon_and_back`.

**Plantas que se cortan (11.111, playtest 2026-10-12):** cactus, árboles y matas se cortan como el pasto: son `Breakable` (`src/world/plants/*.tscn`: árbol, queñoa chica, cardón, cardón brazos y chico, tola, yareta, flores, hongos; el ichu es `grass.tscn`), sueltan la tabla del pasto y vuelven al recargar. Se rompen con animación (`Breakable.break_style`): las matas (`CUT`) saltan girando y se achican, y el ichu deja su mata cortada; árboles y cardones (`FELL`) caen del lado contrario al golpe con polvo y un rebote, y se hunden; los árboles dejan un tocón (`Stump`, oculto hasta romperse). El paso se abre en el acto. Las vasijas siguen rompiéndose de una (`SHATTER`). Las celdas de planta del kit (Árbol, Queñoa chica, Cardón, Cardón brazos) quedan en el `GridMap` como marca, sin malla ni colisión en el kit orgánico; las que `build_terreno_organico.py` desparrama en el piso jugable (`.`, `:`, `w`) no van a la malla del terreno: salen a `tools/plantas_overworld.json`. `decorate_levels.gd` pone la escena en cada una (en `Decor/Plantas`), y también en las piezas de planta de la decoración. Arriba de los riscos siguen en la malla. Test: `test_overworld_plants_are_cut_like_grass`.

**Agua (7.9):** la Laguna es agua de verdad: un plano con `water.gdshader` (el de la cueva de la vertiente: color por profundidad y espuma donde toca la orilla) sobre el hueco de Abismo, cuyas paredes el estilo `laguna` pinta de piedra y musgo. Una cascada (`waterfall.tscn`, agrandada) cae del acantilado norte donde termina la quebrada. Caer al agua es un `Pit` con `water`: salpica (`Feel.burst(&"splash")` y su sonido), saca vida y vuelve a la orilla; no se nada. El Bañado tiene agua baja que se camina: cada `ShallowWater` (`src/world/water/shallow_water.tscn`, un rectángulo con `size`) marca sus celdas como `w` al exportar el terreno, y `build_terreno_organico.py` hunde ahí el piso 0,35 m con una orilla en pendiente y un borde que ondula ±1 m; alrededor el piso queda sin lomas. La superficie se pasa 1,4 m del rectángulo, así la orilla la dibuja el pozo. Adentro los players van a `wade_speed` (0,6; `PlayerCharacter.ground_speed` multiplica la velocidad al caminar y al cargar) y salpican al andar. Tests: `test_falling_in_the_lagoon_splashes_and_returns_to_the_shore`, `test_the_marsh_water_slows_and_splashes_but_holds`.

**Pluma en el overworld (11.61):** el overworld es el hub, así que la pluma abre cosas ahí. Desde 11.90 la pluma es de D2, así que todo esto queda para después de la Chullpa. La pieza de corazón de la pradera está arriba de un escalón de 0,6 m en el rincón noroeste (se ve desde el principio). La grieta entre la entrada del templo y el Risco ya no está (7.9): la reemplaza la angostura de la quebrada. Tests en `test_jump`.

**Blockout (7.2):** `levels/overworld.tscn`, un `GridMap` con el kit gris más sus piezas de exterior (Pasto, Acantilado, Cerco, Árbol, Abismo). Zonas de 11 × 7 celdas de interior separadas por acantilados de una celda; aberturas de 3 celdas donde el paso es libre y de 1 celda donde hay gating (ahí van el muro agrietado o la reja de 7.4, 7.5 y 7.7). Cada zona tiene un `AreaZone` (el HUD muestra su nombre al entrar desde otra zona) y un `SpawnPoint` con el id de la zona (`start` y `santuario` son checkpoints). El abismo no tiene piso (el kit le saca la colisión a Abismo y Pozo, ids 9 y 10): el que entra cae a un `Pit`, pierde vida y vuelve a su `respawn` (en el Risco, `Spawn_risco`). Las flechas pasan por arriba. El del Risco tiene 4 celdas (8 m), más de lo que cruza el salto largo (7.11), así que el ojo sigue siendo solo para flechas (11.35; `test_abyss_has_no_floor_but_a_pit`, `test_the_crag_abyss_is_too_wide_and_falling_returns`). Cajas y rocas: `src/world/physics_box.tscn` y `physics_rock.tscn`. La navmesh se hornea desde el grupo `navmesh_source` (el `GridMap`); si cambia el terreno, botón *Bake* del `NavigationRegion3D`. La navmesh queda 0.5 m sobre el piso, así que el `NavigationAgent3D` del enemigo usa `path_desired_distance` 1.0 (con 0.5 se trababa en las esquinas: nunca daba por alcanzado el punto). Los enemigos ven al player a 12 m (`EntityConfig.vision_range`, antes 8): con la cámara que muestra la sala entera, a 8 m se quedaban quietos estando en pantalla. `test_enemy_ai` revisa que ningún enemigo del overworld o del templo aparezca encimado con paredes o cercos. El mapa de pausa usa una foto cenital del nivel que se saca al abrirlo (ver §Pausa › Mapa).

**Cambio de escena (7.3, 14.9):** los cambios de escena son del autoload `SceneFlow` (`src/flow/scene_flow.tscn`, que reemplaza a `Fader`: fundidos, `travel_to`, `respawn`, `new_game`, `quit_to_title`, `enter_saved_scene`, ubicar players y `location()`); `SaveManager` solo lee y escribe partidas. **Pantalla de carga** (mockup Loading): si la escena tarda más de `show_loading_after` (0,25 s) en cargar en su hilo, sobre el negro aparece solo el ojo que parpadea con "Cargando…" (puntos animados) en la esquina inferior derecha (Daniel, 2026-10-12: sin destino ni barra); queda al menos `loading_min_time` (0,6 s). También al cargar una partida. Un `Portal` (Area3D con `target_scene` y `target_spawn`) llama a `SceneFlow.travel_to()`: pausa, fundido, carga en segundo plano con `ResourceLoader.load_threaded_request` (la imagen no se congela), cambio de escena, el player en el `SpawnPoint` pedido con la cámara enganchada encima (`TopDownCamera.snap_to_target`), autosave en `SaveManager.autosave_slot` y fundido de vuelta. `current_dungeon` lo pone y lo saca el nodo `Dungeon` de cada escena; el estado de cada mazmorra vive en `GameState.dungeons`, así que entrar y salir no lo pierde. El punto de llegada va siempre afuera del portal de la otra escena. Por ahora la puerta del templo lleva a la mazmorra gris (`dungeon_test`); en M8 apunta al templo. **Portal de salida del jefe:** `src/world/warp_portal.tscn` (un `Portal` con disco, anillo y haz dorados) en el centro de la sala del jefe lleva al overworld, a `Spawn_templo` (la entrada del templo). `Portal.required_flag` lo deja oculto y sin detectar hasta que el flag sea verdadero; por ahora no tiene flag (todavía no hay jefe) y en 9.6 se le pone `d1_boss_defeated`.

**Bombas (11.43):** tocar el botón coloca la bomba delante (o la lanza si se apunta con el mouse lejos o hay un objetivo fijado). Mantenerlo más de `PlaceBehavior.hold_time` (0,25 s) la levanta sobre la cabeza (estado `AimingThrow`): el player se planta y apunta como con el arco, la retícula marca dónde cae (`Aim.throw_distance`) y la mecha sigue corriendo; al soltar, `Carry_Throw` la tira en arco. Rodar o recibir un golpe la deja caer; si explota en las manos, lastima. Lo de cargar sobre la cabeza es `Carrier` (`player/components/carrier.gd`: socket `CarrySocket`, animaciones `Carry_*` de `player/animation/libs/Carry.res` vía `CarryBlend`/`CarryPhase`, guarda espada y escudo mientras carga), que también usan los objetos levantables.

**Levantar y tirar (11.44):** vasijas (`pot.tscn`) y piedras (`stone.tscn`) llevan un `Liftable` (un Interactable con prompt "Levantar"). Interactuar las levanta (`Carry_Lift`, estado `Carrying`): el objeto pasa a vivir dentro de un `ThrownObject` (RigidBody3D) que sostiene el `Carrier`; se camina más lento (`Carry_Walk`) y se gira con el stick. Interactuar o atacar lo tira 4,5 m adelante (o al objetivo fijado). Al chocar daña al enemigo que toque; la vasija se rompe y suelta lo suyo; la piedra queda donde cae (sirve para apretar placas) y se puede volver a levantar. Rodar o recibir un golpe lo suelta, y se rompe si es frágil.

**Tutorial (11.45):** sin pantallas de tutorial: lo enseñan tablillas, y cada ítem nuevo trae un puzzle chico al lado de una tablilla que explica cómo se usa. En los textos, `{btn:accion}` se dibuja con el ícono del botón según el dispositivo (`{btn:move}` es el stick o WASD) y `{item:id}` con el botón al que está asignado el ítem (`TextBox`, que en esas líneas cambia el `Label` por un `RichTextLabel`; mockup *Tablet_Tutorial*). *Claro del inicio:* tablilla de controles al lado del spawn (cue `start_controls`: moverse, rodar, interactuar), de combate hacia la salida norte (`start_combat`: atacar, cubrirse, fijar objetivo) y el puzzle de levantar: una piedra, una placa de peso (`ow_start_lift_switch`, modo `WEIGHT`: el player no la aprieta, la piedra arrojada la deja trabada) y la reja del nicho noreste con una poción (`ow_start_lift_chest`), con su tablilla (`start_lift`). *Bombas:* la tablilla de la cueva y el muro de práctica. *Escudo espejo:* la tablilla del santuario suma cómo devolver la luz, y el haz de práctica abre el atajo. *Arco:* tablilla en la arena frente al cofre (`bow_hint`, `d1_tablet_bow`); la sala de ojos que sigue es el puzzle. Lo arrojado no choca con quien lo tiró durante 0,4 s (`Carrier.THROWER_GRACE`).

**Cueva de las bombas (7.4):** el cofre (`ow_cave_bombs_chest`) da la bolsa con bombas y la tablilla de al lado enseña a ponerlas (`data/dialogue/overworld.dialogue`, cue `cave_bombs`). En la esquina suroeste, un recoveco tapado por un muro agrietado de práctica (`ow_cave_practice_wall`) guarda una vasija de corazones: se prueba la bomba enseguida y sin riesgo. El muro del paso al Santuario (`ow_shrine_cracked_wall`) queda a la vista desde la entrada de la cueva. Pendiente de pulido: las paredes altas del recoveco tapan al player cuando pasa justo detrás.

**Santuario (7.5):** detrás del muro agrietado. Desafío corto: un bloque al interruptor (`ow_shrine_switch`) baja la reja del recoveco norte, donde está el cofre grande del escudo espejo (`ow_shrine_mirror_chest`; `equip_on_get` hace que se equipe solo aunque haya otro escudo, y su *item get* explica el reflejo). Haz de práctica: la fuente de la esquina noreste apunta al sur; bloqueando en diagonal (girando con el stick derecho o el mouse) el espejo lo manda al oeste, al cristal (`ow_shrine_shortcut`, con latch), que abre la reja del atajo a la Entrada del templo: solo se abre desde adentro. Las rejas (`Gate`) y los cristales con flag quedan como estaban al cargar la partida. Escenario `bombs_only`: inventario inicial + bombas, en la cueva.

**Sello del templo (7.6):** la fuente del oeste apunta al sur, a un espejo fijo a 45° que manda el haz al este, cruzando la plaza. Atajándolo con el escudo espejo (bloqueo en diagonal, girando con el stick derecho o el mouse) va al norte, al cristal del sello (`ow_temple_seal_open`, con latch). `TempleSeal` (una `Gate` con el ojo) se hunde con sacudida fuerte, retumbo y polvo: el primer momento de *doom*. `TremorZone` cubre la entrada del templo: mientras el player está ahí, cada 6 s una sacudida suave con retumbo grave. Escenario `pre_temple`: todo lo del overworld hasta el escudo espejo, en la entrada del templo.

**Secretos (7.7):** *Gruta oculta*: muro agrietado desde el claro del inicio (`ow_grotto_cracked_wall`), cofre con la poción en botella (`ow_grotto_chest`) y tablilla que adelanta el ojo del risco (cue `grotto_hint`). *Arboleda*: dos bloques en dos interruptores (`ow_grove_switch_a/b`) bajan la reja del recoveco noreste con la cota reforzada (`ow_grove_chest`; no se equipa sola, así se usa la pantalla Equipo). *Risco del ojo*: el `EyeSwitch` de la cornisa (`ow_cliff_eye`) solo reacciona a proyectiles y abre el nicho del carcaj grande (`ow_cliff_quiver_chest`, +20 flechas de capacidad).

**Zonas tapadas (11.52, 11.54):** la gruta y el santuario arrancan bajo un velo negro (`ZoneVeil`, hijo de su `AreaZone`) hasta que se entra o se rompe su muro agrietado; al romperlo se disuelve con dither desde el muro sin frenar el juego, y el minimapa no las ve. El velo cubre la zona más el grosor de la pared que la rodea (`wall_margin`, hasta la cara de afuera) y llega a ras de la tapa del muro (`top`, 2,62 m), así desde el claro no asoma ni la tapa de pasto ni la pared del otro lado.

**Vertiente (11.20):** al oeste de la gruta, una boca de cueva (`SpringCaveMouth`, portal `SpringCaveDoor`) lleva a `levels/spring_cave.tscn`: una sala oscura con una pileta (`WaterPool`) donde cae un hilo de agua, y la vertiente (`Spring`). Con una botella vacía, *Llenar* la cambia por agua bendita en el mismo botón (`GameState.swap_item`); sin botella, *Beber* devuelve toda la vida. Cualquier botella lleva cualquier contenido: un solo modelo de vidrio (`BottleModel`) tiñe el líquido con `ItemData.liquid`/`liquid_glow` (poción roja, agua bendita celeste que brilla). El agua (`water.gdshader`, toon transparente con espuma de borde duro) se proyecta desde la pileta: una `CausticsLight` bajo la superficie, mirando hacia arriba, lo refleja en las paredes, y un `CausticsDecal` lo derrama en el piso de alrededor (`outside_reach`, 2,5 m; `normal_fade` descarta lo vertical, así no se encima con la pared, y `lit_inside` apagado no repite la espuma bajo el agua). Los dos usan, como `light_projector` o textura de emisión, una `DrawableTexture2D` que `caustics.gdshader` dibuja cada frame siguiendo el rayo de cada píxel hasta el plano del agua y leyendo ahí el mismo patrón estilo Wind Waker (`water_pattern.gdshaderinc`, NekotoArts, CC0); así las líneas de espuma caen en la pared alineadas con las de la superficie y se mueven con ellas, y lejos de la pileta se apaga. La luz se puede mover y abrir a ojo (le pasa su pose al shader) y necesita sombra prendida para que el projector se aplique (4.8-dev7).

**Escenarios (7.8):** `start` (inventario inicial, en el claro del inicio; el overworld es la escena principal del juego), `bombs_only` (con bombas, en la cueva) y `pre_temple` (con el escudo espejo, en la entrada del templo). `tests/test_overworld_run.gd` juega `start` de corrido hasta entrar al templo y volver a salir.

## 8. Mazmorra — El Templo
<!-- id: mazmorra -->

**Rediseño (11.113, 2026-10-13, Daniel: si):** el templo es la última mazmorra y usa todos los ítems. No da ítem: el sub-jefe guarda la llave del jefe. Escena nueva `levels/templo.tscn`, flags `te_`; `levels/temple.tscn` (lo de abajo) queda como nivel de prueba hasta que el nuevo esté listo, y entonces el portal del overworld apunta al nuevo. Salas de 7 × 6 celdas (14 × 12 m), para que la cámara quede fija como en Link's Awakening. Grafo de diseño: `data/dungeons/templo_graph.tres` (pasa el test de alcanzabilidad y el molde, con `item` = llave del jefe y `guard` = la Mano). El ala del gancho está hecha (11.30): el abismo se ensanchó a 4 celdas y lleva dos postes.

```
                      ┌──────────┐
                      │ JEFE     │ el Ojo con manos (§9)
                      └────▲─────┘
                        [JEFE]
           ┌──────────┐┌───┴──────┐┌──────────┐
           │COMBINADA ├┤ ANTESALA ├┤ LA MANO  │
           │LLAVE JEFE││          ││ sub-jefe │
           └──────────┘└───▲──────┘└──────────┘
                     [SELLO: 4 ojos]
┌──────────┐┌──────────┐┌───┴──────┐┌──────────┐┌──────────┐
│ OJO DEL  ├┤ GANCHO   ├┤   HUB    ├┤ ESPEJO   ├┤ OJO DEL  │
│ GANCHO   ││ postes   │[L]4 ojos [L]orbes →   ││ ESPEJO   │
│acorazado ││          ││esqueletos││ cristal  ││ haz      │
└──────────┘└──────────┘└───▲──────┘└──────────┘└──────────┘
┌──────────┐┌──────────┐┌───┴──────┐┌──────────┐┌──────────┐
│ OJO DE   ├┤ PLUMA    ├┤VESTÍBULO ├┤ ARCO     ├┤ OJO DEL  │
│ LA PLUMA ││ huecos y ││ bloque → ││ agrietada││ ARCO     │
│llave,brúj││ pinchos  ││interrupt.││ mapa     ││ojos/abismo│
└──────────┘└──────────┘└──────────┘└──────────┘└──────────┘
                              ▲ entrada (sello de afuera: escudo espejo)
```

| Sala | Qué pasa |
|---|---|
| Vestíbulo | Bloque por grilla al interruptor que abre la puerta del hub (como hoy). Libre a las alas de la pluma y del arco |
| Pluma | Filas de huecos de una baldosa con pinchos en ola: se saltan con la pluma siguiendo el ritmo |
| Ojo de la pluma | Del otro lado de los huecos: **llave chica**, **brújula** y el ojo del ala (`te_eye_feather`) |
| Arco | **Mapa**. Muro agrietado (bomba) al ojo del arco |
| Ojo del arco | Ojos-interruptor sobre un abismo, solo con flechas: abren el nicho de la **llave chica** y encienden el ojo del ala (`te_eye_bow`) |
| Hub | Esqueletos. Cuatro ojos tallados en el sello de la pared norte, uno por ala. Puertas con llave a las alas del gancho y del espejo |
| Gancho | Un abismo (foso) de 4 celdas a lo ancho de la sala, entre el hub y el ojo del gancho: el salto largo cruza 3, así que solo pasa el gancho. Un poste de cada lado, a 0,5 m del borde (`GanchoWestPost`, `GanchoEastPost`), corridos de la línea de las puertas para no tapar el paso |
| Ojo del gancho | Esqueleto acorazado: el gancho le saca la armadura (11.90). Vencido, enciende el ojo del ala (`te_eye_hook`) |
| Espejo | Torretas que disparan orbes: el escudo espejo los devuelve al cristal (`te_mirror_crystal`, de la galería de hoy) |
| Ojo del espejo | Un haz de luz que se refleja con el escudo espejo hasta el receptor del ojo del ala (`te_eye_mirror`) |
| Antesala | Se abre con los cuatro ojos. Vasijas con corazones, tablilla, puerta del jefe |
| La Mano | Sub-jefe: uno de los guanteletes del jefe, suelto (`te_hand_defeated`, `HandGuard`). Usa los tres ataques de las manos del jefe (golpe al piso, agarre, barrido); rebota todo mientras está lista y tras el golpe al piso queda aturdida, y ahí entra la espada. Sala sin obstáculos. Vencida, abre la combinada |
| Combinada | Todos los ítems en secuencia (salto, flecha, gancho, reflejo, bomba) hasta el cofre de la **llave del jefe** |

**Munición (11.109 S7):** cada sala que gasta munición tiene vasijas que siempre la dan (`data/drops/pot_bombs.tres`, `pot_arrows.tres`; vuelven al salir de la sala): dos de bombas en el Arco, dos de flechas en el Ojo del arco, y una de cada en la combinada.
| Jefe | El Ojo con manos (§9) |

**Templo viejo (nivel de prueba):**

9 salas + jefe. Hub central con puertas que se van abriendo.

**Sin pluma (11.90, 2026-10-12):** la pluma pasó a D2. Se quitaron la sala de la pluma (era la 10, debajo de la agrietada: su puerta quedó tapiada), la fila de huecos de la entrada del puzzle y el escalón de la vasija de la antesala. Pendiente: el arco lo guarda un sub-jefe (11.31) en vez de solo oleadas.

| # | Sala | Puzzle / mecánica | Combate | Obtiene | Doom |
|---|---|---|---|---|---|
| 1 | Vestíbulo | Bloque por grilla → interruptor de piso abre persiana | — | — | Calma, luz natural |
| 2 | Hub central | 4 salidas: con llave, con persiana, del jefe (sellada), libre | Esqueletos | — | Primeras grietas |
| 3 | Galería de trampas | Torretas disparan orbes → reflejar con escudo espejo a un cristal; entre la entrada y el puzzle, dos columnas de pinchos (`SpikeTrap`) que suben en ola de norte a sur y se cruzan con timing | Torretas, pinchos | Llave chica | Polvo cae al resolver |
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
│ llave 1   │    │ 1 VESTÍB. │
└───────────┘    │ bloque →  │
                 │ interrup. │
                 └───────────┘  ← entrada desde el overworld (vestíbulo)
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

**Pluma (11.35):** estuvo en la sala 10 hasta el 2026-10-12; desde 11.90 es el ítem de D2. El grafo llave-cerradura del templo está en `data/dungeons/temple_graph.tres` (`test_dungeon_reach`).

**Arco a mitad de camino:** sin arco se recorren Vestíbulo, Hub, Galería, Agrietada y Arena (5 de 9). Con el arco se vuelve a la Galería, cuyo ojo sobre la puerta norte se vio desde el principio (cebo), y empieza la segunda mitad: Ojos y Puzzle giran alrededor de las flechas, combinadas con bloques y el escudo espejo.

**Munición:** las vasijas sueltan flechas y bombas (solo si ya se tiene el arco o la bolsa); hay vasijas en el hub y en la antesala.

**Curva de tensión y *doom*:** calma (Vestíbulo) → combate (Hub) → puzzle con presión (Galería) → puzzle (Agrietada) → clímax de la primera mitad (Arena, oleadas) → descubrimiento con el arco (Ojos) → prueba combinada (Puzzle) → respiro antes del jefe (Antesala) → Jefe. El *doom* de cada sala es la columna de la tabla de arriba.

**Construcción:** `levels/temple.tscn` (id `d1`, flags `d1_*`, diálogos en `data/dialogue/temple.dialogue`) con el kit gris: 9 salas de 11 × 7 celdas (22 × 14 m, apenas más que una pantalla) con paredes compartidas y la puerta en el centro de cada pared; la sala (cx, cz) del mapa tiene su centro en (24 cx, 16 cz) m. La puerta del templo del overworld lleva al vestíbulo (spawn `start`) y la salida sur vuelve al spawn `templo`. *Vestíbulo:* bloque → interruptor (`d1_vestibule_switch`) → puerta al hub. *Hub:* dos esqueletos cierran la persiana oeste hasta vencerlos; este con llave (`d1_hub_locked_door`); norte, el sello; vasijas con munición. *Galería:* una torreta al norte; bloqueando en diagonal con el escudo espejo, el orbe entra de frente y sale hacia el ojo del noroeste (`d1_gallery_eye`), que baja la reja del nicho con la llave 1. El ojo sobre la puerta norte (`d1_ojos_door_eye`) solo se despierta con flecha. *Sala agrietada:* una pared cruza la sala con un hueco tapado por una caja liviana (masa 0.3): el player no la empuja, una bomba la vuela. Del otro lado, el mapa (`d1_map_chest`) y el muro agrietado hacia la arena (`d1_arena_cracked_wall`). Si la caja queda trabando la salida, otra bomba la saca (las vasijas dan bombas). *Arena:* `WaveSpawner` (cada hijo es una oleada; sus `WaveSpawn` dicen qué enemigo y dónde) arranca al entrar y retiene cerrada la persiana entre oleadas (`Room.waves_running`). Dos oleadas: dos esqueletos; después el esqueleto con escudo y dos esqueletos. Al ganar (`d1_arena_cleared`) baja la reja del cofre grande del arco (`d1_chest_bow`, trae 10 flechas). Morir a mitad recarga la sala y las oleadas empiezan de cero. *Sala de ojos:* un hueco (pieza Hueco del kit, sin colisión) cruza la sala; caer lastima medio corazón y devuelve a la entrada de la sala (`Pit`). Del otro lado, dos ojos que solo despiertan con flecha: el oeste (`d1_ojos_eye_a`) abre el nicho de la brújula, el este (`d1_ojos_eye_b`) sube un `Bridge` sobre el hueco; cruzando, la llave 2 y la puerta con llave al puzzle. *Sala del puzzle*: en secuencia: 1) el bloque, al este del interruptor, empujado dos veces al oeste, baja la reja que corta el haz; 2) atajando el haz con el escudo espejo se enciende el cristal, que baja la reja delante del ojo; 3) una flecha al ojo (`d1_puzzle_eye`) abre el nicho de la llave del jefe y el sello del hub. *Antesala:* cuatro vasijas de corazones, una tablilla que anticipa al jefe (cue `antechamber`: flechas y reflejo) y la puerta del jefe (`d1_boss_door`; la llave del jefe no se gasta). Checkpoint: la cámara no anota la entrada de la sala del jefe (`Room.boss_room`), así que morir ahí devuelve a la antesala. *Guarida del ojo:* sala vacía; el jefe es M9.

**Doom (10.6):** cada `Room` tiene `doom` (0..1): Vestíbulo 0, Hub 0.15, Galería 0.3, Agrietada 0.4, Arena 0.55, Ojos 0.65, Puzzle 0.75, Antesala 0.9, Jefe 1. `DoomAmbience` (un nodo en la escena del templo) lo sigue suavizado: la luz ambiente y el sol viran de frío a rojo, sube una niebla rojiza, cae polvo alrededor de la cámara, el piso se agrieta (decals generados, más cuanto más doom; el vestíbulo queda intacto) y desde 0.3 el templo tiembla cada vez más seguido (de cada ~14 s a cada ~4 s) con retumbo. La música suma capas con el mismo valor (10.5). **Legibilidad (11.7):** el player y los objetos (cofres, pickups, vasijas, bloques, bombas, tablillas, interruptores; `DoomAmbience.is_legible`) no se tiñen: van en la capa visual 2, que el sol rojo no ilumina (pero sí proyectan sombra, `shadow_caster_mask`), los ilumina `LegibleLight`, una luz neutra con la dirección del sol, y sus materiales no reciben niebla (copias con `disable_fog`). Las grietas no se proyectan sobre ellos. La luz ambiente sí les llega.

**Escenarios y recorrido (8.8):** `dungeon_no_bow` (en el hub, con escudo espejo y bombas), `pre_boss` (en la antesala, todo resuelto y la llave del jefe) y `boss_key_door_locked` (inconsistente a propósito: la puerta del jefe abierta sin la llave; `SaveCodec.validate` lo marca). `tests/test_temple.gd › test_full_run_from_the_entrance_to_the_boss_door` recorre de la entrada a la puerta del jefe desde un único estado inicial e imprime el tiempo por tramo (simulado, sin pelear de verdad); el recorrido real queda para la prueba a mano.

**Softlocks revisados:** *munición*: las vasijas sueltan flechas y bombas solo si se tiene el arco o la bolsa, y vuelven al recargar la escena (salir y entrar al templo); hacen falta 2 bombas y 4 flechas. *Bloques*: los que no están resueltos vuelven a su lugar al salir de la sala (el del vestíbulo, saliendo al overworld). *Caja de la sala agrietada*: si cae trabando la salida, otra bomba la saca (las vasijas de esa mitad dan bombas). *Puertas*: las persianas solo encierran al entrar a su sala y se abren al vencer; las puertas con llave se abren desde el lado por el que se llega y no hay otro camino. *Hueco*: caer devuelve a la entrada de la sala.

**Kit gris y medidas (6.7):** las salas se arman con un `GridMap` sobre `data/kits/gray_kit.tres` (lo genera `src/tools/build_gray_kit.gd` con las texturas de prototipo de Kenney): Piso, Pared, Columna, Escalón y Puerta (piso + dintel; la `Door` va en el medio de esa celda). Celdas de 2 m centradas en (2i, 2k), piso en y = 0, paredes de 2.6 m y una celda de grosor; la cámara de esas escenas usa `mask_margin` = 2 para que se vean las paredes enteras. Una sala de una pantalla tiene 7 × 5 celdas de interior (14 × 10 m); las más grandes se recorren. El bloque de empuje usa la misma grilla.

**Mazmorra gris de prueba** (`levels/dungeon_test.tscn`, id `d0`, flags `d0_*`, escenario `dungeon_test`): un mini candado-y-llave. Vestíbulo: bloque → interruptor abre la puerta oeste; la puerta norte tiene llave. Sala de guardia (dos pantallas de ancho, lateral): la persiana se cierra con dos esqueletos y el cofre del fondo tiene la llave chica. Cámara sellada: cofre grande con la brújula.

## 8b. Mazmorra 1 — La Chullpa (diseño, 11.60)
<!-- id: mazmorra-2 -->

Decidido el 2026-10-11. Torre funeraria de piedra (chullpa) con sótano de enterramientos, siguiendo a los enemigos chullpa (vale aunque el setting siga abierto). Tres pisos apilados en la misma escena, cada uno de 2 × 2 salas con la misma planta, así que un hueco siempre cae a la sala de abajo (referencia: la Torre de Hera de *A Link to the Past*, en `docs/the-ultimate-methodology…`). Ítem: la **pluma**; es la primera mazmorra (D1, desde el 2026-10-13). Unas 11 salas más el jefe. El orden lo comprueba `data/dungeons/chullpa_graph.tres` con el test de alcanzabilidad (§6.2).

**Sub-jefe (2026-10-13):** la **Momia Guardiana** guarda la pluma en 2SE y se vence sin ítems. Su última caída rompe el piso agrietado y abre la isla de la pluma de abajo, que es la sala contigua que se abre al vencerla (§8c, molde). **Jefe (2026-10-13):** **Mallqui, el Ancestro**, la versión grande de la momia en B-NE. Sus ondas llenan la sala y solo se pasan saltando con la pluma. **Acertijos y enemigos (2026-10-13):** uno por piso: bloques en la Entrada, placas en el Rellano, oleadas y pinchos en el sótano. Hay esqueletos en la Entrada, el Osario y el Rellano, y arqueros del otro lado de los huecos de 2NO y del Mausoleo.

```
 PISO ALTO    ┌────────┬────────┐
              │2NO     │2NE     │
              │pluma → │pluma → │
              │ brújula│ corazón│
              ├─[LLAVE]┼────────┤
              │2SO     │2SE     │
              │placas  ├[placas]┤ MOMIA
              │nicho▒  │sub-jefe│
              └──▲─────┴────────┘
                 │ escalera
 PLANTA BAJA  ┌──┴─────┬────────┐
              │1NO     │1NE     │
              │        │escalera│
              ├────────┼─[pluma]┤
              │1SO     │1SE     │
              │ENTRADA ├ abierta┤
              └────────┴────────┘
                  ▲ escalera de mano (solo sube)
 SÓTANO       ┌────────┬────────┐
              │B-NO    │B-NE    │
              │pluma → ├[JEFE]──┤
              │llave j.│ JEFE   │
              ├────────┼────────┤
              │B-SO    │B-SE    │
              │llave   │mapa    │
              └────────┴────────┘
```

| Sala | Qué pasa |
|---|---|
| 1SO Entrada | Llega del overworld; puerta abierta a 1SE. **Acertijo:** una reja (`EntradaGate`) tapa la escalera al piso alto y la abre una placa de bloque (`ch_entry_plate`) metida entre dos columnas, contra la pared norte. Los dos bloques empiezan en fila debajo de la placa y no se empujan juntos: hay que correr el de abajo para pararse detrás del de arriba. Al salir de la sala vuelven a su lugar. Un esqueleto |
| 1NO Osario | Donde se cae desde los huecos de 2NO. Un interruptor abre el atajo a la entrada (la puerta, del lado de la entrada, está sellada). Dos esqueletos. Como solo se llega cayendo y la única salida es el atajo, no lleva acertijo de bloques: un bloque trabado dejaría al player encerrado |
| 1SE Sala del cofre | Cofre grande de la **pluma** en una isla de 3 baldosas (cofre al norte, la del sur queda libre para caer desde 2SE) rodeada de huecos de 2 baldosas, así que ni con la pluma se sale saltando: se sale cayendo. Se ve desde el principio y se alcanza solo cayendo desde 2SE después de vencer a la momia. Caer lleva a B-SE. La puerta a 1NE está en la esquina noreste. **Primera caída (11.117):** caer es el primer paso obligatorio, así que se enseña sin texto: al borde de los huecos hay un esqueleto que, de un espadazo, cae y se lo ve aterrizar en la Cripta, y dos vasijas para tirar por el hueco |
| B-SE Cripta | Donde se cae desde 1SE. Al caer empiezan dos oleadas (`CriptaWaves`, `ch_crypt_waves`): dos esqueletos, y después uno con escudo y dos esqueletos. Vencidas, aparece el cofre del **mapa** (`Chest.switches`: el cofre aparece cuando se cumplen sus interruptores). Escalera de mano que solo sube a la entrada. Caer enseña que los huecos llevan a algún lado |
| B-SO Cripta oscura | **Llave chica** (la de 2NO), desde B-SE, sin ítems. Entre la entrada y el cofre, tres columnas de pinchos (7 trampas cada una, mismo ritmo y desfase de 0,6 s) arman una ola que avanza hacia el cofre: se cruza siguiéndola |
| 2SO Rellano | Llegada del piso alto, con dos esqueletos. Puerta con llave a 2NO. La puerta a 2SE la abren dos placas: una de peso, que aprieta la **vasija grande** de 2NO, y otra en un nicho de la pared oeste, detrás de un muro agrietado (bomba), que se pisa |
| 2NO | Con la llave. La **vasija grande** del acertijo está al lado de la puerta: se lleva a 2SO (se empuja o se carga). Dos filas de huecos de una baldosa: sin pluma, caer lleva al Osario (y a su atajo); con la pluma se cruzan hasta la **brújula** |
| 2SE Sala agrietada | Sub-jefe, la **Momia Guardiana** (`MummyFight`, `ch_mummy_defeated`). Sala sin obstáculos, solo vasijas; al entrar se cierran sus dos puertas. La momia se acerca a saltitos y después salta alto: su sombra sigue al player y se fija antes de caer. Al caer golpea donde cae y manda una onda corta por el piso, que se esquiva alejándose. Después queda trabada y ahí le pegan la espada, las bombas y las vasijas. Vencida, su caída rompe el piso agrietado justo encima de la isla de 1SE: se cae sobre el cofre de la pluma (el truco de la Torre de Hera). Las bombas no rompen ese piso |
| 1NE Sala del abismo | Al pasar la puerta desde 1SE, una fila de huecos de una baldosa sobre un abismo (sin sala abajo: foso que lastima y vuelve): solo con la pluma. Escalera al sótano, que llega a B-NO |
| B-NO Mausoleo | Llega la escalera de 1NE. **Llave del jefe** del otro lado de una fila de huecos sobre un foso (pluma). Puerta del jefe a B-NE, del lado de la escalera |
| B-NE Guardián | Jefe, **Mallqui, el Ancestro** (`BossFight`, `ch_boss_defeated`; la `MummyGuard` a 1,6× con `mummy_guardian.tres`, 24 de vida). Igual que la momia: tres saltitos, salto alto con la sombra fija y trabado al caer, que es cuando le pegan. Su onda cruza toda la sala (radio 24 m), así que caminando no se esquiva: hay que saltarla con la pluma. Con media vida o menos salta dos veces seguidas antes de trabarse, y las dos ondas se cruzan. Vencido da un contenedor de corazón (`ch_heart_container`) y abre el portal al overworld |
| 2NE | Opcional, con la pluma: pieza de corazón del otro lado de una fila de huecos (caer va al foso de 1NE) |

**Ítems anteriores:** solo bombas (de la cueva del overworld). **Vasija grande** (`big_pot.tscn`): se empuja como un bloque y se levanta. Con las manos quietas, interactuar la apoya en la celda de adelante; con una dirección, la tira y se rompe. Un golpe mientras se carga la suelta y se rompe, y la espada también la rompe. Rota, vuelve entera al salir de su sala. **Overworld:** la pluma abre la pieza de la Pradera y los angostos del barranco (§7.1). **Huecos (11.117, Daniel 2026-10-13):** un hueco sin `Pit` debajo cae al piso de abajo; con `Pit` es un foso, que lastima y vuelve a la entrada de la sala. Tienen que distinguirse de un vistazo: por el hueco a otro piso se ve la sala de abajo, con blur y algo oscurecida, con un haz de luz y polvo que cae; el foso es negro, con niebla en el borde. `DropHoles` los lista y `test_drop_holes` comprueba que cada uno cae sobre el piso de abajo y que son los del diseño. **Técnica (hecha):** `levels/chullpa.tscn`. Cada piso es un `DungeonFloor` (`level` −1, 0, 1; nombre del piso para el mapa) con su GridMap, sus salas y lo que hay en él, a `DungeonFloor.HEIGHT` = 8 m uno del otro. Una sala dentro de un piso cuenta solo desde 2,5 m debajo de su piso hasta el de arriba, así que el que cae por un hueco pasa a la sala de abajo: la cámara cambia de sala sin deslizarse, se lleva a los demás players y anota la entrada recién al aterrizar. La cámara oculta los pisos de arriba de la sala actual; el de abajo se ve por los huecos. Donde no hay sala abajo (1NE, B-NO) va un `Pit` como siempre. `Stairs` (`stairs.tscn` sube, `stairs_down.tscn` baja): fundido corto y todos los players aparecen en su `to`, un marcador afuera de la escalera de llegada; la escalera de mano de B-SE no tiene vuelta. El piso agrietado de 2SE es `cracked_floor.tscn` (el script del muro agrietado sobre un hueco). Visitadas, mapa y brújula siguen siendo de la mazmorra. **Selector de pisos** (mockups *Pausa · Mapa por pisos* y *HUD · Minimapa por pisos*): en una mazmorra de varios pisos, la pestaña Mapa tiene a la izquierda una columna con los pisos de arriba abajo (`DungeonFloor.code()`: 2P, 1P, S1), cada uno con su nombre y sus marcas (estás acá; con brújula, cofres sin abrir y jefe); abre en el piso de la sala actual y se cambia con LT/RT (`map_floor_up`/`map_floor_down`, en teclado RePág/AvPág) o con un clic, y el cursor queda en la misma celda. El minimapa muestra el piso actual con una etiqueta arriba. `tools/vary_temple.gd` arregla los huecos y paredes de cada GridMap de las dos mazmorras, y la navmesh se hornea con `godot --headless --path . --script res://tools/bake_overworld_nav.gd -- chullpa`. Escenario de debug: `chullpa`. Las columnas que eran postes del gancho quedan de decoración.

## 8c. Mazmorra 2 — La Queñoa Vigía (11.113)
<!-- id: mazmorra-1 -->

Propuesta el 2026-10-12 y armada en blockout (`levels/quenoa.tscn`). Una queñoa antigua y hueca en el claro de la Arboleda, con ojos que le crecen en la corteza: son vigías del Ojo con manos del templo, así que D1 presenta los ojos y el final muestra de dónde salen. Tres pisos de 2 × 2 salas como la Chullpa (Raíces, Tronco y Copa, 8 m uno del otro); un hueco cae a la sala de abajo. Ítem: el **arco**; es la segunda mazmorra (D2, desde el 2026-10-13). Trae las bombas de la cueva y la pluma de la Chullpa. La segunda mitad (Raíces y Sala de los ojos) combina el arco con los saltos de la pluma (2026-10-13). Grafo: `data/dungeons/quenoa_graph.tres` (con escena; pasa el test y las reglas del molde).

```
 COPA     ┌────────┬────────┐
          │Nido    │Copa    │
          │llave,  ├(bomba)─┤ mapa
          │brújula │escalera│
          │hueco↓  ├─[LLAVE]┤
          │Cámara  │Guarida │
          │ARCO    ├[VIGÍA]─┤ sub-jefe
          │hueco↓  │vasijas │
          └────────┴────────┘
 TRONCO   ┌────────┬────────┐
          │Rama    │Escalera│
          │bloque→ │escalera│
          │llave   │   ▲    │
          ├ abierta┼─[LLAVE]┤
          │Tronco  │Entrada │
          │ojo→    ├ abierta┤
          │escalera│ salida │
          └────────┴────────┘
 RAÍCES   ┌────────┬────────┐
          │Raíces  │Ojos    │
          │2 ojos →├[LLAVE]─┤ ojo tras muro
          │llave   │llave j.│ agrietado
          │(macizo)├[JEFE]──┤
          │        │Jefe    │
          └────────┴────────┘
```

| Sala | Qué pasa |
|---|---|
| Entrada (Tronco SE) | Llega del overworld. Abierta al Tronco; puerta con llave al hueco de la escalera |
| Tronco (SO) | Hub. Un ojo en la pared norte (arco) abre la reja de la escalera que baja a las Raíces. Abajo cae el hueco de la cámara del arco |
| Rama oeste (NO) | Bloque al interruptor → reja del nicho de la **llave chica**. Un ojo en la pared norte, inalcanzable sin arco, abre el nicho de la pieza de corazón. Abajo cae el hueco del nido |
| Hueco de la escalera (NE) | Con la llave. Escalera a la Copa |
| Copa (NE) | **Mapa**. Muro agrietado (bomba) al Nido; puerta con llave a la guarida del vigía |
| Nido (NO) | **Llave chica** y **brújula**. Un hueco cae a la Rama: atajo de vuelta |
| Guarida del vigía (SE) | Sub-jefe, el **Ojo Vigía** (`WardenFight`, `qv_warden_defeated`). Sala sin obstáculos, solo vasijas. Al entrar se cierra la puerta. El ojo flota, se abre, marca una línea en el piso y la barre con un rayo; después se tira sobre el player y queda enganchado en las raíces, y ahí le pegan la espada, las bombas y las vasijas. Vencido, abre la puerta de la cámara del arco |
| Cámara del arco (SO) | Solo se abre al vencer al sub-jefe. Cofre del **arco**. Un hueco cae al Tronco, que es la vuelta |
| Raíces (NO) | Con el arco, desde el Tronco. Un ojo abre el nicho de la **llave chica**. El otro es un ojo con tiempo (`open_time` 6 s, sin flag): abre unos segundos la reja `RaicesGate`, rodeada de huecos frente a la puerta con llave a la Sala de los ojos. Hay que flechar el ojo, saltar los huecos con la pluma y pasar antes de que se cierre. Caer al hueco devuelve a la entrada de la sala |
| Sala de los ojos (NE) | Con llave, saltando desde las Raíces. Junto a la entrada, una placa (`OjosStep`, `qv_eyes_step`) deja abierta la reja de las Raíces para volver. Un ojo detrás de un muro agrietado (bomba y flecha) abre el nicho de la **llave del jefe**, que queda del otro lado de una fila de huecos (pluma): la llave del jefe pide bomba, arco y pluma |
| Corazón del árbol (SE) | Jefe, **Los Ojos de la Queñoa** (`BossFight`, `qv_boss_defeated`). Sala sin obstáculos. Dos ojos que flotan y barren con rayos, de a uno por vez. Cerrados, todo les rebota. Una flecha mientras se abren para cargar los derriba, y en el piso les pega la espada. Al caer uno, el otro se apura. Vencidos: se abre la puerta, aparecen el contenedor de corazón (`qv_heart_container`) y el portal de salida |

Los ojos son `WatcherEye` (`src/entities/watcher_eye/`). Los maneja un `ArenaFight` (`src/world/arena_fight.gd`, el mismo de la momia de la Chullpa) en la sala, como una oleada: cierra las puertas, hace la intro con la cámara y el nombre, muestra la barra del HUD, deja barrer a un ojo por vez y, si el player sale, la pelea vuelve a empezar. Al ganar pone el flag y hace de interruptor. Molde de todas las mazmorras: las peleas de sub-jefe y jefe van en salas sin obstáculos (solo objetos como vasijas), y el cofre del ítem va en una sala contigua que se abre al vencer al sub-jefe. El kit es el de la Chullpa hasta que haya uno de árbol. Escenario de debug: `quenoa`. La puerta en el overworld la pone la sesión del overworld (7.10); mientras, la salida lleva al punto `arboleda`.

## 8d. Mazmorra 3 — El Santuario de Totora (11.30)
<!-- id: mazmorra-3 -->

Plano aprobado por Daniel el 2026-10-13 ("me parece bien la totora") y armado en blockout (`levels/totora.tscn`, hecho con `debug/tmp/build_totora.gd`). Un santuario de islas de totora en la isla de la Laguna. Dos pisos de 3 × 2 salas de 14 × 10 m (7 × 5 celdas), 8 m uno del otro, para que la cámara de LA quede fija. Ítem: el **gancho**, guardado por el sub-jefe Amaru. Trae la pluma (D1), el arco (D2), las bombas y las sandalias (los islotes de la Laguna piden el salto largo). Grafo: `data/dungeons/totora_graph.tres` (con escena; pasa el test y las reglas del molde). Flags `tt_`.

**El agua honda es un pozo:** celdas sin piso con un `Pit` debajo y la superficie de agua de LA. El que cae salpica, pierde 2 y vuelve a la entrada de la sala. Con las sandalias la pluma cruza 3 celdas, así que **todo cruce que pide el gancho mide 4 celdas de agua**, y su poste está en la celda siguiente, a 0.5 m del borde. Por eso el gancho llega a 10 m. Los postes se fijan con el targeting (Z): así se elige uno entre varios. El agua de 1 celda (Embarcadero, Balsas, el estanque del Juncal) se salta con la pluma.

```
 PISO ALTO  ┌───────────┬───────────┬───────────┐
            │Tejedores  │Estanque   │Mirador    │
            │ojo c/tiempo├─[LLAVE]───┤del lago   │
            │→ reja,    │postes al  ├ abierta ──┤ postes →
            │LLAVE JEFE │islote:    │           │ pieza ♥
            │hueco ↓    │llave chica│           │
            ├───────────┼──agua─────┼───────────┤
            │ (macizo)  │Telar      │Garita     │
            │           │agua ancha ├─(bomba)───┤
            │           │postes ↑   │brújula    │
            │           │acorazado  │escalera ▼ │
            └───────────┴───────────┴───────────┘
 PISO BAJO  ┌───────────┬───────────┬───────────┐
            │Cámara del │Pozo del   │Nido de    │
            │GANCHO     ├─[AMARU]   │Yacumama   │
            │postes ↓   │sub-jefe   │JEFE       │
            ├──agua─────┼─[LLAVE]───┼─[JEFE]────┤
            │Balsas     │Embarcadero│Juncal     │
            │pluma      ├─ abierta ─┤arquero en │
            │llave chica│ entrada   │islote; ojo│
            │           │           │→ reja: mapa,
            │           │           │escalera ▲ │
            └───────────┴───────────┴───────────┘
```

| Sala | Qué pasa |
|---|---|
| Embarcadero (bajo, centro sur) | Entrada desde el overworld (punto `totora`). Dos charcos de 1 celda a los costados de un paso enseñan que el agua es un pozo. Abierta a las Balsas y al Juncal; al norte, puerta con llave al Pozo del Amaru |
| Balsas (bajo, SO) | Dos balsas de totora en fila, separadas por agua de 1 celda: con la pluma se llega a la **llave chica**. En la balsa del medio hay un poste (`BalsasPost`) frente a 4 celdas de agua que siguen por la puerta hasta la Cámara del gancho: hoy se ven, con el gancho son el atajo |
| Juncal (bajo, SE) | Un arquero en un islote de un estanque (pluma) y un esqueleto. Un ojo en la pared norte (arco) abre la reja (`JuncalGate`) de la parte este, con el **mapa** y la escalera a la Garita. Al norte, la puerta del jefe |
| Garita (alto, SE) | Escalera al Juncal. **Brújula**. Muro agrietado (bomba) al Telar |
| Telar (alto, centro sur) | Agua ancha hacia el norte: 4 celdas hasta el poste del Estanque, que pasa por la puerta. Sin gancho solo se ve: es la promesa del ítem. Un esqueleto acorazado (bomba o gancho) |
| Pozo del Amaru (bajo, centro norte) | Sub-jefe **Amaru**, una serpiente joven (`AmaruFight`, `tt_amaru_defeated`, `src/entities/amaru/`). Sala sin obstáculos: cuatro charcos al ras del piso y una vasija en cada esquina. Se hunde y asoma por otro charco (asomada, todo rebota), mira al player y marca una línea en el piso (1 s, la línea ya no corrige); se lanza recta por ella hasta 11 m o la pared (2 de daño) y queda tirada sobre la totora 2,2 s: ahí le pegan la espada, las bombas y las vasijas. Después vuelve reptando al charco más cercano. Con la mitad de la vida o menos (10 en total) escupe una bola antes de lanzarse (se esquiva o se para con el escudo). Se vence sin el gancho. Vencido, abre la puerta (`GanchoDoor`) de la Cámara del gancho. test_amaru |
| Cámara del gancho (bajo, NO) | Cofre grande del **gancho**. Primer uso: el poste de las Balsas, 4 celdas al sur por la puerta, es la vuelta (atajo al Embarcadero) |
| Estanque (alto, centro norte) | Con gancho, desde el Telar. Tierra al oeste, un islote al este con 4 celdas de agua en el medio, y un poste de cada lado. En el islote, la **llave chica**; de ahí, una puerta abierta al Mirador. Al oeste, la puerta con llave a los Tejedores |
| Mirador del lago (alto, NE; opcional) | Postes de una orilla a la otra hasta la **pieza de corazón** (`tt_heart_piece`) |
| Tejedores (alto, NO) | Con llave. Una franja de entrada y, del otro lado de 4 celdas de agua, una franja oeste con un poste. Un ojo con tiempo (`open_time` 6 s, sin flag) en la pared oeste se flecha desde la entrada; con el gancho se cruza y hay que pasar la reja (`BossKeyGate`) antes de que se cierre, hasta el nicho de la **llave del jefe**. En el nicho, un hueco cae a la Cámara del gancho: si la reja se cerró, esa es la salida. Si se cruza antes de flechar el ojo, desde la franja oeste también se le pega |
| Nido de Yacumama (bajo, NE) | Jefe **Yacumama**, la madre serpiente (`BossFight`, `tt_boss_defeated`, `src/entities/yacumama/`, hereda del Amaru). Sala sin obstáculos: cuatro charcos y una vasija en cada esquina. Asoma por un charco, escupe dos bolas (el escudo las devuelve) y queda asomada 2,5 s; asomada, todo rebota menos el gancho, que la arranca del charco y la tira al piso a 2 m del player: ahí queda 3 s y le pega la espada (y las bombas). Después vuelve reptando y se hunde. El gancho le pega en el cuerpo (la punta va a 0,9 m del piso; la argolla de la máscara queda como detalle del modelo). Con la mitad de la vida o menos (14 en total), antes de escupir saca la cola de su charco y barre la sala en una vuelta: pega 2 a quien está en el piso y se salta con la pluma. Vencida, aparecen el contenedor de corazón (`tt_heart_container`) y el portal de salida. test_yacumama |

**Recorrido:**
1. Primera mitad, sin gancho: Embarcadero → Balsas (llave) → Juncal (arco: mapa) → Garita (brújula) → Telar (bomba; los postes a la vista) → Embarcadero → Pozo del Amaru (llave) → gancho.
2. Segunda mitad, con gancho: atajo a las Balsas → Juncal → Garita → Telar → Estanque (llave en el islote; Mirador) → Tejedores (arco y gancho con tiempo: llave del jefe) → hueco a la Cámara → atajo → Juncal → jefe.

**Pendiente:** el Amaru y Yacumama tienen modelos primitivos hasta que arte los haga. Diferencias con el plano aprobado (por las reglas del gancho y de la vasija grande): la vasija grande que se traía con el gancho hasta una placa no está, porque se levanta con las manos y el puzzle se resolvía sin el gancho; el Juncal usa una reja en lugar de un puente; el acorazado está en el Telar y no en los Tejedores; el Mirador son solo postes. Kit: el gris de la Chullpa hasta el horneado LA de arte. Escenario de debug: `totora`. La entrada en el overworld es de la sesión del overworld: `TotoraDoor`, en una choza provisoria de la isla, y `Spawn_totora`, adonde vuelven las dos salidas.

## 8e. Mazmorra 4 — El Intihuatana de la Cumbre
<!-- id: mazmorra-4 -->

Plano aprobado por Daniel el 2026-10-13 ("si, me gusta") y armado en blockout (`levels/cumbre.tscn`, hecho con `debug/tmp/design/build_cumbre.gd`). Un observatorio inca en la cumbre nevada. Dos pisos de 3 × 2 salas de 14 × 12 m (7 × 6 celdas), 8 m uno del otro, y la Cima arriba de la Antesala. Ítem: el **escudo espejo**, guardado por el sub-jefe Kuntur joven. El escudo parte la mazmorra: el piso bajo se juega sin él, el alto con él. Trae la pluma, el arco, las bombas, las sandalias y el gancho. Grafo: `data/dungeons/cumbre_graph.tres` (con escena; pasa el test y las reglas del molde). Flags `cu_`.

**La luz:** las fuentes de sol (`LightSource`) tiran un haz que rebota en los espejos y en el escudo espejo alzado, y enciende los cristales (`LightReceiver`, que quedan encendidos). Pieza nueva: el **espejo que gira** (`src/world/light/rotating_mirror.tscn`), que gira 90° de un espadazo; las flechas, las bombas y el gancho no lo mueven. Las rejas cortan el haz, así que una reja que se cierra sola sirve de persiana.

```
 PISO ALTO  ┌───────────┬───────────┬───────────┐
            │Torretas   │Espejos    │Llegada    │
            │abismo,    ├─(cristal)─┤           │
            │postes; orbe│2 espejos ├─ abierta ──┤ escalera ▼
            │→ ojo:LLAVE│que giran  │           │
            ├─ abierta ─┼───────────┼───────────┤
            │Ojo del Sol│Hueco      │Antesala   │
            │ojo c/tiempo├─abierta──┤vasijas    │
            │→ persiana;│hueco ↓    ├─[LLAVE]───┤ [JEFE] → escalera ▲ (Cima)
            │LLAVE JEFE │pieza ♥    │           │
            └───────────┴───────────┴───────────┘
 PISO BAJO  ┌───────────┬───────────┬───────────┐
            │Grieta     │Nido del   │Cámara del │
            │pluma:     │Kuntur     ├─(kuntur)──┤ESCUDO
            │brújula    │sub-jefe   │cristal →  │ escalera ▲
            ├─(bomba)───┼─[LLAVE]───┼───────────┤
            │Columnas   │Atrio      │Ventisquero│
            │abismo,    ├─abierta───┤torretas;  │
            │postes:    │entrada;   ├─abierta───┤ojo → mapa
            │LLAVE      │cristal    │           │
            └───────────┴───────────┴───────────┘
```

| Sala | Qué pasa |
|---|---|
| Atrio (bajo, centro sur) | Entrada desde el overworld. Un rayo de sol cruza la sala pegado a la pared norte, al lado de un cristal: sin escudo es la promesa del ítem; con él, el cristal abre el nicho de las vasijas (bombas). Abierto a las Columnas y al Ventisquero; al norte, puerta con llave al Nido |
| Columnas (bajo, SO) | Abismo de 4 celdas con un poste a cada lado: con el gancho, la **llave chica**. Pared rajada (bomba) a la Grieta |
| Grieta (bajo, NO) | Dos grietas de una celda (pluma) hasta la **brújula** |
| Ventisquero (bajo, SE) | Dos torretas y columnas de basalto para cubrirse. Del otro lado de un abismo, un ojo en la pared sur (arco) abre la reja del nicho del **mapa** |
| Nido del Kuntur (bajo, centro norte) | Sub-jefe **Kuntur joven** (`KunturFight`, `cu_kuntur_defeated`; por ahora una momia prestada). Sala sin obstáculos, una vasija en cada esquina. Se vence sin el escudo. Vencido, abre la Cámara |
| Cámara del escudo (bajo, NE) | Cofre grande del **escudo espejo**. Primer uso: el sol cae del norte, el escudo lo manda al cristal del oeste y se abre la reja de la escalera a la Llegada |
| Llegada (alto, NE) | Escalera a la Cámara. Abierta a los Espejos |
| Espejos (alto, centro norte) | El sol entra por el este hacia el oeste. Dos espejos que giran, de un espadazo cada uno, lo llevan al sur y lo devuelven al este por el lado sur de la sala; ahí el escudo lo baja al cristal, que abre la puerta de las Torretas. Una columna de basalto tapa el atajo desde el primer tramo. Un esqueleto con escudo |
| Torretas (alto, NO) | Abismo de 4 celdas. En la cornisa oeste, una torreta tira orbes; devuelto con el escudo, un orbe pega en el ojo de la cornisa y abre la reja de la **llave chica**. Al lado de la llave, el gancho cruza de poste a poste |
| Ojo del Sol (alto, SO) | Un sol en un nicho, tras una persiana (reja que se cierra sola). Una flecha al ojo de la pared norte la abre 6 s: con el escudo, el rayo va al receptor del sur, que abre el nicho de la **llave del jefe**. Un arquero |
| Hueco (alto, centro sur) | Un hueco cae al Atrio (atajo). Un abismo con un islote en la esquina: con el salto largo, la **pieza de corazón** (`cu_heart_piece`). Al este, puerta con llave a la Antesala |
| Antesala (alto, SE) | Vasijas. En un recoveco del este, la puerta del jefe y la escalera a la Cima |
| Cima (arriba de la Antesala) | Jefe **Apu Kuntur** (`BossFight`, `cu_boss_defeated`; por ahora un ojo vigía prestado). Sala sin obstáculos, una vasija en cada esquina. Vencido, aparecen el contenedor de corazón (`cu_heart_container`) y el portal de salida |

**Recorrido:**
1. Sin escudo: Atrio → Columnas (gancho: llave) → Grieta (bomba, pluma: brújula) → Ventisquero (arco: mapa) → Atrio → Nido (llave: Kuntur joven) → Cámara (escudo).
2. Con escudo: cristal de la Cámara → Llegada → Espejos (espada y escudo) → Torretas (escudo y gancho: llave) → Ojo del Sol (arco y escudo con tiempo: llave del jefe) → Hueco (pieza de corazón; el hueco es el atajo al Atrio) → Antesala → Cima.

**Pendiente:** el Kuntur joven y el Apu Kuntur (hoy prestados). Horneada en estilo LA por arte, con las salas donde estaban (si se edita el grid: `la_walls.gd -- refresh cumbre`, sin rehornear). Escenario de debug: `cumbre`. Entrada en el overworld: `CumbreDoor`, en el risco norte de la Cumbre; las dos salidas vuelven a `Spawn_cumbre`. A probar en el recorrido: si el escudo, apuntado en diagonal, salta el atajo de la columna de los Espejos; el hueco del Hueco queda pegado al abismo del islote.

## 9. Jefe — El Ojo con manos
<!-- id: jefe -->

Modelo propio basado en el Gigante de la jam LD56: calabaza de piedra flotante con juntas de hierro, boca de horno, un ojo enorme de iris neón entre dos párpados de hierro y dos guanteletes que flotan sueltos. Sin esqueleto: son piezas separadas (`assets/epiphany/jefe.glb`, `tools/blender/build_jefe.py`) que mueve el código; cada mano es una malla con shape keys que cierran los dedos de forma continua (abierta para el golpe, garra para el agarre, puño) y se anima sola: respira en reposo, se inclina al moverse, gesticula en cada ataque y se crispa aturdida. En el dorso, un ojo de neón marca dónde pegar.

**Escena (9.1):** `src/entities/boss/boss.tscn` (`Boss`). `Body` flota a 3 m del piso, inclinado −25° en X para que el ojo mire a la cámara; adentro, `%Eye` (el globo de 1,2 m con iris y pupila pintados, gira entero con `look_at_point`) con `%OrbMuzzle` 1,35 m delante (los orbes salen de ahí y giran con el ojo), `%UpperLid` y `%LowerLid` en el centro del ojo (cerrados en 0; `eye_open` 0..1 los rota ∓70° en X, se ve en el editor), las anclas de las muñecas (`%HandAnchorLeft/Right`, ±2,13 m) y los reposos de las manos (`%HandRestLeft/Right`, ±3,6 m al costado y 2 m abajo). `HandLeft` y `HandRight` (`BossHand`) cuelgan de la raíz, no del cuerpo, porque vuelan por la sala; arrancan en su reposo. Cada mano tiene sus tres mallas hermanas (`Open`, `Fist`, `Claw`) y `pose` muestra una sola. La izquierda del jefe es +X (mira al sur, a la cámara). En el templo está en (24, 0, 14,5), un poco al norte del centro de la Guarida: así entra entero en cuadro y deja lugar al sur para pelear.

**Arquitectura (9.3):** cada `BossHand` es una entidad con `Health` (6), `Hurtbox`, `Hitboxes/Strike` y `AttackRunner`, y un estado `READY`/`BUSY`/`STUNNED`/`DOWN`. Lista, los golpes rebotan en el hierro (chispas); un golpe que aturde (`stun_time`) la deja `STUNNED` y recién ahí la espada le saca vida; sin vida queda `DOWN`. El ojo tiene su `%EyeHurtbox` y la `Health` del jefe (24): cerrado no lo toca nada; abierto, la espada sola rebota y un `Projectile` (flecha u orbe devuelto) lo aturde 3 s, la ventana para espadazos. Las fases son un `LimboHSM` (`Phases`): `Phase1` y `Phase2` son `BTState` con su BT (`data/boss/boss_phase*_bt.tres`), `Defeated` un `LimboState`. Las dos manos `DOWN` pasan a la fase 2 (el ojo se abre, las manos se regeneran); sin vida, a `Defeated` (señal `defeated`). Arranca con `start_fight()` (la intro de 9.2). El blackboard de `Phases` lleva `target`, `phase`, el estado de cada mano, `eye_stunned`, `attack` y `attacker`; el overlay de debug muestra `boss/phase`, `boss/hand_left`, `boss/hand_right` y `boss/attack`.

**Elección del ataque (utilidad):** los ataques son `BossAttack` (`data/boss/attack_*.tres`: slam, grab, sweep con las manos; orb con el ojo, fase 2), con fases, pose, `AttackData`, distancia ideal y peso. La hoja `ChooseBossAttack` del BT llama a `Boss.choose_attack(fase)`: puntúa cada ataque por cada pieza libre que lo puede hacer (distancia del player a esa pieza, penalidad por repetir el ataque y por usar la misma mano), combina con producto compensado y sortea por puntaje entre los que tienen al menos el 75 % del mejor. Así no repite ni se vuelve un patrón fijo, pero tampoco elige algo que no conviene. Si no hay ninguno (manos caídas, ojo cerrado) el BT espera.

**Arena (9.2):** la sala `Jefe` del templo ("Guarida del ojo") y un `BossArena` (`src/entities/boss/boss_arena.gd`) con la sala, el jefe y la `BossDoor`. Al entrar, cuando termina el deslizamiento de la cámara, la puerta se cierra detrás y corre la intro: la cámara va al ojo (`TopDownCamera.reveal` con `hold` de 2,6 s), el ojo mira al player y parpadea, retumba, aparece el nombre ("El Ojo Antiguo", `Boss.display_name`, con el mismo cartel que los nombres de sala) y la música sube todas las capas del templo (`Music.boss_fight`, placeholder hasta tener tema propio). Aceptar, atacar o interactuar la saltan (`skip_reveal` corta la espera y los paneos). Al terminar aparece la barra y arranca la pelea (`start_fight`). Al ganar se abre la puerta y la barra se va. Si el player muere se recarga la escena (vuelve a la antesala) y la intro se repite. **Barra (mockup HUD_Boss):** abajo al centro, 720 px, nombre en Cinzel a la izquierda y "Fase N" a la derecha, marcas en los tercios. Muestra `Boss.bar_fraction()`: en la fase 1 la vida que les queda a las dos manos, en la fase 2 la del ojo; se actualiza con `bar_changed`.

**Fase 1 en juego (9.4):** el BT de cada fase es elegir → `PerformBossAttack` (llama a `Boss.perform_chosen` y espera mientras la mano está `striking`, o sea hasta que golpea, no hasta que se repone, así la otra mano puede atacar mientras una está aturdida) → respiro de 0,8 s. Las manos atacan dentro de `Boss.arena` (la sala menos 1,5 m de borde y al sur del cuerpo; la pone `BossArena`). Avisan con una sombra en el piso (un `Decal` con degradé radial que no pinta al player).
- **Golpe al piso (puño):** sube a 4,5 m sobre el player, lo sigue 1 s mientras la sombra se achica y oscurece (3,6 → 2,6 m), se queda quieta 0,4 s (sombra de 2,4 m, negra: última oportunidad para salir) y cae en 0,12 s. Impacto: el golpe directo (1 corazón) y una onda de choque de 2,6 m (medio corazón; se bloquea con el escudo), con anillo dorado, polvo, retumbo y sacudida. Después queda **aturdida 2,6 s en el piso**: la ventana de espadazos (la mano tiene 6 de vida). Se repone y vuelve a su lugar.
- **Agarre (garra):** se pone a 3,5 m del player, tiembla 0,7 s (aviso) y se lanza en línea recta. Rodando (i-frames) pasa de largo; bloqueando de frente rebota en el escudo. Si lo atrapa, el player pasa al estado `Grabbed` (sigue al `Grip` de la mano), pierde ¼ de corazón cada 0,75 s y se suelta con 8 apretones (atacar, interactuar, rodar o bloquear): la mano queda mareada 1,8 s. Si no se suelta en 3 s, lo tira (medio corazón y empujón). *Cambio respecto de la tarea:* no hay "golpe de la otra mano" para soltarse; el escape es solo a botones o por tiempo.
- **Barrido (abierta):** se va al costado de la arena a la altura del player, toma impulso 0,7 s y cruza la sala en 0,6 s. Se bloquea o se pasa rodando.

Sin flechas ni ítems la fase se gana con lo básico: esquivar mirando la sombra, rodar o bloquear lo demás y pegarle a la mano aturdida después de cada golpe al piso.

**Fase 2 en juego (9.5):** al caer la segunda mano, temblor y retumbo; el cuerpo baja de 3 a 2,6 m, el ojo se abre y desde ahí se lo puede fijar con Z (su `%Solid`, la colisión esférica del cuerpo, entra al grupo `targetable`). Las manos vuelven con la vida llena 1,2 s después y siguen atacando. El ojo suma el orbe: carga 0,8 s (una bola cian crece en `%OrbMuzzle`) y dispara un `Projectile` reflejable (1 corazón). **Dónde se le pega:** las flechas y los orbes devueltos vuelan planos a la altura del player y el ojo está a casi 4 m, así que `%EyeHurtbox` es una columna delante del cuerpo, del piso hasta el ojo (2,4 × 3,8 × 1,6 m). Una flecha o un orbe devuelto con el escudo espejo lo aturde 3 s: el cuerpo cae a 1,9 m, el ojo mira al piso y el jefe no ataca; es la ventana de espadazos (24 de vida). La espada sola con el ojo sin aturdir rebota con chispas.

**Fase 3 en juego (9.7):** con un tercio de la vida del ojo (la última marca de la barra) el jefe se enfurece: retumbo, sacudida y el cuerpo vuelve a 2,6 m aunque estuviera aturdido. Suma **Marcas**: el ojo pinta 3 círculos rojos en el piso (radio 1,6 m), uno bajo el player y dos alrededor, que se encienden durante 1,4 s y después explotan en columnas de fuego (1 corazón y empujón). La explosión es de elemento `blast`, así que el escudo no la para: hay que salir caminando o rodando. Mientras tanto una mano libre lanza un golpe al piso (combo). El reparto se valida antes de pintarlo: siempre queda un lugar libre a 2,4 m del player dentro de la arena (si contra una pared no hay reparto que lo deje, marca solo bajo el player). En fase 3 el respiro entre ataques baja a 0,5 s; el puño, el barrido y el orbe siguen.

**Game juice (11.46):** *Cuerpo vivo:* el cuerpo flota (sube y baja `BOB_HEIGHT` 0,12 m) y las manos en reposo flotan con él (siguen su `rest` también al volver); se inclina hacia la mano que ataca; con el ojo abierto parpadea cada 2,5–6 s y entrecierra los párpados al apuntar el orbe. *Ojo que carga:* el iris (material propio por instancia, emisión relativa a la de la paleta) late cada vez más rápido hasta ×4 mientras crece el orbe; la boca de horno se enciende en cada ataque (orbe, marcas). *Manos:* antes del golpe al piso sube de más (`SLAM_OVERSHOOT`), tiembla y destella en rojo (`HitFlash.warn`); la sombra crece y titila el último instante; cae más rápido (0,09 s), se aplasta (`SQUASH`) y rebota. El agarre y el barrido también destellan y el barrido tiembla y empuja el encuadre en su dirección. *Impactos:* el golpe al piso frena todo el juego 60 ms (`Feel.freeze`: baja `Engine.time_scale` y la física sigue, así el golpe conecta; `Feel.hit_stop` desactiva los nodos y sacaría sus hitboxes de la física), deja una grieta que se borra a los 8 s y suelta piedritas; la vibración va con `Feel.shake`, que ahora acepta una dirección (`TopDownCamera.add_trauma` empuja el encuadre hacia ese lado). *Mano aturdida:* se tambalea, el neón del dorso titila y saltan chispas. *Fases:* al pasar a la 2 los párpados crujen un poco y se abren de golpe, con destello del iris y piedras y polvo cayendo del techo; la 3 repite el parpadeo brusco. *Muerte:* cámara lenta (`Engine.time_scale` 0,25 por 0,7 s reales, en el autoload `Feel` para que vuelva aunque se libere el jefe), el neón del ojo y del cuerpo se apaga titilando, explotan las juntas soltando placas (`shards`) y recién ahí se hunde. *Pupila:* el ojo trae dos shape keys (`rendija` y `dilatada`, de `build_jefe.py`) y `Boss.pupil` (−1..1) sigue una meta: se dilata mientras carga el orbe, se cierra de golpe en rendija al disparar o marcar el piso y vuelve sola; aturdido queda dilatada y temblando, y al morir se abre del todo.

**Muerte y final (9.6, 10.19):** sin vida, las manos caen, el ojo se cierra, el cuerpo tiembla soltando polvo y retumbos y se hunde en el piso (`Boss.death_finished`). `BossArena` pone el flag `d1_boss_defeated` (el `BossExitPortal` lo tiene de `required_flag` y aparece), baja el doom de la sala a 0,2 (la luz roja y la niebla se van, la música se calma), guarda y hace aparecer el contenedor de corazón frente a donde estaba el jefe (un `Pickup` con `item_get`: `GameState.give` suma 4 HP al máximo y el player rellena la vida). Tomarlo (flag `d1_heart_container`) es solo el item get. La puerta queda cerrada, también al cargar: el portal es la única salida. El portal tiene `travels = false`: al entrar, `BossArena` guarda en el punto de reaparición (sin la posición, así al cargar no lo vuelve a disparar) y abre el **diálogo de fin de demo** (`data/dialogue/ending.dialogue`, caja estilo item get con respuestas, mockup Dialog_Ending): *Seguir jugando* completa el viaje al overworld, *Volver a retar al jefe* llama a `start_rematch()` y *Volver al menú principal* guarda y va al título. La respuesta la escribe el diálogo en `BossArena.ending_choice` y se aplica al cerrarse la caja. **Revancha:** `GameState.boss_rematch` (no se guarda; cargar partida la apaga) recarga la arena con el jefe vivo y el player adentro junto a la puerta; el portal queda oculto (`Portal.held`) hasta ganarle, morir la reinicia y al ganar no aparece otro contenedor. Sin pantalla de créditos.

- **Fase 1 — Manos:** golpes y agarres telegrafiados. Bloquear o rodar. Tras un golpe al piso, la mano queda aturdida → ventana para espadazos. Aturdir ambas manos → fase 2.
- **Fase 2 — El Ojo:** el ojo se abre. **Flecha al ojo** = cae aturdido → ventana de espadazos. El ojo dispara orbes: se pueden **reflejar con el escudo espejo** como alternativa para aturdirlo. Las manos se regeneran y siguen presionando.
- **Fase 3 — Furia:** a un tercio de la vida del ojo. El ojo "marca" el piso antes de golpes de área que no se bloquean, combinados con golpes de las manos.

## 10. UI
<!-- id: ui -->

*Mockups de todas las pantallas: artifact "Epiphany UI Mockups" (https://claude.ai/artifact/UuD7d42rAXuYTBcMd9iZJy; copia del 2026-10-11 del original de la cuenta personal, que ya no se actualiza).*

Las páginas de la pausa son hijas de un `TabContainer` sin barra propia (`%Pages`); los títulos van en un `TabBar` (`%Tabs`, variación `PauseTabBar`) entre los prompts de Q/E, que también cambia de página con el mouse.

| Pantalla | Contenido |
|---|---|
| **Título** | Escena principal del juego (`src/ui/title/title_screen.tscn`, mockup Main): Continuar, Cargar partida, Nueva partida, Opciones, Salir; en debug, "Cargar escenario" lista `debug/scenarios/`. `--scenario=` y `next_scenario.txt` se siguen respetando. Piezas reutilizables: `MenuItem` (escena sin script: el ▶ es el ícono de la variación del tema, transparente salvo con foco o hover) y `HintBar` (pistas de botones del dispositivo actual). |
| **HUD** | Corazones (¼), llaves chicas + llave del jefe (solo en mazmorra), botones de ítem X/Y con munición (un botón sin ítem asignado no se dibuja, pero guarda su lugar), indicador de acción contextual (A/B: *Abrir*, *Empujar*, *Leer*), barra del jefe, nombre de la zona al entrar. **Minimapa** (11.37, mockups HUD_Minimap_*; `src/ui/hud/minimap.tscn`, abajo a la derecha con el marco de los slots): en mazmorra, la sala actual y las vecinas (3×3) que se visitaron (todas con el mapa), con las puertas por tipo, cofres sin abrir y el jefe si hay brújula, y la flecha del player en su lugar dentro de la sala; en el overworld, la foto cenital de `OverworldMap` alrededor del player (5 px por metro) y las marcas cercanas (entradas, cofres abiertos, tablillas leídas, pines). Lo que se ve se va descubriendo al recorrer: cada player pinta un disco de 11 m con borde suave en `GameState.map_revealed` (una imagen de 1 px por metro, guardada con la partida) y `minimap_fog.gdshader` funde la foto en tinta donde todavía no se pasó y en el borde del mundo. Lee lo mismo que la pestaña Mapa (`src/ui/menus/map_data.gd`). Se oculta con cualquier menú, caja de texto o *item get* abiertos, en la sala del jefe (cubre la intro) y con la opción *Minimapa* apagada. Con algún player debajo en pantalla (los pies o la cabeza, con 12 px de margen) baja a 0,3 de opacidad y vuelve al salir (11.103). |
| **Caja de texto** | Tablillas e *item get*. El texto vive en archivos `.dialogue` de **Dialogue Manager** (Nathan Hoad); el globo es nuestra `TextBox` con los estilos de los mockups (piedra para tablillas, dorado para *item get*), no la UI del plugin. Se integró aunque no haya NPCs, para tener el sistema andando antes de que haya muchos textos (decisión del 2026-10-08, elegido sobre Dialogic por ser liviano y dejar la UI propia). **Respuestas (10.19):** si la línea trae respuestas, al terminar de escribirse aparecen en la caja dorada (debajo de una línea, `response_button.tscn` con el estilo `DialogueResponse`: ▶ y fondo dorado en la elegida, foco en la primera, se navega con stick o flechas) y el aviso "Elegir"; las que no cumplen su condición (`[if … /]`) no se muestran; elegir sigue por su `next_id`. Sirve para cualquier NPC o cartel. |
| **Item get** | Animación con el ítem en alto + nombre + descripción corta. (11.48) El estado `ItemGet` gira al player hacia la cámara, guarda espada y escudo y levanta las dos manos (`Carry/ItemGet_Raise`, que sigue solo a `ItemGet_Hold`; horneadas por IK en `tools/blender/build_carry_anims.py` como las de Carry: con la cabeza chibi las manos quedan en alto a los costados de la cara). Arriba, un destello (`Feel.burst(&"sparkle")` y una luz que se apaga) y la fanfarria `item_get` (por el bus UI, suena aunque se pause); los anillos con el ícono van sobre la cabeza, donde se carga lo levantado. Al cerrar la caja baja las manos (`ItemGet_Lower`) y vuelve. `tools/build_carry_library.gd` lee el `.glb` con `GLTFDocument` (sin reimportar). |
| **Pausa › Equipo** | Espada, escudo, armadura (con ranuras bloqueadas para lo no conseguido), stats, preview del modelo. |
| **Pausa › Ítems** | Grilla de ítems secundarios; abajo, la fila fija de las cuatro botellas (`bottle_1..4`, con lo que lleva cada una; las que faltan, apagadas y "Botella sin encontrar"); asignar a X/Y; descripción; munición. |
| **Pausa › Mapa** | Referencias: Link's Awakening (2019) y Minish Cap. **Mazmorra:** salas visitadas; con mapa, todas; con brújula, cofres y jefe; puertas por tipo (libre, con llave, del jefe, sellada); el cursor salta de sala en sala y la tarjeta dice qué falta. Las salas usan marcos de Kenney Fantasy UI Borders (`tools/build_ui_frames.sh`: `map_room` visitada, `map_room_mapped` sin visitar, `map_room_here` la actual en dorado). La grilla sale de `Room.map_cell`; título y piso, del nodo `Dungeon`. Debajo, los ítems de la mazmorra como íconos (11.104: mapa, brújula, llave del jefe y llaves chicas con su cantidad; `map_dungeon_item.tscn`, apagados si no se tienen). **Overworld:** `src/world/overworld_map.tscn` en el nivel da el nombre y el rectángulo XZ que cubre; la imagen es una foto cenital ortográfica que su `SubViewport` saca cada vez que se abre el mapa, así siempre muestra el layout y los assets actuales. La cámara solo ve la capa de render 20: `scenery` se suma a esa capa y el `GridMap` (que no tiene capas) se copia en MultiMesh por un frame, con las paredes "borde" como las normales y sin el agujero del player; ni player ni enemigos salen en la foto. Zonas sin explorar: la foto como boceto en tinta sobre pergamino (`map_parchment.gdshader`, bordes de la foto); zonas exploradas: el nombre de su región grande, una sola vez (11.102, mockup *Pausa · Mapa por regiones*): las `AreaZone` de una misma región comparten `display_name` y la que tiene `region_label` lleva el nombre (mayúsculas chicas, Cinzel). Ocho regiones: Explanada del templo (con el Santuario), Pradera (con los Cerros), Claro (con Arboleda, Gruta y Vertiente), Quebrada, Laguna, Necrópolis (con el Mirador), Cumbre (con el Risco) y Bañado (con el Cardonal); el HUD también las nombra, solo al pasar de una región a otra. Los lugares importantes son nodos `MapPlace` (nombre y tipo: mazmorra, cueva o santuario) con ícono y nombre chico debajo, una vez visitada su zona: Templo del Ojo, La Chullpa, Santuario, Cueva de las bombas, Gruta oculta, Vertiente. El subtítulo cuenta regiones exploradas, y la tarjeta del cursor suma lo de la región que ya se visitó. Marcas de cofres abiertos, tablillas leídas, hasta 4 pines del jugador y zoom ×2. Cursor de escuadras doradas en las dos vistas (`map_cursor.png`). Abre directo con la acción `map`. |
| **Opciones** | Autoload `Settings` (`user://settings.cfg`, aparte de la partida; se aplica al arrancar). Mockup Options en `OptionsPanel`: fijar objetivo mantener/alternar, apuntar con el mouse, sensibilidad del stick derecho (multiplica el giro al apuntar y con el haz), cambio de objetivo con flick, vibración (la dispara `Feel.shake`), volúmenes de Música/Efectos/Ambiente (buses Music, SFX, UI, Ambience), pantalla completa, temblor de cámara, escala de la interfaz y tope de cuadros por segundo (`Engine.max_fps`: 30/60/120/sin límite, 60 por defecto; 10.24: con un monitor de 200 Hz y sin tope la GPU dibujaba 200 cuadros y gastaba ~20 W de más). Desde el título (pantalla propia) y desde la pausa (Sistema › Opciones). |
| **Controles y pestaña Sistema (10.29)** | `ControlsScreen` (mockups Controls_Gamepad y Controls_Keyboard), desde Opciones › Ver controles: el mando dibujado con nodos (`gamepad_diagram.tscn`) y una caja por botón, o los grupos de teclado y mouse (`keyboard_diagram.tscn`). Cada fila es un `ControlRow` que lee los íconos de sus acciones del InputMap, así que sigue a cualquier cambio de asignación. Arranca en el dispositivo en uso; LB/RB (Q/E) o `ui_toggle_view` (Y/T) cambian de vista. La pestaña Sistema de la pausa (mockups Pause_System, Pause_System_Save y Pause_System_Load): a la izquierda Guardar, Cargar (con "Último guardado"), Opciones y Volver al título (pregunta, porque se pierde lo no guardado); a la derecha los controles básicos del dispositivo en uso (`ControlsView` al 70 %), con Y/T para ver el otro. **Guardar** pisa siempre la partida cargada (`SaveManager.current_slot`), con confirmación; no hay guardados infinitos. **Cargar** elige entre el último checkpoint (la Auto, solo si es de esta partida) y lo último guardado a mano, y confirma. Atrás vuelve de esos paneles a los controles (`PauseMenu.cancel` le pregunta a la pestaña). |
| **Idiomas** (10.18) | Español e inglés con gettext: `translations/<código>.po` (uno por idioma; sumar un idioma es sumar su `.po` a *Localización › Traducciones* y su código a `Settings.LANGUAGES`). Todo texto del juego es una clave (`TITLE_CONTINUE`, `ITEM_BOW_NAME`, `PLACE_EYE_TEMPLE`…, prefijo por área): `Label` y `Button` la traducen solos y se re-traducen al cambiar de idioma; lo que se arma con valores usa `tr(clave).format({nombre = valor})` (placeholders con nombre, así otro idioma puede reordenarlos) y los plurales `tr_n`. Los nombres y descripciones de ítems y lugares en `data/` y en los niveles también son claves; cada ítem tiene su frase de *item get* (`ITEM_<ID>_GOT`) en vez de un artículo. **Diálogos:** el español vive en los `.dialogue` (Dialogue Manager con `use_static_ids_as_translation_keys` apagado, así traduce con `tr(texto, id)`): `es.po` no los repite y `en.po` los traduce con el `[ID:…]` de la línea como `msgctxt`; el nombre del personaje, con `msgctxt "character"`. Si cambia una línea en español, su inglés deja de coincidir y `test_i18n` avisa. **Elegir idioma:** la primera vez (sin `language` en `settings.cfg`) se abre `language_select.tscn` (mockup Language) encima del título, con el idioma del sistema preseleccionado si es es o en; mientras el foco pasa por una opción la pantalla ya se ve en ese idioma. Después se cambia en Opciones (sección Idioma), en vivo. `test_i18n` compara las claves de todos los `.po`, busca las claves usadas en scripts, escenas y datos y verifica que cada línea de diálogo tenga inglés. |
| **Game over** | `GameOver` (mockup GameOver, "CAÍSTE"): al morir, en vez del fundido automático. Continuar (desde la entrada de la sala en mazmorra, o el último punto de control en el overworld), Guardar y salir (guarda en el punto de reaparición, no donde cayó) y Salir sin guardar. Es modal: atrás y pausa no la cierran. |
| **Fin** | Diálogo de fin de demo (`TextBox` estilo ITEM con respuestas, mockup Dialog_Ending): al entrar al portal del jefe. "Fin de la demo", Seguir jugando, Volver a retar al jefe o Volver al menú principal. |
| **Cutscenes e intro (10.20)** | `Cutscene` (`src/cutscene/cutscene.tscn`, mockup Cutscene_Intro): cada cutscene es una escena que hereda de esa, con su `Camera` y un `AnimationPlayer` (animación `play`) que mueve la cámara, escribe `%Caption` (Cinzel centrado, abajo) y llama a `tremor(cantidad)` y `dust(nodo)`; `%Fade` sirve para cortes a negro. Mientras corre hay franjas arriba y abajo, viñeta, sin HUD y los players quietos (`controls.captured`). Se saltea manteniendo aceptar, interactuar o atacar `skip_hold` (0,8 s; el anillo dorado se llena); un toque no hace nada. Al terminar la cámara vuelve sola a la de juego (`settle_time`) y las franjas se van. **Intro** (`src/cutscene/intro.tscn`, ~25 s, 4 planos): el prado desde arriba yendo al norte ("Hace mucho, el cielo tenía dos soles."), llegada al templo ("Uno bajó a mirarnos. Los antiguos lo durmieron dentro del templo."), la entrada que tiembla y se enciende en rojo ("Hace mucho que nadie vuelve.") y corte al claro con el player ("El Ojo despierta."). Los planos van sobre el layout D (11.106): del Claro al norte por la Pradera, la puerta del templo en (−48, −37,5) y `Spawn_start`; `test_shots_frame_the_meadow_the_temple_and_the_player` revisa que cada plano encuadre lo suyo. Corre solo con Nueva partida desde el título (`SceneFlow.new_game(slot, true)`), que pone el flag `ow_intro_seen` antes de guardar: cargar o continuar nunca la repite. |
| **Selección de partida** | `FileSelect` (`file_select.tscn`, mockup FileSelect): tres `SlotCard` (corazones, ubicación, ítems, tiempo jugado; la vacía ofrece Nueva partida), Copiar y Borrar como modos de la misma pantalla; reemplazar o borrar pide un `ConfirmDialog` con el foco en Cancelar. |
| **Debug (solo editor/debug)** | Overlay de valores en vivo (tecla `1`), cargar/guardar rápido (teclas `2`/`3`), pestaña Log en el debugger del editor. Ver §11.9. |

**Máquina de estados de la UI.** Toda la UI son escenas `.tscn` (nada armado por código: los scripts solo llenan datos y reaccionan; lo repetido, como ranuras, pistas o filas, es su propia escena chica; los estilos son variaciones de `src/ui/theme.tres`); `test_ui_scenes` falla si un script de `src/ui` crea Controls o StyleBoxes con `.new()`). Las pantallas extienden `UiScreen` y se abren con `MenuStack.push()`, un autómata de pila: solo la de arriba recibe input y foco; las de abajo quedan desactivadas (y ocultas, salvo que la nueva tenga `hides_below = false`, como los diálogos). Atrás llama primero a `cancel()` de la pantalla (para subestados como Copiar/Borrar) y si no, la cierra, salvo que sea `modal` (game over); pausa y mapa solo cierran las que tienen `closes_with_pause` (el menú de pausa). El título es el estado raíz (`MenuStack.set_base`): queda desactivado mientras haya algo encima y recupera el foco donde estaba.

**Audio (10.5):** buses Master / Music / SFX / UI / Ambience (los crea `Settings`; volúmenes desde Opciones). *SFX:* `Feel` toma varias muestras por evento de los packs CC0 de Kenney (`assets/audio/sfx/`, con su licencia; lista en `compass/lists/assets-de-audio`) y las varía en tono y volumen; explosión, secreto, curación y temblor siguen sintetizados. La interfaz suena sola en el bus UI (moverse, aceptar, volver, abrir y cerrar menús). *Música:* placeholder en capas (`src/tools/render_music.gd` las renderiza a `assets/audio/music/`, loops exactos de 8 s) que el autoload `Music` mezcla: calma en el overworld; en el templo, la base oscura y, según `Room.doom` de la sala, pulso (≥ 0.15), murmullo (≥ 0.45) y latido (≥ 0.7). Con un menú, *item get* o caja de texto abierta, baja 8 dB.

---

### 10.1 Dirección de arte
<!-- id: arte -->

Decidido el 2026-10-09: **KayKit + prototipo, pulido.** Personajes y armas de KayKit Adventurers; props de KayKit Dungeon Remastered (CC0, `assets/kaykit_dungeon/`: cofres, muros agrietados, antorchas); el terreno es el kit gris (`GridMap` con texturas de prototipo de Kenney, teñidas). **Ampliado el 2026-10-09 (M11):** el pack completo de KayKit Dungeon Remastered 1.0 (CC0, 203 modelos en `assets/kaykit_dungeon_remastered/`: pisos de 2 y 4 m, paredes de 4 × 4 × 1 m, arcos, estandartes, barriles, cajas, velas, escombros, mesas, pinchos) y la decoración de KayKit Medieval Hexagon 1.0 (CC0, `assets/kaykit_medieval/nature` y `props`: árboles, rocas, colinas, cajas, carpas, banderas). Bajados de los repos públicos de KayKit-Game-Assets en GitHub; licencia junto a cada pack. **Retirados el 2026-10-13 (11.59):** ya los reemplazan los assets propios (§ Assets propios); de KayKit Adventurers queda solo `Characters/gltf/Knight.glb` (con su textura), el rig del que parten `build_personajes.py` y `make_template.py`, y de las texturas de prototipo y los cielos de Kenney, solo los archivos que usan el kit gris y el overworld.

**Paleta del mundo.**

| Zona | Base | Acentos |
|---|---|---|
| Overworld | Pasto verde apagado `#7aa86b`, acantilado arena `#947a61`, piso de piedra gris | Naranja de las columnas/rocas, madera de cofres |
| Templo | Piedra gris fría (luz ambiente `#8c85a6`) | Antorchas cálidas `#ffad61`; con el *doom*, todo vira a rojo `#cc4d40` con niebla `#401410` |
| Interactivos | Cofres de madera con herrajes (grandes: dorados), muros agrietados de ladrillo gris con musgo (se distinguen del acantilado), puertas de color por tipo, cristales celestes, sello violeta con el ojo | — |

**Kit del templo** (M11): `data/kits/temple_kit.tres`, que arma `tools/build_temple_kit.gd` a partir del kit gris. Los ítems, las colisiones y la navegación son los mismos; cambian las mallas KayKit. Piso: `floor_tile_small`, más cuatro variantes (rota A/B y yuyos A/B, ítems 11–14) repartidas en ~15 % de las celdas. Pared: cuatro `wall_half` estiradas a la celda de 2 × 2 m. Columna: `pillar`. Paso de puerta: con dintel; el marco mira a ±Z, así que en las paredes este/oeste la celda va girada 90° (orientación 16 del GridMap). Si no, el marco queda cruzado en el paso como una losa del alto de la pared sin colisión (test `test_doorways_face_their_wall`). Las piedras usan `kaykit_stone.tres`, que es el shader de corte con `use_uv`, para que el muro sur se siga recortando. Para cambiar una pieza se edita el script y se vuelve a correr (`godot --headless --path . --script res://tools/build_temple_kit.gd`). El overworld sigue con el kit gris.

**Personajes** (M11): el player es el Knight de KayKit Adventurers, y los enemigos son de KayKit Skeletons 1.1 (CC0, `assets/kaykit_skeletons/`): el esqueleto común es el Minion y el de escudo, el Warrior. (Después pasaron a los modelos propios de `build_personajes.py`; el pack se retiró el 2026-10-13.) Todos usan el Rig_Medium, así que comparten el Skeleton3D y las librerías de animación de `player/animation/libs/`; los packs no traen animaciones nuevas. `tools/build_character_models.gd` arma una escena `Visuals` por personaje en `src/entities/models/` (mallas, piel y material; los cascos y capuchas van en BoneAttachment3D con esqueleto externo), y esa escena se instancia bajo el `ModelController`. Para otro modelo en un enemigo, `EntityConfig.model` reemplaza el `Visuals` de la escena al arrancar. Rogue y Mage están listos para cuando haya más tipos de enemigo.

**Assets propios (M12, desde el 2026-10-09).** Todo se rehace en Blender con el estilo de KayKit: low poly, una sola textura de paleta y sin texturas pintadas. **Identidad: Altiplano del Ojo** (elegida el 2026-10-09, para que no parezca un clon de Zelda): fantasía con raíces andinas. Terrazas (andenes) de piedra encastrada en vez de acantilados lisos, pircas de piedra seca en vez de cercos de madera, queñoas, cardones, matas de ichu y tola; caminos de tierra y lajas; puertas y nichos trapezoidales, escalonado de chakana y ojos tallados en el templo; metal de cobre verde. Las piezas se generan por script: `tools/blender/epi/` (primitivas low poly, pintado con la paleta) y un `build_<kit>.py` por kit (`blender -b -P tools/blender/build_<kit>.py`), que escribe `assets/epiphany/<kit>.blend`; para cambiar una pieza se edita el script y se regenera. `tools/blender/diorama.py` arma una escena chica con los kits y la renderiza con la cámara del juego, para revisarlos. `assets/epiphany/palette.png` tiene 8 × 4 franjas de 128 × 256 px, cada una un degradé de claro (arriba) a oscuro (abajo): terreno (pasto, follaje, tierra, acantilado, roca naranja, piedra, piedra del templo, musgo), materiales (madera, madera oscura, hierro, dorado, cristal, sello, doom, ladrillo), tela y vida (hueso, piel, telas roja y azul, agua, flores, fuego) y grises. Los colores se cambian en `tools/blender/epiphany_palette.py` y la textura se rehace con `blender -b -P tools/blender/make_palette.py`. Ese mismo archivo es un addon de Blender (Vista 3D › N › Epiphany, enlazado desde `~/.config/blender/5.2/scripts/addons/`): pone las caras elegidas en una franja, con degradé por altura o tono fijo, y les asigna el material `paleta`. **Medidas:** Z arriba, una celda va de −1 a 1 en X e Y con el origen al centro, el piso arriba en Z = 0 y la losa hasta −0.5; escalón hasta 0.6, cerco 0.9, pared y acantilado 2.6. El frente de las piezas mira a −Y en Blender, que en Godot es +Z, hacia la cámara. El Knight mide ≈2.5 m (chibi). Las piezas que tilean no llevan bisel en los bordes que tocan a la vecina. **Flujo:** se parte de `tools/blender/plantilla.blend` (la arma `make_template.py`: material, Knight y cajas de las alturas en la colección `referencias`, que no se renderiza) y se guarda como `.blend` en `assets/epiphany/`; Godot lo importa directo con Blender. `importer_defaults/scene` pone `blender/nodes/visible` en *Renderable*, así que las referencias no se importan, y la paleta llega como `palette.png`, sin copias. Godot headless no puede importar un `.blend` con el editor abierto (los dos usan el puerto de Blender): lo importa el editor. Kits: `terreno_overworld`, `naturaleza`, `lugares`, `objetos`, `equipo`, `templo` y `personaje_*` (jugador, chullpa y chullpa guardián, pesados con huesos rígidos al Rig_Medium de KayKit, así siguen andando las animaciones). **Integración:** `tools/extract_epiphany_meshes.gd` guarda cada pieza como `assets/epiphany/meshes/<kit>/<pieza>.res` con el material compartido `data/kits/materials/epiphany.tres` (la paleta con tinte 0.72, para que no se lave con el sol); las escenas de `src/world`, ítems, flecha, bomba y torreta usan esas mallas. Los GridMap: `tools/build_overworld_kit.gd` (`overworld_kit.tres`, mismos ids y colisiones que el kit gris más variantes desde el 11) y `tools/build_temple_kit.gd` (paredes con `epiphany_stone.tres`, el cutaway con la paleta); `tools/vary_overworld.gd` reparte en el overworld variantes de pasto, tierra, andenes y árboles con un hash de la celda y elige por vecinos: bordes de tierra donde el pasto toca el camino; la pirca recta, esquina, final o poste según hacia dónde sigue (las rectas salen rotas a veces); el abismo (una grieta de 3 m con paredes de roca que se oscurecen hacia abajo) con pared en cada lado que da a tierra (borde, esquina, pasillo, punta, pozo; test `test_abyss_walls_face_the_ground`); y alrededor del mapa, hasta donde ve la cámara, el **borde del mundo**: meseta a la altura de los topes (`monte_*`, con queñoas, cardones, ichu y flores; sin colisión ni navmesh), baja del lado sur para que ningún árbol tape al player. En el kit una pieza se puede subir con `"kit/pieza@y"` (los árboles sobre la meseta). `tools/vary_temple.gd` reparte nichos y ojos tallados en las paredes que miran a la cámara (salvo donde ya hay algo delante) y hace lo mismo con los huecos del templo (hiladas de piedra del templo que bajan 3 m y se oscurecen; `hueco_borde`, `esquina`, `pasillo`, `punta`, `pozo`). La elección por vecinos está en `tools/grid_pieces.gd`, compartida por los dos; después de cambiar una grilla a mano se vuelve a correr el `vary_*` del nivel. Las puertas eligen la hoja por tipo (madera, llave, persiana, interruptor, jefe). `tools/build_character_models.gd` arma `src/entities/models/{jugador,chullpa,chullpa_guardian}.tscn`; cada armadura puede tener su paleta completa: `VARIANTS` en `epiphany_palette.py` cambia franjas enteras (con su degradé) y `make_palette.py` escribe `palette_<variante>.png` y su emisión; el `body_material` de la armadura las usa. Las franjas de `EMISSIVE` (neón y doom) brillan por `palette_emission.png`. Los íconos de ítems se renderizan de las mismas piezas (`tools/render_item_icons.gd`). Después de regenerar un `.blend`: importar (`godot --headless --path . --import`, con el editor cerrado) y correr el extractor y los builders que lo usan.

**Materiales.** Sin PBR fino: albedo + textura de prototipo en triplanar de mundo (una textura por celda de 2 m), rugosidad alta. Lo que se puede usar o romper tiene que leerse distinto del escenario: otro material (KayKit), otro color o un brillo.

**UI.** La que fijan los mockups: fondo `#0b0d10`, paneles `#151920`, bordes `#3a4250`, dorado `#d9a441` para foco y títulos, texto `#efe6d2`, secundario `#a79f8e`, peligro `#d0503a`. Títulos en Cinzel, texto en Alegreya Sans. Íconos de ítems renderizados desde sus modelos 3D (decidido el 2026-10-09): `tools/render_item_icons.gd` (con ventana, no headless) saca un PNG de 256 px con fondo transparente y contorno oscuro por ítem, en una vista de tres cuartos, a `assets/ui/items/`. Los modelos son los de KayKit (Adventurers, Dungeon Remastered) y los del propio equipo; las armaduras son el torso del Knight con su `body_material`. El mapa, la brújula y el contenedor de corazón no tienen modelo y siguen con su SVG plano. Botones con los prompts de Kenney según el dispositivo; la letra viene calada en el SVG y `InputPrompts` la rellena con el fondo `#0b0d10` al cargarla, para que no se vea lo que hay detrás. **Marcos** (decidido el 2026-10-09): los de *Fantasy UI Borders* de Kenney (CC0), teñidos con esta paleta por `tools/build_ui_frames.sh` en `assets/ui/frames/` (el pack original queda en `assets/kenney_fantasy-ui-borders/`, fuera de la importación). Marco doble dorado para la pausa, los diálogos y el *item get*; doble gris para las tarjetas; piedra para las tablillas; simple bronce `#6b5a3a` para botones, casillas y ranuras, que pasan a dorado con el foco; los sliders son la doble línea del pack (bronce, dorado lo lleno) con un rombo dorado de perilla, como los radios; casillas marcadas con un cuadrado dorado; la ranura de partida vacía es solo el borde. Un único divisor ornamentado: bajo las pestañas de la pausa y a los lados del nombre de la zona.

## 11. Arquitectura técnica
<!-- id: arquitectura -->

**Nodos en la escena (10.27):** todo lo que hereda de `Node` va en su `.tscn`, no con `X.new()` + `add_child`, así se retoca en el inspector; el código solo ajusta lo que depende del juego (un flag, un radio por objeto, un stream sorteado). Lo que aparece en runtime se instancia de una escena: ráfagas de `Feel` (`src/feel/bursts/*.tscn`), su onda (`shockwave.tscn`) y sus reproductores (`sfx_player.tscn`, `ui_sound.tscn`); tramos del haz de luz (`beam_segment.tscn`); grietas del doom y del golpe del jefe (`doom_crack.tscn`, `slam_crack.tscn`); cuerpo de lo levantado (`thrown_object.tscn`); pedazo de armadura (`armor_piece.tscn`); mallas de la foto del mapa (`map_piece.tscn`). Fijos en su escena: `PersistentFlag` (el dueño le copia su `flag` en `_ready`; acepta el flag tarde), `HitFlash` (con `health` y `visuals` exportados), el modelo del cofre, el área del checkpoint (`spawn_point.tscn`), las capas de `Music` (el autoload es `music.tscn`), el polvo y la luz legible del doom (`doom_ambience.tscn`) y, en el player, el cono de bloqueo, la mira, la flecha de apuntado y la luz del *item get*. Las herramientas del editor (`addons/`) arman su UI por código y quedan afuera.

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

**Tests** (10.23): `godot --headless --path . --script res://tests/run_tests.gd` reparte los `test_*.gd` en varios procesos headless (los núcleos, hasta 4), parejos según lo que tardó cada archivo la última vez (`user://test_times.cfg`); solo muestra las líneas `ok`/`FALLA` y deja todo lo que imprime cada proceso en `user://test_logs/worker_<n>.log`. Cada proceso usa sus propias partidas, opciones y temporales (`test_saves_<n>/`, `test_settings_<n>.cfg`, `tests_tmp_<n>`; los tests los leen de `test_case.gd`, nunca con la ruta fija). `-- --jobs=1` corre todo en serie en un solo proceso; `-- --only=test_a.gd,test_b.gd` corre solo esos archivos. Los procesos corren con `--fixed-fps 60`: el tiempo de juego no depende de la carga de la máquina, así que los tests no se vuelven inestables con varios procesos y avanzan tan rápido como da la CPU. Suite completa (276 tests): ~16 s con 4 procesos y ~55 s con `--jobs=1`; antes, en serie a tiempo real, ~8,5 min. Por eso el juego no mide tiempos con el reloj (`Time.get_ticks_msec`) sino con el `delta` de los frames, que además respeta la pausa y el hit-stop.

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
# (Ranged_Bow_Release) llama a use(). El arco se sostiene en la mano del escudo (Equipment.hold, socket
# BowSocket: de pie, ladeado 55° y delante del puño, para que se lea desde la cámara cenital). Su modelo
# (BowModel) se tensa con la shape key "tensado" al ritmo de Ranged_Bow_Draw y lleva la flecha en la cuerda.


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

> Sin objetivo fijado, el stick derecho mueve la cámara para mirar alrededor (decidido el 2026-10-11: desde que el arco y la bomba se apuntan con el stick izquierdo al mantener, el derecho ya no hacía falta para apuntar). Con objetivo fijado, el mismo stick cambia de objetivo. Si no hay candidato en la dirección pedida, no pasa nada (o se hace wrap, a decidir jugando).

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

Las puertas `SHUTTER` las abre la sala (al limpiar enemigos) y las `SWITCH` sus interruptores. **Interruptores:** `FloorSwitch`, `EyeSwitch` y `LightReceiver` comparten la interfaz `active` + señales `activated`/`deactivated`. Las puertas y rejas exportan `switches: Array[NodePath]` y una condición (`ALL`/`ANY`); el helper `Wiring` los escucha y avisa cuando la condición se cumple o deja de cumplirse, así que se cablea en el editor, sin código por sala. **Modos de `FloorSwitch`:** `HOLD` (activo mientras haya algo encima), `ONCE` (queda activado con lo primero que lo pise, player incluido), `BLOCK` (solo un bloque empujable; el player y lo arrojado no lo aprietan) y `WEIGHT` (un objeto apoyado o arrojado, o un bloque; el player no). `BLOCK` y `WEIGHT` quedan resueltos y guardan el flag. Playtest 2026-10-12: los puzzles de bloques se resuelven solo con bloques; los de objetos y los de golpe fuerte son otros tipos de placa. Usan `BLOCK` el Vestíbulo y el Puzzle del templo, el santuario y la arboleda del overworld y la mazmorra gris; `WEIGHT` la placa de levantar del Claro. Un bloque con `solved_flag` aparece en `solved_position` al volver: tiene que ser la posición de su interruptor (test). `Gate` también tiene `stays_open` y `close()`. **Mostrar lo activado (11.98):** todo lo que se destraba por una acción lo muestra la cámara: `Door` y `Gate` (`reveal_on_open`, encendido por defecto; se apaga si el interruptor acciona algo en otra sala), `Bridge` (`reveal_on_raise`) y la sala al limpiar la horda (enfoca la primera persiana y las abre todas). Pasan por `TopDownCamera.reveal_unlock()`; el runner de tests apaga `unlock_reveals` antes de cada test y los que prueban el acercamiento lo encienden. La primera vez que sus interruptores los abren, `TopDownCamera.reveal()` pausa el juego, se acerca al objetivo (`reveal_zoom` 0.6 del offset, `reveal_pan_time` 0.6 s; el foco se acota a la sala con la vista acercada, así no muestra lo que hay detrás de sus paredes), lo abre, espera `reveal_hold` (0.9 s) y vuelve al player. No se dispara al cargar una partida (`SaveManager.loading`) ni con el juego ya en pausa. La puerta del Vestíbulo y la reja del Puzzle lo usan. **Bloques por grilla**: `AnimatableBody3D` que se mueve 1 celda con tween al empujar ≈0.3 s contra él; los `RigidBody3D` quedan para objetos físicos (bombas, rocas, enemigos livianos).

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

**Ranuras y autosave (10.2, rehecho en 10.21):** `user://saves/slot_N.cfg`. La ranura 0 es la **Auto** (`SaveManager.AUTO_SLOT`): siempre la última partida guardada sola (autosave o guardado rápido de debug), venga de la ranura que venga; guarda en `meta/slot` de qué partida es. Las ranuras 1–3 (`PLAYER_SLOTS`) son las del jugador: solo cambian con Guardar (Guardar y salir de la pausa, del game over y del final). `current_slot` es la ranura del jugador de la partida en curso; al cargar la Auto se vuelve a su ranura de origen, así Guardar va ahí. Los escenarios y los tests usan ranuras propias (98, 8, 9…) y su autosave va a esa misma ranura, nunca a la Auto. Se guarda solo al cambiar de escena, al abrir un cofre grande y al entrar a la antesala (`Room.autosave_on_enter`); el HUD muestra "Guardado". Cada partida guarda `play_time` (segundos jugados con player en escena y sin pausa) y `location` (mazmorra · sala, o la zona del overworld) para la pantalla de ranuras. Un guardado cortado a mitad se recupera del `.bak` (una ranura con solo el `.bak` no aparece vacía). Al cargar, cada clave con un tipo inesperado vuelve a su valor por defecto (`SaveCodec.typed`), `_migrate` corre antes de validar y una partida de una versión más nueva no se carga. **Título y selección de partida (mockups Main y FileSelect):** *Continuar* carga directo la ranura más reciente (Auto o del jugador). *Cargar partida* abre la selección: la tarjeta Auto arriba, más baja, con la partida de la que viene ("de la partida 2"), y las tres ranuras; Copiar y Borrar (con confirmación, foco en Cancelar; la Auto se puede copiar a una ranura y borrar, pero no es destino de una copia). *Nueva partida* sin ninguna partida empieza directo en la ranura 1; si no, abre la selección en modo nueva partida ("¿Dónde empezás la partida?", sin la Auto, foco en la primera libre): una vacía empieza ahí y una ocupada pide confirmar que se sobrescribe. Una partida nueva ocupa su ranura enseguida (guarda en ella y en la Auto).

- **Formato:** `ConfigFile`, en `user://saves/slot_N.cfg`.
- **Release:** encriptado (`save_encrypted_pass`). La clave está en el binario, así que es ofuscación y no seguridad, pero alcanza para el objetivo: nadie edita la partida por accidente y después reporta un "bug".
- **Editor / builds de debug:** texto plano (feature `editor` o la feature tag custom `plain_saves` en el preset de export).
- **`meta/checksum`:** si no coincide al cargar, se marca `save_tampered` (se incluye en reportes de bugs), pero la partida carga igual.
- **`meta/version`** + migraciones.
- **Escritura atómica:** se escribe a `slot_N.cfg.tmp`, la partida anterior pasa a `slot_N.cfg.bak` y el `.tmp` se renombra. Si `slot_N.cfg` no carga, se lee el `.bak`.
- **Posición:** por ahora `[player] position` guarda la posición exacta y `spawn_scene` la escena; con salas y overworld pasa a `spawn_point`.
- **Escena por uid:** junto a `spawn_scene` va `spawn_uid`, y al cargar manda el uid, así que mover o renombrar un nivel no rompe partidas viejas. Un save sin uid usa la ruta. Todo nivel con `SpawnPoint` necesita uid (lo prueba `test_portals`).
- **Cargar recarga la escena** aunque sea la misma en la que se está (`SceneFlow.enter_saved_scene`, tarea 11.108): así puertas, interruptores y puentes arrancan con los flags de la partida en vez de quedar como los dejó el mundo en curso.

Ejemplo de partida en texto plano:

```ini
[meta]
version=1
timestamp=1790660850.0
checksum="3f1a…"

[player]
max_health=12
spawn_scene="res://levels/overworld.tscn"
spawn_uid="uid://cjddyr8q6b3o0"
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

**Sombras del sol (10.25):** el `Sun` del overworld, el templo y la mazmorra de prueba usa 2 cascadas hasta 32 m (lo que abarca la cámara cenital) en vez del default de 4 hasta 100 m, que volvía a dibujar la geometría por cada cascada. Medido el 2026-10-11 (RX 580, 1280×720, sin tope): overworld 1,23 M → 346 mil triángulos y 765 → 228 draw calls (GPU 1,39 → 1,16 ms); templo 540 mil → 143 mil y 415 → 149. La sombra ortogonal cuesta lo mismo en geometría y más en GPU. Las capturas antes/después se ven iguales. `test_render_budget` lo controla.

**Paredes del GridMap (10.26):** `tools/build_overworld_kit.gd` y `build_temple_kit.gd` pasan las paredes por `tools/hidden_faces.gd`, que saca las caras que nunca se ven: la base de cada piedra (pegada al núcleo del muro) y las que miran abajo. Lo enterrado queda porque se ve junto a pozos y abismos. Acantilado 1224 → 918 triángulos por celda, Pared del templo 816 → 656. Con las sombras de 10.25: overworld 347 mil → 288 mil triángulos (GPU 1,16 → 1,12 ms), templo 143 mil → 124 mil (1,08 → 0,95 ms), mismas draw calls, capturas iguales. `cell_octant_size` 4 en vez de 8 baja otro 17 % de triángulos en el overworld pero sube las draw calls de 227 a 290 y la GPU apenas cambia (1,12 → 1,03 ms): queda en 8. `test_render_budget` controla el tope por celda.

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
| **9** | **Jefe**: integrar el modelo, fases 1–2 con LimboAI | Se puede terminar el juego |
| **10** | **Terminación**: título, selección de partida, game over, opciones, doom ambiental, audio, build para playtesters (compilar LimboAI templates) | MVP |

Recortes si hace falta, en orden: fase 3 del jefe → cota reforzada → carcaj post-mazmorra → sala 7 (fusionar con 6) → pasto/vasijas en overworld.

**No se corta:** doble función del escudo, ítem de la mazmorra, jefe con 2 fases, guardado.

## 13. Fuera del MVP
<!-- id: fuera-mvp -->

Moneda y tiendas · NPCs con diálogo · piezas de corazón · gancho / telequinesis · espadas múltiples o elementales (estructura lista) · spin attack · remapeo de controles · más de una mazmorra · pesca y otras actividades (hay animaciones, tentador pero no).

**Co-op (después del MVP, decidido el 2026-10-10):** estilo *Four Swords*: primero **local** (dos jugadores en la misma pantalla, M13) y después **online** (host autoritativo, M14). Progreso compartido en `GameState`; cada player con su control, sus corazones y su color (variante de paleta). **Regla desde ahora:** ningún sistema nuevo asume un solo player — se pide la lista de players (o el objetivo de la IA) en vez de "el" player del grupo `player`; el refactor de lo existente es la tarea 13.1.

**Registro de players (13.1):** autoload `Players` (`src/state/players.gd`): `all`, señales `joined`/`left` (cada `PlayerCharacter` se anota al entrar al árbol y se borra al salir), `lead()`, `alive()`, `any_alive()` y `nearest(punto)`. Qué usa cada cosa: la IA (`FindPlayer` sigue al que ya tenía mientras lo vea; si no, el más cercano que vea), el jefe al empezar la pelea, los pickups (imán hacia el más cercano) y el jefe mirando en la intro usan `nearest`; lo que todavía es de uno solo usa `lead()`: guardar la posición, el nombre de la zona, el mapa, Equipo y los temblores. Pausar pide algún player vivo; reaparecer pone a todos en fila (`SaveManager.PLAYER_SPACING`). El grupo `player` sigue (detección de cuerpos y tests), pero el código nuevo no busca "el" player con él. **Input por jugador (13.2):** cada player tiene `controls` (`player/components/controls.gd`, se crea con el player). Jugando solo lee las acciones de siempre (teclado y cualquier control, como antes). En co-op cada uno lee sus copias `p<slot>_<acción>` del `InputMap`, con solo los eventos de sus dispositivos: el primero, el teclado y los controles que no son de nadie; cada invitado, su control. `InputBuffer`, `Aim` (el mouse solo para quien tiene el teclado), `Targeting`, `InteractionDetector`, la máquina de estados y los estados que leen botones pasan por `controls`; la cámara mira con el stick del primero. **Unirse:** Start en un control que no es del primero suma un player al lado (hasta 2 por ahora, sin pausar); con un solo control conectado y el primero en teclado, ese Start pausa. **Salir:** mantener Start 1,5 s; un toque pausa, como el de cualquiera (los menús son de todos). Los invitados se anotan en `Players.guests` (slot → control) y reaparecen al lado del primero en cada escena. **Prompts:** `InputPrompts.icon_for(acción, player)` muestra los botones del control de ese player (cada panel del HUD muestra los del suyo). **Colores (13.6):** el P2 lleva túnica azul y neón lima (paleta `p2` de `VARIANTS` en `epiphany_palette.py`), y con la cota reforzada, dorada con ribetes azules y neón lima (`reforzada_p2`). `Equipment.guest_body_materials` es el cuerpo de cada invitado sin armadura e `ItemData.guest_body_materials` el de cada armadura; el P1 sigue con los colores del modelo. **Cámara y salas (13.3):** jugando solo la cámara es la de siempre. En co-op mira al centro del rectángulo que encierra a los players vivos (sin lock-on, apuntado ni stick de mirar, que son de uno) y hace de borde invisible: lo que alguien se mueve en un cuadro y abre el grupo más de lo que entra en pantalla (menos `leash_margin`) se deshace en ese eje; los saltos grandes (reaparecer, pozo) no. **Cambio de sala, decidido:** como en *Four Swords*, el que cruza a otra sala se lleva a los demás: aparecen a su lado (y detrás si son más de tres) y entran caminando juntos en el deslizamiento. El agujero de las paredes se abre sobre el player que esté tapado. Entre escenas (overworld ↔ templo) todos llegan juntos al punto de entrada (13.2 + `SaveManager`). **HUD (13.5, mockup HUD_Coop):** un `PlayerPanel` por player (`src/ui/hud/player_panel.gd`): corazones, slots X/Y con los botones de su dispositivo y su prompt de acción. Jugando solo el HUD instancia `player_panel_solo.tscn`, el de siempre (corazones y llaves a la izquierda, slots y prompt a la derecha); en co-op un `player_panel.tscn` compacto por player, P1 arriba a la izquierda y P2 arriba a la derecha (la misma escena en espejo con `layout_direction` RTL; corazones y slots quedan en su orden), con una etiqueta P1/P2 del color de `HUD.player_colors` y las llaves compartidas arriba al medio. Al entrar o salir alguien el HUD rearma los paneles. Los slots muestran los X/Y de ese player (`GameState.buttons_of(slot)`). **Reglas, decidido (13.4, 2026-10-11):** *Vida:* cada uno tiene sus corazones (la vida máxima es del grupo). El que cae queda en el piso un momento y, si otro sigue vivo, se vuelve un espíritu (estado `Spirit`, nodo `Spirit` del player) que flota detrás del vivo más cercano, sin colisión ni daño. Revive con un corazón si un vivo se le queda pegado un momento (`revive_radius`, `revive_time`) o cuando el grupo pasa a otra sala (`TopDownCamera.enter_room`). Game over solo cuando no queda nadie vivo. *Ítems:* inventario, munición, equipo (espada, escudo, armadura) y progreso son del grupo (`GameState`); los X/Y son de cada uno: `item_buttons` es del P1 y se guarda, los de los demás (`guest_buttons`) arrancan como copia de los del P1 y no se guardan. En la pestaña Ítems asigna el que toca el botón (su control). Lo que aparece se acomoda en los botones libres de todos, y el ítem que se acaba deja su reemplazo en todos (poción → botella vacía). *Drops:* el corazón cura al que lo toca (el vivo más cercano). *Elegir ítems, decidido (13.9):* un anillo por player que se abre manteniendo la cruceta (mockups Coop_Ring y Solo_Ring); cada uno conserva X e Y, un ítem lo lleva uno solo, en co-op no pausa y jugando solo el mundo casi se detiene. La pestaña Ítems de la pausa queda para jugar solo; en co-op muestra quién lleva qué. Se abre manteniendo LB (teclado: F) y se elige con el stick o WASD. A prueba: la tecla 5 (debug) alterna, en co-op, entre el anillo y un solo menú de pausa donde cada invitado mueve su cursor con su control y asigna con X/Y (Settings `coop_item_menu`). Botones libres del mando para lo que venga: L3 y R3. **Cuántos, decidido (2026-10-11):** el co-op es de dos por ahora (`Players.MAX_PLAYERS`); 3–4 quedan para cuando haya puzzles pensados para ese número (y el HUD irá a las esquinas de abajo). Para probar el online, un modo arena aparte de hasta 8 jugadores peleando entre sí mide hasta dónde aguanta la red; la meta del co-op online sigue siendo 4.

## 14. Decisiones abiertas
<!-- id: decisiones-abiertas -->

- [ ] Historia: opción A o B (o propia). Título del juego.
- [ ] ¿Varias espadas o una espada con modificadores elementales?
- [x] Layout exacto de la mazmorra (§8.1) y del overworld (§7.1).
- [x] Ranuras de guardado: 3 (decidido el 2026-10-09).
- [x] Arte: KayKit + texturas de prototipo, pulido con paleta propia (decidido el 2026-10-09, §10.1).
- [x] Multijugador: co-op estilo Four Swords, primero local (M13) y después online (M14) (decidido el 2026-10-10, §13).
- [x] Modelo del jefe: el `.blend` de la jam no tenía rig; piezas separadas que mueve el código, sin AnimationTree (decidido el 2026-10-09, §9).
