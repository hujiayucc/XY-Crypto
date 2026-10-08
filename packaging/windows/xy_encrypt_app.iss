#define BuildDir GetEnv("BUILD_DIR")
#define OutputDir GetEnv("OUTPUT_DIR")
#define ArchLabel GetEnv("ARCH_LABEL")

[Setup]
AppId={{2F4B6A4B-4C8D-4A78-9B9B-131180C0DE01}}
AppName=XY加密
AppVersion=1.3.1
AppVerName=XY加密 1.3.1
AppPublisher=XY加密
DefaultDirName={localappdata}\Programs\XY加密
DefaultGroupName=XY加密
UninstallDisplayName=XY加密
OutputDir={#OutputDir}
OutputBaseFilename=XY-Crypto-windows-{#ArchLabel}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\XY加密"; Filename: "{app}\xy_encrypt_app.exe"
Name: "{commondesktop}\XY加密"; Filename: "{app}\xy_encrypt_app.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："

[Run]
Filename: "{app}\xy_encrypt_app.exe"; Description: "启动 XY加密"; Flags: nowait postinstall skipifsilent