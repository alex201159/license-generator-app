$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
$package = Join-Path (Get-Location) 'dist\Gerador-de-Licencas-Windows'
if (-not (Test-Path -LiteralPath (Join-Path $package 'license_generator_app.exe'))) {
    throw 'Gere o pacote com scripts\build_windows.ps1 antes de criar o instalador.'
}
$compiler = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) {
    $command = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
    if ($command) { $compiler = $command.Source }
}
if (-not $compiler) { throw 'Instale Inno Setup 6 para gerar o instalador.' }
& $compiler /Qp 'scripts\windows_installer.iss'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o instalador.' }
$setup = Join-Path (Get-Location) 'dist\Gerador-de-Licencas-Setup.exe'
if (-not (Test-Path -LiteralPath $setup)) { throw 'O instalador nao foi gerado.' }
Write-Host "Instalador criado em $setup"
