# Seguir Epiphany con Claude Code desde Windows

Recrea en Windows lo que usamos en Linux:
- el repo y el tablero (scope-compass)
- un worktree propio
- el perfil de Claude, con los skills, los plugins y la memoria del proyecto

Con el dual boot no hay otras sesiones prendidas. La de Windows trabaja sola en `wt/windows`. Al volver a Linux, el integrador mergea esa rama y actualiza el tablero con lo que quedó en `HANDOFF.md`.

## Antes de bootear (en Linux)

```bash
tools/claude_windows/export_kit.sh   # copia la memoria y los skills actuales al kit
```

Después commiteá y pusheá. El integrador ya lo hace al mergear.

## En Windows, una sola vez

1. Instalá Git, Node y Claude Code: `winget install Git.Git OpenJS.NodeJS.LTS`. Sumá la extensión de Claude Code en VS Code o VSCodium.
2. Tené a mano Godot 4.8-beta1 para Windows, con sus export templates instalados (Editor > Manage Export Templates). `setup.ps1` avisa si faltan.
3. Si querés clonar por SSH, cargá tu clave en `~\.ssh`. Si no hay clave, el script prueba por HTTPS.
4. Cloná el repo y corré el script desde el clon:

   ```powershell
   git clone git@github.com:dannroda/project-epiphany.git "$env:USERPROFILE\Proyectos\Godot\project-epiphany"
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Proyectos\Godot\project-epiphany\tools\claude_windows\setup.ps1" -Godot "C:\ruta\a\Godot_v4.8-beta1_win64.exe"
   ```

   Por defecto, `-Root` es `%USERPROFILE%\Proyectos\Godot`. El script hace esto:
   - Clona `project-epiphany` y `scope-compass`.
   - Crea el worktree `epiphany-wt\windows` en la rama `wt/windows`, con upstream `origin/wt/windows` (nunca main: un "Sync" de VS Code no puede pushear a main).
   - Fija `CLAUDE_CONFIG_DIR` en `%USERPROFILE%\.claude-profiles\personal`, como en Linux.
   - Copia los skills y un `settings.json` sin los hooks de Linux.
   - Copia la memoria para la carpeta del clon y la del worktree, más una memoria `windows-machine` con las rutas de esta PC.
5. Reabrí VS Code/VSCodium, abrí la carpeta del worktree, hacé `/login` y revisá con `/plugin` que estén los plugins.

## Primer trabajo: medir shaders en Windows

Pedile a Claude: *"leé tools/claude_windows/README.md y corré la medición de shaders"*. Hace esto:

```powershell
powershell -ExecutionPolicy Bypass -File tools\claude_windows\measure_shaders.ps1 -Godot "C:\...\godot.exe" -ClearDriverCache
```

- Exporta "Windows (debug)" dos veces, con y sin shader baker. El baker de D3D12 solo se puede generar desde Windows.
- Corre cada build 3 veces en frío (caché vacía) y 3 en caliente, en D3D12, y además la build sin baker en Vulkan.
- `tools/pipeline_probe.gd` entra al overworld y larga cada efecto una vez. Anota cuánto tardó el overworld desde que arrancó el proceso, las compilaciones de pipelines y el peor frame de cada efecto.
- Pasa la lista dos veces (`PROBE 1` y `PROBE 2`) con un tramo `(sin efecto)` antes de cada efecto, y anota los ms desde el arranque. Para 15.2: si el pico de `sparks_gold` aparece solo en la pasada 1, es del efecto; si cae en un tramo sin efecto o en otro efecto al mismo tiempo, es de algo que corre de fondo en ese momento.
- Todo queda en `debug\tmp\shaders\resultados.txt`.
- `-ClearDriverCache` borra también la caché del driver de AMD, NVIDIA y D3D. Así se mide el primer arranque real. Los demás juegos la rehacen solos.
- Las ventanas abren en `-Screen 1` sin robar foco. Confirmá que el 1 sea el monitor HP.
- Antes de correrlo, desenchufá o apagá el joystick: acá no hay bwrap que lo esconda.

Referencia en Linux (Vulkan, RX 580; overworld listo desde que arranca el proceso):

| Caché | Sin baker | Con baker |
|---|---|---|
| Vacía | ~5,2 s | ~5,05 s |
| Caliente | ~2,6 s | ~2,6 s |

En Linux el baker no aporta: lo que tarda es el driver armando pipelines. En D3D12 se espera que ayude más.

## Al terminar en Windows

- Commiteá en `wt/windows` y hacé `git push origin wt/windows`. No toques main.
- Anotá en `tools/claude_windows/HANDOFF.md` las mediciones, lo que haya que cambiar en el tablero y las memorias nuevas. El integrador lo lee al mergear.
