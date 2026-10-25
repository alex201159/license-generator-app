param(
    [string]$AppPath = (Join-Path $PSScriptRoot 'license_generator_app.exe'),
    [ValidateRange(1, 65535)][int]$Port = 8787,
    [switch]$ColdStartup
)
$ErrorActionPreference = 'Stop'
$resolvedApp = (Resolve-Path -LiteralPath $AppPath).Path
$appDirectory = Split-Path -Parent $resolvedApp
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$expectedCommand = '"' + $resolvedApp + '" --startup'

# Opening normally registers the current installation path and starts the server.
Start-Process -FilePath $resolvedApp -WorkingDirectory $appDirectory | Out-Null
$registered = $null
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $registered = Get-ItemPropertyValue -LiteralPath $runKey -Name 'LCCargaServer' -ErrorAction SilentlyContinue
    if ($registered -eq $expectedCommand) { break }
    Start-Sleep -Milliseconds 500
}
if ($registered -ne $expectedCommand) {
    throw 'A inicializacao automatica nao foi registrada para este executavel. Abra o programa novamente apos fechar uma versao antiga.'
}
Write-Host 'OK: inicializacao registrada para o usuario atual.'

$headers = @{ Authorization = 'Bearer 88336092' }
$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $history = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/history" -Headers $headers -TimeoutSec 2
        if ($null -eq $history.entries) { throw 'Resposta do servidor invalida.' }
        $ready = $true
        break
    } catch {
        Start-Sleep -Milliseconds 500
    }
}
if (-not $ready) { throw 'O servidor nao respondeu com a senha configurada.' }
Write-Host 'OK: servidor respondeu com a senha configurada.'

# Simulate the registered startup command without signing the user out.
Start-Process -FilePath $resolvedApp -WorkingDirectory $appDirectory -ArgumentList '--startup' | Out-Null
Start-Sleep -Seconds 2
$instances = @(Get-Process -Name 'license_generator_app' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $resolvedApp })
if ($instances.Count -ne 1) { throw 'A protecao contra instancias duplicadas falhou.' }
Write-Host 'OK: uma unica instancia do aplicativo em execucao.'
if ($ColdStartup) {
    # CI-only cold start: restart the app exactly as the Windows Run entry does.
    $instances | Stop-Process -Force
    foreach ($instance in $instances) { $instance.WaitForExit(10000) | Out-Null }
    Start-Process -FilePath $resolvedApp -WorkingDirectory (Join-Path $env:WINDIR 'System32') -ArgumentList '--startup' | Out-Null
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            $history = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/history" -Headers $headers -TimeoutSec 2
            if ($null -eq $history.entries) { throw 'Resposta do servidor invalida.' }
            $ready = $true
            break
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { throw 'O servidor nao iniciou no teste de arranque automatico.' }
    $instances = @(Get-Process -Name 'license_generator_app' | Where-Object { $_.Path -eq $resolvedApp })
    if ($instances.Count -ne 1) { throw 'Numero de instancias incorreto apos arranque automatico.' }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LCCargaWindowState {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsIconic(IntPtr window);
}
'@
    $minimized = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        $instances[0].Refresh()
        if ([LCCargaWindowState]::IsIconic($instances[0].MainWindowHandle)) { $minimized = $true; break }
        Start-Sleep -Milliseconds 250
    }
    if (-not $minimized) {
        throw 'O aplicativo nao iniciou minimizado.'
    }
    Write-Host 'OK: arranque automatico minimizado com servidor ativo.'
}
Write-Host 'Para conferir o login automatico, saia e entre novamente na mesma conta do Windows.'
Write-Host 'O aplicativo foi mantido aberto para disponibilizar o servidor.'
