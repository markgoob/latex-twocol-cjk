# package-skill.ps1 - build a .skill archive that installers will actually accept.
#
# Do NOT use Compress-Archive for this. Windows PowerShell 5.1 writes the
# platform separator into the archive, so entries come out as
# "latex-twocol-cjk\SKILL.md". The ZIP spec (APPNOTE 4.4.17.1) requires forward
# slashes, and a strict reader rejects the file with
# "Zip file contains path with invalid characters".
#
# This builds each entry by hand so the stored names are controlled explicitly,
# then verifies the result before handing it back.
#
#   .\scripts\package-skill.ps1                       # -> latex-twocol-cjk.skill
#   .\scripts\package-skill.ps1 -Version v1.0.1       # -> latex-twocol-cjk-v1.0.1.skill

[CmdletBinding()]
param(
    # Folder holding SKILL.md. Defaults to the repo root, i.e. the parent of scripts/.
    [string] $Source = (Split-Path -Parent $PSScriptRoot),

    # Name of the folder as it appears inside the archive, and of the installed skill.
    [string] $SkillName = 'latex-twocol-cjk',

    [string] $Version,

    [string] $OutDir = (Get-Location).Path,

    # Repo scaffolding that must not ship inside the skill.
    [string[]] $Exclude = @('LICENSE', 'README.md', 'README.zh-TW.md', '.gitattributes', '.gitignore')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Source = (Resolve-Path -LiteralPath $Source).Path
if (-not (Test-Path (Join-Path $Source 'SKILL.md'))) {
    throw "No SKILL.md in $Source - point -Source at the skill folder."
}

$suffix  = if ($Version) { "-$Version" } else { '' }
$outFile = Join-Path $OutDir "$SkillName$suffix.skill"
if (Test-Path $outFile) { Remove-Item $outFile -Force }

# Everything under Source except the git directory, the scaffolding, and any
# build residue the template leaves behind.
$files = Get-ChildItem $Source -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($Source.Length + 1)
    $top = ($rel -split '[\\/]')[0]
    $top -ne '.git' -and
    $top -ne '.github' -and
    $Exclude -notcontains $rel -and
    $_.Extension -notin @('.aux', '.log', '.fls', '.fdb_latexmk', '.out', '.pdf', '.synctex.gz')
}

if (-not $files) { throw "Nothing to package under $Source." }

$zip = [System.IO.Compression.ZipFile]::Open($outFile, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Source.Length + 1)
        # The one line that matters: forward slashes, always.
        $entryName = "$SkillName/" + ($rel -replace '\\', '/')
        $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $f.LastWriteTime
        $out = $entry.Open()
        try {
            $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
            $out.Write($bytes, 0, $bytes.Length)
        } finally { $out.Dispose() }
    }
} finally { $zip.Dispose() }

# Verify rather than assume: this script exists because an unverified archive
# shipped once already.
$zip = [System.IO.Compression.ZipFile]::OpenRead($outFile)
try {
    $bad = @()
    foreach ($e in $zip.Entries) {
        if ($e.FullName -match '\\')            { $bad += "backslash: $($e.FullName)" }
        if ($e.FullName -match '^[/]|^[A-Za-z]:') { $bad += "absolute: $($e.FullName)" }
        if ($e.FullName -match '(^|/)\.\.(/|$)') { $bad += "traversal: $($e.FullName)" }
    }
    $names = $zip.Entries | ForEach-Object { $_.FullName }
    if ($names -notcontains "$SkillName/SKILL.md") { $bad += "missing $SkillName/SKILL.md at archive root" }
} finally { $zip.Dispose() }

if ($bad) {
    Remove-Item $outFile -Force
    $bad | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw 'Archive failed verification; not written.'
}

Write-Host "OK  $outFile  ($((Get-Item $outFile).Length) bytes)" -ForegroundColor Green
$names | ForEach-Object { Write-Host "    $_" }
