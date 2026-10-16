# Teaser (10.31)

Las tomas del teaser están guionadas en `teaser.tscn`. Cada toma se puede grabar desde varios ángulos con exactamente la misma acción, así que sirven como multicámara para editar.

## Qué hay en `teaser.tscn`

Cada hijo de `Shots` es una toma (`TeaserShot`). Una toma define:
- el escenario de `debug/scenarios`;
- dónde arranca el player (`Inicio`, mirando hacia su -Z);
- cuánto dura (`length`) y cuánto espera antes de grabar (`settle`);
- la semilla del azar;
- si se ve el player;
- si saca los enemigos (`clear_enemies`);
- qué nodos congela (`freeze`);
- en qué fase pone al jefe final (`boss_phase`).

**Pasos (`TeaserStep`):** son lo que hace el player, a los `at` segundos. Puede caminar a un marcador, perseguir al enemigo más cercano, apretar o mantener un botón, equipar un ítem, o fijar un blanco y soltarlo. Con `on_floor`, el paso espera a que el player pise el suelo.

**Ángulos (`TeaserAngle`):**

| Ángulo | Qué hace | HUD |
|---|---|---|
| `GAME` | Usa la cámara del juego. | Sí |
| `RAIL` | Va de From a To, mirando a Mira. | No |
| `FOLLOW` | Sigue al player desde `offset`. | No |
| `ORBIT` | Gira alrededor de Mira o del player. | No |

Todo se retoca en el editor: mover los marcadores y cambiar los tiempos.

## Grabar

```bash
tools/teaser/record.sh                 # todas las tomas y ángulos (Movie Maker, 1080p60, monitor HP, ~20 min)
tools/teaser/record.sh Hub Mano        # solo esas tomas
tools/teaser/record.sh Hub-Orbita      # solo ese ángulo
tools/teaser/edit.sh                   # arma debug/tmp/teaser/teaser.mp4 con la lista CUTS y la música del juego
```

Cada toma queda en `debug/tmp/teaser/NN_<toma>-<ángulo>.mp4`, con el sonido del juego y sin la música.

## Jugarla vos

```bash
tools/teaser/play.sh Hub               # se abre en tu pantalla; jugás cuando el player se suelta
tools/teaser/record.sh --tomas Hub     # repite tus inputs desde todos los ángulos (…-jugada.mp4)
```

`play.sh` arma la toma igual que la versión guionada: mismo escenario, misma semilla y misma fase del jefe. Corre a 60 fps fijos.
- Mientras espera el `settle`, el player no se mueve.
- Cuando empieza a grabar, se suelta y vos jugás durante `length` segundos.
- Al terminar, tus inputs quedan en `takes/<toma>.json`, con cada cambio ubicado en su tick de física.

`record.sh --tomas` repite esos inputs con Movie Maker desde cada ángulo. Los videos que salen así llevan `-jugada` en el nombre, y `edit.sh` los usa en vez de los guionados.

Jugala con el joystick o con el teclado; el mouse no se graba. Si la repetición se desfasa (por ejemplo, un enemigo que esquiva distinto), volvé a jugar la toma.
