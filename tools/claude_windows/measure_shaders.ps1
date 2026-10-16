# Mide en Windows cuánto ayuda el shader baker (D3D12, el driver del proyecto; Vulkan como comparación) y qué efectos
# compilan pipelines al aparecer. Exporta dos builds de debug ("Windows (debug)" con y sin baker) en debug\tmp\shaders,
# corre cada una en frío (caché vacía) y en caliente con tools/pipeline_probe.gd, y junta las líneas PROBE en
# debug\tmp\shaders\resultados.txt. export_presets.cfg vuelve a quedar como estaba.
#   powershell -ExecutionPolicy Bypass -File tools\claude_windows\measure_shaders.ps1 -Godot "C:\...\godot.exe" -ClearDriverCache
param(
	[Parameter(Mandatory = $true)][string]$Godot,
	[string]$Project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
	[int]$Runs = 3,
	[int]$Screen = 1,
	# También borra la caché de shaders del driver (AMD/NVIDIA/D3D): es el primer arranque real de un jugador. Los
	# demás juegos la rehacen solos la próxima vez que abren.
	[switch]$ClearDriverCache
)
$ErrorActionPreference = "Stop"
$out = Join-Path $Project "debug\tmp\shaders"
$presets = Join-Path $Project "export_presets.cfg"
$userDir = Join-Path $env:APPDATA "Godot\app_userdata\Project Epiphany"
$log = Join-Path $userDir "logs\godot.log"
$results = Join-Path $out "resultados.txt"
$original = [IO.File]::ReadAllText($presets)
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Preset([bool]$Bake) {
	$text = $original
	$text = $text.Replace('include_filter="data/dialogue/*.dialogue, build_info.cfg"' + "`n" + 'exclude_filter="tests/*, *.md"' + "`n" + 'export_path="builds/windows-debug/',
		'include_filter="data/dialogue/*.dialogue, build_info.cfg, debug/scenarios/*.cfg"' + "`n" + 'exclude_filter="tests/*, *.md"' + "`n" + 'export_path="builds/windows-debug/')
	if (-not $text.Contains("debug/scenarios/*.cfg")) {
		throw 'El include_filter de "Windows (debug)" cambió: actualizá Preset en measure_shaders.ps1'
	}
	$header = [regex]::Match($text, '\[preset\.(\d+)\]\s*\n+name="Windows \(debug\)"')
	if (-not $header.Success) {
		throw 'No encuentro el preset "Windows (debug)" en export_presets.cfg'
	}
	$options = "[preset.$($header.Groups[1].Value).options]"
	$value = if ($Bake) { "true" } else { "false" }
	$text = $text.Replace($options + "`n", $options + "`nshader_baker/enabled=$value`n")
	[IO.File]::WriteAllText($presets, $text, $utf8)
}

function Run([string]$Exe, [string[]]$Arguments, [int]$Seconds) {
	$process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
	if (-not $process.WaitForExit($Seconds * 1000)) {
		$process.Kill()
	}
}

function ClearCaches() {
	foreach ($name in @("shader_cache", "vulkan", "d3d12")) {
		Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $userDir $name)
	}
	if ($ClearDriverCache) {
		foreach ($dir in @("AMD\DxCache", "AMD\DxcCache", "AMD\VkCache", "NVIDIA\DXCache", "NVIDIA\GLCache", "D3DSCache")) {
			Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $env:LOCALAPPDATA $dir)
		}
	}
}

function Measure([string]$Label, [string]$Exe, [string[]]$Extra) {
	$override = "[display]`nwindow/size/no_focus=true`n[autoload]`nPipelineProbe=`"*res://tools/pipeline_probe.gd`"`n"
	[IO.File]::WriteAllText((Join-Path (Split-Path $Exe) "override.cfg"), $override, $utf8)
	Remove-Item -Force -ErrorAction SilentlyContinue $log
	Run $Exe (@("--screen", "$Screen") + $Extra + @("--", "--scenario=start")) 150
	$lines = if (Test-Path $log) { Select-String -Path $log -Pattern "^PROBE" | ForEach-Object { $_.Line } } else { @() }
	if (-not $lines) {
		$lines = @("PROBE sin resultados (¿no cargó el overworld?)")
	}
	Add-Content -Encoding UTF8 $results "== $Label"
	Add-Content -Encoding UTF8 $results $lines
	Write-Host "$Label  $($lines[0])"
}

New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue $results
$builds = @{}
try {
	foreach ($bake in @($false, $true)) {
		$name = if ($bake) { "bake" } else { "nobake" }
		Preset $bake
		$exe = Join-Path $out "$name\epi.exe"
		New-Item -ItemType Directory -Force (Split-Path $exe) | Out-Null
		Write-Host "Exportando $name..."
		Run $Godot @("--path", "`"$Project`"", "--export-debug", "`"Windows (debug)`"", "`"$exe`"") 1800
		if (-not (Test-Path $exe)) {
			throw "No se exportó $exe"
		}
		$builds[$name] = $exe
	}
} finally {
	[IO.File]::WriteAllText($presets, $original, $utf8)
}

foreach ($k in 1..$Runs) {
	foreach ($name in @("nobake", "bake")) {
		ClearCaches
		Measure "$name d3d12 frio $k" $builds[$name] @()
		Measure "$name d3d12 caliente $k" $builds[$name] @()
	}
	ClearCaches
	Measure "nobake vulkan frio $k" $builds["nobake"] @("--rendering-driver", "vulkan")
	Measure "nobake vulkan caliente $k" $builds["nobake"] @("--rendering-driver", "vulkan")
}
Write-Host ""
Write-Host "Resultados completos en $results" -ForegroundColor Green
