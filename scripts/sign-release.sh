#!/usr/bin/env bash
set -euo pipefail

# Sign an unsigned APK and produce a signed release manifest (SEC-04, TC-10).
# Usage:
#   DEEPSKY_KS_PASS=... DEEPSKY_KEY_PASS=... ./scripts/sign-release.sh \
#     --apk app-release-unsigned.apk \
#     --version-code 2 \
#     --version-name 1.0.1 \
#     --prev-version-code 1 \
#     --keystore /path/to/release.p12 \
#     --alias deep-sky-release \
#     --ed25519-key /path/to/ed25519-private.pkcs8.b64 \
#     --out-dir ./release-out \
#     [--ed25519-pub /path/to/ed25519-public.x509.b64]

UNSIGNED_APK=""
VERSION_CODE=""
VERSION_NAME=""
PREV_VERSION_CODE=""
KEYSTORE=""
ALIAS=""
ED25519_KEY=""
ED25519_PUB=""
OUT_DIR=""
PACKAGE_ID="com.vectevo.deep_sky"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apk) UNSIGNED_APK="$2"; shift 2 ;;
    --version-code) VERSION_CODE="$2"; shift 2 ;;
    --version-name) VERSION_NAME="$2"; shift 2 ;;
    --prev-version-code) PREV_VERSION_CODE="$2"; shift 2 ;;
    --keystore) KEYSTORE="$2"; shift 2 ;;
    --alias) ALIAS="$2"; shift 2 ;;
    --ed25519-key) ED25519_KEY="$2"; shift 2 ;;
    --ed25519-pub) ED25519_PUB="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --package-id) PACKAGE_ID="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$UNSIGNED_APK" ] || [ -z "$VERSION_CODE" ] || [ -z "$VERSION_NAME" ] || [ -z "$PREV_VERSION_CODE" ] || [ -z "$KEYSTORE" ] || [ -z "$ALIAS" ] || [ -z "$ED25519_KEY" ] || [ -z "$OUT_DIR" ]; then
  echo "Missing required arguments." >&2
  exit 1
fi

if [ "$VERSION_CODE" -le "$PREV_VERSION_CODE" ]; then
  echo "Refusing to sign: versionCode ($VERSION_CODE) must be greater than prevVersionCode ($PREV_VERSION_CODE)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ED25519_TOOL="$SCRIPT_DIR/Ed25519Tool.java"

find_apksigner() {
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -n "$sdk" ] && [ -d "$sdk/build-tools" ]; then
    local latest
    latest="$(ls -1 "$sdk/build-tools" | sort -V | tail -n 1)"
    if [ -x "$sdk/build-tools/$latest/apksigner" ]; then
      echo "$sdk/build-tools/$latest/apksigner"
      return
    fi
  fi
  echo "apksigner not found" >&2
  exit 1
}

APKSIGNER="$(find_apksigner)"
mkdir -p "$OUT_DIR"

APK_NAME="deep-sky-${VERSION_NAME}-${VERSION_CODE}.apk"
SIGNED_APK="$OUT_DIR/$APK_NAME"
MANIFEST="$OUT_DIR/manifest.json"
MANIFEST_SIG="$OUT_DIR/manifest.json.sig"

SIGN_ARGS=(sign --ks "$KEYSTORE" --ks-key-alias "$ALIAS" --out "$SIGNED_APK")
[ -n "${DEEPSKY_KS_PASS:-}" ] && SIGN_ARGS+=(--ks-pass env:DEEPSKY_KS_PASS)
[ -n "${DEEPSKY_KEY_PASS:-}" ] && SIGN_ARGS+=(--key-pass env:DEEPSKY_KEY_PASS)
SIGN_ARGS+=("$UNSIGNED_APK")

"$APKSIGNER" "${SIGN_ARGS[@]}"
"$APKSIGNER" verify --verbose "$SIGNED_APK"

APK_SHA256="$(sha256sum "$SIGNED_APK" | awk '{print $1}')"
APK_SIZE="$(wc -c < "$SIGNED_APK" | tr -d ' ')"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$MANIFEST" <<EOF
{
  "schemaVersion": 1,
  "packageId": "$PACKAGE_ID",
  "versionCode": $VERSION_CODE,
  "versionName": "$VERSION_NAME",
  "apkFile": "$APK_NAME",
  "apkSha256": "$APK_SHA256",
  "apkSizeBytes": $APK_SIZE,
  "createdAt": "$CREATED_AT"
}
EOF

java "$ED25519_TOOL" sign --key "$ED25519_KEY" --in "$MANIFEST" --out "$MANIFEST_SIG"
if [ -n "$ED25519_PUB" ]; then
  java "$ED25519_TOOL" verify --pub "$ED25519_PUB" --in "$MANIFEST" --sig "$MANIFEST_SIG"
fi

echo "Release artifacts ready in $OUT_DIR"
