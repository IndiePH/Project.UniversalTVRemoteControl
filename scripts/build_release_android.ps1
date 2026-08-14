# Builds a signed release AAB with production dart-defines from
# android/release_dart_defines.properties (gitignored).
param(
  [ValidateSet('appbundle', 'apk')]
  [string]$Target = 'appbundle'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$definesFile = Join-Path $repoRoot 'android\release_dart_defines.properties'

$dartDefines = @()
if (Test-Path $definesFile) {
  Get-Content $definesFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $parts = $line -split '=', 2
    if ($parts.Count -ne 2) { return }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($key -and $value) {
      $dartDefines += "--dart-define=${key}=${value}"
    }
  }
} else {
  Write-Warning "Missing $definesFile - release build will omit FEEDBACK_WEBHOOK_TOKEN."
}

Push-Location $repoRoot
try {
  if ($Target -eq 'appbundle') {
    flutter build appbundle --release @dartDefines
  } else {
    flutter build apk --release @dartDefines
  }
} finally {
  Pop-Location
}
