# build.ps1 — compile a LuaLaTeX CJK document in a TeX Live container, with the
# machine's own fonts mounted so the build sees exactly the families you have.
# Use when no TeX distribution is installed locally.
#
#   .\scripts\build.ps1 main.tex
#   .\scripts\build.ps1 main.tex -Clean

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $TexFile,

    [string] $Image = 'texlive/texlive:latest-medium',

    # Packages missing from the -medium scheme that this template needs.
    # 'preprint' carries balance.sty; 'caption' carries subcaption.sty.
    [string[]] $ExtraPackages = @('preprint', 'titlesec', 'placeins', 'xurl', 'multirow', 'noto'),

    [switch] $Clean
)

# Deliberately NOT 'Stop': docker writes routine messages ("No such container")
# to stderr, and under ErrorActionPreference=Stop PowerShell promotes those to
# terminating errors even when docker exits 0. Exit codes are checked by hand.
$ErrorActionPreference = 'Continue'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker not found. Install Docker Desktop, or install TeX Live and run 'latexmk -lualatex' directly."
    exit 2
}

function Remove-ContainerIfPresent([string] $Name) {
    $id = (docker ps -aq --filter "name=^/$Name$" | Out-String).Trim()
    if ($id) { docker rm -f $Name | Out-Null }
}

$source = Resolve-Path -LiteralPath $TexFile
$dir    = Split-Path -Parent $source
$name   = Split-Path -Leaf $source

# A prepared image is cached under this tag so the tlmgr step runs only once.
$prepared = 'latex-cjk-build:local'
# 'docker images -q' returns an empty string for a missing tag and still exits 0;
# 'image inspect' writes to stderr, which PowerShell turns into a terminating error.
$exists = (docker images -q $prepared | Out-String).Trim()
if ([string]::IsNullOrEmpty($exists)) {
    Write-Host "Preparing $prepared (one time, a few minutes)..." -ForegroundColor Cyan
    Remove-ContainerIfPresent 'latex-cjk-prep'
    $tlmgr = "tlmgr install $($ExtraPackages -join ' ')"
    docker run --name latex-cjk-prep $Image sh -c $tlmgr
    if ($LASTEXITCODE -ne 0) {
        Remove-ContainerIfPresent 'latex-cjk-prep'
        Write-Error "tlmgr install failed."
        exit 3
    }
    docker commit latex-cjk-prep $prepared | Out-Null
    Remove-ContainerIfPresent 'latex-cjk-prep'
}

$fonts = Join-Path $env:WINDIR 'Fonts'
$script = @"
fc-cache -f > /dev/null 2>&1
cd /work || exit 1
$(if ($Clean) { 'latexmk -C > /dev/null 2>&1' })
latexmk -lualatex -interaction=nonstopmode -halt-on-error '$name'
status=`$?
log='/work/$($name -replace '\.tex$', '.log')'
echo "--- build exit: `$status ---"
# grep -c prints the count and exits 1 when there is no match, so no '|| echo 0'.
for pattern in 'Missing character' 'Font shape .* undefined' 'Overfull' 'Underfull'; do
  printf '%-28s %s\n' "`$pattern" "`$(grep -c "`$pattern" "`$log" 2>/dev/null)"
done
grep -E '^(LaTeX|Package|Class) .*Warning' "`$log" 2>/dev/null | sort -u
exit `$status
"@

$scriptPath = Join-Path $dir '.build-in-container.sh'
# Unix line endings, no BOM: the container's /bin/sh will not tolerate CRLF.
[System.IO.File]::WriteAllText($scriptPath, ($script -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

try {
    docker run --rm `
        -v "${dir}:/work" `
        -v "${fonts}:/usr/share/fonts/win:ro" `
        -w /work `
        $prepared sh /work/.build-in-container.sh
    $code = $LASTEXITCODE
}
finally {
    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
}

if ($code -eq 0) {
    Write-Host "OK: $($name -replace '\.tex$', '.pdf')" -ForegroundColor Green
} else {
    Write-Host "Build failed. See references/troubleshooting.md" -ForegroundColor Red
}
exit $code
