#Requires -RunAsAdministrator
param(
    [string]$AppPath = (Join-Path $PSScriptRoot 'license_generator_app.exe'),
    [ValidateRange(1, 65535)][int]$Port = 8787
)
$ErrorActionPreference = 'Stop'
$resolvedApp = (Resolve-Path -LiteralPath $AppPath).Path
$ruleName = "LCCarga-LAN-TCP-$Port"
Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -Name $ruleName -DisplayName "LC Carga - rede local (TCP $Port)" `
    -Direction Inbound -Action Allow -Program $resolvedApp -Protocol TCP `
    -LocalPort $Port -Profile Private -RemoteAddress LocalSubnet -EdgeTraversalPolicy Block | Out-Null
Write-Host "Acesso liberado na porta $Port para a rede local no perfil Privado."
Write-Host 'O servidor inicia na porta 8787 ao abrir o aplicativo. Consulte o status na aba Rede.'
Write-Host 'Se usar outra porta, desative o acesso na aba Rede, ajuste a porta e ative novamente.'
