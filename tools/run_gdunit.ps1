param(
    [string]$TestPath = 'res://tests/runtime',
    [switch]$ContinueOnFailure,
    [string]$ReportDirectory = 'res://reports/gdunit',
    [switch]$Headless
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$args = @('--path', $projectRoot)
if ($Headless) {
    $args += '--headless'
}
$args += @('-s', '-d', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', $TestPath, '-rd', $ReportDirectory)
if ($ContinueOnFailure) {
    $args += '--continue'
}

& "$PSScriptRoot\godot_cli.ps1" @args
$exitCode = $LASTEXITCODE

$copyArgs = @('--headless', '--path', $projectRoot, '--quiet', '-s', 'res://addons/gdUnit4/bin/GdUnitCopyLog.gd', '-a', $TestPath, '-rd', $ReportDirectory)
if ($ContinueOnFailure) {
    $copyArgs += '--continue'
}
& "$PSScriptRoot\godot_cli.ps1" @copyArgs | Out-Null

exit $exitCode
