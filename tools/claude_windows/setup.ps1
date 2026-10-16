# Prepara Windows para seguir Epiphany con Claude Code: clona los repos, arma el worktree wt/windows, el perfil de
# Claude (skills, plugins, memoria) y anota las rutas de esta máquina. Se puede volver a correr.
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -Godot "C:\ruta\Godot_v4.8-beta1_win64.exe"
param(
	[Parameter(Mandatory = $true)][string]$Godot,
	[string]$Root = (Join-Path $env:USERPROFILE "Proyectos\Godot"),
	[string]$ClaudeProfile = (Join-Path $env:USERPROFILE ".claude-profiles\personal")
)
$ErrorActionPreference = "Stop"

function Need([string]$Command, [string]$Install) {
	if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
		throw "Falta '$Command'. Instalalo con: $Install (y abrí una consola nueva)"
	}
}

function Clone([string]$Name, [string]$Path) {
	if (Test-Path $Path) {
		return
	}
	git clone "git@github.com:dannroda/$Name.git" $Path
	if ($LASTEXITCODE -ne 0) {
		git clone "https://github.com/dannroda/$Name.git" $Path
	}
	if ($LASTEXITCODE -ne 0) {
		throw "No se pudo clonar $Name"
	}
}

function ProjectKey([string]$Path) {
	return ($Path -replace '[^A-Za-z0-9]', '-')
}

Need git "winget install Git.Git"
Need node "winget install OpenJS.NodeJS.LTS"
if (-not (Test-Path $Godot)) {
	throw "No existe $Godot"
}
$Godot = (Resolve-Path $Godot).Path

New-Item -ItemType Directory -Force $Root | Out-Null
$project = Join-Path $Root "project-epiphany"
$compass = Join-Path $Root "scope-compass"
$worktree = Join-Path $Root "epiphany-wt\windows"
Clone "project-epiphany" $project
Clone "scope-compass" $compass
git -C $project fetch origin
if (-not (Test-Path $worktree)) {
	git -C $project rev-parse --verify --quiet wt/windows | Out-Null
	if ($LASTEXITCODE -eq 0) {
		git -C $project worktree add $worktree wt/windows
	} elseif (git -C $project branch -r --list "origin/wt/windows") {
		git -C $project worktree add -b wt/windows $worktree origin/wt/windows
	} else {
		git -C $project worktree add -b wt/windows $worktree origin/main
	}
}
$kit = Join-Path $worktree "tools\claude_windows"

[Environment]::SetEnvironmentVariable("CLAUDE_CONFIG_DIR", $ClaudeProfile, "User")
$env:CLAUDE_CONFIG_DIR = $ClaudeProfile
$skills = Join-Path $ClaudeProfile "skills"
New-Item -ItemType Directory -Force $skills | Out-Null
Copy-Item -Recurse -Force (Join-Path $kit "skills\*") $skills
$settings = Join-Path $ClaudeProfile "settings.json"
if (-not (Test-Path $settings)) {
	Copy-Item (Join-Path $kit "settings.json") $settings
}

$machine = @"
---
name: windows-machine
description: Windows paths on this PC (Godot, repos, worktree, Claude profile); written by tools/claude_windows/setup.ps1
metadata:
  type: reference
---

- Godot 4.8-beta1: ``$Godot``
- Main clone (read only for this session): ``$project``
- Worktree to work in (branch wt/windows): ``$worktree``
- Board, read only: ``node "$compass\hub\bin\scompass.js" --dir "$project" <command>``
- Claude profile (CLAUDE_CONFIG_DIR): ``$ClaudeProfile``
- HP monitor screen index for ``--screen``: not checked yet (see [[windows-session]])
"@
foreach ($dir in @($project, $worktree)) {
	$memory = Join-Path $ClaudeProfile ("projects\" + (ProjectKey $dir) + "\memory")
	New-Item -ItemType Directory -Force $memory | Out-Null
	Copy-Item -Force (Join-Path $kit "memory\*.md") $memory
	[IO.File]::WriteAllText((Join-Path $memory "windows-machine.md"), $machine)
	Add-Content -Encoding UTF8 (Join-Path $memory "MEMORY.md") "- [windows-machine](windows-machine.md) - Godot, repos, worktree and profile paths on this Windows PC"
}

Write-Host ""
Write-Host "Listo." -ForegroundColor Green
Write-Host "1. Cerrá y abrí VS Code/VSCodium (toma CLAUDE_CONFIG_DIR) y abrí la carpeta: $worktree"
Write-Host "2. En Claude Code: /login con tu cuenta y /plugin para instalar los de settings.json si no aparecen."
Write-Host "3. Primer pedido sugerido: 'leé tools/claude_windows/README.md y corré la medición de shaders'."
