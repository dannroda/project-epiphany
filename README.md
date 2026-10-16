# Project Epiphany *(working title)*

A top-down action-adventure in the style of *The Legend of Zelda: Link's Awakening* (Switch remake), built in 3D with a tilted camera so it reads like a 2D Zelda. You explore a small overworld, find the tools that open new paths, clear four dungeons and end in an ancient temple where something is waking up. Its guardian waits at the bottom: a giant floating eye with hands.

The original jam theme, *Imminent Doom*, still sets the tone. The end is felt through light, sound, cracks, tremors and stone tablets, never through a timer.

- **Engine:** Godot 4.8 (Forward+)
- **Version:** 0.2, playable from the title screen to the ending
- **Status:** in active development. The setting is Andean-inspired for now and not final.
- **Design document:** [`gdd.md`](gdd.md) (Spanish)
- **Task board:** [`docs/tareas.md`](docs/tareas.md) (Spanish, generated from `compass/`)

---

## What's in the game

### World
- **Overworld:**
  - terraces, cliffs, caves and a lagoon;
  - secret trees and cracked walls;
  - zones hidden behind a fog veil until you first visit them;
  - fast-travel portals and a pause map with pins.
- **Caves:** bomb, bush, grotto, shrine and spring caves, each with its own secret or upgrade.
- **Dungeons.** Each one guards a key item behind a sub-boss that can be beaten without that item. No item ever gates content in an earlier dungeon.

| # | Dungeon | Item | Sub-boss |
|---|---|---|---|
| D1 | La Chullpa (burial tower) | Feather (jump) | Mummy Guardian |
| D2 | La Queñoa Vigía (watch tree) | Bow and arrows | Watcher Eye |
| D3 | El Santuario de Totora (reed sanctuary) | Hookshot | Amaru (young serpent); the boss is Yacumama |
| D4 | El Intihuatana de la Cumbre (summit) | Mirror shield | Young Kuntur (condor) |
| — | El Templo (final temple) | Golden sword (optional) | A boss rush: one earlier sub-boss per wing |

- **Dungeon structure:**
  - small keys and a boss key that needs backtracking with the dungeon's item;
  - a map, a compass and multi-floor layouts;
  - rooms that center on the camera and hide the others, in the Link's Awakening style.
- **Final boss:** the Eye with hands, a multi-phase fight.
  - The hands slam the floor, sweep the arena and grab you.
  - The eye fires orbs and, once both hands are out of play, sweeps a laser across the arena.
  - Stunning the hands and the eye opens the boss up to damage.

### Combat and items
- **Zelda-style combat:**
  - Z-targeting, which also raises the guard;
  - directional shield blocking and a sword stab while guarding;
  - dodge rolls, hit-stop, knockback and a blade trail.
- **Items:**
  - **Equipment:** sword, wood shield, mirror shield (reflects projectiles and light beams), tunic and reinforced mail.
  - **Usable items:** bombs (place, or lift and throw), bow, feather, hookshot, dash sandals, hammer (strong hits), and bottles with potions or holy water.
  - **Upgrades:** heart containers, 13 heart pieces and a bigger quiver.
- **Enemies:**
  - skeletons (plain, shielded, armored and archers), each themed per dungeon;
  - turrets and wandering sentinels that alert and search;
  - a pack-hunting Andean fox (atoq);
  - wave encounters.
- **Puzzles:**
  - push blocks;
  - floor switches (block, weight and strong-hit types);
  - eye switches you hit with arrows;
  - light beams and mirrors, gates, bridges and spike traps.

### Everything around it
- **Controls:** gamepad and keyboard/mouse are both first-class. That includes analog and mouse aiming, input prompts that follow the last device used, and a controls screen with a drawn gamepad and keyboard.
- **Menus:** a pause menu with inventory pages for equipment and items, a map and a system tab. Text boxes and dialogue use Dialogue Manager.
- **Saves:**
  - three player slots plus autosave;
  - atomic writes with a backup copy;
  - a checksum that flags hand-edited saves, and encryption in release builds.
- **Languages:** Spanish and English (`translations/`).
- **Local co-op (in progress):** a second player joins with Start on another pad. Each player has their own X/Y buttons and colors, a fallen player floats as a spirit until revived, and the camera frames both. The project is planned to grow into Four Swords-style co-op.

---

## How it's built

The project is **data first**. Items, attacks, enemies, flags, dungeon layouts and saves are Godot Resources that you can inspect and validate in the editor. Scenes put them together, and code only reacts to them.

- **Items:**
  - `ItemData` holds the static data.
  - A stateless `ItemBehavior` strategy defines what the item does: melee, projectile, place, jump, hook, strike or consumable.
  - `ItemUseContext` tells the behavior who is using the item.
