#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot packaging of the dsh-linux offline Linux distribution.

.DESCRIPTION
    Windows-side orchestrator. It builds the dsh npm tarballs from a
    deepseek-harness checkout, repacks them, runs the WSL/Linux assembly driver
    (scripts/linux-assemble/build-all.sh), copies the operator README into the
    deliverable directory, and records dist/linux/build-info.json.

    Nothing machine-specific is baked in: paths come from parameters or the
    environment, and each phase can be skipped so an interrupted build can resume
    without redoing finished work.

    Phases:
      1 preflight        resolve paths, record version/commit, probe WSL
      2 harness build    pnpm install + clean + build:official (official profile)
      3 repack           07-repack.ps1 -> <HarnessRoot>/dist/npm-<Suffix>
      4 assemble         WSL: build-all.sh (install, prune, verify, 4 variants, smoke)
      5 deliver          operator README + build-info.json (+ optional re-extract)

.PARAMETER HarnessRoot
    deepseek-harness checkout. Default: $env:HARNESS_ROOT, else a sibling
    directory named deepseek-harness next to this repository.
.PARAMETER Version
    Version stamped into each bundle's BUILD-INFO.txt and into build-info.json.
    Default: the version of <HarnessRoot>/package.json.
.PARAMETER Suffix
    Suffix of the repack directories <HarnessRoot>/dist/npm-<Suffix>. Default: -Version.
.PARAMETER Variants
    Deliverables to build: full, slim, basic, basic-slim. Default: all four.
.PARAMETER Distro
    WSL distribution to assemble in. Default: $env:DSH_WSL_DISTRO, else Ubuntu-22.04.
.PARAMETER StageDir
    WSL-side build stage. Default: the WSL login user's $HOME/dsh-linux-build.
.PARAMETER SystemNode
    WSL directory holding the Node used to verify the slim variants.
    Default: $StageDir/node24 (see docs/build.md section 3.4).
.PARAMETER LandlockTgzSrc
    Legacy input: directory holding the landlock entry tarball used up to dsh
    0.1.2. From 0.1.5 the native primitives (@deepseek-ai/node-addon-system) are
    resolved from the registry, so this is not passed by default.
.PARAMETER SkipInstall
    Skip `pnpm install --frozen-lockfile`.
.PARAMETER SkipHarnessBuild
    Skip `pnpm run clean` and `pnpm run build:official`, keeping the existing
    build outputs (use after a successful upstream build).
.PARAMETER SkipRepack
    Skip `07-repack.ps1` and reuse the existing
    <HarnessRoot>/dist/npm-<Suffix> and dist/npm-vendor-<Suffix> tarballs.
.PARAMETER ReuseStage
    Reuse the existing WSL install (SKIP_INSTALL=1 on the Linux side): skips
    staging and the pnpm install, keeping app/node_modules as is.
.PARAMETER SkipSmoke
    Skip the landlock + static bwrap + `dsh web` acceptance test.
.PARAMETER Extract
    Re-extract the tarballs into dist/linux/<variant> as a final integrity check
    (adds ~3 GB under dist/linux).
.PARAMETER SkipHash
    Do not compute SHA-256 for the deliverables in build-info.json.
.PARAMETER DryRun
    Print the resolved plan and the commands that would run, then exit.

.EXAMPLE
    pwsh -File scripts/build-linux.ps1

.EXAMPLE
    pwsh -File scripts/build-linux.ps1 -SkipHarnessBuild -ReuseStage

.EXAMPLE
    pwsh -File scripts/build-linux.ps1 -Variants full,slim -Distro Ubuntu-22.04
