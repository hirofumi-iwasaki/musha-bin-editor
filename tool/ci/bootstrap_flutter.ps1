# SPDX-License-Identifier: GPL-3.0-or-later
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [ValidateSet('x64', 'arm64')] [string]$Architecture,
  [Parameter(Mandatory = $true)] [string]$FlutterRoot
)

$ErrorActionPreference = 'Stop'
$expectedRevision = '9584c6713b324636289d067944a46fd6b49df14b'
$nativeArchitecture = $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant()
if (($Architecture -eq 'arm64' -and $nativeArchitecture -ne 'arm64') -or
    ($Architecture -eq 'x64' -and $nativeArchitecture -ne 'amd64')) {
  throw "Runner architecture is $nativeArchitecture; expected native $Architecture."
}

git clone --depth 1 --branch 3.47.4 https://github.com/flutter/flutter.git $FlutterRoot
$actualRevision = (git -C $FlutterRoot rev-parse HEAD).Trim()
if ($actualRevision -ne $expectedRevision) { throw "Flutter revision $actualRevision does not match $expectedRevision." }

$flutter = Join-Path $FlutterRoot 'bin\flutter.bat'
& $flutter --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter bootstrap failed.' }

# The upstream bootstrap selects the Arm64 Dart archive only for ARM64. Check
# the PE COFF header to reject an x64 fallback under emulation.
$dart = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path $dart)) { throw 'Native Dart SDK was not bootstrapped.' }
$bytes = [System.IO.File]::ReadAllBytes($dart)
$peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
$machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
$expectedMachine = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
if ($machine -ne $expectedMachine) { throw ('Dart PE machine is 0x{0:X4}; expected 0x{1:X4}.' -f $machine, $expectedMachine) }

if (-not $env:GITHUB_PATH) { throw 'GITHUB_PATH is required in CI.' }
(Join-Path $FlutterRoot 'bin') | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
