$ErrorActionPreference = 'Stop'
$FlutterVersion = $args[0]
$DartVersion = $args[1]
if ([string]::IsNullOrWhiteSpace($FlutterVersion) -or [string]::IsNullOrWhiteSpace($DartVersion)) {
  throw 'Flutter and Dart versions are required.'
}
$FlutterRoot = Join-Path $env:RUNNER_TEMP "flutter-$FlutterVersion-windows-arm64"
if (!(Test-Path (Join-Path $FlutterRoot '.git'))) {
  git clone --depth 1 --branch $FlutterVersion https://github.com/flutter/flutter.git $FlutterRoot
  if ($LASTEXITCODE -ne 0) { throw "Flutter source checkout failed: $LASTEXITCODE" }
}
$DartBin = (Get-Command dart -ErrorAction Stop).Source
$version = & $DartBin --version 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $version -notmatch [regex]::Escape($DartVersion) -or $version -notmatch 'windows_arm64') {
  throw "Expected Dart $DartVersion windows_arm64; got $version"
}
& (Join-Path $PSScriptRoot 'setup_flutter_windows.ps1') -FlutterRoot $FlutterRoot -DartBin $DartBin
