#!/usr/bin/env sh
set -eu
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit scripts/*.sh
echo "Configured git core.hooksPath to .githooks"
