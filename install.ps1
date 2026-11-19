<#
.SYNOPSIS
  Registers this repository as a Typst local package via a directory junction.

.DESCRIPTION
  Reads "name" and "version" from typst.toml, then creates a junction at
    %APPDATA%\typst\packages\local\<name>\<version>
  pointing back at this repository, so a deck can use
    #import "@local/<name>:<version>": *
  Because it is a junction rather than a copy, edits inside the repo take
  effect immediately. The script is safe to re-run and never deletes a real
  (non-junction) directory.

.PARAMETER PackageRoot
  Root of the "local" namespace. Defaults to %APPDATA%\typst\packages\local.

.PARAMETER Force
  When a junction with the same name points somewhere else, repoint it to
  this repository instead of aborting.
#>
[CmdletBinding()]
param(
  [string]$PackageRoot = (Join-Path $env:APPDATA 'typst\packages\local'),
  [switch]$Force
)

# Works on Windows PowerShell 5.1 and PowerShell 7+.
# Deliberately avoids:
#   - $IsWindows (undefined on 5.1)
#   - [IO.Path]::TrimEndingDirectorySeparator (undefined on .NET Framework)
#   - [System.IO.Path]::IsPathRooted($null) (throws on some versions)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
  param([Parameter(Mandatory)][string]$Path)
  # GetFullPath normalizes separators and resolves "." and "..".
  return [IO.Path]::GetFullPath($Path)
}

# Compares two filesystem paths case-insensitively and without trailing
# separators, so "C:\repo\" and "c:\repo" are treated as identical.
function Test-SamePath {
  param([string]$Left, [string]$Right)
  if (-not $Left -or -not $Right) { return $false }
  $normalize = {
    param([string]$Value)
    return (Resolve-FullPath $Value).TrimEnd([char]'\', [char]'/')
  }
  return ((& $normalize $Left) -ieq (& $normalize $Right))
}

# Returns the junction/symlink target as a full path, or $null when it cannot
# be determined. Handles file symlinks (Target is a string) and directory
# junctions/symlinks (Target is a string array).
function Get-LinkTarget {
  param([Parameter(Mandatory)][IO.FileSystemInfo]$Item)
  $raw = $Item.Target
  if (-not $raw) { return $null }
  $candidate = $Item.PSObject.Properties['LinkTarget']
  if ($candidate -and $candidate.Value) { $raw = $candidate.Value }
  $first = @($raw)[0]
  if (-not $first) { return $null }
  try {
    return (Resolve-FullPath ([string]$first))
  }
  catch {
    return $null
  }
}

$repo = $PSScriptRoot
if (-not $repo) { throw 'Cannot determine the repository path ($PSScriptRoot is empty).' }
$repo = Resolve-FullPath $repo

if (-not $env:APPDATA) { throw 'Environment variable APPDATA is not set.' }
$PackageRoot = Resolve-FullPath $PackageRoot

$manifest = Join-Path $repo 'typst.toml'
if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
  throw "typst.toml was not found at: $manifest"
}

$toml = $null
try {
  $toml = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
}
catch {
  throw "Failed to read typst.toml: $($_.Exception.Message)"
}
if (-not $toml) { throw 'typst.toml is empty.' }

# Only match inside the [package] table so unrelated keys cannot be picked up.
$packageSection = [regex]::Match(
  $toml,
  '(?mis)^[ \t]*\[package\][ \t]*\r?\n(.*?)(?=^[ \t]*\[|\z)'
)
if (-not $packageSection.Success) { throw 'typst.toml has no [package] table.' }
$packageText = $packageSection.Groups[1].Value

$name = [regex]::Match($packageText, '(?m)^\s*name\s*=\s*"([^"]+)"').Groups[1].Value
$version = [regex]::Match($packageText, '(?m)^\s*version\s*=\s*"([^"]+)"').Groups[1].Value
if (-not $name) { throw 'Could not parse "name" from the [package] table in typst.toml.' }
if (-not $version) { throw 'Could not parse "version" from the [package] table in typst.toml.' }

$parent = Join-Path $PackageRoot $name
$link = Join-Path $parent $version

# Entry point of the package for Typst.
$entrypoint = [regex]::Match($packageText, '(?m)^\s*entrypoint\s*=\s*"([^"]+)"').Groups[1].Value
if (-not $entrypoint) { $entrypoint = 'lib.typ' }
$entryPath = Join-Path $repo $entrypoint
if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
  Write-Warning "Entrypoint '$entrypoint' listed in typst.toml was not found in $repo."
}

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $PackageRoot | Out-Null
}
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$importHint = '#import "@local/{0}:{1}": *' -f $name, $version

if (Test-Path -LiteralPath $link) {
  # Test-Path follows junctions; verify the item is actually a link first.
  $item = Get-Item -LiteralPath $link -Force
  $isLink = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
  if (-not $isLink) {
    throw ("'$link' already exists and is a real directory, not a junction. " +
      'Aborting to avoid deleting your data. Remove or rename it manually, then re-run.')
  }

  $target = Get-LinkTarget -Item $item
  if (-not $target) {
    throw ("'$link' is a junction/symlink but its target cannot be resolved. " +
      'It may be broken or point to a disconnected drive. Remove it manually, then re-run.')
  }

  if (Test-SamePath -Left $target -Right $repo) {
    Write-Host "Already registered: $link -> $target"
    Write-Host "Use in a deck: $importHint"
    return
  }

  if (-not $Force) {
    throw ("'$link' already points to '$target'. Re-run with -Force to repoint it " +
      "to '$repo'.")
  }

  # Remove only the junction itself; the old target's contents are untouched.
  try {
    [IO.Directory]::Delete($link, $false)
  }
  catch {
    throw ("Failed to remove the existing junction '$link': $($_.Exception.Message). " +
      "If the target '$target' no longer exists, delete the junction manually.")
  }
}

# Guard against a race between the checks above and the creation below.
if (Test-Path -LiteralPath $link) {
  throw "'$link' appeared unexpectedly. Aborting."
}

try {
  New-Item -ItemType Junction -Path $link -Value $repo | Out-Null
}
catch {
  throw ("Failed to create the junction '$link' -> '$repo': " +
    "$($_.Exception.Message). Junctions require NTFS and do not need elevation.")
}

Write-Host "Registered: $link -> $repo"
Write-Host "Use in a deck: $importHint"
