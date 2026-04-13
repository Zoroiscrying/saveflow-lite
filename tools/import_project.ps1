param()

$projectRoot = Split-Path -Parent $PSScriptRoot
& "$PSScriptRoot\godot_cli.ps1" --headless --path $projectRoot --editor --quit
exit $LASTEXITCODE
