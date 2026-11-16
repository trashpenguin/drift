[Setup]
AppId={{C48A2D91-4A03-46FA-AD9C-5F57D7D89010}
AppName=Drift
AppVersion={#Version}
DefaultDirName={localappdata}\Programs\Drift
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
SetupArchitecture=x64
ArchitecturesAllowed=x64compatible
MinVersion=10.0
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CreateUninstallRegKey=IntegrateWithWindows
UninstallDisplayIcon={app}\drift.exe

[Files]
Source: "{#Payload}\drift.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\yt-dlp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\mpv.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\d3dcompiler_43.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\WINDOWS.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\mpv-Copyright.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Payload}\mpv-LICENSE.GPL.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Drift"; Filename: "{app}\drift.exe"; WorkingDir: "{app}"; Check: IntegrateWithWindows

[Run]
Filename: "{app}\drift.exe"; WorkingDir: "{app}"; Description: "Launch Drift"; Flags: nowait postinstall skipifsilent unchecked

[Code]
function IntegrateWithWindows: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '/NOINTEGRATION') = 0 then
      Result := False;
end;
