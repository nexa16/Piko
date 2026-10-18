[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Flutter,
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Device,
    [Parameter(Mandatory = $true)][string]$Target,
    [string[]]$Define = @()
)

# Build only, install directly with no uninstall fallback, and attach to the
# authenticated, paused process. Never use Flutter's application-start path.
# Fixtures and the caller own their evidence output and any native phase ACKs.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$appRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$package = 'io.github.nexa16.piko'
$activity = "$package/.MainActivity"
$forwardedPort = $null
$baseline = $null
$failure = $null

function Resolve-Executable([string]$Name) {
    if (Test-Path -LiteralPath $Name -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Name).ProviderPath
    }
    $command = Get-Command -Name $Name -CommandType Application, ExternalScript -ErrorAction Stop |
        Select-Object -First 1
    if (-not $command.Path) { throw 'Executable must resolve to a file or installed command.' }
    return $command.Path
}

$flutterExecutable = Resolve-Executable $Flutter
$adbExecutable = Resolve-Executable $Adb
if ([string]::IsNullOrWhiteSpace($Device) -or $Device.StartsWith('-')) {
    throw 'An explicit Android device serial is required.'
}
$targetCandidate = if ([IO.Path]::IsPathRooted($Target)) {
    $Target
} else {
    Join-Path $appRoot $Target
}
if (-not (Test-Path -LiteralPath $targetCandidate -PathType Leaf)) {
    throw 'Integration target does not exist.'
}
$targetPath = (Resolve-Path -LiteralPath $targetCandidate).ProviderPath
$integrationRoot = [IO.Path]::GetFullPath((Join-Path $appRoot 'integration_test')) + [IO.Path]::DirectorySeparatorChar
if (-not $targetPath.StartsWith($integrationRoot, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetExtension($targetPath) -ne '.dart' -or
    (Get-Item -LiteralPath $targetPath).LinkType) {
    throw 'Target must be a real Dart file inside this app integration_test directory.'
}
$driverPath = Join-Path $appRoot 'test_driver/attach_only.dart'
if (-not (Test-Path -LiteralPath $driverPath -PathType Leaf)) {
    throw 'The attach-only host driver is missing.'
}
foreach ($item in $Define) {
    if ($item -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') {
        throw 'Each Define must be a KEY=value Dart define.'
    }
    if ($item -match '^INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=' -and
        $item -ne 'INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false') {
        throw 'Attach-only acceptance does not use native instrumentation reporting.'
    }
}

function Invoke-Adb([string[]]$Arguments, [switch]$AllowMissingProcess) {
    $lines = @(& $adbExecutable -s $Device @Arguments 2>&1)
    $code = $LASTEXITCODE
    $result = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
    if ($AllowMissingProcess -and $code -eq 1 -and [string]::IsNullOrWhiteSpace($result)) {
        return ''
    }
    if ($code -ne 0) { throw "ADB operation failed (exit $code); no fallback attempted." }
    return $result
}

function Read-ProtectedFiles {
    $result = @{}
    # A main-file hash alone is not a complete SQLite preservation boundary
    # while a WAL or rollback journal exists. Do not open/checkpoint it here.
    foreach ($sidecar in @('piko.sqlite-wal', 'piko.sqlite-shm', 'piko.sqlite-journal')) {
        $null = Invoke-Adb -Arguments @('shell', "run-as $package sh -c 'if [ -e files/$sidecar ] || [ -L files/$sidecar ]; then exit 23; fi'")
    }
    foreach ($name in @('piko.sqlite', 'release-final-sentinel.txt')) {
        # Fixed filenames only. Reject symlinks and non-files rather than treating
        # an unreadable original as absent. Both project baseline files must
        # exist before any replacement. Never open/checkpoint SQLite itself.
        $remote = "run-as $package sh -c 'if [ -L files/$name ]; then exit 21; elif [ -f files/$name ]; then sha256sum files/$name; elif [ -e files/$name ]; then exit 22; else echo MISSING; fi'"
        $output = (Invoke-Adb -Arguments @('shell', $remote)).Trim()
        if ($output -eq 'MISSING') {
            throw 'A required protected baseline file is missing; refusing acceptance.'
        } elseif ($output -match '^([0-9a-fA-F]{64})\s+') {
            $result[$name] = $Matches[1].ToLowerInvariant()
        } else {
            throw 'Protected-file fingerprint could not be read; refusing acceptance.'
        }
    }
    return $result
}

function Assert-ProtectedFiles([hashtable]$Original) {
    $current = Read-ProtectedFiles
    foreach ($name in $Original.Keys) {
        if ($current[$name] -ne $Original[$name]) {
            throw 'Protected application file changed or disappeared; preserve all data and investigate.'
        }
    }
}

Push-Location -LiteralPath $appRoot
try {
    # Require an already installed, debuggable app. Failure to inspect its private
    # directory must stop here, never become a fresh-install/empty-data baseline.
    $null = Invoke-Adb -Arguments @('get-state')
    $null = Invoke-Adb -Arguments @('shell', 'am', 'force-stop', $package)
    $remainingProcess = (Invoke-Adb -Arguments @('shell', 'pidof', '-s', $package) -AllowMissingProcess).Trim()
    if ($remainingProcess) { throw 'Application is still running after force-stop; refusing acceptance.' }
    $baseline = Read-ProtectedFiles
    $installedPackage = Invoke-Adb -Arguments @('shell', 'dumpsys', 'package', $package)
    $installedVersions = [regex]::Matches($installedPackage, '(?m)^\s*versionCode=(\d+)\b')
    if ($installedVersions.Count -ne 1) {
        throw 'Installed versionCode is ambiguous; refusing acceptance.'
    }
    $installedVersion = $installedVersions[0].Groups[1].Value
    $abi = (Invoke-Adb -Arguments @('shell', 'getprop', 'ro.product.cpu.abi')).Trim()
    $targetPlatform = switch ($abi) {
        'x86_64' { 'android-x64' }
        'arm64-v8a' { 'android-arm64' }
        'armeabi-v7a' { 'android-arm' }
        default { throw 'Device ABI has no supported Flutter Android target platform.' }
    }
    # Build a single matching ABI, avoiding the storage cost of a universal APK.
    $buildArguments = @('build', 'apk', '--debug', '--no-pub', '--target', $targetPath,
        '--target-platform', $targetPlatform,
        "--build-number=$installedVersion",
        '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false')
    foreach ($item in $Define) { $buildArguments += "--dart-define=$item" }
    & $flutterExecutable @buildArguments
    if ($LASTEXITCODE -ne 0) { throw "APK build failed (exit $LASTEXITCODE)." }
    $apk = Join-Path $appRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) { throw 'Expected debug APK is missing.' }
    $installed = Invoke-Adb -Arguments @('install', '-r', '-t', $apk)
    if ($installed -match '(?im)\bFailure\b|INSTALL_FAILED|\bError:' -or
        $installed -notmatch '(?im)^\s*Success\s*$') {
        throw 'Direct APK replacement did not report Success; no fallback attempted.'
    }
    Assert-ProtectedFiles $baseline
    # Do not wait for the first rendered frame: the isolate is deliberately
    # paused until the attach-only driver connects and resumes it below.
    $started = Invoke-Adb -Arguments @('shell', 'am', 'start', '-n', $activity,
        '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER',
        '--ez', 'enable-checked-mode', 'true', '--ez', 'verify-entry-points', 'true',
        '--ez', 'start-paused', 'true')
    if ($started -match '(?im)\bError:|\bException\b|Status:\s*(?!ok\b)\S+') {
        throw 'Manual activity start failed; application data is retained.'
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    $vmUri = $null
    $processId = $null
    while ([DateTime]::UtcNow -lt $deadline) {
        $candidateId = (Invoke-Adb -Arguments @('shell', 'pidof', '-s', $package) -AllowMissingProcess).Trim()
        if ([string]::IsNullOrWhiteSpace($candidateId)) {
            Start-Sleep -Milliseconds 250
            continue
        }
        if ($candidateId -notmatch '^\d+$') { throw 'The manually launched app has no unique PID.' }
        if ($processId -and $processId -ne $candidateId) { throw 'Application PID changed while attaching.' }
        $processId = $candidateId
        $log = Invoke-Adb -Arguments @('logcat', '-d', "--pid=$processId", '-t', '300')
        $urls = [regex]::Matches($log, '(?:Dart )?VM [Ss]ervice (?:is )?listening on\s+(http://(?:127\.0\.0\.1|localhost):\d+/[^\s]+)')
        if ($urls.Count -gt 0) {
            $candidate = [Uri]$urls[$urls.Count - 1].Groups[1].Value
            if ($candidate.AbsolutePath -eq '/' -or -not $candidate.AbsolutePath.EndsWith('/')) {
                throw 'The VM service did not expose an authenticated URI.'
            }
            $vmUri = $candidate
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $vmUri) { throw 'Authenticated VM service was not observed within 30 seconds.' }
    $forwardedPort = (Invoke-Adb -Arguments @('forward', 'tcp:0', "tcp:$($vmUri.Port)")).Trim()
    if ($forwardedPort -notmatch '^\d+$') { throw 'ADB did not allocate a local forwarding port.' }
    $attachUri = [UriBuilder]::new($vmUri)
    $attachUri.Host = '127.0.0.1'
    $attachUri.Port = [int]$forwardedPort
    # This exact flag selects reuseApplication, bypassing all install/start code.
    # Explicit keep-app-running also prevents Flutter drive's teardown path.
    & $flutterExecutable drive --no-pub -d $Device --target $targetPath --driver $driverPath `
        "--use-existing-app=$($attachUri.Uri.AbsoluteUri)" --keep-app-running --no-dds
    if ($LASTEXITCODE -ne 0) { throw "Attach-only acceptance failed (exit $LASTEXITCODE); app retained." }
    Assert-ProtectedFiles $baseline
    Write-Host 'Android acceptance passed; protected files unchanged and application retained.'
} catch {
    $failure = $_
} finally {
    if ($baseline) {
        try { Assert-ProtectedFiles $baseline } catch { $failure = $_ }
    }
    if ($forwardedPort -match '^\d+$') {
        try { $null = Invoke-Adb -Arguments @('forward', '--remove', "tcp:$forwardedPort") } catch {
            if (-not $failure) { $failure = $_ }
        }
    }
    Pop-Location
}
if ($failure) { throw $failure }
