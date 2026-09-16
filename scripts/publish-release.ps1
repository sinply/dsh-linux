#Requires -Version 5.1
<#
.SYNOPSIS
    Publish the dsh-linux GitHub release: tag, release notes, and asset upload.

.DESCRIPTION
    Follows the repository's release convention: the tag is v<version>, the title
    is "dsh-linux <version> (Rocky 8/9 Linux bundles)", and the assets are the
    four bundle tarballs plus the operator READMEs and the companion VS Code
    extension when present.

    The release body is derived from the CHANGELOG.zh.md section for this version
    (single source of truth), prefixed with a one-line English summary. Artifact
    sizes and SHA-256 in build-info.json are checked against the files on disk
    before anything is uploaded.

    Authentication: gh needs a token. Provide one through $env:GH_TOKEN, or let
    this script read the stored git credential for github.com (Git Credential
    Manager), which is what the working tree already pushes with.

.PARAMETER Version
    Package version to publish. Default: dshVersion from dist/linux/build-info.json.
.PARAMETER Tag
    Release tag. Default: v<Version>.
.PARAMETER DistDir
    Directory holding the deliverables. Default: <repo>/dist/linux.
.PARAMETER NotesFile
    Markdown body to publish. Default: generated from CHANGELOG.zh.md.
.PARAMETER Assets
    Files to upload. Default: dist/linux/dsh-linux-x64*.tar.gz + README.md +
    README.zh.md + the newest dsh-vscode-*.vsix.
.PARAMETER Commit
    Commit the tag points at. Default: HEAD of the current branch.
.PARAMETER Draft
    Create the release as a draft.
.PARAMETER Prerelease
    Mark the release as a prerelease.
.PARAMETER SkipUpload
    Tag and publish the release body only (no asset upload).
.PARAMETER SkipVerify
    Skip the SHA-256 check of the tarballs against build-info.json.
.PARAMETER DryRun
    Print the resolved plan and exit.

.EXAMPLE
    pwsh -File scripts/publish-release.ps1 -DryRun
.EXAMPLE
    pwsh -File scripts/publish-release.ps1
.EXAMPLE
    pwsh -File scripts/publish-release.ps1 -Draft -SkipUpload
#>
[CmdletBinding()]
param(
  [string]$Version,
  [string]$Tag,
  [string]$DistDir,
  [string]$NotesFile,
  [string[]]$Assets,
  [string]$Commit,
  [switch]$Draft,
  [switch]$Prerelease,
  [switch]$SkipUpload,
  [switch]$SkipVerify,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

function Write-Phase([string]$Text) {
  Write-Host ''
  Write-Host ('=' * 72)
  Write-Host "== $Text"
  Write-Host ('=' * 72)
}
function Write-Info([string]$Text) { Write-Host "   $Text" }
function Fail([string]$Text) { throw $Text }

function Get-GitHubToken {
  if ($env:GH_TOKEN) { return $env:GH_TOKEN }
  if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN }
  $credential = @('protocol=https', 'host=github.com', '') -join "`n" | git credential fill 2>$null
  $password = ($credential | Select-String '^password=').Line -replace '^password=', ''
  if (-not $password) { Fail 'no GitHub token: run `gh auth login`, or set $env:GH_TOKEN' }
  return $password
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $DistDir) { $DistDir = Join-Path $RepoRoot 'dist\linux' }
$manifestPath = Join-Path $DistDir 'build-info.json'
if (-not (Test-Path $manifestPath)) { Fail "no build manifest: $manifestPath (run scripts/build-linux.ps1 first)" }
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $Version) { $Version = $manifest.dshVersion }
if (-not $Version) { Fail 'cannot determine the version; pass -Version' }
if (-not $Tag) { $Tag = "v$Version" }
if (-not $Commit) { $Commit = (& git -C $RepoRoot rev-parse HEAD).Trim() }
$title = "dsh-linux $Version (Rocky 8/9 Linux bundles)"

if (-not $Assets) {
  $patterns = @(
    (Join-Path $DistDir 'dsh-linux-x64*.tar.gz')
    (Join-Path $DistDir 'README.md')
    (Join-Path $DistDir 'README.zh.md')
    (Join-Path $DistDir 'dsh-vscode-*.vsix')
  )
  $Assets = @()
  foreach ($pattern in $patterns) {
    $Assets += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Sort-Object Name |
      ForEach-Object { $_.FullName })
  }
}
if ($Assets.Count -eq 0) { Fail "no assets found under $DistDir" }

Write-Phase 'release plan'
Write-Info "repo      : $RepoRoot"
Write-Info "version   : $Version"
Write-Info "tag       : $Tag -> $Commit"
Write-Info "title     : $title"
Write-Info "dist      : $DistDir"
Write-Info "draft     : $($Draft.IsPresent)   prerelease: $($Prerelease.IsPresent)"
foreach ($asset in $Assets) {
  $item = Get-Item -LiteralPath $asset
  Write-Info ("asset     : {0,-34} {1,8:N1} MiB" -f $item.Name, ($item.Length / 1MB))
}

