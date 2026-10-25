[Setup]
AppId={{BF720C7A-A254-4D97-8A9F-45F7985DB485}
AppName=Gerador de Licenças
AppVersion=1.0.0
DefaultDirName={localappdata}\Programs\Gerador de Licencas
DefaultGroupName=Gerador de Licenças
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\dist
OutputBaseFilename=Gerador-de-Licencas-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\license_generator_app.exe
AppMutex=Local\LCCargaLicenseGenerator.SingleInstance
SetupMutex=GeradorDeLicencasInstaller
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "..\dist\Gerador-de-Licencas-Windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Gerador de Licenças"; Filename: "{app}\license_generator_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Gerador de Licenças"; Filename: "{app}\license_generator_app.exe"; WorkingDir: "{app}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "LCCargaServer"; Flags: deletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "GeradorLicencasServer"; ValueData: """{app}\license_generator_app.exe"" --startup"; Flags: uninsdeletevalue

[Run]
Filename: "{app}\license_generator_app.exe"; Description: "Abrir Gerador de Licenças"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
