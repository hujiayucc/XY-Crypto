#define BuildDir GetEnv("BUILD_DIR")
#define OutputDir GetEnv("OUTPUT_DIR")
#define ArchLabel GetEnv("ARCH_LABEL")

[Setup]
AppId={{2F4B6A4B-4C8D-4A78-9B9B-131180C0DE01}}
AppName=XY加密
AppVersion=1.3.2
AppVerName=XY加密 1.3.2
AppPublisher=胡佳宇
VersionInfoDescription=XY加密安装程序
VersionInfoProductName=XY加密
VersionInfoCompany=胡佳宇
DefaultDirName={localappdata}\Programs\XY加密
DefaultGroupName=XY加密
UninstallDisplayName=XY加密
OutputDir={#OutputDir}
OutputBaseFilename=XY加密-windows-{#ArchLabel}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ChangesAssociations=yes
; Always show Simplified Chinese, including on English-language Windows.
ShowLanguageDialog=no
LanguageDetectionMethod=none
UsePreviousLanguage=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "Languages\ChineseSimplified.isl"

[Registry]
Root: HKCU; Subkey: "Software\Classes\xyd"; ValueType: string; ValueName: ""; ValueData: "URL:XY加密分享链接"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\xyd"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\xyd\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\xy_encrypt_app.exe"",0"
Root: HKCU; Subkey: "Software\Classes\xyd\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\xy_encrypt_app.exe"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\.xyshare"; ValueType: string; ValueName: ""; ValueData: "XYEncryptShareFile"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\XYEncryptShareFile"; ValueType: string; ValueName: ""; ValueData: "XY加密分享文件"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\XYEncryptShareFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\xy_encrypt_app.exe"",0"
Root: HKCU; Subkey: "Software\Classes\XYEncryptShareFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\xy_encrypt_app.exe"" ""%1"""

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\XY加密"; Filename: "{app}\xy_encrypt_app.exe"
Name: "{commondesktop}\XY加密"; Filename: "{app}\xy_encrypt_app.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\xy_encrypt_app.exe"; Description: "{cm:LaunchProgram,XY加密}"; Flags: nowait postinstall skipifsilent