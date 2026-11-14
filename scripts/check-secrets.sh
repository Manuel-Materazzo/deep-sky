#!/usr/bin/env sh
set -eu

MODE="tracked"
if [ "${1:-}" = "--staged" ]; then
  MODE="staged"
elif [ "${1:-}" = "--history" ]; then
  MODE="history"
fi

check_filename() {
  f="$1"
  base="$(basename "$f")"
  case "$f" in
    *.jks|*.keystore|*.p12|*.pem|*.key)
      echo "Forbidden key/certificate file: $f" >&2
      return 1
      ;;
  esac
  case "$base" in
    google-services.json|.env)
      echo "Forbidden secret/env file: $f" >&2
      return 1
      ;;
    .env.example)
      ;;
    .env.*)
      echo "Forbidden environment file: $f" >&2
      return 1
      ;;
    firebase-service-account*.json)
      echo "Forbidden Firebase service account file: $f" >&2
      return 1
      ;;
  esac
  return 0
}

PATTERN='-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----|"type"[[:space:]]*:[[:space:]]*"service_account"|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,}'

FAILED=0

if [ "$MODE" = "staged" ]; then
  for f in $(git diff --cached --name-only --diff-filter=ACM); do
    if ! check_filename "$f"; then
      FAILED=1
      continue
    fi
    if git show ":$f" | grep -Eq "$PATTERN"; then
      echo "Secret pattern detected in staged file: $f" >&2
      FAILED=1
    fi
  done
elif [ "$MODE" = "history" ]; then
  for c in $(git rev-list --all); do
    for f in $(git diff-tree --no-commit-id --name-only -r "$c"); do
      if ! check_filename "$f"; then
        echo "  in commit $c" >&2
        FAILED=1
      fi
    done
    if git show "$c" --pretty=format: | grep -E '^\+' | grep -Ev '^\+\+\+' | grep -Eq "$PATTERN"; then
      echo "Secret pattern detected in commit history: $c" >&2
      FAILED=1
    fi
  done
else
  for f in $(git ls-files); do
    if ! check_filename "$f"; then
      FAILED=1
      continue
    fi
    if [ -f "$f" ] && grep -Eq "$PATTERN" "$f"; then
      echo "Secret pattern detected in tracked file: $f" >&2
      FAILED=1
    fi
  done
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "Secret scan passed ($MODE)."
