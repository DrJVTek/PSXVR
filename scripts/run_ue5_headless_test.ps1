$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$uproject = Join-Path $root "PSXVR.uproject"
if (-not (Test-Path $uproject)) { throw "Missing uproject: $uproject" }

function Find-UnrealEditorExe {
  $candidates = @(
    $env:UE_EDITOR_EXE,
    "C:\Program Files\Epic Games\UE_5.5\Engine\Binaries\Win64\UnrealEditor.exe",
    "C:\Program Files\Epic Games\UE_5.4\Engine\Binaries\Win64\UnrealEditor.exe",
    "C:\Program Files\Epic Games\UE_5.3\Engine\Binaries\Win64\UnrealEditor.exe",
    "C:\Program Files\Epic Games\UE_5.2\Engine\Binaries\Win64\UnrealEditor.exe",
    "C:\Program Files\Epic Games\UE_5.1\Engine\Binaries\Win64\UnrealEditor.exe"
  ) | Where-Object { $_ -ne $null -and $_.Length -gt 0 }

  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }

  # Try PATH
  $cmd = Get-Command "UnrealEditor.exe" -ErrorAction SilentlyContinue
  if ($cmd -and (Test-Path $cmd.Source)) { return $cmd.Source }

  return $null
}

$editor = Find-UnrealEditorExe
if (-not $editor) {
  throw "UnrealEditor.exe not found. Set UE_EDITOR_EXE env var to full path."
}

Write-Host "Editor: $editor"
Write-Host "Project: $uproject"

$logFile = Join-Path $root "Saved\Logs\UE5_headless_test.log"
if (Test-Path $logFile) { Remove-Item $logFile -Force }

# Start on the default map configured in DefaultEngine.ini (/Game/ue5_test)
# Let it run for a while to generate PSXVR/logs/*.log (R3000Emu OutputDir).
$args = @(
  "`"$uproject`"",
  "/Game/ue5_test",
  "-game",
  "-log",
  "-nosplash",
  "-nop4",
  "-unattended",
  "-nullrhi",
  "-NoShaderCompile"
)

Write-Host "Args: $($args -join ' ')"

$p = Start-Process -FilePath $editor `
  -ArgumentList ($args -join ' ') `
  -WorkingDirectory $root `
  -RedirectStandardOutput (Join-Path $root "Saved\Logs\UE5_headless_stdout.txt") `
  -RedirectStandardError  (Join-Path $root "Saved\Logs\UE5_headless_stderr.txt") `
  -PassThru -NoNewWindow

Write-Host "PID: $($p.Id)"
Start-Sleep -Seconds 120

if (-not $p.HasExited) {
  Write-Host "Stopping UE after 120s..."
  Stop-Process -Id $p.Id -Force
}

Write-Host "Done. Check:"
Write-Host "  $root\logs\system.log"
Write-Host "  $root\logs\cdrom.log"
Write-Host "  $root\logs\spu.log"

