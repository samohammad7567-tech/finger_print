<#
    Downloads the four families the type scale is built on into assets/fonts.

        powershell -ExecutionPolicy Bypass -File tool\fetch_fonts.ps1

    The fonts are committed to the repository, so this only needs running when a
    weight is added to lib/core/style/theme/app_text_styles.dart or a family is
    replaced. It exists so that set is reproducible rather than a folder of
    files nobody remembers the provenance of.

    All four are SIL Open Font License 1.1 - IBM Plex from IBM, Spectral from
    the Spectral Project Authors. The OFL allows redistribution inside an
    application; both licences ship verbatim beside the faces, in
    assets/fonts/OFL-IBMPlex.txt and assets/fonts/OFL-Spectral.txt.

    Static TTFs, not the variable versions: Flutter maps a `fontWeight` onto a
    variable font's `wght` axis inconsistently across platforms, and a desktop
    app that renders a 600 as a synthesised 400 on one machine is exactly the
    class of difference bundling the fonts is meant to remove. The Google Fonts
    CSS API serves TTF rather than WOFF2 to a user agent old enough not to
    claim WOFF2 support, which is why the request below sends one.
#>
[CmdletBinding()]
param(
    # Re-download faces already present instead of skipping them.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root   = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'assets\fonts'

# 400/500/600/700 for every family: the scale itself only asks for regular,
# medium and semibold, but `FontWeight.bold` is used directly in the widgets,
# and a weight that is bundled for one family and not another is a bug waiting
# for the one screen that mixes them. Italic is Latin-only and wanted in a
# single place (the attendance detail note), so only the sans carries it.
$families = @(
    [pscustomobject]@{ Api = 'IBM Plex Sans';        File = 'IBMPlexSans';       Italic = $true  },
    [pscustomobject]@{ Api = 'IBM Plex Sans Arabic'; File = 'IBMPlexSansArabic'; Italic = $false },
    [pscustomobject]@{ Api = 'IBM Plex Mono';        File = 'IBMPlexMono';       Italic = $false },
    [pscustomobject]@{ Api = 'Spectral';             File = 'Spectral';          Italic = $false }
)

$weightNames = @{ '400' = 'Regular'; '500' = 'Medium'; '600' = 'SemiBold'; '700' = 'Bold' }

# Old enough that the API serves format('truetype') rather than WOFF2.
$userAgent = 'Mozilla/4.0'

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$downloaded = 0
$skipped    = 0

foreach ($family in $families) {
    $spec = if ($family.Italic) {
        'ital,wght@0,400;0,500;0,600;0,700;1,400'
    } else {
        'wght@400;500;600;700'
    }

    $query = ($family.Api -replace ' ', '+') + ':' + $spec
    $url   = "https://fonts.googleapis.com/css2?family=$query"

    Write-Host "==> $($family.Api)" -ForegroundColor Cyan
    $css = (Invoke-WebRequest -Uri $url -UserAgent $userAgent -UseBasicParsing).Content

    # Each @font-face block carries its style, its weight and its URL in that
    # order, so one regex over the whole sheet pairs them without splitting it.
    $pattern = "font-style:\s*(?<style>\w+);\s*font-weight:\s*(?<weight>\d+);(?:[^}]*?)src:\s*url\((?<url>[^)]+)\)"
    $matched = [regex]::Matches($css, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)

    if ($matched.Count -eq 0) {
        throw "No @font-face blocks parsed for $($family.Api). The CSS API response format may have changed:`n$css"
    }

    foreach ($m in $matched) {
        $weight = $m.Groups['weight'].Value
        $style  = $m.Groups['style'].Value
        $href   = $m.Groups['url'].Value

        if (-not $weightNames.ContainsKey($weight)) { continue }
        if ($href -notmatch '\.ttf$') {
            throw "The API served $href for $($family.Api) $weight - expected a .ttf. Check the user agent."
        }

        $suffix = if ($style -eq 'italic') {
            # Google's own naming: the 400 italic is "-Italic", heavier ones
            # pair the weight name with it.
            if ($weight -eq '400') { 'Italic' } else { $weightNames[$weight] + 'Italic' }
        } else {
            $weightNames[$weight]
        }

        $name = "$($family.File)-$suffix.ttf"
        $path = Join-Path $outDir $name

        if ((Test-Path $path) -and -not $Force) {
            $skipped++
            continue
        }

        Invoke-WebRequest -Uri $href -OutFile $path -UseBasicParsing
        $size = [Math]::Round((Get-Item $path).Length / 1KB)
        Write-Host ("    {0,-34} {1,5} KB" -f $name, $size)
        $downloaded++
    }
}

$total = [Math]::Round(((Get-ChildItem $outDir -Filter '*.ttf' | Measure-Object Length -Sum).Sum / 1MB), 2)
Write-Host "==> $downloaded downloaded, $skipped already present - $total MB in assets\fonts" -ForegroundColor Green
Write-Host '    Declare any new file in the fonts: section of pubspec.yaml.' -ForegroundColor DarkGray
