# check-fonts.ps1 — report which of the template's candidate font families are
# installed on this Windows machine, in the order \PickFont tries them.
# Run before the first build: a missing family is a fatal fontspec error.

$ErrorActionPreference = 'Stop'

$candidates = [ordered]@{
    'Latin serif (rm)' = @('Noto Serif', 'TeX Gyre Termes', 'Times New Roman', 'DejaVu Serif')
    'Latin sans  (sf)' = @('Noto Sans', 'TeX Gyre Heros', 'Arial', 'DejaVu Sans')
    'Latin mono  (tt)' = @('Noto Sans Mono', 'DejaVu Sans Mono', 'Consolas', 'Courier New')
    'CJK serif   (rm)' = @('Noto Serif CJK TC', 'Noto Serif TC', 'Source Han Serif TC', 'PMingLiU', 'MingLiU', 'Microsoft JhengHei')
    'CJK sans    (sf)' = @('Noto Sans CJK TC', 'Noto Sans TC', 'Source Han Sans TC', 'Microsoft JhengHei', 'PMingLiU')
    'CJK mono    (tt)' = @('Noto Sans Mono CJK TC', 'Noto Sans TC', 'Microsoft JhengHei', 'MingLiU')
}

# Registered font families: machine-wide plus per-user installs.
$installed = New-Object System.Collections.Generic.HashSet[string]
foreach ($hive in 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                  'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
    try { $props = Get-ItemProperty $hive } catch { continue }
    foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -like 'PS*') { continue }
        # Registry names look like "Noto Serif TC (TrueType)" or
        # "Microsoft JhengHei & Microsoft JhengHei UI (TrueType)".
        $name = $p.Name -replace '\s*\((TrueType|OpenType|VariableFont)\)\s*$', ''
        foreach ($part in $name -split '\s*&\s*') { [void]$installed.Add($part.Trim()) }
    }
}

$anyMissing = $false
foreach ($slot in $candidates.Keys) {
    $chosen = $null
    foreach ($f in $candidates[$slot]) { if ($installed.Contains($f)) { $chosen = $f; break } }
    if ($chosen) {
        Write-Host ("{0,-18} -> {1}" -f $slot, $chosen) -ForegroundColor Green
    } else {
        $anyMissing = $true
        Write-Host ("{0,-18} -> NONE INSTALLED" -f $slot) -ForegroundColor Red
        Write-Host ("{0,-18}    tried: {1}" -f '', ($candidates[$slot] -join ', ')) -ForegroundColor DarkGray
    }
}

Write-Host ''
if ($anyMissing) {
    Write-Host 'Install the missing families before building.' -ForegroundColor Yellow
    Write-Host 'Traditional Chinese: https://fonts.google.com/noto/specimen/Noto+Serif+TC'
    Write-Host 'Install for all users, or MiKTeX/TeX Live may not see them.'
    exit 1
}

# The variable-font weight trap: a family whose only file is a VF resolves to
# its first named instance, which for Noto TC is ExtraLight.
$vf = @(Get-ChildItem "$env:WINDIR\Fonts" -Filter '*-VF.ttf' -ErrorAction SilentlyContinue)
if ($vf.Count -gt 0) {
    Write-Host 'Variable fonts present:' -ForegroundColor Cyan
    $vf | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host 'The template pins RawFeature={axis={wght=400}} for these - keep it,'
    Write-Host 'or Chinese text renders in ExtraLight with no warning.' -ForegroundColor Cyan
}

Write-Host 'All font slots resolved.' -ForegroundColor Green
