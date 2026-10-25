$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar as dependencias.' }
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'A analise do projeto falhou.' }
& flutter test
if ($LASTEXITCODE -ne 0) { throw 'Os testes falharam.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'O build do Windows falhou.' }

$executables = @(Get-ChildItem -Path 'build\windows' -Filter 'license_generator_app.exe' -Recurse |
    Where-Object { $_.Directory.FullName -match '[\\/]runner[\\/]Release$' })
if ($executables.Count -ne 1) { throw 'Pasta de release do Windows nao encontrada ou ambigua.' }

$releaseFolder = $executables[0].Directory.FullName
$packageFolder = Join-Path (Get-Location) 'dist\LC-Carga-Windows'
if (Test-Path -LiteralPath $packageFolder) { Remove-Item -LiteralPath $packageFolder -Recurse -Force }
New-Item -ItemType Directory -Path $packageFolder -Force | Out-Null
Copy-Item -Path (Join-Path $releaseFolder '*') -Destination $packageFolder -Recurse -Force
# Include the app-local Visual C++ runtime in the portable package when present.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path -LiteralPath $vswhere) {
    $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($visualStudio) {
        $redistRoot = Join-Path $visualStudio 'VC\Redist\MSVC'
        if (Test-Path -LiteralPath $redistRoot) {
            $runtime = Get-ChildItem -LiteralPath $redistRoot -Directory |
                Where-Object { $_.Name -match '^14\.\d+\.\d+$' } |
                Sort-Object { [version]$_.Name } -Descending |
                ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
                Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($runtime) {
                Copy-Item -Path (Join-Path $runtime '*.dll') -Destination $packageFolder -Force
                Write-Host 'Bibliotecas Visual C++ incluidas no pacote.'
            }
        }
    }
}
Copy-Item -LiteralPath 'docs\ACESSO_REDE.md' -Destination (Join-Path $packageFolder 'LEIA-ME.md')
Copy-Item -LiteralPath 'scripts\allow_windows_network.ps1' -Destination (Join-Path $packageFolder 'HABILITAR_REDE.ps1')
Copy-Item -LiteralPath 'scripts\test_windows_startup.ps1' -Destination (Join-Path $packageFolder 'VERIFICAR_INICIALIZACAO.ps1')
$archive = Join-Path (Get-Location) 'dist\LC-Carga-Windows.zip'
Compress-Archive -Path $packageFolder -DestinationPath $archive -Force
Write-Host "Pacote criado em $archive"
Write-Host 'Copie e extraia a pasta inteira no PC de destino.'
