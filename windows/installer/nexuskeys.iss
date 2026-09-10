; Script de Inno Setup para el instalador de NexusKeys en Windows.
;
; Genera un unico .exe que instala la app donde el usuario elija (por
; defecto, Archivos de programa si se ejecuta como administrador, o una
; carpeta en el perfil del usuario si no - Inno Setup pregunta al empezar),
; crea accesos en el Menu Inicio y, opcionalmente, en el Escritorio, y deja
; un desinstalador registrado en "Aplicaciones y caracteristicas".
;
; La base de datos de la boveda NO se instala aqui ni vive en la carpeta de
; instalacion - sigue guardandose en la carpeta de datos de la aplicacion
; del usuario (vease path_provider en Windows), independientemente de donde
; se instale el programa. Es el comportamiento correcto en Windows: la
; carpeta de instalacion puede no ser escribible sin permisos de
; administrador (p.ej. Archivos de programa), y los datos de usuario nunca
; deben depender de esos permisos.
;
; Requiere: Inno Setup 6 (https://jrsoftware.org/isinfo.php) y haber
; compilado antes la app con `flutter build windows --release` (este script
; empaqueta directamente esa salida).
;
; Compilar: abre este archivo con el Compilador de Inno Setup y pulsa
; Compilar, o desde una terminal: iscc nexuskeys.iss

; Sin acentos a proposito: el compilador de Inno Setup se ejecuta bajo la
; codepage ANSI del sistema salvo que el .iss tenga BOM UTF-8, y no hay
; forma de comprobar aqui cual de las dos asumiria - texto ASCII evita
; cualquier riesgo de que el nombre salga con caracteres corruptos en el
; instalador o en "Aplicaciones y caracteristicas".
#define MyAppName "NexusKeys"
#define MyAppVersion "1.2.1"
#define MyAppPublisher "Ivan Bezanilla Lopez"
#define MyAppExeName "nexuskeys.exe"
#define MyAppIcoName "app_icon.ico"

[Setup]
; Este AppId identifica a NexusKeys de forma estable entre versiones - no lo
; cambies, o Windows tratara cada version como una app distinta en vez de
; ofrecer actualizar/reinstalar sobre la anterior.
AppId={{8D4F0501-3DCE-4864-808C-FC8C69BDC6CF}
AppName={#MyAppName}
; Sin esto, Inno Setup usa por defecto "{#MyAppName} {#MyAppVersion}" como
; nombre para mostrar - que es lo que hacia que "Aplicaciones y
; caracteristicas" mostrase "NexusKeys version 1.2.0" en la columna Nombre
; en vez de solo "NexusKeys" (la version ya se muestra aparte, en su propia
; columna, a partir de AppVersion).
AppVerName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; "lowest" + "dialog" es el mismo patron que usan instaladores como el de
; VS Code: al arrancar, pregunta si instalar solo para el usuario actual
; (sin necesitar administrador, en su carpeta de perfil) o para todos los
; usuarios de la maquina (con administrador, en Archivos de programa). El
; usuario elige la ubicacion final en cualquiera de los dos casos.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UsePreviousAppDir=yes
OutputDir=Output
OutputBaseFilename=NexusKeys-Setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\{#MyAppIcoName}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\..\LICENSE
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Copia TODO lo que genera `flutter build windows --release` - el .exe, sus
; DLLs, y la carpeta data\ con los assets y el motor de Flutter. Hace falta
; haber compilado antes; este script no lo hace por si mismo.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// El desinstalador de Inno Setup ya limpia solo, sin necesitar nada de este
// [Code]: los archivos del programa, la carpeta de instalacion, los accesos
// de Menu Inicio/Escritorio, y la entrada del registro en "Aplicaciones y
// caracteristicas". Lo unico que Inno Setup NO sabe que existe es la boveda
// cifrada del usuario en %APPDATA%\NexusKeys - vive fuera de la carpeta de
// instalacion a proposito (vease el comentario del principio del archivo),
// asi que hace falta este paso aparte para poder borrarla tambien.
//
// Se pregunta explicitamente, con "No" como opcion por defecto: borrar la
// boveda del usuario sin preguntar seria destructivo e irreversible,
// incluida la situacion mas comun de reinstalar solo para actualizar de
// version.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
  Response: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    DataDir := ExpandConstant('{userappdata}\{#MyAppName}');
    if DirExists(DataDir) then
    begin
      Response := MsgBox(
        'Quieres eliminar tambien los datos de tu boveda (tus contrasenas guardadas)?' + #13#10 + #13#10 +
        'Esta accion NO se puede deshacer. Si solo estas actualizando o reinstalando ' +
        '{#MyAppName}, elige "No" para conservar tu boveda.',
        mbConfirmation, MB_YESNO or MB_DEFBUTTON2);
      if Response = IDYES then
        DelTree(DataDir, True, True, True);
    end;
  end;
end;
