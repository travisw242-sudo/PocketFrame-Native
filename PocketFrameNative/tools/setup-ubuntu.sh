#!/usr/bin/env bash
set -euo pipefail
# Only build tools; no ROMs, profiles, keys or game downloads.
sudo apt-get update
sudo apt-get install --no-install-recommends -y \
    build-essential cmake ninja-build python3 pkg-config git ca-certificates \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu file
echo "Toolchain installed. Run bash tools/build-linux-arm64.sh from PocketFrameNative."
