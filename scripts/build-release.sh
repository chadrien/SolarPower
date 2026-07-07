#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version e.g. 1.0.0>" >&2
  exit 1
fi
sed -i "s/^## Version: .*/## Version: ${VERSION}/" "$ROOT/SolarPower/SolarPower.toc"
rm -rf "$ROOT/dist" "$ROOT/SolarPower.zip"
mkdir -p "$ROOT/dist"
cp -r "$ROOT/SolarPower" "$ROOT/dist/"
(cd "$ROOT/dist" && zip -r "$ROOT/SolarPower.zip" SolarPower)
echo "Built $ROOT/SolarPower.zip"
