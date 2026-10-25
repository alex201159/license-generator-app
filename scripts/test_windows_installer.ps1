$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$installer = Join-Path (Get-Location) 'dist\Gerador-de-Licencas-Setup.exe'
$installDirectory = Join-Path $env:RUNNER_TEMP 'Gerador-de-Licencas-Installed'
if (Test-Path -LiteralPath $installDirectory) { throw 'A pasta de teste do instalador ja existe.' }
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installDirectory`"")
$setup = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
if ($setup.ExitCode -ne 0) { throw "A instalacao falhou: $($setup.ExitCode)" }
$executable = Join-Path $installDirectory 'license_generator_app.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw 'O instalador nao criou o executavel.' }
& ./scripts/test_windows_startup.ps1 -AppPath $executable -ColdStartup
Write-Host 'OK: aplicativo instalado, servidor e inicializacao automatica verificados.'

$instances = @(Get-Process -Name 'license_generator_app' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $executable })
$instances | Stop-Process -Force
foreach ($instance in $instances) { $instance.WaitForExit(10000) | Out-Null }
$history = Join-Path $env:APPDATA 'com.example\license_generator_app\license_history.json'
if (-not (Test-Path -LiteralPath $history)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $history) -Force | Out-Null
    Set-Content -LiteralPath $history -Value '[]' -Encoding utf8
}
$historyHash = (Get-FileHash -LiteralPath $history -Algorithm SHA256).Hash
$uninstaller = Join-Path $installDirectory 'unins000.exe'
$removed = Start-Process -FilePath $uninstaller -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
if ($removed.ExitCode -ne 0) { throw 'A desinstalacao falhou.' }
if (Test-Path -LiteralPath $executable) { throw 'O executavel permaneceu apos a desinstalacao.' }
if (-not (Test-Path -LiteralPath $history)) { throw 'O historico foi removido na desinstalacao.' }
if ((Get-FileHash -LiteralPath $history -Algorithm SHA256).Hash -ne $historyHash) {
    throw 'O historico foi alterado na desinstalacao.'
}
$runKey = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
if ($runKey.GeradorLicencasServer -or $runKey.LCCargaServer) { throw 'A inicializacao permaneceu cadastrada apos a desinstalacao.' }
Write-Host 'OK: desinstalacao preserva o historico e remove a inicializacao automatica.'
