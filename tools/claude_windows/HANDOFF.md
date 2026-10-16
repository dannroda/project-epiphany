# Handoff Windows → Linux

La sesión de Windows escribe acá. El integrador de Linux lo lee al mergear `wt/windows`, pasa lo que corresponda al tablero y a la memoria, y deja este archivo vacío otra vez.

## Mediciones

Shader baker en Windows (2026-10-16): `measure_shaders.ps1 -ClearDriverCache`, export "Windows (debug)", RX 580 (driver 31.0.21924.61), 3 corridas por caso. Overworld listo desde que arranca el proceso:

| Caché | D3D12 sin baker | D3D12 con baker | Vulkan sin baker |
|---|---|---|---|
| Vacía | 10,3 s (10,6 / 10,2 / 10,1) | 8,1 s (8,2 / 7,9 / 8,2) | 8,2 s (8,3 / 8,1 / 8,1) |
| Caliente | 2,7 s | 2,7 s | 2,65 s |

- En D3D12 el baker ahorra ~2,2 s (~21 %) en el primer arranque. Con eso D3D12 queda igual que Vulkan sin baker. Con caché caliente no cambia nada.
- Linux (Vulkan, misma GPU) daba ~5,2 s en frío. En Windows el frío es más lento con los dos drivers.
- Pipelines al llegar al overworld, iguales en todos los casos: CANVAS 6, MESH 15, SURFACE 49, SPECIALIZATION 22.
- Efectos: `explosion` (+7 specialization), `projectile` (+2) y `roar_ring` (+1) compilan al aparecer en todos los casos, incluso con baker y caché caliente. Igual no pasan de ~18 ms de peor frame (vsync a 60 Hz ≈ 17 ms).
- `sparks_gold` tuvo dos picos sueltos sin compilar pipelines: 85,7 ms (D3D12 sin baker, caliente 1) y 63,6 ms (Vulkan, caliente 1). En las corridas en frío marca 19,5 ms. No parece venir de shaders. Vale mirarlo aparte.
- No se midió Vulkan con baker.
- Resultados completos: `debug/tmp/shaders/resultados.txt` en el worktree de Windows (ignorado por git).

Arreglos a `measure_shaders.ps1` para PowerShell 5.1:
- `$PSScriptRoot` llega vacío dentro de `param()`.
- `measure` es alias de `Measure-Object` y le gana a la función: se renombró a `MeasureBuild`.
- Nuevo `-SkipExport` para reusar las builds ya exportadas.

## Cambios para el tablero

- 11.203: anotar las mediciones de arriba. Recomendación: activar el baker en el preset de Windows, porque D3D12 es el driver por defecto.
- Revisar: el export "Windows (debug)" incluye `liblimboai.windows.editor.x86_64.dll`. ¿El de release usa el template_release oficial de LimboAI 1.8.1?
- Revisar el pico de `sparks_gold` con caché caliente (ver arriba).
- Kit de Windows: el README da por hechos los export templates. En esta PC no estaban y hubo que instalarlos desde el editor (4.8.beta1). Podría verificarlo `setup.ps1`.

## Memorias nuevas

- `windows-machine`: `--screen 1` = HP N223 (1920×1080); el 0 es la ViewSonic principal (2560×1440). Ya está en la memoria de este perfil.
- En PowerShell 5.1, los alias integrados (`measure`, `select`, `where`, `sort`…) le ganan a las funciones del mismo nombre. No nombrar funciones de scripts `.ps1` así.

## Pendiente en el worktree de Windows

- El primer export reimportó el proyecto y cambió 531 archivos: 485 `.res` de meshes, 45 `.import` y `src/entities/guard_bt.tres`. Están en un commit aparte, 8dfae88, para que Linux decida si se mergean o se descartan; ese commit se puede revertir solo.
- `guard_bt.tres` solo ganó los uid de `bt_alert.gd`, `bt_search.gd` y del recurso, y se movió de lugar el sub_resource `BTAction_wander`. El árbol es el mismo.
