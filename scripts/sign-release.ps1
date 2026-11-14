param(
    [Parameter(Mandatory = $true)][string]$UnsignedApk,
    [Parameter(Mandatory = $true)][int]$VersionCode,
    [Parameter(Mandatory = $true)][string]$VersionName,
    [Parameter(Mandatory = $true)][int]$PreviousVersionCode,
    [Parameter(Mandatory = $true)][string]$KeystorePath,
    [Parameter(Mandatory = $true)][string]$KeystoreAlias,
    [Parameter(Mandatory = $true)][string]$Ed25519PrivateKeyPath,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Ed25519PublicKeyPath = "",
    [string]$PackageId = "com.vectevo.deep_sky"
)

$ErrorActionPreference = "Stop"

if ($VersionCode -le $PreviousVersionCode) {
    throw "Refusing to sign: versionCode ($VersionCode) must be strictly greater than previousVersionCode ($PreviousVersionCode)."
}

if (-not (Test-Path $UnsignedApk -PathType Leaf)) {
    throw "Unsigned APK not found: $UnsignedApk"
}
if (-not (Test-Path $KeystorePath -PathType Leaf)) {
    throw "Keystore not found: $KeystorePath"
}
if (-not (Test-Path $Ed25519PrivateKeyPath -PathType Leaf)) {
    throw "Ed25519 private key not found: $Ed25519PrivateKeyPath"
}

function Find-ApkSigner {
    $cmd = Get-Command apksigner -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $sdkRoot = $env:ANDROID_HOME
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        $sdkRoot = $env:ANDROID_SDK_ROOT
    }
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    }
    $buildToolsDir = Join-Path $sdkRoot "build-tools"
    if (Test-Path $buildToolsDir) {
        $latest = Get-ChildItem $buildToolsDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) {
            $candidate = Join-Path $latest.FullName "apksigner.bat"
            if (Test-Path $candidate) { return $candidate }
        }
    }
    throw "apksigner not found on PATH or in ANDROID_HOME/build-tools."
}

$apksigner = Find-ApkSigner
$repoRoot = Split-Path -Parent $PSScriptRoot
$ed25519Tool = Join-Path $PSScriptRoot "Ed25519Tool.java"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$apkFileName = "deep-sky-$VersionName-$VersionCode.apk"
$signedApkPath = Join-Path $OutDir $apkFileName
$manifestPath = Join-Path $OutDir "manifest.json"
$manifestSigPath = Join-Path $OutDir "manifest.json.sig"

$ksPass = $env:DEEPSKY_KS_PASS
$keyPass = $env:DEEPSKY_KEY_PASS

$signArgs = @(
    "sign",
    "--ks", $KeystorePath,
    "--ks-key-alias", $KeystoreAlias,
    "--out", $signedApkPath
)
if (-not [string]::IsNullOrEmpty($ksPass)) {
    $signArgs += @("--ks-pass", "env:DEEPSKY_KS_PASS")
}
if (-not [string]::IsNullOrEmpty($keyPass)) {
    $signArgs += @("--key-pass", "env:DEEPSKY_KEY_PASS")
}
$signArgs += $UnsignedApk

Write-Host "Signing APK with $apksigner..."
& $apksigner @signArgs
if ($LASTEXITCODE -ne 0) { throw "apksigner sign failed with exit code $LASTEXITCODE" }

Write-Host "Verifying signed APK..."
& $apksigner verify --verbose $signedApkPath
if ($LASTEXITCODE -ne 0) { throw "apksigner verify failed with exit code $LASTEXITCODE" }

$apkHash = (Get-FileHash -Algorithm SHA256 -Path $signedApkPath).Hash.ToLowerInvariant()
$apkSize = (Get-Item $signedApkPath).Length

$manifestObj = [ordered]@{
    schemaVersion = 1
    packageId     = $PackageId
    versionCode   = $VersionCode
    versionName   = $VersionName
    apkFile       = $apkFileName
    apkSha256     = $apkHash
    apkSizeBytes  = $apkSize
    createdAt     = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}
$manifestJson = ($manifestObj | ConvertTo-Json -Depth 4) + "`n"
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

Write-Host "Signing manifest.json with Ed25519..."
& java $ed25519Tool sign --key $Ed25519PrivateKeyPath --in $manifestPath --out $manifestSigPath
if ($LASTEXITCODE -ne 0) { throw "Ed25519 manifest signing failed." }

if (-not [string]::IsNullOrWhiteSpace($Ed25519PublicKeyPath)) {
    & java $ed25519Tool verify --pub $Ed25519PublicKeyPath --in $manifestPath --sig $manifestSigPath
    if ($LASTEXITCODE -ne 0) { throw "Ed25519 manifest self-verification failed." }
}

Write-Host "Release artifacts ready in ${OutDir}:"
Write-Host " - $signedApkPath (SHA-256: $apkHash)"
Write-Host " - $manifestPath"
Write-Host " - $manifestSigPath"
