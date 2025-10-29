[Setup]
AppName=Menu de Manutencao do Windows
AppVersion=1.0.0
DefaultDirName={sd}\Dev\ManutencaoWindows
DefaultGroupName=Menu de Manutencao do Windows
DisableDirPage=yes
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=MenuManutencaoSetup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
WizardStyle=modern

[Dirs]
Name: "{sd}\Dev"

[Files]
Source: "..\menu.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\Menu de Manutencao do Windows"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\menu.ps1"""; WorkingDir: "{app}"; IconFilename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Comment: "Executa o menu de manutencao do Windows"

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\menu.ps1"""; Flags: postinstall skipifsilent runascurrentuser; Description: "Abrir o menu ao final da instalacao"
