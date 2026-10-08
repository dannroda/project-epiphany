# Tablero del proyecto — guía para agentes

Las tareas y los hitos de este proyecto viven en `compass/`, en el formato de Scope Compass. Esta guía alcanza para operar el tablero; no hace falta leer el código de Scope Compass.

## Reglas

- **Usá la CLI `scompass`, no edites los JSON a mano.** Valida, escribe en formato canónico, regenera el export markdown y, si hay un hub corriendo, avisa al instante a la UI web y al dock de Godot.
- Corré los comandos desde cualquier carpeta del proyecto (busca `compass/` hacia arriba) o con `--dir <proyecto>`.
- Si `scompass` no está en el PATH: `node <carpeta de scope-compass>/hub/bin/scompass.js`.
- Agregá `--json` para leer la salida desde un programa. Código de salida 0 si anduvo; el error va por stderr.
- No hace falta que el hub esté corriendo: sin hub, la CLI escribe directo en `compass/`. Con el Inicio corriendo (`scompass home`), la CLI pasa por él solo (lo encuentra en el registro).
- Si la CLI avisa que el hub es de otra versión, reinicialo con `scompass restart` antes de seguir: un hub viejo puede no conocer campos nuevos.
- Los cambios quedan como archivos modificados en `compass/` (y en el export markdown). Commitealos solo si te lo piden. `scompass list` termina con cuántos hay sin commitear (`uncommitted` en `--json`).

## Modelo

- **Hito** (`compass/milestones/<id>.json`): id `m00`, `m01`, …; campos `code` ("M0"), `title`, `order`, `goal`, `done_when`.
- **Tarea** (`compass/tasks/<id>.json`): el id es el nombre del archivo. `scompass add` le da el siguiente número de su hito (`m5-12` en `m05`) y lo imprime; las tareas de antes pueden tener ids al azar como `sd3tg577`. No se renombra, aunque la tarea cambie de hito. Campos:
  - `milestone` (id del hito), `title`, `code` (número visible, por ejemplo "5.2"; opcional);
  - `status`: `todo` (Pendiente), `doing` (En curso), `review` (Revisión), `done` (Hecho);
  - `checklist`: pasos `{ text, done, detail? }`. `text` es una línea corta; el cómo y el porqué van en `detail`;
  - `due`: fecha límite opcional, `YYYY-MM-DD` o `YYYY-MM-DDTHH:MM` (hora local);
  - `priority`: prioridad opcional, `high`, `medium` o `low`;
  - `assignee`: responsable opcional, texto libre (una persona o un agente);
  - `tags`: etiquetas opcionales, textos cortos sin comas (`["arte", "audio"]`);
  - `test`: cómo se comprueba que la tarea está terminada;
  - `notes`: notas libres;
  - `refs`: documentos del proyecto que la tarea cita, enteros (`{ doc }`) o una sección (`{ doc, section }`);
  - `links`: vínculos con otras tareas (ver "Vínculos entre tareas").
- En los textos, `` `así` `` se muestra como código.

## Leer

```sh
scompass milestone list                      # hitos, en orden
scompass list                                # todas las tareas, por hito
scompass list --milestone m05 --status doing # filtros (se pueden combinar)
scompass list --q "menú pausa"               # todas las palabras en código, título o id (sin tildes)
scompass list --status todo,doing --priority high --assignee Claude
scompass list --due overdue                  # overdue | today | week | none (las hechas no vencen)
scompass list --tag arte,audio               # con alguna de esas etiquetas
scompass list --blocked                      # o --unblocked; también --pending-steps y --with-refs
scompass list --json                         # { "tasks": [ { "id", "etag", "title", "status", "checklist", … } ] }
scompass show m5-02                          # una tarea, con los pasos numerados desde 1
scompass show m5-02 --json
```

## Escribir

```sh
scompass add "Título de la tarea" --milestone m05 --code 5.9   # imprime el id nuevo
scompass move m5-02 doing                                     # todo | doing | review | done
scompass set m5-02 --title "…" --notes "…" --test "…"          # cambia solo esos campos
scompass set m5-02 --due 2026-10-10                           # fecha límite (--due "" la quita)
scompass set m5-02 --priority high --assignee Claude --tags arte,nivel  # "" quita cada uno; --tags reemplaza la lista
scompass step add m5-02 "Paso corto" --detail "Cómo y por qué"
scompass step set m5-02 2 --text "…" --detail "…"              # --detail "" quita el detalle
scompass step rm m5-02 2
scompass check m5-02 2                                        # tilda el paso 2
scompass check m5-02 2 --undo
scompass set m5-02 --file tarea.json                          # reemplazo completo (--file - lee stdin)
scompass milestone set m08 --file hito.json                   # crea o reemplaza un hito
```

- Los pasos se numeran desde 1, como los muestra `scompass show`.
- Para no pisar un cambio ajeno, pasá `--etag <etag>` (el que devuelve `--json`): si la tarea cambió, falla con conflicto. Volvé a leerla y reintentá.
- Una tarea se borra borrando su archivo en `compass/tasks/`.

## Vínculos entre tareas

Una tarea puede bloquear a otra o estar relacionada con otra. Se guarda en un solo lado (`links` de la tarea que bloquea); "bloqueada por" se calcula.

