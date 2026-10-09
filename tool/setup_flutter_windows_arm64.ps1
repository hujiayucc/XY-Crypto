$ErrorActionPreference = 'Stop'
$FlutterVersion = $args[0]
$DartVersion = $args[1]
if ([string]::IsNullOrWhiteSpace($FlutterVersion) -or [string]::IsNullOrWhiteSpace($DartVersion)) {
  throw 'Flutter and Dart versions are required.'
}

$FlutterRoot = Join-Path $env:RUNNER_TEMP "flutter-$FlutterVersion-windows-arm64"
$DartRoot = ''
$FlutterBinDir = Join-Path $env:RUNNER_TEMP 'flutter-arm64-bin'

if (!(Test-Path (Join-Path $FlutterRoot '.git'))) {
  if (Test-Path $FlutterRoot) { Remove-Item -Recurse -Force $FlutterRoot }
  git clone --depth 1 --branch $FlutterVersion https://github.com/flutter/flutter.git $FlutterRoot
}

$DartBin = (Get-Command dart -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($DartBin)) {
  throw 'Dart ARM64 must be installed by dart-lang/setup-dart before this script.'
}

Push-Location (Join-Path $FlutterRoot 'packages\flutter_tools')
try {
  & $DartBin pub get --no-precompile
} finally {
  Pop-Location
}

if (Test-Path $FlutterBinDir) { Remove-Item -Recurse -Force $FlutterBinDir }
New-Item -ItemType Directory -Force $FlutterBinDir | Out-Null
$wrapper = Join-Path $FlutterBinDir 'flutter.bat'
@"
@echo off
set FLUTTER_ROOT=$FlutterRoot
"$DartBin" --packages="$FlutterRoot\packages\flutter_tools\.dart_tool\package_config.json" "$FlutterRoot\packages\flutter_tools\bin\flutter_tools.dart" --no-version-check --suppress-analytics %*
"@ | Set-Content -Encoding ASCII $wrapper

Add-Content -Path $env:GITHUB_ENV -Value "FLUTTER_ROOT=$FlutterRoot"
Add-Content -Path $env:GITHUB_PATH -Value $FlutterBinDir
& $wrapper precache --windows
& $wrapper --version