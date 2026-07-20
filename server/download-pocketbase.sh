#!/usr/bin/env bash
# Κατεβάζει το PocketBase binary για Linux (π.χ. Oracle Ampere A1 = arm64).
# Το binary ΔΕΝ μπαίνει στο git.
set -euo pipefail
VERSION="0.39.8"
HERE="$(cd "$(dirname "$0")" && pwd)"

# arch autodetect: Ampere A1 = aarch64 -> arm64, x86_64 -> amd64
case "$(uname -m)" in
  aarch64|arm64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="amd64" ;;
  *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

URL="https://github.com/pocketbase/pocketbase/releases/download/v${VERSION}/pocketbase_${VERSION}_linux_${ARCH}.zip"
echo "Downloading PocketBase v${VERSION} (linux_${ARCH}) ..."
curl -L -o "${HERE}/pb.zip" "$URL"
unzip -o "${HERE}/pb.zip" -d "$HERE"
rm -f "${HERE}/pb.zip"
chmod +x "${HERE}/pocketbase"
"${HERE}/pocketbase" --version
echo "OK. Ξεκίνα με:  ./pocketbase serve --http=0.0.0.0:8090"