#>
[CmdletBinding()]
param(
  [string]$HarnessRoot = $env:HARNESS_ROOT,
  [string]$Version,
  [string]$Suffix,
  [ValidateSet('full', 'slim', 'basic', 'basic-slim')]
  [string[]]$Variants = @('full', 'slim', 'basic', 'basic-slim'),
  [string]$Distro = $(if ($env:DSH_WSL_DISTRO) { $env:DSH_WSL_DISTRO } else { 'Ubuntu-22.04' }),
  [string]$StageDir,
  [string]$SystemNode,
  [string]$LandlockTgzSrc,
  [switch]$SkipInstall,
  [switch]$SkipHarnessBuild,
  [switch]$SkipRepack,
  [switch]$ReuseStage,
  [switch]$SkipSmoke,
  [switch]$Extract,
  [switch]$SkipHash,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'
if ($null -ne $PSNativeCommandUseErrorActionPreference) { $PSNativeCommandUseErrorActionPreference = $false }
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
$script:Started = Get-Date

function Write-Phase([string]$Text) {
  Write-Host ''
  Write-Host ('=' * 72)
  Write-Host "== $Text"
  Write-Host ('=' * 72)
}
function Write-Info([string]$Text) { Write-Host "   $Text" }
function Fail([string]$Text) { throw $Text }

# Run a native command or a called script with every stream (including Write-Host)
# captured in a log file while still streaming to the console. $LASTEXITCODE
# decides success; native stderr is text, not a terminating error.
function Invoke-Logged([string]$Label, [string]$LogFile, [scriptblock]$Command) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Command *>&1 | Tee-Object -FilePath $LogFile -Encoding utf8
  } finally { $ErrorActionPreference = $previous }
  if ($LASTEXITCODE -ne 0) { Fail "$Label failed (exit $LASTEXITCODE) - log: $LogFile" }
}

function Invoke-Step([string]$Label, [scriptblock]$Body) {
  $t0 = Get-Date
  & $Body
  Write-Info ("{0} done in {1:mm}m{1:ss}s" -f $Label, ((Get-Date) - $t0))
}

# Convert a Windows path to its WSL mount path (/mnt/<drive>/...). Paths that are
# already Linux-style are returned unchanged.
function ConvertTo-WslPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
  if ($Path.StartsWith('/')) { return $Path }
  $full = [System.IO.Path]::GetFullPath($Path)
  if ($full -match '^([A-Za-z]):\\(.*)$') {
    return "/mnt/$($Matches[1].ToLowerInvariant())/$($Matches[2].Replace('\', '/'))"
  }
  Fail "cannot convert to a WSL path: $Path"
}

function Invoke-Wsl([string[]]$Arguments) {
  & wsl.exe @Arguments
  if ($LASTEXITCODE -ne 0) { Fail "wsl.exe exited with code $LASTEXITCODE" }
}

