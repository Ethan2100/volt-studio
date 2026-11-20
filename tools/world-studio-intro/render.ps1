param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)
$ErrorActionPreference = 'Stop'
$electronCli = Join-Path $ProjectRoot 'node_modules/electron/cli.js'
$output = Join-Path $ProjectRoot 'docs/world-studio-intro.webm'
if (!(Test-Path -LiteralPath $electronCli)) { throw 'Electron is missing. Run npm ci in the repository first.' }
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
node $electronCli --no-sandbox $PSScriptRoot
if (!(Test-Path -LiteralPath $output)) { throw 'Video rendering failed; no WebM file was written.' }
$video = Get-Item -LiteralPath $output
if ($video.Length -lt 100000) { throw 'Video rendering produced an unexpectedly small file.' }
Write-Output "Created $($video.FullName) ($([math]::Round($video.Length / 1MB, 1)) MB)"
