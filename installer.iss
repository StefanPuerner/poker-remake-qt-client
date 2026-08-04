; Script de Inno Setup — genera el instalador .exe para Windows.
; Se compila con ISCC.exe (viene preinstalado en los runners de GitHub
; Actions windows-latest, no hace falta instalarlo).
;
; Asume que ya se corrió "windeployqt" sobre
; build\RelWithDebInfo\PokerClientQt.exe, dejando ahí mismo (al lado del
; .exe) todas las DLLs de Qt y las carpetas de plugins que hacen falta —
; este script simplemente empaqueta ESA carpeta entera tal cual.

[Setup]
AppName=PokerRemake
AppVersion=0.1.0
AppPublisher=Stefan
DefaultDirName={autopf}\PokerRemake
DefaultGroupName=PokerRemake
OutputDir=dist
OutputBaseFilename=PokerRemake-Setup
SetupIconFile=assets\icon.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Sin firma de código — Windows mostrará un aviso de "editor desconocido"
; al instalar. Es esperable para un proyecto pequeño sin certificado
; comercial; no bloquea la instalación, solo pide un clic extra de más
; ("Más información" → "Ejecutar de todas formas").

[Files]
Source: "build\RelWithDebInfo\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\PokerRemake"; Filename: "{app}\PokerClientQt.exe"
Name: "{commondesktop}\PokerRemake"; Filename: "{app}\PokerClientQt.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"
