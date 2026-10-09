param(
  [Parameter(Mandatory = $true)][string]$FlutterRoot,
  [string]$DartBin = ''
)
$ErrorActionPreference = 'Stop'
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
if (!(Test-Path $FlutterRoot)) { throw "Flutter SDK not found: $FlutterRoot" }
$CacheDir = Join-Path $FlutterRoot 'bin\cache'
New-Item -ItemType Directory -Force $CacheDir | Out-Null

if ($DartBin) {
  $DartRoot = Split-Path (Split-Path $DartBin -Parent) -Parent
  $CachedDart = Join-Path $CacheDir 'dart-sdk'
  if (!(Test-Path $CachedDart)) {
    New-Item -ItemType Junction -Path $CachedDart -Target $DartRoot | Out-Null
  }
}
$DartBin = Join-Path $CacheDir 'dart-sdk\bin\dart.exe'
if (!(Test-Path $DartBin)) { throw "Flutter Dart SDK not found: $DartBin" }

# Flutter 3.35.4 falls back to VS 2019 for VS 2026. Backport the generator mapping.
$ToolsRoot = Join-Path $FlutterRoot 'packages\flutter_tools'
$VisualStudioFile = Join-Path $ToolsRoot 'lib\src\windows\visual_studio.dart'
$source = Get-Content -Raw $VisualStudioFile
$anchor = "17 => 'Visual Studio 17 2022',"
$mapping = "18 => 'Visual Studio 18 2026',"
if (!$source.Contains($mapping)) {
  if (!$source.Contains($anchor)) { throw 'Unexpected Flutter Visual Studio source; review compatibility patch.' }
  $source = $source.Replace($anchor, "$mapping`n      $anchor")
  [System.IO.File]::WriteAllText($VisualStudioFile, $source, $Utf8NoBom)
}

$engine = (Get-Content -Raw (Join-Path $FlutterRoot 'bin\internal\engine.version')).Trim()
[System.IO.File]::WriteAllText((Join-Path $CacheDir 'engine.stamp'), $engine, $Utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $CacheDir 'engine-dart-sdk.stamp'), $engine, $Utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $CacheDir 'engine.realm'), '', $Utf8NoBom)
$env:FLUTTER_ROOT = $FlutterRoot
Push-Location $ToolsRoot
try {
  & $DartBin pub get --no-precompile
  if ($LASTEXITCODE -ne 0) { throw "Flutter tools pub get failed: $LASTEXITCODE" }
} finally {
  Pop-Location
}

# CMake invokes FLUTTER_ROOT/bin/flutter.bat directly; use the same patched tool.
$wrapper = Join-Path $FlutterRoot 'bin\flutter.bat'
$WrapperText = @"
@echo off
setlocal
set "FLUTTER_ROOT=$FlutterRoot"
"$DartBin" --packages="$ToolsRoot\.dart_tool\package_config.json" "$ToolsRoot\bin\flutter_tools.dart" --no-version-check --suppress-analytics %*
exit /b %errorlevel%
"@
[System.IO.File]::WriteAllText($wrapper, $WrapperText.Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
$env:PATH = "$FlutterRoot\bin;$env:PATH"
Add-Content -Path $env:GITHUB_ENV -Value "FLUTTER_ROOT=$FlutterRoot"
Add-Content -Path $env:GITHUB_PATH -Value "$FlutterRoot\bin"
& $wrapper precache --windows
if ($LASTEXITCODE -ne 0) { throw "Flutter Windows precache failed: $LASTEXITCODE" }
& $wrapper --version
if ($LASTEXITCODE -ne 0) { throw "Flutter version check failed: $LASTEXITCODE" }
