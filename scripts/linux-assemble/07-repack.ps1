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
$npmOut = "dist\npm-$suffix"
$vendorOut = "dist\npm-vendor-$suffix"

Push-Location $root
try {
  Write-Host "== release:pack dsh family -> $npmOut =="
  & $pnpm run release:pack --family dsh --out $npmOut
  if ($LASTEXITCODE -ne 0) { throw "release:pack dsh failed ($LASTEXITCODE)" }
  Write-Host "== release:pack vendor -> $vendorOut =="
  & $pnpm run release:pack --family vendor --out $vendorOut
  if ($LASTEXITCODE -ne 0) { throw "release:pack vendor failed ($LASTEXITCODE)" }
  Write-Host '== version distribution =='
  Get-ChildItem "$npmOut\*.tgz" | ForEach-Object {
    if ($_.Name -match '\d+\.\d+\.\d+[-a-zA-Z0-9.]*\.tgz$') { $matches[0] }
  } | Group-Object | Select-Object Name, Count | Format-Table -AutoSize
  Write-Host '== done =='
} finally {
  Pop-Location
}