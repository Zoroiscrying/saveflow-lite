param(
    [int]$TimeoutSeconds = 0,
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

$effectiveTimeoutSeconds = $TimeoutSeconds
if ($effectiveTimeoutSeconds -le 0 -and $env:GODOT_CLI_TIMEOUT_SECONDS) {
    $parsedTimeoutSeconds = 0
    if ([int]::TryParse($env:GODOT_CLI_TIMEOUT_SECONDS, [ref]$parsedTimeoutSeconds)) {
        $effectiveTimeoutSeconds = $parsedTimeoutSeconds
    }
}

if ($effectiveTimeoutSeconds -le 0) {
    & $godotExe @GodotArgs
    exit $LASTEXITCODE
}

function ConvertTo-CommandLineArgument {
    param([string]$Argument)

    if ($null -eq $Argument) {
        return '""'
    }
    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashCount = 0
    foreach ($char in $Argument.ToCharArray()) {
        if ($char -eq '\') {
            $backslashCount += 1
            continue
        }
        if ($char -eq '"') {
            [void]$builder.Append('\' * (($backslashCount * 2) + 1))
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append('\' * $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($char)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append('\' * ($backslashCount * 2))
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

$processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
$processStartInfo.FileName = $godotExe
$processStartInfo.UseShellExecute = $false
$processStartInfo.Arguments = (($GodotArgs | ForEach-Object { ConvertTo-CommandLineArgument $_ }) -join ' ')

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $processStartInfo

[void]$process.Start()
if (-not $process.WaitForExit($effectiveTimeoutSeconds * 1000)) {
    Write-Error "Godot CLI timed out after $effectiveTimeoutSeconds seconds. Terminating process $($process.Id)."
    try {
        $process.Kill($true)
    } catch {
        try {
            $process.Kill()
        } catch {
        }
    }
    $process.Dispose()
    exit 124
}

$exitCode = $process.ExitCode
$process.Dispose()
exit $exitCode