# ---------------------------------------------------------------- verification
Write-Phase 'verify artifacts against build-info.json'
if ($SkipVerify) {
  Write-Info 'skipped (-SkipVerify)'
} else {
  foreach ($record in $manifest.artifacts) {
    $file = Join-Path $DistDir $record.file
    if (-not (Test-Path $file)) { Fail "manifest lists a missing artifact: $file" }
    $item = Get-Item -LiteralPath $file
    if ($item.Length -ne $record.bytes) { Fail "$($record.file): size $($item.Length) != manifest $($record.bytes)" }
    if ($record.sha256) {
      $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($hash -ne $record.sha256) { Fail "$($record.file): sha256 $hash != manifest $($record.sha256)" }
      Write-Info "$($record.file): size ok, sha256 ok"
    } else {
      Write-Info "$($record.file): size ok (no sha256 in manifest)"
    }
  }
}

# ---------------------------------------------------------------- release body
if (-not $NotesFile) {
  $changelog = Join-Path $RepoRoot 'CHANGELOG.zh.md'
  if (-not (Test-Path $changelog)) { Fail "no changelog: $changelog (pass -NotesFile)" }
  # Windows PowerShell 5.1 defaults Get-Content to the ANSI code page; the
  # changelog is UTF-8 without BOM, so read it explicitly.
  $lines = Get-Content $changelog -Encoding UTF8
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^##\s+$([regex]::Escape($Version))\b") { $start = $i; break }
  }
  if ($start -lt 0) { Fail "CHANGELOG.zh.md has no '## $Version' section (pass -NotesFile)" }
  $end = $lines.Count
  for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s') { $end = $i; break }
  }
  $summary = @(
    "Offline self-contained DeepSeek Harness bundles for Rocky Linux 8/9 (x86_64), glibc >= 2.28 - dsh $Version.",
    '',
    'Upgrading from 0.1.2-rc.1? The session on-disk format moved V0 -> V3: back up `$DSH_HOME` before the first launch and do not roll back afterwards.',
    'Independent third-party packaging project, not affiliated with DeepSeek.',
    '',
    '---',
    ''
  )
  $body = ($summary + $lines[$start..($end - 1)]) -join "`n"
  $NotesFile = Join-Path $DistDir 'release-notes.md'
  [System.IO.File]::WriteAllText($NotesFile, $body, [System.Text.UTF8Encoding]::new($false))
  Write-Info "release body: CHANGELOG.zh.md [## $Version] -> $NotesFile"
} else {
  if (-not (Test-Path $NotesFile)) { Fail "notes file not found: $NotesFile" }
  Write-Info "release body: $NotesFile"
}

if ($DryRun) { Write-Host ''; Write-Host 'DryRun: no tag, release, or upload performed.'; return }

# ------------------------------------------------------------------- tag, push
Write-Phase "tag $Tag"
$env:GH_TOKEN = Get-GitHubToken
$existingLocal = (& git -C $RepoRoot tag --list $Tag)
if ($existingLocal) {
  Write-Info "local tag $Tag already exists (left as is)"
} else {
  & git -C $RepoRoot tag $Tag $Commit
  if ($LASTEXITCODE -ne 0) { Fail "git tag $Tag failed" }
  Write-Info "created local tag $Tag -> $Commit"
}
& git -C $RepoRoot push origin "refs/tags/$Tag" 2>&1 | ForEach-Object { Write-Info $_ }
if ($LASTEXITCODE -ne 0) { Fail "git push tag $Tag failed" }
Write-Info 'tag pushed'

# --------------------------------------------------------------------- release
Write-Phase "publish release $Tag"
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  $exists = (& gh release view $Tag --json tagName 2>$null | Out-String).Trim()
} finally { $ErrorActionPreference = $previous }
if ($exists) {
  Write-Info 'release exists — updating title/body'
  & gh release edit $Tag --title $title --notes-file $NotesFile
  if ($LASTEXITCODE -ne 0) { Fail 'gh release edit failed' }
} else {
  $args = @('release', 'create', $Tag, '--title', $title, '--notes-file', $NotesFile)
  if ($Draft) { $args += '--draft' }
  if ($Prerelease) { $args += '--prerelease' }
  & gh @args
  if ($LASTEXITCODE -ne 0) { Fail 'gh release create failed' }
}
if (-not $SkipUpload) {
  Write-Host ''
  Write-Info "uploading $($Assets.Count) asset(s) — this streams ~$([math]::Round((($Assets | ForEach-Object { (Get-Item $_).Length }) | Measure-Object -Sum).Sum / 1GB, 2)) GB"
  & gh release upload $Tag @Assets --clobber
  if ($LASTEXITCODE -ne 0) { Fail 'gh release upload failed' }
} else {
  Write-Info 'asset upload skipped (-SkipUpload)'
}

Write-Phase 'release published'
& gh release view $Tag --json url,isDraft,isPrerelease,assets --template '{{.url}}{{"\n"}}draft={{.isDraft}} prerelease={{.isPrerelease}}{{"\n"}}{{range .assets}}{{.name}}{{"  "}}{{.size}}{{"\n"}}{{end}}'
