param(
    [string]$InputApk = ""
)

$ErrorActionPreference = "Stop"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("deepsky-sign-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    if ([string]::IsNullOrWhiteSpace($InputApk)) {
        $defaultApk = Join-Path (Split-Path -Parent $PSScriptRoot) "build\app\outputs\flutter-apk\app-debug.apk"
        if (-not (Test-Path $defaultApk)) {
            throw "No APK found at $defaultApk. Run 'flutter build apk --debug' first or pass -InputApk."
        }
        $InputApk = $defaultApk
    }

    $ksPath = Join-Path $tempRoot "test-release.p12"
    $edDir = Join-Path $tempRoot "ed25519"
    $outDir = Join-Path $tempRoot "out"

    $env:DEEPSKY_KS_PASS = "test-only-password"
    $env:DEEPSKY_KEY_PASS = "test-only-password"

    Write-Host "1. Generating ephemeral test APK keystore..."
    & keytool -genkeypair `
        -keystore $ksPath `
        -storetype PKCS12 `
        -storepass "test-only-password" `
        -alias "test-alias" `
        -keyalg RSA `
        -keysize 2048 `
        -validity 1 `
        -dname "CN=Test Only, O=DeepSkyTest, C=IT" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "keytool failed" }

    Write-Host "2. Generating ephemeral test Ed25519 keypair..."
    & java (Join-Path $PSScriptRoot "Ed25519Tool.java") generate --out-dir $edDir
    if ($LASTEXITCODE -ne 0) { throw "Ed25519 generation failed" }

    $edPriv = Join-Path $edDir "ed25519-private.pkcs8.b64"
    $edPub = Join-Path $edDir "ed25519-public.x509.b64"

    Write-Host "3. Verifying version monotonicity rejection (versionCode 1 <= previous 1)..."
    $rejected = $false
    try {
        & (Join-Path $PSScriptRoot "sign-release.ps1") `
            -UnsignedApk $InputApk `
            -VersionCode 1 `
            -VersionName "1.0.0" `
            -PreviousVersionCode 1 `
            -KeystorePath $ksPath `
            -KeystoreAlias "test-alias" `
            -Ed25519PrivateKeyPath $edPriv `
            -Ed25519PublicKeyPath $edPub `
            -OutDir $outDir
    }
    catch {
        $rejected = $true
        Write-Host "   Correctly rejected non-increasing versionCode: $($_.Exception.Message)"
    }
    if (-not $rejected) {
        throw "Expected sign-release.ps1 to reject non-increasing versionCode!"
    }

    Write-Host "4. Signing APK and manifest with test keys (versionCode 2 > previous 1)..."
    & (Join-Path $PSScriptRoot "sign-release.ps1") `
        -UnsignedApk $InputApk `
        -VersionCode 2 `
        -VersionName "1.0.1" `
        -PreviousVersionCode 1 `
        -KeystorePath $ksPath `
        -KeystoreAlias "test-alias" `
        -Ed25519PrivateKeyPath $edPriv `
        -Ed25519PublicKeyPath $edPub `
        -OutDir $outDir

    Write-Host "5. Verifying tampered manifest is rejected..."
    $manifestPath = Join-Path $outDir "manifest.json"
    $sigPath = Join-Path $outDir "manifest.json.sig"
    $tamperedPath = Join-Path $outDir "manifest.tampered.json"
    (Get-Content -Raw $manifestPath).Replace("1.0.1", "1.0.9") | Set-Content -NoNewline $tamperedPath
    & java (Join-Path $PSScriptRoot "Ed25519Tool.java") verify --pub $edPub --in $tamperedPath --sig $sigPath
    if ($LASTEXITCODE -eq 0) {
        throw "Tampered manifest should have failed signature verification!"
    }
    Write-Host "   Tampered manifest correctly rejected (exit code $LASTEXITCODE)."
    Write-Host "ALL RELEASE SIGNING TESTS PASSED."
}
finally {
    Remove-Item Env:DEEPSKY_KS_PASS -ErrorAction SilentlyContinue
    Remove-Item Env:DEEPSKY_KEY_PASS -ErrorAction SilentlyContinue
    if (Test-Path $tempRoot) {
        Remove-Item -Recurse -Force $tempRoot
    }
}