- **Combat pipeline:**
  - `AttackData` sets the timing windows of an attack.
  - `AttackRunner` follows the animation's progress and turns the `Hitbox` on and off.
  - The hitbox builds a `DamageInfo` and hands it to the target's `Hurtbox`.
  - The owner of the hurtbox decides what the hit means: a block, damage or a reflection.
  - The player and every enemy use this same pipeline.
- **Components:** `Health`, `Hitbox`, `Hurtbox`, `HitFlash`, `PersistentFlag` and `Interactable`, each placed as a node in the scenes.
- **AI:** LimboAI drives the AI.
  - The player runs a hierarchical state machine with an event table and an input buffer.
  - Enemies run behavior trees whose custom tasks live in `ai/tasks/`.
  - The boss has one phase state machine per phase, with a behavior tree in each, and chooses attacks from utility-scored `BossAttack` resources.
- **State and flow:** global autoloads for game state, players, saves, scene flow, the menu stack, input device, settings, music, game feel (`Feel`), logging and the debug overlay. Player state, such as current HP, is global and goes into the save.
- **Flags:** every flag is defined once in `data/flag_registry.tres`, with a description and a per-dungeon prefix. Nodes read flags through `PersistentFlag` exports, which warn in the editor when misconfigured.
- **Dungeon graphs:** each dungeon has a `DungeonGraph` resource in `data/dungeons/`, describing its areas, locks and what each spot gives. A test checks the graph against the real scene and searches every path for dead ends, such as a key spent on the wrong door or a drop with no way back.

---

## Tools used

