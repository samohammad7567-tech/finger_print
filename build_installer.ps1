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

    # --- 2b. Verify the payload satisfies every import ---------------------
    # The one failure this build cannot see in its own output: the runner
    # imports a runtime DLL that the installer does not carry. It works here,
    # because a developer machine has the system-wide redistributable to fall
    # back on, and dies on a clean staff machine with 0xc0000135 before
    # wWinMain runs - no window, no error dialog, nothing in the event log that
    # names the app. Which satellites the compiler references changes when the
    # toolset updates (v145 added vcruntime140_threads.dll), so this is checked
    # rather than assumed.
    #
    # Imports are read out of the PE import directory instead of by guessing
    # from a hard-coded list.
    function Get-PEImportedModules {
        param([Parameter(Mandatory)][string]$Path)

        $bytes = [IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -lt 0x40) { throw "$Path is too small to be a PE image." }
        if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { throw "$Path is not a PE image (no MZ)." }

        $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        if ([BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x00004550) {
            throw "$Path is not a PE image (no PE signature)."
        }

        $coff            = $peOffset + 4
        $sectionCount    = [BitConverter]::ToUInt16($bytes, $coff + 2)
        $optionalSize    = [BitConverter]::ToUInt16($bytes, $coff + 16)
        $optional        = $coff + 20
        $magic           = [BitConverter]::ToUInt16($bytes, $optional)
        # PE32+ carries eight more bytes before the data directories than PE32.
        $dataDirectories = if ($magic -eq 0x20B) { $optional + 112 } else { $optional + 96 }
        $importRva       = [BitConverter]::ToUInt32($bytes, $dataDirectories + 8)
        if ($importRva -eq 0) { return @() }

        # RVA -> file offset, through the section table that follows the
        # optional header.
        $sections = @(0..([int]$sectionCount - 1) | ForEach-Object {
            $s = $optional + $optionalSize + ($_ * 40)
            [pscustomobject]@{
                VirtualAddress = [BitConverter]::ToUInt32($bytes, $s + 12)
                VirtualSize    = [BitConverter]::ToUInt32($bytes, $s + 8)
                RawOffset      = [BitConverter]::ToUInt32($bytes, $s + 20)
                RawSize        = [BitConverter]::ToUInt32($bytes, $s + 16)
            }
        })

        function Convert-Rva([uint32]$rva) {
            foreach ($s in $sections) {
                $span = [Math]::Max($s.VirtualSize, $s.RawSize)
                if ($rva -ge $s.VirtualAddress -and $rva -lt ($s.VirtualAddress + $span)) {
                    return [int]($s.RawOffset + ($rva - $s.VirtualAddress))
                }
            }
            return -1
        }

        $names  = New-Object System.Collections.Generic.List[string]
        $cursor = Convert-Rva $importRva
        if ($cursor -lt 0) { return @() }

        # IMAGE_IMPORT_DESCRIPTOR is 20 bytes; an all-zero one ends the table.
        while ($true) {
            $nameRva = [BitConverter]::ToUInt32($bytes, $cursor + 12)
            if ($nameRva -eq 0) { break }
            $at = Convert-Rva $nameRva
            if ($at -lt 0) { break }
            $end = $at
            while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
            $names.Add([Text.Encoding]::ASCII.GetString($bytes, $at, $end - $at))
            $cursor += 20
        }

        return $names.ToArray()
    }

    # Everything the installer puts next to the exe: the Release folder's own
    # binaries plus the CRT DLLs scrip.iss copies in.
    $shipped = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    Get-ChildItem $release -Filter '*.dll' -File | ForEach-Object { [void]$shipped.Add($_.Name) }
    @(
        'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'msvcp140_atomic_wait.dll',
        'msvcp140_codecvt_ids.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
        'vcruntime140_threads.dll', 'concrt140.dll'
    ) | Where-Object { Test-Path (Join-Path $crt.FullName $_) } | ForEach-Object { [void]$shipped.Add($_) }

    # Imports resolved by Windows itself rather than by the payload: the Win32
    # DLLs in System32 and the Universal CRT, which every supported Windows
    # build carries. Anything outside these two sets has to be in the payload.
    $missing = @()
    foreach ($image in @($exe) + @(Get-ChildItem $release -Filter '*.dll' -File | ForEach-Object { $_.FullName })) {
        foreach ($import in (Get-PEImportedModules -Path $image)) {
            if ($import -like 'api-ms-win-*') { continue }
            if ($import -like 'ext-ms-win-*') { continue }
            if (Test-Path (Join-Path $env:SystemRoot "System32\$import")) { continue }
            if ($shipped.Contains($import)) { continue }
            $missing += "$([IO.Path]::GetFileName($image)) -> $import"
        }
    }

    if ($missing.Count -gt 0) {
        throw ("The installer payload does not satisfy every import, so the app would fail to " +
               "start on a machine without the Visual C++ redistributable:`n  " +
               ($missing -join "`n  ") +
               "`nAdd the missing DLL to the [Files] section of scrip.iss.")
    }
    Write-Host '==> imports satisfied by the payload' -ForegroundColor Cyan

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
