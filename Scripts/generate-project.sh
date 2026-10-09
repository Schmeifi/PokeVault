#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen fehlt. Installation (macOS): brew install xcodegen"
  exit 1
fi

xcodegen generate --spec project.yml
echo "PokeVault.xcodeproj erzeugt."
