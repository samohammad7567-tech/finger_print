<#
    Builds the Windows release and compiles scrip.iss into
    build\installer\SecureAttend-<version>-Setup.exe.

        powershell -ExecutionPolicy Bypass -File build_installer.ps1
        powershell -ExecutionPolicy Bypass -File build_installer.ps1 -SkipBuild

    The Visual C++ runtime is shipped app-local, so this locates the newest
    Microsoft.VC*.CRT\x64 folder on the machine and hands it to ISCC. That is
    the one input scrip.iss cannot reliably guess, and its hard-coded fallback
    goes stale the moment the Visual Studio toolset updates.
#>
[CmdletBinding()]
param(
    # Reuse an existing build\windows\x64\runner\Release instead of rebuilding.
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
Push-Location $root
try {
    # --- 1. Release build ---------------------------------------------------
    if (-not $SkipBuild) {
        Write-Host '==> flutter build windows --release' -ForegroundColor Cyan
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit code $LASTEXITCODE." }
    }

    $release = Join-Path $root 'build\windows\x64\runner\Release'
    $exe     = Join-Path $release 'attendence.exe'
    if (-not (Test-Path $exe)) {
        throw "Release build not found at $exe. Run without -SkipBuild."
    }

    # --- 2. Locate the VC++ CRT redistributable ----------------------------
    # Newest version wins: the runner is compiled with the newest toolset
    # installed, and an older CRT cannot satisfy its imports.
    $crt = Get-ChildItem -Path @(
                "${env:ProgramFiles}\Microsoft Visual Studio",
                "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
            ) -Directory -Recurse -Depth 8 -Filter 'Microsoft.VC*.CRT' `
            -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Redist\\MSVC\\[\d.]+\\x64\\' -and
                       (Test-Path (Join-Path $_.FullName 'msvcp140.dll')) } |
        Sort-Object { [version](($_.FullName -split '\\Redist\\MSVC\\')[1] -split '\\')[0] } |
        Select-Object -Last 1

    if (-not $crt) {
        throw 'No Microsoft.VC*.CRT\x64 folder with msvcp140.dll found. Install the ' +
              '"MSVC v14x - VS C++ x64/x86 build tools" component in the Visual Studio Installer.'
    }
    Write-Host "==> VC++ runtime: $($crt.FullName)" -ForegroundColor Cyan

    # --- 3. Compile the installer ------------------------------------------
    $iscc = @(
        "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $iscc) {
        throw 'ISCC.exe not found. Install Inno Setup 6.3 or later from https://jrsoftware.org/isdl.php.'
    }

    # Compiled into a staging folder under %TEMP%, then moved into
    # build\installer. Stamping the icon into Setup.exe goes through
    # EndUpdateResource, which Defender's Controlled Folder Access blocks when
    # the output sits under Desktop or Documents — it fails with
    # "Resource update error: EndUpdateResource failed ... (110)". Plain file
    # writes there are fine, so staging elsewhere and moving the finished
    # installer in sidesteps it without asking anyone to weaken Defender.
    $staging = Join-Path ([IO.Path]::GetTempPath()) ("secureattend-installer-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    try {
        Write-Host "==> $iscc scrip.iss" -ForegroundColor Cyan
        & $iscc "/DVCRedistDir=$($crt.FullName)" "/O$staging" (Join-Path $root 'scrip.iss')
        if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE." }

        $built = Get-ChildItem $staging -Filter '*-Setup.exe' |
            Sort-Object LastWriteTime | Select-Object -Last 1
        if (-not $built) { throw "ISCC reported success but produced no *-Setup.exe in $staging." }

        $outDir = Join-Path $root 'build\installer'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        $setup = Join-Path $outDir $built.Name
        Move-Item -LiteralPath $built.FullName -Destination $setup -Force

        Write-Host "==> $setup" -ForegroundColor Green
        Write-Host ('    {0:N1} MB' -f ((Get-Item $setup).Length / 1MB)) -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Pop-Location
}
