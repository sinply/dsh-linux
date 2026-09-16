# Step 7 (Windows side): repack the dsh family + vendor tarballs from a
# deepseek-harness checkout into fresh output dirs.
# Required env:
#   HARNESS_ROOT  path to the deepseek-harness checkout (contains package.json)
# Optional:
#   PNPM_CMD      pnpm executable (default: pnpm on PATH)
#   OUT_SUFFIX    output dir suffix (default: a3) -> dist/npm-<suffix>, dist/npm-vendor-<suffix>
$ErrorActionPreference = 'Stop'
# Git's busybox tar cannot parse drive-letter paths; prefer the Windows bsdtar.
$env:PATH = "C:\Windows\System32;$env:PATH"
$tar = Get-Command tar -ErrorAction Stop
Write-Host "using tar: $($tar.Source)"

$root = $env:HARNESS_ROOT
if (-not $root) { throw 'set HARNESS_ROOT to the deepseek-harness checkout' }
$pnpm = if ($env:PNPM_CMD) { $env:PNPM_CMD } else { 'pnpm' }
$suffix = if ($env:OUT_SUFFIX) { $env:OUT_SUFFIX } else { 'a3' }
$npmName = "npm-$suffix"
$vendorName = "npm-vendor-$suffix"
$npmOut = "dist\$npmName"
$vendorOut = "dist\$vendorName"

# Native tools write progress to stderr, which Windows PowerShell 5.1 turns into
# an ErrorRecord; under ErrorActionPreference=Stop that aborts the run before the
# exit code is even read. Keep those invocations non-terminating and decide on
# $LASTEXITCODE instead.
function Invoke-Pnpm([string[]]$Arguments) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $pnpm @Arguments 2>&1 | ForEach-Object { Write-Host $_ }
  } finally { $ErrorActionPreference = $previous }
  if ($LASTEXITCODE -ne 0) { throw "pnpm $($Arguments -join ' ') failed ($LASTEXITCODE)" }
}

Push-Location $root
try {
  # Repo convention: only clean stale version-suffixed output directories
  # (npm-<version> / npm-vendor-<version>); never touch npm-landlock, which is
  # reused across versions, and never the directories this run writes to.
  Get-ChildItem 'dist' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^npm(-vendor)?-\d' -and $_.Name -ne $npmName -and $_.Name -ne $vendorName } |
    ForEach-Object {
      Write-Host "  clean stale: dist\$($_.Name)"
      Remove-Item $_.FullName -Recurse -Force
    }
  foreach ($pair in @(@('dsh', $npmOut), @('vendor', $vendorOut))) {
    $family, $out = $pair
    Write-Host "== release:pack $family -> $out =="
    Invoke-Pnpm @('run', 'release:pack', '--family', $family, '--out', $out)
  }
  Write-Host '== version distribution =='
  Get-ChildItem "$npmOut\*.tgz" | ForEach-Object {
    if ($_.Name -match '\d+\.\d+\.\d+[-a-zA-Z0-9.]*\.tgz$') { $matches[0] }
  } | Group-Object | Select-Object Name, Count | Format-Table -AutoSize
  Write-Host "== done: $((Get-ChildItem "$npmOut\*.tgz").Count) dsh + $((Get-ChildItem "$vendorOut\*.tgz").Count) vendor tarballs =="
} finally {
  Pop-Location
}