### Engine and addons
| Tool | Used for |
|---|---|
| [Godot 4.8](https://godotengine.org) (beta 1) | Engine and editor. The project uses 4.8 features such as contact shadows, multi-bounce AO, allocation-free physics queries, decals with DrawableTexture and the shader baker. |
| [LimboAI](https://github.com/limbonaut/limboai) 1.8 | Behavior trees and hierarchical state machines (player, enemies, boss). The editor library carries a small local UI patch; release exports use the official template. |
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) 4.1 | Dialogue, signs and stone tablets. |
| [Editor debugger](https://github.com/Zylann/godot_editor_debugger_plugin) (Zylann) | Inspecting the editor's own scene tree. |

### Tools made for this project
- **Epiphany Tools** (`addons/epiphany_tools/`), an editor plugin with:
  - **Save Inspector dock:**
    - opens any save slot or debug scenario;
    - flags grouped by place, with search and a "changed only" filter;
    - "where is this flag used" with jump-to;
    - tabs for player, inventory and dungeons;
    - a key-by-key compare against another save;
    - copy to a player slot, and undo/redo;
    - detects when the game rewrites the open file, and launches the game from that save.
  - **Runtime logging and debug overlay:** `Log` and `DebugOverlay`.
  - **Scene import hook** for the Blender models.
- **Editor Bridge** (`addons/editor_bridge/`): a small HTTP endpoint on `localhost:4713` that lets scripts drive the open editor (open scenes, select nodes, save, bake navmeshes) instead of launching a second editor.
- **Scope Compass** (`addons/scope_compass/` and `compass/`): the in-house project board. It keeps milestones, tasks, checklists, links and playtest sessions as JSON in the repo. It comes with a web hub, a Godot dock and the `scompass` CLI, and exports to [`docs/tareas.md`](docs/tareas.md).
- **Debug scenarios** (`debug/scenarios/*.cfg`): signed save files that start the game at a given point. For example, `-- --scenario=pre_boss` starts right before the boss.

### Art and level pipeline
- **Blender:**
  - All own models are in `art/blender/*.blend`: the player, enemies, bosses, props, dungeon kits and terrain tests.
  - They are built and exported by Python scripts in `tools/blender/` and share one palette module (`tools/blender/epi`).
  - Some modeling sessions used the official Blender MCP server, so the AI assistant could inspect and edit scenes in a running Blender.
- **Level tools** (GDScript tools in `tools/`, run headless):
  - `la_walls.gd` bakes the Link's Awakening-style wall pieces, and doubles walls into the levels.
  - Other scripts build the temple and overworld kits, decorate levels, render the item icons and bake the overworld navmesh.
  - `dungeon_graph_mermaid.gd` draws the dungeon graphs as Mermaid diagrams.
- **Third-party art:** KayKit (Adventurers and character animations) and Kenney (input prompts, UI borders, skyboxes, development textures), plus the Prototype Textures pack.

### Video
- **Teaser rig** (`tools/teaser/`):
  - Shots are scripted in a scene: the scenario, the player's steps, camera angles and the random seed.
  - The same action can be recorded from several angles, which gives multi-camera footage for editing.
  - `record.sh` records every shot, and `edit.sh` cuts them together with **ffmpeg**. ffmpeg is also used to convert recordings for sharing.
- **Title flyover** (`tools/title_flyover/`): a scripted camera path over the overworld for the title screen.

### Builds
- **Export presets:** Linux and Windows (release and debug), plus macOS, Web and Android.
- **Build scripts:** `tools/build.sh` and `tools/build_icon.sh`.
- **Windows setup** (`tools/claude_windows/`): setup scripts, a shader-measuring script and a handoff kit for work on the Windows machine.

### AI-assisted development
Development is done with **[Claude Code](https://claude.com/claude-code)** (Anthropic), working with the developer through the editor bridge, the board CLI and the test runner.
- **Parallel sessions:**
  - Several sessions work at once, each in its own **git worktree** and branch (`../epiphany-wt/<name>`, `wt/<name>`) and each with its own area: bugs and integration, art, overworld, and dungeon design.
  - The integrator session merges into `main`, runs the full test suite and pushes.
- **Ground rules:**
  - Editor saves from the developer always win over regenerated files.
  - Nothing is merged while the editor is open.
  - Each board task gets its own commit.
- **Reviews with Godot skills:** five reviews of the whole codebase ran on 2026-10-16, one per skill: architecture, code review, signal and autoload communication, gameplay patterns, and data-driven design. Their findings became milestone **M16, Code health** on the board. The confirmed bugs were fixed first, each with a regression test:
  - the boss laser hitting only once per fight;
  - a heart container reviving a co-op spirit;
  - a wrong item id in the temple graph;
  - a group-name typo that kept the title flyover from hiding the fog veils;
  - malformed saves crashing on item buttons.

  The skills live in `tools/claude_windows/skills/`.

---

## Repository layout

| Path | Contents |
|---|---|
| `src/` | Game code and scenes: `components/`, `combat/`, `entities/` (enemies, sub-bosses, boss), `items/`, `world/` (rooms, puzzles, props, overworld), `ui/`, `state/`, `save/`, `flow/`, `feel/`, `audio/`, `input/`, `shaders/` |
| `player/` | Player scene, state machine, states and components (equipment, shield, targeting, aim) |
| `ai/tasks/` | Custom LimboAI behavior-tree tasks |
| `data/` | Resources: items, attacks, entity configs, boss attacks and behavior trees, dungeon graphs, flag registry, kits |
| `levels/` | Overworld, caves, dungeons, temple and test levels |
| `art/` | Blender sources and logo |
| `assets/` | Imported models, textures, audio, fonts and third-party packs |
| `tests/` | Headless test suite (~120 files) and its parallel runner |
| `tools/` | Build, bake, Blender, teaser and Windows tools |
| `debug/scenarios/` | Signed save scenarios for jumping to any point of the game |
| `translations/` | Spanish and English strings |
| `compass/` | Scope Compass board data (milestones, tasks, playtests) |
| `addons/` | LimboAI, Dialogue Manager, Zylann's editor debugger, and the in-house Epiphany Tools, Editor Bridge and Scope Compass |

---

## Running it

1. Open the project with **Godot 4.8 beta 1**. LimboAI ships as a GDExtension in `addons/limboai/bin/`.
2. Press Play. The game starts at the title screen.
3. To start at a given point, pass a scenario: `godot --path . -- --scenario=start` (any file in `debug/scenarios/`, without the extension). The Save Inspector's **Jugar** button does the same from the editor.

### Tests
The suite runs headless, split over several processes:

```sh
godot --headless --path . --script res://tests/run_tests.gd -- --jobs=4
godot --headless --path . --script res://tests/run_tests.gd -- --only=test_boss.gd,test_player.gd
```

It has about 600 tests. They cover the player and combat, every enemy and boss, items, puzzles, saves and scenarios, dungeon reachability, the UI screens, input prompts, co-op rules and the export presets. On Linux, run it with `/dev/input` hidden (for example `bwrap --dev-bind / / --tmpfs /dev/input godot …`), so a connected gamepad doesn't feed input into the tests.

---

## History

The project started on 2026-09-28 as a game jam entry for the theme *Imminent Doom*. It grew through 16 milestones, all on the board:
- M0–M9: the player refactor, combat, targeting, inventory and UI, world interaction, secondary items, the dungeon framework, overworld, dungeon content and the boss;
- M10: wrapping up the demo;
- M11: polish;
- M12: own art from Blender;
- M13–M14: local and online co-op, planned;
- M15: optimization;
- M16: code health.
