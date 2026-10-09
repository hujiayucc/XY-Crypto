param(
  [Parameter(Mandatory = $true)]
  [string]$Path,
  [string]$Description = 'XY加密',
  [string]$Url = 'https://app.hujiayucc.cn'
)

$ErrorActionPreference = 'Stop'

$certificateBase64 = $env:WINDOWS_SIGNING_CERTIFICATE_BASE64
$certificatePassword = $env:WINDOWS_SIGNING_CERTIFICATE_PASSWORD
$timestampUrl = if ($env:WINDOWS_SIGNING_TIMESTAMP_URL) {
  $env:WINDOWS_SIGNING_TIMESTAMP_URL
} else {
  'http://timestamp.digicert.com'
}

if ([string]::IsNullOrWhiteSpace($certificateBase64)) {
  Write-Warning 'Windows signing certificate is not configured; leaving the artifact unsigned.'
  exit 0
}

if (!(Test-Path -LiteralPath $Path)) {
  throw "Signing input does not exist: $Path"
}

$signtool = (Get-Command signtool.exe -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($signtool)) {
  $sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
  $signtool = (Get-ChildItem -Path $sdkRoot -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName)
}
if ([string]::IsNullOrWhiteSpace($signtool)) {
  throw 'signtool.exe was not found on the runner.'
}

$certificatePath = Join-Path $env:RUNNER_TEMP 'xy-encrypt-signing.pfx'
try {
  [IO.File]::WriteAllBytes($certificatePath, [Convert]::FromBase64String($certificateBase64))
  & $signtool sign /fd SHA256 /f $certificatePath /p $certificatePassword /tr $timestampUrl /td SHA256 /d $Description /du $Url $Path
  if ($LASTEXITCODE -ne 0) {
    throw "signtool sign failed with exit code $LASTEXITCODE"
  }
  & $signtool verify /pa /all /tw $Path
  if ($LASTEXITCODE -ne 0) {
    $allowUntrusted = $env:WINDOWS_SIGNING_ALLOW_UNTRUSTED -eq 'true'
    $authenticode = Get-AuthenticodeSignature -LiteralPath $Path
    if (!$allowUntrusted -or $null -eq $authenticode.SignerCertificate -or $authenticode.Status -eq 'NotSigned') {
      throw "signtool verify failed with exit code $LASTEXITCODE; status=$($authenticode.Status)"
    }
    Write-Warning "Signature is present but the certificate chain is not trusted on this runner: $($authenticode.Status)"
  }
  Write-Host "Signed and verified: $Path"
} finally {
  if (Test-Path -LiteralPath $certificatePath) {
    Remove-Item -LiteralPath $certificatePath -Force
  }
}