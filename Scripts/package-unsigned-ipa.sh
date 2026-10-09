#!/usr/bin/env bash
# Packt ein unsigned .app aus dem Xcode-Build in eine .ipa (Payload/).
# Für Sideloadly / TrollStore o. Ä. – kein Apple-Developer-Signing.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <path-to-PokeVault.app> <output.ipa>"
  exit 1
fi

APP_PATH="$1"
OUTPUT_IPA="$2"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

mkdir -p "$WORKDIR/Payload"
cp -R "$APP_PATH" "$WORKDIR/Payload/"
(
  cd "$WORKDIR"
  zip -qr "$OUTPUT_IPA" Payload
)
echo "IPA geschrieben: $OUTPUT_IPA"
