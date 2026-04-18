[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Manifest,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$PreservedRootNames = @(
    ".git"
)

function Resolve-WorkspacePath {
    param([string]$RelativePath)
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\\$RelativePath"))
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Normalize-RelativePath {
    param([string]$Path)
    return ($Path -replace '\\', '/').TrimStart('/')
}

function Test-IsExcludedPath {
    param(
        [string]$RelativePath,
        [System.Collections.Generic.HashSet[string]]$ExcludeSet
    )

    $normalized = Normalize-RelativePath $RelativePath
    foreach ($excluded in $ExcludeSet) {
        $candidate = Normalize-RelativePath $excluded
        if ($normalized.Equals($candidate, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
        if ($normalized.StartsWith($candidate + "/", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Copy-Entry {
    param(
        [string]$SourcePath,
        [string]$DestinationRoot,
        [string]$RelativePath,
        [System.Collections.Generic.HashSet[string]]$ExcludeSet
    )

    $targetPath = Join-Path $DestinationRoot $RelativePath
    if (Test-Path -LiteralPath $SourcePath -PathType Container) {
        Get-ChildItem -LiteralPath $SourcePath -Recurse -File | ForEach-Object {
            $childRelative = $_.FullName.Substring($SourcePath.Length).TrimStart('\', '/')
            $relativeChildPath = Normalize-RelativePath (Join-Path $RelativePath $childRelative)
            if (Test-IsExcludedPath -RelativePath $relativeChildPath -ExcludeSet $ExcludeSet) {
                return
            }
            $destinationFile = Join-Path $DestinationRoot $relativeChildPath
            Ensure-ParentDirectory -Path $destinationFile
            Copy-Item -LiteralPath $_.FullName -Destination $destinationFile -Force
        }
        return
    }

    if (Test-IsExcludedPath -RelativePath $RelativePath -ExcludeSet $ExcludeSet) {
        return
    }

    Ensure-ParentDirectory -Path $targetPath
    Copy-Item -LiteralPath $SourcePath -Destination $targetPath -Force
}

function Copy-Overlay {
    param(
        [string]$OverlayPath,
        [string]$DestinationRoot
    )

    if (-not (Test-Path -LiteralPath $OverlayPath)) {
        throw "Overlay path not found: $OverlayPath"
    }

    Get-ChildItem -LiteralPath $OverlayPath -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($OverlayPath.Length).TrimStart('\', '/')
        $destinationPath = Join-Path $DestinationRoot $relativePath
        Ensure-ParentDirectory -Path $destinationPath
        Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
    }
}

$manifestPath = Resolve-Path -LiteralPath $Manifest
$manifestData = Get-Content -LiteralPath $manifestPath | ConvertFrom-Json
$workspaceRoot = Resolve-WorkspacePath "."
$destinationRoot = [System.IO.Path]::GetFullPath($Destination)

if ($Clean -and (Test-Path -LiteralPath $destinationRoot)) {
    Get-ChildItem -LiteralPath $destinationRoot -Force | ForEach-Object {
        if ($PreservedRootNames -contains $_.Name) {
            return
        }
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $destinationRoot)) {
    New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
}

$includeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$excludeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$overlayPath = $null

foreach ($item in $manifestData.include) { [void]$includeSet.Add($item) }
foreach ($item in $manifestData.exclude) { [void]$excludeSet.Add($item) }
if ($manifestData.overlay) {
    $overlayPath = Join-Path $workspaceRoot $manifestData.overlay
}

foreach ($relativePath in $includeSet) {
    if ($excludeSet.Contains($relativePath)) {
        throw "Manifest conflict: '$relativePath' is listed in both include and exclude."
    }

    $sourcePath = Join-Path $workspaceRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Included path not found: $relativePath"
    }

    Copy-Entry -SourcePath $sourcePath -DestinationRoot $destinationRoot -RelativePath $relativePath -ExcludeSet $excludeSet
}

if ($overlayPath) {
    Copy-Overlay -OverlayPath $overlayPath -DestinationRoot $destinationRoot
}

Write-Host "Exported '$($manifestData.name)' release projection to $destinationRoot"