```sh
scompass link add m5-02 blocked-by m5-01   # m5-02 no puede avanzar hasta que m5-01 esté hecha
scompass link add m5-01 blocks m5-02       # lo mismo, dicho desde la otra tarea
scompass link add m5-02 related m4-03      # relacionadas, sin orden
scompass link rm m5-02 m5-01               # quita el vínculo entre las dos
scompass link list m5-02 --json            # { "links": [ { "id", "blocks", "blocked_by", "related" } ], "broken": [] }
scompass link list                         # todos; sale con 1 si hay vínculos a tareas que no existen
```

- Entre dos tareas hay un solo vínculo: agregar otro reemplaza al anterior. Un `blocks` que cerraría un ciclo se rechaza.
- `scompass list` marca `[bloqueada por <ids>]` en las tareas que tienen delante una tarea sin terminar; `scompass show` lista los vínculos.
- Antes de empezar una tarea, mirá si está bloqueada. Si descubrís que una depende de otra, vinculalas en lugar de anotarlo en `notes`.

## Uso habitual

- Al empezar una tarea: `scompass move <id> doing`. A medida que avanzás, `scompass check <id> <n>`.
- Al terminar: completá `test` si está vacío, dejá en `notes` lo que el siguiente necesite saber y pasala a `review` (o a `done` si ya se comprobó).
- Trabajo nuevo que aparece en el camino: `scompass add` en el hito que corresponda, en lugar de dejarlo solo en el chat.
- Si te piden "lo mío" o "lo de alta prioridad", filtrá con `--assignee` o `--priority`. Al tomar una tarea, si el proyecto usa responsables, poné tu nombre con `set --assignee`. Usá las etiquetas que ya existen (`scompass list --json` las muestra) antes de inventar otras.

## Listas

Además de las tareas, un proyecto puede tener listas (`compass/lists/<id>.json`): pendientes, compras, ideas, assets a conseguir. Cada ítem es `{ text, done, created_at, due?, repeat?, task? }`; `due` es la fecha límite (`YYYY-MM-DD` o `YYYY-MM-DDTHH:MM`, hora local), `repeat` `{ "every": "day" | "week" | "month" | "year" }` (requiere `due`) y `task` el id de la tarea creada desde el ítem.

```sh
scompass lists                                      # listas con lo que queda pendiente
scompass lists show compras --json                  # { "id", "etag", "title", "items": [ … ] }
scompass lists add "Libros para leer"               # el id sale del título: libros-para-leer
scompass item add compras "Yerba"
scompass item add pendientes "Pagar la luz" --due 2026-10-10 --repeat month
scompass item check compras 2                       # ítems numerados desde 1, como en lists show
scompass item set pendientes 1 --due ""             # quita la fecha
scompass item clear compras                         # quita los tildados
scompass item task assets 3 --milestone m06         # pasa el ítem a una tarea y lo enlaza
```

- Tildar un ítem que se repite no lo deja tildado: su `due` avanza un período desde la fecha límite (31/01 → 28/02). No se destilda; si hace falta, cambiale la fecha con `item set --due`.
- Algo con etapas o pasos va como tarea en un hito; algo que solo se tilda va en una lista. Si un ítem crece, pasalo a tarea con `item task`.

## Documentos y referencias

Los documentos citables están en `compass/config.json` › `docs` (alias y ruta). Una referencia apunta a una sección por su id estable (`<!-- id: … -->` debajo del título), o al documento entero si va sin `#<id>`. En notas, prueba y pasos, `[[alias#id]]` enlaza una sección y `[[alias]]` el documento.

```sh
scompass doc list                  # documentos con su índice de secciones
scompass doc show spec#godot --raw # el markdown de una sección (sin #godot, el documento entero)
scompass ref add m5-02 spec#godot  # la tarea cita esa sección
scompass ref add m5-02 spec        # la tarea cita el documento entero
scompass ref rm m5-02 spec#godot
scompass refs check                # referencias rotas (sale con 1 si hay)
```

## Proyectos del equipo

Cada hub que se levanta anota su proyecto en `~/.config/scope-compass/projects.json` (en Windows, `%APPDATA%\scope-compass\projects.json`), para que el Inicio lo muestre aunque después se apague. No hace falta tocarlo para operar el tablero.

```sh
scompass home list --json   # { "file", "projects": [ { "path", "name", "found", "hubs": [ { "pid", "port" } ] } ] }
scompass home add           # anota este proyecto sin levantar su hub (o: home add <carpeta>)
scompass home rm <carpeta>  # lo quita del registro; no toca sus datos
scompass home               # levanta el Inicio (uno por usuario): GET /api/today junta lo vencido, de hoy y en curso
```

## Más

- `scompass --help`: todos los comandos. Un proyecto nuevo se crea con `scompass init --template juego|personal|vacio`.
- `compass/README.md`: formato de los archivos y manejo a mano con git.
- `compass/schema/`: JSON Schema de tareas, hitos, listas y `config.json` (`views` elige las pestañas de la web: `board`, `lists`, `docs`).
- `scompass update`: pone al día `compass/schema/`, esta guía y `compass/.gitattributes` (LF también en Windows) cuando Scope Compass se actualizó (`--check` solo avisa). El dock de Godot lo ofrece con el botón "Actualizar", y la bandeja del hub con "Actualizar compass/".
