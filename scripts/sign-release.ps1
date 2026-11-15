param(
    [string]$UnsignedApk           = $env:DEEPSKY_UNSIGNED_APK,
    [string]$VersionCode           = $env:DEEPSKY_VERSION_CODE,
    [string]$VersionName           = $env:DEEPSKY_VERSION_NAME,
    [string]$PreviousVersionCode   = $env:DEEPSKY_PREVIOUS_VERSION_CODE,
    [string]$KeystorePath          = $env:DEEPSKY_KEYSTORE_PATH,
    [string]$KeystoreAlias         = $env:DEEPSKY_KEYSTORE_ALIAS,
    [string]$Ed25519PrivateKeyPath = $env:DEEPSKY_ED25519_PRIV_KEY,
    [string]$OutDir                = $env:DEEPSKY_OUT_DIR,
    [string]$Ed25519PublicKeyPath  = $env:DEEPSKY_ED25519_PUB_KEY,
    [string]$PackageId             = $(if ($env:DEEPSKY_PACKAGE_ID) { $env:DEEPSKY_PACKAGE_ID } else { "com.vectevo.deep_sky" })
)

$ErrorActionPreference = "Stop"

function Resolve-RequiredParam {
    param(
        [string]$Name,
        [string]$CurrentValue,
        [string]$EnvVarName
    )

    if (-not [string]::IsNullOrWhiteSpace($CurrentValue)) {
        return $CurrentValue.Trim('"') # Strips accidental quotes if dragged-and-dropped into terminal
    }

    # Fail fast in CI or headless terminals instead of hanging on Read-Host
    if ($env:CI -eq "true" -or -not [Environment]::UserInteractive) {
        throw "Missing required parameter '-$Name' (and '$EnvVarName' is not set)."
    }

    $inputVal = Read-Host "Enter $Name (or set $EnvVarName)"
    if ([string]::IsNullOrWhiteSpace($inputVal)) {
        throw "Parameter '-$Name' cannot be empty."
    }

    return $inputVal.Trim('"')
}

$UnsignedApk           = Resolve-RequiredParam -Name "UnsignedApk"           -CurrentValue $UnsignedApk           -EnvVarName "DEEPSKY_UNSIGNED_APK"
$VersionCode           = Resolve-RequiredParam -Name "VersionCode"           -CurrentValue $VersionCode           -EnvVarName "DEEPSKY_VERSION_CODE"
$VersionName           = Resolve-RequiredParam -Name "VersionName"           -CurrentValue $VersionName           -EnvVarName "DEEPSKY_VERSION_NAME"
$PreviousVersionCode   = Resolve-RequiredParam -Name "PreviousVersionCode"   -CurrentValue $PreviousVersionCode   -EnvVarName "DEEPSKY_PREVIOUS_VERSION_CODE"
$KeystorePath          = Resolve-RequiredParam -Name "KeystorePath"          -CurrentValue $KeystorePath          -EnvVarName "DEEPSKY_KEYSTORE_PATH"
$KeystoreAlias         = Resolve-RequiredParam -Name "KeystoreAlias"         -CurrentValue $KeystoreAlias         -EnvVarName "DEEPSKY_KEYSTORE_ALIAS"
$Ed25519PrivateKeyPath = Resolve-RequiredParam -Name "Ed25519PrivateKeyPath" -CurrentValue $Ed25519PrivateKeyPath -EnvVarName "DEEPSKY_ED25519_PRIV_KEY"
$OutDir                = Resolve-RequiredParam -Name "OutDir"                -CurrentValue $OutDir                -EnvVarName "DEEPSKY_OUT_DIR"

# Cast integers after resolution
[int]$VersionCodeInt         = $VersionCode
[int]$PreviousVersionCodeInt = $PreviousVersionCode

if ($VersionCodeInt -le $PreviousVersionCodeInt) {
    throw "Refusing to sign: versionCode ($VersionCodeInt) must be strictly greater than previousVersionCode ($PreviousVersionCodeInt)."
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
$apkFileName = "deep-sky-$VersionName-$VersionCodeInt.apk"
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
    versionCode   = $VersionCodeInt
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
