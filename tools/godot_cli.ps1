param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$defaultGodot = 'F:\Engines\Godot\Godot4-6-2-Csharp\Godot_v4.6.2-stable_mono_win64_console.exe'
$godotExe = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { $defaultGodot }

if (-not (Test-Path $godotExe)) {
    throw "Godot executable not found: $godotExe"
}

$godotUserRoot = Join-Path $projectRoot '.godot_user'
$appData = Join-Path $godotUserRoot 'AppData\Roaming'
$localAppData = Join-Path $godotUserRoot 'AppData\Local'
$tempDir = Join-Path $godotUserRoot 'Temp'

New-Item -ItemType Directory -Force -Path $appData | Out-Null
New-Item -ItemType Directory -Force -Path $localAppData | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$env:APPDATA = $appData
$env:LOCALAPPDATA = $localAppData
$env:TEMP = $tempDir
$env:TMP = $tempDir

& $godotExe @GodotArgs
exit $LASTEXITCODE
