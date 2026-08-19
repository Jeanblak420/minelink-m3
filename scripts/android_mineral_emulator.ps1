# New Android emulator (API 34, Google APIs). Uses subst only when the SDK path contains spaces
# (sdkmanager breaks --sdk_root on paths like C:\Users\Somebody Someone\...).
param(
    [switch]$Launch,
    [switch]$RunFlutter,
    # Leave empty to auto-pick a free drive letter or reuse subst that already points at this SDK.
    [string]$DriveLetter = ''
)

$ErrorActionPreference = 'Stop'

$studioBin = 'C:\Program Files\Android\Android Studio\bin'
$studioJbr = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path $studioBin) {
    $env:Path = "$studioBin;$env:Path"
}
if (-not $env:JAVA_HOME -and (Test-Path (Join-Path $studioJbr 'bin\java.exe'))) {
    $env:JAVA_HOME = $studioJbr
}

function Get-AndroidSdkRoot {
    foreach ($v in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
        if ($v -and (Test-Path -LiteralPath $v)) {
            return (Resolve-Path -LiteralPath $v).Path
        }
    }
    return (Join-Path $env:LOCALAPPDATA 'Android\sdk')
}

function Test-PathHasAsciiSpace([string]$p) {
    return ($p -match ' ')
}

function Get-SubstMappings {
    $map = @{}
    (& subst.exe 2>$null) | ForEach-Object {
        if ($_ -match '^(\w):\\: => (.+)$') {
            $letter = $Matches[1].ToUpperInvariant()
            $target = $Matches[2].Trim().TrimEnd('\')
            $map[$letter] = $target
        }
    }
    return $map
}

function Resolve-NormalizedPath([string]$p) {
    try { return (Resolve-Path -LiteralPath $p).Path.TrimEnd('\') } catch { return $p.TrimEnd('\') }
}

function Get-DriveLetterForSdk {
    param([string]$SdkPath, [string]$Preferred)
    $normSdk = (Resolve-NormalizedPath $SdkPath)

    $substMap = Get-SubstMappings
    foreach ($pair in $substMap.GetEnumerator()) {
        $t = $pair.Value
        try { $nt = (Resolve-NormalizedPath $t) } catch { continue }
        if ($nt -eq $normSdk) {
            Write-Host "Reusing existing subst $($pair.Key): -> $normSdk"
            return $pair.Key
        }
    }

    if ($Preferred) {
        $L = $Preferred.ToUpperInvariant()
        if ($substMap.ContainsKey($L)) {
            $nt = Resolve-NormalizedPath $substMap[$L]
            if ($nt -ne $normSdk) {
                throw "Drive ${L}: is already subst to $nt. Use -DriveLetter <other> or clear that subst."
            }
            return $L
        }
        subst.exe "${L}:" $normSdk | Out-Null
        if (Test-Path "${L}:\cmdline-tools\latest\bin\sdkmanager.bat") { return $L }
        throw "Could not map ${L}: to SDK."
    }

    foreach ($L in @('M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z')) {
        if ($substMap.ContainsKey($L)) { continue }
        if (Test-Path "${L}:\") { continue }
        subst.exe "${L}:" $normSdk | Out-Null
        if (Test-Path "${L}:\cmdline-tools\latest\bin\sdkmanager.bat") {
            Write-Host "Mapped SDK to ${L}: (path contains spaces)."
            return $L
        }
        subst.exe "${L}:" /d 2>$null | Out-Null
    }
    throw "No free drive letter M..Z to subst the SDK. Free one up or move ANDROID_SDK_ROOT to a path without spaces."
}

$sdk = Get-AndroidSdkRoot
$pkg = 'system-images;android-34;google_apis;x86_64'
$avdName = 'Mineral_Guide_API34'
$sysImg = Join-Path $sdk 'system-images\android-34\google_apis\x86_64\system.img'
$sdkMgr = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
$avdMgr = Join-Path $sdk 'cmdline-tools\latest\bin\avdmanager.bat'
$emu = Join-Path $sdk 'emulator\emulator.exe'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$root = Split-Path -Parent $PSScriptRoot

function Test-SdkTools {
    if (-not (Test-Path $sdkMgr)) { throw "Missing sdkmanager: $sdkMgr. Install Android SDK Command-line Tools." }
    if (-not (Test-Path $avdMgr)) { throw "Missing avdmanager: $avdMgr" }
    if (-not (Test-Path $emu)) { throw "Missing emulator: $emu" }
}

function Get-EmulatorList {
    $raw = & $emu -list-avds 2>$null
    if (-not $raw) { return @() }
    return @($raw | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
}

Test-SdkTools

$sdkRootArg = $sdk
if (Test-PathHasAsciiSpace $sdk) {
    $L = Get-DriveLetterForSdk -SdkPath $sdk -Preferred $DriveLetter
    $sdkRootArg = "${L}:"
    $sdkMgrOnDrive = "${L}:\cmdline-tools\latest\bin\sdkmanager.bat"
    $avdMgrOnDrive = "${L}:\cmdline-tools\latest\bin\avdmanager.bat"
} else {
    $sdkMgrOnDrive = $sdkMgr
    $avdMgrOnDrive = $avdMgr
    Write-Host "SDK path has no spaces; using --sdk_root directly (no subst)."
}

if (-not (Test-Path $sysImg)) {
    Write-Host "Installing platforms;android-34 + $pkg (first run can take several minutes)..."
    & $sdkMgrOnDrive @(
        "--sdk_root=$sdkRootArg",
        '--install',
        'platforms;android-34',
        $pkg
    )
    if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed with exit $LASTEXITCODE" }
}

if (-not (Test-Path $sysImg)) {
    throw "system.img still missing at $sysImg. Check disk space and network, then run this script again."
}

$existing = Get-EmulatorList
if ($existing -contains $avdName) {
    Write-Host "AVD '$avdName' already exists."
} else {
    Write-Host "Creating AVD '$avdName'..."
    & $avdMgrOnDrive @('create', 'avd', '-n', $avdName, '-k', $pkg, '-d', 'pixel_6', '--force')
    if ($LASTEXITCODE -ne 0) { throw "avdmanager create failed with exit $LASTEXITCODE" }
}

Write-Host "Emulators:" (& $emu -list-avds)

if (-not $Launch -and -not $RunFlutter) {
    Write-Host "Next: -Launch to start emulator, or -RunFlutter to start and run Flutter."
    exit 0
}

if ($Launch -or $RunFlutter) {
    Write-Host "Starting emulator '$avdName'..."
    Start-Process -FilePath $emu -ArgumentList @('-avd', $avdName, '-netdelay', 'none', '-netspeed', 'full')
}

if ($RunFlutter) {
    $cfg = Join-Path $root 'config\supabase.live.json'
    if (-not (Test-Path $cfg)) { throw "Missing $cfg" }
    Write-Host "Waiting for adb..."
    & $adb wait-for-device
    $deadline = (Get-Date).AddMinutes(8)
    while ((Get-Date) -lt $deadline) {
        $boot = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
        if ($boot -eq '1') { break }
        Start-Sleep -Seconds 2
    }
    Set-Location $root
    flutter run --dart-define-from-file=config/supabase.live.json
}
