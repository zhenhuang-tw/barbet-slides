<#
.SYNOPSIS
  把本 repo 以目錄連接（junction）登錄為 Typst local package。

.DESCRIPTION
  從 typst.toml 讀取 name / version，在
    %APPDATA%\typst\packages\local\<name>\<version>
  建立指向本 repo 的 junction。之後簡報可用 #import "@local/<name>:<version>": *。
  因為是連接而非複製，repo 內的修改立即生效。可重複執行；不會刪除真實資料夾。

.PARAMETER PackageRoot
  local 命名空間的根目錄，預設 %APPDATA%\typst\packages\local。

.PARAMETER Force
  當同名 junction 指向別處時，改指向本 repo。
#>
[CmdletBinding()]
param(
  [string]$PackageRoot = (Join-Path $env:APPDATA 'typst\packages\local'),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$manifest = Join-Path $repo 'typst.toml'
if (-not (Test-Path -LiteralPath $manifest)) { throw "找不到 typst.toml：$manifest" }

$toml = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
$name = [regex]::Match($toml, '(?m)^\s*name\s*=\s*"([^"]+)"').Groups[1].Value
$version = [regex]::Match($toml, '(?m)^\s*version\s*=\s*"([^"]+)"').Groups[1].Value
if (-not $name -or -not $version) { throw '無法從 typst.toml 解析 name / version。' }

$parent = Join-Path $PackageRoot $name
$link = Join-Path $parent $version
New-Item -ItemType Directory -Force -Path $parent | Out-Null

if (Test-Path -LiteralPath $link) {
  $item = Get-Item -LiteralPath $link -Force
  $isLink = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
  if (-not $isLink) {
    throw "$link 是真實資料夾，為避免誤刪，已中止。請自行確認後移除。"
  }
  $target = [IO.Path]::GetFullPath([string](@($item.Target)[0])).TrimEnd('\')
  $want = [IO.Path]::GetFullPath($repo).TrimEnd('\')
  if ($target -ieq $want) {
    Write-Host "已就緒：$link -> $want"
    Write-Host "import 寫法：#import `"@local/${name}:${version}`": *"
    return
  }
  if (-not $Force) {
    throw "$link 已指向 $target。若要改指向本 repo，請加 -Force。"
  }
  # 只移除連接本身，不遞迴刪除目標內容
  [IO.Directory]::Delete($link, $false)
}

New-Item -ItemType Junction -Path $link -Value $repo | Out-Null
Write-Host "已建立：$link -> $repo"
Write-Host "import 寫法：#import `"@local/${name}:${version}`": *"
