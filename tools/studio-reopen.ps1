# 이 게임(SonarMaze)만 다시 빌드해 Studio 창 하나로 다시 연다. 다른 플레이스 창은 건드리지 않는다.
$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path -Parent $PSScriptRoot
$rojo = (Get-Command rojo -ErrorAction SilentlyContinue).Source
if (-not $rojo) { $rojo = Join-Path $env:USERPROFILE "bin\rojo.exe" }
$out = Join-Path $root "build\SonarMaze.rbxlx"
& $rojo build (Join-Path $root "default.project.json") -o $out | Out-Null
if ($LASTEXITCODE -ne 0) { "rojo build failed"; exit 1 }
Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like "*SonarMaze*" } | Stop-Process -Force -Confirm:$false
Start-Sleep -Seconds 2
$exe = (Get-Process RobloxStudioBeta | Select-Object -First 1).Path
if (-not $exe) { $exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
Start-Process -FilePath $exe -ArgumentList "`"$out`""
Start-Sleep -Seconds 25
"studio windows: " + ((Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like "*SonarMaze*" } | Measure-Object).Count)
