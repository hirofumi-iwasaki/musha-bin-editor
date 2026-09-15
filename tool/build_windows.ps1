# SPDX-License-Identifier: GPL-3.0-or-later
[CmdletBinding()]
param(
  [ValidateSet('x64', 'arm64')] [string]$Architecture,
  [string]$FlutterBin
)

$ErrorActionPreference = 'Stop'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$processorArchitecture = $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant()
$nativeArchitecture = if ($processorArchitecture -eq 'arm64') { 'arm64' } elseif ($processorArchitecture -eq 'amd64') { 'x64' } else { throw "Unsupported Windows host architecture: $processorArchitecture" }
if (-not $Architecture) { $Architecture = $nativeArchitecture }
if ($Architecture -ne $nativeArchitecture) { throw "Native Windows host required (host=$nativeArchitecture target=$Architecture)." }
if (-not $FlutterBin) { $FlutterBin = if (Test-Path (Join-Path $projectDir '.tooling\flutter\bin\flutter.bat')) { Join-Path $projectDir '.tooling\flutter\bin\flutter.bat' } else { 'flutter' } }
$flutterCommand = if ([IO.Path]::IsPathRooted($FlutterBin)) { (Resolve-Path $FlutterBin).Path } else { (Get-Command $FlutterBin -ErrorAction Stop).Source }
$dartBin = Join-Path (Split-Path -Parent $flutterCommand) 'dart.bat'
if (-not (Test-Path $dartBin)) { throw "Missing Dart SDK beside Flutter: $dartBin" }

Set-Location $projectDir
& $FlutterBin pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
& $FlutterBin build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed.' }

$bundle = Join-Path $projectDir "build\windows\$Architecture\runner\Release"
$exe = Join-Path $bundle 'mushagaeshi_binary_editor.exe'
if (-not (Test-Path $exe)) { throw "Missing complete Windows bundle: $bundle" }
$expectedMachine = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
Get-ChildItem $bundle -File -Recurse | Where-Object { $_.Extension -in '.exe', '.dll' } | ForEach-Object {
  $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
  $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
  $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
  if ($machine -ne $expectedMachine) { throw ('Unexpected PE architecture in {0}: 0x{1:X4}' -f $_.FullName, $machine) }
}

$dist = Join-Path $projectDir 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $dist ('.windows-package.' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
  $packageRoot = Join-Path $stage 'mushagaeshi_binary_editor'
  Copy-Item -Recurse -Path $bundle -Destination $packageRoot
  & $dartBin run tool/ci/write_distribution_metadata.dart $packageRoot "windows-$Architecture" $FlutterBin
  if ($LASTEXITCODE -ne 0) { throw 'Distribution metadata generation failed.' }
  $archive = Join-Path $dist "musha-bin-edit-windows-$Architecture.zip"
  Remove-Item -Force -ErrorAction SilentlyContinue $archive
  Compress-Archive -Path $packageRoot -DestinationPath $archive -CompressionLevel Optimal
  Write-Host "Windows package ready: $archive"
} finally {
  Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $stage
}