function Write-TextFile([string]$Path, [string]$Text) {
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

# ---------------------------------------------------------------- 1. preflight
$RepoRoot = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $RepoRoot 'dist\linux'
$Stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$LogDir = Join-Path $RepoRoot "dist\logs\$Stamp"

if (-not $HarnessRoot) {
  $sibling = Join-Path (Split-Path -Parent $RepoRoot) 'deepseek-harness'
  if (Test-Path (Join-Path $sibling 'package.json')) { $HarnessRoot = $sibling }
}
if (-not $HarnessRoot) { Fail 'set -HarnessRoot or $env:HARNESS_ROOT to the deepseek-harness checkout' }
if (-not (Test-Path (Join-Path $HarnessRoot 'package.json'))) { Fail "no package.json under $HarnessRoot" }
$HarnessRoot = (Resolve-Path -LiteralPath $HarnessRoot).Path

if (-not $Version) {
  $Version = (Get-Content (Join-Path $HarnessRoot 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
}
if (-not $Version) { Fail 'cannot determine the dsh version; pass -Version' }
if (-not $Suffix) { $Suffix = $Version }

$upstreamCommit = (& git -C $HarnessRoot rev-parse HEAD).Trim()
$upstreamShort = $upstreamCommit.Substring(0, 10)
$upstreamTag = (& git -C $HarnessRoot describe --tags --abbrev=0 2>$null | Select-Object -First 1)
if ($upstreamTag) { $upstreamTag = $upstreamTag.Trim() }
$upstreamDirty = [bool](& git -C $HarnessRoot status --porcelain)

$npmSrc = Join-Path $HarnessRoot "dist\npm-$Suffix"
$vendorSrc = Join-Path $HarnessRoot "dist\npm-vendor-$Suffix"

$repoWsl = ConvertTo-WslPath $RepoRoot
$outWsl = ConvertTo-WslPath $DistDir
if ($StageDir -and $StageDir -match '^[A-Za-z]:\\') { $StageDir = ConvertTo-WslPath $StageDir }

$nodeVersion = (& node --version).Trim()
$pnpmVersion = (& pnpm --version).Trim()

Write-Phase 'dsh-linux packaging plan'
Write-Info "repo            : $RepoRoot"
Write-Info "harness         : $HarnessRoot"
Write-Info "dsh version     : $Version   (repack suffix: $Suffix)"
Write-Info "upstream commit : $upstreamShort $upstreamTag dirty=$upstreamDirty"
Write-Info "variants        : $($Variants -join ' ')"
Write-Info "wsl distro      : $Distro"
Write-Info "stage           : $(if ($StageDir) { $StageDir } else { '$HOME/dsh-linux-build (WSL default)' })"
Write-Info "deliverables    : $DistDir"
Write-Info "logs            : $LogDir"
Write-Info "tools           : node $nodeVersion, pnpm $pnpmVersion"

# A stopped distro is normal on Windows (WSL shuts down when idle) and takes a
# moment to boot, so a single failed probe is not conclusive.
$wslOk = $false
for ($attempt = 1; $attempt -le 3 -and -not $wslOk; $attempt++) {
  try { Invoke-Wsl @('-d', $Distro, '-e', 'true'); $wslOk = $true }
  catch {
    if ($attempt -lt 3) {
      Write-Info "wsl probe attempt $attempt failed; retrying in 5s"
      Start-Sleep -Seconds 5
    } else {
      Write-Info "wsl probe failed: $_"
    }
  }
}
if (-not $wslOk) {
  $list = ((& wsl.exe -l -q) | Where-Object { $_ }) -join ', '
  Fail "WSL distro '$Distro' is not usable (installed: $list). Pass -Distro <name>, or start it once with: wsl -d $Distro -e true"
}
Write-Info 'wsl             : ok'

if ($DryRun) {
  Write-Host ''
  Write-Host 'DryRun: nothing executed. Steps that would run:'
  Write-Host "  2  pnpm install$(if ($SkipInstall) { ' (skipped)' }) ; pnpm run clean$(if ($SkipHarnessBuild) { ' (skipped)' }) ; pnpm run build:official$(if ($SkipHarnessBuild) { ' (skipped)' })"
  Write-Host "  3  07-repack.ps1  OUT_SUFFIX=$Suffix$(if ($SkipRepack) { ' (skipped)' })"
  Write-Host "  4  wsl -d $Distro -e env DSH_LINUX_ENV=<env file> bash $repoWsl/scripts/linux-assemble/build-all.sh  (VARIANTS='$($Variants -join ',')')"
  Write-Host "  5  dist/linux/README*.md + build-info.json"
  return
}

New-Item -ItemType Directory -Force -Path $DistDir, $LogDir | Out-Null

# ------------------------------------------------------------ 2. harness build
Write-Phase '2/5 harness build (Windows)'
if ($SkipHarnessBuild) {
  Write-Info 'skipped (-SkipHarnessBuild): reusing the existing build output'
} else {
  Push-Location $HarnessRoot
  try {
    if ($SkipInstall) {
      Write-Info 'pnpm install skipped (-SkipInstall)'
    } else {
      Invoke-Step 'pnpm install' {
        Invoke-Logged 'pnpm install' (Join-Path $LogDir '01-install.log') { & pnpm install --frozen-lockfile }
      }
    }
    # `clean` drops build output plus residue of packages deleted upstream: a
    # stale package directory without package.json breaks the tsdown workspace
    # build (see HANDOFF-BUILD-ISSUE.md).
    Invoke-Step 'pnpm run clean' {
      Invoke-Logged 'pnpm run clean' (Join-Path $LogDir '02-clean.log') { & pnpm run clean }
    }
    Invoke-Step 'pnpm run build:official' {
      Invoke-Logged 'pnpm run build:official' (Join-Path $LogDir '03-build-official.log') { & pnpm run build:official }
    }
  } finally { Pop-Location }
}

Write-Phase '3/5 repack tarballs'
if ($SkipRepack) {
  Write-Info 'skipped (-SkipRepack): reusing the existing tarball directories'
} else {
  Invoke-Step '07-repack.ps1' {
    $env:HARNESS_ROOT = $HarnessRoot
    $env:OUT_SUFFIX = $Suffix
    Invoke-Logged '07-repack.ps1' (Join-Path $LogDir '04-repack.log') {
      & (Join-Path $PSScriptRoot 'linux-assemble\07-repack.ps1')
    }
  }
}

foreach ($entry in @(@($npmSrc, 'dsh family'), @($vendorSrc, 'vendor'))) {
  $dir, $what = $entry
  if (-not (Test-Path $dir)) { Fail "$what tarballs missing: $dir (run without -SkipRepack)" }
  $count = @(Get-ChildItem -LiteralPath $dir -Filter '*.tgz').Count
  if ($count -eq 0) { Fail "$what tarballs missing: $dir contains no .tgz" }
  Write-Info "$what tarballs: $count in dist\$([System.IO.Path]::GetFileName($dir))"
}

# ----------------------------------------------------------------- 4. assemble
Write-Phase '4/5 assemble in WSL'
$driverWsl = "$repoWsl/scripts/linux-assemble/build-all.sh"
$wslEnv = @(
  "DSH_LINUX_REPO=$repoWsl"
  "OUT_DIR=$outWsl"
  "DSH_TGZ_SRC=$(ConvertTo-WslPath $npmSrc)"
  "VENDOR_TGZ_SRC=$(ConvertTo-WslPath $vendorSrc)"
  "VARIANTS=$($Variants -join ',')"
  "PACKAGE_VERSION=$Version"
  "UPSTREAM_COMMIT=$upstreamShort"
  "UPSTREAM_TAG=$upstreamTag"
  "BUILD_DATE=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
  "LOG_DIR=$(ConvertTo-WslPath $LogDir)"
)
# dist/npm-landlock carried the landlock entry package used up to dsh 0.1.2.
# From 0.1.5 the native primitives (@deepseek-ai/node-addon-system) resolve from
# the registry during the install, so this input is opt-in: staging the old
# package would ship a dead dependency and shadow the shipped launcher.
if ($LandlockTgzSrc) {
  if (-not (Test-Path $LandlockTgzSrc)) { Fail "LandlockTgzSrc not found: $LandlockTgzSrc" }
  $wslEnv += "LANDLOCK_TGZ_SRC=$(ConvertTo-WslPath $LandlockTgzSrc)"
  Write-Info "legacy landlock tarballs staged from $LandlockTgzSrc"
}
if ($StageDir) { $wslEnv += "STAGE_DIR=$StageDir" }
if ($SystemNode) { $wslEnv += "SYSTEM_NODE=$SystemNode" }
if ($ReuseStage) { $wslEnv += 'SKIP_INSTALL=1' }
if ($SkipSmoke) { $wslEnv += 'SKIP_SMOKE=1' }

Write-Info "wsl.exe -d $Distro -e env DSH_LINUX_ENV=<env file> bash $driverWsl"
Invoke-Step 'build-all.sh' {
  # The environment travels in a file: values with spaces (VARIANTS) or non-ASCII
  # would not survive a Windows -> WSL command line intact.
  $envFile = Join-Path $LogDir 'build-all.env'
  $envBody = @('# generated by scripts/build-linux.ps1; sourced by build-all.sh')
  foreach ($entry in $wslEnv) {
    $name, $value = $entry -split '=', 2
    $envBody += "$name='" + $value.Replace("'", "'\''") + "'"
  }
  Write-TextFile $envFile ($envBody -join "`n")
  Invoke-Logged 'build-all.sh' (Join-Path $LogDir '05-assemble.log') {
    Invoke-Wsl (@('-d', $Distro, '-e', 'env', "DSH_LINUX_ENV=$(ConvertTo-WslPath $envFile)", 'bash', $driverWsl))
  }
}

# ----------------------------------------------------------------- 5. deliver
Write-Phase '5/5 deliverables'
$artifactMap = [ordered]@{
  'full'       = 'dsh-linux-x64.tar.gz'
  'slim'       = 'dsh-linux-x64-slim.tar.gz'
  'basic'      = 'dsh-linux-x64-basic.tar.gz'
  'basic-slim' = 'dsh-linux-x64-basic-slim.tar.gz'
}
# The basic variants are pruned copies of the full/slim bundles, so their sources
# are produced as well even when only they were requested.
$produced = [System.Collections.Generic.List[string]]::new()
foreach ($v in @('full', 'slim', 'basic', 'basic-slim')) {
  if ($Variants -contains $v) { $produced.Add($v) }
}
if (($Variants -contains 'basic') -and -not $produced.Contains('full')) { $produced.Add('full') }
if (($Variants -contains 'basic-slim') -and -not $produced.Contains('slim')) { $produced.Add('slim') }

foreach ($entry in @(@('operator-readme.md', 'README.md'), @('operator-readme.zh.md', 'README.zh.md'))) {
  $srcName, $dstName = $entry
  $src = Join-Path $RepoRoot "docs\$srcName"
  if (Test-Path $src) {
    Copy-Item -LiteralPath $src -Destination (Join-Path $DistDir $dstName) -Force
    Write-Info "operator README: docs\$srcName -> dist\linux\$dstName"
  } else {
    Write-Info "WARN: docs\$srcName missing; dist\linux\$dstName not refreshed"
  }
}

$artifacts = @()
foreach ($variant in $produced) {
  $file = Join-Path $DistDir $artifactMap[$variant]
  if (-not (Test-Path $file)) { Fail "expected deliverable missing: $file" }
  $item = Get-Item -LiteralPath $file
  $record = [ordered]@{
    variant = $variant
    file    = $item.Name
    bytes   = $item.Length
    mib     = [math]::Round($item.Length / 1MB, 1)
  }
  if (-not $SkipHash) { $record.sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
  $artifacts += $record
  Write-Info ("{0,-30} {1,8:N1} MiB" -f $item.Name, ($item.Length / 1MB))
}

$info = [ordered]@{
  package        = 'dsh-linux'
  dshVersion     = $Version
  upstreamTag    = $upstreamTag
  upstreamCommit = $upstreamCommit
  upstreamDirty  = $upstreamDirty
  built          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  builtBy        = [ordered]@{
    node      = $nodeVersion
    pnpm      = $pnpmVersion
    wslDistro = $Distro
    stage     = $(if ($StageDir) { $StageDir } else { '$HOME/dsh-linux-build' })
  }
  variants       = @($produced)
  artifacts      = $artifacts
}
$infoPath = Join-Path $DistDir 'build-info.json'
Write-TextFile $infoPath ($info | ConvertTo-Json -Depth 6)
Write-Info "manifest: $infoPath"

if ($Extract) {
  Write-Info 're-extract tarballs (integrity check + convenience dirs)'
  Invoke-Step 're-extract' {
    Invoke-Wsl @('-d', $Distro, '-e', 'env', "OUT_DIR=$outWsl", 'bash', "$repoWsl/scripts/linux-assemble/22-re-extract.sh")
  }
}

$total = (Get-Date) - $script:Started
Write-Host ''
Write-Host ('=' * 72)
Write-Host (" dsh $Version packaged in {0:hh}h{0:mm}m{0:ss}s" -f $total)
Write-Host ('=' * 72)
foreach ($a in $artifacts) {
  $hash = if ($a.sha256) { $a.sha256.Substring(0, 16) + '...' } else { '' }
  Write-Host ("  {0,-30} {1,8:N1} MiB  {2}" -f $a.file, $a.mib, $hash)
}
Write-Host ''
Write-Host '  update notes : CHANGELOG.zh.md / CHANGELOG.md'
Write-Host '  ship         : scp dist/linux/dsh-linux-x64*.tar.gz <target>:/opt/'
